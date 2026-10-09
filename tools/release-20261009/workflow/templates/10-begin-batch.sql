-- 一个批次只启动一次；默认占位值不能执行。失败批次先查原因，不得自动清空重开。
BEGIN;
LOCK TABLE cost_sync_stage_v20261009.sync_control IN EXCLUSIVE MODE;
DO $$ BEGIN
 IF '__BATCH_CODE__' LIKE 'REPLACE%' OR '__SNAPSHOT_TAG__' LIKE 'REPLACE%' THEN
   RAISE EXCEPTION '批次号和一致快照标识未适配';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM cost_sync_stage_v20261009.sync_control WHERE id=1
    AND load_status IN ('EMPTY','SUCCESS','ABORTED')) THEN
   RAISE EXCEPTION '上一批仍在处理或失败待核查，拒绝并发/自动重置';
 END IF;
END $$;
INSERT INTO cost_sync_stage_v20261009.batch_register(batch_code,tenant_id,snapshot_tag)
VALUES ('__BATCH_CODE__',__TENANT_ID__,'__SNAPSHOT_TAG__');
TRUNCATE TABLE cost_sync_stage_v20261009.stg_unit_dict,cost_sync_stage_v20261009.stg_model_node,
 cost_sync_stage_v20261009.stg_project,cost_sync_stage_v20261009.stg_unit_amount,
 cost_sync_stage_v20261009.stg_work_order,cost_sync_stage_v20261009.stg_ledger_detail;
UPDATE cost_sync_stage_v20261009.sync_control SET tenant_id=__TENANT_ID__,batch_code='__BATCH_CODE__',
 source_tag='cost_snapshot_sync',load_status='LOADING',loaded_at=NULL,synced_at=NULL,
 remark='20261009 完整快照装载；任何业务更新尚未开始' WHERE id=1;
COMMIT;
SELECT * FROM cost_sync_stage_v20261009.sync_control WHERE id=1;
