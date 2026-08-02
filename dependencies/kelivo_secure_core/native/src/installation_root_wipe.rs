use super::KelivoStatus;
use std::{
    collections::HashMap,
    sync::{Arc, Mutex, OnceLock},
};

#[cfg(any(target_os = "android", target_os = "linux"))]
mod unix;
#[cfg(target_os = "windows")]
mod windows;

#[cfg(any(target_os = "android", target_os = "linux"))]
use unix as platform;
#[cfg(target_os = "windows")]
use windows as platform;

#[cfg(not(any(target_os = "android", target_os = "linux", target_os = "windows")))]
mod platform {
    use crate::KelivoStatus;

    pub(super) struct PinnedRoot;

    pub(super) fn is_supported() -> bool {
        false
    }

    impl PinnedRoot {
        pub(super) fn open(_path: &str) -> Result<Self, KelivoStatus> {
            Err(KelivoStatus::UnsupportedPlatform)
        }

        pub(super) fn wipe_preserving(&self, _name: &str) -> Result<(), KelivoStatus> {
            Err(KelivoStatus::UnsupportedPlatform)
        }

        pub(super) fn retire_plaintext_backups(&self) -> Result<(), KelivoStatus> {
            Err(KelivoStatus::UnsupportedPlatform)
        }

        pub(super) fn retire_attachment_staging(&self) -> Result<(), KelivoStatus> {
            Err(KelivoStatus::UnsupportedPlatform)
        }

        pub(super) fn retire_persistent_logs(&self) -> Result<(), KelivoStatus> {
            Err(KelivoStatus::UnsupportedPlatform)
        }

        pub(super) fn verify_shared_preferences_removal(
            &self,
            _raw_key: &str,
        ) -> Result<(), KelivoStatus> {
            Err(KelivoStatus::UnsupportedPlatform)
        }
    }
}

pub(super) const SCOPE_INSTALLATION: u32 = 1;
pub(super) const SCOPE_TEMPORARY: u32 = 2;
pub(super) const SCOPE_SHARED_PREFERENCES: u32 = 3;
pub(super) const OPERATION_RETIRE_PLAINTEXT_BACKUPS: u32 = 1;
pub(super) const OPERATION_RETIRE_ATTACHMENT_STAGING: u32 = 2;
pub(super) const OPERATION_RETIRE_PERSISTENT_LOGS: u32 = 3;
pub(super) const OPERATION_WIPE_INSTALLATION_ROOT: u32 = 4;
pub(super) const OPERATION_VERIFY_SHARED_PREFERENCES_REMOVAL: u32 = 5;

pub(super) const SHARED_PREFERENCES_FILE_MAX_SIZE: usize = 16 * 1024 * 1024;

const MAX_ACTIVE_MANAGED_ROOTS: usize = 16;
const MAX_MANAGED_ROOT_HANDLE: u64 = (1_u64 << 60) - 1;

#[derive(Clone, Copy, Eq, PartialEq)]
enum ManagedRootScope {
    Installation,
    Temporary,
    SharedPreferences,
}

impl ManagedRootScope {
    fn parse(value: u32) -> Result<Self, KelivoStatus> {
        match value {
            SCOPE_INSTALLATION => Ok(Self::Installation),
            SCOPE_TEMPORARY => Ok(Self::Temporary),
            SCOPE_SHARED_PREFERENCES => Ok(Self::SharedPreferences),
            _ => Err(KelivoStatus::InvalidArgument),
        }
    }
}

struct ManagedRoot {
    scope: ManagedRootScope,
    root: platform::PinnedRoot,
    operation_lock: Mutex<()>,
}

struct ManagedRootRegistry {
    active: HashMap<u64, Arc<ManagedRoot>>,
    next_handle: u64,
}

impl Default for ManagedRootRegistry {
    fn default() -> Self {
        Self {
            active: HashMap::new(),
            next_handle: 1,
        }
    }
}

pub(super) fn is_supported() -> bool {
    platform::is_supported()
}

pub(super) fn open(scope: u32, root_path: &str) -> Result<u64, KelivoStatus> {
    if !is_supported() {
        return Err(KelivoStatus::UnsupportedPlatform);
    }
    let scope = ManagedRootScope::parse(scope)?;
    let root = platform::PinnedRoot::open(root_path)?;
    let mut registry = registry().lock().map_err(|_| KelivoStatus::InternalState)?;
    if registry.active.len() >= MAX_ACTIVE_MANAGED_ROOTS {
        return Err(KelivoStatus::TooManyActiveHandles);
    }
    let handle = registry.next_handle;
    if handle == 0 || handle > MAX_MANAGED_ROOT_HANDLE {
        return Err(KelivoStatus::HandleSpaceExhausted);
    }
    registry.next_handle = if handle == MAX_MANAGED_ROOT_HANDLE {
        0
    } else {
        handle + 1
    };
    let replaced = registry.active.insert(
        handle,
        Arc::new(ManagedRoot {
            scope,
            root,
            operation_lock: Mutex::new(()),
        }),
    );
    debug_assert!(replaced.is_none());
    Ok(handle)
}

pub(super) fn execute(handle: u64, operation: u32, argument: &str) -> Result<(), KelivoStatus> {
    let root = root_for_handle(handle)?;
    let _guard = root
        .operation_lock
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;
    match (root.scope, operation) {
        (ManagedRootScope::Installation, OPERATION_WIPE_INSTALLATION_ROOT)
            if !argument.is_empty() =>
        {
            root.root.wipe_preserving(argument)
        }
        (ManagedRootScope::Installation, OPERATION_RETIRE_ATTACHMENT_STAGING)
            if argument.is_empty() =>
        {
            root.root.retire_attachment_staging()
        }
        (ManagedRootScope::Installation, OPERATION_RETIRE_PERSISTENT_LOGS)
            if argument.is_empty() =>
        {
            root.root.retire_persistent_logs()
        }
        (ManagedRootScope::Temporary, OPERATION_RETIRE_PLAINTEXT_BACKUPS)
            if argument.is_empty() =>
        {
            root.root.retire_plaintext_backups()
        }
        (ManagedRootScope::SharedPreferences, OPERATION_VERIFY_SHARED_PREFERENCES_REMOVAL)
            if !argument.is_empty() =>
        {
            root.root.verify_shared_preferences_removal(argument)
        }
        _ => Err(KelivoStatus::InvalidArgument),
    }
}

pub(super) fn verify_shared_preferences_document(
    contents: &[u8],
    raw_key: &str,
) -> Result<(), KelivoStatus> {
    let values = serde_json::from_slice::<serde_json::Map<String, serde_json::Value>>(contents)
        .map_err(|_| KelivoStatus::IoFailure)?;
    if values.contains_key(raw_key) {
        Err(KelivoStatus::IoFailure)
    } else {
        Ok(())
    }
}

pub(super) fn close(handle: u64) -> Result<(), KelivoStatus> {
    if handle == 0 || handle > MAX_MANAGED_ROOT_HANDLE {
        return Err(KelivoStatus::InvalidManagedRootHandle);
    }
    let mut registry = registry().lock().map_err(|_| KelivoStatus::InternalState)?;
    let root = registry
        .active
        .get(&handle)
        .ok_or(KelivoStatus::InvalidManagedRootHandle)?;
    if Arc::strong_count(root) != 1 {
        return Err(KelivoStatus::SlotInUse);
    }
    registry
        .active
        .remove(&handle)
        .ok_or(KelivoStatus::InternalState)?;
    Ok(())
}

fn root_for_handle(handle: u64) -> Result<Arc<ManagedRoot>, KelivoStatus> {
    if handle == 0 || handle > MAX_MANAGED_ROOT_HANDLE {
        return Err(KelivoStatus::InvalidManagedRootHandle);
    }
    registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?
        .active
        .get(&handle)
        .map(Arc::clone)
        .ok_or(KelivoStatus::InvalidManagedRootHandle)
}

fn registry() -> &'static Mutex<ManagedRootRegistry> {
    static REGISTRY: OnceLock<Mutex<ManagedRootRegistry>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(ManagedRootRegistry::default()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn shared_preferences_document_requires_object_without_target_key() {
        assert_eq!(
            verify_shared_preferences_document(br#"{"flutter.other":"kept"}"#, "flutter.removed"),
            Ok(())
        );
        assert_eq!(
            verify_shared_preferences_document(
                br#"{"flutter.removed":"secret"}"#,
                "flutter.removed"
            ),
            Err(KelivoStatus::IoFailure)
        );
        assert_eq!(
            verify_shared_preferences_document(br#"[]"#, "flutter.removed"),
            Err(KelivoStatus::IoFailure)
        );
        assert_eq!(
            verify_shared_preferences_document(br#"{"#, "flutter.removed"),
            Err(KelivoStatus::IoFailure)
        );
        assert_eq!(
            verify_shared_preferences_document(&[0xff], "flutter.removed"),
            Err(KelivoStatus::IoFailure)
        );
    }
}
