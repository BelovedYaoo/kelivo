use super::{
    BACKGROUND_ACCESS_CAPABILITY, KEY_SLOT_ID_SIZE, KEY_SLOTS_CAPABILITY, KelivoStatus,
    LOCAL_KEY_SIZE, LocalKey, RECORD_ENVELOPES_CAPABILITY, SQLCIPHER_DATABASE_ATTACH_CAPABILITY,
    SQLCIPHER_KEY_APPLICATION_CAPABILITY,
};
use core_foundation::{
    base::{TCFType, kCFAllocatorDefault, kCFAllocatorNull},
    boolean::CFBoolean,
    data::CFData,
    dictionary::CFDictionary,
    string::CFString,
};
use core_foundation_sys::data::CFDataCreateWithBytesNoCopy;
use security_framework::{
    access_control::{ProtectionMode, SecAccessControl},
    base::Error,
    passwords::{PasswordOptions, delete_generic_password_options, generic_password},
};
use security_framework_sys::{
    base::{errSecAuthFailed, errSecDuplicateItem, errSecItemNotFound, errSecSuccess},
    item::{
        kSecAttrService, kSecAttrSynchronizable, kSecClass, kSecClassGenericPassword,
        kSecUseDataProtectionKeychain, kSecValueData,
    },
    keychain_item::{SecItemAdd, SecItemDelete},
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

const SLOT_SERVICE: &str = "top.bemylover.olivia.secure-core.slot.v1";

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
    let source = generic_password(slot_options(slot_id))
        .map(Zeroizing::new)
        .map_err(map_open_error)?;
    copy_opened_key(&source)
}

pub(super) fn delete_slot(slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<(), KelivoStatus> {
    delete_generic_password_options(slot_options(slot_id)).or_else(map_delete_error)
}

pub(super) fn delete_all_slots() -> Result<(), KelivoStatus> {
    let query = CFDictionary::from_CFType_pairs(&[
        (
            unsafe { CFString::wrap_under_get_rule(kSecClass) },
            unsafe { CFString::wrap_under_get_rule(kSecClassGenericPassword) }.into_CFType(),
        ),
        (
            unsafe { CFString::wrap_under_get_rule(kSecAttrService) },
            CFString::from(SLOT_SERVICE).into_CFType(),
        ),
        (
            unsafe { CFString::wrap_under_get_rule(kSecAttrSynchronizable) },
            CFBoolean::from(false).into_CFType(),
        ),
        (
            unsafe { CFString::wrap_under_get_rule(kSecUseDataProtectionKeychain) },
            CFBoolean::from(true).into_CFType(),
        ),
    ]);
    let status = unsafe { SecItemDelete(query.as_concrete_TypeRef()) };
    map_delete_all_status(status)
}

fn copy_opened_key(source: &[u8]) -> Result<LocalKey, KelivoStatus> {
    if source.len() != LOCAL_KEY_SIZE {
        return Err(KelivoStatus::SlotDataInvalid);
    }
    let mut key = Zeroizing::new(vec![0_u8; LOCAL_KEY_SIZE].into_boxed_slice());
    key.copy_from_slice(source);
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

fn map_delete_error(error: Error) -> Result<(), KelivoStatus> {
    if error.code() == errSecItemNotFound {
        Ok(())
    } else if error.code() == errSecAuthFailed {
        Err(KelivoStatus::SlotUnwrapFailed)
    } else {
        Err(KelivoStatus::SecureStorageUnavailable)
    }
}

fn map_delete_all_status(status: i32) -> Result<(), KelivoStatus> {
    if status == errSecSuccess || status == errSecItemNotFound {
        Ok(())
    } else if status == errSecAuthFailed {
        Err(KelivoStatus::SlotUnwrapFailed)
    } else {
        Err(KelivoStatus::SecureStorageUnavailable)
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
    use zeroize::Zeroize;

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
        assert_eq!(
            map_delete_error(Error::from_code(errSecItemNotFound)),
            Ok(())
        );
        assert_eq!(
            map_delete_error(Error::from_code(errSecAuthFailed)),
            Err(KelivoStatus::SlotUnwrapFailed)
        );
        assert_eq!(
            map_delete_error(Error::from_code(-50)),
            Err(KelivoStatus::SecureStorageUnavailable)
        );
        assert_eq!(map_delete_all_status(errSecSuccess), Ok(()));
        assert_eq!(map_delete_all_status(errSecItemNotFound), Ok(()));
        assert_eq!(
            map_delete_all_status(errSecAuthFailed),
            Err(KelivoStatus::SlotUnwrapFailed)
        );
        assert_eq!(
            map_delete_all_status(-50),
            Err(KelivoStatus::SecureStorageUnavailable)
        );
    }

    #[test]
    fn opened_key_copy_keeps_zeroizing_lifetimes_independent() {
        let expected = [0x5a_u8; LOCAL_KEY_SIZE];
        let mut source = Zeroizing::new(Vec::with_capacity(LOCAL_KEY_SIZE * 2));
        source.extend_from_slice(&expected);
        let source_address = source.as_ptr() as usize;

        let mut key = copy_opened_key(&source).expect("有效 Keychain 密钥应可复制");
        assert_ne!(source_address, key.as_ptr() as usize);
        assert_eq!(&key[..], &expected);

        source.zeroize();
        assert!(source.is_empty());
        assert_eq!(&key[..], &expected);

        key.zeroize();
        assert!(key.iter().all(|byte| *byte == 0));
    }
}
