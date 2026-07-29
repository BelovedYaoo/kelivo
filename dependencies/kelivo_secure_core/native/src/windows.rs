use super::{
    BACKGROUND_ACCESS_CAPABILITY, KEY_SLOT_ID_SIZE, KEY_SLOTS_CAPABILITY, KelivoStatus,
    LOCAL_KEY_SIZE, LocalKey, RECORD_ENVELOPES_CAPABILITY, SQLCIPHER_DATABASE_ATTACH_CAPABILITY,
    SQLCIPHER_KEY_APPLICATION_CAPABILITY,
    slot_store_name::{SlotStoreEntryKind, classify_slot_store_entry},
};
use core::mem::size_of;
#[cfg(test)]
use std::{
    env,
    io::ErrorKind,
    sync::{
        MutexGuard,
        atomic::{AtomicUsize, Ordering},
    },
};
use std::{
    ffi::{OsStr, OsString},
    fs::{File, OpenOptions},
    io::{Read, Write},
    os::windows::{
        ffi::{OsStrExt, OsStringExt},
        fs::{MetadataExt, OpenOptionsExt},
        io::{AsRawHandle, FromRawHandle},
    },
    path::{Component, Path, PathBuf, Prefix},
    ptr, slice,
};
#[cfg(any(test, feature = "test-store-support"))]
use std::{
    fs,
    sync::{Mutex, OnceLock},
};
#[cfg(feature = "test-store-support")]
use windows_sys::Win32::Storage::FileSystem::GetTempPathW;
#[cfg(all(not(test), not(feature = "test-store-support")))]
use windows_sys::Win32::{
    System::Com::CoTaskMemFree,
    UI::Shell::{FOLDERID_LocalAppData, KF_FLAG_DEFAULT, SHGetKnownFolderPath},
};
use windows_sys::{
    Wdk::{
        Foundation::OBJECT_ATTRIBUTES,
        Storage::FileSystem::{
            FILE_BOTH_DIR_INFORMATION, FILE_CREATE, FILE_DIRECTORY_FILE, FILE_NON_DIRECTORY_FILE,
            FILE_OPEN, FILE_OPEN_IF, FILE_OPEN_REPARSE_POINT, FILE_RENAME_INFORMATION,
            FILE_RENAME_INFORMATION_0, FILE_SYNCHRONOUS_IO_NONALERT, FileBothDirectoryInformation,
            FileRenameInformation, NtCreateFile, NtQueryDirectoryFile, NtSetInformationFile,
        },
    },
    Win32::{
        Foundation::{
            HANDLE, INVALID_HANDLE_VALUE, LocalFree, OBJ_CASE_INSENSITIVE, OBJ_DONT_REPARSE,
            STATUS_NO_MORE_FILES, STATUS_OBJECT_NAME_COLLISION, STATUS_OBJECT_NAME_NOT_FOUND,
            STATUS_OBJECT_PATH_NOT_FOUND, UNICODE_STRING,
        },
        Security::Cryptography::{
            BCRYPT_USE_SYSTEM_PREFERRED_RNG, BCryptGenRandom, CRYPT_INTEGER_BLOB,
            CRYPTPROTECT_UI_FORBIDDEN, CryptProtectData, CryptUnprotectData,
        },
        Storage::FileSystem::{
            DELETE, FILE_ATTRIBUTE_DIRECTORY, FILE_ATTRIBUTE_REPARSE_POINT, FILE_DISPOSITION_INFO,
            FILE_FLAG_BACKUP_SEMANTICS, FILE_FLAG_OPEN_REPARSE_POINT, FILE_LIST_DIRECTORY,
            FILE_READ_ATTRIBUTES, FILE_READ_DATA, FILE_SHARE_DELETE, FILE_SHARE_READ,
            FILE_SHARE_WRITE, FILE_TRAVERSE, FILE_WRITE_DATA, FileDispositionInfo,
            LOCKFILE_EXCLUSIVE_LOCK, LockFileEx, SYNCHRONIZE, SetFileInformationByHandle,
            UnlockFileEx,
        },
        System::IO::{IO_STATUS_BLOCK, OVERLAPPED},
    },
};
use zeroize::{Zeroize, Zeroizing};

pub(super) const SECURE_STORAGE_BACKEND: u32 = 1;
pub(super) const CAPABILITY_FLAGS: u64 = KEY_SLOTS_CAPABILITY
    | BACKGROUND_ACCESS_CAPABILITY
    | RECORD_ENVELOPES_CAPABILITY
    | SQLCIPHER_KEY_APPLICATION_CAPABILITY
    | SQLCIPHER_DATABASE_ATTACH_CAPABILITY;

const SLOT_MAGIC: [u8; 8] = *b"KELVKS01";
const SLOT_HEADER_SIZE: usize = SLOT_MAGIC.len() + size_of::<u32>();
// DPAPI 包装 32 字节密钥的结果远小于此上限；限制读取量可阻止损坏文件触发无界分配。
const MAX_PROTECTED_KEY_SIZE: usize = 64 * 1024;
const MAX_SLOT_FILE_SIZE: usize = SLOT_HEADER_SIZE + MAX_PROTECTED_KEY_SIZE;
const TEMP_FILE_ATTEMPTS: usize = 16;
const DIRECTORY_QUERY_BUFFER_SIZE: usize = 64 * 1024;

pub(super) fn create_slot(slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<LocalKey, KelivoStatus> {
    default_store()?.create_slot(slot_id)
}

pub(super) fn open_slot(slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<LocalKey, KelivoStatus> {
    default_store()?.open_slot(slot_id)
}

pub(super) fn delete_slot(slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<(), KelivoStatus> {
    default_store()?.delete_slot(slot_id)
}

pub(super) fn delete_all_slots() -> Result<(), KelivoStatus> {
    default_store()?.delete_all_slots()
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

#[cfg(all(not(test), not(feature = "test-store-support")))]
fn production_store_root() -> Result<PathBuf, KelivoStatus> {
    let folder_id = FOLDERID_LocalAppData;
    let mut raw_path = ptr::null_mut();
    let status = unsafe {
        SHGetKnownFolderPath(
            &raw const folder_id,
            KF_FLAG_DEFAULT as u32,
            ptr::null_mut(),
            &mut raw_path,
        )
    };
    if status < 0 || raw_path.is_null() {
        return Err(KelivoStatus::SecureStorageUnavailable);
    }
    let raw_path = KnownFolderPath(raw_path);
    let mut length = 0_usize;
    while unsafe { *raw_path.0.add(length) } != 0 {
        length = length
            .checked_add(1)
            .filter(|value| *value <= 32_767)
            .ok_or(KelivoStatus::SecureStorageUnavailable)?;
    }
    let local_app_data = PathBuf::from(OsString::from_wide(unsafe {
        slice::from_raw_parts(raw_path.0, length)
    }));
    if !local_app_data.is_absolute() {
        return Err(KelivoStatus::SecureStorageUnavailable);
    }

    Ok(local_app_data
        .join("Kelivo")
        .join("secure-core")
        .join("v1")
        .join("slots"))
}

#[cfg(all(not(test), not(feature = "test-store-support")))]
struct KnownFolderPath(*mut u16);

#[cfg(all(not(test), not(feature = "test-store-support")))]
impl Drop for KnownFolderPath {
    fn drop(&mut self) {
        unsafe { CoTaskMemFree(self.0.cast()) };
    }
}

#[cfg(test)]
fn production_store_root() -> Result<PathBuf, KelivoStatus> {
    production_store_resolution_attempts().fetch_add(1, Ordering::SeqCst);
    Err(KelivoStatus::InternalState)
}

#[cfg(test)]
fn production_store_resolution_attempts() -> &'static AtomicUsize {
    static ATTEMPTS: AtomicUsize = AtomicUsize::new(0);
    &ATTEMPTS
}

#[cfg(all(not(test), not(feature = "test-store-support")))]
fn default_store() -> Result<SlotStore, KelivoStatus> {
    Ok(SlotStore::new(production_store_root()?))
}

#[cfg(all(test, not(feature = "test-store-support")))]
fn default_store() -> Result<SlotStore, KelivoStatus> {
    // 测试产物不得继承生产根；遗漏显式作用域时必须失败，不能便利性回退。
    let root = test_store_root()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?
        .clone()
        .ok_or(KelivoStatus::InternalState)?;
    let temporary_root = env::temp_dir()
        .canonicalize()
        .map_err(|_| KelivoStatus::InternalState)?;
    let canonical_root = root
        .canonicalize()
        .map_err(|_| KelivoStatus::InternalState)?;
    if !canonical_root.starts_with(&temporary_root) {
        return Err(KelivoStatus::InternalState);
    }
    Ok(SlotStore::new(canonical_root))
}

#[cfg(feature = "test-store-support")]
fn default_store() -> Result<SlotStore, KelivoStatus> {
    let root = test_store_state()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?
        .as_ref()
        .map(|active| active.root.clone())
        .ok_or(KelivoStatus::InternalState)?;
    Ok(SlotStore::new(root))
}

#[cfg(feature = "test-store-support")]
struct ActiveTestStore {
    scope: u64,
    root: PathBuf,
    temporary_root: PathBuf,
}

#[cfg(feature = "test-store-support")]
fn test_store_state() -> &'static Mutex<Option<ActiveTestStore>> {
    static STATE: OnceLock<Mutex<Option<ActiveTestStore>>> = OnceLock::new();
    STATE.get_or_init(|| Mutex::new(None))
}

#[cfg(feature = "test-store-support")]
pub(super) fn open_test_store_scope() -> Result<u64, KelivoStatus> {
    register_test_store_exit_cleanup()?;
    let mut state = test_store_state()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;
    if state.is_some() {
        return Err(KelivoStatus::InternalState);
    }
    let temporary_root = canonical_temporary_root()?;
    let root = create_random_test_store_root(&temporary_root)?;
    let scope = random_test_scope()?;
    *state = Some(ActiveTestStore {
        scope,
        root,
        temporary_root,
    });
    Ok(scope)
}

#[cfg(feature = "test-store-support")]
pub(super) fn close_test_store_scope(scope: u64) -> Result<(), KelivoStatus> {
    let active = {
        let mut state = test_store_state()
            .lock()
            .map_err(|_| KelivoStatus::InternalState)?;
        if state.as_ref().map(|active| active.scope) != Some(scope) {
            return Err(KelivoStatus::InvalidArgument);
        }
        state.take().ok_or(KelivoStatus::InternalState)?
    };
    match cleanup_test_store(&active) {
        Ok(()) => Ok(()),
        Err(status) => {
            let mut state = test_store_state()
                .lock()
                .map_err(|_| KelivoStatus::InternalState)?;
            if state.is_none() {
                *state = Some(active);
            }
            Err(status)
        }
    }
}

#[cfg(feature = "test-store-support")]
fn canonical_temporary_root() -> Result<PathBuf, KelivoStatus> {
    let mut buffer = vec![0_u16; 32_768];
    let length = unsafe {
        GetTempPathW(
            u32::try_from(buffer.len()).map_err(|_| KelivoStatus::InternalState)?,
            buffer.as_mut_ptr(),
        )
    };
    let length = usize::try_from(length).map_err(|_| KelivoStatus::InternalState)?;
    if length == 0 || length >= buffer.len() {
        return Err(KelivoStatus::SecureStorageUnavailable);
    }
    let path = PathBuf::from(OsString::from_wide(&buffer[..length]));
    let canonical = fs::canonicalize(path).map_err(|_| KelivoStatus::IoFailure)?;
    split_disk_path(&canonical)?;
    Ok(canonical)
}

#[cfg(feature = "test-store-support")]
fn create_random_test_store_root(temporary_root: &Path) -> Result<PathBuf, KelivoStatus> {
    for _ in 0..TEMP_FILE_ATTEMPTS {
        let mut suffix = [0_u8; 16];
        fill_random(&mut suffix)?;
        let root = temporary_root.join(format!(
            "kelivo_secure_core_dart_test_{}",
            encode_hex(&suffix)
        ));
        match fs::create_dir(&root) {
            Ok(()) => {
                let canonical = fs::canonicalize(&root).map_err(|_| KelivoStatus::IoFailure)?;
                if canonical.parent() != Some(temporary_root) {
                    return Err(KelivoStatus::InternalState);
                }
                return Ok(canonical);
            }
            Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(_) => return Err(KelivoStatus::IoFailure),
        }
    }
    Err(KelivoStatus::InternalState)
}

#[cfg(feature = "test-store-support")]
fn random_test_scope() -> Result<u64, KelivoStatus> {
    loop {
        let mut encoded = [0_u8; size_of::<u64>()];
        fill_random(&mut encoded)?;
        let scope = u64::from_le_bytes(encoded) & ((1_u64 << 63) - 1);
        if scope != 0 {
            return Ok(scope);
        }
    }
}

#[cfg(feature = "test-store-support")]
fn cleanup_test_store(active: &ActiveTestStore) -> Result<(), KelivoStatus> {
    let canonical = fs::canonicalize(&active.root).map_err(|_| KelivoStatus::IoFailure)?;
    if canonical != active.root || canonical.parent() != Some(active.temporary_root.as_path()) {
        return Err(KelivoStatus::InternalState);
    }
    let store = SlotStore::new(canonical.clone());
    store.delete_all_slots()?;
    let directory = open_directory_chain(&canonical)?.ok_or(KelivoStatus::InternalState)?;
    delete_slot_file(
        &directory,
        OsStr::new(super::slot_store_name::NAMESPACE_LOCK_FILE_NAME),
    )?;
    if !enumerate_directory_entries(&directory)?.is_empty() {
        return Err(KelivoStatus::IoFailure);
    }
    drop(directory);
    fs::remove_dir(canonical).map_err(|_| KelivoStatus::IoFailure)
}

#[cfg(feature = "test-store-support")]
fn register_test_store_exit_cleanup() -> Result<(), KelivoStatus> {
    static REGISTERED: OnceLock<bool> = OnceLock::new();
    if *REGISTERED.get_or_init(|| unsafe { libc::atexit(test_store_exit_cleanup) == 0 }) {
        Ok(())
    } else {
        Err(KelivoStatus::InternalState)
    }
}

#[cfg(feature = "test-store-support")]
extern "C" fn test_store_exit_cleanup() {
    let active = test_store_state()
        .lock()
        .ok()
        .and_then(|mut state| state.take());
    if let Some(active) = active {
        let _ = cleanup_test_store(&active);
    }
}

#[cfg(test)]
fn test_store_root() -> &'static Mutex<Option<PathBuf>> {
    static ROOT: OnceLock<Mutex<Option<PathBuf>>> = OnceLock::new();
    ROOT.get_or_init(|| Mutex::new(None))
}

#[cfg(test)]
fn test_store_serialization_lock() -> &'static Mutex<()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    LOCK.get_or_init(|| Mutex::new(()))
}

#[cfg(test)]
pub(super) struct TestStoreScope {
    root: PathBuf,
    _serialization_guard: MutexGuard<'static, ()>,
}

#[cfg(test)]
impl TestStoreScope {
    pub(super) fn enter(label: &str) -> Self {
        let serialization_guard = test_store_serialization_lock()
            .lock()
            .expect("测试槽位作用域串行锁不得中毒");
        let temporary_root = env::temp_dir()
            .canonicalize()
            .expect("系统临时目录必须可解析");
        let root = create_scoped_test_store_root(&temporary_root, label);
        let mut active_root = test_store_root().lock().expect("测试槽位根状态不得中毒");
        assert!(active_root.is_none(), "同一进程只能激活一个测试槽位根");
        *active_root = Some(root.clone());
        drop(active_root);
        Self {
            root,
            _serialization_guard: serialization_guard,
        }
    }
}

#[cfg(test)]
impl Drop for TestStoreScope {
    fn drop(&mut self) {
        let mut active_root = test_store_root().lock().expect("测试槽位根状态不得中毒");
        assert_eq!(active_root.as_ref(), Some(&self.root));
        *active_root = None;
        drop(active_root);
        let temporary_root = env::temp_dir()
            .canonicalize()
            .expect("系统临时目录必须可复查");
        let canonical_root = self.root.canonicalize().expect("测试槽位根必须可复查");
        assert!(
            canonical_root.starts_with(&temporary_root),
            "只允许清理系统临时目录内的测试槽位根"
        );
        fs::remove_dir_all(&self.root).expect("测试槽位临时目录必须可清理");
    }
}

#[cfg(test)]
fn create_scoped_test_store_root(temporary_root: &Path, label: &str) -> PathBuf {
    assert!(
        !label.is_empty()
            && label
                .bytes()
                .all(|byte| byte.is_ascii_lowercase() || byte == b'_'),
        "测试槽位标签只能使用小写 ASCII 与下划线"
    );
    for _ in 0..TEMP_FILE_ATTEMPTS {
        let mut suffix = [0_u8; 16];
        fill_random(&mut suffix).expect("测试槽位目录随机后缀应生成成功");
        let root = temporary_root.join(format!(
            "kelivo_secure_core_c_abi_{label}_{}",
            encode_hex(&suffix)
        ));
        match fs::create_dir(&root) {
            Ok(()) => {
                let canonical_root = root.canonicalize().expect("测试槽位根必须可解析");
                assert!(
                    canonical_root.starts_with(temporary_root),
                    "测试槽位根必须位于系统临时目录"
                );
                return canonical_root;
            }
            Err(error) if error.kind() == ErrorKind::AlreadyExists => continue,
            Err(error) => panic!("测试槽位根创建失败：{error}"),
        }
    }
    panic!("无法分配唯一测试槽位根")
}

#[cfg(test)]
pub(super) struct ProductionStoreAccessCanary;

#[cfg(test)]
impl ProductionStoreAccessCanary {
    pub(super) fn capture() -> Self {
        // 保留测试哨兵函数的静态可达性，但绝不调用它或解析生产路径。
        let _forbidden_resolver: fn() -> Result<PathBuf, KelivoStatus> = production_store_root;
        assert_eq!(
            production_store_resolution_attempts().load(Ordering::SeqCst),
            0,
            "任何测试开始前都不得尝试解析生产槽位根"
        );
        Self
    }

    pub(super) fn assert_no_attempt(self) {
        assert_eq!(
            production_store_resolution_attempts().load(Ordering::SeqCst),
            0,
            "C ABI 测试不得尝试解析生产槽位根"
        );
    }
}

struct SlotStore {
    root: PathBuf,
}

impl SlotStore {
    fn new(root: PathBuf) -> Self {
        Self { root }
    }

    fn create_slot(&self, slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<LocalKey, KelivoStatus> {
        let directory = ensure_directory_chain(&self.root)?;
        let _namespace_lock = NamespaceLockGuard::acquire(&directory)?;
        let slot_name = Self::slot_name(slot_id);
        match open_relative_file(
            &directory,
            OsStr::new(&slot_name),
            FILE_READ_ATTRIBUTES | SYNCHRONIZE,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            FILE_OPEN,
        )? {
            RelativeOpenResult::Opened(_) => return Err(KelivoStatus::SlotAlreadyExists),
            RelativeOpenResult::Missing => {}
            RelativeOpenResult::Collision => return Err(KelivoStatus::InternalState),
        }

        let mut key = Zeroizing::new(vec![0_u8; LOCAL_KEY_SIZE].into_boxed_slice());
        fill_random(&mut key[..])?;
        let protected_key = protect_key(&key[..], slot_id)?;
        let encoded = encode_slot_file(&protected_key)?;
        self.write_atomic(&directory, OsStr::new(&slot_name), &encoded)?;
        Ok(key)
    }

    fn open_slot(&self, slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<LocalKey, KelivoStatus> {
        let Some(directory) = open_directory_chain(&self.root)? else {
            return Err(KelivoStatus::SlotNotFound);
        };
        let _namespace_lock = NamespaceLockGuard::acquire(&directory)?;
        let slot_name = Self::slot_name(slot_id);
        let encoded = read_slot_file(&directory, OsStr::new(&slot_name))?;
        let protected_key = decode_slot_file(&encoded)?;
        unprotect_key(protected_key, slot_id)
    }

    fn delete_slot(&self, slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<(), KelivoStatus> {
        // DPAPI 没有独立的槽位对象；包装密文文件就是该槽唯一的持久材料。
        let Some(directory) = open_directory_chain(&self.root)? else {
            return Ok(());
        };
        let _namespace_lock = NamespaceLockGuard::acquire(&directory)?;
        let slot_name = Self::slot_name(slot_id);
        delete_slot_file(&directory, OsStr::new(&slot_name))
    }

    fn delete_all_slots(&self) -> Result<(), KelivoStatus> {
        let Some(directory) = open_directory_chain(&self.root)? else {
            return Ok(());
        };
        let _namespace_lock = NamespaceLockGuard::acquire(&directory)?;
        let entries = enumerate_directory_entries(&directory)?;
        let mut deletable_names = Vec::new();
        for entry in entries {
            match validate_namespace_entry(&entry)? {
                SlotStoreEntryKind::Slot | SlotStoreEntryKind::Temporary => {
                    deletable_names.push(entry.name);
                }
                SlotStoreEntryKind::NamespaceLock => {}
                SlotStoreEntryKind::Unknown => return Err(KelivoStatus::IoFailure),
            }
        }
        for name in deletable_names {
            delete_slot_file(&directory, &name)?;
        }
        for entry in enumerate_directory_entries(&directory)? {
            if validate_namespace_entry(&entry)? != SlotStoreEntryKind::NamespaceLock {
                return Err(KelivoStatus::IoFailure);
            }
        }
        Ok(())
    }

    fn slot_name(slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> String {
        format!("{}.bin", encode_hex(slot_id))
    }

    #[cfg(test)]
    fn slot_path(&self, slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> PathBuf {
        self.root.join(Self::slot_name(slot_id))
    }

    fn write_atomic(
        &self,
        directory: &DirectoryChainGuard,
        destination_name: &OsStr,
        contents: &[u8],
    ) -> Result<(), KelivoStatus> {
        let mut temporary_file = self.create_temporary_file(directory, destination_name)?;
        let write_result = temporary_file
            .write_all(contents)
            .and_then(|()| temporary_file.sync_all());

        if write_result.is_err() {
            delete_open_file(&temporary_file)?;
            return Err(KelivoStatus::IoFailure);
        }

        match rename_open_file(&temporary_file, directory, destination_name) {
            Ok(()) => Ok(()),
            Err(status) => {
                delete_open_file(&temporary_file)?;
                Err(status)
            }
        }
    }

    fn create_temporary_file(
        &self,
        directory: &DirectoryChainGuard,
        destination_name: &OsStr,
    ) -> Result<File, KelivoStatus> {
        let destination_name = destination_name
            .to_str()
            .ok_or(KelivoStatus::InternalState)?;

        for _ in 0..TEMP_FILE_ATTEMPTS {
            let mut suffix = [0_u8; 16];
            fill_random(&mut suffix)?;
            let temporary_name = format!(".{destination_name}.{}.tmp", encode_hex(&suffix));
            match open_relative_file(
                directory,
                OsStr::new(&temporary_name),
                FILE_WRITE_DATA | FILE_READ_ATTRIBUTES | DELETE | SYNCHRONIZE,
                FILE_SHARE_READ,
                FILE_CREATE,
            )? {
                RelativeOpenResult::Opened(file) => return Ok(file),
                RelativeOpenResult::Collision => continue,
                RelativeOpenResult::Missing => return Err(KelivoStatus::InternalState),
            }
        }

        Err(KelivoStatus::InternalState)
    }
}

struct DirectoryChainGuard {
    directory: File,
}

struct NamespaceLockGuard {
    file: File,
    overlapped: OVERLAPPED,
}

impl NamespaceLockGuard {
    fn acquire(directory: &DirectoryChainGuard) -> Result<Self, KelivoStatus> {
        let file = match open_relative_file(
            directory,
            OsStr::new(super::slot_store_name::NAMESPACE_LOCK_FILE_NAME),
            FILE_READ_DATA | FILE_WRITE_DATA | FILE_READ_ATTRIBUTES | SYNCHRONIZE,
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            FILE_OPEN_IF,
        )? {
            RelativeOpenResult::Opened(file) => file,
            RelativeOpenResult::Missing | RelativeOpenResult::Collision => {
                return Err(KelivoStatus::IoFailure);
            }
        };
        let mut overlapped = OVERLAPPED::default();
        let locked = unsafe {
            LockFileEx(
                file.as_raw_handle(),
                LOCKFILE_EXCLUSIVE_LOCK,
                0,
                u32::MAX,
                u32::MAX,
                &mut overlapped,
            )
        };
        if locked == 0 {
            return Err(KelivoStatus::IoFailure);
        }
        Ok(Self { file, overlapped })
    }
}

impl Drop for NamespaceLockGuard {
    fn drop(&mut self) {
        unsafe {
            UnlockFileEx(
                self.file.as_raw_handle(),
                0,
                u32::MAX,
                u32::MAX,
                &mut self.overlapped,
            )
        };
    }
}

fn ensure_directory_chain(path: &Path) -> Result<DirectoryChainGuard, KelivoStatus> {
    open_directory_chain_with_mode(path, FILE_OPEN_IF)?.ok_or(KelivoStatus::IoFailure)
}

fn open_directory_chain(path: &Path) -> Result<Option<DirectoryChainGuard>, KelivoStatus> {
    open_directory_chain_with_mode(path, FILE_OPEN)
}

fn open_directory_chain_with_mode(
    path: &Path,
    disposition: u32,
) -> Result<Option<DirectoryChainGuard>, KelivoStatus> {
    let (volume_root, components) = split_disk_path(path)?;
    let mut directory = open_volume_root(&volume_root)?;
    for component in components {
        match nt_create_relative(
            &directory,
            &component,
            FILE_LIST_DIRECTORY | FILE_READ_ATTRIBUTES | FILE_TRAVERSE | SYNCHRONIZE,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            disposition,
            FILE_DIRECTORY_FILE | FILE_OPEN_REPARSE_POINT | FILE_SYNCHRONOUS_IO_NONALERT,
        )? {
            RelativeOpenResult::Opened(child) => {
                validate_directory_handle(&child)?;
                directory = child;
            }
            RelativeOpenResult::Missing => return Ok(None),
            RelativeOpenResult::Collision => return Err(KelivoStatus::IoFailure),
        }
    }
    Ok(Some(DirectoryChainGuard { directory }))
}

fn split_disk_path(path: &Path) -> Result<(PathBuf, Vec<OsString>), KelivoStatus> {
    // 句柄相对重命名不支持网络根；安全槽必须落在可由本机内核完整约束的本地卷。
    let mut components = path.components();
    let prefix = match components.next() {
        Some(Component::Prefix(prefix))
            if matches!(prefix.kind(), Prefix::Disk(_) | Prefix::VerbatimDisk(_)) =>
        {
            prefix
        }
        _ => return Err(KelivoStatus::IoFailure),
    };
    let root = match components.next() {
        Some(Component::RootDir) => Component::RootDir,
        _ => return Err(KelivoStatus::IoFailure),
    };
    let mut volume_root = PathBuf::new();
    volume_root.push(prefix.as_os_str());
    volume_root.push(root.as_os_str());

    let mut names = Vec::new();
    for component in components {
        match component {
            Component::Normal(name) => names.push(name.to_os_string()),
            Component::Prefix(_)
            | Component::RootDir
            | Component::CurDir
            | Component::ParentDir => {
                return Err(KelivoStatus::IoFailure);
            }
        }
    }
    Ok((volume_root, names))
}

fn open_volume_root(path: &Path) -> Result<File, KelivoStatus> {
    let file = match OpenOptions::new()
        .access_mode(FILE_READ_ATTRIBUTES | FILE_TRAVERSE)
        .share_mode(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE)
        .custom_flags(FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT)
        .open(path)
    {
        Ok(file) => file,
        Err(_) => return Err(KelivoStatus::IoFailure),
    };
    validate_directory_handle(&file)?;
    Ok(file)
}

fn validate_directory_handle(file: &File) -> Result<(), KelivoStatus> {
    let attributes = file
        .metadata()
        .map_err(|_| KelivoStatus::IoFailure)?
        .file_attributes();
    validate_directory_attributes(attributes)?;
    Ok(())
}

enum RelativeOpenResult {
    Opened(File),
    Missing,
    Collision,
}

fn open_relative_file(
    directory: &DirectoryChainGuard,
    name: &OsStr,
    desired_access: u32,
    share_access: u32,
    disposition: u32,
) -> Result<RelativeOpenResult, KelivoStatus> {
    let result = nt_create_relative(
        &directory.directory,
        name,
        desired_access,
        share_access,
        disposition,
        FILE_NON_DIRECTORY_FILE | FILE_OPEN_REPARSE_POINT | FILE_SYNCHRONOUS_IO_NONALERT,
    )?;
    if let RelativeOpenResult::Opened(file) = &result {
        validate_slot_file_handle(file)?;
    }
    Ok(result)
}

fn nt_create_relative(
    parent: &File,
    name: &OsStr,
    desired_access: u32,
    share_access: u32,
    disposition: u32,
    create_options: u32,
) -> Result<RelativeOpenResult, KelivoStatus> {
    let mut encoded_name = encode_relative_name(name)?;
    let name_length = u16::try_from(encoded_name.len() * size_of::<u16>())
        .map_err(|_| KelivoStatus::IoFailure)?;
    let object_name = UNICODE_STRING {
        Length: name_length,
        MaximumLength: name_length,
        Buffer: encoded_name.as_mut_ptr(),
    };
    let object_attributes = OBJECT_ATTRIBUTES {
        Length: u32::try_from(size_of::<OBJECT_ATTRIBUTES>())
            .map_err(|_| KelivoStatus::InternalState)?,
        RootDirectory: parent.as_raw_handle(),
        ObjectName: &raw const object_name,
        Attributes: OBJ_CASE_INSENSITIVE | OBJ_DONT_REPARSE,
        SecurityDescriptor: ptr::null(),
        SecurityQualityOfService: ptr::null(),
    };
    let mut handle: HANDLE = ptr::null_mut();
    let mut io_status = IO_STATUS_BLOCK::default();
    let status = unsafe {
        NtCreateFile(
            &mut handle,
            desired_access,
            &object_attributes,
            &mut io_status,
            ptr::null(),
            0,
            share_access,
            disposition,
            create_options,
            ptr::null(),
            0,
        )
    };
    if status >= 0 {
        if handle.is_null() || handle == INVALID_HANDLE_VALUE {
            return Err(KelivoStatus::IoFailure);
        }
        let file = unsafe { File::from_raw_handle(handle) };
        return Ok(RelativeOpenResult::Opened(file));
    }
    if !handle.is_null() && handle != INVALID_HANDLE_VALUE {
        drop(unsafe { File::from_raw_handle(handle) });
    }
    match status {
        STATUS_OBJECT_NAME_NOT_FOUND | STATUS_OBJECT_PATH_NOT_FOUND => {
            Ok(RelativeOpenResult::Missing)
        }
        STATUS_OBJECT_NAME_COLLISION => Ok(RelativeOpenResult::Collision),
        _ => Err(KelivoStatus::IoFailure),
    }
}

fn encode_relative_name(name: &OsStr) -> Result<Vec<u16>, KelivoStatus> {
    let mut components = Path::new(name).components();
    if !matches!(components.next(), Some(Component::Normal(_))) || components.next().is_some() {
        return Err(KelivoStatus::IoFailure);
    }
    let encoded: Vec<u16> = name.encode_wide().collect();
    if encoded.is_empty() || encoded.contains(&0) {
        return Err(KelivoStatus::IoFailure);
    }
    Ok(encoded)
}

fn validate_slot_file_handle(file: &File) -> Result<(), KelivoStatus> {
    let attributes = file
        .metadata()
        .map_err(|_| KelivoStatus::IoFailure)?
        .file_attributes();
    validate_slot_file_attributes(attributes)
}

fn validate_directory_attributes(attributes: u32) -> Result<(), KelivoStatus> {
    if attributes & FILE_ATTRIBUTE_REPARSE_POINT != 0 || attributes & FILE_ATTRIBUTE_DIRECTORY == 0
    {
        return Err(KelivoStatus::IoFailure);
    }
    Ok(())
}

const MAX_RELATIVE_NAME_CODE_UNITS: usize = 255;

#[repr(C)]
struct RelativeRenameInfo {
    anonymous: FILE_RENAME_INFORMATION_0,
    root_directory: HANDLE,
    file_name_length: u32,
    file_name: [u16; MAX_RELATIVE_NAME_CODE_UNITS],
}

const _: () = {
    assert!(
        core::mem::offset_of!(RelativeRenameInfo, root_directory)
            == core::mem::offset_of!(FILE_RENAME_INFORMATION, RootDirectory)
    );
    assert!(
        core::mem::offset_of!(RelativeRenameInfo, file_name_length)
            == core::mem::offset_of!(FILE_RENAME_INFORMATION, FileNameLength)
    );
    assert!(
        core::mem::offset_of!(RelativeRenameInfo, file_name)
            == core::mem::offset_of!(FILE_RENAME_INFORMATION, FileName)
    );
};

fn rename_open_file(
    file: &File,
    destination_directory: &DirectoryChainGuard,
    destination_name: &OsStr,
) -> Result<(), KelivoStatus> {
    let encoded_name = encode_relative_name(destination_name)?;
    if encoded_name.len() > MAX_RELATIVE_NAME_CODE_UNITS {
        return Err(KelivoStatus::IoFailure);
    }
    let mut info = RelativeRenameInfo {
        anonymous: FILE_RENAME_INFORMATION_0 { Flags: 0 },
        root_directory: destination_directory.directory.as_raw_handle(),
        file_name_length: u32::try_from(encoded_name.len() * size_of::<u16>())
            .map_err(|_| KelivoStatus::IoFailure)?,
        file_name: [0; MAX_RELATIVE_NAME_CODE_UNITS],
    };
    info.file_name[..encoded_name.len()].copy_from_slice(&encoded_name);
    let buffer_size = core::mem::offset_of!(RelativeRenameInfo, file_name)
        .checked_add(encoded_name.len() * size_of::<u16>())
        .and_then(|value| u32::try_from(value).ok())
        .ok_or(KelivoStatus::InternalState)?;
    let mut io_status = IO_STATUS_BLOCK::default();
    let status = unsafe {
        NtSetInformationFile(
            file.as_raw_handle(),
            &mut io_status,
            (&raw const info).cast(),
            buffer_size,
            FileRenameInformation,
        )
    };
    if status >= 0 {
        return Ok(());
    }
    if status != STATUS_OBJECT_NAME_COLLISION {
        return Err(KelivoStatus::IoFailure);
    }
    match open_relative_file(
        destination_directory,
        destination_name,
        FILE_READ_ATTRIBUTES | SYNCHRONIZE,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        FILE_OPEN,
    )? {
        RelativeOpenResult::Opened(_) => Err(KelivoStatus::SlotAlreadyExists),
        RelativeOpenResult::Missing | RelativeOpenResult::Collision => Err(KelivoStatus::IoFailure),
    }
}

fn read_slot_file(directory: &DirectoryChainGuard, name: &OsStr) -> Result<Vec<u8>, KelivoStatus> {
    let file = match open_relative_file(
        directory,
        name,
        FILE_READ_DATA | FILE_READ_ATTRIBUTES | SYNCHRONIZE,
        FILE_SHARE_READ,
        FILE_OPEN,
    )? {
        RelativeOpenResult::Opened(file) => file,
        RelativeOpenResult::Missing => return Err(KelivoStatus::SlotNotFound),
        RelativeOpenResult::Collision => return Err(KelivoStatus::InternalState),
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

fn delete_slot_file(directory: &DirectoryChainGuard, name: &OsStr) -> Result<(), KelivoStatus> {
    let file = match open_relative_file(
        directory,
        name,
        DELETE | FILE_READ_ATTRIBUTES | SYNCHRONIZE,
        FILE_SHARE_READ,
        FILE_OPEN,
    )? {
        RelativeOpenResult::Opened(file) => file,
        RelativeOpenResult::Missing => return Ok(()),
        RelativeOpenResult::Collision => return Err(KelivoStatus::InternalState),
    };
    delete_open_file(&file)
}

fn delete_open_file(file: &File) -> Result<(), KelivoStatus> {
    let disposition = FILE_DISPOSITION_INFO { DeleteFile: true };
    let deleted = unsafe {
        SetFileInformationByHandle(
            file.as_raw_handle(),
            FileDispositionInfo,
            (&raw const disposition).cast(),
            u32::try_from(size_of::<FILE_DISPOSITION_INFO>())
                .map_err(|_| KelivoStatus::InternalState)?,
        )
    };
    if deleted == 0 {
        return Err(KelivoStatus::IoFailure);
    }
    Ok(())
}

fn validate_slot_file_attributes(attributes: u32) -> Result<(), KelivoStatus> {
    if attributes & FILE_ATTRIBUTE_REPARSE_POINT != 0 || attributes & FILE_ATTRIBUTE_DIRECTORY != 0
    {
        return Err(KelivoStatus::IoFailure);
    }
    Ok(())
}

struct DirectoryEntry {
    name: OsString,
    attributes: u32,
}

fn enumerate_directory_entries(
    directory: &DirectoryChainGuard,
) -> Result<Vec<DirectoryEntry>, KelivoStatus> {
    let word_count = DIRECTORY_QUERY_BUFFER_SIZE.div_ceil(size_of::<u64>());
    let mut buffer = vec![0_u64; word_count];
    let mut entries = Vec::new();
    let mut restart_scan = true;
    loop {
        let mut io_status = IO_STATUS_BLOCK::default();
        let status = unsafe {
            NtQueryDirectoryFile(
                directory.directory.as_raw_handle(),
                ptr::null_mut(),
                None,
                ptr::null(),
                &mut io_status,
                buffer.as_mut_ptr().cast(),
                u32::try_from(DIRECTORY_QUERY_BUFFER_SIZE)
                    .map_err(|_| KelivoStatus::InternalState)?,
                FileBothDirectoryInformation,
                false,
                ptr::null(),
                restart_scan,
            )
        };
        restart_scan = false;
        if status == STATUS_NO_MORE_FILES {
            break;
        }
        if status != 0
            || io_status.Information == 0
            || io_status.Information > DIRECTORY_QUERY_BUFFER_SIZE
        {
            return Err(KelivoStatus::IoFailure);
        }
        parse_directory_entries(buffer.as_ptr().cast(), io_status.Information, &mut entries)?;
    }
    Ok(entries)
}

fn parse_directory_entries(
    buffer: *const u8,
    buffer_length: usize,
    output: &mut Vec<DirectoryEntry>,
) -> Result<(), KelivoStatus> {
    let file_name_offset = core::mem::offset_of!(FILE_BOTH_DIR_INFORMATION, FileName);
    let fixed_entry_size = size_of::<FILE_BOTH_DIR_INFORMATION>();
    let mut offset = 0_usize;
    loop {
        let remaining = buffer_length
            .checked_sub(offset)
            .ok_or(KelivoStatus::IoFailure)?;
        if remaining < fixed_entry_size {
            return Err(KelivoStatus::IoFailure);
        }
        let information =
            unsafe { ptr::read_unaligned(buffer.add(offset).cast::<FILE_BOTH_DIR_INFORMATION>()) };
        let file_name_length =
            usize::try_from(information.FileNameLength).map_err(|_| KelivoStatus::IoFailure)?;
        if file_name_length % size_of::<u16>() != 0
            || file_name_length > remaining - file_name_offset
        {
            return Err(KelivoStatus::IoFailure);
        }
        let file_name_start = offset
            .checked_add(file_name_offset)
            .ok_or(KelivoStatus::IoFailure)?;
        let mut file_name = Vec::with_capacity(file_name_length / size_of::<u16>());
        for index in (0..file_name_length).step_by(size_of::<u16>()) {
            file_name.push(unsafe {
                ptr::read_unaligned(buffer.add(file_name_start + index).cast::<u16>())
            });
        }
        let name = OsString::from_wide(&file_name);
        if name != "." && name != ".." {
            output.push(DirectoryEntry {
                name,
                attributes: information.FileAttributes,
            });
        }

        if information.NextEntryOffset == 0 {
            break;
        }
        let next_offset =
            usize::try_from(information.NextEntryOffset).map_err(|_| KelivoStatus::IoFailure)?;
        let entry_payload_size = file_name_offset
            .checked_add(file_name_length)
            .ok_or(KelivoStatus::IoFailure)?;
        if next_offset < fixed_entry_size.max(entry_payload_size) || next_offset >= remaining {
            return Err(KelivoStatus::IoFailure);
        }
        offset = offset
            .checked_add(next_offset)
            .ok_or(KelivoStatus::IoFailure)?;
    }
    Ok(())
}

fn validate_namespace_entry(entry: &DirectoryEntry) -> Result<SlotStoreEntryKind, KelivoStatus> {
    validate_slot_file_attributes(entry.attributes)?;
    let name = entry.name.to_str().ok_or(KelivoStatus::IoFailure)?;
    Ok(classify_slot_store_entry(name))
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
    use std::{
        fs,
        os::windows::fs::symlink_file,
        process::Command,
        sync::mpsc,
        thread,
        time::{Duration, Instant},
    };

    const LOCK_CHILD_ROOT_ENV: &str = "KELIVO_TEST_NAMESPACE_LOCK_ROOT";
    const LOCK_CHILD_READY_ENV: &str = "KELIVO_TEST_NAMESPACE_LOCK_READY";
    const LOCK_CHILD_RELEASE_ENV: &str = "KELIVO_TEST_NAMESPACE_LOCK_RELEASE";

    #[test]
    fn native_test_default_store_requires_explicit_temporary_scope() {
        let _serialization_guard = test_store_serialization_lock()
            .lock()
            .expect("测试槽位作用域串行锁不得中毒");
        assert!(
            test_store_root()
                .lock()
                .expect("测试槽位根状态不得中毒")
                .is_none()
        );
        match default_store() {
            Ok(_) => panic!("测试态默认存储不得回落生产目录"),
            Err(status) => assert_eq!(status, KelivoStatus::InternalState),
        }
    }

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

    fn wait_for_marker(path: &Path, timeout: Duration) {
        let deadline = Instant::now() + timeout;
        while !path.exists() {
            assert!(Instant::now() < deadline, "等待子进程标记超时：{path:?}");
            thread::sleep(Duration::from_millis(10));
        }
    }

    #[test]
    fn namespace_lock_child_process() {
        let Some(root) = env::var_os(LOCK_CHILD_ROOT_ENV) else {
            return;
        };
        let ready = PathBuf::from(
            env::var_os(LOCK_CHILD_READY_ENV).expect("锁测试子进程必须收到就绪标记路径"),
        );
        let release = PathBuf::from(
            env::var_os(LOCK_CHILD_RELEASE_ENV).expect("锁测试子进程必须收到释放标记路径"),
        );
        let directory = ensure_directory_chain(Path::new(&root)).expect("子进程槽目录必须可固定");
        let _lock = NamespaceLockGuard::acquire(&directory).expect("子进程必须取得命名空间锁");
        fs::write(&ready, b"ready").expect("子进程就绪标记应写入成功");
        wait_for_marker(&release, Duration::from_secs(10));
    }

    #[test]
    fn all_slots_delete_waits_for_another_process_namespace_lock() {
        let (_unused_store, sandbox) = create_test_store("cross_process_lock");
        let slot_root = sandbox.join("slots");
        fs::create_dir(&slot_root).expect("跨进程锁测试槽目录应创建成功");
        let slot_name = format!("{}.bin", "ab".repeat(KEY_SLOT_ID_SIZE));
        fs::write(slot_root.join(&slot_name), b"test-slot").expect("测试槽文件应写入成功");
        let ready = sandbox.join("child-ready");
        let release = sandbox.join("child-release");

        let current_executable = env::current_exe().expect("当前测试程序路径必须可解析");
        let mut child = Command::new(current_executable)
            .args([
                "--exact",
                "windows::tests::namespace_lock_child_process",
                "--nocapture",
            ])
            .env(LOCK_CHILD_ROOT_ENV, &slot_root)
            .env(LOCK_CHILD_READY_ENV, &ready)
            .env(LOCK_CHILD_RELEASE_ENV, &release)
            .spawn()
            .expect("命名空间锁测试子进程应启动成功");
        wait_for_marker(&ready, Duration::from_secs(10));

        let (sender, receiver) = mpsc::channel();
        let delete_store = SlotStore::new(slot_root.clone());
        let delete_thread = thread::spawn(move || {
            sender
                .send(delete_store.delete_all_slots())
                .expect("删除结果接收端必须存活");
        });
        let early_result = receiver.recv_timeout(Duration::from_millis(300));
        let was_blocked = matches!(early_result, Err(mpsc::RecvTimeoutError::Timeout));

        fs::write(&release, b"release").expect("子进程释放标记应写入成功");
        let delete_result = match early_result {
            Ok(result) => result,
            Err(mpsc::RecvTimeoutError::Timeout) => receiver
                .recv_timeout(Duration::from_secs(10))
                .expect("锁释放后删除必须完成"),
            Err(mpsc::RecvTimeoutError::Disconnected) => panic!("删除线程不得提前断开"),
        };
        delete_thread.join().expect("删除线程不得 panic");
        let child_status = child.wait().expect("锁测试子进程必须可回收");
        fs::remove_dir_all(&sandbox).expect("跨进程锁测试目录必须清理");

        assert!(child_status.success(), "锁测试子进程必须成功退出");
        assert!(was_blocked, "另一进程持锁期间全槽删除不得开始");
        delete_result.expect("另一进程释放锁后全槽删除应成功");
    }

    fn expect_status(result: Result<LocalKey, KelivoStatus>, expected: KelivoStatus) {
        match result {
            Ok(_) => panic!("操作意外成功，期望状态：{expected:?}"),
            Err(actual) => assert_eq!(actual, expected),
        }
    }

    fn expect_empty_status(result: Result<(), KelivoStatus>, expected: KelivoStatus) {
        match result {
            Ok(()) => panic!("操作意外成功，期望状态：{expected:?}"),
            Err(actual) => assert_eq!(actual, expected),
        }
    }

    fn create_directory_junction(link: &Path, target: &Path) {
        let output = Command::new("cmd.exe")
            .args(["/d", "/c", "mklink", "/j"])
            .arg(link)
            .arg(target)
            .output()
            .expect("目录 junction 创建命令应可执行");
        assert!(
            output.status.success(),
            "目录 junction 应创建成功：{}{}",
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        );
    }

    #[test]
    fn slot_create_rejects_ancestor_junction_without_external_write() {
        let (_unused_store, sandbox) = create_test_store("ancestor_junction");
        let external = sandbox.join("external");
        let junction = sandbox.join("redirected");
        fs::create_dir(&external).expect("重定向目标目录应创建成功");
        create_directory_junction(&junction, &external);

        let store = SlotStore::new(junction.join("slots"));
        let slot_id = [0x61; KEY_SLOT_ID_SIZE];
        let result = store.create_slot(&slot_id);
        let external_slot_written = external
            .join("slots")
            .join(format!("{}.bin", encode_hex(&slot_id)))
            .exists();

        fs::remove_dir(&junction).expect("目录 junction 应清理成功");
        fs::remove_dir_all(&sandbox).expect("测试目录应清理成功");

        assert!(!external_slot_written, "junction 目标不得写入槽材料");
        expect_status(result, KelivoStatus::IoFailure);
    }

    #[test]
    fn slot_directory_junction_rejects_all_operations_without_external_mutation() {
        let (_unused_store, sandbox) = create_test_store("slots_junction");
        let external_slots = sandbox.join("external-slots");
        fs::create_dir(&external_slots).expect("外部槽目录应创建成功");
        let external_store = SlotStore::new(external_slots.clone());
        let existing_id = [0x65; KEY_SLOT_ID_SIZE];
        let missing_id = [0x66; KEY_SLOT_ID_SIZE];
        let _key = external_store
            .create_slot(&existing_id)
            .expect("外部测试槽应创建成功");
        let external_path = external_store.slot_path(&existing_id);
        let before = fs::read(&external_path).expect("外部测试槽应可读取");

        let slots_junction = sandbox.join("slots");
        create_directory_junction(&slots_junction, &external_slots);
        let linked_store = SlotStore::new(slots_junction.clone());

        let create_result = linked_store.create_slot(&missing_id);
        let open_result = linked_store.open_slot(&existing_id);
        let delete_result = linked_store.delete_slot(&existing_id);
        let after = fs::read(&external_path).expect("外部测试槽不得被删除");
        let unexpected_slot = external_store.slot_path(&missing_id).exists();

        fs::remove_dir(&slots_junction).expect("槽目录 junction 应清理成功");
        fs::remove_dir_all(&sandbox).expect("测试目录应清理成功");

        assert_eq!(after, before);
        assert!(!unexpected_slot, "junction 目标不得生成新槽");
        expect_status(create_result, KelivoStatus::IoFailure);
        expect_status(open_result, KelivoStatus::IoFailure);
        expect_empty_status(delete_result, KelivoStatus::IoFailure);
    }

    #[test]
    fn slot_create_builds_missing_regular_directory_chain() {
        let (_unused_store, sandbox) = create_test_store("missing_directories");
        let slot_root = sandbox
            .join("Kelivo")
            .join("secure-core")
            .join("v1")
            .join("slots");
        let store = SlotStore::new(slot_root.clone());
        let slot_id = [0x67; KEY_SLOT_ID_SIZE];

        let created = store.create_slot(&slot_id).expect("缺失槽目录链应安全创建");
        let opened = store.open_slot(&slot_id).expect("新建槽位应可读取");

        assert_eq!(&opened[..], &created[..]);
        open_directory_chain(&slot_root)
            .expect("最终槽目录链应通过验证")
            .expect("最终槽目录必须存在");
        fs::remove_dir_all(&sandbox).expect("测试目录应清理成功");
    }

    #[test]
    fn directory_chain_rejects_network_roots() {
        match ensure_directory_chain(Path::new(r"\\server\share\Kelivo\slots")) {
            Ok(_) => panic!("网络根不应承载本地安全槽"),
            Err(status) => assert_eq!(status, KelivoStatus::IoFailure),
        }
    }

    #[test]
    fn relative_handles_stay_bound_after_ancestor_replacement() {
        let (_unused_store, sandbox) = create_test_store("relative_handle_binding");
        let slot_root = sandbox.join("slots");
        let moved_root = sandbox.join("moved-slots");
        let external_root = sandbox.join("external-slots");
        fs::create_dir(&slot_root).expect("原槽目录应创建成功");
        fs::create_dir(&external_root).expect("外部槽目录应创建成功");
        let store = SlotStore::new(slot_root.clone());
        let slot_id = [0x68; KEY_SLOT_ID_SIZE];
        let original_key = store.create_slot(&slot_id).expect("原测试槽应创建成功");
        let slot_name = SlotStore::slot_name(&slot_id);
        let external_contents = b"external-slot-must-remain";
        fs::write(external_root.join(&slot_name), external_contents).expect("外部同名槽应创建成功");

        let guard = open_directory_chain(&slot_root)
            .expect("普通目录链应通过验证")
            .expect("普通目录链应存在");
        fs::rename(&slot_root, &moved_root).expect("逻辑槽目录应可被替换");
        create_directory_junction(&slot_root, &external_root);

        let reopened = read_slot_file(&guard, OsStr::new(&slot_name))
            .and_then(|encoded| decode_slot_file(&encoded).map(ToOwned::to_owned))
            .and_then(|protected| unprotect_key(&protected, &slot_id))
            .expect("读取必须保持绑定原槽目录");
        let mut temporary_file = match open_relative_file(
            &guard,
            OsStr::new(".binding.tmp"),
            FILE_WRITE_DATA | FILE_READ_ATTRIBUTES | DELETE | SYNCHRONIZE,
            FILE_SHARE_READ,
            FILE_CREATE,
        )
        .expect("相对临时文件创建应成功")
        {
            RelativeOpenResult::Opened(file) => file,
            RelativeOpenResult::Missing | RelativeOpenResult::Collision => {
                panic!("相对临时文件创建结果异常")
            }
        };
        temporary_file
            .write_all(b"bound-to-original-directory")
            .expect("相对临时文件应写入成功");
        temporary_file.sync_all().expect("相对临时文件应同步成功");
        rename_open_file(&temporary_file, &guard, OsStr::new("bound.bin"))
            .expect("句柄相对原子改名应成功");
        drop(temporary_file);
        delete_slot_file(&guard, OsStr::new(&slot_name)).expect("句柄删除应成功");

        let external_after =
            fs::read(external_root.join(&slot_name)).expect("外部同名槽不得被删除");
        let bound_contents =
            fs::read(moved_root.join("bound.bin")).expect("原目录应收到改名后的文件");
        let original_deleted = !moved_root.join(&slot_name).exists();
        let external_not_written = !external_root.join("bound.bin").exists();

        fs::remove_dir(&slot_root).expect("替换 junction 应清理成功");
        fs::remove_dir_all(&sandbox).expect("测试目录应清理成功");

        assert_eq!(&reopened[..], &original_key[..]);
        assert_eq!(external_after, external_contents);
        assert_eq!(bound_contents, b"bound-to-original-directory");
        assert!(original_deleted, "删除必须命中原槽目录");
        assert!(external_not_written, "外部 junction 目标不得接收临时文件");
    }

    #[test]
    fn open_file_cleanup_deletes_original_handle_after_name_replacement() {
        let (_unused_store, sandbox) = create_test_store("relative_handle_cleanup");
        let slot_root = sandbox.join("slots");
        let temporary_path = slot_root.join(".cleanup.tmp");
        let moved_temporary_path = slot_root.join(".moved-cleanup.tmp");
        let external_file = sandbox.join("external.bin");
        fs::create_dir(&slot_root).expect("原槽目录应创建成功");
        fs::write(&external_file, b"external-must-remain").expect("外部文件应创建成功");
        let guard = open_directory_chain(&slot_root)
            .expect("普通目录链应通过验证")
            .expect("普通目录链应存在");
        let temporary_file = match open_relative_file(
            &guard,
            OsStr::new(".cleanup.tmp"),
            FILE_WRITE_DATA | FILE_READ_ATTRIBUTES | DELETE | SYNCHRONIZE,
            FILE_SHARE_READ | FILE_SHARE_DELETE,
            FILE_CREATE,
        )
        .expect("相对临时文件创建应成功")
        {
            RelativeOpenResult::Opened(file) => file,
            RelativeOpenResult::Missing | RelativeOpenResult::Collision => {
                panic!("相对临时文件创建结果异常")
            }
        };
        fs::rename(&temporary_path, &moved_temporary_path).expect("临时文件名应可被替换");
        symlink_file(&external_file, &temporary_path).expect("旧临时名应可替换为外部链接");

        delete_open_file(&temporary_file).expect("临时文件应按原句柄删除");
        drop(temporary_file);
        let original_deleted = !moved_temporary_path.exists();
        let link_remains = fs::symlink_metadata(&temporary_path).is_ok();
        let external_contents = fs::read(&external_file).expect("外部文件不得被删除");

        fs::remove_file(&temporary_path).expect("旧临时名链接应清理成功");
        fs::remove_dir_all(&sandbox).expect("测试目录应清理成功");

        assert!(original_deleted, "清理必须删除原句柄对应文件");
        assert!(link_remains, "清理不得删除替换后的链接");
        assert_eq!(external_contents, b"external-must-remain");
    }

    #[test]
    fn slot_open_rejects_file_symlink() {
        let (store, root) = create_test_store("open_symlink");
        let slot_id = [0x62; KEY_SLOT_ID_SIZE];
        let slot_path = store.slot_path(&slot_id);
        let external_slot = root.join("external-slot.bin");
        let _key = store.create_slot(&slot_id).expect("测试槽位应创建成功");
        fs::rename(&slot_path, &external_slot).expect("槽位密文应移动到链接目标");
        symlink_file(&external_slot, &slot_path).expect("槽位文件符号链接应创建成功");

        let result = store.open_slot(&slot_id);

        fs::remove_file(&slot_path).expect("槽位文件符号链接应清理成功");
        fs::remove_dir_all(&root).expect("测试目录应清理成功");
        expect_status(result, KelivoStatus::IoFailure);
    }

    #[test]
    fn slot_create_rejects_file_symlink_without_external_write() {
        let (store, root) = create_test_store("create_symlink");
        let slot_id = [0x63; KEY_SLOT_ID_SIZE];
        let slot_path = store.slot_path(&slot_id);
        let external_slot = root.join("external-slot.bin");
        let sentinel = b"external-slot-must-not-change";
        fs::write(&external_slot, sentinel).expect("外部目标文件应创建成功");
        symlink_file(&external_slot, &slot_path).expect("槽位文件符号链接应创建成功");

        let result = store.create_slot(&slot_id);
        let external_contents = fs::read(&external_slot).expect("外部目标文件应保持可读");
        let link_remains = fs::symlink_metadata(&slot_path).is_ok();

        fs::remove_file(&slot_path).expect("槽位文件符号链接应清理成功");
        fs::remove_dir_all(&root).expect("测试目录应清理成功");

        assert_eq!(external_contents, sentinel);
        assert!(link_remains, "失败关闭不得移除既有符号链接");
        expect_status(result, KelivoStatus::IoFailure);
    }

    #[test]
    fn slot_delete_rejects_file_symlink_without_external_delete() {
        let (store, root) = create_test_store("delete_symlink");
        let slot_id = [0x64; KEY_SLOT_ID_SIZE];
        let slot_path = store.slot_path(&slot_id);
        let external_slot = root.join("external-slot.bin");
        let sentinel = b"external-slot-must-remain";
        fs::write(&external_slot, sentinel).expect("外部目标文件应创建成功");
        symlink_file(&external_slot, &slot_path).expect("槽位文件符号链接应创建成功");

        let result = store.delete_slot(&slot_id);
        let external_contents = fs::read(&external_slot).expect("外部目标文件不得被删除");
        let link_remains = fs::symlink_metadata(&slot_path).is_ok();

        if link_remains {
            fs::remove_file(&slot_path).expect("槽位文件符号链接应清理成功");
        }
        fs::remove_dir_all(&root).expect("测试目录应清理成功");

        assert_eq!(external_contents, sentinel);
        assert!(link_remains, "失败关闭不得移除符号链接");
        expect_empty_status(result, KelivoStatus::IoFailure);
    }

    #[test]
    fn all_slots_delete_removes_slot_files_and_legacy_temporary_files() {
        let (store, root) = create_test_store("delete_all");
        let first_slot_id = [0x71; KEY_SLOT_ID_SIZE];
        let second_slot_id = [0x72; KEY_SLOT_ID_SIZE];
        let _first_key = store
            .create_slot(&first_slot_id)
            .expect("首个测试槽应创建成功");
        let _second_key = store
            .create_slot(&second_slot_id)
            .expect("第二个测试槽应创建成功");
        let temporary_name = format!(
            ".{}.{}.tmp",
            SlotStore::slot_name(&first_slot_id),
            "ab".repeat(16)
        );
        fs::write(root.join(&temporary_name), b"legacy-partial-write")
            .expect("遗留临时文件应创建成功");

        store.delete_all_slots().expect("全部槽材料应删除成功");

        assert!(!store.slot_path(&first_slot_id).exists());
        assert!(!store.slot_path(&second_slot_id).exists());
        assert!(!root.join(temporary_name).exists());
        let remaining_names: Vec<OsString> = fs::read_dir(&root)
            .expect("槽目录应保持可枚举")
            .map(|entry| entry.expect("残留条目应可读取").file_name())
            .collect();
        assert_eq!(
            remaining_names,
            [OsString::from(
                super::super::slot_store_name::NAMESPACE_LOCK_FILE_NAME
            )],
            "全槽删除只能保留固定命名空间锁"
        );
        store.delete_all_slots().expect("空目录应幂等删除成功");
        fs::remove_dir_all(root).expect("测试目录应清理成功");
    }

    #[test]
    fn all_slots_delete_rejects_unknown_entry_before_deleting_valid_slots() {
        let (store, root) = create_test_store("delete_all_unknown");
        let slot_id = [0x73; KEY_SLOT_ID_SIZE];
        let _key = store.create_slot(&slot_id).expect("测试槽应创建成功");
        let unknown = root.join("unexpected-entry");
        fs::write(&unknown, b"must-not-be-touched").expect("异常条目应创建成功");

        let result = store.delete_all_slots();

        assert!(
            store.slot_path(&slot_id).exists(),
            "预检失败不得先删除合法槽"
        );
        assert_eq!(
            fs::read(&unknown).expect("异常条目应保持原样"),
            b"must-not-be-touched"
        );
        fs::remove_dir_all(root).expect("测试目录应清理成功");
        expect_empty_status(result, KelivoStatus::IoFailure);
    }

    #[test]
    fn all_slots_delete_rejects_reparse_entry_without_touching_external_target() {
        let (_unused_store, sandbox) = create_test_store("delete_all_reparse");
        let root = sandbox.join("slots");
        fs::create_dir(&root).expect("槽目录应创建成功");
        let store = SlotStore::new(root.clone());
        let valid_slot_id = [0x74; KEY_SLOT_ID_SIZE];
        let linked_slot_id = [0x75; KEY_SLOT_ID_SIZE];
        let _key = store
            .create_slot(&valid_slot_id)
            .expect("合法测试槽应创建成功");
        let external = sandbox.join("external.bin");
        fs::write(&external, b"external-must-remain").expect("外部目标应创建成功");
        symlink_file(&external, store.slot_path(&linked_slot_id))
            .expect("伪装为槽位的重解析点应创建成功");

        let result = store.delete_all_slots();

        assert!(
            store.slot_path(&valid_slot_id).exists(),
            "重解析点预检失败不得删除其他合法槽"
        );
        assert_eq!(
            fs::read(&external).expect("外部目标不得被删除"),
            b"external-must-remain"
        );
        fs::remove_file(store.slot_path(&linked_slot_id)).expect("测试链接应清理成功");
        fs::remove_dir_all(sandbox).expect("测试目录应清理成功");
        expect_empty_status(result, KelivoStatus::IoFailure);
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
    fn slot_delete_is_idempotent_and_preserves_io_failures() {
        let (store, root) = create_test_store("delete");
        let slot_id = [0x45; KEY_SLOT_ID_SIZE];
        let slot_path = store.slot_path(&slot_id);

        let _key = store.create_slot(&slot_id).expect("待删除槽位应创建成功");
        store.delete_slot(&slot_id).expect("已有槽位应删除成功");
        assert!(!slot_path.exists());
        expect_status(store.open_slot(&slot_id), KelivoStatus::SlotNotFound);
        store.delete_slot(&slot_id).expect("缺失槽位应幂等成功");

        fs::create_dir(&slot_path).expect("故障槽位目录应创建成功");
        expect_empty_status(store.delete_slot(&slot_id), KelivoStatus::IoFailure);
        fs::remove_dir(&slot_path).expect("故障槽位目录应清理成功");
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
