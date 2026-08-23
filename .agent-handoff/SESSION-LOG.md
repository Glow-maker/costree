# 会话记录

## 一次会话
- 开始时间：2026-07-28 18:30:00 +0800
- 结束时间：2026-07-28 21:40:00 +0800
- 本次焦点：项目办单位金额维护、工作令查询、单位树层级和 20260728 内网部署包收尾

### 本次进展
- 完成 /cost/collect 项目办全宽项目列表和单位金额维护弹窗。
- 完成合同、到款只读以及目标、审定逐单位事务保存接口。
- 完成工作令记录左侧、填报表单右侧和按主业项目过滤。
- 新增 /cost/work-order-list 只读服务端分页查询页及门户入口。
- 成本树新增 HEAD_OFFICE，院部直属型号，总体所映射调整为八部和509所。
- cost_project_basic 增加 quantity、product_short_name、vertical_division 并同步前后端类型。
- MySQL、PostgreSQL、PostgreSQL 9.2/GaussDB 完整 DDL 和 20260728 增量脚本已补齐。
- 正式数据同步改为只更新预分预控合同和到款，保留目标、账面和审定。
- 后端 Reactor compile 和 CostMapperAnnotationSqlTest 通过，1 个测试 0 失败。
- 前端 pnpm run ts:check:cost 和定向 ESLint 通过。
- GaussDB(DWS) 8.2.1 静态兼容检查通过，共检查 15 个 SQL 文件。
- 前端 c6b81fe 和后端 114b6202 已推送对应 Codeup 分支。

### 涉及文件
- costree-frontend/src/views/cost/collect/index.vue
- costree-frontend/src/views/cost/workOrderList/index.vue
- costree-frontend/src/views/cost/treeDetail/index.vue
- costree-frontend/src/router/modules/remaining.ts
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/projectbasic/CostProjectBasicServiceImpl.java
- baback/sql/postgresql/costree-deploy/11-upgrade-existing-to-20260728-project-office-form.sql
- baback/sql/postgresql92/costree-deploy/11-upgrade-existing-to-20260728-project-office-form.sql
- baback/sql/postgresql/costree-integration/10-sync-to-cost.sql
- baback/sql/postgresql92/costree-integration/10-sync-to-cost.sql
- deploy/cost-server-offline-template
- tools/build-cost-server-offline-package.ps1

### 下次恢复点
- 继续项目时先运行 python .agent-handoff/runtime/agent-handoff/scripts/handoff.py resume .；内网部署使用前端 c6b81fe、后端 114b6202，并按离线包 docs/02-数据库建库与升级.md 依次执行 00、10、11、20。正式同步只导入合同和到款，单位目标和审定由项目办在 /cost/collect 维护。

### 风险与备注
- 未执行 20260728 数据库升级时，新后端会因缺列无法正常查询项目基本情况。
- 内网单位名称和项目编码必须与预分预控、单位字典、工作令及账面明细保持一致，否则单位卡片和金额无法正确关联。
- 账面只统计借方明细，真实数据导入后必须按工作令、年度和八项科目抽样对账。
- GaussDB(DWS) 仅完成静态兼容验证，现场执行前必须备份且不得跳过 00-precheck 和 20-verify。
- 使用 application-jt/local 启动时必须配置 COST_DATASOURCE_* 环境变量。

## 一次会话
- 开始时间：2026-08-17 09:00:00 +0800
- 结束时间：2026-08-17 15:00:00 +0800
- 本次焦点：成本树三级数据权限、达梦与成本库双库初始化、PostgreSQL 9.2/GaussDB 全量快照幂等同步及新对话交接

### 本次进展
- 后端 feature/costree 与前端 costree 已同步最新 codeup/master，当前 HEAD 分别为 e2219d0c 和 8ca1b07。
- 三级成本角色、项目授权、管理单位授权、后端数据范围过滤、前端落地页和成本数据授权页已进入未提交工作区。
- 补齐达梦 MQB 的 costree-access-role-menu-20260817.sql 和 check-cost-permissions-20260817.sql，并确认平台实际表名为 SYSTEM_USERS、SYSTEM_ROLE、SYSTEM_MENU、SYSTEM_USER_ROLE、SYSTEM_ROLE_MENU。
- 补齐 MySQL、PostgreSQL、PostgreSQL 9.2/GaussDB 的成本授权表完整 DDL、旧库 12 升级脚本、部署校验和说明。
- 新增 note/80-deployment/03-成本树三级权限与双库初始化.md，说明系统页面分配角色、成本授权页分配项目/管理单位以及双库边界。
- 新增 PostgreSQL 9.2/GaussDB snapshot-upsert 数据集成目录，覆盖六类源数据的全量中间表、校验、幂等同步、借方账面重算和差异清单。
- 新增 note/30-data/11-外部源全量快照中间表幂等同步.md，并更新数据文档索引、变更日志、部署模板入口和包校验器。
- 将 snapshot-upsert 镜像到忽略 Git 的 cost-intranet-data-kit/release-20260729-data-integration，更新 README、RELEASE-INFO、SHA-256 清单并通过包校验。
- 遵循用户要求，本轮未重复构建前端、未构建完整离线包、未提交和未推送。

### 涉及文件
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/accessscope
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/controller/admin/accessscope
- baback/sql/dm/costree-access-role-menu-20260817.sql
- baback/sql/dm/check-cost-permissions-20260817.sql
- baback/sql/postgresql92/costree-deploy/12-upgrade-existing-to-20260817-access-scope.sql
- costree-frontend/src/store/modules/costAccess.ts
- costree-frontend/src/views/cost/accessScope
- costree-frontend/src/permission.ts
- deploy/cost-server-offline-template/database/postgresql92/03-data-integration/snapshot-upsert
- deploy/cost-server-offline-template/database/platform
- note/30-data/11-外部源全量快照中间表幂等同步.md
- note/80-deployment/03-成本树三级权限与双库初始化.md
- cost-intranet-data-kit/release-20260729-data-integration

### 下次恢复点
- 新对话先运行 python .agent-handoff/runtime/agent-handoff/scripts/handoff.py resume .，再分别检查 root、../sqlbot_with_bcback/baback、../sqlbot_with_bcback/costree-frontend 的 git status。不要重置未提交的三级权限、双库 SQL、部署模板和 snapshot-upsert 改动。先完成三级权限静态/运行验证与真实三账号验收，再适配 snapshot-upsert/03 的内网源字段并在备份的 GaussDB 试点执行；用户确认全部改动后才提交推送并一次性构建完整内网包。

### 风险与备注
- 当前三个仓库均有未提交修改，后续操作不得 reset、checkout 或覆盖用户工作；应先逐仓库检查 diff 后继续。
- 权限验收必须使用真实中台登录态和三类测试账号，前端菜单隐藏不能替代后端数据过滤证明。
- 达梦平台脚本和 PostgreSQL/GaussDB 成本业务脚本必须连接各自数据库执行，混用会直接失败或污染错误库。
- snapshot-upsert 目前是标准映射模板，不是已经适配现场源表的最终 SELECT；上线前必须替换占位 schema 并抽样对账。
- 单位展示和权限依赖核算单位名称到 manage_unit_code 的字典映射；名称不一致、字典停用或缺失时必须失败关闭并进入差异清单。
- 账面明细保留借贷双方，但工作令账面、预警和八项组成只统计借方；amount 为元、amount_wan 为万元。

## 一次会话
- 开始时间：2026-08-17 15:04:48 +0800
- 结束时间：2026-08-17 15:52:00 +0800
- 本次焦点：恢复交接后完成成本树三级权限的静态安全审查、P1 修复、聚焦验证和部署校验加固

### 本次进展
- 按 agent-handoff 恢复 TASK-005，读取三个仓库状态并保持现有未提交改动。
- 完成后端、前端、SQL/部署三路并行只读审查，收敛高风险权限与部署缺口。
- 后端 CostAccessScopeService 强制管理后台用户类型，授权保存改为带租户条件的物理替换；项目基本情况和工作令保存接口补齐草稿状态机。
- 新增 CostPermissionGuardTest，连同 CostMapperAnnotationSqlTest 共 4 项测试通过，Maven Reactor 构建成功。
- 前端补齐工作令状态只读、授权选择请求序号、profile 跨账号缓存失效、默认角色落地、成本后台菜单裁剪和遗漏 costCapability 时默认拒绝。
- 扩展 tsconfig.cost.json 覆盖核心权限守卫和 store；pnpm run ts:check:cost 与七个触达文件的定向 ESLint 通过。
- MySQL、PostgreSQL、PostgreSQL 9.2/GaussDB、DM 四套角色脚本统一 data_scope=5，并更新 DM 与 PG 平台检查口径。
- 修复 PostgreSQL 9.2/GaussDB 独立数据库子包 new-database/upgrade-existing/data-integration 布局识别；源码布局与模拟独立子包布局的 DWS 静态检查通过。
- root PowerShell/Shell 验包器补齐平台检查文件、权限清单、manual 和 snapshot-upsert 必需文件；相关 PowerShell/Bash 语法解析通过。
- 更新权限双库操作文档和变更日志，明确通用 data_scope 边界、达梦关闭自动提交及 PowerShell 7 要求。
- 遵循既定边界，本轮未提交、未推送、未构建正式离线包，也未把静态验证表述为真实现场验收。

### 涉及文件
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/accessscope/CostAccessScopeServiceImpl.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/dal/mysql/accessscope
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/projectbasic/CostProjectBasicServiceImpl.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/workorder/CostWorkOrderServiceImpl.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/test/java/cn/iocoder/yudao/module/cost/dal/mysql/CostPermissionGuardTest.java
- baback/sql/mysql|postgresql|postgresql92|dm/costree-access-role-menu-20260817.sql
- baback/sql/postgresql92/costree-deploy/run-new-database.*
- baback/sql/postgresql92/costree-deploy/verify-dws82-compatibility.*
- costree-frontend/src/permission.ts
- costree-frontend/src/store/modules/costAccess.ts
- costree-frontend/src/store/modules/permission.ts
- costree-frontend/src/store/modules/user.ts
- costree-frontend/src/views/cost/accessScope/index.vue
- costree-frontend/src/views/cost/collect/index.vue
- costree-frontend/src/views/cost/workOrderList/index.vue
- costree-frontend/tsconfig.cost.json
- costree-frontend/types/cost-*-shim.d.ts
- deploy/cost-server-offline-template/database/platform/check-cost-permissions.sql
- deploy/cost-server-offline-template/tools/verify-package.ps1
- deploy/cost-server-offline-template/tools/verify-package.sh
- deploy/cost-server-offline-template/docs/02-数据库建库与升级.md
- deploy/cost-server-offline-template/docs/06-网关菜单权限.md
- deploy/cost-server-offline-template/docs/11-三级权限升级与授权操作.md
- note/80-deployment/03-成本树三级权限与双库初始化.md
- note/90-logs/02-变更日志.md

### 下次恢复点
- 下次先运行 D:\Anaconda\python.exe .agent-handoff/runtime/agent-handoff/scripts/handoff.py resume .，再检查 root、../sqlbot_with_bcback/baback、../sqlbot_with_bcback/costree-frontend 的 git status 和本轮聚焦 diff。不要重置未提交变更。TASK-005 优先进入真实四账号验收：默认落地、菜单、直接 URL、项目/单位范围、详情/导出、草稿/驳回可编辑、已提交/已审批只读，并补测 MEMBER/ADMIN 同号。TASK-006 随后在备份环境关闭 DM 自动提交执行平台脚本，在 PG92/GaussDB 执行 12 与 20-verify 并核对索引定义。未完成这些现场验证前不要构建正式包或宣称权限验收完成。

### 风险与备注
- 真实登录验收仍缺失；必须用四类账号和直接 URL/API 参数验证，不能以按钮隐藏和 vue-tsc 代替。
- 真实数据库执行仍缺失；DM 自动提交、PG92/GaussDB 方言与旧库索引现状只能在备份环境确认。
- 平台通用认证过滤器和权限缓存未按 userType 全面隔离；成本入口已 fail-closed，但平台层仍需专项回归。
- CostAccessScope 的历史失效 project_code 清理及部分 Mapper 空集合 fail-open 合约尚未统一加固，当前服务调用路径已有前置空结果保护。
- 候选包 source-state patch 不包含未跟踪文件内容；正式干净包不受影响，但当前 dirty 候选包不能仅凭 patch 完整重现。
- 三个仓库含大量本轮前已有未提交文件，后续审查和提交必须按路径精确分组，禁止整体清理。

## 一次会话
- 开始时间：2026-08-17 23:39:00 +0800
- 结束时间：2026-08-18 02:32:00 +0800
- 本次焦点：修复三级成本权限启动与路由问题，完善项目和管理单位交集授权，完成跨模块提交前审查、聚焦验证和发布准备

### 本次进展
- 恢复并复核三级权限交接状态，检查 root、baback、costree-frontend 三个仓库的完整 dirty 与 untracked 范围。
- 修复 CostAccessScopeServiceImpl 上误加的 method-level Resource，避免 Bean 创建时因无参资源注入方法导致启动失败；新增 RpcConfiguration 显式启用 AdminUserApi Feign 客户端。
- 修复四套平台角色 SQL 顶级菜单 path 缺少前导斜杠的问题，并同步平台检查器，消除业务中台登录时 Vue Router 动态路由异常。
- tenant_admin 归一化为完整成本管理员；授权菜单按 canManageAccess 对管理员可见，普通三类成本角色仍无法直接访问授权页。
- cost_unit_user 改为同时保存项目和管理单位范围，后端按项目与单位交集过滤；授权页新增领域、项目编号与名称筛选，并处理远程请求乱序。
- 加固用户类型、角色冲突、授权物理替换、工作令状态机和失效授权修复路径；补齐研制单位创建工作令权限。
- 非成本角色首次登录不再请求成本 profile，避免其他中台模块依赖 cost-server；成本角色默认落地保持 global viewer 到看板、project office 到项目树。
- 后端 Maven 聚焦测试共 10 项通过，前端 vue-tsc 成本配置和变更文件 ESLint 通过，三个仓库 diff check 通过。
- 加固 PG/PG92 scope 索引定义验收、PG92/GaussDB 独立子包布局和 root 验包清单；DWS 27 个 SQL 静态兼容检查通过。
- snapshot-upsert 增加 LoadSql 空值、文件缺失和模板占位符前置拒绝，状态改为 BUSINESS_SYNCED 到 RECALCULATED 再由最终验收设置 SUCCESS；文档明确跨文件非原子边界。
- 已形成后端提交 fbfc3e3404b8 和前端提交 bfd196e4282c；root 部署与交接内容将在本轮一并提交并按用户授权推送。

### 涉及文件
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/accessscope/CostAccessScopeServiceImpl.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/framework/rpc/config/RpcConfiguration.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/test/java/cn/iocoder/yudao/module/cost/dal/mysql/CostPermissionGuardTest.java
- baback/sql/mysql|postgresql|postgresql92|dm/costree-access-role-menu-20260817.sql
- baback/sql/postgresql|postgresql92/costree-deploy/12-upgrade-existing-to-20260817-access-scope.sql
- baback/sql/postgresql|postgresql92/costree-deploy/20-verify.sql
- costree-frontend/src/permission.ts
- costree-frontend/src/router/modules/remaining.ts
- costree-frontend/src/store/modules/costAccess.ts
- costree-frontend/src/store/modules/permission.ts
- costree-frontend/src/views/cost/accessScope/index.vue
- costree-frontend/src/views/cost/collect/index.vue
- costree-frontend/src/views/cost/workOrderList/index.vue
- deploy/cost-server-offline-template/database/platform/check-cost-permissions.sql
- deploy/cost-server-offline-template/database/postgresql92
- deploy/cost-server-offline-template/docs/06-网关菜单权限.md
- deploy/cost-server-offline-template/docs/11-三级权限升级与授权操作.md
- deploy/cost-server-offline-template/tools/verify-package.ps1
- deploy/cost-server-offline-template/tools/verify-package.sh
- note/30-data/11-外部源全量快照中间表幂等同步.md
- note/80-deployment/03-成本树三级权限与双库初始化.md
- tools/build-cost-server-offline-package.ps1

### 下次恢复点
- 下次先运行 D:\Anaconda\python.exe .agent-handoff/runtime/agent-handoff/scripts/handoff.py resume .，再确认 root master、baback feature/costree、costree-frontend costree 对应远端分支状态。TASK-005 优先使用 tenant_admin、cost_global_viewer、cost_project_office、cost_unit_user 四类真实账号验收；unit user 至少覆盖 P1+U1 允许、P1+U2 拒绝、P2+U1 拒绝，以及列表、详情、导出和工作令状态机。TASK-006 随后在备份环境执行 DM、PG92 和 GaussDB/DWS 脚本并核对索引定义。完成真实验收前不要宣称现场通过或构建正式离线包。

### 风险与备注
- 真实 ApplicationContext 启动、AdminUserApi Feign 调用与业务中台四账号登录尚未执行，当前结论仅覆盖静态、编译、单元和脚本检查。
- 真实 DM、PG92 与 GaussDB/DWS 脚本执行和回滚路径尚未验证，不能把静态兼容检查表述为现场数据库验收。
- DWS scope 普通索引不能在并发下提供数据库唯一约束，需通过执行流程串行化和重复数据检查控制，后续仍应现场压测。
- 单位事实表仍按单位名称过滤，同名、改名和一个管理单位映射多个核算单位的场景需要真实数据验收。
- 工作令状态读取与更新不是单 SQL 条件写，极端并发状态迁移仍存在读后写竞态，后续可用条件 UPDATE 或乐观锁进一步收口。
- 正式离线包尚未构建；候选 dirty 包的 source-state patch 不包含 untracked 文件内容，只有干净提交后的正式包可完整复现。

## 一次会话
- 开始时间：2026-08-18 02:32:00 +0800
- 结束时间：2026-08-18 02:49:00 +0800
- 本次焦点：修复达梦中台权限初始化的旧路由兼容与误删风险，并把中台权限 SQL、验收和说明加入指定数据集成发布目录

### 本次进展
- 按 agent-handoff 恢复最新权限与发布状态，确认数据集成发布目录被 .gitignore 忽略。
- 核对控制器、四方言脚本和 DM checker，确认 18 个权限点与 22 个角色映射齐全，tenant_admin 无需新增映射。
- 在 DM 初始化脚本中增加旧 cost-access-permissions 顶级路由的子权限迁移、旧角色映射清理和逻辑删除。
- 把 DM 角色映射清理从 PERMISSION LIKE cost:% 收窄为 18 个精确受管权限，避免误删目录外现场自定义成本权限。
- 扩展 DM checker，检查正确与旧路径数量、角色去重、权限点重复、缺失映射、多余受管映射和同用户多成本角色冲突。
- 在指定 release-20260729-data-integration 下新增 platform/README.md 与 platform/dm8 两个 SQL，并更新总入口和 RELEASE-INFO。
- 发现发布包 snapshot 内容落后于 root 受控模板，就地同步 00、06、07、09、10 和外部源快照设计说明，保留用户指定目录名。
- 扩展包校验器，要求两个 DM SQL 和说明存在，并断言三个角色、18 权限、正确/旧路由处理、DATA_SCOPE=5、禁止宽泛 cost:% 删除及禁止写 SYSTEM_USER_ROLE。
- 重新生成相关 SHA256 条目并执行包校验：manual 9、snapshot 8、DM8 2、应用二进制 0、前端资源 0；44 个文件与 manifest 一一对应。
- 逐字节核对发布包 DM SQL 与 baback 源文件一致，snapshot 全目录与 root 受控模板一致；两个仓库 diff check 通过。

### 涉及文件
- baback/sql/dm/costree-access-role-menu-20260817.sql
- baback/sql/dm/check-cost-permissions-20260817.sql
- cost-intranet-data-kit/release-20260729-data-integration/00-开始这里.md
- cost-intranet-data-kit/release-20260729-data-integration/RELEASE-INFO.txt
- cost-intranet-data-kit/release-20260729-data-integration/SHA256SUMS.txt
- cost-intranet-data-kit/release-20260729-data-integration/platform/README.md
- cost-intranet-data-kit/release-20260729-data-integration/platform/dm8/costree-access-role-menu-20260817.sql
- cost-intranet-data-kit/release-20260729-data-integration/platform/dm8/check-cost-permissions-20260817.sql
- cost-intranet-data-kit/release-20260729-data-integration/postgresql92/snapshot-upsert/00-开始这里.md
- cost-intranet-data-kit/release-20260729-data-integration/postgresql92/snapshot-upsert/06-重算工作令账面.sql
- cost-intranet-data-kit/release-20260729-data-integration/postgresql92/snapshot-upsert/07-同步后验收.sql
- cost-intranet-data-kit/release-20260729-data-integration/postgresql92/snapshot-upsert/09-定时任务最简顺序.md
- cost-intranet-data-kit/release-20260729-data-integration/postgresql92/snapshot-upsert/10-最简过程.ps1
- cost-intranet-data-kit/release-20260729-data-integration/docs/11-外部源全量快照中间表幂等同步.md
- cost-intranet-data-kit/release-20260729-data-integration/tools/verify-package.ps1

### 下次恢复点
- 下次先运行 D:\Anaconda\python.exe .agent-handoff/runtime/agent-handoff/scripts/handoff.py resume .。重点检查 baback 两个未提交 DM SQL，以及 ignored 的 cost-intranet-data-kit/release-20260729-data-integration/platform 与 SHA256SUMS。真实执行时先备份 MQB 五张平台表、替换租户 124、关闭自动提交并串行运行初始化，再执行 checker，前六组 STATUS 必须全为 OK；随后做四账号登录验收。没有真实 DM 结果前不要宣称现场通过。

### 风险与备注
- 未连接真实 DM8，当前无法证明 UPDATE 同表子查询、客户端自动提交关闭和异常后整体回滚在现场工具中符合预期。
- 初始化脚本会重建三个成本角色在隐藏权限目录、目录子菜单及 18 个受管权限点上的映射；现场人工定制必须在执行前导出对比。
- DM 表缺少本脚本可依赖的唯一约束或显式锁语法证明，并发运行可能创建重复路由或权限点；文档要求串行执行，checker 会发现重复但不会自动修复。
- ignored 发布目录无法依靠普通 Git 提交复现，本次由 RELEASE-INFO、SHA256SUMS 和源文件哈希对照提供本地证据。

## 一次会话
- 开始时间：2026-08-19 02:30:00 +0800
- 结束时间：2026-08-19 03:45:00 +0800
- 本次焦点：实现内网常规快照同步手工字段保护、旧清库快照恢复、成本分系统字典及 20260819 发布包

### 本次进展
- 新增 cost_subsystem_dict 的 MySQL、PostgreSQL、PostgreSQL 9.2/DWS 全量和 20260819 增量结构，历史项目办与工作令分系统值去重回填。
- 新增成本分系统字典后端查询/维护接口、租户内重名校验、管理员权限、服务测试，以及成本后台管理页和菜单可见性。
- collect 页移除中台通用 cost_subsystem 字典依赖，项目办与工作令均改用成本字典多选；阶段继续以逗号分隔多选保存。
- snapshot-upsert 新增逐行 manual_field_baseline 和五类摘要；同步后对项目办、项目状态、单位填报、工作令填报和预警状态逐行复验，异常拒绝 SUCCESS。
- 收紧工作令同步字段所有权，既有行不再被同步清空 fiscal_year，合同、到款、目标、审定、阶段、分系统、简称、配套数、纵向分工和状态均不进入外部 UPDATE SET。
- 新增 cost_manual_snapshot 建表、生成快照、清库前验收、业务键恢复、异常清单、恢复后验收及显式备份/确认包装器。
- 指定 release-20260729-data-integration 原地升级 20260819，新增 business-upgrade、manual-preservation、验收文档、RELEASE-INFO、验包规则和 58 项 SHA256。
- 验证通过：后端 16 测试、前端成本 vue-tsc 与目标 ESLint、DWS 29 SQL PowerShell/Bash 静态检查、三个仓库 diff check、发布包验包，以及三个模板目录与发布副本逐文件 SHA256 一致。

### 涉及文件
- baback/sql/mysql/costree-cost.sql
- baback/sql/postgresql/costree-cost.sql
- baback/sql/postgresql92/costree-cost.sql
- baback/sql/*/costree-cost-20260819-manual-fields-subsystem.sql
- baback/sql/postgresql*/costree-deploy/14-upgrade-existing-to-20260819-manual-fields-subsystem.sql
- baback/yudao-module-cost/.../subsystemdict/
- costree-frontend/src/api/cost/subsystemDict/
- costree-frontend/src/views/cost/subsystemDict/
- costree-frontend/src/views/cost/collect/index.vue
- deploy/cost-server-offline-template/database/postgresql92/03-data-integration/snapshot-upsert/
- deploy/cost-server-offline-template/database/postgresql92/03-data-integration/manual-preservation/
- deploy/cost-server-offline-template/database/postgresql92/03-data-integration/business-upgrade/
- cost-intranet-data-kit/release-20260729-data-integration/

### 下次恢复点
- 下次先执行 agent-handoff resume。重点进入 ignored 的 cost-intranet-data-kit/release-20260729-data-integration，按 docs/12 和 postgresql92/business-upgrade 先升级检查，再执行 snapshot-upsert 两批幂等验收，最后仅在完整备份的专用测试库用 manual-preservation 做一次清库恢复往返。要求外部字段更新、手工字段和状态摘要不变、源缺失只出差异、不删除业务行；无真实结果前不要宣称内网上线通过。

### 风险与备注
- 未在真实 PostgreSQL 9.2 或 GaussDB(DWS) 执行新增 DDL、逐行摘要、恢复 SQL 和动态索引检查，静态兼容通过不能替代现场执行。
- 清库恢复会按稳定业务键重映射项目、单位和工作令；真实历史数据中的重复键、单位别名或孤立预警必须通过 restore_exception 和现场演练确认。
- cost_manual_snapshot 表通过当前 20260819 业务表结构创建，必须先完成 20260819 升级；未来新增手工字段时需同步升级保护表和摘要。
- Maven 构建仍输出仓库既有重复依赖声明警告，本轮聚焦测试成功但未处理这些无关 POM 问题。

## 一次会话
- 开始时间：2026-08-24 01:30:00 +0800
- 结束时间：2026-08-24 02:30:43 +0800
- 本次焦点：实现型号比对模块及内网权限发布更新

### 本次进展
- 新增 /cost/model-comparison/options、compare、export-excel 接口及权限注解
- 新增门户型号比对入口、远程选择、基准排序、金额与组成图表、差异矩阵和下钻
- 四方言及 DM8 发布脚本新增 query/export 权限，当前目标为 21 个权限点和 42 条角色权限映射
- release-20260729-data-integration 原地更新并通过验包

### 涉及文件
- H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/controller/admin/modelcomparison
- H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/modelcomparison
- H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/modelComparison/index.vue
- H:/light/project/sqlbot_with_bcback/costree-frontend/src/api/cost/modelComparison/index.ts
- H:/light/project/costree/deploy/cost-server-offline-template/database/platform
- H:/light/project/costree/cost-intranet-data-kit/release-20260729-data-integration

### 下次恢复点
- 从真实环境验收开始：先部署前后端，再执行 DM/MQB 权限脚本和检查脚本，精确失效 role、menu_role_ids、permission_menu_ids 缓存，最后逐类账号验证选择范围、直接 API 越权、单位交集、金额对账和导出。

### 风险与备注
- 三个仓库均有用户原有未提交修改，本轮未提交或推送
- 静态测试不能替代真实数据库、缓存和账号权限验收

## 一次会话
- 开始时间：2026-08-24 02:34:00 +0800
- 结束时间：2026-08-24 02:40:40 +0800
- 本次焦点：将指定内网数据集成目录原地升级为 20260824 权限首次部署包

### 本次进展
- 将 PACKAGE_REVISION 和 BUILD_DATE 更新为 20260824，成本业务结构版本保持 20260820
- 将 DM8 权限初始化和权限检查文件重命名为 20260824，并更新全部执行入口引用
- 新增 20260824 型号比对与权限首次导入验收文档，明确无需先跑旧 20260817 权限脚本
- 更新验包器必需文件、版本令牌和 SHA256SUMS，67 个文件中除清单自身外 66 个文件全部纳入哈希
- 包验收、PowerShell 语法、8 条型号比对角色映射及源/发布权限脚本哈希核对通过

### 涉及文件
- cost-intranet-data-kit/release-20260729-data-integration/00-开始这里.md
- cost-intranet-data-kit/release-20260729-data-integration/RELEASE-INFO.txt
- cost-intranet-data-kit/release-20260729-data-integration/SHA256SUMS.txt
- cost-intranet-data-kit/release-20260729-data-integration/platform/README.md
- cost-intranet-data-kit/release-20260729-data-integration/platform/dm8/costree-access-role-menu-20260824.sql
- cost-intranet-data-kit/release-20260729-data-integration/platform/dm8/check-cost-permissions-20260824.sql
- cost-intranet-data-kit/release-20260729-data-integration/docs/14-20260824型号比对与权限首次导入验收.md
- cost-intranet-data-kit/release-20260729-data-integration/tools/verify-package.ps1

### 下次恢复点
- 下一次从 docs/14-20260824型号比对与权限首次导入验收.md 开始；连接 MQB 后按 platform/README 顺序执行 costree-access-role-menu-20260824.sql、cost-warning-notify-template-20260820.sql、check-cost-permissions-20260824.sql，前六组必须为 OK，再精确清缓存并用五类账号验收。

### 风险与备注
- 发布目录被 root .gitignore 忽略，交付证据依赖本地目录、RELEASE-INFO 和 SHA256SUMS
- 静态验包不能替代真实 DM8、Redis、中台登录和权限范围验收
- 执行权限初始化前必须备份平台表、替换示例租户 124、关闭自动提交并串行执行

## 一次会话
- 开始时间：2026-08-24 02:35:00 +0800
- 结束时间：2026-08-24 02:46:49 +0800
- 本次焦点：修复型号比对页缺少纵向滚动

### 本次进展
- 对比同类 ledger-composition-detail 与 warning 页面后确认根容器缺少独立纵向滚动
- 仅修改 modelComparison/index.vue 根容器的 height、overflow 和 scrollbar-gutter
- 通过类型检查、目标 ESLint、Stylelint、diff check 和真实登录态浏览器滚动验证

### 涉及文件
- H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/modelComparison/index.vue

### 下次恢复点
- 继续真实环境验收；型号比对页滚动修复位于 comparison-page 根样式，若内网仍无法滚动，先确认部署的 dist 是否包含本次前端源码。

### 风险与备注
- 前端工作树包含用户原有未提交修改，本轮未提交或推送
- 真实内网浏览器与部署制品仍需上线后复验

## 一次会话
- 开始时间：2026-08-24 02:47:00 +0800
- 结束时间：2026-08-24 02:55:02 +0800
- 本次焦点：审查、提交并推送型号比对与 20260824 部署更新

### 本次进展
- 确认 root、backend、frontend 与对应远端均为 0/0 无分叉
- 后端 31/31 聚焦测试通过，前端成本类型检查和 ESLint 通过，型号比对页 Stylelint 通过
- 20260824 本地数据集成发布包验包通过，PowerShell/Bash 验包脚本语法通过
- root 4a16981 推送 origin/jt/cost-server-offline-20260820
- 后端 e76c2369 推送 codeup/feature/costree
- 前端 a6138aea 推送 codeup/feature/costree2

### 涉及文件
- H:/light/project/costree/deploy/cost-server-offline-template
- H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost
- H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/modelComparison
- H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost

### 下次恢复点
- 从真实内网验收开始；源码基线为 root 4a16981、后端 e76c2369、前端 a6138aea。先部署制品，再按 20260824 文档执行 DM/MQB 权限初始化、检查和精确缓存失效。

### 风险与备注
- 前端 package-lock.json 的本地 npm 机械变化未提交并原样保留
- 被 .gitignore 忽略的本地发布成品目录未强制纳入 Git，版本证据仍依赖 RELEASE-INFO 与 SHA256SUMS
- 全量 Stylelint 扫描仍显示旧成本页面既有格式债务，本轮未扩大范围重排样式
- 静态与本地验证不能替代真实内网数据库、缓存和五类账号验收
