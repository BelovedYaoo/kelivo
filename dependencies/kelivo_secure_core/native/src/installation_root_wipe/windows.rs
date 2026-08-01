use crate::KelivoStatus;
use core::mem::size_of;
use std::{
    ffi::{OsStr, OsString},
    fs::{File, OpenOptions},
    os::windows::{
        ffi::{OsStrExt, OsStringExt},
        fs::OpenOptionsExt,
        io::{AsRawHandle, FromRawHandle},
    },
    path::{Component, Path, PathBuf, Prefix},
    ptr,
};
use windows_sys::{
    Wdk::{
        Foundation::OBJECT_ATTRIBUTES,
        Storage::FileSystem::{
            FILE_BOTH_DIR_INFORMATION, FILE_DIRECTORY_FILE, FILE_NON_DIRECTORY_FILE, FILE_OPEN,
            FILE_OPEN_REPARSE_POINT, FILE_SYNCHRONOUS_IO_NONALERT, FileBothDirectoryInformation,
            NtCreateFile, NtFlushBuffersFile, NtQueryDirectoryFile,
        },
    },
    Win32::{
        Foundation::{
            HANDLE, INVALID_HANDLE_VALUE, OBJ_DONT_REPARSE, STATUS_NO_MORE_FILES,
            STATUS_OBJECT_NAME_NOT_FOUND, STATUS_OBJECT_PATH_NOT_FOUND, UNICODE_STRING,
        },
        Storage::FileSystem::{
            BY_HANDLE_FILE_INFORMATION, DELETE, FILE_ATTRIBUTE_DIRECTORY,
            FILE_ATTRIBUTE_REPARSE_POINT, FILE_DISPOSITION_INFO, FILE_FLAG_BACKUP_SEMANTICS,
            FILE_FLAG_OPEN_REPARSE_POINT, FILE_LIST_DIRECTORY, FILE_READ_ATTRIBUTES,
            FILE_SHARE_READ, FILE_SHARE_WRITE, FILE_TRAVERSE, FILE_WRITE_DATA, FileDispositionInfo,
            GetFileInformationByHandle, SYNCHRONIZE, SetFileInformationByHandle,
        },
        System::IO::IO_STATUS_BLOCK,
    },
};

const DIRECTORY_QUERY_BUFFER_SIZE: usize = 64 * 1024;
const MAX_RELATIVE_NAME_CODE_UNITS: usize = 255;
const MAX_DIRECTORY_DEPTH: usize = 128;
const SHARE_READ_WRITE: u32 = FILE_SHARE_READ | FILE_SHARE_WRITE;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct FileIdentity {
    volume_serial: u32,
    file_index: u64,
}

#[derive(Clone, Copy)]
struct FileMetadata {
    identity: FileIdentity,
    attributes: u32,
    links: u32,
}

struct PinnedMarker {
    file: File,
    identity: FileIdentity,
}

pub(super) fn wipe(root_path: &str, preserved_entry_name: &str) -> Result<(), KelivoStatus> {
    wipe_after_marker_pinned(root_path, preserved_entry_name, || {})
}

fn wipe_after_marker_pinned(
    root_path: &str,
    preserved_entry_name: &str,
    after_marker_pinned: impl FnOnce(),
) -> Result<(), KelivoStatus> {
    let preserved_name = validate_preserved_name(preserved_entry_name)?;
    let root = open_installation_root(root_path)?;
    let root_metadata = metadata_for(&root)?;
    require_directory(root_metadata)?;
    let marker = pin_marker(&root, &preserved_name, root_metadata.identity.volume_serial)?;

    after_marker_pinned();
    wipe_directory(
        &root,
        &preserved_name,
        root_metadata.identity.volume_serial,
        marker.identity,
        0,
    )?;
    verify_only_marker(&root, &preserved_name, marker.identity)?;

    let final_marker = open_preserved_regular_relative(&root, &preserved_name)?;
    let final_metadata = metadata_for(&final_marker)?;
    require_regular(final_metadata)?;
    if final_metadata.identity != marker.identity || final_metadata.links != 1 {
        return Err(KelivoStatus::IoFailure);
    }
    flush(&marker.file)?;
    flush(&final_marker)?;
    flush(&root)
}

fn validate_preserved_name(name: &str) -> Result<OsString, KelivoStatus> {
    if name
        .chars()
        .any(|character| matches!(character, '/' | '\\' | ':'))
    {
        return Err(KelivoStatus::InvalidArgument);
    }
    let value = OsString::from(name);
    let encoded = encode_relative_name(&value)?;
    if encoded.len() > MAX_RELATIVE_NAME_CODE_UNITS {
        return Err(KelivoStatus::InvalidArgument);
    }
    Ok(value)
}

fn open_installation_root(path: &str) -> Result<File, KelivoStatus> {
    validate_disk_path_text(path)?;
    let (volume_root, components) = split_disk_path(Path::new(path))?;
    if components.is_empty() {
        return Err(KelivoStatus::InvalidArgument);
    }
    let mut directory = open_volume_root(&volume_root)?;
    for (index, component) in components.iter().enumerate() {
        let is_installation_root = index + 1 == components.len();
        let desired_access = FILE_LIST_DIRECTORY
            | FILE_READ_ATTRIBUTES
            | FILE_TRAVERSE
            | SYNCHRONIZE
            | if is_installation_root {
                FILE_WRITE_DATA
            } else {
                0
            };
        directory = match open_relative(&directory, component, desired_access, FILE_DIRECTORY_FILE)?
        {
            RelativeOpenResult::Opened(child) => child,
            RelativeOpenResult::Missing => return Err(KelivoStatus::IoFailure),
        };
        require_directory(metadata_for(&directory)?)?;
    }
    Ok(directory)
}

fn validate_disk_path_text(path: &str) -> Result<(), KelivoStatus> {
    let bytes = path.as_bytes();
    if bytes.len() < 4
        || !bytes[0].is_ascii_alphabetic()
        || bytes[1] != b':'
        || !matches!(bytes[2], b'/' | b'\\')
        || matches!(bytes.last(), Some(b'/' | b'\\'))
    {
        return Err(KelivoStatus::InvalidArgument);
    }
    if path[3..]
        .split(['/', '\\'])
        .any(|component| component.is_empty() || matches!(component, "." | ".."))
    {
        return Err(KelivoStatus::InvalidArgument);
    }
    Ok(())
}

fn split_disk_path(path: &Path) -> Result<(PathBuf, Vec<OsString>), KelivoStatus> {
    let mut components = path.components();
    let prefix = match components.next() {
        Some(Component::Prefix(prefix)) if matches!(prefix.kind(), Prefix::Disk(_)) => prefix,
        _ => return Err(KelivoStatus::InvalidArgument),
    };
    let root = match components.next() {
        Some(Component::RootDir) => Component::RootDir,
        _ => return Err(KelivoStatus::InvalidArgument),
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
            | Component::ParentDir => return Err(KelivoStatus::InvalidArgument),
        }
    }
    Ok((volume_root, names))
}

fn open_volume_root(path: &Path) -> Result<File, KelivoStatus> {
    let file = OpenOptions::new()
        .access_mode(FILE_READ_ATTRIBUTES | FILE_TRAVERSE)
        .share_mode(SHARE_READ_WRITE)
        .custom_flags(FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT)
        .open(path)
        .map_err(|_| KelivoStatus::IoFailure)?;
    require_directory(metadata_for(&file)?)?;
    Ok(file)
}

enum RelativeOpenResult {
    Opened(File),
    Missing,
}

fn open_relative(
    parent: &File,
    name: &OsStr,
    desired_access: u32,
    required_type: u32,
) -> Result<RelativeOpenResult, KelivoStatus> {
    let mut encoded_name = encode_relative_name(name)?;
    let name_length = u16::try_from(encoded_name.len() * size_of::<u16>())
        .map_err(|_| KelivoStatus::InvalidArgument)?;
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
        Attributes: OBJ_DONT_REPARSE,
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
            SHARE_READ_WRITE,
            FILE_OPEN,
            required_type | FILE_OPEN_REPARSE_POINT | FILE_SYNCHRONOUS_IO_NONALERT,
            ptr::null(),
            0,
        )
    };
    if status >= 0 {
        if handle.is_null() || handle == INVALID_HANDLE_VALUE {
            return Err(KelivoStatus::IoFailure);
        }
        return Ok(RelativeOpenResult::Opened(unsafe {
            File::from_raw_handle(handle)
        }));
    }
    if !handle.is_null() && handle != INVALID_HANDLE_VALUE {
        drop(unsafe { File::from_raw_handle(handle) });
    }
    match status {
        STATUS_OBJECT_NAME_NOT_FOUND | STATUS_OBJECT_PATH_NOT_FOUND => {
            Ok(RelativeOpenResult::Missing)
        }
        _ => Err(KelivoStatus::IoFailure),
    }
}

fn open_regular_relative(parent: &File, name: &OsStr) -> Result<File, KelivoStatus> {
    let file = match open_relative(
        parent,
        name,
        FILE_WRITE_DATA | FILE_READ_ATTRIBUTES | DELETE | SYNCHRONIZE,
        FILE_NON_DIRECTORY_FILE,
    )? {
        RelativeOpenResult::Opened(file) => file,
        RelativeOpenResult::Missing => return Err(KelivoStatus::IoFailure),
    };
    require_regular(metadata_for(&file)?)?;
    Ok(file)
}

fn open_preserved_regular_relative(parent: &File, name: &OsStr) -> Result<File, KelivoStatus> {
    let file = match open_relative(
        parent,
        name,
        FILE_WRITE_DATA | FILE_READ_ATTRIBUTES | SYNCHRONIZE,
        FILE_NON_DIRECTORY_FILE,
    )? {
        RelativeOpenResult::Opened(file) => file,
        RelativeOpenResult::Missing => return Err(KelivoStatus::IoFailure),
    };
    require_regular(metadata_for(&file)?)?;
    Ok(file)
}

fn open_directory_relative(parent: &File, name: &OsStr) -> Result<File, KelivoStatus> {
    let directory = match open_relative(
        parent,
        name,
        FILE_LIST_DIRECTORY
            | FILE_READ_ATTRIBUTES
            | FILE_TRAVERSE
            | FILE_WRITE_DATA
            | DELETE
            | SYNCHRONIZE,
        FILE_DIRECTORY_FILE,
    )? {
        RelativeOpenResult::Opened(file) => file,
        RelativeOpenResult::Missing => return Err(KelivoStatus::IoFailure),
    };
    require_directory(metadata_for(&directory)?)?;
    Ok(directory)
}

fn encode_relative_name(name: &OsStr) -> Result<Vec<u16>, KelivoStatus> {
    let mut components = Path::new(name).components();
    if !matches!(components.next(), Some(Component::Normal(_))) || components.next().is_some() {
        return Err(KelivoStatus::InvalidArgument);
    }
    let encoded: Vec<u16> = name.encode_wide().collect();
    if encoded.is_empty() || encoded.len() > MAX_RELATIVE_NAME_CODE_UNITS || encoded.contains(&0) {
        return Err(KelivoStatus::InvalidArgument);
    }
    Ok(encoded)
}

fn pin_marker(
    root: &File,
    name: &OsStr,
    root_volume_serial: u32,
) -> Result<PinnedMarker, KelivoStatus> {
    let exact_entry = enumerate_directory_entries(root)?
        .into_iter()
        .find(|entry| entry.name == name)
        .ok_or(KelivoStatus::IoFailure)?;
    require_regular_attributes(exact_entry.attributes)?;
    let file = open_preserved_regular_relative(root, name)?;
    let metadata = metadata_for(&file)?;
    if metadata.identity.volume_serial != root_volume_serial || metadata.links != 1 {
        return Err(KelivoStatus::IoFailure);
    }
    flush(&file)?;
    Ok(PinnedMarker {
        file,
        identity: metadata.identity,
    })
}

fn wipe_directory(
    directory: &File,
    preserved_name: &OsStr,
    root_volume_serial: u32,
    marker_identity: FileIdentity,
    depth: usize,
) -> Result<(), KelivoStatus> {
    if depth >= MAX_DIRECTORY_DEPTH {
        return Err(KelivoStatus::InputTooLarge);
    }
    for entry in enumerate_directory_entries(directory)? {
        if depth == 0 && entry.name == preserved_name {
            continue;
        }
        if entry.attributes & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
            return Err(KelivoStatus::IoFailure);
        }
        if entry.attributes & FILE_ATTRIBUTE_DIRECTORY != 0 {
            let child = open_directory_relative(directory, &entry.name)?;
            let metadata = metadata_for(&child)?;
            if metadata.identity.volume_serial != root_volume_serial {
                return Err(KelivoStatus::IoFailure);
            }
            wipe_directory(
                &child,
                preserved_name,
                root_volume_serial,
                marker_identity,
                depth + 1,
            )?;
            flush(&child)?;
            delete_handle(child)?;
            flush(directory)?;
        } else {
            let file = open_regular_relative(directory, &entry.name)?;
            let metadata = metadata_for(&file)?;
            if metadata.identity.volume_serial != root_volume_serial || metadata.links != 1 {
                return Err(KelivoStatus::IoFailure);
            }
            if metadata.identity == marker_identity {
                continue;
            }
            flush(&file)?;
            delete_handle(file)?;
            flush(directory)?;
        }
    }
    Ok(())
}

fn verify_only_marker(
    root: &File,
    preserved_name: &OsStr,
    marker_identity: FileIdentity,
) -> Result<(), KelivoStatus> {
    let entries = enumerate_directory_entries(root)?;
    if entries.len() != 1 || entries[0].name != preserved_name {
        return Err(KelivoStatus::IoFailure);
    }
    let marker = open_preserved_regular_relative(root, preserved_name)?;
    let metadata = metadata_for(&marker)?;
    if metadata.identity == marker_identity && metadata.links == 1 {
        Ok(())
    } else {
        Err(KelivoStatus::IoFailure)
    }
}

fn metadata_for(file: &File) -> Result<FileMetadata, KelivoStatus> {
    let mut output = BY_HANDLE_FILE_INFORMATION::default();
    if unsafe { GetFileInformationByHandle(file.as_raw_handle(), &mut output) } == 0 {
        return Err(KelivoStatus::IoFailure);
    }
    Ok(FileMetadata {
        identity: FileIdentity {
            volume_serial: output.dwVolumeSerialNumber,
            file_index: (u64::from(output.nFileIndexHigh) << 32) | u64::from(output.nFileIndexLow),
        },
        attributes: output.dwFileAttributes,
        links: output.nNumberOfLinks,
    })
}

fn require_directory(metadata: FileMetadata) -> Result<(), KelivoStatus> {
    if metadata.attributes & FILE_ATTRIBUTE_REPARSE_POINT == 0
        && metadata.attributes & FILE_ATTRIBUTE_DIRECTORY != 0
    {
        Ok(())
    } else {
        Err(KelivoStatus::IoFailure)
    }
}

fn require_regular(metadata: FileMetadata) -> Result<(), KelivoStatus> {
    require_regular_attributes(metadata.attributes)
}

fn require_regular_attributes(attributes: u32) -> Result<(), KelivoStatus> {
    if attributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY) == 0 {
        Ok(())
    } else {
        Err(KelivoStatus::IoFailure)
    }
}

fn flush(file: &File) -> Result<(), KelivoStatus> {
    let mut io_status = IO_STATUS_BLOCK::default();
    if unsafe { NtFlushBuffersFile(file.as_raw_handle(), &mut io_status) } >= 0 {
        Ok(())
    } else {
        Err(KelivoStatus::IoFailure)
    }
}

fn delete_handle(file: File) -> Result<(), KelivoStatus> {
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
    drop(file);
    Ok(())
}

struct DirectoryEntry {
    name: OsString,
    attributes: u32,
}

fn enumerate_directory_entries(directory: &File) -> Result<Vec<DirectoryEntry>, KelivoStatus> {
    let word_count = DIRECTORY_QUERY_BUFFER_SIZE.div_ceil(size_of::<u64>());
    let mut buffer = vec![0_u64; word_count];
    let mut entries = Vec::new();
    let mut restart_scan = true;
    loop {
        let mut io_status = IO_STATUS_BLOCK::default();
        let status = unsafe {
            NtQueryDirectoryFile(
                directory.as_raw_handle(),
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::{
        cell::Cell,
        fs,
        process::Command,
        sync::atomic::{AtomicUsize, Ordering},
    };

    static TEST_SEQUENCE: AtomicUsize = AtomicUsize::new(1);

    struct TestRoot(PathBuf);

    impl TestRoot {
        fn new(label: &str) -> Self {
            let root = std::env::temp_dir().join(format!(
                "kelivo-root-wipe-{label}-{}-{}",
                std::process::id(),
                TEST_SEQUENCE.fetch_add(1, Ordering::Relaxed)
            ));
            fs::create_dir(&root).expect("隔离测试根必须创建成功");
            Self(root)
        }

        fn path_text(&self) -> &str {
            self.0.to_str().expect("测试路径必须是 UTF-8")
        }
    }

    impl Drop for TestRoot {
        fn drop(&mut self) {
            let temporary = fs::canonicalize(std::env::temp_dir()).expect("临时根必须可解析");
            if let Ok(root) = fs::canonicalize(&self.0) {
                assert!(root.starts_with(&temporary), "测试清理不得越出临时根");
            }
            let _ = fs::remove_dir_all(&self.0);
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
    fn nested_contents_are_wiped_and_marker_is_preserved() {
        let root = TestRoot::new("nested");
        fs::write(root.0.join("wipe-complete"), b"done").expect("标记必须写入成功");
        fs::create_dir(root.0.join("nested")).expect("嵌套目录必须创建成功");
        fs::write(root.0.join("nested/data.bin"), b"secret").expect("样本必须写入成功");

        wipe(root.path_text(), "wipe-complete").expect("安装根擦除必须成功");

        let names: Vec<_> = fs::read_dir(&root.0)
            .expect("测试根必须可枚举")
            .map(|entry| entry.expect("目录项必须有效").file_name())
            .collect();
        assert_eq!(names, ["wipe-complete"]);
        assert_eq!(fs::read(root.0.join("wipe-complete")).unwrap(), b"done");
    }

    #[test]
    fn nested_junction_is_rejected_without_touching_external_target() {
        let root = TestRoot::new("junction");
        let external = TestRoot::new("external");
        fs::write(root.0.join("wipe-complete"), b"done").unwrap();
        fs::create_dir(root.0.join("nested")).unwrap();
        fs::write(external.0.join("sentinel"), b"outside").unwrap();
        let junction = root.0.join("nested").join("link");
        create_directory_junction(&junction, &external.0);

        assert_eq!(
            wipe(root.path_text(), "wipe-complete"),
            Err(KelivoStatus::IoFailure)
        );
        assert_eq!(fs::read(external.0.join("sentinel")).unwrap(), b"outside");
        fs::remove_dir(&junction).expect("测试 junction 必须在递归清理前解除");
    }

    #[test]
    fn pinned_marker_cannot_be_renamed_during_wipe() {
        let root = TestRoot::new("marker-replaced");
        let marker = root.0.join("wipe-complete");
        fs::write(&marker, b"original").unwrap();
        fs::write(root.0.join("data"), b"secret").unwrap();
        let rename_was_blocked = Cell::new(false);

        let result = wipe_after_marker_pinned(root.path_text(), "wipe-complete", || {
            rename_was_blocked.set(fs::rename(&marker, root.0.join("original-marker")).is_err());
        });

        result.expect("标记句柄固定期间重命名必须被内核阻断");
        assert!(rename_was_blocked.get());
        assert_eq!(fs::read(&marker).unwrap(), b"original");
    }

    #[test]
    fn pinned_root_cannot_be_replaced_during_wipe() {
        let root = TestRoot::new("root-replaced");
        fs::write(root.0.join("wipe-complete"), b"done").unwrap();
        fs::write(root.0.join("data"), b"secret").unwrap();
        let replacement_was_blocked = Cell::new(false);

        let result = wipe_after_marker_pinned(root.path_text(), "wipe-complete", || {
            replacement_was_blocked
                .set(fs::rename(&root.0, root.0.with_extension("moved")).is_err());
        });

        result.expect("根句柄固定期间替换必须被内核阻断");
        assert!(replacement_was_blocked.get());
        assert_eq!(fs::read(root.0.join("wipe-complete")).unwrap(), b"done");
    }

    #[test]
    fn pinned_child_cannot_be_renamed() {
        let root = TestRoot::new("rename-locked");
        fs::create_dir(root.0.join("nested")).unwrap();
        let root_handle = open_installation_root(root.path_text()).unwrap();
        let child = open_directory_relative(&root_handle, OsStr::new("nested")).unwrap();

        assert!(fs::rename(root.0.join("nested"), root.0.join("moved")).is_err());

        drop(child);
        fs::rename(root.0.join("nested"), root.0.join("moved"))
            .expect("子目录句柄释放后重命名应恢复");
    }

    #[test]
    fn failed_wipe_can_be_retried_idempotently() {
        let root = TestRoot::new("retry");
        fs::write(root.0.join("wipe-complete"), b"done").unwrap();
        fs::write(root.0.join("first"), b"secret").unwrap();
        let blocked_path = root.0.join("z-blocked");
        fs::write(&blocked_path, b"locked").unwrap();
        let blocker = OpenOptions::new()
            .read(true)
            .share_mode(FILE_SHARE_READ)
            .open(&blocked_path)
            .unwrap();

        assert_eq!(
            wipe(root.path_text(), "wipe-complete"),
            Err(KelivoStatus::IoFailure)
        );
        drop(blocker);
        wipe(root.path_text(), "wipe-complete").expect("关闭阻断句柄后必须可幂等重试");
    }

    #[test]
    fn root_and_marker_inputs_are_strict() {
        assert_eq!(
            wipe("C:\\", "wipe-complete"),
            Err(KelivoStatus::InvalidArgument)
        );
        assert_eq!(
            wipe("C:\\temp\\..\\temp", "wipe-complete"),
            Err(KelivoStatus::InvalidArgument)
        );
        let root = TestRoot::new("invalid-marker");
        assert_eq!(
            wipe(root.path_text(), "nested\\marker"),
            Err(KelivoStatus::InvalidArgument)
        );
    }
}
