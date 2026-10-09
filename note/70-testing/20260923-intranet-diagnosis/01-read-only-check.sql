-- PostgreSQL 9.2+ / DWS: READ ONLY. Do not run in MySQL or DM.
-- Replace public with the actual cost schema. Replace tenant 124 in each params CTE if needed.
-- For unit checks, replace REPLACE_WITH_UNIT_NAME with the exact name displayed in the cost tree.
-- This script changes no business data, schema, migration records, or permissions.
BEGIN READ ONLY;
SET LOCAL search_path TO "public";
SELECT version(), current_database(), current_schema(), current_user;

-- A: Project metadata used by DOMAIN/MODEL filter options (NOT cost_model_node).
WITH params AS (SELECT 124::bigint AS tenant_id)
SELECT count(*) AS active_projects,
 sum(CASE WHEN NULLIF(btrim(p.domain_code), '') IS NULL THEN 1 ELSE 0 END) AS missing_domain_code,
 sum(CASE WHEN NULLIF(btrim(p.model_code), '') IS NULL THEN 1 ELSE 0 END) AS missing_model_code
FROM cost_project p, params x WHERE p.tenant_id=x.tenant_id AND p.deleted=0;

-- B: Ledger rows eligible before role, unit, phase and voucher-date filters.
-- project_not_matched means project_code/tenant/deleted mismatch; no matching eligible work order
-- also excludes a row. A matching work order needs project + number + exact accounting-unit name.
WITH params AS (SELECT 124::bigint AS tenant_id), rows AS (
 SELECT d.project_code, d.accounting_unit_name, d.work_order_no,
 EXISTS (SELECT 1 FROM cost_project p WHERE p.tenant_id=d.tenant_id
  AND p.deleted=0 AND p.project_code=d.project_code) AS project_found,
 EXISTS (SELECT 1 FROM cost_project p WHERE p.tenant_id=d.tenant_id
  AND p.deleted=0 AND p.project_code=d.project_code
  AND NULLIF(btrim(p.domain_code),'') IS NOT NULL) AS domain_found,
 EXISTS (SELECT 1 FROM cost_project p WHERE p.tenant_id=d.tenant_id
  AND p.deleted=0 AND p.project_code=d.project_code
  AND NULLIF(btrim(p.model_code),'') IS NOT NULL) AS model_found,
 EXISTS (SELECT 1 FROM cost_work_order w WHERE w.tenant_id=d.tenant_id AND w.deleted=0
  AND (w.vertical_division IS NULL OR w.vertical_division=TRUE)
  AND w.project_code=d.project_code AND w.work_order_no=d.work_order_no
  AND w.unit_name=d.accounting_unit_name) AS work_order_found
 FROM cost_work_order_ledger_detail d, params x
 WHERE d.tenant_id=x.tenant_id AND d.deleted=0 AND btrim(d.debit_credit)='借'
)
SELECT count(*) AS debit_rows,
 sum(CASE WHEN NOT project_found THEN 1 ELSE 0 END) AS project_not_matched,
 sum(CASE WHEN NOT work_order_found THEN 1 ELSE 0 END) AS vertical_work_order_not_matched,
 sum(CASE WHEN project_found AND work_order_found AND domain_found THEN 1 ELSE 0 END) AS rows_with_domain,
 sum(CASE WHEN project_found AND work_order_found AND model_found THEN 1 ELSE 0 END) AS rows_with_model
FROM rows;

-- C: Baseline available options; this does NOT replicate the logged-in account's access scope.
-- Nonempty here + empty API can mean current page filters, access scope, API errors, or client state.
WITH params AS (SELECT 124::bigint AS tenant_id)
SELECT p.domain_code, p.domain_name, p.model_code, p.model_name, count(*) AS ledger_rows
FROM cost_work_order_ledger_detail d
JOIN cost_project p ON p.tenant_id=d.tenant_id AND p.project_code=d.project_code AND p.deleted=0
JOIN params x ON x.tenant_id=d.tenant_id
WHERE d.deleted=0 AND btrim(d.debit_credit)='借'
 AND EXISTS (SELECT 1 FROM cost_work_order w WHERE w.tenant_id=d.tenant_id AND w.deleted=0
  AND (w.vertical_division IS NULL OR w.vertical_division=TRUE)
  AND w.project_code=d.project_code AND w.work_order_no=d.work_order_no
  AND w.unit_name=d.accounting_unit_name)
GROUP BY p.domain_code,p.domain_name,p.model_code,p.model_name
ORDER BY p.domain_code,p.model_code LIMIT 100;

-- D: Actual cost dictionary flags, including disabled/deleted rows for diagnosis.
-- inside_institute=false means outside institute even when inside_group=true.
WITH params AS (SELECT 124::bigint AS tenant_id, 'REPLACE_WITH_UNIT_NAME'::text AS unit_name)
SELECT u.id,u.accounting_unit_code,u.accounting_unit_name,u.contact_unit_name,
 u.manage_unit_code,u.manage_unit_name,u.manage_unit_group,u.inside_institute,u.inside_group,
 u.status,u.deleted,u.tenant_id
FROM cost_unit_dict u,params x
WHERE u.tenant_id=x.tenant_id AND
 (btrim(u.accounting_unit_name)=btrim(x.unit_name) OR btrim(u.contact_unit_name)=btrim(x.unit_name)
  OR btrim(u.manage_unit_name)=btrim(x.unit_name))
ORDER BY u.inside_institute DESC,u.manage_unit_code,u.accounting_unit_code;

-- E: Exact active name match used by frontend; zero active matches currently defaults to INNER.
WITH params AS (SELECT 124::bigint AS tenant_id, 'REPLACE_WITH_UNIT_NAME'::text AS unit_name)
SELECT x.unit_name,count(u.id) AS enabled_name_matches
FROM params x LEFT JOIN cost_unit_dict u ON u.tenant_id=x.tenant_id AND u.deleted=0
 AND u.status='ENABLE' AND (btrim(u.accounting_unit_name)=btrim(x.unit_name)
 OR btrim(u.contact_unit_name)=btrim(x.unit_name))
GROUP BY x.unit_name;
ROLLBACK;
