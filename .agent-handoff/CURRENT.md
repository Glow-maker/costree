# 当前状态

- 最近更新时间：2026-07-28 21:40:00 +0800
- 当前阶段：第一阶段 MVP 实现、真实数据对齐和内网部署准备收口中
- 当前目标：在已有业务中台中嵌入成本库/成本树业务模块，让成本库数据可进入、可维护、可查询、可控权限，并用 note 文档中心和 .agent-handoff 形成可持续接管、开发、收尾和经验沉淀机制。
- 当前摘要：本轮完成项目办按项目进入弹窗、按单位维护目标成本和审定金额；合同和到款只读取自预分预控同步。研制单位采集页调整为左侧工作令记录、右侧填报表单，选择主业项目后仅查询该项目工作令；新增只读工作令查询页。成本树新增 HEAD_OFFICE，院部直属型号且排在最左，总体所只包含八部和509所。后端新增项目办聚合查询与事务保存接口，cost_project_basic 增加 quantity、product_short_name、vertical_division。数据库版本升级为 20260728，MySQL、PostgreSQL 和 PostgreSQL 9.2/GaussDB 均补齐完整 DDL 与增量脚本。正式同步脚本只更新预分预控合同和到款，不覆盖项目办维护的目标和审定。前端提交 c6b81fe 已推送 codeup/feature/costree2，后端提交 114b6202 及前置提交 771efff4 已推送 codeup/feature/costree。

## 已完成进展
- TASK-037: 完成项目办按单位维护目标和审定金额
- TASK-038: 完成研制单位工作令筛选和独立工作令查询页
- TASK-039: 完成 20260728 多方言数据库升级和内网包模板

## 下一步建议
- 使用根仓库 tools/build-cost-server-offline-package.ps1 从已提交前后端构建正式离线包。内网既有库必须依次执行对应数据库目录的 00-precheck.sql、10-upgrade-existing-to-20260722.sql、11-upgrade-existing-to-20260728-project-office-form.sql、20-verify.sql，再替换后端 jar 和前端资源。数据接入先同步单位、项目树、工作令字典和预分预控合同/到款，再导入借方账面明细，最后由项目办在 /cost/collect 维护单位目标和审定。

## 当前阻塞
- 现有数据库不能只替换 jar；未执行 20260728 增量脚本会因 cost_project_basic 缺少 quantity、product_short_name、vertical_division 导致查询失败。
- 本轮未连接真实 GaussDB(DWS) 8.2.1 执行升级，仅完成 PostgreSQL 9.2/GaussDB 方言静态兼容检查，现场仍需先备份并执行 precheck 和 verify。
- 真实内网 Nacos、Redis、网关、菜单权限、租户、组织和数据权限仍需现场确认。
- 后端配置已改为必须显式提供 COST_DATASOURCE_URL、COST_DATASOURCE_USERNAME、COST_DATASOURCE_PASSWORD；未配置时应用会在启动早期失败。
