import 'dart:convert';
import 'dart:typed_data';

const e2eeRecoveryPassphraseMatchesPasswordCode =
    'SYNC_RECOVERY_PASSPHRASE_MATCHES_PASSWORD';

/// OPAQUE 凭据验证失败（错误密码或不存在账号）的统一未认证错误码。
/// 服务端对凭据失败返回 `AUTHENTICATION_FAILED`，客户端本地 OPAQUE 计算
/// 阶段出现的协议失败也收敛到同一错误码，避免区分账号是否存在。
const e2eeOpaqueAuthenticationFailedCode = 'OPAQUE_AUTHENTICATION_FAILED';

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
  if (bytes == null) return;
  try {
    bytes.fillRange(0, bytes.length, 0);
  } on UnsupportedError {
    // Native 绑定层可能返回不可变视图（asUnmodifiableView）：
    // 底层内存由创建方管理，Dart 侧无法（也无需）清零。
  }
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
