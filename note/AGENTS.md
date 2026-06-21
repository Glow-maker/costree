# AGENTS - 成本库项目 Codex 工作规则

更新时间：2026-06-18

用途：约束后续 Codex/AI 协作方式，减少跨会话丢上下文、误改文件、忘记验证和文档失配的问题。

## 1. 项目边界

路径统一使用可迁移写法：`<costree-root>` 表示当前文档仓库根目录，`<frontend-root>` 表示前端仓库根目录，`<backend-root>` 表示后端仓库根目录。当前推荐相对布局为前端 `../sqlbot_with_bcback/costree-frontend`、后端 `../sqlbot_with_bcback/baback`，不要把 `H:\`、`D:\` 等本机盘符写入新的协作文档。

| 类型 | 路径 | 规则 |
|---|---|---|
| 文档中心 | `<costree-root>/note` | 长期维护项目事实，新增文档必须归位 |
| 前端仓库 | `<frontend-root>` | 成本库 Vue3 页面和 API 的主要开发位置；当前分支 `costree`，跟踪 `codeup/feature/costree2` |
| 后端仓库 | `<backend-root>` | 数据中台后端和 `yudao-module-cost` 开发位置；当前分支 `feature/costree`，跟踪 `codeup/feature/costree` |
| React/Figma 原型 | `<costree-root>` | 只作为页面、字段和交互参考，不直接作为最终中台代码 |

## 2. 工作原则

- 先读现有文档和代码，再新增实现或文档。
- 长期任务开工前，先按 `00-overview/05-长期项目文档与工程经验沉淀模式.md` 做上下文恢复，读取 `.agent-handoff`、`README.md`、`PROJECT_STATE.md`、`PLAN.md` 和本轮相关专题文档。
- 新增需求、接口、页面、聚合、导出或权限逻辑前，先查 `00-overview/04-工程经验与开发约束手册.md`，确认是否已有可复用模式或禁止反模式。
- 成本库按模块化边界开发：默认只修改成本库/成本树相关文件；确需修改其他模块时，必须先通知用户说明原因、影响范围和替代方案，并在本轮文档中记录为什么必须修改。
- 优先复用数据中台已有登录、租户、权限、菜单、组织、消息、导入导出能力。
- 不创建平行体系：已有目录、页面、接口、数据表或文档能承载的，不另起一套。
- 修改要可追溯到当前目标，不做顺手重构。
- 不确定事项统一标记 `【需确认】`，并同步到 `RISKS.md` 或对应确认问题清单。
- 阶段性进展写入 `PROJECT_STATE.md`、`PLAN.md`、`DECISIONS.md`、`RISKS.md` 或 `90-logs/02-变更日志.md` 中的合适位置。

## 3. 文档归位

| 内容 | 归档位置 |
|---|---|
| 总览、路线图、维护规范、工程经验与开发约束 | `00-overview/` |
| 现有代码、原型、参考模块分析 | `10-research/` |
| PRD、角色权限、业务确认问题 | `20-requirements/` |
| 数据模型、枚举、建表 SQL、测试数据 | `30-data/` |
| 接口清单、字段契约、联调用例 | `40-api/` |
| Vue3 页面迁移、页面实现说明 | `50-frontend/` |
| Yudao 后端设计、生成清单、实现记录 | `60-backend/` |
| 测试计划、验收清单、问题复盘 | `70-testing/` |
| 环境账号、内外网迁移、部署手册 | `80-deployment/` |
| 决策记录、变更日志、过程记录 | `90-logs/` |

## 4. 修改约束

- 不提交或主动修改本地运行日志，例如 `costree-frontend-dev.log`。
- 不把后端本地配置 `application-local.yml` 中的个人运行改动当作业务提交，除非用户明确要求。
- 前端默认只改 `src/views/cost/**`、`src/api/cost/**`、成本库路由/菜单入口和成本库复用组件；修改其他业务模块文件前必须先说明原因并记录到变更日志或专题文档。
- 后端默认只改 `yudao-module-cost/**`、`cost-server`、网关中成本库路由和必要配置；修改其他模块前必须先说明原因并记录到变更日志或专题文档。
- 如果因为全局构建、Vite 启动、依赖错误、登录态或网关集成必须触碰非成本模块，改动应最小化，并在文档中写明：触碰文件、触碰原因、是否临时、是否需要后续回归。
- 不在真实内网库执行 `seed-mvp.sql`。
- 不在内网正式环境开启 `COST_LOCAL_TEST_MOCK_PLATFORM=true`。
- SQL 结构变更必须同步更新数据模型、建表说明、部署说明。
- 接口字段变更必须同步更新接口字段契约。
- 页面行为变更必须同步更新前端接入记录或页面设计文档。
- 涉及账号、密码、Token 的信息集中维护在 `80-deployment/00-环境账号与敏感信息.md`，提交公网前必须检查。

## 5. 验证要求

前端成本库相关修改后，优先执行：

```powershell
cd ../sqlbot_with_bcback/costree-frontend
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

后端成本库相关修改后，优先执行：

```powershell
cd ../sqlbot_with_bcback/baback
mvn -pl yudao-module-cost/yudao-module-cost-biz -am -DskipTests compile
```

文档-only 修改后，至少检查：

- 新增/修改的 Markdown 可用 UTF-8 正常读取。
- README、PROJECT_STATE、PLAN、RISKS、DECISIONS 之间没有明显冲突。
- 如果本轮不跑前后端验证，要在最终说明里明确“本轮只改文档，未运行前后端构建”。

## 6. 交接规则

- 每次长任务结束前更新 `PROJECT_STATE.md` 的当前目标、已完成、未完成、阻塞、关键决策和下一步最小任务。
- 每次长任务结束前按长期维护模式做 10 分钟收尾：同步 `PROJECT_STATE.md`、`PLAN.md`、`90-logs/02-变更日志.md`，必要时更新 `RISKS.md`、`DECISIONS.md`、工程经验手册和 `.agent-handoff`。
- 关键设计取舍进入 `DECISIONS.md` 索引，详细背景保留在专题文档或 `90-logs/01-决策记录.md`。
- 风险和待确认项进入 `RISKS.md`，不要只留在聊天记录里。
- 实施过程和验证结果进入 `90-logs/02-变更日志.md`，便于后续追溯。
- 如用户要求 commit，先检查工作区，避免提交本地日志、个人配置或无关改动。
