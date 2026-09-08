# 0907 本地授权候选包审查

本轮为静态源码审查及现有制品只读核对。发现两项数据范围并发缺口，建议先修复并验证，再推进真实环境验收。没有修改业务源码、提交、推送、重新构建、重新打包或连接真实数据库。

## 工作树与路径

用户提供的 `costree.agent-handoff`、`sqlbot/_with/_bcback` 路径在本机不存在；实际入口为 `H:/light/project/costree/.agent-handoff/START-HERE.md`，前后端位于 `H:/light/project/sqlbot_with_bcback/`。分支、HEAD 与交接相符。

以下为本轮新增报告前的状态；未跟踪项按 Git 默认目录折叠统计，三个仓库均无暂存改动。

| 仓库 | 分支 / HEAD | 已跟踪改动 | 未跟踪项 |
|---|---|---:|---:|
| costree | jt/cost-server-offline-20260907 / 2cd69dd | 17 | 23 |
| baback | feature/costree / 7469e960 | 20 | 8 |
| costree-frontend | costree / e95d87e9 | 8 | 2 |

- 根仓库：既有交接状态、3 个发布工具修改、新本地授权打包工具与说明、验证目录、4 组备份及 test.html/test2.html。3 个旧交接中转文件在本轮开始时已处于删除状态，未恢复或新增删除。
- 后端：权限注解迁移、范围版本校验、预警接收人逻辑与测试；新增本地角色控制器、服务、策略、DO、Mapper、17 SQL 和两组测试。没有未提交的 system 模块改动。
- 前端：cost API、路由守卫、角色和范围页面、门户入口及导入导出控制。未跟踪项为 design-qa.md 和 importExportPermission.ts。
- 三仓 `git diff --check` 均退出 0；有既有 LF/CRLF 提示。没有整理格式、还原配置或清理备份。

## 发现

### R1 / P1：范围档案可能把旧范围标成新角色版本

位置：[CostAccessScopeServiceImpl.java:110](H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/accessscope/CostAccessScopeServiceImpl.java:110)、[同文件:639](H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/accessscope/CostAccessScopeServiceImpl.java:639)。

`getProfile` 先执行 `resolveScope` 读取角色/范围，中间还调用用户 RPC；随后 `buildProfile` 另查当前 `roleRevision`。读取不在同一稳定快照内，也没有前后版本一致性检查。

可触发顺序：A 读取研制单位角色及项目 P 的旧范围；B 将该账号切换为项目办，清空范围并把版本从 n 升为 n+1；A 随后取到 n+1，返回“旧角色＋旧项目 P＋新版本”。客户端携带该版本和旧项目 P 提交范围 API 时，`saveProfile` 的版本比较通过，按当前项目办角色重新写入 P，覆盖了切换角色后清空范围的效果。单位列表另查，页面可能要求重新补选单位；此项描述的是后端 API 的版本校验缺口，未声称已经浏览器复现。

这是静态代码时序推导，尚未做真实并发复现。建议把角色、范围和版本作为一致快照读取；角色解析复用同一条本地记录。增加可控交错测试，保证角色切换后旧表单必须冲突，不能恢复旧范围。不要只给 GET 加默认隔离级别事务便宣称解决。

### R2 / P2：范围与范围并发保存会静默丢失更新

位置：[CostAccessScopeServiceImpl.java:119](H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/accessscope/CostAccessScopeServiceImpl.java:119)。

保存范围会加同一用户锁，并比较角色 revision，但成功保存不递增任何范围版本。两位专员都读到版本 n：A 移除项目 P 并保存，B 持旧页面随后保存，仍满足版本 n，整表删除再插入后可把 P 重新加回。行锁只串行化写入，不能检测旧表单覆盖。

建议为授权整体引入能覆盖范围保存的版本检查，并让每次有效保存递增；兼顾尚无本地角色记录的旧账号，不要借此把其角色强制接管。增加“双读取、先后保存”测试，第二次应明确冲突。

现有 CostLocalRoleAssignmentTest 仅覆盖角色分配旧版本拒绝；源码测试检索未发现以上范围并发场景。不要把既有 82 项通过当作这些场景已覆盖。

## 安全边界与旧中台兼容性

已核对的实现：

- 本地记录优先；NULL 角色返回无业务角色，不回退平台旧角色；数据库读取异常也不会回退放行。
- 分配入口执行 manager 检查；限定四类角色，拒绝自改及管理员/专员目标；角色变化清理旧范围，写追加角色审计。
- 显式 tenant/user 查询及唯一键、同用户事务锁存在；成本服务租户过滤器还比较登录租户与请求租户。静态未发现新增主动忽略租户的路径。
- 共享 `ss` 权限 Bean 未被替换；cost 控制器改用 `costPermission`。本地角色没有写入通用平台权限缓存；管理员原用户管理页及原范围用户列表保留。
- 研制单位范围仍按项目与管理单位交集；科研部全周期经费使用单独角色守卫，不依赖普通填报权限矩阵。

旧中台兼容仍为待验收项：本地源码已有 AdminUserApi 的 getUserList、listByNameLike、getUser 及 PermissionApi 的 hasAnyRoles、hasAnyPermissions；新授权服务未要求新增 system 授权 API。但只有现场旧 system 才能证明这些 RPC 版本、返回字段、租户转发及 `data-permission-enable=false` 的跨部门目录读取可用。缺失用户时，现有 system `getUser` 实现还可能空指针，因此需验证无效/跨租户目标的实际错误响应，不能仅依赖 Mock 返回 null。

性能观察：[CostRoleAssignmentService.java:65](H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/accessscope/CostRoleAssignmentService.java:65) 对匹配用户逐个串行查询平台角色。100 个普通、尚未接管用户可产生约 700 次角色 RPC（每人管理员/专员判定 3 次，四类业务角色 4 次），另加目录及操作者校验。列表每页 100 个本地普通账号也约有 300 次角色 RPC。需测旧中台延迟和超时；优化时优先减少重复调用或复用已确认存在的旧批量能力，不恢复新增 system 部署方案。

现场最小验收应覆盖：管理员、专员、四类业务角色；跨租户/停用/伪造目标；专员混配角色；原角色接管；撤销后不重登直接查询与导出；角色切换和两个范围保存的交错；科研经费和预警完整流程；原中台页面。DWS 8.2 必须单独验证新三表、唯一约束、行锁、事务回滚与重复升级，不能用独立 PG9.2 结果替代。

## 候选包一致性

- 外层 ZIP SHA256：`FA8412A3A0A34B055C1BDAD5EC3EEB37885F73402ADC41D80EA32B38758897C6`。
- ZIP 共 14 文件，逐文件与现有目录一致；SHA256SUMS 的 13 个条目均通过，清单自身为第 14 文件。
- SOURCE-SHA256 登记的 216 个前后端源码文件与当前工作区逐字节一致。
- SQL 来源清单 14 项按生成器规则（去 BOM、CRLF 转 LF）核对全部一致。原始字节哈希因换行不同而不同，不是 SQL 内容漂移。
- JAR 中 199 个成本 class 与当前 target/classes 一致；这只是既有编译产物一致性，不代替重新编译证明。
- 前端 ZIP 的 6827 个文件与现有 dist-cost-local-role-0907 输出逐文件一致；JS/HTML 中未发现 `/system/cost-role-assignment`，现代及 legacy 资源均包含 `/cost/role-assignment/assign`。
- RELEASE-INFO 明确 `validation-candidate`、工作树源码、两仓基线、`systemDeployment=not-required`、真实验收 pending。包内只有成本 JAR 与前端 ZIP。
- 本地既有 Surefire XML 共 13 份，汇总 82 tests、0 failures、0 errors、0 skipped；本轮只读取这些报告，没有重跑测试。
- 源码清单不是完整可复现构建清单：未覆盖全部前端共享路由/构建依赖、后端框架/API 源码等。当前核对不能升级为“全依赖可复现”或生产验收结论。

## 下一步

1. 先修复并定向复现 R1/R2；本轮只报告，不自动改源码。保存现有 0907 候选包作为基准，修复后它将不再代表最新源码，后续是否重新出包另按用户指令执行。
2. 在不部署 system、不直写 DM 的约束下，验证旧 RPC 的租户隔离、跨部门目录及延迟，再进行六类账号和真实 DWS 验收。
3. 只有后续明确要求时才选择性提交推送；排除 design-qa.md、本地配置、验证目录和制品备份。旧成本 JAR 不识别撤销记录，不能盲目回退后开放访问。
