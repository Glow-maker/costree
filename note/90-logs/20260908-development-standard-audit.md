# 通用开发规范符合性检查（2026-09-08）

结论：当前部分符合，尚不具备按该规范完成正式合并及发布的完整证据。DDL 本地归档已补齐，但迁移执行链、分支、脚本和接口文档仍有差距。

依据：[飞书《通用开发规范》](https://icnb5zyq3hvp.feishu.cn/wiki/BO9ew1M8Diiv3ckoSADciMZTnTb?fromScene=spaceOverview)，本次通过浏览器读取正文及环境/脚本目录图，页面显示最近修改为 9 月 1 日 15:54。检查范围为该文档本身，未将其链接的云效配置、环境隔离、端口台账等子文档视为已经核验。

页面推进计划列出 2026-09-11 正式宣贯、2027-01-01 全仓库正式运行。本报告按用户要求提前对标，不把计划日期当作已正式生效的证明。正文对 master/release 的输入输出、prev/pre/online 的命名存在不一致，实际执行口径需要仓库负责人统一。

## 取证范围

- 文档仓库：`H:/light/project/costree`，`jt/cost-server-offline-20260907`，HEAD `4d9c2a1`。
- 后端：`H:/light/project/sqlbot_with_bcback/baback`，`feature/costree`，上游 `codeup/feature/costree`，HEAD `9b0476ed`。
- 前端：`H:/light/project/sqlbot_with_bcback/costree-frontend`，`costree`，上游 `codeup/feature/costree2`，HEAD `4d5766a8`。
- 本轮读取工作树、近期提交、SQL、发布说明、两端 stage 脚本和 API 文档；执行 DDL 静态覆盖与迁移原文比对。
- 后端 SQL 整理与 DDL 尚未提交；前端工作树干净；文档仓库保留既有交接改动。本轮只新增本报告。
- 未访问真实数据库或服务器，未查询云效 MR/保护规则/流水线设置，未重新执行业务测试或构建。已有报告里的测试结果不能代替本轮真实验收。

## 检查结果

| 检查项 | 判定 | 当前证据与影响 |
|---|---|---|
| 前后端同名功能分支、规定命名 | 不符合 | 本地 `feature/costree` 与 `costree` 不同；远端上游也为 `feature/costree` 与 `feature/costree2`，均不是文档示例的 `feat/YYYY_MM/...`。不自动改名或重写已推送历史。 |
| 从最新 master 派生并在 MR 前整理提交 | 待验证 | 本地多条开发提交本身不构成违规；是否已在 MR 前 squash/rebase、基于哪个 master，应在正式合并前核验。未拉取最新远端，不能凭旧远端引用判定。 |
| 至少一位人工 reviewer、流水线通过、评论解决、分支保护 | 待验证 | 本轮无云效设置和 MR 记录。AI 静态审查、直接推送功能分支均不能充当这几项证明；也不能据此断言没有配置流水线。 |
| MR 标题含类型、模块、摘要 | 待验证 | 近期 commit 有 `feat(cost): ...`，语义可追溯；规范示例为 `[feat][cost]...`。commit 标题不等于 MR 标题，下次 MR 按规范格式填写。 |
| 单次 MR 建议不超过 500 行 | 建议项有差距 | 后端最近一次提交为 659 行新增、73 行删除；若整体形成一个 MR，超过建议规模。该条是建议，不作为硬性违规，也不能将提交统计冒充真实 MR diff。 |
| 文档覆盖所有 API URI、结构和请求样例 | 不完整 | `note/40-api` 有接口清单、字段契约、联调用例，但检索未找到 `role-assignment` 和 `roleRevision`；新增角色分配与范围版本接口未进入该正式入口。 |
| 自测、用户用例、缺陷修复与提测 | 未完成闭环 | 有本地测试及历史审查报告；真实旧中台 RPC、DWS、六类账号验收待完成。R1/R2 并发缺口仍登记未修复，当前相关源码与 `9b0476ed` 无差异。缺陷分级须由项目负责人按该文档的 P0/P1 定义确认，不直接换算旧报告等级。 |
| 模块内 sql/DDL.sql、后续尾部追加 | 本地文件符合，流程未完成 | 已建立 `yudao-module-cost/sql/DDL.sql` 及 README；有来源、日期、前置条件、后续追加规则，但 Git 仍未跟踪此文件，尚未进入正式提交与审查。 |
| 表、字段仅小写字母或下划线 | 存在 4 个历史例外 | 20 张表命名符合；376 个字段中 `cost_project_basic.competitor_unit_1/2`、`competitor_price_1/2` 含数字。先前为兼容保留，按规范严格字面不能算全部符合；需负责人认可历史豁免，或单独做数据库、Java、映射及接口兼容迁移。 |
| 所有表及字段有数据库注释 | DDL 文件符合；部署链不完整 | 静态检查确认 20 张表、376 个字段均有非空 COMMENT，三个来源 SQL 原文均已收录。但原 `costree-cost.sql` 和 `17` 没有字段 COMMENT；`17` 也未为授权锁表加表注释。现有执行器/候选包不会自动执行 DDL 的补充注释，真实库注释状态未查。 |
| 按环境维护构建/部署/重启/回滚脚本 | 不完整 | 两代码仓库 `scripts` 均只有 `stage`，仅发现 build/deploy，缺少文档示意的环境目录与 restart/rollback 入口。当前 stage 不是 cost 专用流程。 |
| 构建脚本可用且可追溯 | 旧入口不符合当前交付 | 后端 `scripts/stage/build.sh:3` 为 `git clone pull`，不是更新当前仓库命令；后续跳过测试、复制多个模块且未复制 cost。前端 stage 使用 `npm install`、`build:prod`；不能把这些脚本当作已验证的当前 cost 内场构建流程。跳过构建内测试本身不证明独立流水线缺失。 |
| 最小化发布，不影响其他模块 | 当前候选说明符合；旧脚本不符合 | 当前应用替换说明明确只替换 cost 与前端、保留 system 和配置；后端 stage deploy 会清日志、kill/restart bpm、system、data、gateway、infra，且没有模块参数分派。不能用于本次 cost 发布。 |
| 数据盘 /data、按环境及模块分目录 | 旧脚本不符合示意；现场待查 | 后端用 `~/service`，前端部署到 `/home/sht808/project/frontend/dist/main`；未按 `/data/service/<环境>/<模块>/current` 分层。真实挂载点、现场目录未核验，不能从本机路径断定服务器磁盘不合规。 |
| 内场构建、完整依赖、预发用例通过 | 缺验收证据 | 0907 是已构建的 validation-candidate，应用替换说明采用 JAR/前端 ZIP 替换。现有候选不是“内场源码构建+预发验证完成”的凭证，需另行验证离线依赖、构建机和源码版本一致性。不能把候选替换步骤直接作为正式上线批准。 |
| 守护进程或容器自动重启 | 旧脚本不符合；现场待查 | 后端 stage 只用 `nohup ... &`，不具备异常自动拉起。候选沿用现场启动方式，真实 systemd/docker 配置需由运维核实。 |
| 非公共微服务端口大于 10000 | 默认源码符合；登记待查 | cost 主配置默认 48108，本地配置默认 38108；环境变量可覆盖。这里只判断 cost 服务端口，不把公共 Redis 的 6379 算作违规。现场端口、隔离命名及防火墙台账待查。 |
| 备份、回归、发布通知、标签及 release 回合 master | 待验证 | 候选要求备份和上线检查；未见本次真实备份、预发/线上回归、通知、发布标签或 release 合入记录。不能将尚未上线解释为已漏做上线操作。 |
| 回滚与备份保留 | 有项目特有约束 | 本地角色撤销记录不能被旧 JAR 正确理解，通用“换回最新备份 JAR”不足以保证权限安全。回滚前必须停写、核对授权兼容性并审批；文档最多 5 份备份规则不能覆盖用户明确要求保留全部现有备份。 |
| 第三方仓库权限、后端 API 包及前端 Qiankun | 待验证适用性 | 本轮未获取外协合作范围、仓库成员权限或实际接入证据。不能据源码有 API 模块便判定外协管理符合。 |

## 关键证据入口

- [DDL 与维护规则](../../../sqlbot_with_bcback/baback/yudao-module-cost/sql/README.md)
- [原本地授权迁移](../../../sqlbot_with_bcback/baback/sql/postgresql92/costree-deploy/17-cost-local-roles-20260907.sql)
- [后端旧构建脚本](../../../sqlbot_with_bcback/baback/scripts/stage/build.sh)、[旧部署脚本](../../../sqlbot_with_bcback/baback/scripts/stage/deploy.sh)
- [前端旧部署脚本](../../../sqlbot_with_bcback/costree-frontend/scripts/stage/deploy.sh)
- [新增角色接口](../../../sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/controller/admin/accessscope/CostRoleAssignmentController.java)：`/cost/role-assignment` 下 page、scope-user-page、lookup、assign；assign 含 userId、roleCode、revision。
- [现有接口文档](../40-api/README.md)、[接口联调用例](../40-api/03-接口联调用例.md)：后者仍标注初稿，前置环境为外网 MySQL。
- [0907 应用替换说明](../../cost-server-offline-package/00-现场必用/03-应用文件/00-应用替换说明.md)
- [既有授权并发审查](20260907-local-authorization-review.md)：本轮没有将静态发现冒充实际生产事故，也未重新复现。

## 下一步顺序

1. 先补代码合并可审查材料：把已有 SQL 整理和 DDL 纳入待审提交，补本地授权接口与冲突响应样例；形成只追加注释的迁移，使后续迁移源与 DDL 一致。保留冻结的 0907 包，不把这次补注释说成已进入候选包。
2. 为 cost 与前端建立适用的环境脚本，包含单模块部署、备份、重启、健康检查和授权兼容回滚；给旧 stage 明确历史用途，不能复用其批量重启共享模块的做法。是否复用公共部署仓库需结合其实际内容决定。
3. 修复并定向验证 R1/R2；整理真实测试用例及失败处理，完成旧 RPC、DWS、六类账号和内场构建/预发验收。
4. 正式发起 MR 前，与仓库负责人确定历史分支迁移、四个历史数字字段、master/release 流程和环境目录的唯一口径；核验 reviewer、分支保护、流水线和评论状态，再按规范整理提交。
5. 正式发布前由运维提供端口/防火墙登记、数据盘挂载、守护进程、备份及发布计划证据。通知、发布、备份删除、重写历史、重新打包均不在本轮审查中执行。

本报告不批准上线，不改变仅部署 cost 与前端、不部署 system、不直接修改 DM 的既有边界。
