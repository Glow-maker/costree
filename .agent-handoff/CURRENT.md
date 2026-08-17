# 当前状态

- 最近更新时间：2026-08-18 02:32:00 +0800
- 当前阶段：第一阶段 MVP 权限实现已提交，进入真实账号与目标数据库验收
- 当前目标：在同一业务租户内完成 tenant_admin 授权管理与三类成本业务角色的数据范围控制，并在真实中台、达梦平台库和 PostgreSQL 9.2/GaussDB 成本库完成端到端验收。
- 当前摘要：已修复 Cost 服务缺失 AdminUserApi Bean、平台菜单顶级路由缺少前导斜杠、成本授权菜单不可见、工作令状态机绕过和跨用户类型角色串用等问题。tenant_admin 作为成本授权管理员；cost_global_viewer 默认进入 /cost/index，cost_project_office 默认进入 /cost/catalog，cost_unit_user 必须同时选择项目与管理单位，实际范围取二者交集。非成本账号登录不再同步请求成本 profile，避免成本服务可用性影响其他中台模块。后端提交 fbfc3e3404b8、前端提交 bfd196e4282c；root 部署模板、快照同步和交接记录将一并提交。后端 10 项聚焦测试、前端成本类型检查与定向 ESLint、PowerShell/Bash 语法及 DWS 27 个 SQL 静态检查通过。尚未完成真实 ApplicationContext 启动、真实账号登录和真实目标数据库执行。

## 已完成进展
- TASK-039: 完成 20260728 多方言数据库升级和内网包模板
- TASK-040: 完成 PostgreSQL 9.2/GaussDB 全量快照幂等同步模板
- TASK-041: 完成三级权限静态安全收口

## 下一步建议
- 在完整中台环境启动 system-server、gateway、cost-server 和前端，使用 tenant_admin、cost_global_viewer、cost_project_office、cost_unit_user 四类真实账号验收默认落地、菜单、直接 URL、项目与单位交集、详情、导出和工作令状态机；随后在备份库执行 DM 平台角色脚本、PG92/GaussDB 12 升级与 20-verify，并替换 snapshot-upsert 的现场源字段映射进行重复同步对账。

## 当前阻塞
- 当前没有完整可用的 system-server、gateway、cost-server、Nacos、Redis 和业务数据库链路，AdminUserApi Feign 注册仅通过静态与编译验证，未做真实 ApplicationContext 启动。
- 没有可用的四类真实测试账号，本轮不能证明真实菜单、默认落地、直接 URL、详情、导出和工作令状态机端到端验收通过。
- 尚未在真实达梦 MQB、PostgreSQL 9.2 或 GaussDB(DWS) 8.2.1 执行本轮脚本；静态兼容检查不能替代目标库验收。
- snapshot-upsert 仍需替换现场源 schema、表名和字段转换；跨文件流程采用分阶段提交，不承诺整批原子回滚。
- DWS 兼容模式下 scope 防重依赖普通索引加重复数据检查，仍需现场并发写入与重复键卫生验收；单位范围当前仍以名称匹配事实表，改名或同名风险需业务数据验证。
