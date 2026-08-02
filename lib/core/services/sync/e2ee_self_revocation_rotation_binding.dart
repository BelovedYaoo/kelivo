import 'dart:typed_data';

final _selfRevocationRotationUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

final class E2eeSelfRevocationRotationBinding {
  factory E2eeSelfRevocationRotationBinding({
    required String deviceId,
    required String mutationId,
    required String operationId,
    required int expectedGeneration,
    required int expectedKeyEpoch,
    required Uint8List expectedMembershipManifestDigest,
    required Uint8List intentDigest,
  }) {
    return E2eeSelfRevocationRotationBinding._(
      deviceId: _requireUuid(deviceId, 'deviceId'),
      mutationId: _requireUuid(mutationId, 'mutationId'),
      operationId: _requireUuid(operationId, 'operationId'),
      expectedGeneration: _requirePositiveBoundedInt(
        expectedGeneration,
        0x7ffffffe,
        'expectedGeneration',
      ),
      expectedKeyEpoch: _requirePositiveBoundedInt(
        expectedKeyEpoch,
        0xfffffffe,
        'expectedKeyEpoch',
      ),
      expectedMembershipManifestDigest: _copyDigest(
        expectedMembershipManifestDigest,
        'expectedMembershipManifestDigest',
      ),
      intentDigest: _copyDigest(intentDigest, 'intentDigest'),
    );
  }

  const E2eeSelfRevocationRotationBinding._({
    required this.deviceId,
    required this.mutationId,
    required this.operationId,
    required this.expectedGeneration,
    required this.expectedKeyEpoch,
    required this._expectedMembershipManifestDigest,
    required this._intentDigest,
  });

  final String deviceId;
  final String mutationId;
  final String operationId;
  final int expectedGeneration;
  final int expectedKeyEpoch;
  final Uint8List _expectedMembershipManifestDigest;
  final Uint8List _intentDigest;

  Uint8List get expectedMembershipManifestDigest =>
      Uint8List.fromList(_expectedMembershipManifestDigest);

  Uint8List get intentDigest => Uint8List.fromList(_intentDigest);

  bool hasSameSecurityBinding(E2eeSelfRevocationRotationBinding other) {
    return deviceId == other.deviceId &&
        mutationId == other.mutationId &&
        operationId == other.operationId &&
        expectedGeneration == other.expectedGeneration &&
        expectedKeyEpoch == other.expectedKeyEpoch &&
        _sameBytes(
          _expectedMembershipManifestDigest,
          other._expectedMembershipManifestDigest,
        ) &&
        _sameBytes(_intentDigest, other._intentDigest);
  }
}

String _requireUuid(String value, String field) {
  if (!_selfRevocationRotationUuidPattern.hasMatch(value)) {
    throw FormatException('$field 必须是规范 UUID v4');
  }
  return value;
}

int _requirePositiveBoundedInt(int value, int maximum, String field) {
  if (value < 1 || value > maximum) {
    throw FormatException('$field 超出协议范围');
  }
  return value;
}

Uint8List _copyDigest(Uint8List value, String field) {
  if (value.length != 32) {
    throw FormatException('$field 必须为 32 字节');
  }
  return Uint8List.fromList(value).asUnmodifiableView();
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
