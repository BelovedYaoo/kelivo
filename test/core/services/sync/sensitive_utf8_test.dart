import 'dart:typed_data';

import 'package:Kelivo/core/services/sync/sensitive_utf8.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('接管普通 UTF-8 列表时清零中间副本并保留结果', () {
    final intermediate = <int>[0x61, 0x62, 0x63];

    final owned = takeSensitiveEncodedBytes(intermediate);

    expect(intermediate, everyElement(0));
    expect(owned, orderedEquals(<int>[0x61, 0x62, 0x63]));
    clearSensitiveBytes(owned);
    expect(owned, everyElement(0));
  });

  test('接管 Uint8List 时不产生额外副本且仍可清零', () {
    final encoded = Uint8List.fromList(<int>[0x61, 0x62, 0x63]);

    final owned = takeSensitiveEncodedBytes(encoded);

    expect(identical(owned, encoded), isTrue);
    clearSensitiveBytes(owned);
    expect(encoded, everyElement(0));
  });

  test('敏感文本按实际 UTF-8 字节比较且清零内部缓冲区', () {
    expect(sensitiveUtf8Equals('same-password', 'same-password'), isTrue);
    expect(sensitiveUtf8Equals('\u00e9-password', 'e\u0301-password'), isFalse);
    expect(sensitiveUtf8Equals('password-a', 'password-b'), isFalse);
  });
}
