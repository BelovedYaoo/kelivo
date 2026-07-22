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

#define KELIVO_CORE_ABI_VERSION UINT32_C(1)
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
#define KELIVO_STATUS_UNSUPPORTED_PLATFORM INT32_C(100)

#define KELIVO_SECURE_STORAGE_BACKEND_NONE UINT32_C(0)
#define KELIVO_SECURE_STORAGE_BACKEND_WINDOWS_DPAPI UINT32_C(1)
#define KELIVO_SECURE_STORAGE_BACKEND_ANDROID_KEYSTORE UINT32_C(2)
#define KELIVO_SECURE_STORAGE_BACKEND_LINUX_SECRET_SERVICE UINT32_C(3)
#define KELIVO_CAPABILITY_FLAGS_NONE UINT64_C(0)
#define KELIVO_CAPABILITY_KEY_SLOTS (UINT64_C(1) << 0)
#define KELIVO_CAPABILITY_BACKGROUND_ACCESS (UINT64_C(1) << 1)
#define KELIVO_CAPABILITY_RECORD_ENVELOPES (UINT64_C(1) << 2)

#define KELIVO_RECORD_ID_SIZE ((size_t)16)
#define KELIVO_RECORD_MAX_ASSOCIATED_DATA_SIZE ((size_t)(64 * 1024))
#define KELIVO_RECORD_MAX_PLAINTEXT_SIZE ((size_t)(16 * 1024 * 1024))
#define KELIVO_RECORD_MAX_ENVELOPE_SIZE ((size_t)(KELIVO_RECORD_MAX_PLAINTEXT_SIZE + 80))

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

#ifdef __cplusplus
}
#endif

#endif
