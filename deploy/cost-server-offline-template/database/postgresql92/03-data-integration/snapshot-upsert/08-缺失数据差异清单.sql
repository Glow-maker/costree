-- 只读差异清单：列出“业务表中存在，但本批全量快照未出现”的源同步记录。
-- 本脚本绝不删除或停用业务数据。确认源系统明确状态后，再随下一批传 source_deleted/disabled。

SELECT 'cost_unit_dict' AS business_table,
       d.accounting_unit_code AS business_key,
       d.accounting_unit_name AS display_name,
       '本批单位快照未出现，不自动删除' AS difference
FROM "costree_mvp".cost_unit_dict d
CROSS JOIN cost_sync_stage.sync_control c
WHERE c.id = 1 AND d.tenant_id = c.tenant_id
  AND (d.creator = c.source_tag OR d.updater = c.source_tag)
  AND NOT EXISTS (
      SELECT 1 FROM cost_sync_stage.stg_unit_dict s
      WHERE s.accounting_unit_code = d.accounting_unit_code
  )
ORDER BY d.accounting_unit_code;

SELECT 'cost_model_node' AS business_table,
       n.node_code AS business_key,
       n.node_name AS display_name,
       '本批型号树快照未出现，不自动删除' AS difference
FROM "costree_mvp".cost_model_node n
CROSS JOIN cost_sync_stage.sync_control c
WHERE c.id = 1 AND n.tenant_id = c.tenant_id
  AND (n.creator = c.source_tag OR n.updater = c.source_tag)
  AND NOT EXISTS (
      SELECT 1 FROM cost_sync_stage.stg_model_node s WHERE s.node_code = n.node_code
  )
ORDER BY n.node_code;

SELECT 'cost_project' AS business_table,
       p.project_code AS business_key,
       p.project_name AS display_name,
       '本批项目快照未出现，不自动删除' AS difference
FROM "costree_mvp".cost_project p
CROSS JOIN cost_sync_stage.sync_control c
WHERE c.id = 1 AND p.tenant_id = c.tenant_id
  AND (p.creator = c.source_tag OR p.updater = c.source_tag)
  AND NOT EXISTS (
      SELECT 1 FROM cost_sync_stage.stg_project s WHERE s.project_code = p.project_code
  )
ORDER BY p.project_code;

SELECT 'cost_unit_cost_detail' AS business_table,
       x.project_code || ' | ' || x.unit_name AS business_key,
       x.project_name AS display_name,
       '本批预分预控快照未出现，保留合同、到款、目标和审定' AS difference
FROM "costree_mvp".cost_unit_cost_detail x
CROSS JOIN cost_sync_stage.sync_control c
WHERE c.id = 1 AND x.tenant_id = c.tenant_id
  AND (x.source_record_id IS NOT NULL OR x.creator = c.source_tag OR x.updater = c.source_tag)
  AND NOT EXISTS (
      SELECT 1
      FROM cost_sync_stage.stg_unit_amount s
      JOIN "costree_mvp".cost_unit_dict u
        ON u.tenant_id = c.tenant_id AND u.accounting_unit_code = s.accounting_unit_code
      WHERE (s.source_record_id IS NOT NULL AND s.source_record_id = x.source_record_id)
         OR (s.project_code = x.project_code AND u.accounting_unit_name = x.unit_name)
  )
ORDER BY x.project_code, x.unit_name;

SELECT 'cost_work_order' AS business_table,
       w.project_code || ' | ' || w.unit_name || ' | ' || w.work_order_no AS business_key,
       w.work_order_name AS display_name,
       '本批工作令快照未出现，保留填报和账面数据' AS difference
FROM "costree_mvp".cost_work_order w
CROSS JOIN cost_sync_stage.sync_control c
WHERE c.id = 1 AND w.tenant_id = c.tenant_id
  AND (w.source_work_order_id IS NOT NULL OR w.creator = c.source_tag OR w.updater = c.source_tag)
  AND NOT EXISTS (
      SELECT 1
      FROM cost_sync_stage.stg_work_order s
      JOIN "costree_mvp".cost_unit_dict u
        ON u.tenant_id = c.tenant_id AND u.accounting_unit_code = s.accounting_unit_code
      WHERE (s.source_work_order_id IS NOT NULL AND s.source_work_order_id = w.source_work_order_id)
         OR (s.project_code = w.project_code
             AND u.accounting_unit_name = w.unit_name
             AND s.work_order_no = w.work_order_no)
  )
ORDER BY w.project_code, w.unit_name, w.work_order_no;

SELECT 'cost_work_order_ledger_detail' AS business_table,
       d.source_detail_id AS business_key,
       COALESCE(d.voucher_no, '') || ' | ' || COALESCE(d.work_order_no, '') AS display_name,
       '本批账面快照未出现，不自动删除或冲销' AS difference
FROM "costree_mvp".cost_work_order_ledger_detail d
CROSS JOIN cost_sync_stage.sync_control c
WHERE c.id = 1 AND d.tenant_id = c.tenant_id
  AND (d.creator = c.source_tag OR d.updater = c.source_tag)
  AND NOT EXISTS (
      SELECT 1 FROM cost_sync_stage.stg_ledger_detail s
      WHERE s.source_detail_id = d.source_detail_id
  )
ORDER BY d.source_detail_id;

-- 本批明确传入的停用/删除状态，供人工复核。
SELECT 'unit_dict' AS source_object, accounting_unit_code AS business_key,
       source_deleted, disabled
FROM cost_sync_stage.stg_unit_dict
WHERE lower(btrim(COALESCE(source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
   OR lower(btrim(COALESCE(disabled, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
UNION ALL
SELECT 'work_order', project_code || ' | ' || accounting_unit_code || ' | ' || work_order_no,
       source_deleted, disabled
FROM cost_sync_stage.stg_work_order
WHERE lower(btrim(COALESCE(source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
   OR lower(btrim(COALESCE(disabled, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
ORDER BY source_object, business_key;
