use super::{
    BACKGROUND_ACCESS_CAPABILITY, KEY_SLOT_ID_SIZE, KEY_SLOTS_CAPABILITY, KelivoStatus,
    LOCAL_KEY_SIZE, LocalKey, RECORD_ENVELOPES_CAPABILITY, SQLCIPHER_DATABASE_ATTACH_CAPABILITY,
    SQLCIPHER_KEY_APPLICATION_CAPABILITY,
};
use core::mem::size_of;
use std::{
    env,
    ffi::{OsStr, OsString},
    fs::{File, OpenOptions},
    io::{Read, Write},
    os::windows::{
        ffi::OsStrExt,
        fs::{MetadataExt, OpenOptionsExt},
        io::{AsRawHandle, FromRawHandle},
    },
    path::{Component, Path, PathBuf, Prefix},
    ptr, slice,
};
use windows_sys::{
    Wdk::{
        Foundation::OBJECT_ATTRIBUTES,
        Storage::FileSystem::{
            FILE_CREATE, FILE_DIRECTORY_FILE, FILE_NON_DIRECTORY_FILE, FILE_OPEN, FILE_OPEN_IF,
            FILE_OPEN_REPARSE_POINT, FILE_RENAME_INFORMATION, FILE_RENAME_INFORMATION_0,
            FILE_SYNCHRONOUS_IO_NONALERT, FileRenameInformation, NtCreateFile,
            NtSetInformationFile,
        },
    },
    Win32::{
        Foundation::{
            HANDLE, INVALID_HANDLE_VALUE, LocalFree, OBJ_CASE_INSENSITIVE, OBJ_DONT_REPARSE,
            STATUS_OBJECT_NAME_COLLISION, STATUS_OBJECT_NAME_NOT_FOUND,
            STATUS_OBJECT_PATH_NOT_FOUND, UNICODE_STRING,
        },
        Security::Cryptography::{
            BCRYPT_USE_SYSTEM_PREFERRED_RNG, BCryptGenRandom, CRYPT_INTEGER_BLOB,
            CRYPTPROTECT_UI_FORBIDDEN, CryptProtectData, CryptUnprotectData,
        },
        Storage::FileSystem::{
            DELETE, FILE_ATTRIBUTE_DIRECTORY, FILE_ATTRIBUTE_REPARSE_POINT, FILE_DISPOSITION_INFO,
            FILE_FLAG_BACKUP_SEMANTICS, FILE_FLAG_OPEN_REPARSE_POINT, FILE_READ_ATTRIBUTES,
            FILE_READ_DATA, FILE_SHARE_DELETE, FILE_SHARE_READ, FILE_SHARE_WRITE, FILE_TRAVERSE,
            FILE_WRITE_DATA, FileDispositionInfo, SYNCHRONIZE, SetFileInformationByHandle,
        },
        System::IO::IO_STATUS_BLOCK,
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

pub(super) fn create_slot(slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<LocalKey, KelivoStatus> {
    default_store()?.create_slot(slot_id)
}

pub(super) fn open_slot(slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<LocalKey, KelivoStatus> {
    default_store()?.open_slot(slot_id)
}

pub(super) fn delete_slot(slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<(), KelivoStatus> {
    default_store()?.delete_slot(slot_id)
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
        let directory = ensure_directory_chain(&self.root)?;
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
        let slot_name = Self::slot_name(slot_id);
        delete_slot_file(&directory, OsStr::new(&slot_name))
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
            FILE_READ_ATTRIBUTES | FILE_TRAVERSE | SYNCHRONIZE,
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
    use std::{fs, os::windows::fs::symlink_file, process::Command};

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
