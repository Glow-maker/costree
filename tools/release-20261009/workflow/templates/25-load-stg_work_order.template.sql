-- 仅装载 stg_work_order，不得混入业务表更新。完整 SQL 在同一连接执行。
BEGIN;
LOCK TABLE cost_sync_stage_v20261009.sync_control IN EXCLUSIVE MODE;
DO $$
BEGIN
  IF '__BATCH_CODE__' LIKE 'REPLACE%' THEN RAISE EXCEPTION '必须生成本批参数'; END IF;
  IF NOT EXISTS (SELECT 1 FROM cost_sync_stage_v20261009.sync_control
      WHERE id=1 AND tenant_id=__TENANT_ID__ AND batch_code='__BATCH_CODE__'
        AND load_status='LOADING') THEN
    RAISE EXCEPTION '批次不一致或不是 LOADING；停止，不能串批';
  END IF;
END $$;

DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM cost_sync_stage_v20261009.load_receipt
   WHERE batch_code='__BATCH_CODE__' AND stage_table='stg_work_order') THEN
   RAISE EXCEPTION '本源已成功装载，不可再次追加；请跳过该成功节点';
 END IF;
END $$;
TRUNCATE TABLE cost_sync_stage_v20261009.stg_work_order;
__SOURCE_stg_work_order__
DO $$ DECLARE v_count bigint; BEGIN
 SELECT count(*) INTO v_count FROM cost_sync_stage_v20261009.stg_work_order;
 IF v_count <> __COUNT_stg_work_order__ THEN
   RAISE EXCEPTION '完整性失败 stg_work_order: expected=%, actual=%',__COUNT_stg_work_order__,v_count;
 END IF;
END $$;
INSERT INTO cost_sync_stage_v20261009.load_receipt(batch_code,stage_table,row_count,expected_rows,snapshot_tag)
SELECT '__BATCH_CODE__','stg_work_order',count(*),__COUNT_stg_work_order__,'__SNAPSHOT_TAG__'
FROM cost_sync_stage_v20261009.stg_work_order;
COMMIT;
