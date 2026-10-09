-- Manual recovery only: STOP scheduler and all active nodes BEFORE using this file.
-- Never use as automatic failure handler. No business table is changed.
BEGIN;
LOCK TABLE cost_sync_stage_v20261009.sync_control IN EXCLUSIVE MODE;
DO $$ BEGIN
 IF '__BATCH_CODE__' LIKE 'REPLACE%' THEN RAISE EXCEPTION '必须指定要放弃的确切批次'; END IF;
 IF NOT EXISTS(SELECT 1 FROM cost_sync_stage_v20261009.sync_control WHERE id=1
     AND batch_code='__BATCH_CODE__' AND tenant_id=__TENANT_ID__ AND load_status='LOADING') THEN
   RAISE EXCEPTION '只能放弃本版未提交的 LOADING 批次；其它状态须单独调查';
 END IF;
END $$;
UPDATE cost_sync_stage_v20261009.sync_control SET load_status='ABORTED',remark='人工确认停止所有节点后放弃；业务数据未改' WHERE id=1;
COMMIT;
