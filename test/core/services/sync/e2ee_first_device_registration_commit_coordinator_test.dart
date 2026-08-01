import 'package:Kelivo/core/services/sync/e2ee_first_device_registration_commit_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const coordinator = E2eeFirstDeviceRegistrationCommitCoordinator();

  test('首次注册先耐久保存待导出事务和确认状态再发送网络请求', () async {
    final events = <String>[];

    final result = await coordinator.start<String>(
      persistAwaitingExport: () async => events.add('persist-awaiting'),
      exportRecoveryMedia: () async {
        events.add('export');
        return true;
      },
      persistExportConfirmed: () async => events.add('persist-confirmed'),
      installAccountState: () async => events.add('install-state'),
      submitRegistration: () async {
        events.add('submit');
        return 'session';
      },
    );

    expect(result, 'session');
    expect(events, <String>[
      'persist-awaiting',
      'export',
      'persist-confirmed',
      'install-state',
      'submit',
    ]);
  });

  test('取消介质导出时保留待导出事务且不安装状态或发送请求', () async {
    final events = <String>[];

    await expectLater(
      coordinator.start<void>(
        persistAwaitingExport: () async => events.add('persist-awaiting'),
        exportRecoveryMedia: () async {
          events.add('export');
          return false;
        },
        persistExportConfirmed: () async => events.add('persist-confirmed'),
        installAccountState: () async => events.add('install-state'),
        submitRegistration: () async => events.add('submit'),
      ),
      throwsA(isA<E2eeRecoveryMediaExportCancelled>()),
    );

    expect(events, <String>['persist-awaiting', 'export']);
  });

  test('确认状态持久化失败时不安装状态或发送请求', () async {
    final events = <String>[];

    await expectLater(
      coordinator.start<void>(
        persistAwaitingExport: () async => events.add('persist-awaiting'),
        exportRecoveryMedia: () async {
          events.add('export');
          return true;
        },
        persistExportConfirmed: () async {
          events.add('persist-confirmed');
          throw StateError('persist-confirmed-failed');
        },
        installAccountState: () async => events.add('install-state'),
        submitRegistration: () async => events.add('submit'),
      ),
      throwsStateError,
    );

    expect(events, <String>['persist-awaiting', 'export', 'persist-confirmed']);
  });

  test('显式恢复已确认事务时跳过导出并在安装状态后发送请求', () async {
    final events = <String>[];

    final result = await coordinator.resume<String>(
      stage: E2eeRecoveryMediaCommitStage.exportConfirmed,
      exportRecoveryMedia: () async {
        events.add('export');
        return true;
      },
      persistExportConfirmed: () async => events.add('persist-confirmed'),
      installAccountState: () async => events.add('install-state'),
      submitRegistration: () async {
        events.add('submit');
        return 'resumed-session';
      },
    );

    expect(result, 'resumed-session');
    expect(events, <String>['install-state', 'submit']);
  });
}
