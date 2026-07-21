# 每日工作日志

---

## 2026-07-21

### 成本树管理单位分组、管理单位穿透、单位使用率排名和演示数据收尾
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

#### 风险与备注
- 只更新 jar 而未执行数据库增量脚本会导致 manage_unit_group 缺列。
- manage_unit_name 为空时会按核算单位名称分别展示，无法形成期望的管理单位汇总。
- 真实单位名称与 cost_unit_dict.accounting_unit_name 不一致时，管理单位查询和穿透可能遗漏工作令。
- 使用率排名依赖单位目标成本；目标为 0 或空时仅显示 --，不参与有效比例排序。

---

## 2026-06-26

### 成本库树页面展示优化、数据采集字段口径调整和前后端提交推送收尾
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

#### 风险与备注
- 本轮新增字段要求数据库结构同步升级；如果只更新 jar/前端而未跑 ALTER，保存项目基本情况会报缺列。
- 项目办填报的承研单位现在依赖 cost_unit_dict，如果内网单位字典未导入或状态不可用，下拉会为空，需要先导入单位字典。
- 树页面账面组成已按八项支出口径改造方向推进，但正式验收仍需用真实账面明细核对二级科目编码 501101-501108 的金额合计。

---

## 2026-06-22

### 成本库内网数据源表映射和两个型号试点步骤收口
- 整理主业项目树原表 ads_lc_lshsxm2022 的字段和它到 cost_model_node、cost_project 的映射思路。
- 整理工作令关联主业项目字典 dwd_bd_bfcustomitem_gzl 的字段和它到 cost_work_order 的映射思路。
- 整理项目工作令账面成本明细 dws_bu_pz_pzmx_gzl 的字段和它到 cost_work_order_ledger_detail 的映射思路。
- 解释 /cost/catalog 左侧树来自 cost_model_node，右侧项目卡片来自 cost_project，工作令数量来自 cost_work_order，账面成本来自账面明细聚合。
- 将原本偏专业的总设计方案调整为更容易交接理解的语言，并补充两个型号试点的操作顺序。

#### 风险与备注
- 当前映射方案来自内网截图和现有 DDL/代码理解，正式上线前仍需拿到内网真实 DDL 和样本数据复核。
- 如果 source_work_order_id 或 project_code 在真实库中不能稳定匹配，需要补映射表或改导入规则。
- 如果账面明细达到百万级以上，应优先靠数据库索引和 SQL 聚合，不要在 Java 内存中全量汇总。

---

## 2026-06-18

### 成本树预警、工作令组成穿透、PostgreSQL 适配、部署脚本和离线包收尾
- 完成 /cost/tree-detail 账面预警展示，卡片、顶部汇总、详情面板和进度状态按 80%/超目标口径统一。
- 完成 /cost/tree-unit-detail 账面预警、默认树状卡片、工作令账面组成穿透弹窗；/cost/catalog 默认卡片视图。
- 修复 /cost/collect 左侧内容超屏不可滚动问题，并将周期字段恢复为年月口径。
- 对齐内网单位字典、主业项目树、工作令映射、账面明细表字段，补充 cost_work_order 源字段。
- 新增工作令账面组成后端接口，账面明细按科目 Top8 聚合，前端展示环形图和明细列表。
- 新增 sql/mysql 与 sql/postgresql 成本模块建表和测试 seed 脚本；PostgreSQL 脚本已做 JDBC dry-run 验证。
- 补充 PostgreSQL JDBC 依赖，并调整成本模块手写 SQL 兼容 PostgreSQL。
- 生成 cost-server-offline-package 与 zip 离线包，包含 jar、外部配置、启动脚本、建表脚本和说明。
- 前端提交 0b657d1 已推送到 codeup/feature/costree2；后端提交 976e511c 已推送到 codeup/feature/costree。

#### 风险与备注
- 真实内网环境需要重新确认 Nacos 命名空间、网关路由、菜单权限、租户 ID 和数据权限，否则页面可能能启动但查不到数据或被权限拦截。
- PostgreSQL 脚本已验证建表和 seed 可执行，但真实数据导入仍需按内网源表字段、租户、单位、工作令编号规则做映射校验。
- 离线包为本机产物，不进入 Git；后续如需多人复用，应建立制品分发方式。

### 成本库文档路径可迁移口径收口
- 统一 note 活跃 Markdown 中的本机绝对路径为占位符或相对路径。
- 更新 README.md 和 AGENTS.md，明确 <costree-root>、<frontend-root>、<backend-root> 以及推荐相对布局。
- 更新 00-overview/00-文档结构与维护规范.md，新增路径书写规则。
- 更新 00-overview/06-新对话接管成本库项目启动指南.md，将启动 prompt 和常用命令改成项目根目录下的相对路径。
- 更新 PROJECT_STATE.md、PLAN.md、DECISIONS.md 和 90-logs/02-变更日志.md，记录路径可迁移口径和当前前后端已推送基线。

#### 风险与备注
- 历史 .agent-handoff 会话日志和归档记录可能仍包含当时真实执行路径；这些属于历史记录，不作为当前操作指南使用。
- 如果内网仓库不采用推荐相对布局，需要先把 <frontend-root> 和 <backend-root> 替换为实际仓库根目录。

---

## 2026-06-12

### 初始化 agent-handoff 项目交接，并从 note 文档中心灌入当前成本库项目状态
- 安装并使用 agent-handoff 初始化 H:\light\project\costree\.agent-handoff。
- 发现 init 只生成空白骨架后，改为使用 close-session 更新请求写入当前项目状态。
- 从 note/PROJECT_STATE.md、README.md、PLAN.md 和工程经验文档提取当前目标、已完成事项、待办、阻塞和关键决策。
- 准备后续 resume 时可直接看到当前项目阶段、下一步和风险。

#### 风险与备注
- agent-handoff 是另一个交接体系，后续仍以 note/ 文档中心作为项目事实源，agent-handoff 用于跨会话快速恢复。
- 本次写入内容来自 2026-06-03 左右的 note 状态文档，后续如代码继续变化，需要再次 close-session 更新。

### 更新 agent-handoff 交接状态并收尾
- 读取 agent-handoff skill 规则，确认生成 Markdown 不应直接手改。
- 运行 resume 确认当前阶段、目标、阻塞、TASK-001 至 TASK-006、DEC-001 至 DEC-006 已存在。
- 准备 close-session 更新请求，保留正式项目待办不变，仅追加本轮收尾完成项。
- 通过 close-session 更新交接状态，并计划执行 validate 完成收尾校验。

#### 风险与备注
- agent-handoff 作为跨会话恢复入口，项目事实仍以 note/ 文档中心为主。
- 后续如果继续开发并修改前后端或文档，需要再次 close-session 更新交接状态。

### 沉淀长期文档维护与工作区活力机制
- 读取 long-term-project-docs 和 agent-handoff 规则，确认本轮只做文档治理。
- 更新 00-overview/05-长期项目文档与工程经验沉淀模式.md，补充项目操作系统、固定开发节奏、周巡检、可复用 prompt 和文档活力判断标准。
- 同步更新 README.md、PROJECT_STATE.md、PLAN.md、AGENTS.md 和 90-logs/02-变更日志.md。
- 读取修改后的 Markdown 文件并检查关键入口，确认均可正常读取。

#### 风险与备注
- 文档机制只有持续执行才有价值；后续如果开发后不更新 PROJECT_STATE、PLAN、RISKS、DECISIONS 和工程经验手册，文档会再次失效。
- 本轮未运行前后端构建，因为只修改 Markdown 文档。

### 接管成本库项目并完成本地页面复核
- 读取 agent-handoff 和 note 入口文档，确认当前目标、待办、阻塞、工程约束和本机前后端仓库位置。
- 确认 cost-server、gateway、Nacos 和前端 dev server 本地链路，前端使用 VITE_BASE_URL=http://127.0.0.1:38080 且不启用 VITE_COST_MOCK_LOGIN。
- 清理一批无效自动导入并修正 src/main.ts 初始化异常日志调用，解除 Vite 启动 blocker。
- 通过浏览器复核 /cost/pending-allocation、/cost/warning、/cost/catalog，页面均可渲染当前测试数据和关键交互。
- 运行前端类型检查、触达文件 ESLint、后端成本模块编译和 diff 检查，并同步更新项目状态、计划、变更日志和新对话接管指南。

#### 风险与备注
- 后端 application-local.yml 当前有本地配置变更，提交前需要确认是否属于应纳入版本的 Nacos discovery 默认值调整。
- 前端触达文件 ESLint 仍有 10 个既有格式警告，但退出码为 0，不阻塞当前成本库页面复核。
- 内网真实部署、菜单权限和业务金额口径仍待确认。

### 补充成本库模块化开发边界约束
- 根据用户要求确认模块化开发约束：默认只管成本库/成本树相关内容。
- 更新 AGENTS.md，明确前端和后端默认可修改范围，以及触碰其他模块时的通知和文档要求。
- 更新 00-overview/04-工程经验与开发约束手册.md，新增 FE-007、BE-007 模块边界经验和每次变更检查项。
- 更新 DECISIONS.md、PROJECT_STATE.md 和 90-logs/02-变更日志.md，记录该规则为长期决策。

#### 风险与备注
- 本规则执行时要区分成本库必要集成变更和其他模块顺手重构；必要集成变更可做，但必须先通知和留痕。
