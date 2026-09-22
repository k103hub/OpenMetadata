# OpenMetadata 定制适配说明（中文版）

> 基于实际应用需求，对 OpenMetadata（OM）做了若干小适配。本文档分两部分：**第一部分：功能定制**（fork 代码改动：目的、默认行为、修改内容与当前状态，便于后续维护与升级对照）与**第二部分：Docker 部署说明**（生产全栈 compose）。

---

## 目录

**第一部分：功能定制**

| # | 适配项 | 状态 | 是否定制 |
|---|--------|------|----------|
| 1 | 静默创建账号（不发欢迎通知） | 已完成 | 本次定制 |
| 2 | 禁止自助注册账号 | 已满足 | 后续不再定制 |
| 3 | 修复 displayName 被覆盖 | 已完成 | 后续不再定制 |
| 4 | lifeCycle 更新不产生 VersionsHistory | 已满足 | 后续不再定制 |
| 5 | DataQuality 失败后查看具体失败数据 | 已满足 | 后续不再定制 |

**第二部分：Docker 部署**

- Docker 部署（`docker/docker-compose-custom`），见文末

---

## 第一部分：功能定制

### 1. 静默创建账号（API 创建用户不发欢迎邮件）

- **状态**：已完成（本次 fork 定制）
- **默认行为**：通过 API 创建用户（`POST /api/v1/users`）时，会向用户 email 发送欢迎/邀请邮件。
- **修改为**：API 创建用户时**不发送欢迎/邀请邮件**（静默创建）。自助注册（`POST /api/v1/users/signup`）的邮件通知**保留**。
- **实现位置**（分支 `feat/user-creation-no-notify`）：
  - `openmetadata-service/src/main/java/org/openmetadata/service/resources/teams/UserResource.java` 的 `createUser`
  - 注释掉 `sendInviteMailToUserForBasicAuth(...)` 调用。

---

### 2. 禁止自助注册账号

- **状态**：标准功能已满足，后续不再定制
- **默认行为**：首页允许自助注册账号，无法保证与 eHR 系统完全一致。
- **修改为**：禁止自助注册。
- **实现方式**：通过配置关闭（非代码硬编码开关）。
  - 配置项：`conf/openmetadata.yaml` 中的 `enableSelfSignup`（默认 `true`）
  - 通过环境变量 `AUTHENTICATION_ENABLE_SELF_SIGNUP=false` 关闭自助注册；关闭后注册端点将返回 `SELF_SIGNUP_NOT_ENABLED`。
- **可选演进**：如需进一步与飞书等统一身份认证对接，可考虑使用 custom OIDC 认证方案。

---

### 3. 修复 displayName 被覆盖

- **状态**：标准功能已满足，后续不再定制
- **默认行为**：源系统中的表发生修改后，OM 再次同步时，手工修改的 Table 的 `displayName` 会被覆盖/删除。
- **修改为**：同步时**不更新 Table 的 `displayName`**，保留用户手工维护的名称。
- **实现位置**：
  - `openmetadata-service/src/main/java/org/openmetadata/service/jdbi3/EntityRepository.java` 的 `updateDisplayName()`
  - 当 bot 做重同步、其策略拒绝 `EDIT_DISPLAY_NAME` 且未强制覆盖（`overrideMetadata=false`）时，保留用户自定义的 `displayName` 不被覆盖（`TableRepository` 继承此通用逻辑）。

---

### 4. lifeCycle 更新不产生 VersionsHistory

- **状态**：标准功能已按此完善，后续不再定制
- **默认行为**：数据中台中的表每天会重建数据，即使“内容”不变，OM 也会因 `lifeCycle` 变化对应增加一个版本，导致版本历史被“污染”。
- **修改为**：仅更新 `lifeCycle` 时**不产生 VersionsHistory**（不递增版本号）。
- **实现位置**：
  - `openmetadata-service/src/main/java/org/openmetadata/service/jdbi3/EntityRepository.java` 的 `updateLifeCycle()`
  - 调用 `recordChange(..., updateVersion=false)`，避免因纯 `lifeCycle` 变化而污染实体小版本（对应上游 issue #21326）。

---

### 5. DataQuality 失败后查看具体失败数据

- **状态**：标准功能已满足，后续不再定制（但仅显示 3 条 sample 数据）
- **默认行为**：TestCase 失败后，不论选择 Rows 还是 Count 类型，均只返回数量；官方回复该能力仅 Collate SaaS 支持。
- **修改为**：选择 **Rows** 类型时，失败后可查看具体有哪些数据**未通过测试规则**（返回失败行样本 sample rows）。
- **实现位置**：
  - `openmetadata-service/src/main/java/org/openmetadata/service/jdbi3/TestCaseRepository.java`
  - 失败行样本扩展点 `FAILED_ROWS_SAMPLE_EXTENSION = "testCase.failedRowsSample"`；`addFailedRowsSample(...)` 校验列并写入失败行样本；`getSampleData(...)` 读取结果。

---

## 第二部分：Docker 部署（docker/docker-compose-custom）

生产全栈部署 compose，**基于仓库 quickstart 模板**（`docker/docker-compose-quickstart/docker-compose.yml`）按《02-Casdoor与OpenMetadata认证集成.md》方式 A（custom-oidc + 授权码流）配置。

### 目录结构

```
docker/docker-compose-custom/
├── docker-compose.yml      # git 跟踪：完整生产 compose（密钥已剥离为 ${VAR} 引用）
├── Dockerfile              # 本地构建含定制代码的 server 镜像（FROM 用 gcr.nju.edu.cn 国内源）
├── .env                    # git 忽略：真实密钥/部署值（OIDC 凭据、管理员邮箱、Casdoor 地址）
├── .env.example            # git 跟踪：.env 模板（占位符）
├── up.sh                   # git 跟踪：统一启动入口
└── docker-volume/          # git 忽略：MySQL 数据目录（db-data，up 时自动创建）
```

服务：`mysql`、`elasticsearch`、`execute-migrate-all`、`openmetadata-server`、`ingestion`；镜像默认 `2.0.0` 发行版（可用 `OPENMETADATA_SERVER_IMAGE` / `OPENMETADATA_DB_IMAGE` / `OPENMETADATA_INGESTION_IMAGE` 覆盖）。

### 使用

在仓库根目录执行（`up.sh` 会自动切换到其所在目录并加载 `.env`）：

```bash
cd ~/OpenMetadata
./docker/docker-compose-custom/up.sh config   # 校验渲染结果（不启动）
./docker/docker-compose-custom/up.sh up -d    # 启动
./docker/docker-compose-custom/up.sh ps       # 查看状态
./docker/docker-compose-custom/up.sh down     # 停止
```

等价于 `docker compose -f docker-compose.yml --env-file .env up -d`（在 `docker/docker-compose-custom/` 目录下执行）。

### 密钥卫生

- `docker-compose.yml` 中 OIDC 凭据、管理员邮箱均为 `${VAR}` 引用，**不落盘明文**；`OIDC_CLIENT_SECRET` 用 `${OIDC_CLIENT_SECRET:?}`，缺失即启动报错
- 真实值放 `.env`（全局 `.gitignore` + 本目录 `.gitignore` 双重忽略）
- 变更密钥：改 `.env` → `./up.sh up -d`

### 关键配置速查（对应《02-Casdoor与OpenMetadata认证集成.md》）

> 下表标注「.env 可覆盖」的变量同时写入 `.env`（`.env.example` 有占位符模板）；**换域名/IP 只改 `.env`**，compose 内的 `${VAR:-默认}` 为兜底默认值。

| 项 | 变量 | 默认/取值 |
|---|---|---|
| 认证方式 | `AUTHENTICATION_PROVIDER` | `custom-oidc` |
| 授权码流 | `AUTHENTICATION_CLIENT_TYPE` / `AUTHENTICATION_RESPONSE_TYPE` | `confidential` / `code` |
| 回调地址（.env 可覆盖） | `AUTHENTICATION_CALLBACK_URL` / `OIDC_CALLBACK` | `http://127.0.0.1:8585/callback` |
| Casdoor 基础地址（.env 可覆盖） | `AUTHENTICATION_AUTHORITY` / `OIDC_SERVER_URL` | `https://casdoor.<your-domain>` |
| Discovery（.env 可覆盖） | `OIDC_DISCOVERY_URI` | `https://casdoor.<your-domain>/.well-known/openid-configuration` |
| JWKS（.env 可覆盖） | `AUTHENTICATION_PUBLIC_KEYS` | `["http://127.0.0.1:8585/api/v1/system/config/jwks"]` |
| 管理员 | `AUTHORIZER_ADMIN_EMAILS` | `.env` 填写（默认 `[]`） |
| 自助开户 | `AUTHENTICATION_ENABLE_SELF_SIGNUP` | `true` |
| 显示名 claim（DB/UI 专属） | `displayNameClaim` | `displayName` |
| 邮箱 claim / email-first 流（DB/UI 专属） | `emailClaim` | `email` |
| 域名白名单 | `AUTHORIZER_ALLOWED_REGISTRATION_DOMAIN` | 当前 `["all"]`；生产建议收窄为公司域 |

> ⚠️ 服务端会把认证配置持久化到数据库（`openmetadata_settings`，configType=`authenticationConfiguration`），**优先于环境变量**；改 `.env` 不生效时，在 UI「设置 → SSO 配置」同步修改或清理该表记录。
>
> `emailClaim` / `displayNameClaim` 两个字段**无对应 `.env` 变量**，仅存在于 DB 或 UI「设置 → SSO 配置」。当 IdP 的 id_token 中 `name` claim 为**账号名**、`displayName` claim 为**显示名**时（如 Casdoor 默认 TokenFormat=JWT），应配置 `displayNameClaim=displayName` 并配套设置 `emailClaim=email`（开启 email-first 流）；否则 OM 按 `name` 优先的提取顺序，会把用户显示名同步成账号名。

