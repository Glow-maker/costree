# 当前状态

- 最近更新时间：2026-08-19 03:45:00 +0800
- 当前阶段：20260819 数据保护与分系统字典实现完成，等待真实 PostgreSQL 9.2/GaussDB(DWS) 演练
- 当前目标：确保外部全量快照只更新外部拥有字段，成本库填报和流程状态不被覆盖，并为旧清库流程提供独立可验收的恢复保护层。
- 当前摘要：已将 snapshot-upsert 固定为常规入口，只清六张 cost_sync_stage 中间表并按业务键 UPDATE + INSERT；同步前建立逐行手工字段基线和五类摘要，同步后逐行复验，异常不标记 SUCCESS。新增 cost_manual_snapshot 独立保护层及强确认 PowerShell 包装器，覆盖项目办、项目状态、单位填报、工作令填报和预警状态的快照、恢复、异常清单与复验。新增成本库 cost_subsystem_dict、管理员维护 API/页面和 collect 多选，阶段扩至 varchar(255)，移除 vertical_division 的旧默认值但不改历史 false。指定 release-20260729-data-integration 已原地升级为 20260819，新增升级、检查、保护恢复、说明、验包规则和 58 项 SHA256。后端 16 个聚焦测试、前端成本类型与目标 ESLint、DWS 29 SQL 静态检查、发布包验包和模板/发布哈希均通过。

## 已完成进展
- TASK-040: 完成 PostgreSQL 9.2/GaussDB 全量快照幂等同步模板
- TASK-041: 完成三级权限静态安全收口
- TASK-042: 实现 20260819 内网同步与填报数据保护升级

## 下一步建议
- 在真实 PostgreSQL 9.2/GaussDB(DWS) 备份环境先执行 20260819 升级与检查，再用两批相同源快照验证幂等和手工字段不变，最后以专用测试库执行一次 cost_manual_snapshot 清库恢复往返；完成前不得宣称内网上线验收通过。

## 当前阻塞
- 本机没有 psql、gsql、mysql 或 disql，尚未执行真实数据库 SQL、两批幂等同步或清库恢复演练。
- 发布目录 cost-intranet-data-kit 被根仓库 .gitignore 忽略，内容已落盘并通过 SHA256/验包，但不会自动进入普通 Git 提交。
- 当前三个仓库还包含前序已批准但未提交的成本功能和交接状态变更，本轮没有提交或推送。
