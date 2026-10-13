-- 清理外部数据源闭环演示数据（PostgreSQL）
-- 只处理两个专用项目和 cost_demo_source 数据，不清理其他 seed/真实数据。

BEGIN;

CREATE TEMP TABLE tmp_demo_cleanup_context ON COMMIT DROP AS
SELECT tenant_id, batch_code, source_tag
FROM cost_demo_source.demo_config
WHERE id = 1;

CREATE TEMP TABLE tmp_demo_cleanup_project (id int8 PRIMARY KEY) ON COMMIT DROP;
INSERT INTO tmp_demo_cleanup_project
SELECT id FROM public.cost_project
WHERE tenant_id = (SELECT tenant_id FROM tmp_demo_cleanup_context)
  AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002');

CREATE TEMP TABLE tmp_demo_cleanup_work_order (id int8 PRIMARY KEY) ON COMMIT DROP;
INSERT INTO tmp_demo_cleanup_work_order
SELECT id FROM public.cost_work_order
WHERE tenant_id = (SELECT tenant_id FROM tmp_demo_cleanup_context)
  AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002');

CREATE TEMP TABLE tmp_demo_cleanup_batch (id int8 PRIMARY KEY) ON COMMIT DROP;
INSERT INTO tmp_demo_cleanup_batch
SELECT id FROM public.cost_import_batch
WHERE tenant_id = (SELECT tenant_id FROM tmp_demo_cleanup_context)
  AND import_type = 'DEMO_SOURCE_SYNC'
  AND file_name = (SELECT batch_code FROM tmp_demo_cleanup_context);

DELETE FROM public.cost_warning_record
WHERE tenant_id = (SELECT tenant_id FROM tmp_demo_cleanup_context)
  AND (
      project_id IN (SELECT id FROM tmp_demo_cleanup_project)
      OR work_order_id IN (SELECT id FROM tmp_demo_cleanup_work_order)
  );

DELETE FROM public.cost_import_error
WHERE tenant_id = (SELECT tenant_id FROM tmp_demo_cleanup_context)
  AND batch_id IN (SELECT id FROM tmp_demo_cleanup_batch);

DELETE FROM public.cost_import_batch
WHERE id IN (SELECT id FROM tmp_demo_cleanup_batch);

DELETE FROM public.cost_work_order_ledger_detail
WHERE tenant_id = (SELECT tenant_id FROM tmp_demo_cleanup_context)
  AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002');

DELETE FROM public.cost_work_order
WHERE tenant_id = (SELECT tenant_id FROM tmp_demo_cleanup_context)
  AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002');

DELETE FROM public.cost_unit_cost_detail
WHERE tenant_id = (SELECT tenant_id FROM tmp_demo_cleanup_context)
  AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002');

DELETE FROM public.cost_project_basic
WHERE tenant_id = (SELECT tenant_id FROM tmp_demo_cleanup_context)
  AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002');

DELETE FROM public.cost_project
WHERE id IN (SELECT id FROM tmp_demo_cleanup_project);

DELETE FROM public.cost_model_node
WHERE tenant_id = (SELECT tenant_id FROM tmp_demo_cleanup_context)
  AND node_code IN ('MODEL_DEMO_UNIT_HIERARCHY', 'MODEL_DEMO_YEARLY');

DELETE FROM public.cost_model_node n
WHERE n.tenant_id = (SELECT tenant_id FROM tmp_demo_cleanup_context)
  AND n.node_code = 'SERIES_DEMO_UNIT'
  AND NOT EXISTS (
      SELECT 1 FROM public.cost_model_node child
      WHERE child.tenant_id = n.tenant_id AND child.parent_id = n.id
  );

DELETE FROM public.cost_model_node n
WHERE n.tenant_id = (SELECT tenant_id FROM tmp_demo_cleanup_context)
  AND n.node_code = 'DOMAIN_DEMO'
  AND NOT EXISTS (
      SELECT 1 FROM public.cost_model_node child
      WHERE child.tenant_id = n.tenant_id AND child.parent_id = n.id
  );

-- 单位字典是共享基础数据。只删除脚本创建且已无业务引用的 DEMO 单位；
-- 如果同步前目标库已存在同名单位，脚本只更新它，清理时不会删除该行。
DELETE FROM public.cost_unit_dict d
WHERE d.tenant_id = (SELECT tenant_id FROM tmp_demo_cleanup_context)
  AND d.accounting_unit_id LIKE 'DEMO-ACCT-%'
  AND d.creator IN ('cost_demo', (SELECT source_tag FROM tmp_demo_cleanup_context))
  AND NOT EXISTS (
      SELECT 1 FROM public.cost_unit_cost_detail c
      WHERE c.tenant_id = d.tenant_id AND c.unit_name = d.accounting_unit_name
  )
  AND NOT EXISTS (
      SELECT 1 FROM public.cost_work_order w
      WHERE w.tenant_id = d.tenant_id AND w.unit_name = d.accounting_unit_name
  )
  AND NOT EXISTS (
      SELECT 1 FROM public.cost_work_order_ledger_detail l
      WHERE l.tenant_id = d.tenant_id AND l.accounting_unit_name = d.accounting_unit_name
  );

TRUNCATE TABLE
    cost_demo_source.dws_bu_pz_pzmx_gzl,
    cost_demo_source.work_order_fill,
    cost_demo_source.project_office_fill,
    cost_demo_source.precontrol_project_unit_amount,
    cost_demo_source.dwd_bd_bfcustomitem_gzl,
    cost_demo_source.ads_lc_lshsxm2022,
    cost_demo_source.unit_dict;

COMMIT;

SELECT '演示数据已清理，cost_demo_source schema 和 demo_config 保留' AS result;
