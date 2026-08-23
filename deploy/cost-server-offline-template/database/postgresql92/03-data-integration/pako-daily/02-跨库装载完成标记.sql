-- PAKO_CROSS_DB_READY_MARKER
-- 适用场景：帕科已把本批六类全量数据写入 cost_sync_stage.stg_* 中间表。
-- 本文件不装载数据，只验证关键快照非空并把本批标记为 READY。
-- 必须在六张表全部写入成功后执行；失败时禁止继续业务表同步。

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cost_sync_stage.sync_control WHERE id = 1) THEN
        RAISE EXCEPTION 'sync_control 缺少 id=1，请先执行 snapshot-upsert/01-创建标准中间表.sql';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM cost_sync_stage.stg_model_node) THEN
        RAISE EXCEPTION '型号树中间表为空，拒绝把空快照标记为 READY';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM cost_sync_stage.stg_project) THEN
        RAISE EXCEPTION '项目中间表为空，拒绝把空快照标记为 READY';
    END IF;
END $$;

UPDATE cost_sync_stage.sync_control
SET load_status = 'READY',
    loaded_at = CURRENT_TIMESTAMP,
    synced_at = NULL,
    remark = '帕科跨库全量快照已装入六张标准中间表'
WHERE id = 1;

COMMIT;

SELECT 'stg_unit_dict' AS stage_table, count(*) AS row_count FROM cost_sync_stage.stg_unit_dict
UNION ALL SELECT 'stg_model_node', count(*) FROM cost_sync_stage.stg_model_node
UNION ALL SELECT 'stg_project', count(*) FROM cost_sync_stage.stg_project
UNION ALL SELECT 'stg_unit_amount', count(*) FROM cost_sync_stage.stg_unit_amount
UNION ALL SELECT 'stg_work_order', count(*) FROM cost_sync_stage.stg_work_order
UNION ALL SELECT 'stg_ledger_detail', count(*) FROM cost_sync_stage.stg_ledger_detail
ORDER BY stage_table;
