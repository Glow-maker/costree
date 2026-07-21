# 会话记录

## 一次会话
- 开始时间：2026-06-12 02:00:00 +0800
- 结束时间：2026-06-12 02:20:00 +0800
- 本次焦点：沉淀长期文档维护与工作区活力机制

### 本次进展
- 读取 long-term-project-docs 和 agent-handoff 规则，确认本轮只做文档治理。
- 更新 00-overview/05-长期项目文档与工程经验沉淀模式.md，补充项目操作系统、固定开发节奏、周巡检、可复用 prompt 和文档活力判断标准。
- 同步更新 README.md、PROJECT_STATE.md、PLAN.md、AGENTS.md 和 90-logs/02-变更日志.md。
- 读取修改后的 Markdown 文件并检查关键入口，确认均可正常读取。

### 涉及文件
- H:\light\project\costree\note\00-overview\05-长期项目文档与工程经验沉淀模式.md
- H:\light\project\costree\note\README.md
- H:\light\project\costree\note\PROJECT_STATE.md
- H:\light\project\costree\note\PLAN.md
- H:\light\project\costree\note\AGENTS.md
- H:\light\project\costree\note\90-logs\02-变更日志.md

### 下次恢复点
- 继续成本库项目时，先运行 python H:\light\project\costree\.agent-handoff\runtime\agent-handoff\scripts\handoff.py resume H:\light\project\costree；再按 note/00-overview/05-长期项目文档与工程经验沉淀模式.md 做 5 分钟恢复。

### 风险与备注
- 文档机制只有持续执行才有价值；后续如果开发后不更新 PROJECT_STATE、PLAN、RISKS、DECISIONS 和工程经验手册，文档会再次失效。
- 本轮未运行前后端构建，因为只修改 Markdown 文档。

## 一次会话
- 开始时间：2026-06-12 15:30:00 +0800
- 结束时间：2026-06-12 16:35:00 +0800
- 本次焦点：接管成本库项目并完成本地页面复核

### 本次进展
- 读取 agent-handoff 和 note 入口文档，确认当前目标、待办、阻塞、工程约束和本机前后端仓库位置。
- 确认 cost-server、gateway、Nacos 和前端 dev server 本地链路，前端使用 VITE_BASE_URL=http://127.0.0.1:38080 且不启用 VITE_COST_MOCK_LOGIN。
- 清理一批无效自动导入并修正 src/main.ts 初始化异常日志调用，解除 Vite 启动 blocker。
- 通过浏览器复核 /cost/pending-allocation、/cost/warning、/cost/catalog，页面均可渲染当前测试数据和关键交互。
- 运行前端类型检查、触达文件 ESLint、后端成本模块编译和 diff 检查，并同步更新项目状态、计划、变更日志和新对话接管指南。

### 涉及文件
- D:\light\academy8-operation-control-center-frontend\src\main.ts
- D:\light\academy8-operation-control-center-frontend\src\views\... 多处非成本页面无效自动导入清理
- D:\light\bcback\yudao-module-cost\yudao-module-cost-biz\src\main\resources\application-local.yml
- D:\light\costree\note\README.md
- D:\light\costree\note\AGENTS.md
- D:\light\costree\note\PROJECT_STATE.md
- D:\light\costree\note\PLAN.md
- D:\light\costree\note\90-logs\02-变更日志.md
- D:\light\costree\note\00-overview\06-新对话接管成本库项目启动指南.md

### 下次恢复点
- 继续成本库项目时，先运行 python D:\light\costree\.agent-handoff\runtime\agent-handoff\scripts\handoff.py resume D:\light\costree；然后按 TASK-002 进入 /cost/analysis 第一版迁移。当前本地前端可访问 http://localhost:5173/，前端继续使用 VITE_BASE_URL=http://127.0.0.1:38080 且不启用 VITE_COST_MOCK_LOGIN。

### 风险与备注
- 后端 application-local.yml 当前有本地配置变更，提交前需要确认是否属于应纳入版本的 Nacos discovery 默认值调整。
- 前端触达文件 ESLint 仍有 10 个既有格式警告，但退出码为 0，不阻塞当前成本库页面复核。
- 内网真实部署、菜单权限和业务金额口径仍待确认。

## 一次会话
- 开始时间：2026-06-12 16:45:00 +0800
- 结束时间：2026-06-12 16:55:00 +0800
- 本次焦点：补充成本库模块化开发边界约束

### 本次进展
- 根据用户要求确认模块化开发约束：默认只管成本库/成本树相关内容。
- 更新 AGENTS.md，明确前端和后端默认可修改范围，以及触碰其他模块时的通知和文档要求。
- 更新 00-overview/04-工程经验与开发约束手册.md，新增 FE-007、BE-007 模块边界经验和每次变更检查项。
- 更新 DECISIONS.md、PROJECT_STATE.md 和 90-logs/02-变更日志.md，记录该规则为长期决策。

### 涉及文件
- D:\light\costree\note\AGENTS.md
- D:\light\costree\note\00-overview\04-工程经验与开发约束手册.md
- D:\light\costree\note\DECISIONS.md
- D:\light\costree\note\PROJECT_STATE.md
- D:\light\costree\note\90-logs\02-变更日志.md

### 下次恢复点
- 继续成本库项目时，先运行 python D:\light\costree\.agent-handoff\runtime\agent-handoff\scripts\handoff.py resume D:\light\costree；开发 TASK-002 /cost/analysis 时默认只修改成本库/成本树相关文件，如需触碰其他模块先通知用户并写入文档。

### 风险与备注
- 本规则执行时要区分成本库必要集成变更和其他模块顺手重构；必要集成变更可做，但必须先通知和留痕。

## 一次会话
- 开始时间：2026-06-17 22:58:49 +0800
- 结束时间：2026-06-18 02:20:00 +0800
- 本次焦点：成本树预警、工作令组成穿透、PostgreSQL 适配、部署脚本和离线包收尾

### 本次进展
- 完成 /cost/tree-detail 账面预警展示，卡片、顶部汇总、详情面板和进度状态按 80%/超目标口径统一。
- 完成 /cost/tree-unit-detail 账面预警、默认树状卡片、工作令账面组成穿透弹窗；/cost/catalog 默认卡片视图。
- 修复 /cost/collect 左侧内容超屏不可滚动问题，并将周期字段恢复为年月口径。
- 对齐内网单位字典、主业项目树、工作令映射、账面明细表字段，补充 cost_work_order 源字段。
- 新增工作令账面组成后端接口，账面明细按科目 Top8 聚合，前端展示环形图和明细列表。
- 新增 sql/mysql 与 sql/postgresql 成本模块建表和测试 seed 脚本；PostgreSQL 脚本已做 JDBC dry-run 验证。
- 补充 PostgreSQL JDBC 依赖，并调整成本模块手写 SQL 兼容 PostgreSQL。
- 生成 cost-server-offline-package 与 zip 离线包，包含 jar、外部配置、启动脚本、建表脚本和说明。
- 前端提交 0b657d1 已推送到 codeup/feature/costree2；后端提交 976e511c 已推送到 codeup/feature/costree。

### 涉及文件
- H:\light\project\sqlbot_with_bcback\costree-frontend\src\views\cost\treeUnitDetail\index.vue
- H:\light\project\sqlbot_with_bcback\costree-frontend\src\views\cost\treeDetail\index.vue
- H:\light\project\sqlbot_with_bcback\baback\yudao-module-cost\yudao-module-cost-biz\src\main\java\cn\iocoder\yudao\module\cost
- H:\light\project\sqlbot_with_bcback\baback\sql\postgresql\costree-cost.sql
- H:\light\project\costree\cost-server-offline-package
- H:\light\project\costree\.gitignore

### 下次恢复点
- 继续项目时，先运行 python H:\light\project\costree\.agent-handoff\runtime\agent-handoff\scripts\handoff.py resume H:\light\project\costree；然后优先验证内网 cost-server 部署链路：建表、配置外部 application-jt.yml、启动服务、确认 Nacos cost-server、经网关访问 /admin-api/cost/**，再用真实登录态复核成本树和单位工作令页面。

### 风险与备注
- 真实内网环境需要重新确认 Nacos 命名空间、网关路由、菜单权限、租户 ID 和数据权限，否则页面可能能启动但查不到数据或被权限拦截。
- PostgreSQL 脚本已验证建表和 seed 可执行，但真实数据导入仍需按内网源表字段、租户、单位、工作令编号规则做映射校验。
- 离线包为本机产物，不进入 Git；后续如需多人复用，应建立制品分发方式。

## 一次会话
- 开始时间：2026-06-18 02:25:00 +0800
- 结束时间：2026-06-18 02:37:16 +0800
- 本次焦点：成本库文档路径可迁移口径收口

### 本次进展
- 统一 note 活跃 Markdown 中的本机绝对路径为占位符或相对路径。
- 更新 README.md 和 AGENTS.md，明确 <costree-root>、<frontend-root>、<backend-root> 以及推荐相对布局。
- 更新 00-overview/00-文档结构与维护规范.md，新增路径书写规则。
- 更新 00-overview/06-新对话接管成本库项目启动指南.md，将启动 prompt 和常用命令改成项目根目录下的相对路径。
- 更新 PROJECT_STATE.md、PLAN.md、DECISIONS.md 和 90-logs/02-变更日志.md，记录路径可迁移口径和当前前后端已推送基线。

### 涉及文件
- note/README.md
- note/AGENTS.md
- note/PROJECT_STATE.md
- note/PLAN.md
- note/DECISIONS.md
- note/00-overview/00-文档结构与维护规范.md
- note/00-overview/06-新对话接管成本库项目启动指南.md
- note/90-logs/02-变更日志.md
- .agent-handoff/_tmp/close-session-20260618-portable-paths.json

### 下次恢复点
- 继续项目时，先在 <costree-root> 运行 python .agent-handoff/runtime/agent-handoff/scripts/handoff.py resume .；随后按 PROJECT_STATE.md 的下一步最小任务推进内网部署验证。

### 风险与备注
- 历史 .agent-handoff 会话日志和归档记录可能仍包含当时真实执行路径；这些属于历史记录，不作为当前操作指南使用。
- 如果内网仓库不采用推荐相对布局，需要先把 <frontend-root> 和 <backend-root> 替换为实际仓库根目录。

## 一次会话
- 开始时间：2026-06-21 23:20:00 +0800
- 结束时间：2026-06-22 00:03:25 +0800
- 本次焦点：成本库内网数据源表映射和两个型号试点步骤收口

### 本次进展
- 整理主业项目树原表 ads_lc_lshsxm2022 的字段和它到 cost_model_node、cost_project 的映射思路。
- 整理工作令关联主业项目字典 dwd_bd_bfcustomitem_gzl 的字段和它到 cost_work_order 的映射思路。
- 整理项目工作令账面成本明细 dws_bu_pz_pzmx_gzl 的字段和它到 cost_work_order_ledger_detail 的映射思路。
- 解释 /cost/catalog 左侧树来自 cost_model_node，右侧项目卡片来自 cost_project，工作令数量来自 cost_work_order，账面成本来自账面明细聚合。
- 将原本偏专业的总设计方案调整为更容易交接理解的语言，并补充两个型号试点的操作顺序。

### 涉及文件
- note/30-data/05-内网源表与成本库业务表关系实施方案.md
- note/30-data/06-内网原表-主业项目树-ads_lc_lshsxm2022.md
- note/30-data/07-内网原表-工作令关联主业项目字典-dwd_bd_bfcustomitem_gzl.md
- note/30-data/08-内网原表-项目工作令账面成本明细-dws_bu_pz_pzmx_gzl.md
- note/30-data/09-成本库内网数据对接总设计方案.md
- note/30-data/README.md
- note/90-logs/02-变更日志.md
- .agent-handoff/_tmp/close-session-20260622-cost-data-mapping-wrapup.json

### 下次恢复点
- 继续项目时先运行 python .agent-handoff/runtime/agent-handoff/scripts/handoff.py resume .；下一步从两个型号试点第 4 步开始，补 cost_work_order 目标成本、阶段、分系统等业务字段，再核验成本树、预警和组成穿透。

### 风险与备注
- 当前映射方案来自内网截图和现有 DDL/代码理解，正式上线前仍需拿到内网真实 DDL 和样本数据复核。
- 如果 source_work_order_id 或 project_code 在真实库中不能稳定匹配，需要补映射表或改导入规则。
- 如果账面明细达到百万级以上，应优先靠数据库索引和 SQL 聚合，不要在 Java 内存中全量汇总。

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
