-- 每批全量快照开始前执行。
-- 本脚本只清空 cost_sync_stage 下的六张中间表，不清空任何 cost_* 业务表。

BEGIN;

LOCK TABLE cost_sync_stage.sync_control IN EXCLUSIVE MODE;

TRUNCATE TABLE
    cost_sync_stage.stg_unit_dict,
    cost_sync_stage.stg_model_node,
    cost_sync_stage.stg_project,
    cost_sync_stage.stg_unit_amount,
    cost_sync_stage.stg_work_order,
    cost_sync_stage.stg_ledger_detail;

UPDATE cost_sync_stage.sync_control
SET batch_code = 'COST-FULL-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS'),
    load_status = 'LOADING',
    loaded_at = NULL,
    synced_at = NULL,
    remark = '中间表已清空，等待本批全量源数据'
WHERE id = 1;

COMMIT;

SELECT id, tenant_id, batch_code, source_tag, load_status, loaded_at, synced_at
FROM cost_sync_stage.sync_control
WHERE id = 1;

SELECT 'stg_unit_dict' AS stage_table, count(*) AS row_count FROM cost_sync_stage.stg_unit_dict
UNION ALL SELECT 'stg_model_node', count(*) FROM cost_sync_stage.stg_model_node
UNION ALL SELECT 'stg_project', count(*) FROM cost_sync_stage.stg_project
UNION ALL SELECT 'stg_unit_amount', count(*) FROM cost_sync_stage.stg_unit_amount
UNION ALL SELECT 'stg_work_order', count(*) FROM cost_sync_stage.stg_work_order
UNION ALL SELECT 'stg_ledger_detail', count(*) FROM cost_sync_stage.stg_ledger_detail
ORDER BY stage_table;
