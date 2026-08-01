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

pub(super) struct PinnedRoot {
    chain: Vec<PinnedDirectory>,
    #[cfg(target_os = "android")]
    android_user_zero_alias: Option<AndroidUserZeroAlias>,
}

struct PinnedDirectory {
    file: File,
    name_from_parent: Option<CString>,
    identity: FileIdentity,
}

#[cfg(target_os = "android")]
struct AndroidUserZeroAlias {
    user_directory: File,
    user_identity: FileIdentity,
    alias_identity: FileIdentity,
    canonical_target_identity: FileIdentity,
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

#[cfg(test)]
pub(super) fn wipe(root_path: &str, preserved_entry_name: &str) -> Result<(), KelivoStatus> {
    if !is_supported() {
        return Err(KelivoStatus::UnsupportedPlatform);
    }
    wipe_after_marker_pinned(root_path, preserved_entry_name, || {})
}

impl PinnedRoot {
    pub(super) fn open(root_path: &str) -> Result<Self, KelivoStatus> {
        if !is_supported() {
            return Err(KelivoStatus::UnsupportedPlatform);
        }
        validate_absolute_path(root_path)?;
        open_absolute_directory(root_path)
    }

    pub(super) fn wipe_preserving(&self, preserved_entry_name: &str) -> Result<(), KelivoStatus> {
        self.verify_chain()?;
        let result = wipe_pinned_root(self.root(), preserved_entry_name, || {});
        let identity_result = self.verify_chain();
        result?;
        identity_result
    }

    pub(super) fn retire_plaintext_backups(&self) -> Result<(), KelivoStatus> {
        self.guarded(retire_plaintext_backups)
    }

    pub(super) fn retire_attachment_staging(&self) -> Result<(), KelivoStatus> {
        self.guarded(|root| retire_workspace_tree(root, &[b"upload", b"e2ee", b"staging"]))
    }

    pub(super) fn retire_persistent_logs(&self) -> Result<(), KelivoStatus> {
        self.guarded(|root| retire_workspace_tree(root, &[b"logs"]))
    }

    fn guarded(
        &self,
        operation: impl FnOnce(&File) -> Result<(), KelivoStatus>,
    ) -> Result<(), KelivoStatus> {
        self.verify_chain()?;
        let _root_lock = lock_root_exclusively(self.root())?;
        self.verify_chain()?;
        let result = operation(self.root());
        let identity_result = self.verify_chain();
        result?;
        identity_result
    }

    fn root(&self) -> &File {
        &self.chain.last().expect("受管根链不得为空").file
    }

    fn verify_chain(&self) -> Result<(), KelivoStatus> {
        for index in 1..self.chain.len() {
            let parent = &self.chain[index - 1].file;
            let component = &self.chain[index];
            let name = component
                .name_from_parent
                .as_ref()
                .ok_or(KelivoStatus::InternalState)?;
            let metadata = metadata_at(parent, name)?;
            require_directory(metadata)?;
            if metadata.identity != component.identity {
                return Err(KelivoStatus::IoFailure);
            }
        }
        #[cfg(target_os = "android")]
        if let Some(alias) = &self.android_user_zero_alias {
            self.verify_android_user_zero_alias(alias)?;
        }
        Ok(())
    }

    #[cfg(target_os = "android")]
    fn verify_android_user_zero_alias(
        &self,
        alias: &AndroidUserZeroAlias,
    ) -> Result<(), KelivoStatus> {
        let data_directory = self.chain.get(1).ok_or(KelivoStatus::InternalState)?;
        let user_metadata = metadata_at(&data_directory.file, c"user")?;
        if user_metadata.identity != alias.user_identity {
            return Err(KelivoStatus::IoFailure);
        }
        let alias_metadata = metadata_at(&alias.user_directory, c"0")?;
        if alias_metadata.identity != alias.alias_identity
            || alias_metadata.identity.kind != normalized_u32(libc::S_IFLNK)
        {
            return Err(KelivoStatus::IoFailure);
        }
        let target = open_android_system_alias(&alias.user_directory, c"0")?;
        if metadata_for(&target)?.identity != alias.canonical_target_identity {
            return Err(KelivoStatus::IoFailure);
        }
        Ok(())
    }
}

#[cfg(test)]
fn wipe_after_marker_pinned(
    root_path: &str,
    preserved_entry_name: &str,
    after_marker_pinned: impl FnOnce(),
) -> Result<(), KelivoStatus> {
    validate_absolute_path(root_path)?;
    let root = open_absolute_directory(root_path)?;
    root.verify_chain()?;
    let result = wipe_pinned_root(root.root(), preserved_entry_name, after_marker_pinned);
    let identity_result = root.verify_chain();
    result?;
    identity_result
}

fn wipe_pinned_root(
    root: &File,
    preserved_entry_name: &str,
    after_marker_pinned: impl FnOnce(),
) -> Result<(), KelivoStatus> {
    let preserved_name = validate_entry_name(preserved_entry_name)?;
    let root_metadata = metadata_for(root)?;
    require_directory(root_metadata)?;
    let _root_lock = lock_root_exclusively(root)?;
    let marker = pin_marker(root, &preserved_name, root_metadata.identity.device)?;

    after_marker_pinned();
    wipe_directory(root, root_metadata.identity.device, marker.identity, 0)?;
    verify_only_marker(root, &preserved_name, marker.identity)?;

    let final_marker = open_regular_relative(root, &preserved_name)?;
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

struct RootLock<'a>(&'a File);

impl Drop for RootLock<'_> {
    fn drop(&mut self) {
        unsafe { libc::flock(self.0.as_raw_fd(), libc::LOCK_UN) };
    }
}

fn lock_root_exclusively(root: &File) -> Result<RootLock<'_>, KelivoStatus> {
    // Android 可能存在同 UID 多进程，根目录锁把所有遵守安装级协议的写者排除在擦除窗口外。
    if unsafe { libc::flock(root.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } == 0 {
        Ok(RootLock(root))
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

fn open_absolute_directory(path: &str) -> Result<PinnedRoot, KelivoStatus> {
    let root_fd = unsafe {
        libc::open(
            c"/".as_ptr(),
            libc::O_PATH | libc::O_DIRECTORY | libc::O_CLOEXEC | libc::O_NOFOLLOW,
        )
    };
    if root_fd < 0 {
        return Err(KelivoStatus::IoFailure);
    }
    let root = unsafe { File::from_raw_fd(root_fd) };
    let root_identity = metadata_for(&root)?.identity;
    let mut chain = vec![PinnedDirectory {
        file: root,
        name_from_parent: None,
        identity: root_identity,
    }];
    let raw_components = path.as_bytes()[1..]
        .split(|byte| *byte == b'/')
        .collect::<Vec<_>>();
    #[cfg(target_os = "android")]
    let uses_android_user_zero_alias = raw_components.len() >= 4
        && raw_components[0] == b"data"
        && raw_components[1] == b"user"
        && raw_components[2] == b"0";
    #[cfg(target_os = "android")]
    let components = if uses_android_user_zero_alias {
        let mut canonical = Vec::with_capacity(raw_components.len() - 1);
        canonical.push(b"data".as_slice());
        canonical.push(b"data".as_slice());
        canonical.extend_from_slice(&raw_components[3..]);
        canonical
    } else {
        raw_components
    };
    #[cfg(not(target_os = "android"))]
    let components = raw_components;
    for (index, component) in components.iter().enumerate() {
        let component = CString::new(*component).map_err(|_| KelivoStatus::InvalidArgument)?;
        let directory = open_root_component_relative(
            &chain.last().ok_or(KelivoStatus::InternalState)?.file,
            &component,
            index + 1 == components.len(),
        )?;
        let metadata = metadata_for(&directory)?;
        chain.push(PinnedDirectory {
            file: directory,
            name_from_parent: Some(component),
            identity: metadata.identity,
        });
    }
    #[cfg(target_os = "android")]
    let android_user_zero_alias = if uses_android_user_zero_alias {
        let data_directory = chain.get(1).ok_or(KelivoStatus::InternalState)?;
        let canonical_data = chain.get(2).ok_or(KelivoStatus::InternalState)?;
        let user_directory = open_root_component_relative(&data_directory.file, c"user", false)?;
        let user_identity = metadata_for(&user_directory)?.identity;
        let alias_metadata = metadata_at(&user_directory, c"0")?;
        if alias_metadata.identity.kind != normalized_u32(libc::S_IFLNK) {
            return Err(KelivoStatus::IoFailure);
        }
        let target = open_android_system_alias(&user_directory, c"0")?;
        let target_identity = metadata_for(&target)?.identity;
        if target_identity != canonical_data.identity {
            return Err(KelivoStatus::IoFailure);
        }
        Some(AndroidUserZeroAlias {
            user_directory,
            user_identity,
            alias_identity: alias_metadata.identity,
            canonical_target_identity: target_identity,
        })
    } else {
        None
    };
    Ok(PinnedRoot {
        chain,
        #[cfg(target_os = "android")]
        android_user_zero_alias,
    })
}

fn open_root_component_relative(
    parent: &File,
    name: &CStr,
    is_final: bool,
) -> Result<File, KelivoStatus> {
    let access = if is_final {
        libc::O_RDONLY
    } else {
        libc::O_PATH
    };
    let fd = unsafe {
        libc::openat(
            parent.as_raw_fd(),
            name.as_ptr(),
            access | libc::O_DIRECTORY | libc::O_CLOEXEC | libc::O_NOFOLLOW,
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

#[cfg(target_os = "android")]
fn open_android_system_alias(parent: &File, name: &CStr) -> Result<File, KelivoStatus> {
    let fd = unsafe {
        libc::openat(
            parent.as_raw_fd(),
            name.as_ptr(),
            libc::O_PATH | libc::O_DIRECTORY | libc::O_CLOEXEC,
        )
    };
    if fd < 0 {
        return Err(KelivoStatus::IoFailure);
    }
    let directory = unsafe { File::from_raw_fd(fd) };
    require_directory(metadata_for(&directory)?)?;
    Ok(directory)
}

fn retire_plaintext_backups(root: &File) -> Result<(), KelivoStatus> {
    let root_device = metadata_for(root)?.identity.device;
    for name in directory_entry_names(root)? {
        let bytes = name.to_bytes();
        let has_backup_prefix = bytes.starts_with(b"kelivo_backup_");
        let is_loose_file = [
            b"_bk_settings.json".as_slice(),
            b"_bk_chats.json".as_slice(),
            b"_bk_manifest.json".as_slice(),
            b"_bk_kelivo.db".as_slice(),
        ]
        .contains(&bytes);
        if !has_backup_prefix && !is_loose_file {
            continue;
        }
        let metadata = metadata_at(root, &name)?;
        if metadata.identity.kind == normalized_u32(libc::S_IFDIR) {
            if !has_backup_prefix {
                return Err(KelivoStatus::IoFailure);
            }
            delete_named_directory(root, &name, root_device)?;
        } else if metadata.identity.kind == normalized_u32(libc::S_IFREG)
            && (is_loose_file || (has_backup_prefix && bytes.ends_with(b".zip")))
        {
            delete_named_regular(root, &name, root_device)?;
        } else {
            return Err(KelivoStatus::IoFailure);
        }
    }
    root.sync_all().map_err(|_| KelivoStatus::IoFailure)
}

fn retire_workspace_tree(root: &File, relative_segments: &[&[u8]]) -> Result<(), KelivoStatus> {
    let root_device = metadata_for(root)?.identity.device;
    delete_relative_directory(root, relative_segments, root_device)?;
    let workspaces_name = c".kelivo-workspaces";
    let Some(workspaces) = open_optional_directory(root, workspaces_name, root_device)? else {
        return root.sync_all().map_err(|_| KelivoStatus::IoFailure);
    };

    if let Some(local) = open_optional_directory(&workspaces, c"local", root_device)?
        && let Some(data) = open_optional_directory(&local, c"data", root_device)?
    {
        delete_relative_directory(&data, relative_segments, root_device)?;
    }

    if let Some(accounts) = open_optional_directory(&workspaces, c"accounts", root_device)? {
        for name in directory_entry_names(&accounts)? {
            if !is_workspace_key(name.to_bytes()) {
                return Err(KelivoStatus::IoFailure);
            }
            let metadata = metadata_at(&accounts, &name)?;
            require_directory(metadata)?;
            let account = open_required_directory(&accounts, &name, root_device)?;
            if let Some(data) = open_optional_directory(&account, c"data", root_device)? {
                delete_relative_directory(&data, relative_segments, root_device)?;
            }
        }
    }
    workspaces.sync_all().map_err(|_| KelivoStatus::IoFailure)?;
    root.sync_all().map_err(|_| KelivoStatus::IoFailure)
}

fn delete_relative_directory(
    root: &File,
    segments: &[&[u8]],
    root_device: u64,
) -> Result<(), KelivoStatus> {
    let (target, ancestors) = segments.split_last().ok_or(KelivoStatus::InternalState)?;
    let mut chain = Vec::with_capacity(ancestors.len());
    let mut parent = root;
    for segment in ancestors {
        let name = CString::new(*segment).map_err(|_| KelivoStatus::InternalState)?;
        let Some(directory) = open_optional_directory(parent, &name, root_device)? else {
            return Ok(());
        };
        chain.push(directory);
        parent = chain.last().ok_or(KelivoStatus::InternalState)?;
    }
    let target = CString::new(*target).map_err(|_| KelivoStatus::InternalState)?;
    let result = delete_optional_named_directory(parent, &target, root_device);
    drop(chain);
    result
}

fn delete_optional_named_directory(
    parent: &File,
    name: &CStr,
    root_device: u64,
) -> Result<(), KelivoStatus> {
    let Some(metadata) = metadata_at_optional(parent, name)? else {
        return Ok(());
    };
    require_directory(metadata)?;
    delete_named_directory(parent, name, root_device)
}

fn delete_named_directory(
    parent: &File,
    name: &CStr,
    root_device: u64,
) -> Result<(), KelivoStatus> {
    let child = open_required_directory(parent, name, root_device)?;
    let identity = metadata_for(&child)?.identity;
    delete_directory_contents(&child, root_device, 0)?;
    child.sync_all().map_err(|_| KelivoStatus::IoFailure)?;
    ensure_named_identity(parent, name, identity)?;
    if unsafe { libc::unlinkat(parent.as_raw_fd(), name.as_ptr(), libc::AT_REMOVEDIR) } != 0 {
        return Err(KelivoStatus::IoFailure);
    }
    parent.sync_all().map_err(|_| KelivoStatus::IoFailure)
}

fn delete_directory_contents(
    directory: &File,
    root_device: u64,
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
            delete_named_regular(directory, &name, root_device)?;
        } else if metadata.identity.kind == normalized_u32(libc::S_IFDIR) {
            let child = open_required_directory(directory, &name, root_device)?;
            let identity = metadata_for(&child)?.identity;
            delete_directory_contents(&child, root_device, depth + 1)?;
            child.sync_all().map_err(|_| KelivoStatus::IoFailure)?;
            ensure_named_identity(directory, &name, identity)?;
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

fn delete_named_regular(parent: &File, name: &CStr, root_device: u64) -> Result<(), KelivoStatus> {
    let file = open_regular_relative(parent, name)?;
    let metadata = metadata_for(&file)?;
    if metadata.identity.device != root_device || metadata.links != 1 {
        return Err(KelivoStatus::IoFailure);
    }
    file.sync_all().map_err(|_| KelivoStatus::IoFailure)?;
    ensure_named_identity(parent, name, metadata.identity)?;
    if unsafe { libc::unlinkat(parent.as_raw_fd(), name.as_ptr(), 0) } != 0 {
        return Err(KelivoStatus::IoFailure);
    }
    parent.sync_all().map_err(|_| KelivoStatus::IoFailure)
}

fn open_optional_directory(
    parent: &File,
    name: &CStr,
    root_device: u64,
) -> Result<Option<File>, KelivoStatus> {
    if metadata_at_optional(parent, name)?.is_none() {
        return Ok(None);
    }
    open_required_directory(parent, name, root_device).map(Some)
}

fn open_required_directory(
    parent: &File,
    name: &CStr,
    root_device: u64,
) -> Result<File, KelivoStatus> {
    let before = metadata_at(parent, name)?;
    require_directory(before)?;
    let directory = open_directory_relative(parent, name)?;
    let opened = metadata_for(&directory)?;
    if before.identity != opened.identity || opened.identity.device != root_device {
        return Err(KelivoStatus::IoFailure);
    }
    Ok(directory)
}

fn is_workspace_key(value: &[u8]) -> bool {
    value.len() == 64
        && value
            .iter()
            .all(|byte| byte.is_ascii_digit() || matches!(byte, b'a'..=b'f'))
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
    metadata_at_optional(directory, name)?.ok_or(KelivoStatus::IoFailure)
}

fn metadata_at_optional(
    directory: &File,
    name: &CStr,
) -> Result<Option<FileMetadata>, KelivoStatus> {
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
        return if current_errno() == libc::ENOENT {
            Ok(None)
        } else {
            Err(KelivoStatus::IoFailure)
        };
    }
    Ok(Some(metadata_from_stat(unsafe { output.assume_init() })))
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
    fn managed_root_session_rejects_root_replacement_without_external_touch() {
        let parent = TestRoot::new("session-root");
        let root = parent.0.join("managed");
        let moved = parent.0.join("original");
        fs::create_dir(&root).unwrap();
        fs::write(root.join("wipe-complete"), b"done").unwrap();
        fs::write(root.join("secret"), b"secret").unwrap();
        let session = PinnedRoot::open(root.to_str().unwrap()).unwrap();
        fs::rename(&root, &moved).unwrap();
        fs::create_dir(&root).unwrap();
        fs::write(root.join("sentinel"), b"outside").unwrap();

        assert_eq!(
            session.wipe_preserving("wipe-complete"),
            Err(KelivoStatus::IoFailure)
        );
        assert_eq!(fs::read(root.join("sentinel")).unwrap(), b"outside");
        assert_eq!(fs::read(moved.join("secret")).unwrap(), b"secret");
    }

    #[test]
    fn temporary_backup_retirement_deletes_only_owned_artifacts_and_unicode_contents() {
        let root = TestRoot::new("backup-retirement");
        fs::write(root.0.join("_bk_settings.json"), b"secret").unwrap();
        fs::write(root.0.join("kelivo_backup_archive.zip"), b"secret").unwrap();
        let bundle = root.0.join("kelivo_backup_bundle");
        fs::create_dir(&bundle).unwrap();
        fs::write(bundle.join("会话.txt"), b"secret").unwrap();
        fs::write(root.0.join("unrelated.txt"), b"keep").unwrap();
        let session = PinnedRoot::open(root.path_text()).unwrap();

        session.retire_plaintext_backups().unwrap();

        assert!(!root.0.join("_bk_settings.json").exists());
        assert!(!root.0.join("kelivo_backup_archive.zip").exists());
        assert!(!bundle.exists());
        assert_eq!(fs::read(root.0.join("unrelated.txt")).unwrap(), b"keep");
    }

    #[test]
    fn temporary_backup_retirement_rejects_symlink_and_hard_link_without_external_touch() {
        let root = TestRoot::new("backup-links");
        let external = TestRoot::new("backup-links-external");
        let sentinel = external.0.join("sentinel");
        fs::write(&sentinel, b"outside").unwrap();
        symlink(&external.0, root.0.join("kelivo_backup_link")).unwrap();
        let session = PinnedRoot::open(root.path_text()).unwrap();

        assert_eq!(
            session.retire_plaintext_backups(),
            Err(KelivoStatus::IoFailure)
        );
        assert_eq!(fs::read(&sentinel).unwrap(), b"outside");
        fs::remove_file(root.0.join("kelivo_backup_link")).unwrap();

        fs::hard_link(&sentinel, root.0.join("_bk_settings.json")).unwrap();
        assert_eq!(
            session.retire_plaintext_backups(),
            Err(KelivoStatus::IoFailure)
        );
        assert_eq!(fs::read(&sentinel).unwrap(), b"outside");
    }

    #[test]
    fn workspace_retirement_rejects_unknown_account_entry() {
        let root = TestRoot::new("workspace-account");
        fs::create_dir_all(root.0.join(".kelivo-workspaces/accounts/not-owned")).unwrap();
        let session = PinnedRoot::open(root.path_text()).unwrap();
        assert_eq!(
            session.retire_persistent_logs(),
            Err(KelivoStatus::IoFailure)
        );
    }

    #[test]
    fn workspace_retirement_removes_direct_local_and_account_artifacts() {
        let root = TestRoot::new("workspace-retirement");
        let account_key = "a".repeat(64);
        let data_roots = [
            root.0.clone(),
            root.0.join(".kelivo-workspaces/local/data"),
            root.0
                .join(".kelivo-workspaces/accounts")
                .join(account_key)
                .join("data"),
        ];
        for data in &data_roots {
            fs::create_dir_all(data.join("logs")).unwrap();
            fs::write(data.join("logs/日志.txt"), b"secret").unwrap();
            fs::create_dir_all(data.join("upload/e2ee/staging")).unwrap();
            fs::write(data.join("upload/e2ee/staging/plaintext.bin"), b"secret").unwrap();
            fs::write(data.join("retained.bin"), b"keep").unwrap();
        }
        let session = PinnedRoot::open(root.path_text()).unwrap();

        session.retire_persistent_logs().unwrap();
        session.retire_attachment_staging().unwrap();

        for data in &data_roots {
            assert!(!data.join("logs").exists());
            assert!(!data.join("upload/e2ee/staging").exists());
            assert_eq!(fs::read(data.join("retained.bin")).unwrap(), b"keep");
        }
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
        let _lock = lock_root_exclusively(locked_root.root()).unwrap();

        assert_eq!(
            wipe(root.path_text(), "wipe-complete"),
            Err(KelivoStatus::IoFailure)
        );
        drop(_lock);
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
