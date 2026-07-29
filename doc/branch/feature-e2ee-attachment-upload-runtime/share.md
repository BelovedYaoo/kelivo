# 协作记录

## Mini Control Contract

- Primary Setpoint：把持久附件上传协调器接入生产聊天同步周期；消息的结构化附件全部完成 create、manifest、chunk、commit，并在同一 SQLCipher 事务原子回填远端身份后，消息才允许进入 outbox 密文封装与推送。
- Acceptance：正常上传后消息可封装推送；瞬时失败保留草稿并可重试；未完成、终止或目标绑定失效时消息均不进入可租赁 outbox；旧 marker 与明文路径不得恢复。
- Guardrails：不改桌面壳层、服务端、恢复与认证安全协议；不绕过内容门禁；附件远端步骤继续受单周期预算、租约与取消约束。
- Boundary：`lib/core/services/sync/**`、必要的聊天仓储接缝及现有相关测试。
- Risks：同步阶段顺序错误导致先封装后上传；协调器失败语义被调度器误判；附件回填与 outbox 快照之间出现事务竞态。

## 最小场景

- Happy path：含本地结构化附件的消息先完成上传和远端身份回填，再被封装并推送。
- Boundary：无附件消息不消耗附件远端预算；多个待上传附件受单周期预算限制并跨周期继续。
- Failure：瞬时上传失败持久保留并阻止消息封装；永久失败或目标引用失效失败关闭，不回退旧路径或伪造远端身份。
- State transition：上传 `draft -> creating -> manifest -> chunks -> committing -> complete` 期间不可推送，只有 `complete` 原子回填后下个快照才可见。

## 进度

- 已确认 Issue #52 已覆盖本任务，不重复创建。
- 已确认桌面入口复用共享聊天页；生产接线主落点在内容同步运行时，不修改平台 UI。
- 正在核对上传协调器、outbox、聊天适配器与调度器的阶段和错误合同。
