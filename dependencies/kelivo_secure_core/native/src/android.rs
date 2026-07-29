use super::{
    BACKGROUND_ACCESS_CAPABILITY, KEY_SLOTS_CAPABILITY, KelivoStatus, LOCAL_KEY_SIZE, LocalKey,
    RECORD_ENVELOPES_CAPABILITY, SQLCIPHER_DATABASE_ATTACH_CAPABILITY,
    SQLCIPHER_KEY_APPLICATION_CAPABILITY,
};
use jni::{
    JNIEnv, JavaVM,
    objects::{GlobalRef, JClass, JObject, JString, JValue},
    sys::{JavaVM as RawJavaVm, jobject},
};
use std::{
    convert::TryFrom,
    ffi::{CStr, c_void},
    fs::{self, DirBuilder, File, OpenOptions},
    io::{ErrorKind, Read, Write},
    mem::size_of,
    os::{
        fd::AsRawFd,
        unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt},
    },
    path::{Path, PathBuf},
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
        self.ensure_root()?;
        let _lock = StoreLock::acquire(&self.root)?;
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
        self.write_atomic_locked(&slot_path, &encoded)?;
        Ok(key)
    }

    fn open_slot(&self, slot_id: &[u8; 16]) -> Result<LocalKey, KelivoStatus> {
        self.validate_existing_root()?;
        let _lock = StoreLock::acquire(&self.root)?;
        let encoded = read_slot_file(&self.slot_path(slot_id))?;
        let protected_key = decode_slot_file(&encoded)?;
        unprotect_key(protected_key, slot_id)
    }

    fn delete_slot(&self, slot_id: &[u8; 16]) -> Result<(), KelivoStatus> {
        self.ensure_root()?;
        let _lock = StoreLock::acquire(&self.root)?;
        // Keystore 主包装密钥由所有槽共享；删除它会误擦除其他账户，只移除本槽密文。
        match fs::remove_file(self.slot_path(slot_id)) {
            Ok(()) => sync_directory(&self.root),
            Err(error) if error.kind() == ErrorKind::NotFound => sync_directory(&self.root),
            Err(_) => Err(KelivoStatus::IoFailure),
        }
    }

    fn delete_all_slots(&self) -> Result<(), KelivoStatus> {
        self.ensure_root()?;
        let _lock = StoreLock::acquire(&self.root)?;
        let entries = self.deletable_entries()?;
        // 先摧毁共享包装根密钥；之后即使文件系统清理失败，旧槽密文也不可再解密。
        delete_wrapping_key()?;
        for path in entries {
            fs::remove_file(path).map_err(|_| KelivoStatus::IoFailure)?;
        }
        sync_directory(&self.root)
    }

    fn ensure_root(&self) -> Result<(), KelivoStatus> {
        let mut builder = DirBuilder::new();
        builder.recursive(true).mode(0o700);
        builder
            .create(&self.root)
            .map_err(|_| KelivoStatus::IoFailure)?;
        let metadata = fs::symlink_metadata(&self.root).map_err(|_| KelivoStatus::IoFailure)?;
        if !metadata.file_type().is_dir() {
            return Err(KelivoStatus::IoFailure);
        }
        fs::set_permissions(&self.root, fs::Permissions::from_mode(0o700))
            .map_err(|_| KelivoStatus::IoFailure)
    }

    fn validate_existing_root(&self) -> Result<(), KelivoStatus> {
        let metadata = match fs::symlink_metadata(&self.root) {
            Ok(metadata) => metadata,
            Err(error) if error.kind() == ErrorKind::NotFound => {
                return Err(KelivoStatus::SlotNotFound);
            }
            Err(_) => return Err(KelivoStatus::IoFailure),
        };
        if metadata.file_type().is_dir() {
            Ok(())
        } else {
            Err(KelivoStatus::IoFailure)
        }
    }

    fn deletable_entries(&self) -> Result<Vec<PathBuf>, KelivoStatus> {
        let mut entries = Vec::new();
        for entry in fs::read_dir(&self.root).map_err(|_| KelivoStatus::IoFailure)? {
            let entry = entry.map_err(|_| KelivoStatus::IoFailure)?;
            let name = entry
                .file_name()
                .into_string()
                .map_err(|_| KelivoStatus::IoFailure)?;
            if name == ".slot-store.lock" {
                continue;
            }
            let file_type = entry.file_type().map_err(|_| KelivoStatus::IoFailure)?;
            if !file_type.is_file()
                || (!is_slot_file_name(&name) && !is_temporary_slot_file_name(&name))
            {
                return Err(KelivoStatus::IoFailure);
            }
            entries.push(entry.path());
        }
        Ok(entries)
    }

    fn slot_path(&self, slot_id: &[u8; 16]) -> PathBuf {
        self.root.join(format!("{}.bin", encode_hex(slot_id)))
    }

    fn write_atomic_locked(&self, destination: &Path, contents: &[u8]) -> Result<(), KelivoStatus> {
        let (temporary_path, mut temporary_file) = self.create_temporary_file(destination)?;
        let write_result = temporary_file
            .write_all(contents)
            .and_then(|()| temporary_file.sync_all());
        drop(temporary_file);

        if write_result.is_err() {
            cleanup_temporary_file(&temporary_path)?;
            return Err(KelivoStatus::IoFailure);
        }

        match publish_without_replacement(&self.root, &temporary_path, destination) {
            Ok(()) => {
                cleanup_temporary_file(&temporary_path)?;
                sync_directory(&self.root)
            }
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
            match OpenOptions::new()
                .write(true)
                .create_new(true)
                .mode(0o600)
                .open(&path)
            {
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

fn publish_without_replacement(
    root: &Path,
    source: &Path,
    destination: &Path,
) -> Result<(), KelivoStatus> {
    match destination.try_exists() {
        Ok(true) => return Err(KelivoStatus::SlotAlreadyExists),
        Ok(false) => {}
        Err(_) => return Err(KelivoStatus::IoFailure),
    }
    fs::rename(source, destination).map_err(|_| KelivoStatus::IoFailure)?;
    sync_directory(root)
}

fn sync_directory(path: &Path) -> Result<(), KelivoStatus> {
    File::open(path)
        .and_then(|directory| directory.sync_all())
        .map_err(|_| KelivoStatus::IoFailure)
}

struct StoreLock(File);

impl StoreLock {
    fn acquire(root: &Path) -> Result<Self, KelivoStatus> {
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .mode(0o600)
            .custom_flags(libc::O_CLOEXEC | libc::O_NOFOLLOW)
            .open(root.join(".slot-store.lock"))
            .map_err(|_| KelivoStatus::IoFailure)?;
        if !file
            .metadata()
            .map_err(|_| KelivoStatus::IoFailure)?
            .file_type()
            .is_file()
        {
            return Err(KelivoStatus::IoFailure);
        }
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

fn read_slot_file(path: &Path) -> Result<Vec<u8>, KelivoStatus> {
    let file = match File::open(path) {
        Ok(file) => file,
        Err(error) if error.kind() == ErrorKind::NotFound => {
            return Err(KelivoStatus::SlotNotFound);
        }
        Err(_) => return Err(KelivoStatus::IoFailure),
    };
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

fn is_slot_file_name(name: &str) -> bool {
    name.len() == 36 && name.ends_with(".bin") && is_lower_hex(&name[..32])
}

fn is_temporary_slot_file_name(name: &str) -> bool {
    name.len() == 74
        && name.starts_with('.')
        && is_slot_file_name(&name[1..37])
        && &name[37..38] == "."
        && is_lower_hex(&name[38..70])
        && name.ends_with(".tmp")
}

fn is_lower_hex(value: &str) -> bool {
    value
        .bytes()
        .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_slots_delete_names_are_strict_and_include_legacy_temporary_files() {
        assert!(is_slot_file_name(&format!("{}.bin", "ab".repeat(16))));
        assert!(is_temporary_slot_file_name(&format!(
            ".{}.bin.{}.tmp",
            "ab".repeat(16),
            "cd".repeat(16)
        )));
        for invalid in [
            format!("{}.BIN", "ab".repeat(16)),
            format!("{}.bin", "AB".repeat(16)),
            ".slot-store.lock.tmp".to_owned(),
            "unexpected-entry".to_owned(),
        ] {
            assert!(!is_slot_file_name(&invalid));
            assert!(!is_temporary_slot_file_name(&invalid));
        }
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

        let result = store.deletable_entries();

        assert_eq!(result, Err(KelivoStatus::IoFailure));
        assert_eq!(
            fs::read(root.join("unexpected-entry")).expect("异常条目不得被删除"),
            b"must-remain"
        );
        fs::remove_dir_all(root).expect("测试目录应清理成功");
    }
}
