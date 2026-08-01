use super::KelivoStatus;
use std::sync::{Mutex, OnceLock};

#[cfg(any(target_os = "android", all(target_os = "linux", test)))]
mod unix;
#[cfg(target_os = "windows")]
mod windows;

pub(super) fn is_supported() -> bool {
    #[cfg(target_os = "android")]
    {
        unix::is_supported()
    }
    #[cfg(target_os = "windows")]
    {
        true
    }
    #[cfg(not(any(target_os = "android", target_os = "windows")))]
    {
        false
    }
}

pub(super) fn wipe(root_path: &str, preserved_entry_name: &str) -> Result<(), KelivoStatus> {
    let _guard = wipe_lock()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;
    #[cfg(target_os = "android")]
    {
        unix::wipe(root_path, preserved_entry_name)
    }
    #[cfg(target_os = "windows")]
    {
        windows::wipe(root_path, preserved_entry_name)
    }
    #[cfg(not(any(target_os = "android", target_os = "windows")))]
    {
        let _ = (root_path, preserved_entry_name);
        Err(KelivoStatus::UnsupportedPlatform)
    }
}

fn wipe_lock() -> &'static Mutex<()> {
    // 安装根擦除必须在同一进程内保持单一写者，避免两次递归互相制造假冲突。
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    LOCK.get_or_init(|| Mutex::new(()))
}
