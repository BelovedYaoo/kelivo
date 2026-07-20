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
#define KELIVO_STATUS_UNSUPPORTED_PLATFORM INT32_C(100)

#define KELIVO_SECURE_STORAGE_BACKEND_NONE UINT32_C(0)
#define KELIVO_CAPABILITY_FLAGS_NONE UINT64_C(0)

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
 * 缓冲区不足时不写入任何字节。本阶段 backend 与 flags 均为零。
 */
KELIVO_CORE_API KelivoStatus kelivo_core_get_capabilities(
    KelivoCoreCapabilities *out_capabilities,
    size_t out_capabilities_size);

/*
 * slot_id 必须指向恰好 16 字节的稳定槽位标识，policy_version 必须为 v1。
 * 失败时，只要 out_handle 可写，其值都会被置为无效句柄零。
 */
KELIVO_CORE_API KelivoStatus kelivo_key_slot_create(
    const uint8_t *slot_id,
    size_t slot_id_length,
    uint32_t policy_version,
    uint64_t *out_handle);

/*
 * 打开已有槽位的参数约束与创建相同。句柄只允许作为不透明值传回本库，
 * 调用方不得从句柄推断或读取任何密钥材料。
 */
KELIVO_CORE_API KelivoStatus kelivo_key_slot_open(
    const uint8_t *slot_id,
    size_t slot_id_length,
    uint32_t policy_version,
    uint64_t *out_handle);

/*
 * 关闭非零不透明句柄。句柄仅在当前进程内有效，关闭后永久失效且数值不得
 * 在同一进程内复用；当前 stub 在参数有效时明确返回“不支持平台”。
 */
KELIVO_CORE_API KelivoStatus kelivo_key_handle_close(uint64_t handle);

#ifdef __cplusplus
}
#endif

#endif
