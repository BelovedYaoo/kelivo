use super::{
    BACKGROUND_ACCESS_CAPABILITY, KEY_SLOTS_CAPABILITY, KelivoStatus, LOCAL_KEY_SIZE, LocalKey,
    RECORD_ENVELOPES_CAPABILITY, SQLCIPHER_DATABASE_ATTACH_CAPABILITY,
    SQLCIPHER_KEY_APPLICATION_CAPABILITY,
    slot_store_name::{NAMESPACE_LOCK_FILE_NAME, SlotStoreEntryKind, classify_slot_store_entry},
};
use jni::{
    JNIEnv, JavaVM,
    objects::{GlobalRef, JClass, JObject, JString, JValue},
    sys::{JavaVM as RawJavaVm, jobject},
};
use std::{
    convert::TryFrom,
    ffi::{CStr, CString, OsStr, c_void},
    fs::File,
    io::{ErrorKind, Read, Write},
    mem::size_of,
    os::{
        fd::{AsRawFd, FromRawFd},
        unix::ffi::OsStrExt,
    },
    path::{Component, Path, PathBuf},
    sync::OnceLock,
};
use zeroize::Zeroizing;

pub(super) const SECURE_STORAGE_BACKEND: u32 = 2;
pub(super) const CAPABILITY_FLAGS: u64 = KEY_SLOTS_CAPABILITY
    | BACKGROUND_ACCESS_CAPABILITY
    | RECORD_ENVELOPES_CAPABILITY
    | SQLCIPHER_KEY_APPLICATION_CAPABILITY
    | SQLCIPHER_DATABASE_ATTACH_CAPABILITY;

const SLOT_MAGIC: [u8; 8] = *b"KELVKA01";
const SLOT_HEADER_SIZE: usize = SLOT_MAGIC.len() + size_of::<u32>();
const PROTECTED_KEY_SIZE: usize = 61;
const MAX_SLOT_FILE_SIZE: usize = SLOT_HEADER_SIZE + PROTECTED_KEY_SIZE;
const TEMP_FILE_ATTEMPTS: usize = 16;
const ANDROID_SLOT_AAD_PREFIX: [u8; 16] = *b"kelivo.secure.v1";

pub(super) fn create_slot(slot_id: &[u8; 16]) -> Result<LocalKey, KelivoStatus> {
    default_store()?.create_slot(slot_id)
}

pub(super) fn open_slot(slot_id: &[u8; 16]) -> Result<LocalKey, KelivoStatus> {
    default_store()?.open_slot(slot_id)
}

pub(super) fn delete_slot(slot_id: &[u8; 16]) -> Result<(), KelivoStatus> {
    default_store()?.delete_slot(slot_id)
}

pub(super) fn delete_all_slots() -> Result<(), KelivoStatus> {
    default_store()?.delete_all_slots()
}

pub(super) fn fill_random(output: &mut [u8]) -> Result<(), KelivoStatus> {
    getrandom::getrandom(output).map_err(|_| KelivoStatus::RandomSourceFailure)
}

fn default_store() -> Result<SlotStore, KelivoStatus> {
    Ok(SlotStore::new(slot_root_path()?))
}

struct SlotStore {
    root: PathBuf,
}

impl SlotStore {
    fn new(root: PathBuf) -> Self {
        Self { root }
    }

    fn create_slot(&self, slot_id: &[u8; 16]) -> Result<LocalKey, KelivoStatus> {
        let store = self.open_locked(true)?.ok_or(KelivoStatus::InternalState)?;
        let slot_name = Self::slot_name(slot_id);
        if open_relative_regular(&store.directory, &slot_name)?.is_some() {
            return Err(KelivoStatus::SlotAlreadyExists);
        }

        let mut key = Zeroizing::new(vec![0_u8; LOCAL_KEY_SIZE].into_boxed_slice());
        fill_random(&mut key[..])?;
        let protected_key = protect_key(&key[..], slot_id)?;
        let encoded = encode_slot_file(&protected_key)?;
        write_atomic_locked(&store.directory, &slot_name, &encoded)?;
        Ok(key)
    }

    fn open_slot(&self, slot_id: &[u8; 16]) -> Result<LocalKey, KelivoStatus> {
        let Some(store) = self.open_locked(false)? else {
            return Err(KelivoStatus::SlotNotFound);
        };
        let encoded = read_slot_file(&store.directory, &Self::slot_name(slot_id))?;
        let protected_key = decode_slot_file(&encoded)?;
        unprotect_key(protected_key, slot_id)
    }

    fn delete_slot(&self, slot_id: &[u8; 16]) -> Result<(), KelivoStatus> {
        let store = self.open_locked(true)?.ok_or(KelivoStatus::InternalState)?;
        // Keystore 主包装密钥由所有槽共享；删除它会误擦除其他账户，只移除本槽密文。
        unlink_relative(&store.directory, &Self::slot_name(slot_id), true)?;
        store.directory.sync()
    }

    fn delete_all_slots(&self) -> Result<(), KelivoStatus> {
        let store = self.open_locked(true)?.ok_or(KelivoStatus::InternalState)?;
        let entries = deletable_entry_names(&store.directory)?;
        // 先摧毁共享包装根密钥；之后即使文件系统清理失败，旧槽密文也不可再解密。
        delete_wrapping_key()?;
        delete_preflighted_entries(&store.directory, entries)
    }

    #[cfg(test)]
    fn ensure_root(&self) -> Result<(), KelivoStatus> {
        open_directory_chain(&self.root, true)?
            .map(|_| ())
            .ok_or(KelivoStatus::InternalState)
    }

    fn open_locked(&self, create: bool) -> Result<Option<LockedStore>, KelivoStatus> {
        let Some(directory) = open_directory_chain(&self.root, create)? else {
            return Ok(None);
        };
        let lock = StoreLock::acquire(&directory)?;
        Ok(Some(LockedStore {
            directory,
            _lock: lock,
        }))
    }

    fn slot_name(slot_id: &[u8; 16]) -> String {
        format!("{}.bin", encode_hex(slot_id))
    }

    #[cfg(test)]
    fn slot_path(&self, slot_id: &[u8; 16]) -> PathBuf {
        self.root.join(Self::slot_name(slot_id))
    }
}

struct LockedStore {
    directory: DirectoryGuard,
    _lock: StoreLock,
}

struct DirectoryGuard(File);

impl DirectoryGuard {
    fn sync(&self) -> Result<(), KelivoStatus> {
        self.0.sync_all().map_err(|_| KelivoStatus::IoFailure)
    }
}

fn open_directory_chain(path: &Path, create: bool) -> Result<Option<DirectoryGuard>, KelivoStatus> {
    let mut components = path.components();
    if !matches!(components.next(), Some(Component::RootDir)) {
        return Err(KelivoStatus::IoFailure);
    }
    let root_fd = unsafe {
        libc::open(
            c"/".as_ptr(),
            libc::O_RDONLY | libc::O_DIRECTORY | libc::O_CLOEXEC | libc::O_NOFOLLOW,
        )
    };
    if root_fd < 0 {
        return Err(KelivoStatus::IoFailure);
    }
    let mut directory = unsafe { File::from_raw_fd(root_fd) };
    let mut opened_component = false;
    for component in components {
        let Component::Normal(name) = component else {
            return Err(KelivoStatus::IoFailure);
        };
        opened_component = true;
        let name = c_string(name)?;
        if create {
            let created = unsafe { libc::mkdirat(directory.as_raw_fd(), name.as_ptr(), 0o700) };
            if created != 0 && std::io::Error::last_os_error().kind() != ErrorKind::AlreadyExists {
                return Err(KelivoStatus::IoFailure);
            }
        }
        let next_fd = unsafe {
            libc::openat(
                directory.as_raw_fd(),
                name.as_ptr(),
                libc::O_RDONLY | libc::O_DIRECTORY | libc::O_CLOEXEC | libc::O_NOFOLLOW,
            )
        };
        if next_fd < 0 {
            let error = std::io::Error::last_os_error();
            if !create && error.kind() == ErrorKind::NotFound {
                return Ok(None);
            }
            return Err(KelivoStatus::IoFailure);
        }
        directory = unsafe { File::from_raw_fd(next_fd) };
    }
    if !opened_component {
        return Err(KelivoStatus::IoFailure);
    }
    if create && unsafe { libc::fchmod(directory.as_raw_fd(), 0o700) } != 0 {
        return Err(KelivoStatus::IoFailure);
    }
    Ok(Some(DirectoryGuard(directory)))
}

fn c_string(name: &OsStr) -> Result<CString, KelivoStatus> {
    CString::new(name.as_bytes()).map_err(|_| KelivoStatus::IoFailure)
}

fn ascii_c_string(name: &str) -> Result<CString, KelivoStatus> {
    if !name.is_ascii() {
        return Err(KelivoStatus::IoFailure);
    }
    CString::new(name).map_err(|_| KelivoStatus::IoFailure)
}

fn open_relative_regular(
    directory: &DirectoryGuard,
    name: &str,
) -> Result<Option<File>, KelivoStatus> {
    let name = ascii_c_string(name)?;
    let fd = unsafe {
        libc::openat(
            directory.0.as_raw_fd(),
            name.as_ptr(),
            libc::O_RDONLY | libc::O_CLOEXEC | libc::O_NOFOLLOW,
        )
    };
    if fd < 0 {
        return if std::io::Error::last_os_error().kind() == ErrorKind::NotFound {
            Ok(None)
        } else {
            Err(KelivoStatus::IoFailure)
        };
    }
    let file = unsafe { File::from_raw_fd(fd) };
    validate_regular_file(&file)?;
    Ok(Some(file))
}

fn validate_regular_file(file: &File) -> Result<(), KelivoStatus> {
    let mut metadata = std::mem::MaybeUninit::<libc::stat>::zeroed();
    if unsafe { libc::fstat(file.as_raw_fd(), metadata.as_mut_ptr()) } != 0 {
        return Err(KelivoStatus::IoFailure);
    }
    let metadata = unsafe { metadata.assume_init() };
    if u64::from(metadata.st_mode) & u64::from(libc::S_IFMT) == u64::from(libc::S_IFREG) {
        Ok(())
    } else {
        Err(KelivoStatus::IoFailure)
    }
}

fn write_atomic_locked(
    directory: &DirectoryGuard,
    destination_name: &str,
    contents: &[u8],
) -> Result<(), KelivoStatus> {
    let (temporary_name, mut temporary_file) = create_temporary_file(directory, destination_name)?;
    let write_result = temporary_file
        .write_all(contents)
        .and_then(|()| temporary_file.sync_all());
    drop(temporary_file);
    if write_result.is_err() {
        unlink_relative(directory, &temporary_name, true)?;
        return Err(KelivoStatus::IoFailure);
    }

    let source = ascii_c_string(&temporary_name)?;
    let destination = ascii_c_string(destination_name)?;
    let renamed = unsafe {
        libc::syscall(
            libc::SYS_renameat2,
            directory.0.as_raw_fd(),
            source.as_ptr(),
            directory.0.as_raw_fd(),
            destination.as_ptr(),
            libc::RENAME_NOREPLACE,
        )
    };
    if renamed != 0 {
        let error = std::io::Error::last_os_error();
        unlink_relative(directory, &temporary_name, true)?;
        return if error.kind() == ErrorKind::AlreadyExists {
            Err(KelivoStatus::SlotAlreadyExists)
        } else {
            Err(KelivoStatus::IoFailure)
        };
    }
    directory.sync()
}

fn create_temporary_file(
    directory: &DirectoryGuard,
    destination_name: &str,
) -> Result<(String, File), KelivoStatus> {
    for _ in 0..TEMP_FILE_ATTEMPTS {
        let mut suffix = [0_u8; 16];
        fill_random(&mut suffix)?;
        let name = format!(".{destination_name}.{}.tmp", encode_hex(&suffix));
        let encoded_name = ascii_c_string(&name)?;
        let fd = unsafe {
            libc::openat(
                directory.0.as_raw_fd(),
                encoded_name.as_ptr(),
                libc::O_WRONLY | libc::O_CREAT | libc::O_EXCL | libc::O_CLOEXEC | libc::O_NOFOLLOW,
                0o600,
            )
        };
        if fd >= 0 {
            let file = unsafe { File::from_raw_fd(fd) };
            validate_regular_file(&file)?;
            return Ok((name, file));
        }
        if std::io::Error::last_os_error().kind() != ErrorKind::AlreadyExists {
            return Err(KelivoStatus::IoFailure);
        }
    }
    Err(KelivoStatus::InternalState)
}

fn unlink_relative(
    directory: &DirectoryGuard,
    name: &str,
    missing_is_success: bool,
) -> Result<(), KelivoStatus> {
    let name = ascii_c_string(name)?;
    let result = unsafe { libc::unlinkat(directory.0.as_raw_fd(), name.as_ptr(), 0) };
    if result == 0 {
        return Ok(());
    }
    if missing_is_success && std::io::Error::last_os_error().kind() == ErrorKind::NotFound {
        Ok(())
    } else {
        Err(KelivoStatus::IoFailure)
    }
}

fn deletable_entry_names(directory: &DirectoryGuard) -> Result<Vec<String>, KelivoStatus> {
    let mut deletable = Vec::new();
    for name in directory_entry_names(directory)? {
        validate_relative_regular(directory, &name)?;
        match classify_slot_store_entry(&name) {
            SlotStoreEntryKind::Slot | SlotStoreEntryKind::Temporary => deletable.push(name),
            SlotStoreEntryKind::NamespaceLock => {}
            SlotStoreEntryKind::Unknown => return Err(KelivoStatus::IoFailure),
        }
    }
    Ok(deletable)
}

fn delete_preflighted_entries(
    directory: &DirectoryGuard,
    entries: Vec<String>,
) -> Result<(), KelivoStatus> {
    for name in entries {
        unlink_relative(directory, &name, false)?;
    }
    directory.sync()?;
    if deletable_entry_names(directory)?.is_empty() {
        Ok(())
    } else {
        Err(KelivoStatus::IoFailure)
    }
}

fn validate_relative_regular(directory: &DirectoryGuard, name: &str) -> Result<(), KelivoStatus> {
    let name = ascii_c_string(name)?;
    let mut metadata = std::mem::MaybeUninit::<libc::stat>::zeroed();
    if unsafe {
        libc::fstatat(
            directory.0.as_raw_fd(),
            name.as_ptr(),
            metadata.as_mut_ptr(),
            libc::AT_SYMLINK_NOFOLLOW,
        )
    } != 0
    {
        return Err(KelivoStatus::IoFailure);
    }
    let metadata = unsafe { metadata.assume_init() };
    if u64::from(metadata.st_mode) & u64::from(libc::S_IFMT) == u64::from(libc::S_IFREG) {
        Ok(())
    } else {
        Err(KelivoStatus::IoFailure)
    }
}

struct DirectoryStream(*mut libc::DIR);

impl Drop for DirectoryStream {
    fn drop(&mut self) {
        unsafe { libc::closedir(self.0) };
    }
}

fn directory_entry_names(directory: &DirectoryGuard) -> Result<Vec<String>, KelivoStatus> {
    // `dup` 会共享目录偏移，最终确认可能从上次枚举的 EOF 开始；相对打开 `.`
    // 既保持绑定已固定的根目录，又为每次枚举创建独立偏移。
    let enumeration_fd = unsafe {
        libc::openat(
            directory.0.as_raw_fd(),
            c".".as_ptr(),
            libc::O_RDONLY | libc::O_DIRECTORY | libc::O_CLOEXEC | libc::O_NOFOLLOW,
        )
    };
    if enumeration_fd < 0 {
        return Err(KelivoStatus::IoFailure);
    }
    let raw_stream = unsafe { libc::fdopendir(enumeration_fd) };
    if raw_stream.is_null() {
        unsafe { libc::close(enumeration_fd) };
        return Err(KelivoStatus::IoFailure);
    }
    let stream = DirectoryStream(raw_stream);
    let mut names = Vec::new();
    loop {
        unsafe { *libc::__errno() = 0 };
        let entry = unsafe { libc::readdir(stream.0) };
        if entry.is_null() {
            return if unsafe { *libc::__errno() } == 0 {
                Ok(names)
            } else {
                Err(KelivoStatus::IoFailure)
            };
        }
        let name = unsafe { CStr::from_ptr((*entry).d_name.as_ptr()) };
        if name.to_bytes() == b"." || name.to_bytes() == b".." {
            continue;
        }
        names.push(
            name.to_str()
                .map_err(|_| KelivoStatus::IoFailure)?
                .to_owned(),
        );
    }
}

struct StoreLock(File);

impl StoreLock {
    fn acquire(directory: &DirectoryGuard) -> Result<Self, KelivoStatus> {
        let name = ascii_c_string(NAMESPACE_LOCK_FILE_NAME)?;
        let fd = unsafe {
            libc::openat(
                directory.0.as_raw_fd(),
                name.as_ptr(),
                libc::O_RDWR | libc::O_CREAT | libc::O_CLOEXEC | libc::O_NOFOLLOW,
                0o600,
            )
        };
        if fd < 0 {
            return Err(KelivoStatus::IoFailure);
        }
        let file = unsafe { File::from_raw_fd(fd) };
        validate_regular_file(&file)?;
        loop {
            let result = unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX) };
            if result == 0 {
                return Ok(Self(file));
            }
            if std::io::Error::last_os_error().kind() != ErrorKind::Interrupted {
                return Err(KelivoStatus::IoFailure);
            }
        }
    }
}

impl Drop for StoreLock {
    fn drop(&mut self) {
        let result = unsafe { libc::flock(self.0.as_raw_fd(), libc::LOCK_UN) };
        debug_assert_eq!(result, 0);
    }
}

fn read_slot_file(directory: &DirectoryGuard, name: &str) -> Result<Vec<u8>, KelivoStatus> {
    let file = open_relative_regular(directory, name)?.ok_or(KelivoStatus::SlotNotFound)?;
    let mut limited = file.take((MAX_SLOT_FILE_SIZE + 1) as u64);
    let mut encoded = Vec::with_capacity(MAX_SLOT_FILE_SIZE);
    limited
        .read_to_end(&mut encoded)
        .map_err(|_| KelivoStatus::IoFailure)?;
    if encoded.len() > MAX_SLOT_FILE_SIZE {
        return Err(KelivoStatus::SlotDataInvalid);
    }
    Ok(encoded)
}

fn encode_slot_file(protected_key: &[u8]) -> Result<Vec<u8>, KelivoStatus> {
    if protected_key.len() != PROTECTED_KEY_SIZE {
        return Err(KelivoStatus::SlotDataInvalid);
    }
    let protected_length =
        u32::try_from(protected_key.len()).map_err(|_| KelivoStatus::SlotDataInvalid)?;
    let mut encoded = Vec::with_capacity(MAX_SLOT_FILE_SIZE);
    encoded.extend_from_slice(&SLOT_MAGIC);
    encoded.extend_from_slice(&protected_length.to_le_bytes());
    encoded.extend_from_slice(protected_key);
    Ok(encoded)
}

fn decode_slot_file(encoded: &[u8]) -> Result<&[u8], KelivoStatus> {
    if encoded.len() != MAX_SLOT_FILE_SIZE || encoded[..SLOT_MAGIC.len()] != SLOT_MAGIC {
        return Err(KelivoStatus::SlotDataInvalid);
    }
    let mut protected_length = [0_u8; size_of::<u32>()];
    protected_length.copy_from_slice(&encoded[SLOT_MAGIC.len()..SLOT_HEADER_SIZE]);
    if u32::from_le_bytes(protected_length) as usize != PROTECTED_KEY_SIZE {
        return Err(KelivoStatus::SlotDataInvalid);
    }
    Ok(&encoded[SLOT_HEADER_SIZE..])
}

fn protect_key(key: &[u8], slot_id: &[u8; 16]) -> Result<Vec<u8>, KelivoStatus> {
    if key.len() != LOCAL_KEY_SIZE {
        return Err(KelivoStatus::InternalState);
    }
    let aad = slot_aad(slot_id);
    let mut protected_key = vec![0_u8; PROTECTED_KEY_SIZE];
    let written = invoke_bridge_crypto(
        "encrypt",
        key,
        &aad,
        &mut protected_key,
        KelivoStatus::SecureStorageUnavailable,
    )?;
    if written != PROTECTED_KEY_SIZE {
        return Err(KelivoStatus::SecureStorageUnavailable);
    }
    Ok(protected_key)
}

fn unprotect_key(protected_key: &[u8], slot_id: &[u8; 16]) -> Result<LocalKey, KelivoStatus> {
    if protected_key.len() != PROTECTED_KEY_SIZE {
        return Err(KelivoStatus::SlotDataInvalid);
    }
    let aad = slot_aad(slot_id);
    let mut key = Zeroizing::new(vec![0_u8; LOCAL_KEY_SIZE].into_boxed_slice());
    let written = invoke_bridge_crypto(
        "decrypt",
        protected_key,
        &aad,
        &mut key[..],
        KelivoStatus::SlotUnwrapFailed,
    )?;
    if written != LOCAL_KEY_SIZE {
        return Err(KelivoStatus::SlotDataInvalid);
    }
    Ok(key)
}

fn slot_aad(slot_id: &[u8; 16]) -> [u8; 32] {
    let mut aad = [0_u8; 32];
    aad[..ANDROID_SLOT_AAD_PREFIX.len()].copy_from_slice(&ANDROID_SLOT_AAD_PREFIX);
    aad[ANDROID_SLOT_AAD_PREFIX.len()..].copy_from_slice(slot_id);
    aad
}

fn delete_wrapping_key() -> Result<(), KelivoStatus> {
    let context = jni_context()?;
    let mut env = context
        .java_vm
        .attach_current_thread()
        .map_err(|_| KelivoStatus::SecureStorageUnavailable)?;
    let bridge_class = load_bridge_class(&mut env, &context.class_loader)?;
    match env.call_static_method(bridge_class, "deleteWrappingKey", "()V", &[]) {
        Ok(_) => Ok(()),
        Err(_) => {
            clear_pending_exception(&mut env);
            Err(KelivoStatus::SecureStorageUnavailable)
        }
    }
}

fn invoke_bridge_crypto(
    method: &str,
    input: &[u8],
    associated_data: &[u8],
    output: &mut [u8],
    failure_status: KelivoStatus,
) -> Result<usize, KelivoStatus> {
    let context = jni_context()?;
    let mut env = context
        .java_vm
        .attach_current_thread()
        .map_err(|_| failure_status)?;
    let bridge_class = load_bridge_class(&mut env, &context.class_loader)?;
    // Java 方法同步完成且不保存引用，因此三个 DirectByteBuffer 的生命周期覆盖全部访问。
    let input_buffer =
        unsafe { env.new_direct_byte_buffer(input.as_ptr().cast_mut(), input.len()) }
            .map_err(|_| failure_status)?;
    let aad_buffer = unsafe {
        env.new_direct_byte_buffer(associated_data.as_ptr().cast_mut(), associated_data.len())
    }
    .map_err(|_| failure_status)?;
    let output_buffer = unsafe { env.new_direct_byte_buffer(output.as_mut_ptr(), output.len()) }
        .map_err(|_| failure_status)?;
    let value = match env.call_static_method(
        bridge_class,
        method,
        "(Ljava/nio/ByteBuffer;Ljava/nio/ByteBuffer;Ljava/nio/ByteBuffer;)I",
        &[
            JValue::Object(&input_buffer),
            JValue::Object(&aad_buffer),
            JValue::Object(&output_buffer),
        ],
    ) {
        Ok(value) => value,
        Err(_) => {
            clear_pending_exception(&mut env);
            return Err(failure_status);
        }
    };
    let written = value.i().map_err(|_| failure_status)?;
    usize::try_from(written).map_err(|_| failure_status)
}

struct AndroidJniContext {
    java_vm: JavaVM,
    class_loader: GlobalRef,
}

static JNI_CONTEXT: OnceLock<AndroidJniContext> = OnceLock::new();

fn jni_context() -> Result<&'static AndroidJniContext, KelivoStatus> {
    if let Some(context) = JNI_CONTEXT.get() {
        return Ok(context);
    }

    let context = load_jni_context()?;
    let _ = JNI_CONTEXT.set(context);
    JNI_CONTEXT
        .get()
        .ok_or(KelivoStatus::SecureStorageUnavailable)
}

fn load_jni_context() -> Result<AndroidJniContext, KelivoStatus> {
    let library_name = c"libirondash_engine_context_native.so";
    let library = DynamicLibrary::open_loaded(library_name)?;
    let get_java_vm = library.symbol(c"irondash_engine_context_get_java_vm")?;
    let get_class_loader = library.symbol(c"irondash_engine_context_get_class_loader")?;

    type GetJavaVm = unsafe extern "C" fn() -> *mut RawJavaVm;
    type GetClassLoader = unsafe extern "C" fn() -> jobject;
    let get_java_vm: GetJavaVm = unsafe { std::mem::transmute(get_java_vm) };
    let get_class_loader: GetClassLoader = unsafe { std::mem::transmute(get_class_loader) };
    let raw_java_vm = unsafe { get_java_vm() };
    let raw_class_loader = unsafe { get_class_loader() };
    if raw_java_vm.is_null() || raw_class_loader.is_null() {
        return Err(KelivoStatus::SecureStorageUnavailable);
    }

    let java_vm = unsafe { JavaVM::from_raw(raw_java_vm) }
        .map_err(|_| KelivoStatus::SecureStorageUnavailable)?;
    let env = java_vm
        .attach_current_thread()
        .map_err(|_| KelivoStatus::SecureStorageUnavailable)?;
    let class_loader = env
        .new_global_ref(unsafe { JObject::from_raw(raw_class_loader) })
        .map_err(|_| KelivoStatus::SecureStorageUnavailable)?;
    drop(env);

    Ok(AndroidJniContext {
        java_vm,
        class_loader,
    })
}

fn slot_root_path() -> Result<PathBuf, KelivoStatus> {
    let context = jni_context()?;
    let mut env = context
        .java_vm
        .attach_current_thread()
        .map_err(|_| KelivoStatus::SecureStorageUnavailable)?;
    let bridge_class = load_bridge_class(&mut env, &context.class_loader)?;
    let value = match env.call_static_method(
        bridge_class,
        "getSlotRootPath",
        "()Ljava/lang/String;",
        &[],
    ) {
        Ok(value) => value,
        Err(_) => {
            clear_pending_exception(&mut env);
            return Err(KelivoStatus::SecureStorageUnavailable);
        }
    };
    let path_object = value
        .l()
        .map_err(|_| KelivoStatus::SecureStorageUnavailable)?;
    if path_object.is_null() {
        return Err(KelivoStatus::SecureStorageUnavailable);
    }
    let path_string = JString::from(path_object);
    let path: String = env
        .get_string(&path_string)
        .map_err(|_| KelivoStatus::SecureStorageUnavailable)?
        .into();
    let path = PathBuf::from(path);
    if !path.is_absolute() {
        return Err(KelivoStatus::SecureStorageUnavailable);
    }
    Ok(path)
}

fn load_bridge_class<'local>(
    env: &mut JNIEnv<'local>,
    class_loader: &GlobalRef,
) -> Result<JClass<'local>, KelivoStatus> {
    let class_name = env
        .new_string("com.psyche.kelivo.KelivoKeystoreBridge")
        .map_err(|_| KelivoStatus::SecureStorageUnavailable)?;
    let value = match env.call_method(
        class_loader.as_obj(),
        "loadClass",
        "(Ljava/lang/String;)Ljava/lang/Class;",
        &[JValue::Object(&class_name)],
    ) {
        Ok(value) => value,
        Err(_) => {
            clear_pending_exception(env);
            return Err(KelivoStatus::SecureStorageUnavailable);
        }
    };
    value
        .l()
        .map(JClass::from)
        .map_err(|_| KelivoStatus::SecureStorageUnavailable)
}

fn clear_pending_exception(env: &mut JNIEnv<'_>) {
    if env.exception_check().unwrap_or(false) {
        let _ = env.exception_clear();
    }
}

struct DynamicLibrary(*mut c_void);

impl DynamicLibrary {
    fn open_loaded(name: &CStr) -> Result<Self, KelivoStatus> {
        let handle = unsafe { libc::dlopen(name.as_ptr(), libc::RTLD_NOLOAD) };
        if handle.is_null() {
            Err(KelivoStatus::SecureStorageUnavailable)
        } else {
            Ok(Self(handle))
        }
    }

    fn symbol(&self, name: &CStr) -> Result<*mut c_void, KelivoStatus> {
        let symbol = unsafe { libc::dlsym(self.0, name.as_ptr()) };
        if symbol.is_null() {
            Err(KelivoStatus::SecureStorageUnavailable)
        } else {
            Ok(symbol)
        }
    }
}

impl Drop for DynamicLibrary {
    fn drop(&mut self) {
        let result = unsafe { libc::dlclose(self.0) };
        debug_assert_eq!(result, 0);
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
    use std::{fs, os::unix::fs::symlink};

    #[test]
    fn all_slots_delete_names_are_strict_and_include_legacy_temporary_files() {
        assert_eq!(
            classify_slot_store_entry(&format!("{}.bin", "ab".repeat(16))),
            SlotStoreEntryKind::Slot
        );
        assert_eq!(
            classify_slot_store_entry(&format!(".{}.bin.{}.tmp", "ab".repeat(16), "cd".repeat(16))),
            SlotStoreEntryKind::Temporary
        );
        for invalid in [
            format!("{}.BIN", "ab".repeat(16)),
            format!("{}.bin", "AB".repeat(16)),
            ".slot-store.lock.tmp".to_owned(),
            "unexpected-entry".to_owned(),
        ] {
            assert_eq!(
                classify_slot_store_entry(&invalid),
                SlotStoreEntryKind::Unknown
            );
        }
    }

    #[test]
    fn pinned_root_fd_ignores_ancestor_symlink_replacement() {
        let mut suffix = [0_u8; 16];
        fill_random(&mut suffix).expect("祖先换链测试随机后缀应生成成功");
        let sandbox = std::env::temp_dir().join(format!(
            "kelivo_secure_core_android_ancestor_swap_{}",
            encode_hex(&suffix)
        ));
        let live_ancestor = sandbox.join("live");
        let moved_ancestor = sandbox.join("moved");
        let external = sandbox.join("external");
        let slot_root = live_ancestor.join("slots");
        let external_slot_root = external.join("slots");
        fs::create_dir_all(&slot_root).expect("原槽目录应创建成功");
        fs::create_dir_all(&external_slot_root).expect("外部槽目录应创建成功");
        let slot_name = format!("{}.bin", "ab".repeat(16));
        fs::write(slot_root.join(&slot_name), b"original").expect("原目录槽材料应写入成功");
        fs::write(external_slot_root.join(&slot_name), b"external")
            .expect("外部目录哨兵应写入成功");

        let store = SlotStore::new(slot_root);
        let locked = store
            .open_locked(false)
            .expect("原槽目录应可固定")
            .expect("原槽目录必须存在");
        fs::rename(&live_ancestor, &moved_ancestor).expect("原祖先应可换名");
        symlink(&external, &live_ancestor).expect("替换祖先 symlink 应创建成功");

        let entries = deletable_entry_names(&locked.directory).expect("旧目录应可预检");
        let repeated_entries =
            deletable_entry_names(&locked.directory).expect("重复预检必须从目录起点开始");
        assert_eq!(repeated_entries, entries, "目录枚举不得复用上次读取偏移");
        delete_preflighted_entries(&locked.directory, entries).expect("旧目录槽材料应清理成功");
        let original_exists = moved_ancestor.join("slots").join(&slot_name).exists();
        let external_contents =
            fs::read(external_slot_root.join(&slot_name)).expect("外部哨兵不得被删除");
        drop(locked);
        fs::remove_file(&live_ancestor).expect("替换祖先 symlink 应清理成功");
        fs::remove_dir_all(&sandbox).expect("祖先换链测试目录应清理成功");

        assert!(!original_exists, "删除必须落在固定 FD 指向的原目录");
        assert_eq!(external_contents, b"external", "替换目标不得被修改");
    }

    #[test]
    fn slot_file_delete_is_idempotent_and_syncs_the_store() {
        let mut suffix = [0_u8; 16];
        fill_random(&mut suffix).expect("测试目录随机后缀应生成成功");
        let root = std::env::temp_dir().join(format!(
            "kelivo_secure_core_android_delete_{}",
            encode_hex(&suffix)
        ));
        let store = SlotStore::new(root.clone());
        let slot_id = [0x46; 16];
        store.ensure_root().expect("测试槽位目录应创建成功");
        fs::write(store.slot_path(&slot_id), b"wrapped-key").expect("测试槽位应写入成功");

        store.delete_slot(&slot_id).expect("已有槽位应删除成功");
        assert!(!store.slot_path(&slot_id).exists());
        store.delete_slot(&slot_id).expect("缺失槽位应幂等成功");

        fs::remove_dir_all(root).expect("测试目录应清理成功");
    }

    #[test]
    fn all_slots_delete_preflight_rejects_unknown_entries() {
        let mut suffix = [0_u8; 16];
        fill_random(&mut suffix).expect("测试目录随机后缀应生成成功");
        let root = std::env::temp_dir().join(format!(
            "kelivo_secure_core_android_delete_all_{}",
            encode_hex(&suffix)
        ));
        let store = SlotStore::new(root.clone());
        store.ensure_root().expect("测试槽位目录应创建成功");
        fs::write(root.join("unexpected-entry"), b"must-remain").expect("异常条目应写入成功");

        let locked = store
            .open_locked(false)
            .expect("测试槽目录应可固定")
            .expect("测试槽目录必须存在");
        let result = deletable_entry_names(&locked.directory);
        drop(locked);

        assert_eq!(result, Err(KelivoStatus::IoFailure));
        assert_eq!(
            fs::read(root.join("unexpected-entry")).expect("异常条目不得被删除"),
            b"must-remain"
        );
        fs::remove_dir_all(root).expect("测试目录应清理成功");
    }
}
