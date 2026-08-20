-- 必须通过 psql 传入 manual_batch 和 manual_tenant。
-- 示例：psql ... -v manual_batch=MANUAL-20260819-010101 -v manual_tenant=124 -f 本文件

BEGIN;
SELECT pg_advisory_xact_lock(hashtext('cost-manual-snapshot'));
LOCK TABLE cost_manual_snapshot.snapshot_control IN EXCLUSIVE MODE;

UPDATE cost_manual_snapshot.snapshot_control
SET current_batch_code = :'manual_batch', tenant_id = :'manual_tenant'::int8,
    snapshot_status = 'SNAPSHOTTING', snapshot_at = CURRENT_TIMESTAMP,
    restored_at = NULL, remark = '正在生成旧清库前手工数据快照'
WHERE id = 1;

DELETE FROM cost_manual_snapshot.snapshot_count WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8;
DELETE FROM cost_manual_snapshot.restore_exception WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8;
DELETE FROM cost_manual_snapshot.project_state WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8;
DELETE FROM cost_manual_snapshot.project_basic WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8;
DELETE FROM cost_manual_snapshot.unit_fill WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8;
DELETE FROM cost_manual_snapshot.work_order_fill WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8;
DELETE FROM cost_manual_snapshot.warning_state_v2 WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8;
DELETE FROM cost_manual_snapshot.warning_receiver WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8;
DELETE FROM cost_manual_snapshot.warning_action_log WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8;

INSERT INTO cost_manual_snapshot.project_state SELECT :'manual_batch', project.*
FROM "costree_mvp".cost_project project WHERE project.tenant_id = :'manual_tenant'::int8;
INSERT INTO cost_manual_snapshot.project_basic SELECT :'manual_batch', basic.*
FROM "costree_mvp".cost_project_basic basic WHERE basic.tenant_id = :'manual_tenant'::int8;
INSERT INTO cost_manual_snapshot.unit_fill SELECT :'manual_batch', unit_cost.*
FROM "costree_mvp".cost_unit_cost_detail unit_cost WHERE unit_cost.tenant_id = :'manual_tenant'::int8;
INSERT INTO cost_manual_snapshot.work_order_fill SELECT :'manual_batch', work_order.*
FROM "costree_mvp".cost_work_order work_order WHERE work_order.tenant_id = :'manual_tenant'::int8;
INSERT INTO cost_manual_snapshot.warning_state_v2
SELECT :'manual_batch', warning.*, project.project_code,
       work_order.unit_name, work_order.work_order_no
FROM "costree_mvp".cost_warning_record warning
LEFT JOIN "costree_mvp".cost_project project
  ON project.tenant_id = warning.tenant_id AND project.id = warning.project_id
LEFT JOIN "costree_mvp".cost_work_order work_order
  ON work_order.tenant_id = warning.tenant_id AND work_order.id = warning.work_order_id
WHERE warning.tenant_id = :'manual_tenant'::int8;
INSERT INTO cost_manual_snapshot.warning_receiver SELECT :'manual_batch', receiver.*
FROM "costree_mvp".cost_warning_receiver receiver WHERE receiver.tenant_id = :'manual_tenant'::int8;
INSERT INTO cost_manual_snapshot.warning_action_log SELECT :'manual_batch', action_log.*
FROM "costree_mvp".cost_warning_action_log action_log WHERE action_log.tenant_id = :'manual_tenant'::int8;

INSERT INTO cost_manual_snapshot.snapshot_count(batch_code, tenant_id, object_name, row_count)
SELECT :'manual_batch', :'manual_tenant'::int8, 'project_state', count(*) FROM cost_manual_snapshot.project_state WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8
UNION ALL SELECT :'manual_batch', :'manual_tenant'::int8, 'project_basic', count(*) FROM cost_manual_snapshot.project_basic WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8
UNION ALL SELECT :'manual_batch', :'manual_tenant'::int8, 'unit_fill', count(*) FROM cost_manual_snapshot.unit_fill WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8
UNION ALL SELECT :'manual_batch', :'manual_tenant'::int8, 'work_order_fill', count(*) FROM cost_manual_snapshot.work_order_fill WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8
UNION ALL SELECT :'manual_batch', :'manual_tenant'::int8, 'warning_state_v2', count(*) FROM cost_manual_snapshot.warning_state_v2 WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8
UNION ALL SELECT :'manual_batch', :'manual_tenant'::int8, 'warning_receiver', count(*) FROM cost_manual_snapshot.warning_receiver WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8
UNION ALL SELECT :'manual_batch', :'manual_tenant'::int8, 'warning_action_log', count(*) FROM cost_manual_snapshot.warning_action_log WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8;

UPDATE cost_manual_snapshot.snapshot_control
SET snapshot_status = 'SNAPSHOT_READY', remark = '手工数据快照已生成，等待清库前验收'
WHERE id = 1;

COMMIT;

SELECT * FROM cost_manual_snapshot.snapshot_count
WHERE batch_code = :'manual_batch' AND tenant_id = :'manual_tenant'::int8
ORDER BY object_name;
