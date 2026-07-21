# 当前状态

- 最近更新时间：2026-07-21 19:34:41 +0800
- 当前阶段：第一阶段 MVP 实现、真实数据对齐和内网部署准备收口中
- 当前目标：在已有业务中台中嵌入成本库/成本树业务模块，让成本库数据可进入、可维护、可查询、可控权限，并用 note 文档中心和 .agent-handoff 形成可持续接管、开发、收尾和经验沉淀机制。
- 当前摘要：本轮完成成本树单位层级重构：院内核算单位按 cost_unit_dict.manage_unit_name 汇总为管理单位，并按总体所、总装所、专业所、基础所、院外单位五类展示；管理单位穿透仍保留实际核算单位，工作令和账面组成不会因管理简称错误合并。/cost/tree-detail 右侧重复金额区改为院内管理单位账面/目标使用率排名，/cost/catalog 卡片文案同步调整。MySQL/PostgreSQL DDL、增量迁移和完整演示项目脚本已补齐。后端提交 e70c6eac 已推送 codeup/feature/costree，前端提交 db0b185 已推送 codeup/feature/costree2。

## 已完成进展
- TASK-028: 实现成本树管理单位分组与穿透
- TASK-029: 补充管理单位分组迁移和演示数据
- TASK-030: 优化成本树右侧信息和目录卡片文案

## 下一步建议
- 在目标数据库先执行对应数据库的 costree-cost-20260721-add-manage-unit-group.sql，重启后端；需要演示时再执行 costree-unit-hierarchy-demo.sql，并访问 /cost/tree-detail?projectCode=ZY-2026-DEMO-UNIT-001。随后用真实单位字典维护 manage_unit_name 和 manage_unit_group，核验电子所多核算单位汇总、管理单位穿透、阶段筛选、预警和使用率排名。

## 当前阻塞
- 现有数据库必须先执行 20260721 manage_unit_group 增量脚本；新建数据库使用最新完整 DDL，不要重复执行增量脚本。
- 内网单位字典同步时必须维护 manage_unit_name 和 manage_unit_group；未维护分类的院内单位只会进入未分类院内单位。
- 自动化浏览器当前停在登录页，管理单位分组与使用率排名仍需在有登录态的环境完成最终视觉回归。
- 金额口径仍需用真实数据最终核对：账面只统计借方明细且 amount 为元、页面按万元展示。
- 真实内网 Nacos、数据库、Redis、网关、菜单权限、租户、组织和数据权限映射仍待现场确认。
