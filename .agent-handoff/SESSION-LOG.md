# 会话记录

## 一次会话
- 开始时间：2026-06-26 08:00:00 +0800
- 结束时间：2026-06-26 10:25:00 +0800
- 本次焦点：成本库树页面展示优化、数据采集字段口径调整和前后端提交推送收尾

### 本次进展
- 完成 /cost/catalog 布局优化，移除工作令明细后右侧项目区仍保持完整白色面板，修复卡片底部项目详情/成本树按钮被裁切问题。
- 完成 /cost/tree-detail 金额展示调整：型号节点展示合同、到款、目标、账面、审定；院内单位展示目标、账面、审定；院外单位展示目标、已拨付、审定。
- 完成 /cost/tree-detail 多单位矩阵视图：单位数较多时避免横向拖动底部滚动条，仍保留树图切换。
- 完成 /cost/tree-unit-detail 工作令卡片简化：隐藏工作令编号、去掉阶段集合，状态位置改为审定金额，工作令层不再黄红预警。
- 完成 /cost/collect 项目办填报字段调整：新增是否产品附件/发射车等、是否免税、对手字段展示，承研单位改为单位字典下拉。
- 后端新增 cost_project_basic.product_attachment_type、tax_exempt 字段和 MySQL/PostgreSQL 增量 ALTER 脚本。
- 已运行后端编译 mvn -pl yudao-module-cost/yudao-module-cost-biz -am -DskipTests compile，通过。
- 已运行前端类型检查 pnpm run ts:check:cost，通过。
- 后端提交 18e436c3 feat: extend project basic collection fields 已推送 codeup/feature/costree。
- 前端提交 6d77dc4 feat: update cost collection project office form 已推送 codeup/feature/costree2。

### 涉及文件
- baback/sql/mysql/costree-cost.sql
- baback/sql/mysql/costree-cost-20260626-add-project-basic-extra-fields.sql
- baback/sql/postgresql/costree-cost.sql
- baback/sql/postgresql/costree-cost-20260626-add-project-basic-extra-fields.sql
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/dal/dataobject/projectbasic/CostProjectBasicDO.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/controller/admin/projectbasic/vo/CostProjectBasicSaveReqVO.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/controller/admin/projectbasic/vo/CostProjectBasicRespVO.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/controller/admin/projectbasic/vo/CostProjectBasicImportExcelVO.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/controller/admin/projectbasic/CostProjectBasicController.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/projectbasic/CostProjectBasicServiceImpl.java
- costree-frontend/src/api/cost/projectBasic/index.ts
- costree-frontend/src/views/cost/collect/index.vue
- costree-frontend/src/views/cost/treeDetail/index.vue

### 下次恢复点
- 继续项目时先运行 python .agent-handoff/runtime/agent-handoff/scripts/handoff.py resume .；下一步优先在目标数据库执行 20260626 新增字段 ALTER 脚本，然后启动后端和前端核验 /cost/collect、/cost/tree-detail、/cost/tree-unit-detail。

### 风险与备注
- 本轮新增字段要求数据库结构同步升级；如果只更新 jar/前端而未跑 ALTER，保存项目基本情况会报缺列。
- 项目办填报的承研单位现在依赖 cost_unit_dict，如果内网单位字典未导入或状态不可用，下拉会为空，需要先导入单位字典。
- 树页面账面组成已按八项支出口径改造方向推进，但正式验收仍需用真实账面明细核对二级科目编码 501101-501108 的金额合计。

## 一次会话
- 开始时间：2026-07-21 18:30:00 +0800
- 结束时间：2026-07-21 19:34:41 +0800
- 本次焦点：成本树管理单位分组、管理单位穿透、单位使用率排名和演示数据收尾

### 本次进展
- 新增 cost_unit_dict.manage_unit_group，支持 OVERALL、ASSEMBLY、PROFESSIONAL、FOUNDATION、OUTER 分类。
- 完成 /cost/tree-detail 管理单位聚合、五类分组树、响应式单位矩阵和院内管理单位数量统计。
- 完成 /cost/tree-unit-detail 管理单位穿透，列表和详情展示实际核算单位，组成查询继续使用工作令实际 unitName。
- 完成 /cost/work-order/page 和 /cost/overview/unit-detail 的 manageUnitName 可选查询。
- 新增 MySQL/PostgreSQL 20260721 增量迁移脚本及 costree-unit-hierarchy-demo.sql 演示数据。
- 将 /cost/tree-detail 右侧重复金额替换为院内管理单位使用率排名，按账面/目标降序并保留黄红预警颜色。
- 更新 /cost/catalog 卡片文案：项目类别/批次、研制阶段、用户。
- 前端 pnpm run ts:check:cost 和定向 ESLint 通过。
- 后端 mvn -pl yudao-module-cost/yudao-module-cost-biz -am -DskipTests compile 通过。
- 后端提交 e70c6eac 已推送 codeup/feature/costree。
- 前端提交 db0b185 已推送 codeup/feature/costree2。
- root 下 cost-intranet-data-kit/ 与 zip 保持未跟踪，本轮未加入 Git。

### 涉及文件
- baback/sql/mysql/costree-cost.sql
- baback/sql/mysql/costree-cost-20260721-add-manage-unit-group.sql
- baback/sql/mysql/costree-unit-hierarchy-demo.sql
- baback/sql/postgresql/costree-cost.sql
- baback/sql/postgresql/costree-cost-20260721-add-manage-unit-group.sql
- baback/sql/postgresql/costree-unit-hierarchy-demo.sql
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/dal/dataobject/unitdict/CostUnitDictDO.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/dal/mysql/workorder/CostWorkOrderMapper.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/overview/CostOverviewServiceImpl.java
- costree-frontend/src/api/cost/overview/index.ts
- costree-frontend/src/api/cost/unitDict/index.ts
- costree-frontend/src/api/cost/workOrder/index.ts
- costree-frontend/src/views/cost/catalog/index.vue
- costree-frontend/src/views/cost/treeDetail/CostTreeNode.vue
- costree-frontend/src/views/cost/treeDetail/index.vue
- costree-frontend/src/views/cost/treeUnitDetail/index.vue

### 下次恢复点
- 继续项目时先运行 python .agent-handoff/runtime/agent-handoff/scripts/handoff.py resume .；部署最新版本前优先执行 20260721 manage_unit_group 数据库迁移，再用 ZY-2026-DEMO-UNIT-001 验证五类管理单位分组和电子所三核算单位汇总。

### 风险与备注
- 只更新 jar 而未执行数据库增量脚本会导致 manage_unit_group 缺列。
- manage_unit_name 为空时会按核算单位名称分别展示，无法形成期望的管理单位汇总。
- 真实单位名称与 cost_unit_dict.accounting_unit_name 不一致时，管理单位查询和穿透可能遗漏工作令。
- 使用率排名依赖单位目标成本；目标为 0 或空时仅显示 --，不参与有效比例排序。

## 一次会话
- 开始时间：2026-07-22 00:25:00 +0800
- 结束时间：2026-07-22 01:12:12 +0800
- 本次焦点：项目详情三标签维护、逻辑工作令归一和跨年度借方账面汇总收尾

### 本次进展
- 完成 /cost/project-detail 三标签页面、汇总卡片和项目上下文重构。
- 完成项目基本情况新增、编辑、查看弹窗及 DRAFT/REJECTED 可编辑、SUBMITTED/APPROVED 只读规则。
- 完成单位成本只读列表、查看工作令和账面组成穿透。
- 完成工作令固定金额、业务字段维护和账面只读展示，提交时校验合同与目标大于 0。
- 新增 cost_work_order.income_amount，更新 DO、VO、导入模型、前端类型和完整 DDL。
- 工作令唯一口径调整为租户+项目+实际单位+工作令编号，fiscal_year 保留兼容但统一置空。
- 新增 MySQL/PostgreSQL 20260722 迁移脚本，支持冲突检查、主记录保留、明细及预警外键重绑、重复行清理和借方账面重算。
- 更新金额同步模板、两项目演示同步、校验脚本、seed 和单位层级演示脚本。
- 移除 /cost/tree-unit-detail 年度展开，账面组成详情默认汇总全部年度并保留明细年度列。
- 后端 Reactor CostMapperAnnotationSqlTest 通过：1 个测试，0 失败，BUILD SUCCESS。
- 前端 pnpm run ts:check:cost 和定向 ESLint 通过，前后端 git diff --check 通过。
- 后端提交 747d6e25 已推送 codeup/feature/costree。
- 前端提交 56acad9 已推送 codeup/feature/costree2。
- root 下 cost-intranet-data-kit/ 与 zip 作为本地交付制品加入 .gitignore，不提交源码仓库。

### 涉及文件
- costree-frontend/src/views/cost/projectDetail/index.vue
- costree-frontend/src/views/cost/collect/index.vue
- costree-frontend/src/views/cost/treeUnitDetail/index.vue
- costree-frontend/src/views/cost/ledgerCompositionDetail/index.vue
- costree-frontend/src/api/cost/workOrder/index.ts
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/dal/dataobject/workorder/CostWorkOrderDO.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/workorder/CostWorkOrderServiceImpl.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/dal/mysql/workorder/CostWorkOrderMapper.java
- baback/sql/mysql/costree-cost-20260722-logical-work-order.sql
- baback/sql/postgresql/costree-cost-20260722-logical-work-order.sql
- baback/sql/postgresql/costree-demo-source/02-sync-to-cost.sql
- baback/sql/postgresql/costree-demo-source/03-verify.sql

### 下次恢复点
- 继续项目时先运行 python .agent-handoff/runtime/agent-handoff/scripts/handoff.py resume .；部署 747d6e25/56acad9 前先备份并执行 20260721、20260722 两个增量迁移，再用有登录态环境核验项目详情三标签、逻辑工作令和跨年度借方账面合计。

### 风险与备注
- 只更新前后端而不执行 20260722 数据库迁移会出现 income_amount 缺列或旧唯一约束冲突。
- 旧年度工作令固定金额存在不一致时不能自动决定权威值，必须先处理冲突。
- 迁移会重绑账面明细和历史预警的 work_order_id，执行前必须备份相关表。
- 项目单位正式金额仍以 cost_unit_cost_detail 同步数据为准，工作令固定金额不得用于正式汇总。

## 一次会话
- 开始时间：2026-07-22 03:00:00 +0800
- 结束时间：2026-07-22 04:16:53 +0800
- 本次焦点：项目展示、阶段筛选、账面组成穿透导出与 PostgreSQL 内网升级包收尾

### 本次进展
- 完成项目详情顶部项目基本情况、单位成本和工作令维护布局及完整字段展示。
- 完成首页领域账面组成到借方明细页的穿透和当前筛选条件 Excel 导出。
- 完成 /cost/collect 两类表单字段标签悬停说明组件和集中说明文案。
- 新增统一阶段集合工具，/cost/tree-detail 与 /cost/tree-unit-detail 均按完整集合匹配。
- 单位页增加到款；工作令卡片增加编号、目标和账面，展开详情以合同金额替换产品简称。
- 将查阅超支详情统一改为查看详情，修复 ECharts 弹窗多次打开后实例与 DOM 脱节，并用请求序号避免串数据。
- 工作令组成弹窗可进入组成明细页并预选八项科目，返回时恢复项目、管理单位、单位类别和阶段条件。
- 新增 export-work-order-composition-excel，批量汇总借方八项金额和占比，限制最多 5000 条工作令。
- 新增 PostgreSQL costree-deploy 升级包：00-precheck、10-upgrade、20-verify、README 和打包/执行/校验脚本。
- 前端 pnpm run ts:check:cost 与定向 ESLint 通过，前后端 git diff --check 通过。
- 后端 Reactor compile 和 CostMapperAnnotationSqlTest 通过：1 个测试，0 失败，BUILD SUCCESS。
- 前端提交 f78d9c0 已推送 codeup/feature/costree2。
- 后端提交 1f245334 已推送 codeup/feature/costree。

### 涉及文件
- costree-frontend/src/views/cost/projectDetail/index.vue
- costree-frontend/src/views/cost/overview/CompositionDetailDialog.vue
- costree-frontend/src/views/cost/ledgerCompositionDetail/index.vue
- costree-frontend/src/views/cost/collect/FieldHelpLabel.vue
- costree-frontend/src/views/cost/collect/index.vue
- costree-frontend/src/views/cost/utils/stage.ts
- costree-frontend/src/views/cost/treeDetail/index.vue
- costree-frontend/src/views/cost/treeUnitDetail/index.vue
- costree-frontend/src/api/cost/workOrderLedger/index.ts
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/controller/admin/workorderledger/CostWorkOrderLedgerController.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/workorderledger/CostWorkOrderLedgerServiceImpl.java
- baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/dal/mysql/workorderledger/CostWorkOrderLedgerDetailMapper.java
- baback/sql/postgresql/costree-deploy/README.md
- baback/sql/postgresql/costree-deploy/10-upgrade-existing-to-20260722.sql

### 下次恢复点
- 继续项目时先运行 python .agent-handoff/runtime/agent-handoff/scripts/handoff.py resume .；内网部署使用前端 f78d9c0、后端 1f245334，并严格按 baback/sql/postgresql/costree-deploy/README.md 完成数据库检查、升级和验证，再做有登录态的阶段组合与两类导出回归。

### 风险与备注
- 只替换前后端制品而不执行数据库升级包，会产生缺列、旧唯一约束或重复工作令问题。
- 工作令八项组成导出依赖账面明细科目映射和借方口径，内网正式数据应抽样与财务源表对账。
- 阶段筛选已统一为集合完整匹配，其他非树页面若仍用最高阶段或任一命中，需要后续按业务范围逐页确认。
- 浏览器未取得业务登录态，最终视觉、权限及实际下载文件仍有现场回归风险。

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
