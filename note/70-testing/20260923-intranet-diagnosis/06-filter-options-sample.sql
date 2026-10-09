-- Diagnostic only: no data changes. Run in the intranet database shown in the screenshots.
-- Confirm schema costree_mvp and tenant 124. Cancel any older running query first.
-- Select and run this WHOLE block, not only the final SELECT.
-- If it times out/errors, execute ROLLBACK alone in the SAME session and stop.
-- LIMIT bounds the sample size, not the underlying scan cost; timeout remains necessary.
-- Results describe only these sampled rows, not the complete database or user permissions.
-- 2026-10-09: project_found=false explains the old all-option inner join.
-- After the filter-scope code fix, only DOMAIN/MODEL require project metadata;
-- PROJECT/MANAGE_UNIT/ACCOUNTING_UNIT/WORK_ORDER no longer require that join.
BEGIN READ ONLY;
SET LOCAL statement_timeout = '10s';

WITH sample AS (
    SELECT tenant_id, project_code, accounting_unit_code, accounting_unit_name, work_order_no
    FROM costree_mvp.cost_work_order_ledger_detail
    WHERE tenant_id = 124 AND deleted = 0 AND btrim(debit_credit) = '借'
    LIMIT 20
), checked AS (
    SELECT d.*,
        EXISTS (
            SELECT 1 FROM costree_mvp.cost_project p
            WHERE p.tenant_id = d.tenant_id AND p.deleted = 0
              AND p.project_code = d.project_code
        ) AS project_found,
        EXISTS (
            SELECT 1 FROM costree_mvp.cost_project p
            WHERE p.tenant_id = d.tenant_id AND p.deleted = 0
              AND p.project_code = d.project_code
              AND NULLIF(btrim(p.domain_code), '') IS NOT NULL
        ) AS domain_found,
        EXISTS (
            SELECT 1 FROM costree_mvp.cost_project p
            WHERE p.tenant_id = d.tenant_id AND p.deleted = 0
              AND p.project_code = d.project_code
              AND NULLIF(btrim(p.model_code), '') IS NOT NULL
        ) AS model_found,
        EXISTS (
            SELECT 1 FROM costree_mvp.cost_work_order w
            WHERE w.tenant_id = d.tenant_id AND w.deleted = 0
              AND w.project_code = d.project_code AND w.work_order_no = d.work_order_no
        ) AS work_order_found,
        EXISTS (
            SELECT 1 FROM costree_mvp.cost_work_order w
            WHERE w.tenant_id = d.tenant_id AND w.deleted = 0
              AND w.project_code = d.project_code AND w.work_order_no = d.work_order_no
              AND w.unit_name = d.accounting_unit_name
        ) AS exact_unit_work_order_found,
        EXISTS (
            SELECT 1 FROM costree_mvp.cost_work_order w
            WHERE w.tenant_id = d.tenant_id AND w.deleted = 0
              AND w.project_code = d.project_code AND w.work_order_no = d.work_order_no
              AND w.unit_name = d.accounting_unit_name
              AND (w.vertical_division IS NULL OR w.vertical_division = TRUE)
        ) AS eligible_work_order_found
    FROM sample d
)
SELECT checked.*,
    CASE
        WHEN NOT project_found THEN '项目未匹配：旧版六类选项均排除；修复后领域型号仍缺来源'
        WHEN NOT work_order_found THEN '项目和工作令编号未匹配'
        WHEN NOT exact_unit_work_order_found THEN '工作令存在，但单位名称未精确匹配'
        WHEN NOT eligible_work_order_found THEN '只匹配到横向工作令：不进入当前账面范围'
        WHEN NOT domain_found OR NOT model_found THEN '公共关联通过：核对缺少的领域或型号编码'
        ELSE '公共关联及领域型号存在：继续核对接口响应、筛选和权限'
    END AS diagnosis
FROM checked;

ROLLBACK;
