import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/common.dart' show AllowedArgumentCount;

import 'database_cipher.dart';

part 'app_database.g.dart';

typedef SqliteExecutionIsolateProbeResult = ({
  int samples,
  int openingIsolateCalls,
  int backgroundIsolateCalls,
});

class MicrosecondDateTimeConverter extends TypeConverter<DateTime, int> {
  const MicrosecondDateTimeConverter();

  @override
  DateTime fromSql(int fromDb) => DateTime.fromMicrosecondsSinceEpoch(fromDb);

  @override
  int toSql(DateTime value) => value.microsecondsSinceEpoch;
}

@TableIndex(
  name: 'idx_conversations_updated_at',
  columns: {
    IndexedColumn(#updatedAt, orderBy: OrderingMode.desc),
    IndexedColumn(#id, orderBy: OrderingMode.asc),
  },
)
@TableIndex(name: 'idx_conversations_assistant', columns: {#assistantId})
class ConversationRows extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  TextColumn get assistantId => text().nullable()();
  IntColumn get truncateIndex => integer()
      // ignore: recursive_getters
      .check(truncateIndex.isBiggerOrEqualValue(-1))
      .withDefault(const Constant(-1))();
  TextColumn get versionSelectionsJson =>
      text().withDefault(const Constant('{}'))();
  TextColumn get summary => text().nullable()();
  IntColumn get lastSummarizedMessageCount => integer()
      // ignore: recursive_getters
      .check(lastSummarizedMessageCount.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();
  TextColumn get chatSuggestionsJson =>
      text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_messages_conversation_order',
  columns: {#conversationId, #messageOrder, #id},
)
@TableIndex(
  name: 'idx_messages_conversation_timestamp',
  columns: {#conversationId, #timestamp, #id},
)
@TableIndex(
  name: 'idx_messages_group',
  columns: {#conversationId, #groupId, #version, #id},
)
@TableIndex(
  name: 'idx_messages_turn',
  columns: {#conversationId, #turnId, #messageOrder, #id},
)
class MessageRows extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(ConversationRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get role =>
      text()
      // ignore: recursive_getters
      .check(role.isNotValue(''))();
  TextColumn get content => text()();
  IntColumn get timestamp =>
      integer().map(const MicrosecondDateTimeConverter())();
  TextColumn get modelId => text().nullable()();
  TextColumn get providerId => text().nullable()();
  IntColumn get totalTokens => integer()
      // ignore: recursive_getters
      .check(totalTokens.isBiggerOrEqualValue(0))
      .nullable()();
  BoolColumn get isStreaming => boolean().withDefault(const Constant(false))();
  TextColumn get reasoningText => text().nullable()();
  IntColumn get reasoningStartAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();
  IntColumn get reasoningFinishedAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();
  TextColumn get translation => text().nullable()();
  TextColumn get reasoningSegmentsJson => text().nullable()();
  TextColumn get groupId => text().nullable()();
  TextColumn get turnId =>
      text()
      // ignore: recursive_getters
      .check(turnId.isNotValue(''))();
  TextColumn get generationStatus => text().check(
    // ignore: recursive_getters
    generationStatus.isIn(const {
      'draft',
      'completed',
      'interrupted',
      'failed',
    }),
  )();
  IntColumn get version => integer()
      // ignore: recursive_getters
      .check(version.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();
  IntColumn get promptTokens => integer()
      // ignore: recursive_getters
      .check(promptTokens.isBiggerOrEqualValue(0))
      .nullable()();
  IntColumn get completionTokens => integer()
      // ignore: recursive_getters
      .check(completionTokens.isBiggerOrEqualValue(0))
      .nullable()();
  IntColumn get cachedTokens => integer()
      // ignore: recursive_getters
      .check(cachedTokens.isBiggerOrEqualValue(0))
      .nullable()();
  IntColumn get durationMs => integer()
      // ignore: recursive_getters
      .check(durationMs.isBiggerOrEqualValue(0))
      .nullable()();
  IntColumn get messageOrder =>
      integer()
      // ignore: recursive_getters
      .check(messageOrder.isBiggerOrEqualValue(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {conversationId, messageOrder},
    {conversationId, groupId, version},
  ];
}

@TableIndex(
  name: 'idx_turns_conversation_created',
  columns: {#conversationId, #createdAt, #id},
)
class TurnRows extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(ConversationRows, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ConversationMcpServerRows extends Table {
  TextColumn get conversationId =>
      text().references(ConversationRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get serverId => text()();
  IntColumn get ordinal =>
      integer()
      // ignore: recursive_getters
      .check(ordinal.isBiggerOrEqualValue(0))();

  @override
  Set<Column<Object>> get primaryKey => {conversationId, serverId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {conversationId, ordinal},
  ];
}

class ToolEventRows extends Table {
  TextColumn get messageId =>
      text().references(MessageRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get eventsJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {messageId};
}

class GeminiThoughtSignatureRows extends Table {
  TextColumn get messageId =>
      text().references(MessageRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get signature => text()();

  @override
  Set<Column<Object>> get primaryKey => {messageId};
}

class ChatStorageMetaRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@TableIndex(
  name: 'idx_message_parts_revision_ordinal',
  columns: {#conversationId, #revisionId, #ordinal},
)
class MessagePartRows extends Table {
  TextColumn get conversationId => text()();
  TextColumn get revisionId => text()();
  IntColumn get ordinal =>
      integer()
      // ignore: recursive_getters
      .check(ordinal.isBiggerOrEqualValue(0))();
  TextColumn get kind => text().check(
    // ignore: recursive_getters
    kind.isIn(const ['text', 'reasoning', 'tool_call', 'tool_result']),
  )();
  TextColumn get payload => text()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {revisionId, ordinal};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {conversationId, revisionId, ordinal},
  ];

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (revision_id) '
        'REFERENCES message_rows (id) '
        'ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED',
    'CHECK (updated_at >= created_at)',
  ];
}

@TableIndex(
  name: 'idx_provider_artifacts_revision_kind',
  columns: {#conversationId, #revisionId, #kind},
)
class ProviderArtifactRows extends Table {
  TextColumn get conversationId => text()();
  TextColumn get revisionId => text()();
  TextColumn get kind => text().check(
    // ignore: recursive_getters
    kind.isNotValue(''),
  )();
  TextColumn get payload => text()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {revisionId, kind};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (revision_id) '
        'REFERENCES message_rows (id) '
        'ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED',
    'CHECK (updated_at >= created_at)',
  ];
}

class MigrationRunRows extends Table {
  TextColumn get id => text()();
  TextColumn get sourceKind =>
      text()
      // ignore: recursive_getters
      .check(sourceKind.isIn(const ['hive', 'legacy_json']))();
  TextColumn get sourceHash => text()();
  TextColumn get status =>
      text()
      // ignore: recursive_getters
      .check(status.isIn(const ['building', 'completed', 'failed']))();
  IntColumn get startedAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get completedAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sourceKind, sourceHash},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (completed_at IS NULL OR completed_at >= started_at)',
  ];
}

@TableIndex(
  name: 'idx_migration_issues_run_kind',
  columns: {#migrationRunId, #kind, #id},
)
class MigrationIssueRows extends Table {
  TextColumn get id => text()();
  TextColumn get migrationRunId =>
      text().references(MigrationRunRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get conversationId => text().nullable()();
  TextColumn get sourceEntityId => text().nullable()();
  TextColumn get kind => text()();
  TextColumn get severity =>
      text()
      // ignore: recursive_getters
      .check(severity.isIn(const ['warning', 'recovered', 'rejected']))();
  TextColumn get detailsJson => text().withDefault(const Constant('{}'))();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_generation_runs_active_target '
  'ON generation_run_rows (conversation_id, target_revision_id) '
  "WHERE state IN ('preparing', 'requesting', 'streaming', 'waiting_tool')",
)
@TableIndex(
  name: 'idx_generation_runs_state_updated',
  columns: {#state, #updatedAt, #id},
)
class GenerationRunRows extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(ConversationRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get targetRevisionId => text()();
  TextColumn get state => text().check(
    // ignore: recursive_getters
    state.isIn(const [
      'preparing',
      'requesting',
      'streaming',
      'waiting_tool',
      'completed',
      'failed',
      'cancelled',
      'interrupted',
    ]),
  )();
  IntColumn get stateRevision => integer()
      // ignore: recursive_getters
      .check(stateRevision.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();
  IntColumn get checkpointSeq => integer()
      // ignore: recursive_getters
      .check(checkpointSeq.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();
  TextColumn get errorCode => text().nullable()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get terminalAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (target_revision_id) '
        'REFERENCES message_rows (id) '
        'DEFERRABLE INITIALLY DEFERRED',
    'CHECK (updated_at >= created_at)',
    'CHECK (terminal_at IS NULL OR terminal_at >= created_at)',
    "CHECK ((state IN ('preparing', 'requesting', 'streaming', "
        "'waiting_tool') AND terminal_at IS NULL) OR "
        "(state IN ('completed', 'failed', 'cancelled', 'interrupted') "
        'AND terminal_at IS NOT NULL))',
    "CHECK (error_code IS NULL OR (length(error_code) BETWEEN 1 AND 128 "
        "AND state IN ('failed', 'cancelled', 'interrupted')))",
  ];
}

@DriftDatabase(
  tables: [
    ConversationRows,
    MessageRows,
    TurnRows,
    ConversationMcpServerRows,
    ToolEventRows,
    GeminiThoughtSignatureRows,
    ChatStorageMetaRows,
    MessagePartRows,
    ProviderArtifactRows,
    MigrationRunRows,
    MigrationIssueRows,
    GenerationRunRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._(super.executor);

  static const databaseFileName = 'kelivo.db';

  // 定制同步协议把轮次身份和稳定生成终态作为持久化事实。版本 12
  // 与上游未发布的版本 11 硬切，避免旧库被误认为具备这些列。
  static const currentSchemaVersion = 12;
  // 明确保留 SQLite 既有的 1000 页检查点节奏。按常见的 4 KiB 页大小计算，
  // 会在约 4 MiB 时开始检查点，但真实边界仍以页大小为准。
  static const walAutoCheckpointPages = 1000;
  // 该设置限制重置或检查点后保留的 journal/WAL 空间，
  // 并不承诺活跃 WAL 永远不会暂时超过 16 MiB。
  static const journalSizeLimitBytes = 16 << 20;
  static const busyTimeoutMillis = 5000;
  static const synchronousFull = 2;
  static const _executionIsolateProbeFunction =
      'kelivo_sqlite_on_opening_isolate';
  static const _attachEncryptedDatabaseFunction =
      'kelivo_sqlite_attach_encrypted_database';
  static const _maxExecutionIsolateProbeSamples = 1000;

  factory AppDatabase.open({
    required File file,
    required DatabaseCipher cipher,
  }) {
    final databaseType = FileSystemEntity.typeSync(
      file.path,
      followLinks: false,
    );
    if (databaseType != FileSystemEntityType.notFound &&
        databaseType != FileSystemEntityType.file) {
      throw StateError('database_type');
    }
    return AppDatabase._(
      _openExecutor(
        file,
        cipher: cipher,
        createSlotIfMissing: databaseType == FileSystemEntityType.notFound,
      ),
    );
  }

  static QueryExecutor _openExecutor(
    File file, {
    required DatabaseCipher cipher,
    required bool createSlotIfMissing,
  }) {
    final openingIsolatePort = Isolate.current.controlPort;
    return NativeDatabase.createInBackground(
      file,
      setup: (database) {
        // 设键必须早于版本、schema 或 PRAGMA 读取，否则 SQLCipher 会把密文库
        // 当成损坏库，也可能在新库中留下未加密的第一页。
        cipher.apply(database, createSlotIfMissing: createSlotIfMissing);
        final installedSchema = database.userVersion;
        if (installedSchema != 0 &&
            installedSchema != AppDatabase.currentSchemaVersion) {
          throw StateError('database_schema_version');
        }
        // 此回调由 SQLite 在 Drift 工作 isolate 上注册并调用。
        // 必须保持非确定性，以免 SQLite 将多行探测查询折叠成一次回调。
        database.createFunction(
          functionName: _executionIsolateProbeFunction,
          argumentCount: const AllowedArgumentCount(0),
          deterministic: false,
          directOnly: true,
          function: (_) =>
              Isolate.current.controlPort == openingIsolatePort ? 1 : 0,
        );
        database.createFunction(
          functionName: _attachEncryptedDatabaseFunction,
          argumentCount: const AllowedArgumentCount(2),
          deterministic: false,
          directOnly: true,
          function: (arguments) {
            final databasePath = arguments[0];
            final databaseName = arguments[1];
            if (databasePath is! String || databaseName is! String) {
              throw StateError('database_cipher_attach_arguments');
            }
            // ATTACH 必须在 Drift 的数据库 isolate 和同一原生连接上完成，
            // 因此只把非秘密路径与内部别名送入这个 direct-only 函数。
            cipher.attachExisting(
              database,
              databaseFile: File(databasePath),
              databaseName: databaseName,
            );
            return 1;
          },
        );
        database.execute('PRAGMA journal_mode = WAL;');
        database.execute('PRAGMA foreign_keys = ON;');
        database.execute('PRAGMA busy_timeout = $busyTimeoutMillis;');
        database.execute('PRAGMA synchronous = FULL;');
        database.execute(
          'PRAGMA wal_autocheckpoint = $walAutoCheckpointPages;',
        );
        database.execute('PRAGMA journal_size_limit = $journalSizeLimitBytes;');
      },
    );
  }

  Future<void> attachEncryptedDatabase({
    required File databaseFile,
    required String databaseName,
  }) async {
    final row = await customSelect(
      'SELECT $_attachEncryptedDatabaseFunction(?, ?) AS attached;',
      variables: [
        Variable.withString(databaseFile.absolute.path),
        Variable.withString(databaseName),
      ],
    ).getSingle();
    if (row.read<int>('attached') != 1) {
      throw StateError('database_cipher_attach_failed');
    }
  }

  /// 采样活动 SQLite 连接执行回调所处的 isolate。
  ///
  /// 在性能探针中，打开连接的 isolate 是 Flutter UI isolate。
  Future<SqliteExecutionIsolateProbeResult> probeExecutionIsolate({
    int samples = 64,
  }) async {
    RangeError.checkValueInInterval(
      samples,
      1,
      _maxExecutionIsolateProbeSamples,
      'samples',
    );
    final row = await customSelect(
      '''
WITH RECURSIVE probe(sample) AS (
  VALUES (1)
  UNION ALL
  SELECT sample + 1 FROM probe WHERE sample < ?
)
SELECT
  COUNT(*) AS sample_count,
  COALESCE(SUM($_executionIsolateProbeFunction()), 0)
    AS opening_isolate_calls
FROM probe;
''',
      variables: [Variable.withInt(samples)],
    ).getSingle();
    final sampleCount = row.read<int>('sample_count');
    final openingIsolateCalls = row.read<int>('opening_isolate_calls');
    return (
      samples: sampleCount,
      openingIsolateCalls: openingIsolateCalls,
      backgroundIsolateCalls: sampleCount - openingIsolateCalls,
    );
  }

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (_, _, _) async {
      throw StateError('database_schema_version');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement('PRAGMA busy_timeout = 5000;');
    },
  );
}
