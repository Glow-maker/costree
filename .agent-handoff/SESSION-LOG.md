# 会话记录

## 一次会话
- 开始时间：2026-09-21 15:46:00 +0800
- 结束时间：2026-09-21 15:52:26 +0800
- 本次焦点：按base master现有连接更新jt达梦数据源并验证详情

### 本次进展
- 基于base运行JAR核对新DM地址和现有凭据。
- 备份后定向更新jt单条数据源；不修改共享记录或新增账号。
- 连接测试和数据详情API均成功，业务内容未输出。

### 涉及文件
- base:dataease_dev1.dmgt_data_source_config id1000002
- note/70-testing/20260921-dm-source-address/

### 下次恢复点
- 查看note/70-testing/20260921-dm-source-address/README.md；达梦1000002已可查询。其他数据源需逐一确认真实目标；缺字段索引记录需另行补齐，不能盲目把所有源改到同一个库。

### 风险与备注
- 其他数据源和缺字段索引项仍待处理；私有备份不得提交。

## 一次会话
- 开始时间：2026-09-21 16:02:00 +0800
- 结束时间：2026-09-21 16:35:10 +0800
- 本次焦点：新增SQLBot经营分析虚构业务表并完成复杂同源关联验收

### 本次进展
- 在base临时PG和MySQL副本中先演练脚本，六表、41字段、6关系和权限校验通过。
- 备份后部署到sqlbot_demo_dev1/dataease_dev1；合同15566040元、回款7039884元、未回款8526156元。
- 源1增量索引新增6表，语义增强后更新3表；41字段向量块存在，自动调度保持关闭。
- sqlbot1普通业务问法三表关联成功且与只读SQL一致；sqlbot2及账号361无新增授权。
- 八个dev-1组件状态检查通过，未重启应用服务。

### 涉及文件
- scripts/deploy-host2/sqlbot-business-demo/
- note/70-testing/20260921-sqlbot-business-demo/
- base:sqlbot_demo_dev1 public.demo_*
- base:dataease_dev1 JT-BIZ-*目录/字段/关系/权限
- base:sqlbot_dev1平台Embedding

### 下次恢复点
- 先读note/70-testing/20260921-sqlbot-business-demo/README.md。六表已部署并验证，无需重复建表；后续优先继续推荐问题或独立处理模型性能。

### 风险与备注
- 模型全流程50.617秒仍高于30秒目标；这不影响数据与权限正确性，但性能不能标记通过。
- 全量索引批次仍受其他既有无效数据源影响显示partial_failed；源1自身succeeded且failed=0。
- 数据为虚构验收样例，不能作为真实业务结论。

## 一次会话
- 开始时间：2026-09-23 00:11:25 +0800
- 结束时间：2026-09-23 00:11:25 +0800
- 本次焦点：只读定位内网明细弹窗、领域型号选项及院外分类

### 本次进展
- 用户确认已换20260921包。读取实际代码并定向复现旧管理单位名未映射时弹窗关闭/路由竞争及字典缺失默认院内。
- 筛选选项依赖账面明细关联cost_project；现场空选项原因待接口与只读SQL结果。

### 涉及文件
- note/70-testing/20260923-intranet-diagnosis/README.md
- note/70-testing/20260923-intranet-diagnosis/01-read-only-check.sql
- note/70-testing/20260923-intranet-diagnosis/reproduce.cjs

### 下次恢复点
- 内网成本三问题定位见note/70-testing/20260923-intranet-diagnosis/README.md；已复现两项前端缺陷但尚未改业务代码；下拉需现场数据补证。并行SQLBot原状态保留。

### 风险与备注
- 未改业务源码、数据库或既有包。需后续修复弹窗竞争及未知分类，并补现场接口/字典匹配证据。

## 一次会话
- 开始时间：2026-09-23 00:27:27 +0800
- 结束时间：2026-09-23 00:27:27 +0800
- 本次焦点：执行内网成本明细和单位分类修复，隔离下拉选项失败

### 本次进展
- 成本前端本轮已修复明细弹窗路由竞争和字典未知默认院内/重复计款，选项失败隔离与提示完成；51项测试和成本类型检查通过。仅源码，未提交、构建或打包；下拉现场原因待API响应，本地登录态过期未完成UI验收。

### 涉及文件
- ../sqlbot_with_bcback/costree-frontend/src/views/cost/ledgerCompositionDetail/index.vue
- ../sqlbot_with_bcback/costree-frontend/src/views/cost/utils/unitClassification.ts
- ../sqlbot_with_bcback/costree-frontend/src/views/cost/treeDetail/index.vue
- ../sqlbot_with_bcback/costree-frontend/src/views/cost/treeDetail/CostTreeNode.vue
- ../sqlbot_with_bcback/costree-frontend/src/views/cost/treeUnitDetail/index.vue
- ../sqlbot_with_bcback/costree-frontend/src/permission.ts
- ../sqlbot_with_bcback/costree-frontend/scripts/cost-intranet-regression.test.cjs
- note/70-testing/20260923-intranet-diagnosis/02-fix-verification.md

### 下次恢复点
- 当前成本前端有本轮未提交修复，51项回归和ts:check:cost通过。查02-fix-verification.md；不要将下拉问题或内网浏览器验收标记已完成，不要覆盖并行SQLBot状态。

### 风险与备注
- 领域型号空列表还需要现场响应确认；未修改后端与数据库，无新增升级SQL；当前离线包不含本轮修改。

## 一次会话
- 开始时间：2026-09-23 01:18:13 +0800
- 结束时间：2026-09-23 01:18:13 +0800
- 本次焦点：生成20260923完整成本离线包

### 本次进展
- 成本前端89b19528已推送；现生成20260923完整离线包，后端87b8bd2f隔离重建115测试，用户前端原样复制且本轮修复标记存在，51前端测试及类型检查通过，50项文件哈希/ZIP/SQL生成器通过。SHA256 af6cc41646fda27bd953ad889e23a77f4c1f655c4af93dfb4928f6f1cece549e。领域型号空选项仍待现场确认，未改真实数据库或部署服务。

### 涉及文件
- tools/release-20260923
- note/70-testing/20260923-release
- cost-server-offline-package-20260923.zip
- cost-server-offline-package-20260923.zip.sha256

### 下次恢复点
- 前端89b19528已提交推送。最新离线包cost-server-offline-package-20260923.zip已生成校验，见note/70-testing/20260923-release/README.md，不要再以先前“未提交/未打包”摘要为当前状态；包完整性不等同现场验收。

### 风险与备注
- 旧包保持不变；现场DWS/RPC/六账号/旧浏览器仍待验，领域型号空选项根因未确认。

## 一次会话
- 开始时间：2026-09-23 14:32:01 +0800
- 结束时间：2026-09-23 14:32:01 +0800
- 本次焦点：现场重复请求与同名多编码院外分类修复

### 本次进展
- 追加现场修复：已去掉六个下拉的重复展开请求；复现同名不同核算编码但归属一致被误判UNKNOWN，现只按归属冲突判定并保留共同属性。53项前端测试、类型检查及diff-check通过；三个前端文件尚未提交/推送/构建，20260923原包不含追加修复。新增限量10秒只读诊断，停止旧全量关联统计；领域型号空列表根因仍待响应确认。

### 涉及文件
- ../sqlbot_with_bcback/costree-frontend/src/views/cost/utils/unitClassification.ts
- ../sqlbot_with_bcback/costree-frontend/src/views/cost/ledgerCompositionDetail/index.vue
- ../sqlbot_with_bcback/costree-frontend/scripts/cost-intranet-regression.test.cjs
- note/70-testing/20260923-intranet-diagnosis/03-lightweight-check.sql
- note/70-testing/20260923-intranet-diagnosis/04-onsite-followup.md
- note/70-testing/20260923-intranet-diagnosis/05-same-name-classification.md

### 下次恢复点
- 追加现场修复：已去掉六个下拉的重复展开请求；复现同名不同核算编码但归属一致被误判UNKNOWN，现只按归属冲突判定并保留共同属性。53项前端测试、类型检查及diff-check通过；三个前端文件尚未提交/推送/构建，20260923原包不含追加修复。新增限量10秒只读诊断，停止旧全量关联统计；领域型号空列表根因仍待响应确认。

### 风险与备注
- 本地复现路径为归属待核对；若现场原文未分类院内仍须检查实际前端及接口。原包保持不变。

## 一次会话
- 开始时间：2026-10-08 16:13:17 +0800
- 结束时间：2026-10-08 16:52:00 +0800
- 本次焦点：成本树首发经典首页数据准确性调整及服务器预览部署

### 本次进展
- 20261008首发经典首页已部署到jt/dev-1预览：增加当前租户授权范围内正式领域项目编号去重计数，首页饼图改为八项金额条形图，隐藏3D舱与平台舱并固定经典页。补正全负/记录零组成被丢弃，但无源数据仍为空。后端124、前端60项及成本类型检查通过。项目数4与服务器4个正式测试项目一致；首页summary前后完全一致，32条金额逐项核对通过，材料费穿透、单位详情和领域目录成功，1366/1680/1920无裁切。仅更新cost和frontend，无SQL/数据库修改、未启动本地服务。发布20261008-cost-classic-preview-1632，回退/data/scripts/jt/history/20261008-164423-795891。源代码尚未提交；已包含上一轮同名单位分类及去重请求修复。历史内网空下拉仍未现场定因。

### 涉及文件
- costree-frontend/src/views/cost/overview/
- costree-frontend/src/api/cost/overview/index.ts
- baback/yudao-module-cost/yudao-module-cost-biz/
- note/70-testing/20261008-classic-preview/
- .agent-handoff/

### 下次恢复点
- 先读note/70-testing/20261008-classic-preview/README.md；服务器新版已部署，不要重复执行或启动本地服务。等待用户预览反馈；若要求提交或离线包再执行。保留SQLBot并行状态与现场未验项。

### 风险与备注
- 服务器使用虚构测试数据，本次预览验收不代表内网真实数据验收。
- 历史内网账面筛选空选项根因仍待现场响应；本轮未改业务数据库。
- 前后端源码未提交；本轮发布制品和工作区文件哈希已记录。

## 一次会话
- 开始时间：2026-10-09 07:56:50 +0800
- 结束时间：2026-10-09 08:51:48 +0800
- 本次焦点：经典首页紧凑布局与服务器预览

### 本次进展
- 20261009按用户选择保留四个六角图，压缩中央画布和两侧成本卡间距，改为名称/横条/金额紧凑横排。61项前端回归、成本类型检查通过，正式构建及服务器前端预览完成。部署前后4领域32项金额及总项目数/总体/院合计未变化，明细穿透和目录入口通过。本轮只更新frontend，后端和数据库未改、未启动本地服务；源码仍未提交，未生成新的离线包。同一领域条形等长来自虚构测试数据相等，各领域刻度独立。内网空下拉仍待已完成响应及限量抽样；真实金额、权限和360旧浏览器验收未替代。
- 发布信息见note/70-testing/20261009-classic-layout/deployment.json。

### 涉及文件
- costree-frontend/src/views/cost/overview/index.vue
- costree-frontend/src/views/cost/overview/DomainOverviewCard.vue
- costree-frontend/scripts/cost-overview-bars.test.cjs
- note/70-testing/20261009-classic-layout/
- .agent-handoff/

### 下次恢复点
- 先读note/70-testing/20261009-classic-layout/README.md和deployment.json；布局已发布，不要重复部署或启动本地服务。等待用户反馈/提交或离线包请求，保留SQLBot状态。

### 风险与备注
- 预览虚构数据不能替代内网真实数据验收。
- 账面空下拉根因尚未现场闭环。
- 前后端未提交修改及新离线包仍待发布收尾授权。

## 一次会话
- 开始时间：2026-10-09 10:21:34 +0800
- 结束时间：2026-10-09 10:28:06 +0800
- 本次焦点：内网账面空下拉范围不一致修复

### 本次进展
- 20261009追加账面筛选复核：复现汇总不要求项目记录、六类选项却强制关联项目的范围不一致。仅修改Mapper选项SQL：项目信息LEFT JOIN，项目编码来自账面；领域型号仍需真实项目字段。新增6项H2实际SQL及原16服务/5Mapper共27项通过，生产租户拦截器覆盖隔离与空权限，金额明细数不变；前端实际函数模拟验证缺归属项目筛选/URL可用。修复仅源码，未提交、构建发布JAR、部署或生成离线包，无真实DB操作及本地服务启动。现场唯一根因与DWS性能仍待核实。

### 涉及文件
- yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/dal/mysql/workorderledger/CostWorkOrderLedgerDetailMapper.java
- baback: CostWorkOrderLedgerFilterOptionsSqlTest.java
- note/40-api/02-接口字段契约.md
- note/70-testing/20261009-ledger-filter-scope/
- note/70-testing/20260923-intranet-diagnosis/06-filter-options-sample.sql
- note/70-testing/20261009-classic-layout/pending-issues.md

### 下次恢复点
- 先读note/70-testing/20261009-ledger-filter-scope/README.md；新后端修复尚未部署/打包，发布时纳入最终cost JAR。内网用06限量10秒抽样核对项目/领域型号/工作令关联；保留经典预览与SQLBot并行状态，不启动本地服务。

### 风险与备注
- 现有离线包与服务器不含本次后端修改。
- 程序缺陷已复现，但现场唯一原因与大表性能仍未确定。
- 领域型号无真实来源时保持为空，不造数据或取消权限/工作令过滤。

## 一次会话
- 开始时间：2026-10-09 10:46:05 +0800
- 结束时间：2026-10-09 12:06:47 +0800
- 本次焦点：成本源代码提交推送、前后端新构建与完整离线包和快照差异同步交付

### 本次进展
- 20261009 当前成本前后端修改已提交推送：后端82619751、前端2a6a0d38。后端在base Linux固定归档构建，130测试通过；Linux前端3次尝试失败/资源中止后，用户明确批准本机纯构建，Windows前端新构建、61测试及类型检查通过，未启动本地服务。新完整离线包cost-server-offline-package-20261009.zip已生成，1937文件哈希、ZIP及5份SQL参数生成器通过，SHA256 51d368b2e699c2e133b938e4fa67ca3fa11fa3331f23d160a5612ab239af5838。完整/仅建缺表/核验SQL沿用已验证结构版本；新增云鲸2.2.1全量快照差异更新模块和操作步骤，项目基本填报表整行保留，混合表白名单更新，ID/人工字段/状态保护。工作流最终PG17合成隔离验证15+5通过，13审计schema已清理；源缺失只报告不自动删除。服务器临时swap/zswap已恢复，现有服务未重启；未改真实业务数据库或部署应用。真实DWS/PG9.2、源稳定ID/同批完成标记、云鲸现场参数与容量保留、六账号和真实金额仍待现场验收。

### 涉及文件
- tools/release-20261009/
- note/70-testing/20261009-offline-release/
- note/40-api/02-接口字段契约.md
- cost-server-offline-package-20261009.zip

### 下次恢复点
- 使用20261009完整离线包开展现场验证；先核结构再更新应用，云鲸副本按05-workflow适配源字段/完成标记并隔离试跑两次。保持业务数据和既有服务，不能恢复旧全量清空任务；并行SQLBot状态不变。

### 风险与备注
- 真实DWS/PG9.2、云鲸现场调度/源发布完整性、六身份及真实金额仍待验收。
- 中间快照按批次保留，需确定容量保留期；旧清空业务表任务不得接回。
