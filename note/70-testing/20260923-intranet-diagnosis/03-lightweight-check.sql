-- Read-only replacement for the expensive full-ledger diagnosis, NOT an upgrade.
-- In the SAME SQL client session: cancel the previous read-only query, then ROLLBACK.
-- Confirm schema costree_mvp and tenant 124 before running these blocks ONE AT A TIME.
-- If a block times out, run its ROLLBACK alone and stop. Do not increase the timeout.

-- A: Metadata estimates only. These are NOT exact row counts.
BEGIN READ ONLY;
SET LOCAL statement_timeout = '10s';
SELECT n.nspname AS schema_name, c.relname AS table_name,
       c.reltuples AS estimated_rows
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'costree_mvp'
  AND c.relname IN ('cost_project', 'cost_work_order',
                   'cost_work_order_ledger_detail', 'cost_unit_dict');
ROLLBACK;

-- B: Actual current indexes, without executing a ledger query.
BEGIN READ ONLY;
SET LOCAL statement_timeout = '10s';
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'costree_mvp'
  AND tablename IN ('cost_project', 'cost_work_order',
                    'cost_work_order_ledger_detail', 'cost_unit_dict');
ROLLBACK;

-- C: At most 20 ledger rows, no joins/count/group/order. Empty is a fact about this
-- tenant's active debit records only; timeout is NOT evidence of no data.
BEGIN READ ONLY;
SET LOCAL statement_timeout = '10s';
SELECT project_code, work_order_no, accounting_unit_code, accounting_unit_name,
       debit_credit, resolved_stage_code
FROM costree_mvp.cost_work_order_ledger_detail
WHERE tenant_id = 124 AND deleted = 0 AND btrim(debit_credit) = '借'
LIMIT 20;
ROLLBACK;

-- D: Check ONE real row returned by C. Replace both literal placeholders below.
-- Compare returned unit_name against accounting_unit_name in C EXACTLY.
BEGIN READ ONLY;
SET LOCAL statement_timeout = '10s';
SELECT project_code, project_name, domain_code, domain_name, model_code, model_name
FROM costree_mvp.cost_project
WHERE tenant_id = 124 AND deleted = 0
  AND project_code = 'REPLACE_PROJECT_CODE_FROM_C'
LIMIT 20;
ROLLBACK;

BEGIN READ ONLY;
SET LOCAL statement_timeout = '10s';
SELECT project_code, work_order_no, unit_name, vertical_division
FROM costree_mvp.cost_work_order
WHERE tenant_id = 124 AND deleted = 0
  AND project_code = 'REPLACE_PROJECT_CODE_FROM_C'
  AND work_order_no = 'REPLACE_WORK_ORDER_NO_FROM_C'
LIMIT 20;
ROLLBACK;
