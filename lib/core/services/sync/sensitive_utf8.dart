import 'dart:convert';
import 'dart:typed_data';

const e2eeRecoveryPassphraseMatchesPasswordCode =
    'SYNC_RECOVERY_PASSPHRASE_MATCHES_PASSWORD';

Uint8List takeSensitiveEncodedBytes(List<int> encoded) {
  if (encoded is Uint8List) return encoded;
  try {
    return Uint8List.fromList(encoded);
  } finally {
    encoded.fillRange(0, encoded.length, 0);
  }
}

Uint8List encodeSensitiveUtf8(String value) {
  return takeSensitiveEncodedBytes(utf8.encode(value));
}

void clearSensitiveBytes(Uint8List? bytes) {
  bytes?.fillRange(0, bytes.length, 0);
}

bool sensitiveUtf8Equals(String left, String right) {
  final leftBytes = encodeSensitiveUtf8(left);
  Uint8List? rightBytes;
  try {
    rightBytes = encodeSensitiveUtf8(right);
    if (leftBytes.length != rightBytes.length) return false;
    var difference = 0;
    for (var index = 0; index < leftBytes.length; index++) {
      difference |= leftBytes[index] ^ rightBytes[index];
    }
    return difference == 0;
  } finally {
    clearSensitiveBytes(leftBytes);
    clearSensitiveBytes(rightBytes);
  }
}
