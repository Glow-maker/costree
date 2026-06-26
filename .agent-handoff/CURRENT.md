# 当前状态

- 最近更新时间：2026-06-26 10:25:00 +0800
- 当前阶段：第一阶段 MVP 实现、真实数据对齐和内网部署准备收口中
- 当前目标：在已有业务中台中嵌入成本库/成本树业务模块，让成本库数据可进入、可维护、可查询、可控权限，并用 note 文档中心和 .agent-handoff 形成可持续接管、开发、收尾和经验沉淀机制。
- 当前摘要：本轮继续围绕真实数据试点和业务部门反馈收口：前端已调整 /cost/catalog 目录页布局与卡片入口、/cost/tree-detail 树详情金额展示、阶段文案、预警口径和多单位矩阵视图，/cost/tree-unit-detail 简化工作令展示并支持阶段筛选；后端已支持同项目同单位同工作令编号跨年合并、单位目标成本按 cost_unit_cost_detail 口径展示，并补充单位审定金额、工作令合同金额等字段。最后完成 /cost/collect 项目办填报字段调整：新增是否产品附件/发射车、是否免税，承研单位改从 cost_unit_dict 下拉，对手单位/竞价字段接入展示和保存，并同步 MySQL/PostgreSQL DDL 与增量脚本。前后端代码均已提交并推送。

## 已完成进展
- TASK-025: 调整成本树与单位穿透页展示口径
- TASK-026: 支持跨年同编号工作令页面合并
- TASK-027: 补齐 /cost/collect 项目办填报字段

## 下一步建议
- 内网部署或本地验证前，先在目标库执行新增字段增量 SQL：cost_unit_cost_detail.approved_amount、cost_work_order.contract_amount、cost_project_basic.product_attachment_type 与 tax_exempt。随后重启后端并手工核验 /cost/collect、/cost/catalog、/cost/tree-detail、/cost/tree-unit-detail；两个型号试点继续补齐 cost_unit_cost_detail 单位目标/合同/到款/审定、cost_work_order 工作令合同/阶段/分系统/纵向分工等字段，并用账面明细核对八项支出组成。

## 当前阻塞
- 内网真实库上线前必须执行本轮新增的 ALTER 脚本，否则 /cost/collect 保存 project_basic 会缺列。
- 金额口径仍待财务确认：dws_bu_pz_pzmx_gzl.je 是元还是万元，以及 jzfx 借贷方向、冲销规则是否影响正负。
- 主业项目树解析口径仍待确认：哪个父节点字段最权威，哪一级作为成本库 MODEL，领域和系列如何生成。
- 工作令唯一口径已明确页面侧需跨年合并同编号，但导入侧仍需确认 source_work_order_id、work_order_no、fiscal_year、accounting_unit_code 的唯一和匹配规则。
- 真实内网 Nacos、PostgreSQL/MySQL、Redis、网关、菜单权限、租户、组织和数据权限映射仍待现场确认。
