# OpenMetadata 定制适配说明（中文版）

> 基于实际应用需求，对 OpenMetadata（OM）做了若干小适配。本文档记录各项适配的目的、默认行为、修改内容与当前状态，便于后续维护与升级对照。

---

## 目录

| # | 适配项 | 状态 | 是否定制 |
|---|--------|------|----------|
| 1 | 静默创建账号（不发欢迎通知） | 已完成 | 本次定制 |
| 2 | 禁止自助注册账号 | 已满足 | 后续不再定制 |
| 3 | 修复 displayName 被覆盖 | 已完成 | 后续不再定制 |
| 4 | lifeCycle 更新不产生 VersionsHistory | 已满足 | 后续不再定制 |
| 5 | DataQuality 失败后查看具体失败数据 | 已满足 | 后续不再定制 |

---

## 1. 静默创建账号（API 创建用户不发欢迎邮件）

- **状态**：已完成（本次 fork 定制）
- **默认行为**：通过 API 创建用户（`POST /api/v1/users`）时，会向用户 email 发送欢迎/邀请邮件。
- **修改为**：API 创建用户时**不发送欢迎/邀请邮件**（静默创建）。自助注册（`POST /api/v1/users/signup`）的邮件通知**保留**。
- **实现位置**（分支 `feat/user-creation-no-notify`）：
  - `openmetadata-service/src/main/java/org/openmetadata/service/resources/teams/UserResource.java` 的 `createUser`
  - 注释掉 `sendInviteMailToUserForBasicAuth(...)` 调用。

---

## 2. 禁止自助注册账号

- **状态**：标准功能已满足，后续不再定制
- **默认行为**：首页允许自助注册账号，无法保证与 eHR 系统完全一致。
- **修改为**：禁止自助注册。
- **实现方式**：通过配置关闭（非代码硬编码开关）。
  - 配置项：`conf/openmetadata.yaml` 中的 `enableSelfSignup`（默认 `true`）
  - 通过环境变量 `AUTHENTICATION_ENABLE_SELF_SIGNUP=false` 关闭自助注册；关闭后注册端点将返回 `SELF_SIGNUP_NOT_ENABLED`。
- **可选演进**：如需进一步与飞书等统一身份认证对接，可考虑使用 custom OIDC 认证方案。

---

## 3. 修复 displayName 被覆盖

- **状态**：标准功能已满足，后续不再定制
- **默认行为**：源系统中的表发生修改后，OM 再次同步时，手工修改的 Table 的 `displayName` 会被覆盖/删除。
- **修改为**：同步时**不更新 Table 的 `displayName`**，保留用户手工维护的名称。
- **实现位置**：
  - `openmetadata-service/src/main/java/org/openmetadata/service/jdbi3/EntityRepository.java` 的 `updateDisplayName()`
  - 当 bot 做重同步、其策略拒绝 `EDIT_DISPLAY_NAME` 且未强制覆盖（`overrideMetadata=false`）时，保留用户自定义的 `displayName` 不被覆盖（`TableRepository` 继承此通用逻辑）。

---

## 4. lifeCycle 更新不产生 VersionsHistory

- **状态**：标准功能已按此完善，后续不再定制
- **默认行为**：数据中台中的表每天会重建数据，即使“内容”不变，OM 也会因 `lifeCycle` 变化对应增加一个版本，导致版本历史被“污染”。
- **修改为**：仅更新 `lifeCycle` 时**不产生 VersionsHistory**（不递增版本号）。
- **实现位置**：
  - `openmetadata-service/src/main/java/org/openmetadata/service/jdbi3/EntityRepository.java` 的 `updateLifeCycle()`
  - 调用 `recordChange(..., updateVersion=false)`，避免因纯 `lifeCycle` 变化而污染实体小版本（对应上游 issue #21326）。

---

## 5. DataQuality 失败后查看具体失败数据

- **状态**：标准功能已满足，后续不再定制（但仅显示 3 条 sample 数据）
- **默认行为**：TestCase 失败后，不论选择 Rows 还是 Count 类型，均只返回数量；官方回复该能力仅 Collate SaaS 支持。
- **修改为**：选择 **Rows** 类型时，失败后可查看具体有哪些数据**未通过测试规则**（返回失败行样本 sample rows）。
- **实现位置**：
  - `openmetadata-service/src/main/java/org/openmetadata/service/jdbi3/TestCaseRepository.java`
  - 失败行样本扩展点 `FAILED_ROWS_SAMPLE_EXTENSION = "testCase.failedRowsSample"`；`addFailedRowsSample(...)` 校验列并写入失败行样本；`getSampleData(...)` 读取结果。

