use super::{
    BACKGROUND_ACCESS_CAPABILITY, KEY_SLOT_ID_SIZE, KEY_SLOTS_CAPABILITY, KelivoStatus,
    LOCAL_KEY_SIZE, LocalKey, RECORD_ENVELOPES_CAPABILITY, SQLCIPHER_DATABASE_ATTACH_CAPABILITY,
    SQLCIPHER_KEY_APPLICATION_CAPABILITY,
};
use core_foundation::{
    base::{TCFType, kCFAllocatorDefault, kCFAllocatorNull},
    data::CFData,
    dictionary::CFDictionary,
    string::CFString,
};
use core_foundation_sys::data::CFDataCreateWithBytesNoCopy;
use security_framework::{
    access_control::{ProtectionMode, SecAccessControl},
    base::Error,
    passwords::{PasswordOptions, generic_password},
};
use security_framework_sys::{
    base::{errSecAuthFailed, errSecDuplicateItem, errSecItemNotFound, errSecSuccess},
    item::kSecValueData,
    keychain_item::SecItemAdd,
    random::{SecRandomCopyBytes, kSecRandomDefault},
};
use std::ptr;
use zeroize::Zeroizing;

pub(super) const SECURE_STORAGE_BACKEND: u32 = 4;
pub(super) const CAPABILITY_FLAGS: u64 = KEY_SLOTS_CAPABILITY
    | BACKGROUND_ACCESS_CAPABILITY
    | RECORD_ENVELOPES_CAPABILITY
    | SQLCIPHER_KEY_APPLICATION_CAPABILITY
    | SQLCIPHER_DATABASE_ATTACH_CAPABILITY;

const SLOT_SERVICE: &str = "psyche.kelivo.secure-core.slot.v1";

pub(super) fn create_slot(slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<LocalKey, KelivoStatus> {
    let mut options = slot_options(slot_id);
    let access_control = SecAccessControl::create_with_protection(
        Some(ProtectionMode::AccessibleAfterFirstUnlockThisDeviceOnly),
        0,
    )
    .map_err(|_| KelivoStatus::SecureStorageUnavailable)?;
    // 后台同步要求首次解锁后无需交互；ThisDeviceOnly 承担禁止备份迁移的边界。
    options.set_access_control(access_control);

    let mut key = Zeroizing::new(vec![0_u8; LOCAL_KEY_SIZE].into_boxed_slice());
    fill_random(&mut key)?;
    add_slot(&options, &key)?;
    Ok(key)
}

pub(super) fn open_slot(slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<LocalKey, KelivoStatus> {
    let key = generic_password(slot_options(slot_id))
        .map(|value| Zeroizing::new(value.into_boxed_slice()))
        .map_err(map_open_error)?;
    if key.len() != LOCAL_KEY_SIZE {
        return Err(KelivoStatus::SlotDataInvalid);
    }
    Ok(key)
}

pub(super) fn fill_random(output: &mut [u8]) -> Result<(), KelivoStatus> {
    if output.is_empty() {
        return Ok(());
    }
    let status =
        unsafe { SecRandomCopyBytes(kSecRandomDefault, output.len(), output.as_mut_ptr().cast()) };
    if status == errSecSuccess {
        Ok(())
    } else {
        Err(KelivoStatus::RandomSourceFailure)
    }
}

fn slot_options(slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> PasswordOptions {
    let mut options = PasswordOptions::new_generic_password(SLOT_SERVICE, &encode_hex(slot_id));
    options.set_access_synchronized(Some(false));
    options.use_protected_keychain();
    options
}

fn add_slot(options: &PasswordOptions, key: &[u8]) -> Result<(), KelivoStatus> {
    let data_ref = unsafe {
        CFDataCreateWithBytesNoCopy(
            kCFAllocatorDefault,
            key.as_ptr(),
            key.len() as isize,
            kCFAllocatorNull,
        )
    };
    if data_ref.is_null() {
        return Err(KelivoStatus::SecureStorageUnavailable);
    }
    let data = unsafe { CFData::wrap_under_create_rule(data_ref) };
    #[allow(deprecated)]
    let mut query = options.query.clone();
    query.push((
        unsafe { CFString::wrap_under_get_rule(kSecValueData) },
        data.into_CFType(),
    ));
    let parameters = CFDictionary::from_CFType_pairs(&query);
    let status = unsafe { SecItemAdd(parameters.as_concrete_TypeRef(), ptr::null_mut()) };
    if status == errSecSuccess {
        Ok(())
    } else if status == errSecDuplicateItem {
        Err(KelivoStatus::SlotAlreadyExists)
    } else {
        Err(KelivoStatus::SecureStorageUnavailable)
    }
}

fn map_open_error(error: Error) -> KelivoStatus {
    if error.code() == errSecItemNotFound {
        KelivoStatus::SlotNotFound
    } else if error.code() == errSecAuthFailed {
        KelivoStatus::SlotUnwrapFailed
    } else {
        KelivoStatus::SecureStorageUnavailable
    }
}

fn encode_hex(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut output = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        output.push(HEX[(byte >> 4) as usize] as char);
        output.push(HEX[(byte & 0x0f) as usize] as char);
    }
    output
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn slot_identifier_uses_fixed_lowercase_hex() {
        assert_eq!(encode_hex(&[0x00, 0x09, 0x10, 0xab, 0xff]), "000910abff");
    }

    #[test]
    fn keychain_statuses_preserve_missing_and_unwrap_failures() {
        assert_eq!(
            map_open_error(Error::from_code(errSecItemNotFound)),
            KelivoStatus::SlotNotFound
        );
        assert_eq!(
            map_open_error(Error::from_code(errSecAuthFailed)),
            KelivoStatus::SlotUnwrapFailed
        );
    }
}
