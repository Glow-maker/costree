# 当前状态

- 最近更新时间：2026-06-12 02:20:00 +0800
- 当前阶段：第一阶段 MVP 实现、原型迁移和权限链路收口进行中
- 当前目标：在已有业务中台中嵌入成本库/成本树业务模块，让成本库数据可进入、可维护、可查询、可控权限，并用 note 文档中心和 .agent-handoff 形成可持续接管、开发、收尾和经验沉淀机制。
- 当前摘要：本轮只更新 Markdown 文档和交接状态，不改前端、后端或数据库。已把“文档作为项目操作系统”的长期维护机制沉淀到 note/00-overview/05-长期项目文档与工程经验沉淀模式.md，并同步 README.md、PROJECT_STATE.md、PLAN.md、AGENTS.md 和 90-logs/02-变更日志.md。后续每轮开发按开工 5 分钟恢复、需求规格化、开发中专题同步、收尾 10 分钟沉淀和周巡检执行。

## 已完成进展
- TASK-010: 初始化 agent-handoff 项目交接
- TASK-011: 更新 agent-handoff 交接状态并收尾
- TASK-012: 沉淀长期文档维护与工作区活力机制

## 下一步建议
- 继续项目时先运行 agent-handoff resume，再按 note/00-overview/05-长期项目文档与工程经验沉淀模式.md 做上下文恢复。功能开发下一步仍是重启 cost-server 和前端 dev server，使用 VITE_BASE_URL='http://127.0.0.1:38080' 且不启用 VITE_COST_MOCK_LOGIN，登录业务中台后复核 /cost/pending-allocation、/cost/warning、/cost/catalog，再进入 /cost/analysis 第一版迁移。

## 当前阻塞
- 浏览器页面复核需要真实业务中台登录态；未登录时会被重定向到 /login。
- 业务口径仍待确认：金额单位、借贷方向和冲销规则、历史工作令映射追溯、预分预控金额、院本级支出。
- 内网真实 MySQL、Redis、Nacos、网关、菜单权限、组织和数据权限映射仍待内网环境确认。
- 真实内网库不得执行 seed-mvp.sql；测试数据只用于外网测试库。
