use super::KEY_SLOT_ID_SIZE;

pub(crate) const NAMESPACE_LOCK_FILE_NAME: &str = ".slot-store.lock";

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) enum SlotStoreEntryKind {
    Slot,
    Temporary,
    NamespaceLock,
    Unknown,
}

pub(crate) fn classify_slot_store_entry(name: &str) -> SlotStoreEntryKind {
    if !name.is_ascii() {
        return SlotStoreEntryKind::Unknown;
    }
    if name == NAMESPACE_LOCK_FILE_NAME {
        return SlotStoreEntryKind::NamespaceLock;
    }

    let bytes = name.as_bytes();
    if is_slot_file_name(bytes) {
        return SlotStoreEntryKind::Slot;
    }

    let slot_name_length = KEY_SLOT_ID_SIZE * 2 + 4;
    let suffix_length = 16 * 2;
    let expected_length = 1 + slot_name_length + 1 + suffix_length + 4;
    if bytes.len() == expected_length
        && bytes[0] == b'.'
        && is_slot_file_name(&bytes[1..1 + slot_name_length])
        && bytes[1 + slot_name_length] == b'.'
        && is_lower_hex(&bytes[2 + slot_name_length..2 + slot_name_length + suffix_length])
        && bytes.ends_with(b".tmp")
    {
        SlotStoreEntryKind::Temporary
    } else {
        SlotStoreEntryKind::Unknown
    }
}

fn is_slot_file_name(name: &[u8]) -> bool {
    name.len() == KEY_SLOT_ID_SIZE * 2 + 4
        && name.ends_with(b".bin")
        && is_lower_hex(&name[..KEY_SLOT_ID_SIZE * 2])
}

fn is_lower_hex(value: &[u8]) -> bool {
    value
        .iter()
        .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(byte))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fixed_ascii_names_are_classified_without_platform_differences() {
        let slot_name = format!("{}.bin", "ab".repeat(KEY_SLOT_ID_SIZE));
        let temporary_name = format!(".{slot_name}.{}.tmp", "cd".repeat(16));

        assert_eq!(
            classify_slot_store_entry(&slot_name),
            SlotStoreEntryKind::Slot
        );
        assert_eq!(
            classify_slot_store_entry(&temporary_name),
            SlotStoreEntryKind::Temporary
        );
        assert_eq!(
            classify_slot_store_entry(NAMESPACE_LOCK_FILE_NAME),
            SlotStoreEntryKind::NamespaceLock
        );
    }

    #[test]
    fn unicode_at_the_legacy_byte_boundary_is_rejected_without_panicking() {
        let crafted = format!(".{}é{}.tmp", "a".repeat(35), "b".repeat(32));
        assert_eq!(crafted.len(), 74);
        assert_eq!(
            classify_slot_store_entry(&crafted),
            SlotStoreEntryKind::Unknown
        );
    }
}
