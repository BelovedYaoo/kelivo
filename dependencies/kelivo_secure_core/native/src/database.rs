use core::ffi::c_void;
use hkdf::Hkdf;
use sha2::Sha256;
use zeroize::Zeroizing;

const KEY_INFO: &[u8] = b"kelivo.sqlcipher.database.key.v1";
pub(super) const DATABASE_ID_SIZE: usize = 16;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(super) enum DatabaseKeyError {
    Crypto,
    InvalidInput,
    KeyCallbackFailed,
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
}
