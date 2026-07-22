use core::ffi::{c_char, c_void};
use hkdf::Hkdf;
use sha2::Sha256;
use zeroize::Zeroizing;

const KEY_INFO: &[u8] = b"kelivo.sqlcipher.database.key.v1";
const SQLITE_OK: i32 = 0;
const SQLITE_DONE: i32 = 101;
pub(super) const DATABASE_ID_SIZE: usize = 16;
pub(super) const DATABASE_NAME_MAX_SIZE: usize = 64;
pub(super) const DATABASE_PATH_MAX_SIZE: usize = 64 * 1024;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(super) enum DatabaseKeyError {
    Crypto,
    InvalidInput,
    KeyCallbackFailed,
    AttachCallbackFailed,
}

pub(super) fn derive_database_key(
    master_key: &[u8; 32],
    database_id: &[u8; 16],
    epoch: u64,
) -> Result<Zeroizing<[u8; 32]>, DatabaseKeyError> {
    if epoch == 0 {
        return Err(DatabaseKeyError::InvalidInput);
    }
    let mut database_key = Zeroizing::new([0_u8; 32]);
    let epoch_bytes = epoch.to_be_bytes();
    Hkdf::<Sha256>::new(Some(database_id), master_key)
        .expand_multi_info(&[KEY_INFO, &epoch_bytes], &mut database_key[..])
        .map_err(|_| DatabaseKeyError::Crypto)?;
    Ok(database_key)
}

pub(super) type SqlCipherKeyCallback = unsafe extern "C" fn(*mut c_void, *const c_void, i32) -> i32;
pub(super) type SqlitePrepareCallback = unsafe extern "C" fn(
    *mut c_void,
    *const c_char,
    i32,
    *mut *mut c_void,
    *mut *const c_char,
) -> i32;
pub(super) type SqliteDestructor = unsafe extern "C" fn(*mut c_void);
pub(super) type SqliteBindTextCallback =
    unsafe extern "C" fn(*mut c_void, i32, *const c_char, i32, Option<SqliteDestructor>) -> i32;
pub(super) type SqliteBindBlobCallback =
    unsafe extern "C" fn(*mut c_void, i32, *const c_void, i32, Option<SqliteDestructor>) -> i32;
pub(super) type SqliteStepCallback = unsafe extern "C" fn(*mut c_void) -> i32;
pub(super) type SqliteFinalizeCallback = unsafe extern "C" fn(*mut c_void) -> i32;

#[derive(Clone, Copy)]
pub(super) struct SqliteAttachCallbacks {
    pub(super) prepare: SqlitePrepareCallback,
    pub(super) bind_text: SqliteBindTextCallback,
    pub(super) bind_blob: SqliteBindBlobCallback,
    pub(super) step: SqliteStepCallback,
    pub(super) finalize: SqliteFinalizeCallback,
}

pub(super) fn apply_database_key(
    master_key: &[u8; 32],
    database_id: &[u8; 16],
    epoch: u64,
    database: *mut c_void,
    key_callback: SqlCipherKeyCallback,
) -> Result<(), DatabaseKeyError> {
    if database.is_null() {
        return Err(DatabaseKeyError::InvalidInput);
    }
    let database_key = derive_database_key(master_key, database_id, epoch)?;
    let result = unsafe {
        key_callback(
            database,
            database_key.as_ptr().cast::<c_void>(),
            database_key.len() as i32,
        )
    };
    if result != 0 {
        return Err(DatabaseKeyError::KeyCallbackFailed);
    }
    Ok(())
}

pub(super) fn attach_database(
    master_key: &[u8; 32],
    database_id: &[u8; 16],
    epoch: u64,
    database: *mut c_void,
    database_path: &[u8],
    database_name: &[u8],
    callbacks: SqliteAttachCallbacks,
) -> Result<(), DatabaseKeyError> {
    if database.is_null() {
        return Err(DatabaseKeyError::InvalidInput);
    }
    let database_path_text = validate_database_path(database_path)?;
    // ATTACH 默认会创建缺失文件；源库路径错误必须在 SQLite 产生空库前失败。
    if !std::path::Path::new(database_path_text).is_file() {
        return Err(DatabaseKeyError::InvalidInput);
    }
    validate_database_name(database_name)?;
    let database_key = derive_database_key(master_key, database_id, epoch)?;
    let mut sql = Vec::with_capacity(35 + database_name.len());
    sql.extend_from_slice(b"ATTACH DATABASE ? AS \"");
    sql.extend_from_slice(database_name);
    sql.extend_from_slice(b"\" KEY ?;");
    sql.push(0);
    let sql_length = i32::try_from(sql.len() - 1).map_err(|_| DatabaseKeyError::InvalidInput)?;
    let path_length =
        i32::try_from(database_path.len()).map_err(|_| DatabaseKeyError::InvalidInput)?;

    let mut statement = core::ptr::null_mut();
    let prepare_result = unsafe {
        (callbacks.prepare)(
            database,
            sql.as_ptr().cast::<c_char>(),
            sql_length,
            &mut statement,
            core::ptr::null_mut(),
        )
    };
    if prepare_result != SQLITE_OK || statement.is_null() {
        if !statement.is_null() {
            unsafe {
                (callbacks.finalize)(statement);
            }
        }
        return Err(DatabaseKeyError::AttachCallbackFailed);
    }

    let operation = (|| {
        let path_result = unsafe {
            (callbacks.bind_text)(
                statement,
                1,
                database_path.as_ptr().cast::<c_char>(),
                path_length,
                None,
            )
        };
        if path_result != SQLITE_OK {
            return Err(DatabaseKeyError::AttachCallbackFailed);
        }
        let key_result = unsafe {
            (callbacks.bind_blob)(
                statement,
                2,
                database_key.as_ptr().cast::<c_void>(),
                database_key.len() as i32,
                None,
            )
        };
        if key_result != SQLITE_OK {
            return Err(DatabaseKeyError::AttachCallbackFailed);
        }
        if unsafe { (callbacks.step)(statement) } != SQLITE_DONE {
            return Err(DatabaseKeyError::AttachCallbackFailed);
        }
        Ok(())
    })();
    let finalize_result = unsafe { (callbacks.finalize)(statement) };
    if operation.is_err() || finalize_result != SQLITE_OK {
        return Err(DatabaseKeyError::AttachCallbackFailed);
    }
    operation
}

fn validate_database_path(database_path: &[u8]) -> Result<&str, DatabaseKeyError> {
    if database_path.is_empty()
        || database_path.len() > DATABASE_PATH_MAX_SIZE
        || database_path.contains(&0)
    {
        return Err(DatabaseKeyError::InvalidInput);
    }
    core::str::from_utf8(database_path).map_err(|_| DatabaseKeyError::InvalidInput)
}

fn validate_database_name(database_name: &[u8]) -> Result<(), DatabaseKeyError> {
    if database_name.is_empty() || database_name.len() > DATABASE_NAME_MAX_SIZE {
        return Err(DatabaseKeyError::InvalidInput);
    }
    let first = database_name[0];
    if !(first.is_ascii_alphabetic() || first == b'_')
        || !database_name
            .iter()
            .all(|byte| byte.is_ascii_alphanumeric() || *byte == b'_')
        || database_name.eq_ignore_ascii_case(b"main")
        || database_name.eq_ignore_ascii_case(b"temp")
    {
        return Err(DatabaseKeyError::InvalidInput);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn database_key_matches_independent_hkdf_vector() {
        let master_key = core::array::from_fn(|index| index as u8);
        let database_id = [0x42_u8; 16];
        let expected = [
            0x9d, 0xd8, 0xf8, 0x57, 0xb5, 0xa0, 0x79, 0x91, 0xb0, 0x03, 0x87, 0x62, 0xed, 0xe9,
            0xf1, 0x99, 0xef, 0xd4, 0x5c, 0x92, 0xf0, 0xc7, 0x22, 0xcf, 0x2f, 0xff, 0xec, 0xca,
            0x8a, 0x1d, 0xf9, 0x2e,
        ];

        let actual =
            derive_database_key(&master_key, &database_id, 7).expect("数据库子密钥应派生成功");
        assert_eq!(&actual[..], &expected);
    }

    #[test]
    fn database_key_rejects_zero_epoch() {
        assert_eq!(
            derive_database_key(&[0_u8; 32], &[0_u8; 16], 0),
            Err(DatabaseKeyError::InvalidInput)
        );
    }

    #[test]
    fn named_database_accepts_internal_alias_boundaries() {
        assert!(validate_database_name(b"backup_probe").is_ok());
        assert!(validate_database_name(b"_restore2").is_ok());
        assert!(validate_database_name(&[b'a'; DATABASE_NAME_MAX_SIZE]).is_ok());
    }

    #[test]
    fn named_database_rejects_reserved_or_unsafe_aliases() {
        for database_name in [
            &b""[..],
            &b"main"[..],
            &b"TEMP"[..],
            &b"1backup"[..],
            &b"backup-probe"[..],
            &b"backup\0probe"[..],
        ] {
            assert_eq!(
                validate_database_name(database_name),
                Err(DatabaseKeyError::InvalidInput)
            );
        }
        assert_eq!(
            validate_database_name(&[b'a'; DATABASE_NAME_MAX_SIZE + 1]),
            Err(DatabaseKeyError::InvalidInput)
        );
    }

    #[test]
    fn attached_database_rejects_invalid_paths() {
        for database_path in [&b""[..], &b"backup\0.sqlite"[..], &[0xff][..]] {
            assert_eq!(
                validate_database_path(database_path),
                Err(DatabaseKeyError::InvalidInput)
            );
        }
        assert_eq!(
            validate_database_path(&[b'a'; DATABASE_PATH_MAX_SIZE + 1]),
            Err(DatabaseKeyError::InvalidInput)
        );
    }
}
