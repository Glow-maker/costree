-- 创建独立手工数据保护层。不会修改或清空成本业务表。
-- PostgreSQL 9.2.4 / GaussDB(DWS) 8.2.1 兼容。

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'cost_manual_snapshot') THEN
        EXECUTE 'CREATE SCHEMA cost_manual_snapshot';
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS cost_manual_snapshot.snapshot_control
(
    id                 int2        NOT NULL DEFAULT 1,
    current_batch_code varchar(64),
    tenant_id          int8,
    snapshot_status    varchar(32) NOT NULL DEFAULT 'EMPTY',
    snapshot_at        timestamp,
    restored_at        timestamp,
    remark             varchar(1000),
    CONSTRAINT pk_cost_manual_snapshot_control PRIMARY KEY (id),
    CONSTRAINT ck_cost_manual_snapshot_control_single CHECK (id = 1)
);
INSERT INTO cost_manual_snapshot.snapshot_control(id, snapshot_status, remark)
SELECT 1, 'EMPTY', '仅用于旧清库工作流或灾备；不能替代整库备份'
WHERE NOT EXISTS (SELECT 1 FROM cost_manual_snapshot.snapshot_control WHERE id = 1);

CREATE TABLE IF NOT EXISTS cost_manual_snapshot.snapshot_count
(
    batch_code  varchar(64) NOT NULL,
    tenant_id   int8        NOT NULL,
    object_name varchar(64) NOT NULL,
    row_count   int8        NOT NULL,
    CONSTRAINT pk_cost_manual_snapshot_count PRIMARY KEY (batch_code, tenant_id, object_name)
);

CREATE TABLE IF NOT EXISTS cost_manual_snapshot.restore_exception
(
    batch_code   varchar(64)  NOT NULL,
    tenant_id    int8         NOT NULL,
    object_name  varchar(64)  NOT NULL,
    business_key varchar(1000),
    reason        varchar(1000) NOT NULL,
    created_at    timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cost_manual_snapshot.project_state AS
SELECT ''::varchar(64) AS batch_code, project.*
FROM "costree_mvp".cost_project project WHERE false;

CREATE TABLE IF NOT EXISTS cost_manual_snapshot.project_basic AS
SELECT ''::varchar(64) AS batch_code, basic.*
FROM "costree_mvp".cost_project_basic basic WHERE false;

CREATE TABLE IF NOT EXISTS cost_manual_snapshot.unit_fill AS
SELECT ''::varchar(64) AS batch_code, unit_cost.*
FROM "costree_mvp".cost_unit_cost_detail unit_cost WHERE false;

CREATE TABLE IF NOT EXISTS cost_manual_snapshot.work_order_fill AS
SELECT ''::varchar(64) AS batch_code, work_order.*
FROM "costree_mvp".cost_work_order work_order WHERE false;

CREATE TABLE IF NOT EXISTS cost_manual_snapshot.warning_state AS
SELECT ''::varchar(64) AS batch_code, warning.*,
       ''::varchar(128) AS project_code_key,
       ''::varchar(255) AS work_order_unit_key,
       ''::varchar(128) AS work_order_no_key
FROM "costree_mvp".cost_warning_record warning WHERE false;

CREATE OR REPLACE FUNCTION pg_temp.cost_manual_add_warning_column(p_name text, p_definition text)
RETURNS void AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='cost_manual_snapshot' AND table_name='warning_state'
                     AND column_name=p_name) THEN
        EXECUTE 'ALTER TABLE cost_manual_snapshot.warning_state ADD COLUMN ' || quote_ident(p_name) || ' ' || p_definition;
    END IF;
END $$ LANGUAGE plpgsql;
SELECT pg_temp.cost_manual_add_warning_column('project_code','varchar(100)');
SELECT pg_temp.cost_manual_add_warning_column('project_name','varchar(255)');
SELECT pg_temp.cost_manual_add_warning_column('domain_code','varchar(100)');
SELECT pg_temp.cost_manual_add_warning_column('domain_name','varchar(255)');
SELECT pg_temp.cost_manual_add_warning_column('model_code','varchar(100)');
SELECT pg_temp.cost_manual_add_warning_column('model_name','varchar(255)');
SELECT pg_temp.cost_manual_add_warning_column('cycle_no','int4');
SELECT pg_temp.cost_manual_add_warning_column('workflow_status','varchar(32)');
SELECT pg_temp.cost_manual_add_warning_column('active_marker','int2');
SELECT pg_temp.cost_manual_add_warning_column('initiator_user_id','int8');
SELECT pg_temp.cost_manual_add_warning_column('initiator_user_name','varchar(128)');
SELECT pg_temp.cost_manual_add_warning_column('initiated_time','timestamp');
SELECT pg_temp.cost_manual_add_warning_column('disposition_user_id','int8');
SELECT pg_temp.cost_manual_add_warning_column('disposition_user_name','varchar(128)');
SELECT pg_temp.cost_manual_add_warning_column('cause_analysis','varchar(1000)');
SELECT pg_temp.cost_manual_add_warning_column('disposal_measure','varchar(1000)');
SELECT pg_temp.cost_manual_add_warning_column('expected_completion_date','date');
SELECT pg_temp.cost_manual_add_warning_column('disposition_time','timestamp');
SELECT pg_temp.cost_manual_add_warning_column('close_user_id','int8');
SELECT pg_temp.cost_manual_add_warning_column('close_user_name','varchar(128)');
SELECT pg_temp.cost_manual_add_warning_column('close_time','timestamp');
SELECT pg_temp.cost_manual_add_warning_column('return_reason','varchar(500)');

CREATE TABLE IF NOT EXISTS cost_manual_snapshot.warning_receiver AS
SELECT ''::varchar(64) AS batch_code, receiver.*
FROM "costree_mvp".cost_warning_receiver receiver WHERE false;

-- v2 独立表固定保存 20260820 后的完整预警任务结构，避免旧 warning_state 列顺序影响恢复。
CREATE TABLE IF NOT EXISTS cost_manual_snapshot.warning_state_v2 AS
SELECT ''::varchar(64) AS batch_code, warning.*,
       ''::varchar(128) AS project_code_key,
       ''::varchar(255) AS work_order_unit_key,
       ''::varchar(128) AS work_order_no_key
FROM "costree_mvp".cost_warning_record warning WHERE false;

CREATE TABLE IF NOT EXISTS cost_manual_snapshot.warning_action_log AS
SELECT ''::varchar(64) AS batch_code, action_log.*
FROM "costree_mvp".cost_warning_action_log action_log WHERE false;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'cost_manual_snapshot' AND indexname = 'idx_cost_manual_project_batch') THEN
        EXECUTE 'CREATE INDEX idx_cost_manual_project_batch ON cost_manual_snapshot.project_state (batch_code, tenant_id, project_code)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'cost_manual_snapshot' AND indexname = 'idx_cost_manual_basic_batch') THEN
        EXECUTE 'CREATE INDEX idx_cost_manual_basic_batch ON cost_manual_snapshot.project_basic (batch_code, tenant_id, project_code)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'cost_manual_snapshot' AND indexname = 'idx_cost_manual_unit_batch') THEN
        EXECUTE 'CREATE INDEX idx_cost_manual_unit_batch ON cost_manual_snapshot.unit_fill (batch_code, tenant_id, project_code, unit_name)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'cost_manual_snapshot' AND indexname = 'idx_cost_manual_work_order_batch') THEN
        EXECUTE 'CREATE INDEX idx_cost_manual_work_order_batch ON cost_manual_snapshot.work_order_fill (batch_code, tenant_id, project_code, unit_name, work_order_no)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'cost_manual_snapshot' AND indexname = 'idx_cost_manual_warning_batch') THEN
        EXECUTE 'CREATE INDEX idx_cost_manual_warning_batch ON cost_manual_snapshot.warning_state (batch_code, tenant_id, id)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'cost_manual_snapshot' AND indexname = 'idx_cost_manual_warning_receiver_batch') THEN
        EXECUTE 'CREATE INDEX idx_cost_manual_warning_receiver_batch ON cost_manual_snapshot.warning_receiver (batch_code, tenant_id, warning_record_id, user_id)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'cost_manual_snapshot' AND indexname = 'idx_cost_manual_warning_v2_batch') THEN
        EXECUTE 'CREATE INDEX idx_cost_manual_warning_v2_batch ON cost_manual_snapshot.warning_state_v2 (batch_code, tenant_id, id)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'cost_manual_snapshot' AND indexname = 'idx_cost_manual_warning_action_batch') THEN
        EXECUTE 'CREATE INDEX idx_cost_manual_warning_action_batch ON cost_manual_snapshot.warning_action_log (batch_code, tenant_id, warning_record_id, id)';
    END IF;
END $$;

COMMIT;

SELECT 'cost_manual_snapshot ready' AS result;
