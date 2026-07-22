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

    fn open_slot(&self, slot_id: &[u8; 16]) -> Result<LocalKey, KelivoStatus> {
        let encoded = read_slot_file(&self.slot_path(slot_id))?;
        let protected_key = decode_slot_file(&encoded)?;
        unprotect_key(protected_key, slot_id)
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

    fn slot_path(&self, slot_id: &[u8; 16]) -> PathBuf {
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
    let _lock = StoreLock::acquire(root)?;
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
            .open(root.join(".slot-store.lock"))
            .map_err(|_| KelivoStatus::IoFailure)?;
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
