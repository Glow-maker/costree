# AGENTS - 成本库项目 Codex 工作规则

更新时间：2026-06-03

用途：约束后续 Codex/AI 协作方式，减少跨会话丢上下文、误改文件、忘记验证和文档失配的问题。

## 1. 项目边界

| 类型 | 路径 | 规则 |
|---|---|---|
| 文档中心 | `H:\light\project\costree\note` | 长期维护项目事实，新增文档必须归位 |
| 前端仓库 | `H:\light\project\sqlbot_with_bcback\costree-frontend` | 成本库 Vue3 页面和 API 的主要开发位置 |
| 后端仓库 | `H:\light\project\sqlbot_with_bcback\baback` | 数据中台后端和 `yudao-module-cost` 开发位置 |
| React/Figma 原型 | `H:\light\project\costree` | 只作为页面、字段和交互参考，不直接作为最终中台代码 |

## 2. 工作原则

- 先读现有文档和代码，再新增实现或文档。
- 新增需求、接口、页面、聚合、导出或权限逻辑前，先查 `00-overview/04-工程经验与开发约束手册.md`，确认是否已有可复用模式或禁止反模式。
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
- 不在真实内网库执行 `seed-mvp.sql`。
- 不在内网正式环境开启 `COST_LOCAL_TEST_MOCK_PLATFORM=true`。
- SQL 结构变更必须同步更新数据模型、建表说明、部署说明。
- 接口字段变更必须同步更新接口字段契约。
- 页面行为变更必须同步更新前端接入记录或页面设计文档。
- 涉及账号、密码、Token 的信息集中维护在 `80-deployment/00-环境账号与敏感信息.md`，提交公网前必须检查。

## 5. 验证要求

前端成本库相关修改后，优先执行：

```powershell
cd H:\light\project\sqlbot_with_bcback\costree-frontend
pnpm run ts:check:cost
pnpm exec eslint "src/api/cost/**/*.ts" "src/views/cost/**/*.vue" "src/router/modules/remaining.ts" "src/views/HomeIndex/index.vue" --ext .ts,.vue
```

后端成本库相关修改后，优先执行：

```powershell
cd H:\light\project\sqlbot_with_bcback\baback
mvn -pl yudao-module-cost/yudao-module-cost-biz -am -DskipTests compile
```

文档-only 修改后，至少检查：

- 新增/修改的 Markdown 可用 UTF-8 正常读取。
- README、PROJECT_STATE、PLAN、RISKS、DECISIONS 之间没有明显冲突。
- 如果本轮不跑前后端验证，要在最终说明里明确“本轮只改文档，未运行前后端构建”。

## 6. 交接规则

- 每次长任务结束前更新 `PROJECT_STATE.md` 的当前目标、已完成、未完成、阻塞、关键决策和下一步最小任务。
- 关键设计取舍进入 `DECISIONS.md` 索引，详细背景保留在专题文档或 `90-logs/01-决策记录.md`。
- 风险和待确认项进入 `RISKS.md`，不要只留在聊天记录里。
- 实施过程和验证结果进入 `90-logs/02-变更日志.md`，便于后续追溯。
- 如用户要求 commit，先检查工作区，避免提交本地日志、个人配置或无关改动。
