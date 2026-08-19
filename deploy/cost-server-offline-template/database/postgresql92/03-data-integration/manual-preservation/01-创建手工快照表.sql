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
END $$;

COMMIT;

SELECT 'cost_manual_snapshot ready' AS result;
