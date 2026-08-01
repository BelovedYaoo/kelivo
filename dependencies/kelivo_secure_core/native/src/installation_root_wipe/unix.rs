use crate::KelivoStatus;
use std::{
    ffi::{CStr, CString},
    fs::File,
    os::fd::{AsRawFd, FromRawFd},
};

const MAX_COMPONENT_BYTES: usize = 255;
const MAX_DIRECTORY_DEPTH: usize = 128;
// 当前 libc 版本未在所有 Android 架构导出该常量；437 是这些 Linux UAPI 架构的稳定编号。
const SYS_OPENAT2: libc::c_long = 437;
const RESOLVE_NO_XDEV: u64 = 0x01;
const RESOLVE_NO_SYMLINKS: u64 = 0x04;
const RESOLVE_BENEATH: u64 = 0x08;

#[repr(C)]
struct OpenHow {
    flags: u64,
    mode: u64,
    resolve: u64,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct FileIdentity {
    device: u64,
    inode: u64,
    kind: u32,
}

#[derive(Clone, Copy)]
struct FileMetadata {
    identity: FileIdentity,
    links: u64,
}

struct PinnedMarker {
    file: File,
    identity: FileIdentity,
}

pub(super) fn is_supported() -> bool {
    open_beneath_no_mount(
        libc::AT_FDCWD,
        c".",
        libc::O_RDONLY | libc::O_DIRECTORY | libc::O_CLOEXEC,
    )
    .map(drop)
    .is_ok()
}

pub(super) fn wipe(root_path: &str, preserved_entry_name: &str) -> Result<(), KelivoStatus> {
    if !is_supported() {
        return Err(KelivoStatus::UnsupportedPlatform);
    }
    wipe_after_marker_pinned(root_path, preserved_entry_name, || {})
}

fn wipe_after_marker_pinned(
    root_path: &str,
    preserved_entry_name: &str,
    after_marker_pinned: impl FnOnce(),
) -> Result<(), KelivoStatus> {
    validate_absolute_path(root_path)?;
    let preserved_name = validate_entry_name(preserved_entry_name)?;
    let root = open_absolute_directory(root_path)?;
    let root_metadata = metadata_for(&root)?;
    require_directory(root_metadata)?;
    lock_root_exclusively(&root)?;
    let marker = pin_marker(&root, &preserved_name, root_metadata.identity.device)?;

    after_marker_pinned();
    wipe_directory(&root, root_metadata.identity.device, marker.identity, 0)?;
    verify_only_marker(&root, &preserved_name, marker.identity)?;

    let final_marker = open_regular_relative(&root, &preserved_name)?;
    let final_metadata = metadata_for(&final_marker)?;
    require_regular(final_metadata)?;
    if final_metadata.identity != marker.identity || final_metadata.links != 1 {
        return Err(KelivoStatus::IoFailure);
    }
    marker
        .file
        .sync_all()
        .map_err(|_| KelivoStatus::IoFailure)?;
    final_marker
        .sync_all()
        .map_err(|_| KelivoStatus::IoFailure)?;
    root.sync_all().map_err(|_| KelivoStatus::IoFailure)
}

fn lock_root_exclusively(root: &File) -> Result<(), KelivoStatus> {
    // Android 可能存在同 UID 多进程，根目录锁把所有遵守安装级协议的写者排除在擦除窗口外。
    if unsafe { libc::flock(root.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } == 0 {
        Ok(())
    } else {
        Err(KelivoStatus::IoFailure)
    }
}

fn validate_absolute_path(path: &str) -> Result<(), KelivoStatus> {
    let bytes = path.as_bytes();
    if bytes.len() <= 1 || bytes.first() != Some(&b'/') || bytes.last() == Some(&b'/') {
        return Err(KelivoStatus::InvalidArgument);
    }
    for component in bytes[1..].split(|byte| *byte == b'/') {
        if component.is_empty()
            || component == b"."
            || component == b".."
            || component.len() > MAX_COMPONENT_BYTES
        {
            return Err(KelivoStatus::InvalidArgument);
        }
    }
    Ok(())
}

fn validate_entry_name(name: &str) -> Result<CString, KelivoStatus> {
    let bytes = name.as_bytes();
    if bytes.is_empty()
        || bytes.len() > MAX_COMPONENT_BYTES
        || bytes == b"."
        || bytes == b".."
        || bytes.contains(&b'/')
    {
        return Err(KelivoStatus::InvalidArgument);
    }
    CString::new(bytes).map_err(|_| KelivoStatus::InvalidArgument)
}

fn open_absolute_directory(path: &str) -> Result<File, KelivoStatus> {
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
    for component in path.as_bytes()[1..].split(|byte| *byte == b'/') {
        let component = CString::new(component).map_err(|_| KelivoStatus::InvalidArgument)?;
        directory = open_root_component_relative(&directory, &component)?;
    }
    Ok(directory)
}

fn open_root_component_relative(parent: &File, name: &CStr) -> Result<File, KelivoStatus> {
    let fd = unsafe {
        libc::openat(
            parent.as_raw_fd(),
            name.as_ptr(),
            libc::O_RDONLY | libc::O_DIRECTORY | libc::O_CLOEXEC | libc::O_NOFOLLOW,
        )
    };
    if fd < 0 {
        return Err(KelivoStatus::IoFailure);
    }
    let directory = unsafe { File::from_raw_fd(fd) };
    require_directory(metadata_for(&directory)?)?;
    Ok(directory)
}

fn open_directory_relative(parent: &File, name: &CStr) -> Result<File, KelivoStatus> {
    let directory = open_beneath_no_mount(
        parent.as_raw_fd(),
        name,
        libc::O_RDONLY | libc::O_DIRECTORY | libc::O_CLOEXEC | libc::O_NOFOLLOW,
    )?;
    require_directory(metadata_for(&directory)?)?;
    Ok(directory)
}

fn open_regular_relative(parent: &File, name: &CStr) -> Result<File, KelivoStatus> {
    let before = metadata_at(parent, name)?;
    require_regular(before)?;
    let file = open_beneath_no_mount(
        parent.as_raw_fd(),
        name,
        libc::O_RDONLY | libc::O_CLOEXEC | libc::O_NOFOLLOW | libc::O_NONBLOCK,
    )?;
    let opened = metadata_for(&file)?;
    require_regular(opened)?;
    if before.identity != opened.identity || before.links != opened.links {
        return Err(KelivoStatus::IoFailure);
    }
    Ok(file)
}

fn open_beneath_no_mount(
    parent_fd: libc::c_int,
    name: &CStr,
    flags: libc::c_int,
) -> Result<File, KelivoStatus> {
    // st_dev 无法识别同一文件系统的 bind mount，必须由内核在路径解析阶段阻断挂载跨越。
    let how = OpenHow {
        flags: u64::try_from(flags).map_err(|_| KelivoStatus::InternalState)?,
        mode: 0,
        resolve: RESOLVE_NO_XDEV | RESOLVE_NO_SYMLINKS | RESOLVE_BENEATH,
    };
    let raw_fd = unsafe {
        libc::syscall(
            SYS_OPENAT2,
            parent_fd,
            name.as_ptr(),
            &how,
            std::mem::size_of::<OpenHow>(),
        )
    };
    if raw_fd < 0 {
        return Err(KelivoStatus::IoFailure);
    }
    let fd = libc::c_int::try_from(raw_fd).map_err(|_| KelivoStatus::InternalState)?;
    Ok(unsafe { File::from_raw_fd(fd) })
}

fn pin_marker(root: &File, name: &CStr, root_device: u64) -> Result<PinnedMarker, KelivoStatus> {
    let file = open_regular_relative(root, name)?;
    let metadata = metadata_for(&file)?;
    if metadata.identity.device != root_device || metadata.links != 1 {
        return Err(KelivoStatus::IoFailure);
    }
    file.sync_all().map_err(|_| KelivoStatus::IoFailure)?;
    Ok(PinnedMarker {
        file,
        identity: metadata.identity,
    })
}

fn wipe_directory(
    directory: &File,
    root_device: u64,
    marker_identity: FileIdentity,
    depth: usize,
) -> Result<(), KelivoStatus> {
    if depth >= MAX_DIRECTORY_DEPTH {
        return Err(KelivoStatus::InputTooLarge);
    }
    for name in directory_entry_names(directory)? {
        let metadata = metadata_at(directory, &name)?;
        if metadata.identity.device != root_device {
            return Err(KelivoStatus::IoFailure);
        }
        if metadata.identity.kind == normalized_u32(libc::S_IFREG) {
            let file = open_regular_relative(directory, &name)?;
            let opened = metadata_for(&file)?;
            if opened.identity.device != root_device || opened.links != 1 {
                return Err(KelivoStatus::IoFailure);
            }
            if opened.identity == marker_identity {
                continue;
            }
            file.sync_all().map_err(|_| KelivoStatus::IoFailure)?;
            ensure_named_identity(directory, &name, opened.identity)?;
            if unsafe { libc::unlinkat(directory.as_raw_fd(), name.as_ptr(), 0) } != 0 {
                return Err(KelivoStatus::IoFailure);
            }
            directory.sync_all().map_err(|_| KelivoStatus::IoFailure)?;
        } else if metadata.identity.kind == normalized_u32(libc::S_IFDIR) {
            let child = open_directory_relative(directory, &name)?;
            let opened = metadata_for(&child)?;
            if opened.identity != metadata.identity || opened.identity.device != root_device {
                return Err(KelivoStatus::IoFailure);
            }
            wipe_directory(&child, root_device, marker_identity, depth + 1)?;
            child.sync_all().map_err(|_| KelivoStatus::IoFailure)?;
            ensure_named_identity(directory, &name, opened.identity)?;
            if unsafe { libc::unlinkat(directory.as_raw_fd(), name.as_ptr(), libc::AT_REMOVEDIR) }
                != 0
            {
                return Err(KelivoStatus::IoFailure);
            }
            directory.sync_all().map_err(|_| KelivoStatus::IoFailure)?;
        } else {
            return Err(KelivoStatus::IoFailure);
        }
    }
    Ok(())
}

fn verify_only_marker(
    root: &File,
    preserved_name: &CStr,
    marker_identity: FileIdentity,
) -> Result<(), KelivoStatus> {
    let entries = directory_entry_names(root)?;
    if entries.len() != 1 || entries[0].as_bytes() != preserved_name.to_bytes() {
        return Err(KelivoStatus::IoFailure);
    }
    let marker = open_regular_relative(root, preserved_name)?;
    let metadata = metadata_for(&marker)?;
    if metadata.identity == marker_identity && metadata.links == 1 {
        Ok(())
    } else {
        Err(KelivoStatus::IoFailure)
    }
}

fn ensure_named_identity(
    directory: &File,
    name: &CStr,
    expected: FileIdentity,
) -> Result<(), KelivoStatus> {
    if metadata_at(directory, name)?.identity == expected {
        Ok(())
    } else {
        Err(KelivoStatus::IoFailure)
    }
}

fn metadata_for(file: &File) -> Result<FileMetadata, KelivoStatus> {
    let mut output = std::mem::MaybeUninit::<libc::stat>::zeroed();
    if unsafe { libc::fstat(file.as_raw_fd(), output.as_mut_ptr()) } != 0 {
        return Err(KelivoStatus::IoFailure);
    }
    Ok(metadata_from_stat(unsafe { output.assume_init() }))
}

fn metadata_at(directory: &File, name: &CStr) -> Result<FileMetadata, KelivoStatus> {
    let mut output = std::mem::MaybeUninit::<libc::stat>::zeroed();
    if unsafe {
        libc::fstatat(
            directory.as_raw_fd(),
            name.as_ptr(),
            output.as_mut_ptr(),
            libc::AT_SYMLINK_NOFOLLOW,
        )
    } != 0
    {
        return Err(KelivoStatus::IoFailure);
    }
    Ok(metadata_from_stat(unsafe { output.assume_init() }))
}

fn metadata_from_stat(value: libc::stat) -> FileMetadata {
    FileMetadata {
        identity: FileIdentity {
            device: normalized_u64(value.st_dev),
            inode: normalized_u64(value.st_ino),
            kind: normalized_u32(value.st_mode) & normalized_u32(libc::S_IFMT),
        },
        links: normalized_u64(value.st_nlink),
    }
}

fn normalized_u64(value: impl Into<u64>) -> u64 {
    value.into()
}

fn normalized_u32(value: impl Into<u32>) -> u32 {
    value.into()
}

fn require_directory(metadata: FileMetadata) -> Result<(), KelivoStatus> {
    if metadata.identity.kind == normalized_u32(libc::S_IFDIR) {
        Ok(())
    } else {
        Err(KelivoStatus::IoFailure)
    }
}

fn require_regular(metadata: FileMetadata) -> Result<(), KelivoStatus> {
    if metadata.identity.kind == normalized_u32(libc::S_IFREG) {
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

fn directory_entry_names(directory: &File) -> Result<Vec<CString>, KelivoStatus> {
    let fd = unsafe {
        libc::openat(
            directory.as_raw_fd(),
            c".".as_ptr(),
            libc::O_RDONLY | libc::O_DIRECTORY | libc::O_CLOEXEC | libc::O_NOFOLLOW,
        )
    };
    if fd < 0 {
        return Err(KelivoStatus::IoFailure);
    }
    let raw_stream = unsafe { libc::fdopendir(fd) };
    if raw_stream.is_null() {
        unsafe { libc::close(fd) };
        return Err(KelivoStatus::IoFailure);
    }
    let stream = DirectoryStream(raw_stream);
    let mut names = Vec::new();
    loop {
        set_errno(0);
        let entry = unsafe { libc::readdir(stream.0) };
        if entry.is_null() {
            return if current_errno() == 0 {
                Ok(names)
            } else {
                Err(KelivoStatus::IoFailure)
            };
        }
        let name = unsafe { CStr::from_ptr((*entry).d_name.as_ptr()) };
        if name.to_bytes() == b"." || name.to_bytes() == b".." {
            continue;
        }
        names.push(CString::new(name.to_bytes()).map_err(|_| KelivoStatus::IoFailure)?);
    }
}

#[cfg(target_os = "android")]
fn errno_location() -> *mut libc::c_int {
    unsafe { libc::__errno() }
}

#[cfg(target_os = "linux")]
fn errno_location() -> *mut libc::c_int {
    unsafe { libc::__errno_location() }
}

fn set_errno(value: libc::c_int) {
    unsafe { *errno_location() = value };
}

fn current_errno() -> libc::c_int {
    unsafe { *errno_location() }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::{
        fs,
        os::unix::{ffi::OsStrExt, fs::symlink},
        path::PathBuf,
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
    fn nested_symlink_is_rejected_without_touching_external_target() {
        let root = TestRoot::new("symlink");
        let external = TestRoot::new("external");
        fs::write(root.0.join("wipe-complete"), b"done").unwrap();
        fs::create_dir(root.0.join("nested")).unwrap();
        fs::write(external.0.join("sentinel"), b"outside").unwrap();
        symlink(&external.0, root.0.join("nested/link")).unwrap();

        assert_eq!(
            wipe(root.path_text(), "wipe-complete"),
            Err(KelivoStatus::IoFailure)
        );
        assert_eq!(fs::read(external.0.join("sentinel")).unwrap(), b"outside");
    }

    #[test]
    fn marker_inode_replacement_fails_closed() {
        let root = TestRoot::new("marker-replaced");
        let marker = root.0.join("wipe-complete");
        fs::write(&marker, b"original").unwrap();
        fs::write(root.0.join("data"), b"secret").unwrap();

        let result = wipe_after_marker_pinned(root.path_text(), "wipe-complete", || {
            fs::rename(&marker, root.0.join("original-marker")).unwrap();
            fs::write(&marker, b"replacement").unwrap();
        });

        assert_eq!(result, Err(KelivoStatus::IoFailure));
        assert_eq!(
            fs::read(root.0.join("original-marker")).unwrap(),
            b"original"
        );
    }

    #[test]
    fn marker_symlink_replacement_fails_closed_without_external_touch() {
        let root = TestRoot::new("marker-symlink");
        let external = TestRoot::new("marker-external");
        let marker = root.0.join("wipe-complete");
        let sentinel = external.0.join("sentinel");
        fs::write(&marker, b"original").unwrap();
        fs::write(&sentinel, b"outside").unwrap();

        let result = wipe_after_marker_pinned(root.path_text(), "wipe-complete", || {
            fs::rename(&marker, root.0.join("original-marker")).unwrap();
            symlink(&sentinel, &marker).unwrap();
        });

        assert_eq!(result, Err(KelivoStatus::IoFailure));
        assert_eq!(fs::read(&sentinel).unwrap(), b"outside");
    }

    #[test]
    fn failed_wipe_can_be_retried_idempotently() {
        let root = TestRoot::new("retry");
        fs::write(root.0.join("wipe-complete"), b"done").unwrap();
        fs::write(root.0.join("data"), b"secret").unwrap();
        let fifo = root.0.join("unsupported-fifo");
        let fifo_name = CString::new(fifo.as_os_str().as_bytes()).unwrap();
        assert_eq!(unsafe { libc::mkfifo(fifo_name.as_ptr(), 0o600) }, 0);

        assert_eq!(
            wipe(root.path_text(), "wipe-complete"),
            Err(KelivoStatus::IoFailure)
        );
        fs::remove_file(&fifo).unwrap();
        wipe(root.path_text(), "wipe-complete").expect("清除阻断项后必须可幂等重试");
    }

    #[test]
    fn installation_root_exclusive_lock_blocks_parallel_wipe() {
        let root = TestRoot::new("exclusive-lock");
        fs::write(root.0.join("wipe-complete"), b"done").unwrap();
        let locked_root = open_absolute_directory(root.path_text()).unwrap();
        lock_root_exclusively(&locked_root).unwrap();

        assert_eq!(
            wipe(root.path_text(), "wipe-complete"),
            Err(KelivoStatus::IoFailure)
        );
        drop(locked_root);
        wipe(root.path_text(), "wipe-complete").expect("独占锁释放后必须可重试");
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn nested_mount_is_rejected_when_mount_namespace_allows_fixture() {
        let root = TestRoot::new("mount");
        fs::write(root.0.join("wipe-complete"), b"done").unwrap();
        let mounted = root.0.join("mounted");
        fs::create_dir(&mounted).unwrap();
        let target = CString::new(mounted.as_os_str().as_bytes()).unwrap();
        let mounted_ok = unsafe {
            libc::mount(
                c"tmpfs".as_ptr(),
                target.as_ptr(),
                c"tmpfs".as_ptr(),
                0,
                c"size=64k".as_ptr().cast(),
            )
        } == 0;
        if !mounted_ok {
            return;
        }
        fs::write(mounted.join("sentinel"), b"mounted").unwrap();

        assert_eq!(
            wipe(root.path_text(), "wipe-complete"),
            Err(KelivoStatus::IoFailure)
        );
        assert_eq!(
            unsafe { libc::umount2(target.as_ptr(), libc::MNT_DETACH) },
            0
        );
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn same_filesystem_bind_mount_is_rejected_without_external_touch() {
        let root = TestRoot::new("bind-mount");
        let external = TestRoot::new("bind-external");
        fs::write(root.0.join("wipe-complete"), b"done").unwrap();
        fs::write(external.0.join("sentinel"), b"outside").unwrap();
        let mounted = root.0.join("mounted");
        fs::create_dir(&mounted).unwrap();
        let source = CString::new(external.0.as_os_str().as_bytes()).unwrap();
        let target = CString::new(mounted.as_os_str().as_bytes()).unwrap();
        let mounted_ok = unsafe {
            libc::mount(
                source.as_ptr(),
                target.as_ptr(),
                std::ptr::null(),
                libc::MS_BIND,
                std::ptr::null(),
            )
        } == 0;
        if !mounted_ok {
            return;
        }

        assert_eq!(
            wipe(root.path_text(), "wipe-complete"),
            Err(KelivoStatus::IoFailure)
        );
        assert_eq!(fs::read(external.0.join("sentinel")).unwrap(), b"outside");
        assert_eq!(
            unsafe { libc::umount2(target.as_ptr(), libc::MNT_DETACH) },
            0
        );
    }

    #[test]
    fn root_and_marker_inputs_are_strict() {
        assert_eq!(
            wipe("/", "wipe-complete"),
            Err(KelivoStatus::InvalidArgument)
        );
        assert_eq!(
            wipe("/tmp/../tmp", "wipe-complete"),
            Err(KelivoStatus::InvalidArgument)
        );
        let root = TestRoot::new("invalid-marker");
        assert_eq!(
            wipe(root.path_text(), "nested/marker"),
            Err(KelivoStatus::InvalidArgument)
        );
    }
}
