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

class AssetRows extends Table {
  TextColumn get id => text()();
  TextColumn get contentHash => text()();
  TextColumn get path => text()();
  IntColumn get byteSize => integer()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  TextColumn get thumbnailPath => text().nullable()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get lastReferencedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {contentHash},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (typeof(id) = 'text' "
        'AND length(CAST(id AS BLOB)) BETWEEN 1 AND 1024 '
        'AND instr(id, char(0)) = 0)',
    "CHECK (typeof(content_hash) = 'text' AND length(content_hash) = 64 "
        'AND content_hash = lower(content_hash) '
        "AND content_hash NOT GLOB '*[^0-9a-f]*')",
    "CHECK (typeof(path) = 'text' "
        'AND length(CAST(path AS BLOB)) BETWEEN 1 AND 32768 '
        'AND instr(path, char(0)) = 0)',
    "CHECK (typeof(byte_size) = 'integer' "
        'AND byte_size BETWEEN 0 AND 9223372036854775807)',
    'CHECK (width IS NULL OR '
        "(typeof(width) = 'integer' AND width BETWEEN 1 AND 2147483647))",
    'CHECK (height IS NULL OR '
        "(typeof(height) = 'integer' AND height BETWEEN 1 AND 2147483647))",
    'CHECK (thumbnail_path IS NULL OR '
        "(typeof(thumbnail_path) = 'text' "
        'AND length(CAST(thumbnail_path AS BLOB)) BETWEEN 1 AND 32768 '
        'AND instr(thumbnail_path, char(0)) = 0))',
    "CHECK (typeof(created_at) = 'integer' AND created_at >= 0)",
    "CHECK (typeof(last_referenced_at) = 'integer' "
        'AND last_referenced_at >= created_at)',
  ];
}

@TableIndex(
  name: 'idx_message_assets_asset',
  columns: {#assetId, #revisionId, #ordinal},
)
@TableIndex(
  name: 'idx_message_assets_remote_identity',
  columns: {#attachmentId, #uploadId, #keyEpoch, #revisionId, #ordinal},
)
class MessageAssetRows extends Table {
  TextColumn get revisionId =>
      text().references(MessageRows, #id, onDelete: KeyAction.cascade)();
  IntColumn get ordinal => integer()();
  TextColumn get assetId =>
      text().references(AssetRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get mediaType => text().nullable()();
  TextColumn get attachmentId => text().nullable()();
  TextColumn get uploadId => text().nullable()();
  IntColumn get keyEpoch => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {revisionId, ordinal};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {revisionId, attachmentId},
    {revisionId, uploadId},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (typeof(ordinal) = 'integer' AND ordinal BETWEEN 0 AND 31)",
    "CHECK (typeof(kind) = 'text' AND kind IN ('image', 'file'))",
    'CHECK (display_name IS NULL OR '
        "(typeof(display_name) = 'text' "
        'AND length(CAST(display_name AS BLOB)) BETWEEN 1 AND 1024 '
        'AND instr(display_name, char(0)) = 0 '
        "AND instr(display_name, '/') = 0 "
        'AND instr(display_name, char(92)) = 0))',
    'CHECK (media_type IS NULL OR '
        "(typeof(media_type) = 'text' "
        'AND length(CAST(media_type AS BLOB)) BETWEEN 3 AND 255 '
        "AND instr(media_type, '/') BETWEEN 2 AND length(media_type) - 1))",
    "CHECK (kind != 'file' OR "
        '(display_name IS NOT NULL AND media_type IS NOT NULL))',
    'CHECK (attachment_id IS NULL OR '
        "(typeof(attachment_id) = 'text' AND length(attachment_id) = 36 "
        'AND attachment_id = lower(attachment_id) '
        "AND attachment_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(attachment_id, 9, 1) = '-' "
        "AND substr(attachment_id, 14, 1) = '-' "
        "AND substr(attachment_id, 15, 1) = '4' "
        "AND substr(attachment_id, 19, 1) = '-' "
        "AND substr(attachment_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(attachment_id, 24, 1) = '-'))",
    'CHECK (upload_id IS NULL OR '
        "(typeof(upload_id) = 'text' AND length(upload_id) = 36 "
        'AND upload_id = lower(upload_id) '
        "AND upload_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(upload_id, 9, 1) = '-' "
        "AND substr(upload_id, 14, 1) = '-' "
        "AND substr(upload_id, 15, 1) = '4' "
        "AND substr(upload_id, 19, 1) = '-' "
        "AND substr(upload_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(upload_id, 24, 1) = '-'))",
    'CHECK (key_epoch IS NULL OR '
        "(typeof(key_epoch) = 'integer' "
        'AND key_epoch BETWEEN 1 AND 4294967295))',
    'CHECK ((attachment_id IS NULL AND upload_id IS NULL '
        'AND key_epoch IS NULL) OR '
        '(attachment_id IS NOT NULL AND upload_id IS NOT NULL '
        'AND key_epoch IS NOT NULL))',
  ];
}

class AssetGcRows extends Table {
  TextColumn get assetId =>
      text().references(AssetRows, #id, onDelete: KeyAction.cascade)();
  IntColumn get notBefore =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get generation => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {assetId};

  @override
  List<String> get customConstraints => [
    "CHECK (typeof(not_before) = 'integer' AND not_before >= 0)",
    "CHECK (typeof(attempts) = 'integer' "
        'AND attempts BETWEEN 0 AND 9223372036854775807)',
    "CHECK (typeof(generation) = 'integer' "
        'AND generation BETWEEN 0 AND 9223372036854775807)',
  ];
}

class GcAuditRows extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()();
  TextColumn get entityId => text()();
  IntColumn get completedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  List<String> get customConstraints => [
    "CHECK (typeof(kind) = 'text' AND kind = 'asset')",
    "CHECK (typeof(entity_id) = 'text' "
        'AND length(CAST(entity_id AS BLOB)) BETWEEN 1 AND 1024 '
        'AND instr(entity_id, char(0)) = 0)',
    "CHECK (typeof(completed_at) = 'integer' AND completed_at >= 0)",
  ];
}

@TableIndex(
  name: 'idx_asset_gc_quarantine_claim',
  columns: {#assetId, #generation, #state},
)
class AssetGcQuarantineRows extends Table {
  TextColumn get quarantinePath => text()();
  TextColumn get assetId => text()();
  IntColumn get generation => integer()();
  TextColumn get originalPath => text()();
  TextColumn get state => text()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {quarantinePath};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {assetId, generation, originalPath},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (typeof(quarantine_path) = 'text' "
        'AND length(CAST(quarantine_path AS BLOB)) BETWEEN 1 AND 32768 '
        'AND instr(quarantine_path, char(0)) = 0)',
    "CHECK (typeof(asset_id) = 'text' "
        'AND length(CAST(asset_id AS BLOB)) BETWEEN 1 AND 1024 '
        'AND instr(asset_id, char(0)) = 0)',
    "CHECK (typeof(generation) = 'integer' "
        'AND generation BETWEEN 0 AND 9223372036854775807)',
    "CHECK (typeof(original_path) = 'text' "
        'AND length(CAST(original_path AS BLOB)) BETWEEN 1 AND 32768 '
        'AND instr(original_path, char(0)) = 0)',
    "CHECK (typeof(state) = 'text' "
        "AND state IN ('pending', 'completed'))",
    "CHECK (typeof(created_at) = 'integer' AND created_at >= 0)",
  ];
}

class AssetGcLeaseRows extends Table {
  TextColumn get leaseName => text()();
  TextColumn get ownerToken => text()();
  IntColumn get expiresAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {leaseName};

  @override
  List<String> get customConstraints => [
    "CHECK (typeof(lease_name) = 'text' "
        'AND length(CAST(lease_name AS BLOB)) BETWEEN 1 AND 1024 '
        'AND instr(lease_name, char(0)) = 0)',
    "CHECK (typeof(owner_token) = 'text' "
        'AND length(CAST(owner_token AS BLOB)) BETWEEN 1 AND 1024 '
        'AND instr(owner_token, char(0)) = 0)',
    "CHECK (typeof(expires_at) = 'integer' AND expires_at >= 0)",
  ];
}

class AssetReferenceDirtyRows extends Table {
  TextColumn get revisionId =>
      text().references(MessageRows, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {revisionId};
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

@TableIndex(
  name: 'idx_e2ee_sync_record_states_record_version',
  columns: {#recordId, #logicalVersion, #digest},
)
class E2eeSyncRecordStateRows extends Table {
  BlobColumn get digest => blob()();
  TextColumn get recordId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get logicalVersion => integer()();
  TextColumn get kind => text()();
  TextColumn get operationId => text()();
  TextColumn get claimedWriterDeviceId => text()();
  IntColumn get claimedWriterKeyVersion => integer()();
  IntColumn get keyEpoch => integer()();
  IntColumn get acceptedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {digest};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {operationId},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (typeof(digest) = 'blob' AND length(digest) = 32)",
    "CHECK (typeof(record_id) = 'text' AND length(record_id) = 36 "
        "AND record_id = lower(record_id) "
        "AND record_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(record_id, 9, 1) = '-' "
        "AND substr(record_id, 14, 1) = '-' "
        "AND substr(record_id, 15, 1) = '4' "
        "AND substr(record_id, 19, 1) = '-' "
        "AND substr(record_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(record_id, 24, 1) = '-' "
        "AND substr(record_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(record_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(record_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(record_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(record_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(entity_type) = 'text' "
        'AND length(CAST(entity_type AS BLOB)) BETWEEN 1 AND 64)',
    "CHECK (typeof(entity_id) = 'text' "
        'AND length(CAST(entity_id AS BLOB)) BETWEEN 1 AND 1024)',
    "CHECK (typeof(logical_version) = 'integer' "
        'AND logical_version BETWEEN 1 AND 9223372036854775807)',
    "CHECK (typeof(kind) = 'text' AND kind IN ('value', 'tombstone'))",
    "CHECK (typeof(operation_id) = 'text' AND length(operation_id) = 36 "
        "AND operation_id = lower(operation_id) "
        "AND operation_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(operation_id, 9, 1) = '-' "
        "AND substr(operation_id, 14, 1) = '-' "
        "AND substr(operation_id, 15, 1) = '4' "
        "AND substr(operation_id, 19, 1) = '-' "
        "AND substr(operation_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(operation_id, 24, 1) = '-' "
        "AND substr(operation_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(operation_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(operation_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(operation_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(operation_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(claimed_writer_device_id) = 'text' "
        'AND length(claimed_writer_device_id) = 36 '
        'AND claimed_writer_device_id = lower(claimed_writer_device_id) '
        "AND claimed_writer_device_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(claimed_writer_device_id, 9, 1) = '-' "
        "AND substr(claimed_writer_device_id, 14, 1) = '-' "
        "AND substr(claimed_writer_device_id, 15, 1) = '4' "
        "AND substr(claimed_writer_device_id, 19, 1) = '-' "
        "AND substr(claimed_writer_device_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(claimed_writer_device_id, 24, 1) = '-' "
        "AND substr(claimed_writer_device_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(claimed_writer_device_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(claimed_writer_device_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(claimed_writer_device_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(claimed_writer_device_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(claimed_writer_key_version) = 'integer' "
        'AND claimed_writer_key_version BETWEEN 1 AND 4294967295)',
    "CHECK (typeof(key_epoch) = 'integer' "
        'AND key_epoch BETWEEN 1 AND 4294967295)',
    "CHECK (typeof(accepted_at) = 'integer' AND accepted_at >= 0)",
  ];
}

class E2eeSyncRecordParentRows extends Table {
  @ReferenceName('childStateParents')
  BlobColumn get childDigest => blob().references(
    E2eeSyncRecordStateRows,
    #digest,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get ordinal => integer()();
  @ReferenceName('parentStateChildren')
  BlobColumn get parentDigest =>
      blob().references(E2eeSyncRecordStateRows, #digest)();

  @override
  Set<Column<Object>> get primaryKey => {childDigest, ordinal};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {childDigest, parentDigest},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (typeof(child_digest) = 'blob' AND length(child_digest) = 32)",
    "CHECK (typeof(ordinal) = 'integer' AND ordinal BETWEEN 0 AND 1)",
    "CHECK (typeof(parent_digest) = 'blob' AND length(parent_digest) = 32)",
    'CHECK (child_digest <> parent_digest)',
  ];
}

class E2eeSyncRecordHeadRows extends Table {
  BlobColumn get digest => blob().references(
    E2eeSyncRecordStateRows,
    #digest,
    onDelete: KeyAction.cascade,
  )();

  @override
  Set<Column<Object>> get primaryKey => {digest};

  @override
  List<String> get customConstraints => [
    "CHECK (typeof(digest) = 'blob' AND length(digest) = 32)",
  ];
}

@TableIndex(
  name: 'idx_e2ee_sync_intents_phase_updated',
  columns: {#phase, #updatedAt, #entityType, #entityId},
)
class E2eeSyncIntentRows extends Table {
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get intentId => text()();
  IntColumn get generation => integer()();
  TextColumn get phase => text()();
  TextColumn get writerSessionId => text().nullable()();
  TextColumn get sealLeaseToken => text().nullable()();
  TextColumn get sealOwnerSessionId => text().nullable()();
  IntColumn get sealLeaseExpiresAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {entityType, entityId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {intentId},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (typeof(entity_type) = 'text' "
        'AND length(CAST(entity_type AS BLOB)) BETWEEN 1 AND 64)',
    "CHECK (typeof(entity_id) = 'text' "
        'AND length(CAST(entity_id AS BLOB)) BETWEEN 1 AND 1024)',
    "CHECK (typeof(intent_id) = 'text' AND length(intent_id) = 36 "
        'AND intent_id = lower(intent_id) '
        "AND intent_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(intent_id, 9, 1) = '-' "
        "AND substr(intent_id, 14, 1) = '-' "
        "AND substr(intent_id, 15, 1) = '4' "
        "AND substr(intent_id, 19, 1) = '-' "
        "AND substr(intent_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(intent_id, 24, 1) = '-' "
        "AND substr(intent_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(intent_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(intent_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(intent_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(intent_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(generation) = 'integer' "
        'AND generation BETWEEN 1 AND 9223372036854775807)',
    "CHECK (typeof(phase) = 'text' "
        "AND phase IN ('preparing', 'dirty', 'sealing'))",
    "CHECK ((phase = 'preparing' "
        "AND typeof(writer_session_id) = 'text' "
        'AND length(CAST(writer_session_id AS BLOB)) >= 1 '
        'AND seal_lease_token IS NULL '
        'AND seal_owner_session_id IS NULL '
        'AND seal_lease_expires_at IS NULL) '
        "OR (phase = 'dirty' "
        'AND writer_session_id IS NULL '
        'AND seal_lease_token IS NULL '
        'AND seal_owner_session_id IS NULL '
        'AND seal_lease_expires_at IS NULL) '
        "OR (phase = 'sealing' "
        'AND writer_session_id IS NULL '
        "AND typeof(seal_lease_token) = 'text' "
        'AND length(CAST(seal_lease_token AS BLOB)) >= 1 '
        "AND typeof(seal_owner_session_id) = 'text' "
        'AND length(CAST(seal_owner_session_id AS BLOB)) >= 1 '
        "AND typeof(seal_lease_expires_at) = 'integer' "
        'AND seal_lease_expires_at >= 0))',
    "CHECK (typeof(created_at) = 'integer' AND created_at >= 0)",
    "CHECK (typeof(updated_at) = 'integer' AND updated_at >= created_at)",
  ];
}

@TableIndex(
  name: 'idx_e2ee_sync_operations_entity_generation',
  columns: {#entityType, #entityId, #intentGeneration, #operationId},
)
@TableIndex(
  name: 'idx_e2ee_sync_operations_intent_generation',
  columns: {#intentId, #intentGeneration, #operationId},
)
class E2eeSyncOperationRows extends Table {
  TextColumn get operationId => text()();
  BlobColumn get stateDigest => blob()();
  TextColumn get recordId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get intentId => text()();
  IntColumn get intentGeneration => integer()();
  IntColumn get expectedRevision => integer()();
  TextColumn get accountUserId => text()();
  TextColumn get actorDeviceId => text()();
  IntColumn get claimedWriterKeyVersion => integer()();
  TextColumn get outcome => text()();
  IntColumn get resultRevision => integer().nullable()();
  IntColumn get resultChangeSeq => integer().nullable()();
  IntColumn get currentRevision => integer().nullable()();
  TextColumn get errorCode => text().nullable()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {operationId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {stateDigest},
    {operationId, recordId},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (typeof(operation_id) = 'text' AND length(operation_id) = 36 "
        'AND operation_id = lower(operation_id) '
        "AND operation_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(operation_id, 9, 1) = '-' "
        "AND substr(operation_id, 14, 1) = '-' "
        "AND substr(operation_id, 15, 1) = '4' "
        "AND substr(operation_id, 19, 1) = '-' "
        "AND substr(operation_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(operation_id, 24, 1) = '-' "
        "AND substr(operation_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(operation_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(operation_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(operation_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(operation_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(state_digest) = 'blob' AND length(state_digest) = 32)",
    "CHECK (typeof(record_id) = 'text' AND length(record_id) = 36 "
        'AND record_id = lower(record_id) '
        "AND record_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(record_id, 9, 1) = '-' "
        "AND substr(record_id, 14, 1) = '-' "
        "AND substr(record_id, 15, 1) = '4' "
        "AND substr(record_id, 19, 1) = '-' "
        "AND substr(record_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(record_id, 24, 1) = '-' "
        "AND substr(record_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(record_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(record_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(record_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(record_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(entity_type) = 'text' "
        'AND length(CAST(entity_type AS BLOB)) BETWEEN 1 AND 64)',
    "CHECK (typeof(entity_id) = 'text' "
        'AND length(CAST(entity_id AS BLOB)) BETWEEN 1 AND 1024)',
    "CHECK (typeof(intent_id) = 'text' AND length(intent_id) = 36 "
        'AND intent_id = lower(intent_id) '
        "AND intent_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(intent_id, 9, 1) = '-' "
        "AND substr(intent_id, 14, 1) = '-' "
        "AND substr(intent_id, 15, 1) = '4' "
        "AND substr(intent_id, 19, 1) = '-' "
        "AND substr(intent_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(intent_id, 24, 1) = '-' "
        "AND substr(intent_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(intent_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(intent_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(intent_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(intent_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(intent_generation) = 'integer' "
        'AND intent_generation BETWEEN 1 AND 9223372036854775807)',
    "CHECK (typeof(expected_revision) = 'integer' "
        'AND expected_revision BETWEEN 0 AND 9223372036854775807)',
    "CHECK (typeof(account_user_id) = 'text' AND length(account_user_id) = 36 "
        'AND account_user_id = lower(account_user_id) '
        "AND account_user_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(account_user_id, 9, 1) = '-' "
        "AND substr(account_user_id, 14, 1) = '-' "
        "AND substr(account_user_id, 15, 1) = '4' "
        "AND substr(account_user_id, 19, 1) = '-' "
        "AND substr(account_user_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(account_user_id, 24, 1) = '-' "
        "AND substr(account_user_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(account_user_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(account_user_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(account_user_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(account_user_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(actor_device_id) = 'text' AND length(actor_device_id) = 36 "
        'AND actor_device_id = lower(actor_device_id) '
        "AND actor_device_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(actor_device_id, 9, 1) = '-' "
        "AND substr(actor_device_id, 14, 1) = '-' "
        "AND substr(actor_device_id, 15, 1) = '4' "
        "AND substr(actor_device_id, 19, 1) = '-' "
        "AND substr(actor_device_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(actor_device_id, 24, 1) = '-' "
        "AND substr(actor_device_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(actor_device_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(actor_device_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(actor_device_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(actor_device_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(claimed_writer_key_version) = 'integer' "
        'AND claimed_writer_key_version BETWEEN 1 AND 4294967295)',
    "CHECK (typeof(outcome) = 'text' "
        "AND outcome IN ('active', 'applied', 'conflict', 'rejected'))",
    'CHECK (result_revision IS NULL OR '
        "(typeof(result_revision) = 'integer' AND result_revision >= 1))",
    'CHECK (result_change_seq IS NULL OR '
        "(typeof(result_change_seq) = 'integer' AND result_change_seq >= 0))",
    'CHECK (current_revision IS NULL OR '
        "(typeof(current_revision) = 'integer' AND current_revision >= 1))",
    'CHECK (error_code IS NULL OR '
        "(typeof(error_code) = 'text' "
        'AND length(CAST(error_code AS BLOB)) BETWEEN 1 AND 100))',
    "CHECK ((outcome = 'active' "
        'AND result_revision IS NULL '
        'AND result_change_seq IS NULL '
        'AND current_revision IS NULL '
        'AND error_code IS NULL) '
        "OR (outcome = 'applied' "
        'AND result_revision IS NOT NULL '
        'AND result_change_seq IS NOT NULL '
        'AND current_revision IS NULL '
        'AND error_code IS NULL) '
        "OR (outcome = 'conflict' "
        'AND result_revision IS NULL '
        'AND result_change_seq IS NULL '
        'AND error_code IS NULL) '
        "OR (outcome = 'rejected' "
        'AND result_revision IS NULL '
        'AND result_change_seq IS NULL '
        'AND current_revision IS NULL '
        'AND error_code IS NOT NULL))',
    "CHECK (typeof(created_at) = 'integer' AND created_at >= 0)",
    "CHECK (typeof(updated_at) = 'integer' AND updated_at >= created_at)",
  ];
}

@TableIndex(
  name: 'idx_e2ee_sync_outbox_phase_due',
  columns: {#phase, #nextAttemptAt, #operationId},
)
class E2eeSyncOutboxRows extends Table {
  TextColumn get operationId => text()();
  TextColumn get recordId => text()();
  IntColumn get envelopeVersion => integer()();
  IntColumn get keyEpoch => integer()();
  BlobColumn get ciphertext => blob()();
  TextColumn get phase => text()();
  TextColumn get leaseToken => text().nullable()();
  TextColumn get leaseOwnerSessionId => text().nullable()();
  IntColumn get leaseExpiresAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();
  IntColumn get transitionVersion => integer()();
  IntColumn get attemptCount => integer()();
  IntColumn get nextAttemptAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  TextColumn get lastFailureKind => text().nullable()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {operationId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {recordId},
  ];

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (operation_id, record_id) '
        'REFERENCES e2ee_sync_operation_rows (operation_id, record_id)',
    "CHECK (typeof(operation_id) = 'text' AND length(operation_id) = 36 "
        'AND operation_id = lower(operation_id) '
        "AND operation_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(operation_id, 9, 1) = '-' "
        "AND substr(operation_id, 14, 1) = '-' "
        "AND substr(operation_id, 15, 1) = '4' "
        "AND substr(operation_id, 19, 1) = '-' "
        "AND substr(operation_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(operation_id, 24, 1) = '-' "
        "AND substr(operation_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(operation_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(operation_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(operation_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(operation_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(record_id) = 'text' AND length(record_id) = 36 "
        'AND record_id = lower(record_id) '
        "AND record_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(record_id, 9, 1) = '-' "
        "AND substr(record_id, 14, 1) = '-' "
        "AND substr(record_id, 15, 1) = '4' "
        "AND substr(record_id, 19, 1) = '-' "
        "AND substr(record_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(record_id, 24, 1) = '-' "
        "AND substr(record_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(record_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(record_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(record_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(record_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(envelope_version) = 'integer' AND envelope_version = 1)",
    "CHECK (typeof(key_epoch) = 'integer' "
        'AND key_epoch BETWEEN 1 AND 4294967295)',
    "CHECK (typeof(ciphertext) = 'blob' "
        'AND length(ciphertext) BETWEEN 1 AND 1048576)',
    "CHECK (typeof(phase) = 'text' AND phase IN ('ready', 'sending'))",
    "CHECK ((phase = 'ready' "
        'AND lease_token IS NULL '
        'AND lease_owner_session_id IS NULL '
        'AND lease_expires_at IS NULL) '
        "OR (phase = 'sending' "
        "AND typeof(lease_token) = 'text' "
        'AND length(CAST(lease_token AS BLOB)) >= 1 '
        "AND typeof(lease_owner_session_id) = 'text' "
        'AND length(CAST(lease_owner_session_id AS BLOB)) >= 1 '
        "AND typeof(lease_expires_at) = 'integer' "
        'AND lease_expires_at >= 0))',
    "CHECK (typeof(transition_version) = 'integer' "
        'AND transition_version BETWEEN 1 AND 9223372036854775807)',
    "CHECK (typeof(attempt_count) = 'integer' AND attempt_count >= 0)",
    "CHECK (typeof(next_attempt_at) = 'integer' AND next_attempt_at >= 0)",
    'CHECK (last_failure_kind IS NULL OR '
        "(typeof(last_failure_kind) = 'text' "
        'AND length(CAST(last_failure_kind AS BLOB)) BETWEEN 1 AND 100))',
    "CHECK (typeof(created_at) = 'integer' AND created_at >= 0)",
    "CHECK (typeof(updated_at) = 'integer' AND updated_at >= created_at)",
  ];
}

@TableIndex(
  name: 'idx_e2ee_sync_remote_records_gate_updated',
  columns: {#gate, #updatedAt, #recordId},
)
class E2eeSyncRemoteRecordRows extends Table {
  TextColumn get recordId => text()();
  IntColumn get revision => integer().nullable()();
  IntColumn get lastChangeSeq => integer().nullable()();
  BlobColumn get stateDigest => blob().nullable()();
  TextColumn get gate => text()();
  IntColumn get observedRevision => integer().nullable()();
  TextColumn get errorCode => text().nullable()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {recordId};

  @override
  List<String> get customConstraints => [
    "CHECK (typeof(record_id) = 'text' AND length(record_id) = 36 "
        'AND record_id = lower(record_id) '
        "AND record_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(record_id, 9, 1) = '-' "
        "AND substr(record_id, 14, 1) = '-' "
        "AND substr(record_id, 15, 1) = '4' "
        "AND substr(record_id, 19, 1) = '-' "
        "AND substr(record_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(record_id, 24, 1) = '-' "
        "AND substr(record_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(record_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(record_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(record_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(record_id, 25, 12) NOT GLOB '*-*')",
    'CHECK (revision IS NULL OR '
        "(typeof(revision) = 'integer' AND revision >= 1))",
    'CHECK (last_change_seq IS NULL OR '
        "(typeof(last_change_seq) = 'integer' AND last_change_seq >= 0))",
    'CHECK (state_digest IS NULL OR '
        "(typeof(state_digest) = 'blob' AND length(state_digest) = 32))",
    'CHECK ((revision IS NULL '
        'AND last_change_seq IS NULL '
        'AND state_digest IS NULL) '
        'OR (revision IS NOT NULL '
        'AND last_change_seq IS NOT NULL '
        'AND state_digest IS NOT NULL))',
    "CHECK (typeof(gate) = 'text' "
        "AND gate IN ('ready', 'requires-pull', 'quarantined'))",
    'CHECK (observed_revision IS NULL OR '
        "(typeof(observed_revision) = 'integer' AND observed_revision >= 1))",
    'CHECK (error_code IS NULL OR '
        "(typeof(error_code) = 'text' "
        'AND length(CAST(error_code AS BLOB)) BETWEEN 1 AND 100))',
    "CHECK ((gate = 'ready' "
        'AND observed_revision IS NULL '
        'AND error_code IS NULL) '
        "OR (gate = 'requires-pull' AND error_code IS NULL) "
        "OR (gate = 'quarantined' AND error_code IS NOT NULL))",
    "CHECK (typeof(created_at) = 'integer' AND created_at >= 0)",
    "CHECK (typeof(updated_at) = 'integer' AND updated_at >= created_at)",
  ];
}

class E2eeSyncPullCheckpointRows extends Table {
  TextColumn get accountUserId => text()();
  TextColumn get phase => text()();
  TextColumn get syncCursor => text().nullable()();
  IntColumn get lastChangeSeq => integer()();
  TextColumn get snapshotRunId => text().nullable()();
  TextColumn get snapshotCursor => text().nullable()();
  TextColumn get snapshotLastRecordId => text().nullable()();
  IntColumn get snapshotMaxChangeSeq => integer().nullable()();
  IntColumn get transitionVersion => integer()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {accountUserId};

  @override
  List<String> get customConstraints => [
    "CHECK (typeof(account_user_id) = 'text' "
        'AND length(account_user_id) = 36 '
        'AND account_user_id = lower(account_user_id) '
        "AND account_user_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(account_user_id, 9, 1) = '-' "
        "AND substr(account_user_id, 14, 1) = '-' "
        "AND substr(account_user_id, 15, 1) = '4' "
        "AND substr(account_user_id, 19, 1) = '-' "
        "AND substr(account_user_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(account_user_id, 24, 1) = '-' "
        "AND substr(account_user_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(account_user_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(account_user_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(account_user_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(account_user_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(phase) = 'text' "
        "AND phase IN ('incremental', 'snapshot'))",
    'CHECK (sync_cursor IS NULL OR '
        "(typeof(sync_cursor) = 'text' "
        'AND length(CAST(sync_cursor AS BLOB)) BETWEEN 1 AND 4096))',
    "CHECK (typeof(last_change_seq) = 'integer' "
        'AND last_change_seq BETWEEN 0 AND 9223372036854775807)',
    'CHECK (snapshot_run_id IS NULL OR '
        "(typeof(snapshot_run_id) = 'text' "
        'AND length(snapshot_run_id) = 36 '
        'AND snapshot_run_id = lower(snapshot_run_id) '
        "AND snapshot_run_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(snapshot_run_id, 9, 1) = '-' "
        "AND substr(snapshot_run_id, 14, 1) = '-' "
        "AND substr(snapshot_run_id, 15, 1) = '4' "
        "AND substr(snapshot_run_id, 19, 1) = '-' "
        "AND substr(snapshot_run_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(snapshot_run_id, 24, 1) = '-' "
        "AND substr(snapshot_run_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(snapshot_run_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(snapshot_run_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(snapshot_run_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(snapshot_run_id, 25, 12) NOT GLOB '*-*'))",
    'CHECK (snapshot_cursor IS NULL OR '
        "(typeof(snapshot_cursor) = 'text' "
        'AND length(CAST(snapshot_cursor AS BLOB)) BETWEEN 1 AND 4096))',
    'CHECK (snapshot_last_record_id IS NULL OR '
        "(typeof(snapshot_last_record_id) = 'text' "
        'AND length(snapshot_last_record_id) = 36 '
        'AND snapshot_last_record_id = lower(snapshot_last_record_id) '
        "AND snapshot_last_record_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(snapshot_last_record_id, 9, 1) = '-' "
        "AND substr(snapshot_last_record_id, 14, 1) = '-' "
        "AND substr(snapshot_last_record_id, 15, 1) = '4' "
        "AND substr(snapshot_last_record_id, 19, 1) = '-' "
        "AND substr(snapshot_last_record_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(snapshot_last_record_id, 24, 1) = '-' "
        "AND substr(snapshot_last_record_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(snapshot_last_record_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(snapshot_last_record_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(snapshot_last_record_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(snapshot_last_record_id, 25, 12) NOT GLOB '*-*'))",
    'CHECK (snapshot_max_change_seq IS NULL OR '
        "(typeof(snapshot_max_change_seq) = 'integer' "
        'AND snapshot_max_change_seq BETWEEN 0 AND 9223372036854775807))',
    "CHECK (typeof(transition_version) = 'integer' "
        'AND transition_version BETWEEN 1 AND 9223372036854775807)',
    "CHECK (typeof(created_at) = 'integer' AND created_at >= 0)",
    "CHECK (typeof(updated_at) = 'integer' AND updated_at >= created_at)",
    "CHECK ((phase = 'incremental' "
        'AND snapshot_run_id IS NULL '
        'AND snapshot_cursor IS NULL '
        'AND snapshot_last_record_id IS NULL '
        'AND snapshot_max_change_seq IS NULL) '
        "OR (phase = 'snapshot' "
        'AND sync_cursor IS NULL '
        'AND snapshot_run_id IS NOT NULL '
        'AND snapshot_max_change_seq IS NOT NULL '
        'AND ((snapshot_cursor IS NULL AND snapshot_last_record_id IS NULL) '
        'OR (snapshot_cursor IS NOT NULL '
        'AND snapshot_last_record_id IS NOT NULL))))',
  ];
}

class E2eeConfigEntryRows extends Table {
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  BlobColumn get payload => blob()();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {entityType, entityId};

  @override
  List<String> get customConstraints => [
    "CHECK (typeof(entity_type) = 'text' "
        "AND entity_type IN ('provider', 'assistant', 'memory', "
        "'world-book', 'quick-phrase', 'search-service', 'network-tts', "
        "'mcp-server', 'instruction-injection', 'user-preference'))",
    "CHECK (typeof(entity_id) = 'text' "
        'AND length(CAST(entity_id AS BLOB)) BETWEEN 1 AND 1024 '
        'AND instr(entity_id, char(0)) = 0)',
    "CHECK (typeof(payload) = 'blob' "
        'AND length(payload) BETWEEN 1 AND 1000000)',
    "CHECK (typeof(updated_at) = 'integer' AND updated_at >= 0)",
    "CHECK (entity_type != 'user-preference' OR entity_id IN ("
        "'profile:default', 'provider-grouping:default', "
        "'assistant-selection:default', 'world-book-activity:default', "
        "'instruction-activity:default', 'search-state:default', "
        "'tts-state:default', 'mcp-state:default'))",
  ];
}

@TableIndex(
  name: 'idx_e2ee_attachment_upload_due',
  columns: {#phase, #nextAttemptAt, #createdAt, #attachmentId},
)
class E2eeAttachmentUploadRows extends Table {
  TextColumn get attachmentId => text()();
  TextColumn get localAssetId => text()();
  TextColumn get targetRevisionId => text()();
  IntColumn get targetOrdinal => integer()();
  TextColumn get sourcePath => text()();
  IntColumn get keyEpoch => integer()();
  TextColumn get kind => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get mediaType => text().nullable()();
  BlobColumn get contentSha256 => blob()();
  BlobColumn get wrappedDataKey => blob()();
  IntColumn get totalPlaintextBytes => integer()();
  IntColumn get chunkCount => integer()();
  IntColumn get totalCiphertextBytes => integer()();
  TextColumn get phase => text()();
  TextColumn get createMutationId => text()();
  TextColumn get uploadId => text().nullable()();
  BlobColumn get manifestCiphertext => blob().nullable()();
  TextColumn get commitMutationId => text()();
  IntColumn get nextChunkIndex => integer()();
  IntColumn get pendingChunkIndex => integer().nullable()();
  TextColumn get pendingChunkMutationId => text().nullable()();
  TextColumn get pendingChunkCiphertextPath => text().nullable()();
  IntColumn get pendingChunkCiphertextBytes => integer().nullable()();
  BlobColumn get pendingChunkCiphertextSha256 => blob().nullable()();
  TextColumn get leaseToken => text().nullable()();
  TextColumn get leaseOwnerSessionId => text().nullable()();
  IntColumn get leaseExpiresAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();
  IntColumn get transitionVersion => integer()();
  IntColumn get attemptCount => integer()();
  IntColumn get consecutiveFailureCount => integer()();
  IntColumn get nextAttemptAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  TextColumn get lastFailureKind => text().nullable()();
  TextColumn get terminalFailureKind => text().nullable()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {attachmentId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {uploadId},
    {targetRevisionId, targetOrdinal},
  ];

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (target_revision_id, target_ordinal) '
        'REFERENCES message_asset_rows (revision_id, ordinal) '
        'ON DELETE CASCADE',
    // Drift 只验证字面 SQL；以下尺寸上限必须与安全核心 ABI v8 附件常量同步。
    "CHECK (typeof(attachment_id) = 'text' AND length(attachment_id) = 36 "
        'AND attachment_id = lower(attachment_id) '
        "AND attachment_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(attachment_id, 9, 1) = '-' "
        "AND substr(attachment_id, 14, 1) = '-' "
        "AND substr(attachment_id, 15, 1) = '4' "
        "AND substr(attachment_id, 19, 1) = '-' "
        "AND substr(attachment_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(attachment_id, 24, 1) = '-' "
        "AND substr(attachment_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(attachment_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(attachment_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(attachment_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(attachment_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(local_asset_id) = 'text' "
        'AND length(CAST(local_asset_id AS BLOB)) BETWEEN 1 AND 1024 '
        'AND instr(local_asset_id, char(0)) = 0)',
    "CHECK (typeof(target_revision_id) = 'text' "
        'AND length(CAST(target_revision_id AS BLOB)) BETWEEN 1 AND 1024 '
        'AND instr(target_revision_id, char(0)) = 0)',
    "CHECK (typeof(target_ordinal) = 'integer' "
        'AND target_ordinal BETWEEN 0 AND 31)',
    "CHECK (typeof(source_path) = 'text' "
        'AND length(CAST(source_path AS BLOB)) BETWEEN 1 AND 32768 '
        'AND instr(source_path, char(0)) = 0)',
    "CHECK (typeof(key_epoch) = 'integer' "
        'AND key_epoch BETWEEN 1 AND 4294967295)',
    "CHECK (typeof(kind) = 'text' AND kind IN ('image', 'file'))",
    'CHECK (display_name IS NULL OR '
        "(typeof(display_name) = 'text' "
        'AND length(CAST(display_name AS BLOB)) BETWEEN 1 AND 1024 '
        'AND instr(display_name, char(0)) = 0 '
        "AND instr(display_name, '/') = 0 "
        "AND instr(display_name, char(92)) = 0))",
    'CHECK (media_type IS NULL OR '
        "(typeof(media_type) = 'text' "
        'AND length(CAST(media_type AS BLOB)) BETWEEN 3 AND 255 '
        "AND instr(media_type, '/') BETWEEN 2 AND length(media_type) - 1))",
    "CHECK (kind != 'file' OR "
        '(display_name IS NOT NULL AND media_type IS NOT NULL))',
    "CHECK (typeof(content_sha256) = 'blob' "
        'AND length(content_sha256) = 32)',
    "CHECK (typeof(wrapped_data_key) = 'blob' "
        'AND length(wrapped_data_key) = 116)',
    "CHECK (typeof(total_plaintext_bytes) = 'integer' "
        'AND total_plaintext_bytes BETWEEN 0 AND 4194184000)',
    "CHECK (typeof(chunk_count) = 'integer' "
        'AND chunk_count BETWEEN 1 AND 1000)',
    'CHECK ((total_plaintext_bytes = 0 AND chunk_count = 1) OR '
        '(total_plaintext_bytes > 0 AND chunk_count = '
        '((total_plaintext_bytes - 1) / 4194184) + 1))',
    "CHECK (typeof(total_ciphertext_bytes) = 'integer' "
        'AND total_ciphertext_bytes = total_plaintext_bytes + '
        'chunk_count * 120)',
    "CHECK (typeof(phase) = 'text' AND phase IN "
        "('create-pending', 'manifest-pending', 'uploading', "
        "'commit-pending', 'committed'))",
    "CHECK (typeof(create_mutation_id) = 'text' "
        'AND length(create_mutation_id) = 36 '
        'AND create_mutation_id = lower(create_mutation_id) '
        "AND create_mutation_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(create_mutation_id, 9, 1) = '-' "
        "AND substr(create_mutation_id, 14, 1) = '-' "
        "AND substr(create_mutation_id, 15, 1) = '4' "
        "AND substr(create_mutation_id, 19, 1) = '-' "
        "AND substr(create_mutation_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(create_mutation_id, 24, 1) = '-' "
        "AND substr(create_mutation_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(create_mutation_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(create_mutation_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(create_mutation_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(create_mutation_id, 25, 12) NOT GLOB '*-*')",
    'CHECK (upload_id IS NULL OR '
        "(typeof(upload_id) = 'text' AND length(upload_id) = 36 "
        'AND upload_id = lower(upload_id) '
        "AND upload_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(upload_id, 9, 1) = '-' "
        "AND substr(upload_id, 14, 1) = '-' "
        "AND substr(upload_id, 15, 1) = '4' "
        "AND substr(upload_id, 19, 1) = '-' "
        "AND substr(upload_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(upload_id, 24, 1) = '-' "
        "AND substr(upload_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(upload_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(upload_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(upload_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(upload_id, 25, 12) NOT GLOB '*-*'))",
    'CHECK (manifest_ciphertext IS NULL OR '
        "(typeof(manifest_ciphertext) = 'blob' "
        'AND length(manifest_ciphertext) BETWEEN 1 AND 1048576))',
    "CHECK (typeof(commit_mutation_id) = 'text' "
        'AND length(commit_mutation_id) = 36 '
        'AND commit_mutation_id = lower(commit_mutation_id) '
        "AND commit_mutation_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(commit_mutation_id, 9, 1) = '-' "
        "AND substr(commit_mutation_id, 14, 1) = '-' "
        "AND substr(commit_mutation_id, 15, 1) = '4' "
        "AND substr(commit_mutation_id, 19, 1) = '-' "
        "AND substr(commit_mutation_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(commit_mutation_id, 24, 1) = '-' "
        "AND substr(commit_mutation_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(commit_mutation_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(commit_mutation_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(commit_mutation_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(commit_mutation_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(next_chunk_index) = 'integer' "
        'AND next_chunk_index BETWEEN 0 AND chunk_count)',
    'CHECK (pending_chunk_index IS NULL OR '
        "(typeof(pending_chunk_index) = 'integer' "
        'AND pending_chunk_index BETWEEN 0 AND chunk_count - 1))',
    'CHECK (pending_chunk_mutation_id IS NULL OR '
        "(typeof(pending_chunk_mutation_id) = 'text' "
        'AND length(pending_chunk_mutation_id) = 36 '
        'AND pending_chunk_mutation_id = lower(pending_chunk_mutation_id) '
        "AND pending_chunk_mutation_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(pending_chunk_mutation_id, 9, 1) = '-' "
        "AND substr(pending_chunk_mutation_id, 14, 1) = '-' "
        "AND substr(pending_chunk_mutation_id, 15, 1) = '4' "
        "AND substr(pending_chunk_mutation_id, 19, 1) = '-' "
        "AND substr(pending_chunk_mutation_id, 20, 1) "
        "IN ('8', '9', 'a', 'b') "
        "AND substr(pending_chunk_mutation_id, 24, 1) = '-' "
        "AND substr(pending_chunk_mutation_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(pending_chunk_mutation_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(pending_chunk_mutation_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(pending_chunk_mutation_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(pending_chunk_mutation_id, 25, 12) NOT GLOB '*-*'))",
    'CHECK (pending_chunk_ciphertext_path IS NULL OR '
        "(typeof(pending_chunk_ciphertext_path) = 'text' "
        'AND length(CAST(pending_chunk_ciphertext_path AS BLOB)) '
        'BETWEEN 1 AND 32768 '
        'AND instr(pending_chunk_ciphertext_path, char(0)) = 0))',
    'CHECK (pending_chunk_ciphertext_bytes IS NULL OR '
        "(typeof(pending_chunk_ciphertext_bytes) = 'integer' "
        'AND pending_chunk_ciphertext_bytes BETWEEN 120 AND 4194304))',
    'CHECK (pending_chunk_ciphertext_sha256 IS NULL OR '
        "(typeof(pending_chunk_ciphertext_sha256) = 'blob' "
        'AND length(pending_chunk_ciphertext_sha256) = 32))',
    'CHECK ((pending_chunk_index IS NULL '
        'AND pending_chunk_mutation_id IS NULL '
        'AND pending_chunk_ciphertext_path IS NULL '
        'AND pending_chunk_ciphertext_bytes IS NULL '
        'AND pending_chunk_ciphertext_sha256 IS NULL) OR '
        '(pending_chunk_index IS NOT NULL '
        'AND pending_chunk_index = next_chunk_index '
        'AND pending_chunk_mutation_id IS NOT NULL '
        'AND pending_chunk_ciphertext_path IS NOT NULL '
        'AND pending_chunk_ciphertext_bytes IS NOT NULL '
        'AND pending_chunk_ciphertext_sha256 IS NOT NULL '
        'AND pending_chunk_ciphertext_bytes = '
        'CASE WHEN pending_chunk_index < chunk_count - 1 '
        'THEN 4194304 '
        'ELSE total_plaintext_bytes - pending_chunk_index * '
        '4194184 + 120 END))',
    'CHECK ((phase = \'create-pending\' '
        'AND upload_id IS NULL AND manifest_ciphertext IS NULL '
        'AND next_chunk_index = 0 AND pending_chunk_index IS NULL) OR '
        '(phase = \'manifest-pending\' '
        'AND upload_id IS NOT NULL AND manifest_ciphertext IS NULL '
        'AND next_chunk_index = 0 AND pending_chunk_index IS NULL) OR '
        '(phase = \'uploading\' '
        'AND upload_id IS NOT NULL AND manifest_ciphertext IS NOT NULL '
        'AND next_chunk_index < chunk_count) OR '
        '(phase IN (\'commit-pending\', \'committed\') '
        'AND upload_id IS NOT NULL AND manifest_ciphertext IS NOT NULL '
        'AND next_chunk_index = chunk_count '
        'AND pending_chunk_index IS NULL))',
    "CHECK (lease_token IS NULL OR (typeof(lease_token) = 'text' "
        'AND length(CAST(lease_token AS BLOB)) BETWEEN 1 AND 1024))',
    'CHECK (lease_owner_session_id IS NULL OR '
        "(typeof(lease_owner_session_id) = 'text' "
        'AND length(CAST(lease_owner_session_id AS BLOB)) '
        'BETWEEN 1 AND 1024))',
    'CHECK ((lease_token IS NULL AND lease_owner_session_id IS NULL '
        'AND lease_expires_at IS NULL) OR '
        "(phase != 'committed' AND terminal_failure_kind IS NULL "
        'AND lease_token IS NOT NULL '
        'AND lease_owner_session_id IS NOT NULL '
        "AND typeof(lease_expires_at) = 'integer' "
        'AND lease_expires_at >= 0))',
    "CHECK (typeof(transition_version) = 'integer' "
        'AND transition_version BETWEEN 1 AND 9223372036854775807)',
    "CHECK (typeof(attempt_count) = 'integer' "
        'AND attempt_count BETWEEN 0 AND 9223372036854775807)',
    "CHECK (typeof(consecutive_failure_count) = 'integer' "
        'AND consecutive_failure_count BETWEEN 0 AND 9223372036854775807)',
    'CHECK (consecutive_failure_count <= attempt_count)',
    'CHECK ((consecutive_failure_count = 0 AND last_failure_kind IS NULL) OR '
        '(consecutive_failure_count >= 1 AND last_failure_kind IS NOT NULL))',
    "CHECK (typeof(next_attempt_at) = 'integer' AND next_attempt_at >= 0)",
    'CHECK (last_failure_kind IS NULL OR '
        "(typeof(last_failure_kind) = 'text' "
        'AND length(CAST(last_failure_kind AS BLOB)) BETWEEN 1 AND 100))',
    'CHECK (terminal_failure_kind IS NULL OR '
        "(phase != 'committed' AND lease_token IS NULL "
        'AND consecutive_failure_count >= 1 '
        'AND last_failure_kind = terminal_failure_kind '
        "AND typeof(terminal_failure_kind) = 'text' "
        'AND length(CAST(terminal_failure_kind AS BLOB)) BETWEEN 1 AND 100))',
    "CHECK (phase != 'committed' OR "
        '(terminal_failure_kind IS NULL '
        'AND consecutive_failure_count = 0 '
        'AND last_failure_kind IS NULL))',
    "CHECK (typeof(created_at) = 'integer' AND created_at >= 0)",
    "CHECK (typeof(updated_at) = 'integer' AND updated_at >= created_at)",
  ];
}

@TableIndex(
  name: 'idx_e2ee_attachment_download_due',
  columns: {#phase, #nextAttemptAt, #createdAt, #attachmentId},
)
@TableIndex(
  name: 'idx_e2ee_attachment_download_local_asset',
  columns: {#localAssetId, #attachmentId},
)
class E2eeAttachmentDownloadRows extends Table {
  TextColumn get attachmentId => text()();
  TextColumn get uploadId => text()();
  IntColumn get keyEpoch => integer()();
  TextColumn get kind => text()();
  TextColumn get phase => text()();
  BlobColumn get manifestCiphertext => blob().nullable()();
  BlobColumn get contentSha256 => blob().nullable()();
  BlobColumn get wrappedDataKey => blob().nullable()();
  IntColumn get totalPlaintextBytes => integer().nullable()();
  IntColumn get chunkCount => integer().nullable()();
  IntColumn get totalCiphertextBytes => integer().nullable()();
  TextColumn get displayName => text().nullable()();
  TextColumn get mediaType => text().nullable()();
  TextColumn get localAssetId => text().nullable()();
  TextColumn get stagingPath => text().nullable()();
  TextColumn get finalPath => text().nullable()();
  IntColumn get nextChunkIndex => integer()();
  IntColumn get confirmedPlaintextBytes => integer()();
  TextColumn get leaseToken => text().nullable()();
  TextColumn get leaseOwnerSessionId => text().nullable()();
  IntColumn get leaseExpiresAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();
  IntColumn get transitionVersion => integer()();
  IntColumn get attemptCount => integer()();
  IntColumn get consecutiveFailureCount => integer()();
  IntColumn get nextAttemptAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  TextColumn get lastFailureKind => text().nullable()();
  TextColumn get terminalFailureKind => text().nullable()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {attachmentId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {uploadId},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (typeof(attachment_id) = 'text' AND length(attachment_id) = 36 "
        'AND attachment_id = lower(attachment_id) '
        "AND attachment_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(attachment_id, 9, 1) = '-' "
        "AND substr(attachment_id, 14, 1) = '-' "
        "AND substr(attachment_id, 15, 1) = '4' "
        "AND substr(attachment_id, 19, 1) = '-' "
        "AND substr(attachment_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(attachment_id, 24, 1) = '-' "
        "AND substr(attachment_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(attachment_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(attachment_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(attachment_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(attachment_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(upload_id) = 'text' AND length(upload_id) = 36 "
        'AND upload_id = lower(upload_id) '
        "AND upload_id NOT GLOB '*[^0-9a-f-]*' "
        "AND substr(upload_id, 9, 1) = '-' "
        "AND substr(upload_id, 14, 1) = '-' "
        "AND substr(upload_id, 15, 1) = '4' "
        "AND substr(upload_id, 19, 1) = '-' "
        "AND substr(upload_id, 20, 1) IN ('8', '9', 'a', 'b') "
        "AND substr(upload_id, 24, 1) = '-' "
        "AND substr(upload_id, 1, 8) NOT GLOB '*-*' "
        "AND substr(upload_id, 10, 4) NOT GLOB '*-*' "
        "AND substr(upload_id, 15, 4) NOT GLOB '*-*' "
        "AND substr(upload_id, 20, 4) NOT GLOB '*-*' "
        "AND substr(upload_id, 25, 12) NOT GLOB '*-*')",
    "CHECK (typeof(key_epoch) = 'integer' "
        'AND key_epoch BETWEEN 1 AND 4294967295)',
    "CHECK (typeof(kind) = 'text' AND kind IN ('image', 'file'))",
    "CHECK (typeof(phase) = 'text' AND phase IN "
        "('manifest-pending', 'downloading', 'verifying', 'ready'))",
    'CHECK (manifest_ciphertext IS NULL OR '
        "(typeof(manifest_ciphertext) = 'blob' "
        'AND length(manifest_ciphertext) BETWEEN 1 AND 1048576))',
    'CHECK (content_sha256 IS NULL OR '
        "(typeof(content_sha256) = 'blob' AND length(content_sha256) = 32))",
    'CHECK (wrapped_data_key IS NULL OR '
        "(typeof(wrapped_data_key) = 'blob' "
        'AND length(wrapped_data_key) = 116))',
    'CHECK (total_plaintext_bytes IS NULL OR '
        "(typeof(total_plaintext_bytes) = 'integer' "
        'AND total_plaintext_bytes BETWEEN 0 AND 4194184000))',
    'CHECK (chunk_count IS NULL OR '
        "(typeof(chunk_count) = 'integer' "
        'AND chunk_count BETWEEN 1 AND 1000))',
    'CHECK (total_ciphertext_bytes IS NULL OR '
        "(typeof(total_ciphertext_bytes) = 'integer' "
        'AND total_ciphertext_bytes BETWEEN 120 AND 4194304000))',
    'CHECK ((total_plaintext_bytes IS NULL AND chunk_count IS NULL '
        'AND total_ciphertext_bytes IS NULL) OR '
        '(total_plaintext_bytes IS NOT NULL AND chunk_count IS NOT NULL '
        'AND total_ciphertext_bytes = total_plaintext_bytes + '
        'chunk_count * 120 AND '
        '((total_plaintext_bytes = 0 AND chunk_count = 1) OR '
        '(total_plaintext_bytes > 0 AND chunk_count = '
        '((total_plaintext_bytes - 1) / 4194184) + 1))))',
    'CHECK (display_name IS NULL OR '
        "(typeof(display_name) = 'text' "
        'AND length(CAST(display_name AS BLOB)) BETWEEN 1 AND 1024 '
        'AND instr(display_name, char(0)) = 0 '
        "AND instr(display_name, '/') = 0 "
        'AND instr(display_name, char(92)) = 0))',
    'CHECK (media_type IS NULL OR '
        "(typeof(media_type) = 'text' "
        'AND length(CAST(media_type AS BLOB)) BETWEEN 3 AND 255 '
        "AND instr(media_type, '/') BETWEEN 2 AND length(media_type) - 1))",
    'CHECK (local_asset_id IS NULL OR '
        "(typeof(local_asset_id) = 'text' "
        'AND length(CAST(local_asset_id AS BLOB)) BETWEEN 1 AND 1024 '
        'AND instr(local_asset_id, char(0)) = 0))',
    'CHECK (staging_path IS NULL OR '
        "(typeof(staging_path) = 'text' "
        'AND length(CAST(staging_path AS BLOB)) BETWEEN 1 AND 32768 '
        'AND instr(staging_path, char(0)) = 0))',
    'CHECK (final_path IS NULL OR '
        "(typeof(final_path) = 'text' "
        'AND length(CAST(final_path AS BLOB)) BETWEEN 1 AND 32768 '
        'AND instr(final_path, char(0)) = 0))',
    'CHECK (staging_path IS NULL OR final_path IS NULL '
        'OR staging_path != final_path)',
    "CHECK (typeof(next_chunk_index) = 'integer' "
        'AND next_chunk_index BETWEEN 0 AND 1000)',
    "CHECK (typeof(confirmed_plaintext_bytes) = 'integer' "
        'AND confirmed_plaintext_bytes BETWEEN 0 AND 4194184000)',
    'CHECK ((phase = \'manifest-pending\' '
        'AND manifest_ciphertext IS NULL AND content_sha256 IS NULL '
        'AND wrapped_data_key IS NULL AND total_plaintext_bytes IS NULL '
        'AND chunk_count IS NULL AND total_ciphertext_bytes IS NULL '
        'AND display_name IS NULL AND media_type IS NULL '
        'AND local_asset_id IS NULL AND staging_path IS NULL '
        'AND final_path IS NULL AND next_chunk_index = 0 '
        'AND confirmed_plaintext_bytes = 0) OR '
        '(phase = \'downloading\' '
        'AND manifest_ciphertext IS NOT NULL AND content_sha256 IS NOT NULL '
        'AND wrapped_data_key IS NOT NULL AND total_plaintext_bytes IS NOT NULL '
        'AND chunk_count IS NOT NULL AND total_ciphertext_bytes IS NOT NULL '
        'AND local_asset_id IS NOT NULL AND staging_path IS NOT NULL '
        'AND final_path IS NOT NULL AND next_chunk_index < chunk_count '
        'AND confirmed_plaintext_bytes = '
        'MIN(next_chunk_index * 4194184, total_plaintext_bytes) '
        'AND ((kind = \'image\') OR '
        '(display_name IS NOT NULL AND media_type IS NOT NULL))) OR '
        '(phase = \'verifying\' '
        'AND manifest_ciphertext IS NOT NULL AND content_sha256 IS NOT NULL '
        'AND wrapped_data_key IS NOT NULL AND total_plaintext_bytes IS NOT NULL '
        'AND chunk_count IS NOT NULL AND total_ciphertext_bytes IS NOT NULL '
        'AND local_asset_id IS NOT NULL AND staging_path IS NOT NULL '
        'AND final_path IS NOT NULL AND next_chunk_index = chunk_count '
        'AND confirmed_plaintext_bytes = total_plaintext_bytes '
        'AND ((kind = \'image\') OR '
        '(display_name IS NOT NULL AND media_type IS NOT NULL))) OR '
        '(phase = \'ready\' '
        'AND manifest_ciphertext IS NOT NULL AND content_sha256 IS NOT NULL '
        'AND wrapped_data_key IS NOT NULL AND total_plaintext_bytes IS NOT NULL '
        'AND chunk_count IS NOT NULL AND total_ciphertext_bytes IS NOT NULL '
        'AND local_asset_id IS NOT NULL AND staging_path IS NULL '
        'AND final_path IS NOT NULL AND next_chunk_index = chunk_count '
        'AND confirmed_plaintext_bytes = total_plaintext_bytes '
        'AND ((kind = \'image\') OR '
        '(display_name IS NOT NULL AND media_type IS NOT NULL))))',
    "CHECK (lease_token IS NULL OR (typeof(lease_token) = 'text' "
        'AND length(CAST(lease_token AS BLOB)) BETWEEN 1 AND 1024))',
    'CHECK (lease_owner_session_id IS NULL OR '
        "(typeof(lease_owner_session_id) = 'text' "
        'AND length(CAST(lease_owner_session_id AS BLOB)) '
        'BETWEEN 1 AND 1024))',
    'CHECK ((lease_token IS NULL AND lease_owner_session_id IS NULL '
        'AND lease_expires_at IS NULL) OR '
        "(phase IN ('manifest-pending', 'downloading', 'verifying') "
        'AND terminal_failure_kind IS NULL '
        'AND lease_token IS NOT NULL AND lease_owner_session_id IS NOT NULL '
        "AND typeof(lease_expires_at) = 'integer' "
        'AND lease_expires_at >= 0))',
    "CHECK (typeof(transition_version) = 'integer' "
        'AND transition_version BETWEEN 1 AND 9223372036854775807)',
    "CHECK (typeof(attempt_count) = 'integer' "
        'AND attempt_count BETWEEN 0 AND 9223372036854775807)',
    "CHECK (typeof(consecutive_failure_count) = 'integer' "
        'AND consecutive_failure_count BETWEEN 0 AND 9223372036854775807)',
    'CHECK (consecutive_failure_count <= attempt_count)',
    'CHECK ((consecutive_failure_count = 0 AND last_failure_kind IS NULL) OR '
        '(consecutive_failure_count >= 1 AND last_failure_kind IS NOT NULL))',
    "CHECK (typeof(next_attempt_at) = 'integer' AND next_attempt_at >= 0)",
    'CHECK (last_failure_kind IS NULL OR '
        "(typeof(last_failure_kind) = 'text' "
        'AND length(CAST(last_failure_kind AS BLOB)) BETWEEN 1 AND 100))',
    'CHECK (terminal_failure_kind IS NULL OR '
        "(phase != 'ready' AND lease_token IS NULL "
        'AND consecutive_failure_count >= 1 '
        'AND last_failure_kind = terminal_failure_kind '
        "AND typeof(terminal_failure_kind) = 'text' "
        'AND length(CAST(terminal_failure_kind AS BLOB)) BETWEEN 1 AND 100))',
    "CHECK (phase != 'ready' OR "
        '(terminal_failure_kind IS NULL '
        'AND consecutive_failure_count = 0 '
        'AND last_failure_kind IS NULL))',
    "CHECK (typeof(created_at) = 'integer' AND created_at >= 0)",
    "CHECK (typeof(updated_at) = 'integer' AND updated_at >= created_at)",
  ];
}

@DriftDatabase(
  tables: [
    ConversationRows,
    MessageRows,
    AssetRows,
    MessageAssetRows,
    AssetGcRows,
    GcAuditRows,
    AssetGcQuarantineRows,
    AssetGcLeaseRows,
    AssetReferenceDirtyRows,
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
    E2eeSyncRecordStateRows,
    E2eeSyncRecordParentRows,
    E2eeSyncRecordHeadRows,
    E2eeSyncIntentRows,
    E2eeSyncOperationRows,
    E2eeSyncOutboxRows,
    E2eeSyncRemoteRecordRows,
    E2eeSyncPullCheckpointRows,
    E2eeConfigEntryRows,
    E2eeAttachmentUploadRows,
    E2eeAttachmentDownloadRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._(super.executor);

  static const databaseFileName = 'kelivo.db';

  // 消息附件身份已成为 SQLCipher 一等模型，schema 18 无法无损表达有序远端引用。
  static const currentSchemaVersion = 19;
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
