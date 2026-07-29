#ifndef KELIVO_SECURE_CORE_H
#define KELIVO_SECURE_CORE_H

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#if defined(KELIVO_SECURE_CORE_BUILD)
#define KELIVO_CORE_API __declspec(dllexport)
#else
#define KELIVO_CORE_API __declspec(dllimport)
#endif
#elif defined(__GNUC__) || defined(__clang__)
#define KELIVO_CORE_API __attribute__((visibility("default")))
#else
#define KELIVO_CORE_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef int32_t KelivoStatus;

#define KELIVO_CORE_ABI_VERSION UINT32_C(12)
#define KELIVO_CORE_CAPABILITIES_STRUCT_SIZE UINT32_C(32)
#define KELIVO_KEY_SLOT_ID_SIZE ((size_t)16)
#define KELIVO_KEY_POLICY_VERSION UINT32_C(1)
#define KELIVO_INVALID_KEY_HANDLE UINT64_C(0)

#define KELIVO_STATUS_OK INT32_C(0)
#define KELIVO_STATUS_NULL_POINTER INT32_C(1)
#define KELIVO_STATUS_INVALID_SLOT_ID_LENGTH INT32_C(2)
#define KELIVO_STATUS_UNSUPPORTED_POLICY INT32_C(3)
#define KELIVO_STATUS_INVALID_KEY_HANDLE INT32_C(4)
#define KELIVO_STATUS_OUTPUT_BUFFER_TOO_SMALL INT32_C(5)
#define KELIVO_STATUS_SLOT_NOT_FOUND INT32_C(6)
#define KELIVO_STATUS_SLOT_ALREADY_EXISTS INT32_C(7)
#define KELIVO_STATUS_SLOT_DATA_INVALID INT32_C(8)
#define KELIVO_STATUS_SLOT_UNWRAP_FAILED INT32_C(9)
#define KELIVO_STATUS_SECURE_STORAGE_UNAVAILABLE INT32_C(10)
#define KELIVO_STATUS_RANDOM_SOURCE_FAILURE INT32_C(11)
#define KELIVO_STATUS_IO_FAILURE INT32_C(12)
#define KELIVO_STATUS_INTERNAL_STATE INT32_C(13)
#define KELIVO_STATUS_INVALID_RECORD_ID_LENGTH INT32_C(14)
#define KELIVO_STATUS_INVALID_ARGUMENT INT32_C(15)
#define KELIVO_STATUS_RECORD_ENVELOPE_INVALID INT32_C(16)
#define KELIVO_STATUS_RECORD_AUTHENTICATION_FAILED INT32_C(17)
#define KELIVO_STATUS_INPUT_TOO_LARGE INT32_C(18)
#define KELIVO_STATUS_SQLCIPHER_KEY_FAILED INT32_C(19)
#define KELIVO_STATUS_SQLCIPHER_ATTACH_FAILED INT32_C(20)
#define KELIVO_STATUS_INVALID_OPAQUE_STATE_HANDLE INT32_C(21)
#define KELIVO_STATUS_OPAQUE_MESSAGE_INVALID INT32_C(22)
#define KELIVO_STATUS_OPAQUE_PROTOCOL_FAILED INT32_C(23)
#define KELIVO_STATUS_TOO_MANY_ACTIVE_HANDLES INT32_C(24)
#define KELIVO_STATUS_HANDLE_SPACE_EXHAUSTED INT32_C(25)
#define KELIVO_STATUS_INVALID_ACCOUNT_ID INT32_C(26)
#define KELIVO_STATUS_INVALID_DEVICE_IDENTITY_HANDLE INT32_C(27)
#define KELIVO_STATUS_INVALID_ACCOUNT_ROOT_KEY_HANDLE INT32_C(28)
#define KELIVO_STATUS_DEVICE_MESSAGE_INVALID INT32_C(29)
#define KELIVO_STATUS_DEVICE_AUTHENTICATION_FAILED INT32_C(30)
#define KELIVO_STATUS_DEVICE_STATE_INVALID INT32_C(31)
#define KELIVO_STATUS_DEVICE_STATE_AUTHENTICATION_FAILED INT32_C(32)
#define KELIVO_STATUS_INVALID_PENDING_PAIRING_HANDLE INT32_C(33)
#define KELIVO_STATUS_PAIRING_EXPIRED INT32_C(34)
#define KELIVO_STATUS_PENDING_PAIRING_STATE_INVALID INT32_C(35)
#define KELIVO_STATUS_INVALID_ATTACHMENT_DATA_KEY_HANDLE INT32_C(36)
#define KELIVO_STATUS_ATTACHMENT_ENVELOPE_INVALID INT32_C(37)
#define KELIVO_STATUS_ATTACHMENT_AUTHENTICATION_FAILED INT32_C(38)
#define KELIVO_STATUS_UNSUPPORTED_PLATFORM INT32_C(100)

#define KELIVO_SECURE_STORAGE_BACKEND_NONE UINT32_C(0)
#define KELIVO_SECURE_STORAGE_BACKEND_WINDOWS_DPAPI UINT32_C(1)
#define KELIVO_SECURE_STORAGE_BACKEND_ANDROID_KEYSTORE UINT32_C(2)
#define KELIVO_SECURE_STORAGE_BACKEND_LINUX_SECRET_SERVICE UINT32_C(3)
#define KELIVO_CAPABILITY_FLAGS_NONE UINT64_C(0)
#define KELIVO_CAPABILITY_KEY_SLOTS (UINT64_C(1) << 0)
#define KELIVO_CAPABILITY_BACKGROUND_ACCESS (UINT64_C(1) << 1)
#define KELIVO_CAPABILITY_RECORD_ENVELOPES (UINT64_C(1) << 2)
#define KELIVO_CAPABILITY_SQLCIPHER_KEY_APPLICATION (UINT64_C(1) << 3)
#define KELIVO_CAPABILITY_SQLCIPHER_DATABASE_ATTACH (UINT64_C(1) << 4)
#define KELIVO_CAPABILITY_OPAQUE_CLIENT (UINT64_C(1) << 5)
#define KELIVO_CAPABILITY_DEVICE_E2EE_CORE (UINT64_C(1) << 6)
#define KELIVO_CAPABILITY_ATTACHMENT_CRYPTO (UINT64_C(1) << 7)
#define KELIVO_CAPABILITY_ACCOUNT_TRUST_SIGNING (UINT64_C(1) << 8)

#define KELIVO_RECORD_ID_SIZE ((size_t)16)
#define KELIVO_RECORD_ENTITY_KEY_MAX_SIZE ((size_t)2048)
#define KELIVO_RECORD_MAX_ASSOCIATED_DATA_SIZE ((size_t)(64 * 1024))
#define KELIVO_RECORD_MAX_PLAINTEXT_SIZE ((size_t)(16 * 1024 * 1024))
#define KELIVO_RECORD_MAX_ENVELOPE_SIZE ((size_t)(KELIVO_RECORD_MAX_PLAINTEXT_SIZE + 80))
#define KELIVO_DATABASE_ID_SIZE ((size_t)16)
#define KELIVO_DATABASE_NAME_MAX_SIZE ((size_t)64)
#define KELIVO_DATABASE_PATH_MAX_SIZE ((size_t)(64 * 1024))
#define KELIVO_OPAQUE_INVALID_STATE_HANDLE UINT64_C(0)
#define KELIVO_OPAQUE_MAX_INPUT_SIZE ((size_t)65535)
#define KELIVO_OPAQUE_ACCOUNT_ID_SIZE ((size_t)16)
#define KELIVO_OPAQUE_REGISTRATION_REQUEST_SIZE ((size_t)48)
#define KELIVO_OPAQUE_REGISTRATION_RESPONSE_SIZE ((size_t)80)
#define KELIVO_OPAQUE_REGISTRATION_UPLOAD_SIZE ((size_t)208)
#define KELIVO_OPAQUE_CREDENTIAL_REQUEST_SIZE ((size_t)112)
#define KELIVO_OPAQUE_CREDENTIAL_RESPONSE_SIZE ((size_t)336)
#define KELIVO_OPAQUE_CREDENTIAL_FINALIZATION_SIZE ((size_t)80)
#define KELIVO_DEVICE_INVALID_HANDLE UINT64_C(0)
#define KELIVO_DEVICE_UUID_SIZE ((size_t)16)
#define KELIVO_DEVICE_PUBLIC_KEY_SIZE ((size_t)32)
#define KELIVO_DEVICE_PUBLIC_KEYS_SIZE ((size_t)64)
#define KELIVO_DEVICE_CHALLENGE_SIZE ((size_t)32)
#define KELIVO_DEVICE_PROOF_SIZE ((size_t)64)
#define KELIVO_ACCOUNT_KEY_ENVELOPE_SIZE ((size_t)336)
#define KELIVO_PAIRING_SECRET_SIZE ((size_t)32)
#define KELIVO_PAIRING_AUTHENTICATOR_SIZE ((size_t)32)
#define KELIVO_PAIRING_PROTOCOL_VERSION UINT32_C(1)
#define KELIVO_PENDING_PAIRING_MATERIAL_SIZE ((size_t)80)
#define KELIVO_REGISTRATION_FINISH_BUNDLE_SIZE ((size_t)400)
#define KELIVO_PAIRING_APPROVAL_BUNDLE_SIZE ((size_t)432)
#define KELIVO_ACCOUNT_ROOT_KEYRING_CAPACITY ((size_t)8)
#define KELIVO_ACCOUNT_TRUST_PUBLIC_KEY_SIZE ((size_t)32)
#define KELIVO_ACCOUNT_TRUST_SIGNATURE_SIZE ((size_t)64)
#define KELIVO_ACCOUNT_TRUST_PAYLOAD_MAX_SIZE ((size_t)(64 * 1024))
#define KELIVO_DEVICE_STATE_BLOB_SIZE ((size_t)448)
#define KELIVO_DEVICE_STATE_BINDING_STRUCT_SIZE UINT32_C(48)
#define KELIVO_DEVICE_STATE_BINDING_FLAG_ACCOUNT (UINT32_C(1) << 0)
#define KELIVO_ATTACHMENT_ID_SIZE ((size_t)16)
#define KELIVO_ATTACHMENT_WRAPPED_KEY_SIZE ((size_t)116)
#define KELIVO_ATTACHMENT_MAX_CHUNK_ENVELOPE_SIZE ((size_t)(4 * 1024 * 1024))
#define KELIVO_ATTACHMENT_CHUNK_ENVELOPE_OVERHEAD ((size_t)120)
#define KELIVO_ATTACHMENT_CHUNK_PLAINTEXT_SIZE \
    ((size_t)(KELIVO_ATTACHMENT_MAX_CHUNK_ENVELOPE_SIZE - \
              KELIVO_ATTACHMENT_CHUNK_ENVELOPE_OVERHEAD))
#define KELIVO_ATTACHMENT_MAX_CHUNK_COUNT UINT32_C(1000)
#define KELIVO_ATTACHMENT_MAX_TOTAL_PLAINTEXT_BYTES UINT64_C(4194184000)

typedef struct KelivoDeviceStateBinding {
    uint32_t struct_size;
    uint32_t flags;
    uint8_t device_id[KELIVO_DEVICE_UUID_SIZE];
    uint32_t key_version;
    uint8_t user_id[KELIVO_DEVICE_UUID_SIZE];
    uint32_t key_epoch;
} KelivoDeviceStateBinding;

typedef int32_t (*KelivoSqlCipherKeyCallback)(
    void *database,
    const void *key,
    int32_t key_length);

typedef int32_t (*KelivoSqlitePrepareCallback)(
    void *database,
    const char *sql,
    int32_t sql_length,
    void **out_statement,
    const char **sql_tail);
typedef void (*KelivoSqliteDestructor)(void *value);
typedef int32_t (*KelivoSqliteBindTextCallback)(
    void *statement,
    int32_t index,
    const char *value,
    int32_t value_length,
    KelivoSqliteDestructor destructor);
typedef int32_t (*KelivoSqliteBindBlobCallback)(
    void *statement,
    int32_t index,
    const void *value,
    int32_t value_length,
    KelivoSqliteDestructor destructor);
typedef int32_t (*KelivoSqliteStepCallback)(void *statement);
typedef int32_t (*KelivoSqliteFinalizeCallback)(void *statement);

/*
 * 固定为 32 字节的 ABI v1 能力结构。reserved 字段必须忽略；
 * 任何扩大结构的变更都必须提升 ABI 并新增函数，禁止改变本结构大小。
 */
typedef struct KelivoCoreCapabilities {
  uint32_t struct_size;
  uint32_t abi_version;
  uint64_t flags;
  uint32_t secure_storage_backend;
  uint32_t reserved[3];
} KelivoCoreCapabilities;

/* 返回当前动态库实现的 ABI 版本，不会访问任何平台密钥设施。 */
KELIVO_CORE_API uint32_t kelivo_core_abi_version(void);

/*
 * 写入当前平台能力。out_capabilities_size 必须至少为 v1 固定结构大小；
 * 缓冲区不足时不写入任何字节；后端和能力必须按当前平台如实返回。
 */
KELIVO_CORE_API KelivoStatus kelivo_core_get_capabilities(
    KelivoCoreCapabilities *out_capabilities,
    size_t out_capabilities_size);

/*
 * slot_id 必须指向恰好 16 字节的稳定槽位标识，policy_version 必须为 v1；
 * 指针必须覆盖声明的可读长度。创建不得覆盖既有槽位。失败时，只要
 * out_handle 可写，其值都会被置为无效句柄零。
 */
KELIVO_CORE_API KelivoStatus kelivo_key_slot_create(
    const uint8_t *slot_id,
    size_t slot_id_length,
    uint32_t policy_version,
    uint64_t *out_handle);

/*
 * 打开已有槽位的参数约束与创建相同。句柄只允许作为不透明值传回本库，
 * 调用方不得从句柄推断或读取任何密钥材料；解包失败不得回退或新建密钥。
 */
KELIVO_CORE_API KelivoStatus kelivo_key_slot_open(
    const uint8_t *slot_id,
    size_t slot_id_length,
    uint32_t policy_version,
    uint64_t *out_handle);

/*
 * 关闭非零不透明句柄。句柄仅在当前进程内有效，关闭后永久失效且数值不得
 * 在同一进程内复用；成功关闭必须先从句柄表移除并清零对应密钥材料。
 */
KELIVO_CORE_API KelivoStatus kelivo_key_handle_close(uint64_t handle);

/*
 * 从句柄主密钥按 database_id 与 epoch 派生独立的 32 字节 SQLCipher 密钥，
 * 并在本库内同步交给 SQLite 原生设键函数。database_id 必须恰好 16 字节，
 * epoch 必须非零。回调不得保存 key 指针；密钥不会通过 ABI 输出给调用方。
 */
KELIVO_CORE_API KelivoStatus kelivo_sqlcipher_key_apply(
    uint64_t handle,
    const uint8_t *database_id,
    size_t database_id_length,
    uint64_t epoch,
    void *database,
    KelivoSqlCipherKeyCallback key_callback);

/*
 * 在本库内派生密钥，并通过同一 SQLite 资产的预编译、绑定、执行回调完成
 * ATTACH。database_path 必须指向既有普通文件，并且是无 NUL 的 UTF-8 路径；
 * database_name 必须是 1 到 64 字节的 ASCII 标识符且不得为 main 或 temp。
 * 密钥只会绑定为 BLOB，不会写入 SQL 文本或通过 ABI 输出给调用方。
 */
KELIVO_CORE_API KelivoStatus kelivo_sqlcipher_database_attach(
    uint64_t handle,
    const uint8_t *database_id,
    size_t database_id_length,
    uint64_t epoch,
    void *database,
    const uint8_t *database_path,
    size_t database_path_length,
    const uint8_t *database_name,
    size_t database_name_length,
    KelivoSqlitePrepareCallback prepare_callback,
    KelivoSqliteBindTextCallback bind_text_callback,
    KelivoSqliteBindBlobCallback bind_blob_callback,
    KelivoSqliteStepCallback step_callback,
    KelivoSqliteFinalizeCallback finalize_callback);

/*
 * 使用句柄中的 epoch 主密钥密封一条记录。record_id 必须恰好 16 字节，
 * epoch 必须非零；算法套件、HKDF 域分离、随机 nonce 与确定性 CBOR 信封
 * 均由本库控制。输出容量不足时只写 required length，不消耗随机数且不写
 * out_envelope。associated_data 与 plaintext 长度为零时允许传入空指针。
 */
KELIVO_CORE_API KelivoStatus kelivo_record_seal(
    uint64_t handle,
    const uint8_t *record_id,
    size_t record_id_length,
    uint64_t epoch,
    const uint8_t *associated_data,
    size_t associated_data_length,
    const uint8_t *plaintext,
    size_t plaintext_length,
    uint8_t *out_envelope,
    size_t out_envelope_capacity,
    size_t *out_envelope_length);

/*
 * 开启 v1 记录信封。调用方必须提供预期 record_id、epoch 与关联数据；
 * 任一不匹配、密文篡改或认证失败均不得写出明文。输出容量查询只解析
 * 有界的规范 CBOR 结构，实际开启时再次完成 AEAD 认证。
 */
KELIVO_CORE_API KelivoStatus kelivo_record_open(
    uint64_t handle,
    const uint8_t *record_id,
    size_t record_id_length,
    uint64_t epoch,
    const uint8_t *associated_data,
    size_t associated_data_length,
    const uint8_t *envelope,
    size_t envelope_length,
    uint8_t *out_plaintext,
    size_t out_plaintext_capacity,
    size_t *out_plaintext_length);

/*
 * 使用不透明账户根密钥句柄密封云同步记录。key_epoch 必须非零且会同时参与
 * 记录密钥派生和信封认证；原始账户根密钥不会通过 ABI 输出。
 */
KELIVO_CORE_API KelivoStatus kelivo_account_record_seal(
    uint64_t ark_handle,
    const uint8_t *record_id,
    size_t record_id_length,
    uint32_t key_epoch,
    const uint8_t *associated_data,
    size_t associated_data_length,
    const uint8_t *plaintext,
    size_t plaintext_length,
    uint8_t *out_envelope,
    size_t out_envelope_capacity,
    size_t *out_envelope_length);

/*
 * 使用不透明账户根密钥句柄开启云同步记录。错误账户根密钥、key_epoch、
 * record_id、关联数据或篡改信封均不得写出明文。
 */
KELIVO_CORE_API KelivoStatus kelivo_account_record_open(
    uint64_t ark_handle,
    const uint8_t *record_id,
    size_t record_id_length,
    uint32_t key_epoch,
    const uint8_t *associated_data,
    size_t associated_data_length,
    const uint8_t *envelope,
    size_t envelope_length,
    uint8_t *out_plaintext,
    size_t out_plaintext_capacity,
    size_t *out_plaintext_length);

/*
 * 原子生成随机 UUIDv4 附件标识和随机附件数据密钥。密钥只以当前进程内的
 * 不透明句柄返回；容量不足时不读取随机源，也不创建句柄。
 */
KELIVO_CORE_API KelivoStatus kelivo_attachment_data_key_generate(
    uint64_t *out_handle,
    uint8_t *out_attachment_id,
    size_t out_attachment_id_capacity,
    size_t *out_attachment_id_length);

/*
 * 幂等关闭附件数据密钥句柄。关闭后所有加密、解密和包装操作必须失败关闭。
 */
KELIVO_CORE_API KelivoStatus kelivo_attachment_data_key_handle_close(
    uint64_t handle);

/*
 * 使用 ARK 包装附件数据密钥。上下文严格绑定 UUIDv4 用户、随机 UUIDv4 附件
 * 标识与正 uint32 key epoch；输出容量查询不消耗随机数。
 */
KELIVO_CORE_API KelivoStatus kelivo_attachment_data_key_wrap(
    uint64_t ark_handle,
    uint64_t data_key_handle,
    const uint8_t *user_id,
    size_t user_id_length,
    const uint8_t *attachment_id,
    size_t attachment_id_length,
    uint32_t key_epoch,
    uint8_t *out_wrapped_key,
    size_t out_wrapped_key_capacity,
    size_t *out_wrapped_key_length);

/*
 * 认证并解包附件数据密钥。任何 ARK 或上下文错配、截断或篡改均不得创建句柄。
 */
KELIVO_CORE_API KelivoStatus kelivo_attachment_data_key_unwrap(
    uint64_t ark_handle,
    const uint8_t *user_id,
    size_t user_id_length,
    const uint8_t *attachment_id,
    size_t attachment_id_length,
    uint32_t key_epoch,
    const uint8_t *wrapped_key,
    size_t wrapped_key_length,
    uint64_t *out_handle);

/*
 * 独立密封规范附件块。上下文绑定账户、附件、epoch、块序号、块总数、总明文
 * 长度和本块明文长度；upload_id 是 create 后返回的 UUIDv4。非末块固定为
 * 4194184 字节，使完整密文不超过服务端 4 MiB 上限；空附件固定为一个零长度块。
 */
KELIVO_CORE_API KelivoStatus kelivo_attachment_chunk_seal(
    uint64_t data_key_handle,
    const uint8_t *user_id,
    size_t user_id_length,
    const uint8_t *attachment_id,
    size_t attachment_id_length,
    const uint8_t *upload_id,
    size_t upload_id_length,
    uint32_t key_epoch,
    uint32_t chunk_index,
    uint32_t chunk_count,
    uint64_t total_plaintext_bytes,
    const uint8_t *plaintext,
    size_t plaintext_length,
    uint8_t *out_envelope,
    size_t out_envelope_capacity,
    size_t *out_envelope_length);

/*
 * 认证并开启单个附件块。调用方必须提供全部预期上下文；错误块、重排、替换、
 * 截断、跨账户、跨 upload 或跨 epoch 均不得写出明文。
 */
KELIVO_CORE_API KelivoStatus kelivo_attachment_chunk_open(
    uint64_t data_key_handle,
    const uint8_t *user_id,
    size_t user_id_length,
    const uint8_t *attachment_id,
    size_t attachment_id_length,
    const uint8_t *upload_id,
    size_t upload_id_length,
    uint32_t key_epoch,
    uint32_t chunk_index,
    uint32_t chunk_count,
    uint64_t total_plaintext_bytes,
    size_t plaintext_length,
    const uint8_t *envelope,
    size_t envelope_length,
    uint8_t *out_plaintext,
    size_t out_plaintext_capacity,
    size_t *out_plaintext_length);

/*
 * 以 password 启动客户端注册。密码只在调用期间由 Rust 读取，不会进入输出消息。
 * 状态仅作为当前进程内的不透明句柄保存；失败时可写的 out_state_handle 与
 * out_request_length 会先归零。输出缓冲区必须至少容纳固定大小的注册请求。
 * 输入字节区、输出字节区以及两个输出标量区必须彼此完全不重叠。
 */
KELIVO_CORE_API KelivoStatus kelivo_opaque_client_registration_start(
    const uint8_t *password,
    size_t password_length,
    uint64_t *out_state_handle,
    uint8_t *out_request,
    size_t out_request_capacity,
    size_t *out_request_length);

/*
 * 以服务端 RegistrationResponse 完成客户端注册并输出 RegistrationUpload。
 * credential_identifier 必须为服务端分配的 RFC 4122 UUIDv4 原始 16 字节。
 * 只要 out_upload_length 可写，有效状态句柄即在本次调用中单次消费；成功、
 * 协议失败或参数失败后均不可复用。密码和客户端秘密状态都不会跨出 Rust。
 * 所有输入字节区、输出字节区与输出长度标量区必须彼此完全不重叠。
 */
KELIVO_CORE_API KelivoStatus kelivo_opaque_client_registration_finish(
    uint64_t state_handle,
    const uint8_t *password,
    size_t password_length,
    const uint8_t *response,
    size_t response_length,
    const uint8_t *credential_identifier,
    size_t credential_identifier_length,
    uint8_t *out_upload,
    size_t out_upload_capacity,
    size_t *out_upload_length);

/*
 * 以 password 启动客户端登录并输出 CredentialRequest。密码不进入请求消息，
 * ClientLoginState 只存在于 Rust 句柄表。输出约束与注册开始相同，各输入、
 * 输出字节区和输出标量区必须彼此完全不重叠。
 */
KELIVO_CORE_API KelivoStatus kelivo_opaque_client_login_start(
    const uint8_t *password,
    size_t password_length,
    uint64_t *out_state_handle,
    uint8_t *out_request,
    size_t out_request_capacity,
    size_t *out_request_length);

/*
 * 以服务端 CredentialResponse 完成客户端认证并输出 CredentialFinalization。
 * credential_identifier 使用与注册相同的 UUIDv4 原始 16 字节。
 * OPAQUE session key 与 export key 会在 Rust 内归零销毁，绝不通过本接口返回，
 * 也不得用于 ARK。有效状态句柄的单次消费规则与注册完成相同；所有输入字节区、
 * 输出字节区与输出长度标量区必须彼此完全不重叠。
 */
KELIVO_CORE_API KelivoStatus kelivo_opaque_client_login_finish(
    uint64_t state_handle,
    const uint8_t *password,
    size_t password_length,
    const uint8_t *response,
    size_t response_length,
    const uint8_t *credential_identifier,
    size_t credential_identifier_length,
    uint8_t *out_finalization,
    size_t out_finalization_capacity,
    size_t *out_finalization_length);

/*
 * 取消尚未完成的客户端注册或登录状态。关闭成功后句柄永久失效且同一进程内
 * 不会复用；本接口不接受服务端登录状态或任何可序列化秘密状态。
 */
KELIVO_CORE_API KelivoStatus kelivo_opaque_client_state_close(
    uint64_t state_handle);

/*
 * 生成设备 Ed25519/X25519 身份。私钥只保存在当前进程的不透明句柄内；
 * 失败时 out_handle 先写零，不提供任何私钥导出函数。
 */
KELIVO_CORE_API KelivoStatus kelivo_device_identity_generate(
    uint64_t *out_handle);

/*
 * 输出固定 64 字节公开材料：Ed25519 公钥在前，X25519 公钥在后。
 */
KELIVO_CORE_API KelivoStatus kelivo_device_identity_public_keys(
    uint64_t identity_handle,
    uint8_t *out_public_keys,
    size_t out_public_keys_capacity,
    size_t *out_public_keys_length);

/*
 * 严格验证外部 Ed25519 公钥：拒绝非规范编码、小阶点和扭转分量。
 */
KELIVO_CORE_API KelivoStatus kelivo_device_signing_public_key_validate(
    const uint8_t *public_key,
    size_t public_key_length);

/*
 * 严格验证外部 X25519 公钥：必须能完成 HPKE 封装且不能产生全零共享值。
 */
KELIVO_CORE_API KelivoStatus kelivo_device_key_agreement_public_key_validate(
    const uint8_t *public_key,
    size_t public_key_length);

KELIVO_CORE_API KelivoStatus kelivo_device_identity_handle_close(
    uint64_t identity_handle);

/*
 * 目标端在 Rust 内生成一次性 pairingId 与 raw secret，并绑定本机设备身份、
 * deviceId、keyVersion 和五分钟单调时钟截止点。固定 80 字节输出顺序为
 * pairingId16 || rawSecret32 || SHA256(rawSecret)32；raw secret 只用于生成二维码。
 */
KELIVO_CORE_API KelivoStatus kelivo_pending_pairing_start(
    uint64_t identity_handle,
    const uint8_t *target_device_id,
    size_t target_device_id_length,
    uint32_t target_key_version,
    uint64_t *out_pending_handle,
    uint8_t *out_material,
    size_t out_material_capacity,
    size_t *out_material_length);

/*
 * 将服务端创建响应绑定到本地 pending 句柄。返回的 pairingId、目标设备、
 * keyVersion 与两把目标公钥必须逐字节匹配本机材料；expiresAt 必须位于
 * (nowMs, nowMs+300000]，同一句柄只允许绑定一次。
 */
KELIVO_CORE_API KelivoStatus kelivo_pending_pairing_bind(
    uint64_t pending_handle,
    uint32_t protocol_version,
    const uint8_t *pairing_id,
    size_t pairing_id_length,
    const uint8_t *user_id,
    size_t user_id_length,
    const uint8_t *target_device_id,
    size_t target_device_id_length,
    uint32_t target_key_version,
    const uint8_t *target_signing_public_key,
    size_t target_signing_public_key_length,
    const uint8_t *target_key_agreement_public_key,
    size_t target_key_agreement_public_key_length,
    uint64_t expires_at_ms,
    const uint8_t *challenge,
    size_t challenge_length,
    uint64_t now_ms);

KELIVO_CORE_API KelivoStatus kelivo_pending_pairing_handle_close(
    uint64_t pending_handle);

/*
 * 为规范 user_id 和正 key_epoch 生成 ARK，并直接注册为仅含该代次的账户绑定
 * 不透明密钥环句柄。不存在未绑定状态或原始字节导出接口；key_epoch=0 必须失败。
 */
KELIVO_CORE_API KelivoStatus kelivo_account_root_key_generate(
    const uint8_t *user_id,
    size_t user_id_length,
    uint32_t key_epoch,
    uint64_t *out_handle);

/*
 * 使用 ARK 对调用方提供的非空规范实体键执行 v1 域分离 keyed PRF，输出固定
 * 16 字节不透明记录 ID，并设置 RFC 4122 UUIDv4/variant 位。实体键最长 2048
 * 字节；原始 ARK 和完整 PRF 输出均不会通过 ABI 暴露。
 */
KELIVO_CORE_API KelivoStatus kelivo_account_record_id_derive(
    uint64_t ark_handle,
    const uint8_t *canonical_entity_key,
    size_t canonical_entity_key_length,
    uint8_t *out_record_id,
    size_t out_record_id_capacity,
    size_t *out_record_id_length);

/*
 * 从指定且必须存在的 ARK 代次派生账户信任根 Ed25519 验证钥。user_id 必须
 * 等于句柄固有账户；HKDF 固定绑定 user_id 与 key_epoch。成功只输出 32 字节
 * 公钥，原始 ARK 与 seed 不跨 ABI。
 */
KELIVO_CORE_API KelivoStatus kelivo_account_trust_public_key_derive(
    uint64_t ark_handle,
    const uint8_t *user_id,
    size_t user_id_length,
    uint32_t key_epoch,
    uint8_t *out_public_key,
    size_t out_public_key_capacity,
    size_t *out_public_key_length);

/*
 * 对 1 至 65536 字节规范载荷签名。user_id 必须等于句柄固有账户；签名
 * transcript 固定绑定协议域、user_id、key_epoch 与载荷长度。成功固定输出
 * 64 字节，任何失败都清零可写输出。
 */
KELIVO_CORE_API KelivoStatus kelivo_account_trust_payload_sign(
    uint64_t ark_handle,
    const uint8_t *user_id,
    size_t user_id_length,
    uint32_t key_epoch,
    const uint8_t *canonical_payload,
    size_t canonical_payload_length,
    uint8_t *out_signature,
    size_t out_signature_capacity,
    size_t *out_signature_length);

/*
 * 使用严格 Ed25519 语义验证规范载荷。public_key 必须由客户端从已认证 ARK
 * 本地派生；服务器随清单返回的裸公钥不得作为信任根。该函数不建立公钥信任。
 */
KELIVO_CORE_API KelivoStatus kelivo_account_trust_payload_verify(
    const uint8_t *public_key,
    size_t public_key_length,
    const uint8_t *user_id,
    size_t user_id_length,
    uint32_t key_epoch,
    const uint8_t *canonical_payload,
    size_t canonical_payload_length,
    const uint8_t *signature,
    size_t signature_length);

KELIVO_CORE_API KelivoStatus kelivo_account_root_key_handle_close(
    uint64_t ark_handle);

/*
 * 将 source 单槽密钥环原子加入同账户 target 并设为当前代次。source 必须
 * 绑定同一 user_id，且仅含一个严格高于 target 当前值的代次；跨账户、重复、
 * 非递增、容量已满或任一句柄无效时，target 保持不变。两个句柄都继续有效，
 * ARK 原始字节不会跨越 ABI。
 */
KELIVO_CORE_API KelivoStatus kelivo_account_root_keyring_add_epoch(
    uint64_t target_ark_handle,
    uint64_t source_ark_handle);

/*
 * 从密钥环原子移除指定旧代次。不得移除当前代次；代次不存在、为零或句柄
 * 无效时密钥环保持不变。
 */
KELIVO_CORE_API KelivoStatus kelivo_account_root_keyring_prune_epoch(
    uint64_t ark_handle,
    uint32_t key_epoch);

/*
 * 签发设备将不透明 ARK 封装给任意目标设备。user_id 必须等于 ARK 句柄
 * 固有账户；签发公钥由 identity_handle 内部取得，调用方只提供目标公钥与
 * 完整可信绑定。成功固定输出 336 字节；其他验证失败将保持长度为零并清零
 * 可写输出，容量不足返回所需长度 336。
 */
KELIVO_CORE_API KelivoStatus kelivo_account_root_key_envelope_seal(
    uint64_t issuer_identity_handle,
    uint64_t ark_handle,
    const uint8_t *user_id,
    size_t user_id_length,
    const uint8_t *issuer_device_id,
    size_t issuer_device_id_length,
    const uint8_t *target_device_id,
    size_t target_device_id_length,
    uint32_t key_epoch,
    const uint8_t *target_signing_public_key,
    size_t target_signing_public_key_length,
    const uint8_t *target_key_agreement_public_key,
    size_t target_key_agreement_public_key_length,
    uint8_t *out_envelope,
    size_t out_envelope_capacity,
    size_t *out_envelope_length);

/*
 * 目标 identity 使用调用方提供的预期账户、设备、epoch 与双方公钥先验证
 * 336 字节信封的签名和完整绑定，再开启为新的不透明 ARK 句柄。目标公钥
 * 必须与 identity_handle 一致；任何失败都将输出句柄保持为零。
 */
KELIVO_CORE_API KelivoStatus kelivo_account_root_key_envelope_open(
    uint64_t target_identity_handle,
    const uint8_t *envelope,
    size_t envelope_length,
    const uint8_t *user_id,
    size_t user_id_length,
    const uint8_t *issuer_device_id,
    size_t issuer_device_id_length,
    const uint8_t *target_device_id,
    size_t target_device_id_length,
    uint32_t key_epoch,
    const uint8_t *issuer_signing_public_key,
    size_t issuer_signing_public_key_length,
    const uint8_t *issuer_key_agreement_public_key,
    size_t issuer_key_agreement_public_key_length,
    const uint8_t *target_signing_public_key,
    size_t target_signing_public_key_length,
    const uint8_t *target_key_agreement_public_key,
    size_t target_key_agreement_public_key_length,
    uint64_t *out_ark_handle);

/*
 * 对严格 80 字节 CredentialFinalization 生成 LoginFinish KDPF 签名。
 * 公钥从 identity_handle 内取得，主载荷摘要由 Rust 内部计算。
 */
KELIVO_CORE_API KelivoStatus kelivo_device_login_proof_sign(
    uint64_t identity_handle,
    const uint8_t *attempt_id,
    size_t attempt_id_length,
    const uint8_t *account_context_id,
    size_t account_context_id_length,
    const uint8_t *device_id,
    size_t device_id_length,
    uint64_t expires_at_ms,
    const uint8_t *challenge,
    size_t challenge_length,
    const uint8_t *credential_finalization,
    size_t credential_finalization_length,
    uint8_t *out_signature,
    size_t out_signature_capacity,
    size_t *out_signature_length);

/*
 * 单次生成注册自 KAEK 与 RegistrationFinish KDPF，禁止 Dart 分别拼装。
 * 固定 400 字节输出顺序为 KAEK336 || signature64。
 */
KELIVO_CORE_API KelivoStatus kelivo_device_registration_finish_create(
    uint64_t identity_handle,
    uint64_t ark_handle,
    const uint8_t *user_id,
    size_t user_id_length,
    const uint8_t *device_id,
    size_t device_id_length,
    uint32_t key_epoch,
    const uint8_t *attempt_id,
    size_t attempt_id_length,
    const uint8_t *account_context_id,
    size_t account_context_id_length,
    uint64_t expires_at_ms,
    const uint8_t *challenge,
    size_t challenge_length,
    const uint8_t *registration_upload,
    size_t registration_upload_length,
    uint8_t *out_bundle,
    size_t out_bundle_capacity,
    size_t *out_bundle_length);

/*
 * 单次完成面向目标设备的 KAEK、PairingApprove KDPF 与 secret 派生认证器。
 * raw pairing secret 必须恰好 32 字节且不会进入输出；固定输出顺序为
 * KAEK336 || signature64 || authenticator32。
 */
KELIVO_CORE_API KelivoStatus kelivo_device_pairing_approval_create(
    uint64_t identity_handle,
    uint64_t ark_handle,
    const uint8_t *pairing_id,
    size_t pairing_id_length,
    const uint8_t *user_id,
    size_t user_id_length,
    const uint8_t *issuer_device_id,
    size_t issuer_device_id_length,
    const uint8_t *target_device_id,
    size_t target_device_id_length,
    uint64_t expires_at_ms,
    const uint8_t *challenge,
    size_t challenge_length,
    uint32_t key_epoch,
    const uint8_t *target_signing_public_key,
    size_t target_signing_public_key_length,
    const uint8_t *target_key_agreement_public_key,
    size_t target_key_agreement_public_key_length,
    const uint8_t *pairing_secret,
    size_t pairing_secret_length,
    uint8_t *out_bundle,
    size_t out_bundle_capacity,
    size_t *out_bundle_length);

/*
 * 目标端深验证入口。pairingId、userId、目标设备、公钥、过期时间、challenge
 * 与 raw secret 均只从 pending_handle 读取；Dart 无法重新提供这些值。函数先
 * 验证墙钟与单调时钟，再验证 authenticator、KDPF、KAEK，最后解封 ARK。
 * 成功会原子消费并清零 pending，同时输出 ARK 句柄和 448 字节完整状态；
 * 认证失败会归还 pending 供重试，输出句柄与长度保持为零。
 */
KELIVO_CORE_API KelivoStatus kelivo_device_pairing_approval_accept(
    uint64_t key_handle,
    uint64_t identity_handle,
    uint64_t pending_handle,
    uint64_t now_ms,
    const uint8_t *issuer_device_id,
    size_t issuer_device_id_length,
    uint32_t key_epoch,
    const uint8_t *issuer_signing_public_key,
    size_t issuer_signing_public_key_length,
    const uint8_t *issuer_key_agreement_public_key,
    size_t issuer_key_agreement_public_key_length,
    const uint8_t *signature,
    size_t signature_length,
    const uint8_t *authenticator,
    size_t authenticator_length,
    const uint8_t *envelope,
    size_t envelope_length,
    uint64_t *out_ark_handle,
    uint8_t *out_state_blob,
    size_t out_state_blob_capacity,
    size_t *out_state_blob_length);

/*
 * 使用平台槽位句柄密封单一设备状态。ark_handle=0 时必须同时使用空 user_id
 * 和 key_epoch=0，得到 identity-only 状态；完整态会一次认证地封装最多八个
 * ARK 代次，且 key_epoch 必须精确等于密钥环当前代次。
 */
KELIVO_CORE_API KelivoStatus kelivo_device_state_seal(
    uint64_t key_handle,
    uint64_t identity_handle,
    uint64_t ark_handle,
    const uint8_t *device_id,
    size_t device_id_length,
    uint32_t key_version,
    const uint8_t *user_id,
    size_t user_id_length,
    uint32_t key_epoch,
    uint8_t *out_blob,
    size_t out_blob_capacity,
    size_t *out_blob_length);

/*
 * 状态绑定与秘密经过同一 AEAD 认证；认证成功前不得发布绑定或任何句柄。
 * identity-only 成功时 binding 不含 ACCOUNT 标志且 out_ark_handle 保持零；
 * 完整态成功时绑定包含账户与 epoch，两个句柄都有效。
 */
KELIVO_CORE_API KelivoStatus kelivo_device_state_open(
    uint64_t key_handle,
    const uint8_t *blob,
    size_t blob_length,
    KelivoDeviceStateBinding *out_binding,
    uint64_t *out_identity_handle,
    uint64_t *out_ark_handle);

#ifdef __cplusplus
}
#endif

#endif
