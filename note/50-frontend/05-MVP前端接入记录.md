# MVP 前端接入记录

状态：进行中

## 2026-05-17 接入范围

本轮先接入项目基本情况和工作令基础信息两个 Vue3 页面，不直接复用 Figma 生成的 React 代码。

前端仓库：

`<frontend-root>`

## 已新增文件

| 文件 | 说明 |
|---|---|
| `src\api\cost\projectBasic\index.ts` | 项目基本情况分页、导出、模板下载 API |
| `src\api\cost\workOrder\index.ts` | 工作令基础信息分页、导出、模板下载 API |
| `src\api\cost\importResult.ts` | 导入结果和错误明细类型 |
| `src\views\cost\components\CostImportDialog.vue` | 通用成本库导入弹窗，上传后展示批次结果和错误行 |
| `src\views\cost\projectBasic\index.vue` | 项目基本情况列表、查询、导入、导出 |
| `src\views\cost\workOrder\index.vue` | 工作令基础信息列表、查询、导入、导出 |

## 已修改文件

| 文件 | 说明 |
|---|---|
| `src\router\modules\remaining.ts` | 临时新增 `/cost` 静态路由，包含“项目基本情况”和“工作令基础信息”两个页面 |

## 页面能力

### 项目基本情况

- 查询条件：项目编号、分系统、承研单位、阶段、状态。
- 表格列：项目编号、项目名称、分系统/产品配套、用户、获取方式、平台/系列、承研单位、目标价格、合同金额、目标成本、审定金额、周期、阶段、状态、创建时间。
- 操作：导入、导出。
- 权限点：`cost:project-basic:import`、`cost:project-basic:export`。

### 工作令基础信息

- 查询条件：项目编号、工作令编号、工作令名称、单位名称、状态。
- 表格列：项目编号、项目名称、单位名称、工作令编号、工作令名称、目标成本、账面成本、审定金额、阶段集合、最高阶段、所属分系统、产品简称、配套数量、纵向分工、状态、创建时间。
- 操作：导入、导出。
- 权限点：`cost:work-order:import`、`cost:work-order:export`。

## 导入结果展示

导入弹窗上传成功后直接展示后端返回的 `CostImportResultRespVO`：

- `batchId`：导入批次编号。
- `totalCount`：总行数。
- `successCount`：成功行数。
- `failureCount`：失败行数。
- `status`：`SUCCESS`、`PART_SUCCESS`、`FAILED`。
- `errors`：逐行错误明细，包含行号、字段、错误原因、原始数据。

## 当前接入口径

- 页面先使用静态路由接入，便于外网开发和后续合并。
- 正式内网接入时，仍应补后端菜单数据、角色授权和按钮权限配置。
- 列表、导入、导出接口路径统一走 `/admin-api/cost/...`。
- 前端请求代码中保留 Controller 内部路径 `/cost/...`，由中台请求封装和 `VITE_API_URL=/admin-api` 组合成实际访问路径。

## 已验证

在 `<frontend-root>` 执行：

```powershell
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" --ext .ts,.vue
```

结果：通过。

已用 `@vue/compiler-sfc` 对以下文件做 SFC parse / script / template 编译检查：

- `src\views\cost\components\CostImportDialog.vue`
- `src\views\cost\projectBasic\index.vue`
- `src\views\cost\workOrder\index.vue`

结果：通过。

## 当前限制

- `pnpm run build:dev` 本轮执行 3 分钟未完成，被超时终止；未生成 `dist`，也未修改依赖文件。
- 当前静态 `/cost` 路由仍受中台登录守卫控制，必须登录后访问。
- 外网只启动 `cost-server`、不启动 `system-server` 时，前端登录、用户信息、字典加载会受阻；不建议在本轮直接修改生产登录守卫做免登录。
- 如要做纯外网前后端联调，建议下一步单独增加“仅 cost-local 模式生效”的前端联调方案，并明确不能带入内网生产环境。

## 下一步建议

1. 确认是否允许新增 `cost-local` 前端模式，用于外网单服务页面联调。
2. 若允许，设计 dev-only 的登录态、租户、`login-user` 头注入方案，并单独提交。
3. 完成成本项目入口页后，再把当前两个维护页从静态路由逐步迁到正式菜单权限体系。

## 2026-05-17 入口与本地代理补充

- 首页 `src\views\HomeIndex\index.vue` 新增“成本树平台”入口卡片，点击跳转 `/cost/project-basic`。
- `vite.config.ts` 曾新增开发期 `/admin-api/cost/**` 专用代理，用于外网单独启动 `cost-server` 时绕过网关直连后端；当前默认代理策略已在 2026-06-02 调整，见下方记录。
- 本地联调用 `login-user` 与默认 `tenant-id=124` 只能用于显式开启 mock 的 `cost-server` 独立调试模式，不再作为成本库默认开发代理行为。
- `src\views\cost\components\CostImportDialog.vue` 上传地址改为相对 `/admin-api`，避免导入上传绕过 Vite 代理。
- 已验证 `GET http://localhost:82/admin-api/cost/project-basic/page?pageNo=1&pageSize=2` 不带 `login-user` 时经前端代理返回 `code=0`。
- 如当前前端进程已启动，修改 Vite 代理后必须重启前端 dev server 才会生效。

## 2026-05-17 租户越权问题修复

- 现象：登录平台后访问成本库页面，后端日志出现 `User(1/2) 越权访问租户(124)`，前端提示“您无权访问该租户的数据”。
- 原因：外网开发期 `/admin-api/cost/**` 代理只补了本地模拟 `login-user.tenantId=1`，但保留了平台登录态带来的真实 `tenant-id=124`，导致同一个请求中“登录用户租户”和“请求租户”不一致。
- 修复：`vite.config.ts` 中成本库开发代理曾改为强制覆盖 `tenant-id` 和 `login-user`，两者统一使用 `VITE_COST_LOCAL_TENANT_ID`，默认 `124`。
- 注意：这是外网单独启动 `cost-server` 的历史本地联调口径。2026-06-02 起默认不再注入模拟登录头，内网和嵌入中台开发应通过真实登录态访问。

## 2026-05-17 测试租户改为 124

- 为避免外网测试租户 `1` 和内网真实租户 `124` 混淆，成本库本地联调默认租户统一改为 `124`。
- `seed-mvp.sql` 新增 `@cost_tenant_id := 124`，后续重新初始化测试数据时默认写入 `tenant_id=124`。
- 已新增 `30-data/update-tenant-id-124.sql`，用于把既有测试库数据从 `tenant_id=1` 迁移到 `tenant_id=124`。
- 外网 MySQL `costree_mvp` 已完成迁移：7 张成本表均只剩 `tenant_id=124` 数据。
- 已验证通过前端代理和直连 `cost-server:48108` 查询项目基本情况、工作令基础信息均返回正常数据。

## 2026-05-17 前台门户与后台管理拆分

- 新增长期执行清单 `50-frontend/06-前台门户与后台管理执行清单.md`。
- 新增前台门户路由 `/cost/index`，用于承接原型 `Overview.tsx` 的汇总展示页。
- 新增前台目录路由 `/cost/catalog`，用于承接领域-系列-型号选择、项目列表和后续项目详情入口。
- 现有维护页从 `/cost/project-basic`、`/cost/work-order` 迁移到 `/cost/back/project-basic`、`/cost/back/work-order`。
- 旧路由保留兼容跳转，避免已发给业务或同事的旧地址直接 404。
- 首页“成本树平台”入口改为跳转 `/cost/index`，与数据资源门户 `/dataresource/index` 的前台入口口径一致。
- 本轮前台页面暂复用已有成本项目、项目基本情况、工作令、型号树接口做轻量统计，不新增后端 dashboard 聚合接口。
- 已执行局部 ESLint：`src/api/cost/**/*.ts`、`src/views/cost/**/*.vue`、`src/router/modules/remaining.ts`、`src/views/HomeIndex/index.vue` 均通过。
- 已执行新增 SFC 编译检查：`CostPortalHeader.vue`、`overview/index.vue`、`catalog/index.vue` 均通过 parse/script/template 编译。
- 已通过 Vite HTTP 模块请求确认新增页面和 API 文件返回 `200`。
- 已通过前端代理确认成本项目、项目基本情况、工作令、型号树接口返回正常数据，样本数量分别为 8、10、15、4。
- 全仓 `vue-tsc --noEmit` 本轮因 Node 堆内存不足失败；即使加到 8GB 仍 OOM，未得到有效类型错误列表。
- 内置浏览器插件本轮初始化失败，提示本地浏览器运行时资产路径缺失；因此 `/cost/index`、`/cost/catalog` 的真实视觉截图仍需人工或后续浏览器环境恢复后复核。

## 2026-05-17 成本库局部类型检查

为避免全仓 `vue-tsc --noEmit` 因项目体量过大 OOM，前端仓库新增长期维护的成本库局部类型检查入口：

- 配置文件：`tsconfig.cost.json`
- 执行脚本：`pnpm run ts:check:cost`
- 检查范围：成本库 API、成本库页面、成本库静态路由接入、首页成本库入口，以及必要的全局类型。
- 不纳入 `src/types/auto-components.d.ts`，避免自动组件声明把无关组件和本地日志文件拖入类型检查。
- 局部检查专用 `types/cost-*.d.ts` 只服务于类型检查，不参与运行时打包；主要用于把 axios、全局组件、非成本页面等重依赖替换成轻量类型。

本轮已执行：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

结果：均通过，未出现 OOM。

后续每次修改成本库前端、成本库路由或首页入口时，应把上述两条命令作为标准验收项。若局部类型错误来自新增成本库代码，直接修复；若来自既有公共依赖，应记录为“既有全局类型问题”，不要在同一轮扩大治理全仓类型问题。

## 2026-05-22 目录树页面展示优化

- `/cost/catalog` 左侧领域-系列-型号树改为彩色单字层级标识：
  - 领域：`领`，蓝色。
  - 系列：`系`，紫色。
  - 型号：`型`，绿色。
- 项目区域保留原表格行展示，并新增“列表 / 卡片”切换；用户选择会写入 `localStorage`，下次进入保持偏好。
- 卡片模式展示项目名称、编号、所属领域、系列/类别、批次/项目、阶段、承研单位和填报状态，保留收藏、项目详情、成本树入口。
- 工作令明细表高度从 300 调整为 360，并显式开启表体纵向滚动。

已执行：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

结果：均通过。

## 2026-05-17 总体展示按领域实时聚合迁移

- 新增后端接口组 `/cost/overview`，前端新增 `src\api\cost\overview\index.ts`。
- `/cost/index` 不再使用项目、工作令分页接口在前端拼轻量统计，改为调用 `GET /cost/overview/summary`。
- 新增 `src\views\cost\overview\DomainOverviewCard.vue`，按领域展示六边形指标、合同/到款/目标/账面指标和六类成本组成饼图。
- 饼图使用现有依赖 `echarts`，未引入 `recharts` 或其它新依赖。
- 新增 `src\views\cost\overview\UnitCostDetailDialog.vue`，点击“查看研制单位成本详情”后调用 `GET /cost/overview/unit-detail`，按领域展示研制单位成本明细，并支持单位名称搜索。
- 点击领域六边形跳转 `/cost/catalog?domainCode=xxx`，目录树页面已支持按 `domainCode` 查询参数筛选项目和工作令。

本轮数据口径：

- 总体展示数据来源为 `cost_unit_cost_detail`。
- 后端实时按 `domain_code` 聚合领域总览，按 `domain_code + unit_name` 聚合研制单位详情。
- `totalCostAmount = salary + material + outsource + manage + fuelPower + other`。
- `executionRate = bookCostAmount / targetCostAmount`。
- `receivedRate = incomeAmount / contractAmount`。

## 2026-05-17 总体展示视觉对齐原型

- 按 `ui-ux-pro-max` 的企业级 dashboard UX 检查项复核页面，保留信息密度、可扫描指标、图表表格互补和响应式要求；未采用其默认给出的营销化紫色活动风。
- `/cost/index` 页面结构改回更接近原型 `Overview.tsx`：
  - 顶部标题行使用左侧蓝色标记和“总体展示”标题。
  - 领域区域采用 2x2 卡片布局，大屏每行两个领域。
  - 领域卡片左侧恢复白底描边六边形，合同金额、到款率、到款金额、账面金额、执行率、目标金额围绕六边形展示。
  - 领域卡片右侧展示成本组成饼图、图例和“查看研制单位成本详情”入口。
  - 底部“成本树型号项目数据采集”快捷入口已在后续交互修正中移除，总体展示页不再承接数据采集入口。
- 仍使用真实接口 `/cost/overview/summary` 和 `/cost/overview/unit-detail`，没有回退到原型假数据。

## 2026-05-17 总体展示交互修正

- 移除 `/cost/index` 底部“成本树型号项目数据采集”快捷入口，总体展示页只保留四大领域指标总览。
- 修正领域卡片点击口径：
  - 点击六边形：进入 `/cost/catalog?domainCode=xxx`；
  - 点击饼图或“成本组成占比”标题：打开成本组成详情弹窗；
  - 点击“查看研制单位成本详情”：打开研制单位成本明细表。
- 新增 `src\views\cost\overview\CompositionDetailDialog.vue`，按原型样式展示环形图和成本组成占比列表。
- 当前已有的数据采集能力是后台维护页：
  - `/cost/back/project-basic`：项目基本情况导入、导出、查询；
  - `/cost/back/work-order`：工作令基础信息导入、导出、查询。
- 原型中如果存在单独“成本树型号项目数据采集”前台页，目前尚未独立迁移；第一阶段先复用后台维护页承接数据采集。

本轮已执行：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

结果：均通过。

## 2026-05-17 领域六边形指标布局优化

- 按 `ui-ux-pro-max` 的 data-dense dashboard、可读性、响应式和焦点状态检查项，优化领域卡片左侧六边形指标区域。
- 设计口径：
  - 六边形只承载领域名称和进入目录的主入口；
  - 合同金额、到款率、目标金额、到款金额、执行率、账面金额作为外圈 KPI，不压在六边形边线上；
  - 桌面端使用左右安全轨道放置 KPI，避免指标文字和六边形描边重叠；
  - 移动端改为“六边形 + 两列 KPI 卡片”，避免小屏绝对定位挤压。
- 修改文件：`src\views\cost\overview\DomainOverviewCard.vue`。

本轮已执行：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

结果：均通过。

## 2026-05-17 目录页筛选与收藏增强

- `/cost/catalog` 新增独立筛选工具条，支持关键词、领域、系列、批次、阶段下拉筛选。
- 阶段筛选按 `cost_project.stageCodes` 拆分，当前外网测试枚举仍沿用 `M`、`C`、`S`、`D`、`Z`，正式含义【需确认】。
- 项目表新增星标收藏列，收藏状态保存在浏览器 `localStorage`，键名为 `cost:catalog:favoriteProjectCodes`。
- 新增“只看收藏”快速筛选和收藏数量提示；当前不新增后端收藏表，适合作为外网演示和个人浏览偏好。
- 工作令明细会跟随项目范围筛选；只有关键词筛选时，工作令仍按自身编号、名称、单位和项目字段匹配。

本轮已执行：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

结果：均通过。

## 2026-05-17 项目详情页迁移第一版

- 新增前台路由 `/cost/project-detail?projectCode=xxx`，用于从目录页项目列表进入单项目详情。
- 新增 `src\views\cost\projectDetail\index.vue`。
- `/cost/catalog` 项目列表操作区新增“项目详情”和“成本树”两个入口：
  - “项目详情”进入 `/cost/project-detail?projectCode=xxx`；
  - “成本树”进入 `/cost/tree-detail?projectCode=xxx`。
- 项目详情页第一版为前台只读聚合视图，不新增后端接口，复用真实数据：
  - `GET /cost/project/page` 获取锚定项目；
  - `GET /cost/project-basic/page` 获取项目基本情况；
  - `GET /cost/work-order/page` 获取工作令基础信息。
- 页面结构：
  - 顶部返回目录、查看成本树、维护项目基本情况、维护工作令；
  - 汇总条展示项目基本情况数量、工作令数量、目标成本、账面成本、执行率；
  - 左侧锚定项目信息；
  - 右侧 Tab 展示项目基本情况表和工作令基础信息表。
- 后台维护入口暂跳转到已有后台页，后续如需要更顺滑的单项目维护体验，可让后台维护页读取 `projectCode` 查询参数自动筛选。

本轮已执行：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

结果：均通过。

HTTP 入口检查：

- `http://localhost/cost/project-detail?projectCode=ZY-2026-LA-001` 返回 `200`。

## 2026-05-17 成本树详情页迁移第一版

- 新增前台路由 `/cost/tree-detail?projectCode=xxx`，对应原型 `CostTreeDetail.tsx` 的型号项目成本树详情页。
- 新增 `src\views\cost\treeDetail\index.vue` 和递归节点组件 `src\views\cost\treeDetail\CostTreeNode.vue`。
- `/cost/catalog` 项目列表新增“查看成本树”操作，点击后携带 `projectCode` 进入成本树详情页。
- 本版不新增后端表，先复用真实的 `cost_project` 和 `cost_work_order` 数据实时构树：
  - 根节点：型号/项目；
  - 第二层：按 `subsystemName` 聚合为系统；
  - 第三层：工作令作为产品节点；
  - 金额：目标成本取 `productTargetCost`，账面成本取 `bookCostAmount`，审定金额取 `approvedAmount`。
- 页面支持阶段筛选、节点展开/收起、缩放、节点详情面板和无数据状态。
- 图片导出按钮当前为占位提示，后续再接入真正的截图/导出能力。

本轮已执行：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

结果：均通过。

浏览器验证说明：

- `http://localhost/cost/tree-detail?projectCode=ZY-2026-LA-001` 前端入口返回 `200`。
- Codex 内置测试浏览器没有当前系统登录态，访问时被中台登录守卫重定向到 `/login`，因此本轮未形成已登录态视觉截图。

## 2026-05-18 前台数据采集轻流程第一版

- 新增前台路由 `/cost/collect`，用于承接“成本树型号项目数据采集”。
- `CostPortalHeader` 新增“数据采集”入口，点击进入 `/cost/collect`。
- 新增 `src\views\cost\collect\index.vue`，页面包含三个页签：
  - 项目办填报：维护 `cost_project_basic` 项目基本情况，支持保存草稿、提交确认、编辑草稿/退回记录；
  - 研制单位填报：维护 `cost_work_order` 工作令基础信息，支持保存草稿、提交确认、编辑草稿/退回记录；
  - 待确认：展示 `SUBMITTED` 状态的数据，支持确认通过和退回。
- 新增前端 API：
  - `createProjectBasic`、`updateProjectBasic`、`submitProjectBasic`、`approveProjectBasic`、`rejectProjectBasic`；
  - `createWorkOrder`、`updateWorkOrder`、`submitWorkOrder`、`approveWorkOrder`、`rejectWorkOrder`。
- 当前第一版不接完整 BPM，不新增流程实例表；状态仍保存在业务表 `status` 字段。
- 状态流转口径：
  - `DRAFT` / `REJECTED` 可提交为 `SUBMITTED`；
  - `SUBMITTED` 可确认通过为 `APPROVED`，或退回为 `REJECTED`；
  - `APPROVED` 第一版不允许继续编辑。
- 当前正式展示页尚未强制过滤 `APPROVED`，避免外网演示数据突然减少；后续切换正式口径时，应统一让汇总、项目详情和成本树只取通过数据【需确认】。

本轮已执行：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

结果：均通过。

## 2026-05-21 总体展示中心合计块

- `/cost/index` 在四个领域卡片中间新增“八院合计”展示块，其余领域卡片、饼图和研制单位详情交互保持不变。
- 新增 `src\views\cost\overview\AggregateOverviewPanel.vue`，只负责展示四领域合计指标，不发起接口请求。
- `src\views\cost\overview\index.vue` 将现有 `/cost/overview/summary` 返回的领域汇总数据组织成整体驾驶舱画布：
  - 中间为四个领域六边形围绕“八院合计”的集群；
  - 左侧上下展示第 1、3 个领域的成本组成饼图；
  - 右侧上下展示第 2、4 个领域的成本组成饼图。
- `src\views\cost\overview\DomainOverviewCard.vue` 新增 `full`、`hex`、`composition` 三种展示模式，使同一份领域数据可以拆成中心六边形和外侧饼图两种视觉块。
- 领域六边形、饼图和中心合计块新增紧凑展示模式，避免中心块作为独立整行切开页面，优先保证 1080p 高度下总体展示完整露出。
- 中心集群第二轮优化：
  - 放大领域六边形；
  - 将合同金额、到款率、目标金额、到款金额、执行率、账面金额收进六边形内部；
  - 八院合计金额改为与领域一致的整数金额格式，去掉 `.00 万` 和省略号截断；
  - 八院合计百分比改为整数百分比，与领域卡片保持一致。
- 中心集群第三轮优化：
  - 四个领域六边形外层尺寸同步放大，避免内部六边形溢出旧容器；
  - 领域指标按六边形六个方位贴近对应角位展示；
  - 领域名称允许换行展示，取消省略号截断；
  - 八院合计中心块缩小，减少对四个领域节点的视觉压迫；
  - 结余金额、结余率、成本合计改为竖向排列，避免横向遮挡下方领域六边形。
- 中心集群第四轮优化：
  - 四大领域指标点位改为参考“八院合计”的六点布局：到款率居上，执行率居下，合同/到款/目标/账面金额分布在左右角位；
  - 八院合计中心块从上一轮尺寸适当放大，重新强化中心主视觉；
  - 中心列宽和四领域节点间距同步调整，保证中心块位于四大领域之间，整体更接近对称布局。
- 中心集群第五轮优化：
  - 对八院合计块做右下视觉补偿，修正因底部竖排结余指标导致的中心六边形偏上、偏左观感；
  - 本轮只调整中心块定位，不改字段、接口和交互。
- 中心集群第六轮优化：
  - 修正分辨率变化后左右饼图与四大领域互相挤压的问题；
  - 三栏比例调整为左右饼图栏更稳定、中间集群栏不过度拉宽；
  - 四大领域节点从画布边缘响应式内收，避免高分辨率/窄视口下贴边或与饼图视觉重叠。
- 中心集群第七轮优化：
  - 在四大领域节点响应式内收后，取消八院合计块上一轮右下视觉补偿；
  - 八院合计块恢复为中间集群容器的几何中心定位。
- 中心集群第八轮优化：
  - 明确中心定位口径改为“四大领域围合区域的视觉中心”，不是中间集群容器的几何中心；
  - 八院合计块水平居中，垂直向下补偿，使八院六边形本体位于四大领域中间，底部结余指标自然挂在其下方。
- 中心集群第九轮优化：
  - 根据截图继续修正八院合计块偏左、偏上的观感；
  - 八院合计块改为相对中间集群中心水平右移、垂直下移，使其更接近四大领域围合空隙的视觉中心。
- 页面外层改为固定视口内滚动容器，低分辨率或窄屏下仍保留滚动兜底。
- 合计口径第一版由前端实时计算，不新增数据库表、不新增后端接口：
  - 合同金额：`sum(contractAmount)`；
  - 到款金额：`sum(incomeAmount)`；
  - 目标金额：`sum(targetCostAmount)`；
  - 账面金额：`sum(bookCostAmount)`；
  - 成本合计：`sum(totalCostAmount)`；
  - 到款率：`到款金额 / 合同金额`；
  - 执行率：`账面金额 / 目标金额`；
  - 结余金额：`到款金额 - 账面金额`；
  - 结余率：`结余金额 / 到款金额`【需确认】。
- “数据”当前按“领域数量”展示，若业务口径为项目数、工作令数或填报明细数，需要后续在接口返回对应计数字段【需确认】。

本轮已执行：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

结果：均通过。

HTTP 入口检查：

- `http://localhost/cost/index` 返回 `200`。

## 2026-05-22 成本树详情页阶段与单位视角

- `/cost/tree-detail?projectCode=xxx` 右上角阶段选择由单选改为多选，未选择阶段时表示“全部汇总”。
- 阶段顺序按领域默认区分：
  - 武器/导弹领域：`M/C/S/D`；
  - 运载、卫星、空间等宇航类领域：`M/C/Z`。
- 工作令阶段归集口径调整为“最终阶段”：
  - 优先取 `cost_work_order.max_stage_code`；
  - 没有最高阶段时按领域阶段顺序从 `stage_codes` 推断最后阶段。
- 成本树层级从“型号 -> 系统 -> 产品/工作令”调整为“型号 -> 单位 -> 工作令”：
  - 院内单位节点按 `cost_work_order.unit_name` 聚合；
  - 工作令节点展示工作令名称、工作令号、目标成本、账面成本和最终阶段；
  - 院外单位节点预留汇总展示，不展开工作令。
- 型号根节点新增阶段标签，切换阶段后根节点目标成本、账面成本、执行率同步变化。
- 型号右侧新增“项目成本组成”饼图入口，点击打开项目成本组成弹窗。
- 饼图数据复用 `cost_unit_cost_detail` 六类成本结构；后端 `GET /cost/overview/unit-detail` 新增 `projectCode` 和 `stageCodes` 过滤参数，支持按项目和阶段实时汇总。
- 新增设计记录：`50-frontend/07-成本树详情页阶段与单位视角设计.md`。

本轮已执行：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

结果：均通过。

后端编译：

```powershell
mvn -pl yudao-module-cost/yudao-module-cost-biz -am -DskipTests compile
```

结果：通过；Maven duplicate dependency 警告为既有项目警告。

HTTP 入口检查：

- `http://localhost/cost/tree-detail?projectCode=ZY-2026-LA-001` 返回 `200`。

## 2026-05-22 成本树详情页单位点击拆分

- `/cost/tree-detail?projectCode=xxx` 主成本树页面进一步收口为两层：型号根节点和单位节点，不再在主页面显示第三层工作令。
- 院内/院外判断改为读取单位字典接口 `GET /cost/unit-dict/list`：
  - `insideInstitute=true` 的单位作为院内单位；
  - `insideInstitute=false` 且存在项目成本结构数据的单位归入“院外单位汇总”。
- 新增 `/cost/tree-unit-detail` 隐藏路由：
  - 院内单位点击后展示该项目、该单位下的工作令展开列表；
  - 院外单位汇总点击后展示当前项目和阶段下所有院外单位信息，包含核算单位、管理单位、往来单位、集团内标识、合同、到款、目标和账面成本。
- 新增前端 API：`src/api/cost/unitDict/index.ts`。
- 外网测试数据同步扩充 `ZY-2026-LA-001`：
  - 多个院内单位；
  - M/C/Z 多阶段；
  - 多工作令；
  - 多个院外单位且无工作令，用于验证院外详情页。
- 已重灌外网 MySQL `costree_mvp`：
  - `cost_unit_dict` 21 条；
  - `cost_work_order` 22 条，其中 `ZY-2026-LA-001` 10 条；
  - `cost_unit_cost_detail` 29 条，其中 `ZY-2026-LA-001` 院外成本明细 4 条。

本轮验收仍使用成本库局部类型检查和局部 ESLint。

## 2026-05-22 工作令账面明细聚合接入

- 新增前端 API：`src\api\cost\workOrderLedger\index.ts`。
- 新增接口调用：`GET /cost/work-order-ledger/summary`。
- 新增合并策略 `mergeLedgerSummaryToWorkOrders`：
  - 工作令列表仍先读取 `GET /cost/work-order/page`；
  - 若账面明细聚合接口返回同一 `workOrderNo` 的 `ledgerBookCostAmount`，则覆盖前端使用的 `bookCostAmount`；
  - 若没有账面明细数据或接口暂不可用，则保留原 `cost_work_order.book_cost_amount` 测试字段。
- 已接入页面：
  - `/cost/catalog`：工作令明细表、预警计数和账面汇总；
  - `/cost/project-detail`：工作令页签、项目账面成本和执行率；
  - `/cost/tree-detail`：型号-单位成本树中的院内单位账面成本；
  - `/cost/tree-unit-detail`：院内单位工作令列表/树状视图。
- 院外单位汇总仍读取 `cost_unit_cost_detail.book_cost_amount`，因为院外单位当前没有工作令明细，后续若提供院外凭证明细再单独补口径【需确认】。
- 当前页面没有新增视觉结构，只替换账面成本数据来源，避免和前一轮目录树/成本树 UI 调整混在一起。

本轮已执行：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

结果：均通过。

## 2026-05-22 预警中心第一版

- 新增前台路由 `/cost/warning`，用于承接原型 `ProjectWarning.tsx` 的预警中心。
- `CostPortalHeader` 新增“预警中心”入口；头部导航从绝对定位按钮改为左侧横向导航组，避免新增入口后按钮重叠。
- 新增前端 API：`src\api\cost\warning\index.ts`。
- 新增页面：`src\views\cost\warning\index.vue`。
- 页面设计采用内部 data-dense dashboard 口径：
  - 顶部展示预警总数、超阈值、待推送/失败、已处理四个紧凑指标；
  - 中部筛选支持关键字、领域、等级、推送状态、处理状态；
  - 主体以表格为核心，展示项目/型号、工作令、责任单位、目标成本、账面成本、超支金额、超支比例、推送状态、处理状态；
  - 操作支持进入成本树、重新推送、标记已处理。
- 当前推送第一版只调用 `/cost/warning/resend` 更新推送状态，不调用中台真实消息中心。
- 当前标记处理只调用 `/cost/warning/mark-handled` 更新处理状态，不接正式整改/审批流程。

本轮已执行：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

结果：均通过。

## 2026-05-22 目录树页整页滚动修复

- 修复 `/cost/catalog` 在全局 `html/body { overflow: hidden; }` 下无法继续向下滚动的问题。
- 将目录页根容器从 `min-height: 100vh` 改为固定 `height: 100vh` 并由页面自身提供纵向滚动。
- 取消卡片视图 `.project-card-grid` 的内部最大高度和内部纵向滚动，避免卡片区截断页面，改为整页滚动优先。
- 左侧型号树和工作令明细表仍保留各自内部滚动，便于查看长树和长工作令列表。

本轮已执行：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

结果：均通过。

## 2026-05-22 工作令明细分页展示

- `/cost/catalog` 的“工作令明细”改为分页展示，默认每页 8 条。
- 分页器支持 8、10、20、50 条切换，并展示当前范围和总数。
- 搜索、筛选、切换左侧树节点、只看收藏时自动回到第一页，避免过滤后停留在空页。
- 该版本最初为前端本地分页，已在后续升级为后端分页接口，保留本段作为演进记录。

本轮已执行：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

结果：均通过。

## 2026-05-22 工作令明细后端分页接入

- `/cost/catalog` 不再通过 `getCostPortalSummary()` 一次性加载全部工作令。
- 工作令明细改为调用 `GET /cost/work-order/page`，使用后端分页返回当前页数据。
- 目录页筛选到领域、系列、型号、批次或收藏时，前端基于当前项目范围传入 `projectCodes`；关键词传入 `keyword`；阶段传入 `stageCode`。
- 账面成本聚合不再请求全部账面明细汇总，只把当前页工作令编号传给 `GET /cost/work-order-ledger/summary?workOrderNos=...`。
- 顶部“目标成本”和“预警”标签改为“本页目标成本”和“本页预警”，避免在后端分页下误表达为全范围合计。
- 当前项目列表仍保留前端筛选和列表/卡片切换；若后续项目数量明显增加，应继续把项目区域升级为后端分页或虚拟列表【需确认】。

本轮已执行：

```powershell
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

结果：均通过。

## 2026-06-02 成本库代理登录态修正

- 成本库长期按嵌入业务中台口径开发，默认必须复用中台真实 `Authorization`、租户、角色和数据权限。
- `vite.config.ts` 中 `/admin-api/cost/**` 代理目标为 `VITE_COST_BASE_URL || VITE_BASE_URL`；当前中台端口改为 `38080` 时，只需要配置 `VITE_BASE_URL='http://127.0.0.1:38080'`。
- 默认情况下成本库代理不再注入 `login-user`，也不覆盖 `tenant-id`，避免后端优先读取 `login-user` 导致真实登录用户和角色被固定测试用户覆盖。
- 只有外网单独启动 `cost-server` 调试时，才显式配置：

```env
VITE_COST_BASE_URL='http://127.0.0.1:48108'
VITE_COST_MOCK_LOGIN=true
VITE_COST_LOCAL_TENANT_ID=124
```

- 该独立调试模式只用于接口和页面功能联调，不作为角色权限、租户权限、数据权限验收依据。

## 2026-06-02 前端初始化错误日志恢复

- `src/main.ts` 恢复 `setupAll()` 初始化失败时的日志输出。
- 作用：当业务中台初始化、动态路由、登录态或成本库入口加载失败时，浏览器控制台能看到真实错误原因，避免只看到加载动画或页面空白。
- 该改动不改变业务逻辑，只改善本地排障能力。

后续排查页面加载失败时，优先看：

1. 浏览器 Console 中 `应用初始化失败` 后面的错误对象。
2. Network 中 `/admin-api/...` 请求是否 401、403、404、503。
3. 如果是成本库接口 503，继续按 Nacos / `cost-server` 注册链路排查。
