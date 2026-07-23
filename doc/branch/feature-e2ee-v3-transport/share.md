# feature/e2ee-v3-transport 协作记录

## 完成摘要

- 客户端 transport 已硬切到 v3 opaque record：仅保留 record push、change pull、snapshot pull 与账号/设备控制面，内容同步仍由 `contentSyncEnabled=false` 关闭。
- OpenAPI 唯一来源为 `D:\Projects\Private\kelivo-api\openapi\generated\openapi.json`，源文件 SHA-256 为 `E447B6D24629E4F2DE7F176F3C8F19620C3DB8869574CDC8F2C4278DD1E97C90`。
- 已物理删除旧 Hive store、coordinator、conflict resolver/presentation、mutation planner、write journal、配置/聊天明文 adapter、附件同步及专属测试；仅保留本地实体键、仅本地写执行器和旧明文状态退休逻辑。
- 设置页只展示账号、设备和内容仅本地提示；Provider 的旧同步/冲突兼容接口及四份 ARB 的废弃文案已删除。
- v3 协议的 `conflict` 仅表示 record push 的 revision 冲突结果，不是旧冲突资源或冲突 UI。

## 验证摘要

- 生成包 `dart analyze`：通过。
- 根项目 `flutter analyze`：通过。
- 定向测试：167 通过，1 项因 Windows 符号链接权限跳过。
- 串行全量：1433 通过、19 跳过、1 个无关时序测试失败；独立复现为 499.345ms 小于 500ms，已登记 Issue #29，本分支不修改。

## 后续边界

- 当前 `ciphertext` DTO 仍为普通 `String`；后续同步引擎接线时必须只接受安全核心产出的密文类型。
