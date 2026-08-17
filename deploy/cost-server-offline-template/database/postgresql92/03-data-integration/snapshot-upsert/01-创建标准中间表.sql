-- 成本库全量快照中间表。
-- PostgreSQL 9.2.4 / GaussDB 8.2.1 兼容。
-- 本脚本只创建 cost_sync_stage，不修改成本库业务数据。

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata
        WHERE schema_name = 'cost_sync_stage'
    ) THEN
        EXECUTE 'CREATE SCHEMA cost_sync_stage';
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS cost_sync_stage.sync_control
(
    id          int2        NOT NULL DEFAULT 1,
    tenant_id   int8        NOT NULL DEFAULT 124,
    batch_code  varchar(64) NOT NULL DEFAULT 'COST-SNAPSHOT-BATCH',
    source_tag  varchar(64) NOT NULL DEFAULT 'cost_snapshot_sync',
    load_status varchar(16) NOT NULL DEFAULT 'EMPTY',
    loaded_at   timestamp   NULL,
    synced_at   timestamp   NULL,
    remark      varchar(500),
    CONSTRAINT pk_cost_sync_stage_control PRIMARY KEY (id),
    CONSTRAINT ck_cost_sync_stage_control_single CHECK (id = 1)
);

INSERT INTO cost_sync_stage.sync_control (
    id, tenant_id, batch_code, source_tag, load_status, remark
)
SELECT 1, 124, 'COST-SNAPSHOT-BATCH', 'cost_snapshot_sync', 'EMPTY',
       '只清空中间表，业务表按业务键 UPDATE + INSERT'
WHERE NOT EXISTS (
    SELECT 1 FROM cost_sync_stage.sync_control WHERE id = 1
);

CREATE TABLE IF NOT EXISTS cost_sync_stage.sync_history
(
    batch_code       varchar(64)  NOT NULL,
    tenant_id        int8         NOT NULL,
    source_tag       varchar(64)  NOT NULL,
    stage_row_count  int8         NOT NULL DEFAULT 0,
    sync_status      varchar(16)  NOT NULL,
    start_time       timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finish_time      timestamp    NULL,
    remark           varchar(500)
);

CREATE TABLE IF NOT EXISTS cost_sync_stage.stg_unit_dict
(
    source_record_id     varchar(255),
    accounting_unit_id   varchar(255),
    accounting_unit_code varchar(255),
    accounting_unit_name varchar(255),
    manage_unit_code     varchar(255),
    manage_unit_name     varchar(255),
    manage_unit_group    varchar(32),
    contact_unit_code    varchar(255),
    contact_unit_name    varchar(255),
    inside_group         varchar(16),
    inside_institute     varchar(16),
    disabled             varchar(16),
    source_update_time   varchar(64),
    source_deleted       varchar(16)
);

CREATE TABLE IF NOT EXISTS cost_sync_stage.stg_model_node
(
    node_code          varchar(255),
    parent_node_code   varchar(255),
    node_name          varchar(255),
    node_type          varchar(32),
    domain_code        varchar(128),
    sort_no            varchar(32),
    status             varchar(32),
    source_update_time varchar(64),
    source_deleted     varchar(16)
);

CREATE TABLE IF NOT EXISTS cost_sync_stage.stg_project
(
    source_project_id  varchar(255),
    project_code       varchar(255),
    project_name       varchar(255),
    model_node_code    varchar(255),
    domain_code        varchar(128),
    domain_name        varchar(255),
    category_code      varchar(128),
    category_name      varchar(255),
    model_code         varchar(128),
    model_name         varchar(255),
    source_update_time varchar(64),
    source_deleted     varchar(16)
);

CREATE TABLE IF NOT EXISTS cost_sync_stage.stg_unit_amount
(
    source_record_id     varchar(255),
    source_update_time   varchar(64),
    project_code         varchar(255),
    project_name         varchar(255),
    accounting_unit_code varchar(255),
    contract_amount_wan  varchar(64),
    income_amount_wan    varchar(64),
    source_deleted       varchar(16)
);

CREATE TABLE IF NOT EXISTS cost_sync_stage.stg_work_order
(
    source_work_order_id varchar(255),
    project_code         varchar(255),
    project_name         varchar(255),
    accounting_unit_code varchar(255),
    work_order_no        varchar(255),
    work_order_name      varchar(255),
    disabled             varchar(16),
    source_update_time   varchar(64),
    source_deleted       varchar(16)
);

CREATE TABLE IF NOT EXISTS cost_sync_stage.stg_ledger_detail
(
    source_detail_id     varchar(255),
    fiscal_year          varchar(16),
    accounting_period    varchar(16),
    voucher_date         varchar(32),
    voucher_no           varchar(255),
    accounting_unit_id   varchar(255),
    accounting_unit_code varchar(255),
    subject_id           varchar(255),
    subject_code         varchar(255),
    subject_name         varchar(255),
    project_code         varchar(255),
    source_project_id    varchar(255),
    project_name         varchar(255),
    source_work_order_id varchar(255),
    work_order_no        varchar(255),
    work_order_name      varchar(255),
    debit_credit         varchar(32),
    amount_yuan          varchar(64),
    summary_text         varchar(1000),
    source_lastmodify    varchar(64),
    second_subject_code  varchar(255),
    second_subject_name  varchar(255),
    source_timestamp     varchar(64),
    source_deleted       varchar(16)
);

-- PostgreSQL 9.2 不支持 CREATE INDEX IF NOT EXISTS，使用目录判断保证幂等。
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'cost_sync_stage' AND indexname = 'idx_cost_stage_unit_code') THEN
        EXECUTE 'CREATE INDEX idx_cost_stage_unit_code ON cost_sync_stage.stg_unit_dict (accounting_unit_code)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'cost_sync_stage' AND indexname = 'idx_cost_stage_node_code') THEN
        EXECUTE 'CREATE INDEX idx_cost_stage_node_code ON cost_sync_stage.stg_model_node (node_code)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'cost_sync_stage' AND indexname = 'idx_cost_stage_project_code') THEN
        EXECUTE 'CREATE INDEX idx_cost_stage_project_code ON cost_sync_stage.stg_project (project_code)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'cost_sync_stage' AND indexname = 'idx_cost_stage_amount_key') THEN
        EXECUTE 'CREATE INDEX idx_cost_stage_amount_key ON cost_sync_stage.stg_unit_amount (project_code, accounting_unit_code)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'cost_sync_stage' AND indexname = 'idx_cost_stage_work_order_key') THEN
        EXECUTE 'CREATE INDEX idx_cost_stage_work_order_key ON cost_sync_stage.stg_work_order (project_code, accounting_unit_code, work_order_no)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'cost_sync_stage' AND indexname = 'idx_cost_stage_ledger_source') THEN
        EXECUTE 'CREATE INDEX idx_cost_stage_ledger_source ON cost_sync_stage.stg_ledger_detail (source_detail_id)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'cost_sync_stage' AND indexname = 'idx_cost_stage_ledger_business') THEN
        EXECUTE 'CREATE INDEX idx_cost_stage_ledger_business ON cost_sync_stage.stg_ledger_detail (project_code, accounting_unit_code, work_order_no)';
    END IF;
END $$;

COMMENT ON SCHEMA cost_sync_stage IS '成本库外部源全量快照中间层';
COMMENT ON TABLE cost_sync_stage.stg_unit_amount IS '预分预控合同和到款全量快照，金额单位万元';
COMMENT ON TABLE cost_sync_stage.stg_ledger_detail IS '工作令凭证明细全量快照，amount_yuan 单位元';

COMMIT;

SELECT 'cost_sync_stage created' AS result;
