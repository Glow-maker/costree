# PROJECT_STATE - 成本库当前项目状态

更新时间：2026-06-21

用途：给后续接手者或下一轮 Codex 会话快速恢复上下文。本文只记录当前状态，不替代详细 PRD、接口文档、数据模型和变更日志。

## 1. 当前目标

当前项目目标是在已有业务中台中嵌入“成本库/成本树”业务模块，不做独立系统。

第一阶段 MVP 目标仍是：让成本库数据可进入、可维护、可查询、可控权限。

当前正在推进的具体方向：

- 第一批数据口径补强：用 `cost_work_order_ledger_detail` 账面明细逐步替代工作令测试字段，并基于该口径支撑预警中心。
- 继续把 Figma/React 原型迁移为数据中台 Vue3 页面。
- 成本库前台门户和后台管理分开：前台用于总体展示、目录树、项目详情、成本树详情、数据采集；后台用于项目基本情况和工作令基础信息维护。
- 后端以 `cost-server` 独立服务形态接入业务中台，成本库后端模块为 `yudao-module-cost`。
- 外网测试库先用 MySQL 构造数据跑通，后续迁移到内网真实数据环境。
- 前端本地代理默认按嵌入业务中台口径运行，成本库接口跟随 `VITE_BASE_URL` 并复用真实登录态；只有显式开启 `VITE_COST_MOCK_LOGIN=true` 才进入独立 `cost-server` 模拟登录调试。
- 新增“边做边学”协作目标：每次写代码同步解释改动层级、请求链路、数据流、验证方式和本轮概念。
- 新增待分配池目标：集中展示产品简称未填或填写 `待分配` 的工作令，并支持按单位穿透查看账面支出。
- 新增后端性能治理目标：优先消除待分配池、预警中心、总体展示和同步导出中的全量加载隐患。
- 新增长期文档维护目标：把 `note` 和 `.agent-handoff` 作为项目操作系统使用，每轮开发前恢复上下文、开发中同步专题文档、收尾时更新状态和经验。

## 2. 已完成修改

### 文档中心

- 已建立 `<costree-root>/note` 文档中心。
- 已按长期维护方式建立目录：
  - `00-overview`
  - `10-research`
  - `20-requirements`
  - `30-data`
  - `40-api`
  - `50-frontend`
  - `60-backend`
  - `70-testing`
  - `80-deployment`
  - `90-logs`
- 已维护数据模型、接口字段契约、前端接入记录、后端实施记录、外网到内网迁移说明、决策记录和变更日志。
- 新增 `00-overview/02-全栈边做边学与运行链路说明.md`，集中解释 Nacos、Redis、网关、`cost-server` 和成本库请求链路。
- 新增 `00-overview/03-成本树代码阅读地图与自学路线.md`，按前端路由、页面、API、后端 Controller/Service/Mapper/DO、数据库表和请求链路梳理自主开发阅读顺序。
- 更新 `00-overview/05-长期项目文档与工程经验沉淀模式.md`，补充“文档作为项目操作系统”的长期维护机制，明确开工恢复、需求规格化、开发同步、收尾沉淀和周巡检节奏。
- 2026-06-18 已将活跃文档中的本机盘符路径统一为 `<costree-root>`、`<frontend-root>`、`<backend-root>` 或相对路径，便于内网和陵台计算机接手。
- 2026-06-21 新增 `30-data/05-内网源表与成本库业务表关系实施方案.md`，明确内网主业项目树、工作令映射、账面明细、单位字典和成本库业务表之间的关系。
- 2026-06-21 新增 `30-data/06-内网原表-主业项目树-ads_lc_lshsxm2022.md`，开始按内网真实原表整理主业项目树字段和映射待确认项。
- 2026-06-21 新增 `30-data/07-内网原表-工作令关联主业项目字典-dwd_bd_bfcustomitem_gzl.md`，开始按内网真实原表整理工作令关联主业项目字典字段和映射待确认项。
- 2026-06-21 新增 `30-data/08-内网原表-项目工作令账面成本明细-dws_bu_pz_pzmx_gzl.md`，开始按内网真实原表整理账面明细字段和映射待确认项。
- 2026-06-21 新增 `30-data/09-成本库内网数据对接总设计方案.md`，面向交接和执行汇总内网源表、成本库标准源表、业务维护表、页面聚合的设计思路、对应关系、导入维护步骤和两个型号试点方案。

### 数据与测试库

- 外网 MySQL 测试库：`costree_mvp`。
- 当前测试租户：`tenant_id = 124`。
- `schema-mvp.sql` 当前包含 12 张 MVP/源数据表：
  - `cost_source_project_tree`
  - `cost_model_node`
  - `cost_project`
  - `cost_unit_dict`
  - `cost_project_basic`
  - `cost_work_order`
  - `cost_work_order_project_ref`
  - `cost_work_order_ledger_detail`
  - `cost_unit_cost_detail`
  - `cost_import_batch`
  - `cost_import_error`
  - `cost_warning_record`
- 已按业务方建表参考新增三张源数据表：
  - `cost_source_project_tree`：源主业项目树。
  - `cost_work_order_project_ref`：工作令关联主业项目字典。
  - `cost_work_order_ledger_detail`：工作令账面成本凭证明细。
- 外网测试库已重灌，关键记录数：
  - `cost_source_project_tree = 8`
  - `cost_model_node = 20`
  - `cost_project = 8`
  - `cost_unit_dict = 21`
  - `cost_project_basic = 10`
  - `cost_work_order = 26`
  - `cost_work_order_project_ref = 10`
  - `cost_work_order_ledger_detail = 16`
  - `cost_unit_cost_detail = 29`
  - `cost_import_batch = 5`
  - `cost_warning_record = 6`
- 测试数据已覆盖 4 条待分配工作令样本：`product_short_name` 分别为 `NULL`、空字符串和 `待分配`，覆盖多个项目、单位和正常/超支场景。
- 注意：最新后端部署脚本 `sql/mysql/costree-cost.sql`、`sql/postgresql/costree-cost.sql` 当前是 10 张表口径，未包含 `cost_source_project_tree`、`cost_work_order_project_ref`；内网导入前需按新方案决定补齐源表或使用内网原表/视图。
- 已确认第一张内网主业项目树原表名为 `sc_8001_cw.ads_lc_lshsxm2022`，表注释为“分析层项目”；截图可读字段已进入 `30-data/06-内网原表-主业项目树-ads_lc_lshsxm2022.md`，仍需正式 DDL 和样例数据复核。
- 已确认第二张内网工作令映射原表名为 `dwd_bd_bfcustomitem_gzl`，表注释为“明细层工作令项目”；截图可读字段已进入 `30-data/07-内网原表-工作令关联主业项目字典-dwd_bd_bfcustomitem_gzl.md`，仍需正式 DDL、schema 名称、年度来源和样例数据复核。
- 已确认第三张内网账面明细原表名为 `sc_8001_fidw.dws_bu_pz_pzmx_gzl`，表注释为“工作令凭证明细”；截图可读字段已进入 `30-data/08-内网原表-项目工作令账面成本明细-dws_bu_pz_pzmx_gzl.md`，仍需正式 DDL、金额单位、借贷方向、关联键和样例数据复核。

### 后端

后端仓库：

`<backend-root>`

已完成：

- 新增并持续完善 `yudao-module-cost`。
- `cost-server` 可独立启动。
- 已实现成本项目、项目基本情况、工作令基础信息、总体展示聚合、单位字典等接口。
- 已实现项目基本情况和工作令基础信息的导入模板、导入、导出。
- 已实现轻流程状态接口：提交、确认通过、退回；当前不接正式 BPM，只用业务表 `status` 字段。
- `GET /cost/overview/unit-detail` 已支持 `projectCode` 和 `stageCodes` 过滤，用于成本树详情页按项目和阶段取真实成本组成数据。
- 已新增单位字典只读接口 `GET /cost/unit-dict/list`。
- 已新增工作令账面明细聚合接口 `GET /cost/work-order-ledger/summary`，按项目、单位、工作令、阶段聚合 `cost_work_order_ledger_detail.amount_wan`。
- `GET /cost/work-order/page` 已支持 `keyword` 和 `projectCodes`，用于目录页按筛选范围后端分页查询工作令。
- `GET /cost/work-order-ledger/summary` 已支持 `workOrderNos`，用于只对当前页工作令补账面成本汇总。
- `GET /cost/work-order/page` 已支持 `pendingAllocation=true`，用于只查询产品简称为空或待分配的工作令。
- 已新增待分配池接口 `GET /cost/work-order/pending-allocation/summary` 和 `GET /cost/work-order/pending-allocation/unit-detail`，复用工作令查询权限并支持单位穿透。
- 已新增预警中心接口 `GET /cost/warning/page`、`POST /cost/warning/resend`、`POST /cost/warning/mark-handled`。
- 预警查询第一版按工作令目标成本和账面明细实时计算，`cost_warning_record` 只覆盖推送/处理状态。
- 待分配池明细已改为 `cost_work_order` 数据库分页，只对当前页工作令聚合账面明细；汇总接口已改为按单位 SQL 聚合。
- 预警中心分页已改为 SQL 实时计算和数据库分页，不再拉取全部工作令和全部账面聚合后在 Java 内存过滤分页。
- 总体展示 `summary` 和 `unit-detail` 已改为 SQL `GROUP BY` 聚合，返回字段保持不变。
- 项目基本情况和工作令基础信息同步导出已增加 5000 行上限保护，超过时提示缩小筛选范围。
- `application-jt.yml` 已调整为默认使用与网关一致的 Nacos 账号口径，并默认启用 Nacos discovery，便于 `cost-server` 注册到 Nacos 后被网关发现。
- 已新增工作令账面组成接口，用于单位工作令页穿透查看账面科目 Top8 饼图和明细列表。
- 已为 `cost_work_order` 补充内网源字段，并新增 MySQL/PostgreSQL 成本模块建表与测试 seed 脚本。
- 已补充 PostgreSQL JDBC 依赖，并调整成本模块手写 SQL 兼容 PostgreSQL。
- 2026-07-22 已建立 PostgreSQL 结构版本 `20260722` 和旧库统一迁移包：迁移前检查、单事务升级、升级后强校验、交付包 SHA-256 清单；空库继续使用最新 `costree-cost.sql`。

最近后端 commit：

- `976e511c feat(cost): add deployment ddl and ledger composition`
- `3ab3ccb8 perf(cost): page and aggregate backend queries`
- `254ec08b feat(cost): add pending allocation work order api`
- `6574e231 fix(cost): enable jt nacos discovery`
- `983807e feat(cost): support paged work order filters`
- `bc2269c feat(cost): add warning center api`
- `6bdabb4 feat(cost): add work order ledger summary api`
- `78180f8 feat(cost): add unit dictionary api`
- `0c3bfc0 feat(cost): filter overview details by project stage`
- `be0c3df feat(cost): add collection status workflow`

### 前端

前端仓库：

`<frontend-root>`

已完成页面/入口：

- `/cost/index`：成本库总体展示页。
- `/cost/catalog`：成本库目录树页。
- `/cost/project-detail?projectCode=xxx`：项目详情页。
- `/cost/tree-detail?projectCode=xxx`：单项目成本树详情页。
- `/cost/tree-unit-detail?...`：单位详情页。
- `/cost/collect`：数据采集前台页。
- `/cost/pending-allocation`：待分配池页。
- `/cost/warning`：预警中心页。
- `/cost/back/project-basic`：项目基本情况后台维护页。
- `/cost/back/work-order`：工作令基础信息后台维护页。

近期前端改动：

- 总体展示页已形成“四领域 + 八院合计 + 饼图”的驾驶舱布局。
- 成本树详情页已改为“型号 -> 单位”，主页面不再展示第三层工作令。
- 院内单位点击进入工作令展开详情；院外单位点击进入院外单位信息汇总。
- 目录树页左侧已改为“领 / 系 / 型”彩色单字层级标识。
- 目录树页项目区保留表格展示，同时新增“列表 / 卡片”切换；切换偏好存 `localStorage`。
- 目录树页工作令明细表已调整高度并显式开启表体滚动。
- 目录树页工作令明细已从前端本地分页升级为后端分页，只加载当前页工作令；账面成本聚合也只请求当前页 `workOrderNo` 集合。
- 成本库 Vite 代理已改为默认不注入 `login-user`，避免覆盖业务中台真实登录用户、角色、租户和数据权限。
- 顶部导航已新增“待分配池”入口；工作令填报页产品简称字段支持选择或输入 `待分配`。
- 待分配池页面已接入汇总、后端分页明细和单位抽屉穿透，不一次性全量加载待分配工作令。
- `src/main.ts` 已恢复应用初始化失败日志输出，方便定位运行期真实错误。
- 项目详情、目录树、成本树详情、单位详情已接入工作令账面明细聚合：有 `ledgerBookCostAmount` 时优先使用，无明细时保留 `bookCostAmount` 兜底。
- 预警中心已接入工作令实时超支计算，支持筛选、进入成本树、重新推送、标记已处理。
- 本轮清理了一批非成本页面里误引入的 `dist-prod/assets/...`、`element-plus/es/locale`、`element-plus/es/utils` 等无效依赖，修复 Vite 启动时报 unresolved import 导致成本库页面无法加载的问题。
- 本轮修正 `src/main.ts` 初始化失败日志调用，移除不存在的 `Logger.error` 调用，保留 `console.error` 输出真实运行错误。
- 成本树详情和单位工作令页已按 `book / target >= 80%` 黄色、`book > target` 红色的账面预警口径展示卡片边框、账面金额、执行率和进度状态。
- `/cost/catalog` 默认卡片视图，`/cost/tree-unit-detail` 默认树状卡片视图；仍保留用户手动切换后的本地偏好。
- 单位工作令页已新增“查阅超支详情”入口，展示工作令账面组成饼图和 Top8 科目明细。
- `/cost/collect` 已修复左侧内容超屏不可滚动问题，周期字段保持年月口径。

最近前端 commit：

- `0b657d1 feat(cost): add cost warnings and ledger drilldown`
- `a9b94d1 feat(cost): add pending allocation page`
- `8c7d21b fix(cost): log app setup failures`
- `f4fb85f fix(cost): gate local mock login proxy`
- `57d12ba feat(cost): load catalog work orders by page`
- `4dfcdff feat(cost): paginate catalog work orders`
- `cf814f1 fix(cost): allow catalog page scrolling`
- `2ae7f35 feat(cost): add warning center page`
- `97f3362 feat(cost): use ledger summary for book cost`
- `6ff44a5 feat(cost): improve catalog tree and project card view`
- `b7210a5 feat(cost): add unit detail tree drilldown`
- `b3dad7b feat(cost): update tree detail unit stage view`

### 验证

最近通过的常用验证：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
mvn -pl yudao-module-cost/yudao-module-cost-biz -am -DskipTests compile
```

本轮后端分页与聚合风险治理额外验证：

- 外网 MySQL `costree_mvp` 直连验证等价 SQL：待分配汇总 4 个单位、预警实时超支计数 15、总体展示 4 个领域。
- `git diff --check` 通过，仅提示 Windows 换行转换警告。

2026-06-12 本轮运行链路和页面复核：

- 后端 `mvn -pl yudao-module-cost/yudao-module-cost-biz -am -DskipTests compile` 通过。
- 前端 `pnpm run ts:check:cost` 通过。
- 前端本轮触达文件 ESLint 通过，结果为 0 errors、10 warnings；警告来自既有 `vue/first-attribute-linebreak` 和 `src/main.ts` ignore pattern。
- 前端和后端 `git diff --check` 通过。
- 本地前端以 `VITE_BASE_URL=http://127.0.0.1:38080`、不启用 `VITE_COST_MOCK_LOGIN` 启动，访问 `http://localhost:5173/`。
- `/cost/pending-allocation` 已复核：页面显示 4 条待分配工作令、4 个涉及单位、目标成本 2,700.00、账面成本 3,000.00、超阈值预警 2；单位抽屉可打开并展示 `上海神添实业有限公司` 的 `WO-SP-001-03` 明细。
- `/cost/warning` 已复核：页面显示预警总数 15、超阈值 6、待推送/失败 8、已处理 0，预警列表和操作入口可见。
- `/cost/catalog` 已复核：页面显示 4 个领域/系列/型号树、当前范围 8 个项目、26 条工作令、本页目标成本 12,100.00、本页预警 3 条；列表/卡片切换可用。

局部类型检查入口：

- 前端配置：`<frontend-root>/tsconfig.cost.json`
- 脚本：`pnpm run ts:check:cost`
- 2026-06-18 前后端最新基线已分别提交并推送：前端 `0b657d1` 到 `codeup/feature/costree2`，后端 `976e511c` 到 `codeup/feature/costree`。

## 3. 未完成事项

### 前端页面

- `/cost/analysis` 统计分析第一版尚未迁移。
- `/cost/index` 总体展示页仍有业务口径待确认，例如“结余率”“数据数量”的准确含义。
- `/cost/collect` 数据采集前台页仍是轻流程版本，后续需要按真实角色、权限、审批流程继续收敛。
- 项目基本情况表、工作令基础信息表后续还要按项目办/研制单位页面拆分和权限边界继续优化。

### 后端与数据

- 新增源数据表后，后端暂未实现对应同步/导入/查询接口。
- 账面成本已具备工作令级聚合接口和前端优先读取能力，但导入/同步 `cost_work_order_ledger_detail` 的正式流程尚未实现。
- 总体展示、院外单位汇总仍有部分口径来自 `cost_unit_cost_detail.book_cost_amount`，后续需和账面明细表统一口径【需确认】。
- 源主业项目树到 `cost_model_node` / `cost_project` 的转换规则未实现。
- 内网原表 `ads_lc_lshsxm2022` 到标准源表 `cost_source_project_tree` 的字段映射尚未定稿，尤其是父节点字段、领域来源、项目类别/系列来源。
- 工作令关联主业项目字典到 `cost_work_order` 的同步规则未实现。
- 内网原表 `dwd_bd_bfcustomitem_gzl` 到标准源表 `cost_work_order_project_ref` 的字段映射尚未定稿，尤其是年度来源、`zyxmid` 与主业项目树的关联键、停用/完工字段取值。
- 内网原表 `dws_bu_pz_pzmx_gzl` 到标准明细表 `cost_work_order_ledger_detail` 的字段映射尚未定稿，尤其是 `ysnm/id` 唯一键、`gzlnm/gzllb` 工作令关联键、`je` 金额单位、`jzfx` 正负规则和 `lastmodifiedtime/dwts` 增量字段。
- 源表导入后的解析任务和未解析数据查询未实现，包括项目树解析、工作令映射解析、账面明细 `project_id/work_order_id/resolved_stage_code` 回填。
- 预警推送目前仍是 MVP 口径，只记录推送状态；正式接中台消息推送、接收人规则、失败原因回填待完善。
- 待分配池当前只做展示和穿透，不做认领/分配/关闭流程；如业务提出操作闭环，需要新增状态流转设计【需确认】。
- 大批量导出当前只做同步 5000 行保护；如业务需要超过上限的导出，应新增异步导出任务和下载中心【需确认】。

### 权限与部署

- 前端当前仍有静态路由接入，内网正式环境需要配置中台菜单、角色、按钮权限。
- 数据权限仍需与真实组织、部门、项目办、研制单位映射。
- 内网真实部署时不能执行 `seed-mvp.sql`。

## 4. 当前阻塞

- `/cost/pending-allocation`、`/cost/warning`、`/cost/catalog` 本地页面复核已完成，当前不再阻塞 `/cost/analysis` 第一版迁移。
- 业务方字段仍有关键口径未确认：
  - `je` 金额单位是元、万元还是其他。
  - 借贷方向和冲销金额是否按正负数直接汇总。
  - 工作令映射变更后，历史凭证明细按原映射追溯还是按当前映射重算。
  - “预分预控金额”是否等同目标成本。
  - “院本级支出”的判断规则。
- 内网真实 PostgreSQL、Redis、Nacos、网关、菜单权限配置仍待内网环境确认；数据库要求 PostgreSQL 14+，上线前必须执行结构版本验收。
- 内网源表承接方式仍待确认：补齐成本库源表，或用内网原表/视图映射为成本库源表。
- `ads_lc_lshsxm2022` 只从截图整理了字段注释，还缺完整 DDL、字段取值样例、父子关系样例和更新时间字段确认。
- `dwd_bd_bfcustomitem_gzl` 只从截图整理了字段注释，还缺完整 DDL、schema 名称、年度字段来源、字段取值样例和与主业项目树的关联校验。
- `dws_bu_pz_pzmx_gzl` 只从截图整理了字段注释，还缺完整 DDL、字段取值样例、金额单位、借贷方向、唯一键、增量字段和与工作令/主业项目树的关联校验。
- 当前本地 Nacos 服务发现链路已复核：`38108` 健康检查返回 `UP`，经 `38080` 未带登录态直接调成本库接口返回 `401 账号未登录`，说明网关已能发现 `cost-server`；通过前端已登录页面访问成本库页面可正常渲染数据。
- 当前仓库状态注意：
  - 前端仓库 `<frontend-root>` 最新成本预警与组成穿透基线已提交并推送。
  - 后端仓库 `<backend-root>` 最新部署 SQL、PostgreSQL 兼容和账面组成接口基线已提交并推送。
  - 文档仓库 `<costree-root>` 当前正在进行路径可迁移口径更新，提交前需检查 `git status --short`。

## 5. 关键设计决策

- Figma 生成的 React/Vite 原型只作为页面和交互参考，最终按数据中台 Vue3 实现。
- 成本库后端采用独立 `cost-server` 服务，不和已有中台后端强行合并。
- 成本库后端模块命名为 `yudao-module-cost`。
- 前端成本库页面集中放在 `src/views/cost/...`，API 放在 `src/api/cost/...`。
- 前台门户和后台管理拆分：
  - 前台：总体展示、目录树、项目详情、成本树详情、数据采集。
  - 后台：项目基本情况、工作令基础信息等维护页。
- 业务方参考表按“源数据表”保存，不直接替换成本库业务表。
- 内网源数据采用“源数据层 -> 业务维护层 -> 展示/聚合层”的三层口径：源表不直接替代页面业务表，需解析生成或更新 `cost_model_node`、`cost_project`、`cost_work_order`。
- 当前不建每日汇总表；总体展示优先走真实实时聚合。后续如性能压力明显，再考虑快照/汇总表。
- 成本树详情页主树层级定为“型号 -> 单位”，工作令不在主树第三层展示，而在单位详情页展示。
- 院内/院外判断以 `cost_unit_dict.inside_institute` 为当前依据。
- 待分配池判定以 `cost_work_order.product_short_name` 为准：`NULL`、空字符串或 `待分配`；当前不新增独立状态字段和汇总表。
- 预警中心第一版不维护每日预警快照；查询时实时计算，`cost_warning_record` 只保存推送/处理状态。
- 外网测试数据统一使用 `tenant_id = 124`，贴近内网真实租户，避免再出现租户越权误解。
- 内网真实环境必须关闭本地平台 mock，不能使用外网开发代理和模拟登录头作为正式方案。
- 前端 `login-user` 模拟头只允许在 `VITE_COST_MOCK_LOGIN=true` 的独立 `cost-server` 调试模式下启用；嵌入业务中台开发和权限验收必须使用真实登录态。
- Nacos 在成本库链路中作为服务注册/发现入口，网关通过服务名 `cost-server` 查找后端实例。
- Redis 只作为缓存和中台基础设施，不保存成本库正式业务主数据。
- 成本库按模块化边界开发：默认只修改成本库/成本树相关文件；必须触碰其他模块时先通知用户，并在文档中写清修改原因、影响范围、是否临时和回归方式。
- 当前操作指南和协作文档默认使用 `<costree-root>`、`<frontend-root>`、`<backend-root>` 与相对路径，不写死本机盘符。

## 6. 下一步最小任务

建议下一步最小任务优先围绕内网部署验证；如果部署链路已经确认，再进入统计分析第一版：

0. 每轮开发前先按 `00-overview/05-长期项目文档与工程经验沉淀模式.md` 做 5 分钟恢复：读 `.agent-handoff/CURRENT.md`、`README.md`、`PROJECT_STATE.md`、`PLAN.md` 和本轮相关专题文档。
1. 先读 `30-data/09-成本库内网数据对接总设计方案.md`，统一理解 `cost_model_node`、`cost_project`、工作令映射、账面明细和页面取数之间的关系。
2. 再按 `30-data/05-内网源表与成本库业务表关系实施方案.md` 确认源表承接方式：补齐成本库源表，或使用内网原表/视图。
3. 先补齐 `ads_lc_lshsxm2022` 的完整 DDL 和 20 至 50 行样例，确认 `lshsxm_xmnm`、父节点字段、`lshsxm_js`、`lshsxm_xmlx`、`disabled` 等字段含义。
4. 补齐 `dwd_bd_bfcustomitem_gzl` 的完整 DDL 和 20 至 50 行样例，确认 `id/cusitemcode/accountorgcode/zyxmid`、年度来源、停用/完工字段和增量时间字段。
5. 补齐 `dws_bu_pz_pzmx_gzl` 的完整 DDL 和 20 至 50 行样例，确认 `ysnm/id`、`gzlnm/gzllb/dwbh`、`xmnm/xmbh`、`je`、`jzfx`、`lastmodifiedtime/dwts` 的正式口径。
6. 在内网或本地 PostgreSQL/MySQL 目标库执行对应建表脚本，测试环境可选执行 seed，正式真实库不执行 seed。
7. 按“单位字典 -> 主业项目树 -> 解析项目树 -> 工作令映射 -> 解析工作令 -> 项目/工作令填报数据 -> 账面明细 -> 解析账面明细”的顺序做首轮导入验证。
8. 使用离线包或最新 jar 配置外部 `application-jt.yml`，确认 `cost-server` 注册到 Nacos，经网关访问 `/admin-api/cost/**` 返回预期登录态或业务数据。
9. 用真实登录态复核 `/cost/catalog`、`/cost/tree-detail`、`/cost/tree-unit-detail`、`/cost/collect` 的数据、预警颜色和工作令组成穿透。
10. 部署链路确认后，再开始迁移原型 `DataAnalysis.tsx` 为 `/cost/analysis`，先做统计概览和 Excel 导出入口，不做 Word 报告。
11. 页面或接口开发完成后运行 `pnpm run ts:check:cost`、成本库相关 ESLint、后端 `mvn -pl yudao-module-cost/yudao-module-cost-biz -am -DskipTests compile`，并同步更新 `PROJECT_STATE.md`、`PLAN.md`、`90-logs/02-变更日志.md` 和 `.agent-handoff`。
