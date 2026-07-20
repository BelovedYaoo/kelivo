use super::{
    BACKGROUND_ACCESS_CAPABILITY, KEY_SLOT_ID_SIZE, KEY_SLOTS_CAPABILITY, KelivoStatus,
    LOCAL_KEY_SIZE, LocalKey,
};
use core::mem::size_of;
use std::{
    env,
    fs::{self, File, OpenOptions},
    io::{ErrorKind, Read, Write},
    iter,
    os::windows::ffi::OsStrExt,
    path::{Path, PathBuf},
    ptr, slice,
};
use windows_sys::Win32::{
    Foundation::{ERROR_ALREADY_EXISTS, ERROR_FILE_EXISTS, GetLastError, LocalFree},
    Security::Cryptography::{
        BCRYPT_USE_SYSTEM_PREFERRED_RNG, BCryptGenRandom, CRYPT_INTEGER_BLOB,
        CRYPTPROTECT_UI_FORBIDDEN, CryptProtectData, CryptUnprotectData,
    },
    Storage::FileSystem::{MOVEFILE_WRITE_THROUGH, MoveFileExW},
};
use zeroize::{Zeroize, Zeroizing};

pub(super) const SECURE_STORAGE_BACKEND: u32 = 1;
pub(super) const CAPABILITY_FLAGS: u64 = KEY_SLOTS_CAPABILITY | BACKGROUND_ACCESS_CAPABILITY;

const SLOT_MAGIC: [u8; 8] = *b"KELVKS01";
const SLOT_HEADER_SIZE: usize = SLOT_MAGIC.len() + size_of::<u32>();
// DPAPI 包装 32 字节密钥的结果远小于此上限；限制读取量可阻止损坏文件触发无界分配。
const MAX_PROTECTED_KEY_SIZE: usize = 64 * 1024;
const MAX_SLOT_FILE_SIZE: usize = SLOT_HEADER_SIZE + MAX_PROTECTED_KEY_SIZE;
const TEMP_FILE_ATTEMPTS: usize = 16;

pub(super) fn create_slot(slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<LocalKey, KelivoStatus> {
    default_store()?.create_slot(slot_id)
}

pub(super) fn open_slot(slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<LocalKey, KelivoStatus> {
    default_store()?.open_slot(slot_id)
}

pub(super) fn fill_random(output: &mut [u8]) -> Result<(), KelivoStatus> {
    if output.is_empty() {
        return Ok(());
    }
    let output_length =
        u32::try_from(output.len()).map_err(|_| KelivoStatus::RandomSourceFailure)?;
    let status = unsafe {
        BCryptGenRandom(
            ptr::null_mut(),
            output.as_mut_ptr(),
            output_length,
            BCRYPT_USE_SYSTEM_PREFERRED_RNG,
        )
    };
    if status == 0 {
        Ok(())
    } else {
        Err(KelivoStatus::RandomSourceFailure)
    }
}

fn default_store() -> Result<SlotStore, KelivoStatus> {
    let local_app_data = env::var_os("LOCALAPPDATA")
        .filter(|value| !value.is_empty())
        .ok_or(KelivoStatus::SecureStorageUnavailable)?;
    let local_app_data = PathBuf::from(local_app_data);
    if !local_app_data.is_absolute() {
        return Err(KelivoStatus::SecureStorageUnavailable);
    }

    Ok(SlotStore::new(
        local_app_data
            .join("Kelivo")
            .join("secure-core")
            .join("v1")
            .join("slots"),
    ))
}

struct SlotStore {
    root: PathBuf,
}

impl SlotStore {
    fn new(root: PathBuf) -> Self {
        Self { root }
    }

    fn create_slot(&self, slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<LocalKey, KelivoStatus> {
        fs::create_dir_all(&self.root).map_err(|_| KelivoStatus::IoFailure)?;
        let slot_path = self.slot_path(slot_id);
        match slot_path.try_exists() {
            Ok(true) => return Err(KelivoStatus::SlotAlreadyExists),
            Ok(false) => {}
            Err(_) => return Err(KelivoStatus::IoFailure),
        }

        let mut key = Zeroizing::new(vec![0_u8; LOCAL_KEY_SIZE].into_boxed_slice());
        fill_random(&mut key[..])?;
        let protected_key = protect_key(&key[..], slot_id)?;
        let encoded = encode_slot_file(&protected_key)?;
        self.write_atomic(&slot_path, &encoded)?;
        Ok(key)
    }

    fn open_slot(&self, slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<LocalKey, KelivoStatus> {
        let encoded = read_slot_file(&self.slot_path(slot_id))?;
        let protected_key = decode_slot_file(&encoded)?;
        unprotect_key(protected_key, slot_id)
    }

    fn slot_path(&self, slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> PathBuf {
        self.root.join(format!("{}.bin", encode_hex(slot_id)))
    }

    fn write_atomic(&self, destination: &Path, contents: &[u8]) -> Result<(), KelivoStatus> {
        let (temporary_path, mut temporary_file) = self.create_temporary_file(destination)?;
        let write_result = temporary_file
            .write_all(contents)
            .and_then(|()| temporary_file.sync_all());
        drop(temporary_file);

        if write_result.is_err() {
            cleanup_temporary_file(&temporary_path)?;
            return Err(KelivoStatus::IoFailure);
        }

        match move_file_without_replacement(&temporary_path, destination) {
            Ok(()) => Ok(()),
            Err(status) => {
                cleanup_temporary_file(&temporary_path)?;
                Err(status)
            }
        }
    }

    fn create_temporary_file(&self, destination: &Path) -> Result<(PathBuf, File), KelivoStatus> {
        let destination_name = destination
            .file_name()
            .and_then(|value| value.to_str())
            .ok_or(KelivoStatus::InternalState)?;

        for _ in 0..TEMP_FILE_ATTEMPTS {
            let mut suffix = [0_u8; 16];
            fill_random(&mut suffix)?;
            let path = self
                .root
                .join(format!(".{destination_name}.{}.tmp", encode_hex(&suffix)));
            match OpenOptions::new().write(true).create_new(true).open(&path) {
                Ok(file) => return Ok((path, file)),
                Err(error) if error.kind() == ErrorKind::AlreadyExists => continue,
                Err(_) => return Err(KelivoStatus::IoFailure),
            }
        }

        Err(KelivoStatus::InternalState)
    }
}

fn cleanup_temporary_file(path: &Path) -> Result<(), KelivoStatus> {
    match fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == ErrorKind::NotFound => Ok(()),
        Err(_) => Err(KelivoStatus::IoFailure),
    }
}

fn move_file_without_replacement(source: &Path, destination: &Path) -> Result<(), KelivoStatus> {
    let source = path_to_wide(source)?;
    let destination = path_to_wide(destination)?;
    let moved = unsafe {
        MoveFileExW(
            source.as_ptr(),
            destination.as_ptr(),
            MOVEFILE_WRITE_THROUGH,
        )
    };
    if moved != 0 {
        return Ok(());
    }

    let error = unsafe { GetLastError() };
    if error == ERROR_ALREADY_EXISTS || error == ERROR_FILE_EXISTS {
        Err(KelivoStatus::SlotAlreadyExists)
    } else {
        Err(KelivoStatus::IoFailure)
    }
}

fn path_to_wide(path: &Path) -> Result<Vec<u16>, KelivoStatus> {
    let mut encoded: Vec<u16> = path.as_os_str().encode_wide().collect();
    if encoded.contains(&0) {
        return Err(KelivoStatus::IoFailure);
    }
    encoded.extend(iter::once(0));
    Ok(encoded)
}

fn read_slot_file(path: &Path) -> Result<Vec<u8>, KelivoStatus> {
    let file = match File::open(path) {
        Ok(file) => file,
        Err(error) if error.kind() == ErrorKind::NotFound => {
            return Err(KelivoStatus::SlotNotFound);
        }
        Err(_) => return Err(KelivoStatus::IoFailure),
    };
    let mut limited = file.take((MAX_SLOT_FILE_SIZE + 1) as u64);
    let mut encoded = Vec::with_capacity(MAX_SLOT_FILE_SIZE.min(1024));
    limited
        .read_to_end(&mut encoded)
        .map_err(|_| KelivoStatus::IoFailure)?;
    if encoded.len() > MAX_SLOT_FILE_SIZE {
        return Err(KelivoStatus::SlotDataInvalid);
    }
    Ok(encoded)
}

fn encode_slot_file(protected_key: &[u8]) -> Result<Vec<u8>, KelivoStatus> {
    if protected_key.is_empty() || protected_key.len() > MAX_PROTECTED_KEY_SIZE {
        return Err(KelivoStatus::SlotDataInvalid);
    }
    let protected_length =
        u32::try_from(protected_key.len()).map_err(|_| KelivoStatus::SlotDataInvalid)?;
    let mut encoded = Vec::with_capacity(SLOT_HEADER_SIZE + protected_key.len());
    encoded.extend_from_slice(&SLOT_MAGIC);
    encoded.extend_from_slice(&protected_length.to_le_bytes());
    encoded.extend_from_slice(protected_key);
    Ok(encoded)
}

fn decode_slot_file(encoded: &[u8]) -> Result<&[u8], KelivoStatus> {
    if encoded.len() < SLOT_HEADER_SIZE || encoded[..SLOT_MAGIC.len()] != SLOT_MAGIC {
        return Err(KelivoStatus::SlotDataInvalid);
    }
    let mut protected_length = [0_u8; size_of::<u32>()];
    protected_length.copy_from_slice(&encoded[SLOT_MAGIC.len()..SLOT_HEADER_SIZE]);
    let protected_length = u32::from_le_bytes(protected_length) as usize;
    if protected_length == 0
        || protected_length > MAX_PROTECTED_KEY_SIZE
        || encoded.len() != SLOT_HEADER_SIZE + protected_length
    {
        return Err(KelivoStatus::SlotDataInvalid);
    }
    Ok(&encoded[SLOT_HEADER_SIZE..])
}

fn protect_key(key: &[u8], slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<Vec<u8>, KelivoStatus> {
    let input = input_blob(key)?;
    let entropy = input_blob(slot_id)?;
    let mut output = LocalBlob::empty(false);
    let protected = unsafe {
        CryptProtectData(
            &input,
            ptr::null(),
            &entropy,
            ptr::null(),
            ptr::null(),
            CRYPTPROTECT_UI_FORBIDDEN,
            &mut output.blob,
        )
    };
    if protected == 0 {
        return Err(KelivoStatus::SecureStorageUnavailable);
    }
    let protected_key = output.bytes(KelivoStatus::SecureStorageUnavailable)?;
    if protected_key.is_empty() || protected_key.len() > MAX_PROTECTED_KEY_SIZE {
        return Err(KelivoStatus::SecureStorageUnavailable);
    }
    Ok(protected_key.to_vec())
}

fn unprotect_key(
    protected_key: &[u8],
    slot_id: &[u8; KEY_SLOT_ID_SIZE],
) -> Result<LocalKey, KelivoStatus> {
    let input = input_blob(protected_key)?;
    let entropy = input_blob(slot_id)?;
    let mut output = LocalBlob::empty(true);
    let unprotected = unsafe {
        CryptUnprotectData(
            &input,
            ptr::null_mut(),
            &entropy,
            ptr::null(),
            ptr::null(),
            CRYPTPROTECT_UI_FORBIDDEN,
            &mut output.blob,
        )
    };
    if unprotected == 0 {
        return Err(KelivoStatus::SlotUnwrapFailed);
    }
    let plaintext = output.bytes(KelivoStatus::SlotDataInvalid)?;
    if plaintext.len() != LOCAL_KEY_SIZE {
        return Err(KelivoStatus::SlotDataInvalid);
    }

    let mut key = Zeroizing::new(vec![0_u8; LOCAL_KEY_SIZE].into_boxed_slice());
    key[..].copy_from_slice(plaintext);
    Ok(key)
}

fn input_blob(input: &[u8]) -> Result<CRYPT_INTEGER_BLOB, KelivoStatus> {
    let length = u32::try_from(input.len()).map_err(|_| KelivoStatus::InternalState)?;
    Ok(CRYPT_INTEGER_BLOB {
        cbData: length,
        // Win32 将该字段声明为可变指针，但 protect/unprotect 的输入缓冲区契约不会写入。
        pbData: input.as_ptr().cast_mut(),
    })
}

struct LocalBlob {
    blob: CRYPT_INTEGER_BLOB,
    sensitive: bool,
}

impl LocalBlob {
    fn empty(sensitive: bool) -> Self {
        Self {
            blob: CRYPT_INTEGER_BLOB {
                cbData: 0,
                pbData: ptr::null_mut(),
            },
            sensitive,
        }
    }

    fn bytes(&self, invalid_status: KelivoStatus) -> Result<&[u8], KelivoStatus> {
        if self.blob.cbData == 0 || self.blob.pbData.is_null() {
            return Err(invalid_status);
        }
        Ok(unsafe { slice::from_raw_parts(self.blob.pbData, self.blob.cbData as usize) })
    }
}

impl Drop for LocalBlob {
    fn drop(&mut self) {
        if self.blob.pbData.is_null() {
            return;
        }
        if self.sensitive && self.blob.cbData > 0 {
            let plaintext =
                unsafe { slice::from_raw_parts_mut(self.blob.pbData, self.blob.cbData as usize) };
            plaintext.zeroize();
        }

        let remaining = unsafe { LocalFree(self.blob.pbData.cast()) };
        debug_assert!(remaining.is_null());
        self.blob.pbData = ptr::null_mut();
        self.blob.cbData = 0;
    }
}

fn encode_hex(input: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut encoded = String::with_capacity(input.len() * 2);
    for byte in input {
        encoded.push(HEX[(byte >> 4) as usize] as char);
        encoded.push(HEX[(byte & 0x0f) as usize] as char);
    }
    encoded
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_store(label: &str) -> (SlotStore, PathBuf) {
        let mut suffix = [0_u8; 16];
        fill_random(&mut suffix).expect("测试目录随机后缀应生成成功");
        let root = env::temp_dir().join(format!(
            "kelivo_secure_core_{label}_{}",
            encode_hex(&suffix)
        ));
        fs::create_dir(&root).expect("测试目录应创建成功");
        (SlotStore::new(root.clone()), root)
    }

    fn expect_status(result: Result<LocalKey, KelivoStatus>, expected: KelivoStatus) {
        match result {
            Ok(_) => panic!("操作意外成功，期望状态：{expected:?}"),
            Err(actual) => assert_eq!(actual, expected),
        }
    }

    #[test]
    fn dpapi_slot_round_trips_without_plaintext_and_binds_slot_id() {
        let (store, root) = create_test_store("round_trip");
        let first_id = [0x11; KEY_SLOT_ID_SIZE];
        let second_id = [0x22; KEY_SLOT_ID_SIZE];

        let created = store.create_slot(&first_id).expect("DPAPI 槽位应创建成功");
        let encoded = fs::read(store.slot_path(&first_id)).expect("槽位密文应可读取");
        assert!(
            !encoded
                .windows(LOCAL_KEY_SIZE)
                .any(|window| window == &created[..])
        );
        let opened = store.open_slot(&first_id).expect("DPAPI 槽位应可重开");
        assert_eq!(&created[..], &opened[..]);

        fs::copy(store.slot_path(&first_id), store.slot_path(&second_id))
            .expect("测试密文应可复制到另一槽位");
        expect_status(store.open_slot(&second_id), KelivoStatus::SlotUnwrapFailed);

        fs::remove_dir_all(root).expect("测试目录应清理成功");
    }

    #[test]
    fn duplicate_and_missing_slots_fail_without_overwrite() {
        let (store, root) = create_test_store("duplicates");
        let slot_id = [0x33; KEY_SLOT_ID_SIZE];
        let missing_id = [0x44; KEY_SLOT_ID_SIZE];

        let _key = store.create_slot(&slot_id).expect("首个槽位应创建成功");
        let before = fs::read(store.slot_path(&slot_id)).expect("原槽位应可读取");
        expect_status(store.create_slot(&slot_id), KelivoStatus::SlotAlreadyExists);
        let after = fs::read(store.slot_path(&slot_id)).expect("原槽位应保持可读");
        assert_eq!(after, before);
        expect_status(store.open_slot(&missing_id), KelivoStatus::SlotNotFound);

        fs::remove_dir_all(root).expect("测试目录应清理成功");
    }

    #[test]
    fn malformed_slot_files_are_rejected_with_bounded_reads() {
        let (store, root) = create_test_store("malformed");
        let slot_id = [0x55; KEY_SLOT_ID_SIZE];
        let slot_path = store.slot_path(&slot_id);

        fs::write(&slot_path, b"short").expect("截断样本应写入成功");
        expect_status(store.open_slot(&slot_id), KelivoStatus::SlotDataInvalid);

        let mut wrong_length = Vec::from(SLOT_MAGIC);
        wrong_length.extend_from_slice(&8_u32.to_le_bytes());
        wrong_length.push(1);
        fs::write(&slot_path, wrong_length).expect("长度错误样本应写入成功");
        expect_status(store.open_slot(&slot_id), KelivoStatus::SlotDataInvalid);

        fs::write(&slot_path, vec![0_u8; MAX_SLOT_FILE_SIZE + 1]).expect("超长样本应写入成功");
        expect_status(store.open_slot(&slot_id), KelivoStatus::SlotDataInvalid);

        fs::remove_dir_all(root).expect("测试目录应清理成功");
    }
}
