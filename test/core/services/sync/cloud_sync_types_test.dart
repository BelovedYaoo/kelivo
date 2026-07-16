import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';

void main() {
  test('指令注入实体同时被类型解析器和支持集合识别', () {
    expect(
      CloudSyncEntityType.parse('instruction-injection').wireName,
      'instruction-injection',
    );
    expect(isSupportedCloudSyncEntityType('instruction-injection'), isTrue);
  });

  test('所有同步实体枚举都属于支持集合', () {
    for (final entityType in CloudSyncEntityType.values) {
      expect(
        isSupportedCloudSyncEntityType(entityType.wireName),
        isTrue,
        reason: entityType.wireName,
      );
    }
  });
}
