-- Isolated test schema fixture. CREATE SEQUENCE/TABLE definitions copied from
-- <backend-root>/sql/postgresql92/costree-cost.sql on 2026-10-09.
-- Version guards, production indexes and migration writes intentionally excluded.
-- Caller must set search_path to its newly created costree_workflow_audit_*_biz schema.
CREATE SEQUENCE cost_model_node_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE SEQUENCE cost_project_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE SEQUENCE cost_project_basic_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE SEQUENCE cost_work_order_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE SEQUENCE cost_work_order_ledger_detail_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE SEQUENCE cost_unit_dict_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE SEQUENCE cost_subsystem_dict_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE SEQUENCE cost_unit_cost_detail_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE SEQUENCE cost_import_batch_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE SEQUENCE cost_import_error_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE SEQUENCE cost_warning_record_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE SEQUENCE cost_warning_receiver_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE SEQUENCE cost_warning_action_log_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE SEQUENCE cost_user_project_scope_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE SEQUENCE cost_user_unit_scope_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE SEQUENCE cost_user_domain_scope_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE TABLE IF NOT EXISTS cost_model_node
(
    id          int8         NOT NULL DEFAULT nextval('cost_model_node_seq'),
    parent_id   int8         NULL     DEFAULT NULL,
    node_code   varchar(128) NULL     DEFAULT NULL,
    node_name   varchar(255) NOT NULL,
    node_type   varchar(32)  NOT NULL,
    domain_code varchar(128) NULL     DEFAULT NULL,
    sort        int4         NULL     DEFAULT 0,
    status      varchar(32)  NOT NULL DEFAULT 'ENABLE',
    remark      varchar(500) NULL     DEFAULT NULL,
    creator     varchar(64)  NULL     DEFAULT '',
    create_time timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater     varchar(64)  NULL     DEFAULT '',
    update_time timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted     int2         NOT NULL DEFAULT 0,
    tenant_id   int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_model_node PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS cost_project
(
    id                    int8         NOT NULL DEFAULT nextval('cost_project_seq'),
    project_code          varchar(128) NOT NULL,
    project_name          varchar(255) NOT NULL,
    model_node_id         int8         NULL     DEFAULT NULL,
    domain_code           varchar(128) NULL     DEFAULT NULL,
    domain_name           varchar(255) NULL     DEFAULT NULL,
    category_code         varchar(128) NULL     DEFAULT NULL,
    category_name         varchar(255) NULL     DEFAULT NULL,
    model_code            varchar(128) NULL     DEFAULT NULL,
    model_name            varchar(255) NULL     DEFAULT NULL,
    batch_no              varchar(128) NULL     DEFAULT NULL,
    stage_codes           varchar(255) NULL     DEFAULT NULL,
    unit_id               int8         NULL     DEFAULT NULL,
    unit_name             varchar(255) NULL     DEFAULT NULL,
    unit_type             varchar(64)  NULL     DEFAULT NULL,
    project_office_status varchar(32)  NULL     DEFAULT NULL,
    unit_fill_status      varchar(32)  NULL     DEFAULT NULL,
    audit_status          varchar(32)  NULL     DEFAULT NULL,
    dept_id               int8         NULL     DEFAULT NULL,
    owner_user_id         int8         NULL     DEFAULT NULL,
    warning_status        varchar(32)  NULL     DEFAULT NULL,
    remark                varchar(500) NULL     DEFAULT NULL,
    creator               varchar(64)  NULL     DEFAULT '',
    create_time           timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater               varchar(64)  NULL     DEFAULT '',
    update_time           timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted               int2         NOT NULL DEFAULT 0,
    tenant_id             int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_project PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS cost_project_basic
(
    id                 int8          NOT NULL DEFAULT nextval('cost_project_basic_seq'),
    project_id         int8          NULL     DEFAULT NULL,
    project_code       varchar(128)  NULL     DEFAULT NULL,
    project_name       varchar(255)  NULL     DEFAULT NULL,
    product_attachment_type varchar(32) NULL DEFAULT NULL,
    subsystem_name     varchar(255)  NULL     DEFAULT NULL,
    quantity           int4          NULL     DEFAULT NULL,
    product_short_name varchar(255)  NULL     DEFAULT NULL,
    vertical_division  bool          NULL     DEFAULT NULL,
    user_name          varchar(255)  NULL     DEFAULT NULL,
    acquire_method     varchar(128)  NULL     DEFAULT NULL,
    batch_category     varchar(128)  NULL     DEFAULT NULL,
    platform_series    varchar(128)  NULL     DEFAULT NULL,
    research_unit_id   int8          NULL     DEFAULT NULL,
    research_unit_name varchar(255)  NULL     DEFAULT NULL,
    target_price       numeric(18,2) NULL     DEFAULT NULL,
    competitor_unit_1  varchar(255)  NULL     DEFAULT NULL,
    competitor_price_1 numeric(18,2) NULL     DEFAULT NULL,
    competitor_unit_2  varchar(255)  NULL     DEFAULT NULL,
    competitor_price_2 numeric(18,2) NULL     DEFAULT NULL,
    contract_amount    numeric(18,2) NULL     DEFAULT NULL,
    tax_exempt         varchar(16)   NULL     DEFAULT NULL,
    target_cost_amount numeric(18,2) NULL     DEFAULT NULL,
    approved_amount    numeric(18,2) NULL     DEFAULT NULL,
    cycle_start        varchar(16)   NULL     DEFAULT NULL,
    cycle_end          varchar(16)   NULL     DEFAULT NULL,
    stage_code         varchar(255)  NULL     DEFAULT NULL,
    basic_info         text          NULL,
    status             varchar(32)   NULL     DEFAULT NULL,
    remark             varchar(500)  NULL     DEFAULT NULL,
    import_batch_id    int8          NULL     DEFAULT NULL,
    dept_id            int8          NULL     DEFAULT NULL,
    owner_user_id      int8          NULL     DEFAULT NULL,
    creator            varchar(64)   NULL     DEFAULT '',
    create_time        timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater            varchar(64)   NULL     DEFAULT '',
    update_time        timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted            int2          NOT NULL DEFAULT 0,
    tenant_id          int8          NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_project_basic PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS cost_work_order
(
    id                   int8          NOT NULL DEFAULT nextval('cost_work_order_seq'),
    source_work_order_id varchar(128)  NULL     DEFAULT NULL,
    project_id           int8          NULL     DEFAULT NULL,
    project_code         varchar(128)  NOT NULL,
    project_name         varchar(255)  NULL     DEFAULT NULL,
    unit_id              int8          NULL     DEFAULT NULL,
    unit_name            varchar(255)  NOT NULL,
    accounting_unit_code varchar(128)  NULL     DEFAULT NULL,
    accounting_unit_name varchar(255)  NULL     DEFAULT NULL,
    fiscal_year          varchar(16)   NOT NULL DEFAULT '',
    work_order_no        varchar(128)  NOT NULL,
    work_order_name      varchar(255)  NULL     DEFAULT NULL,
    product_target_cost  numeric(18,2) NULL     DEFAULT NULL,
    contract_amount      numeric(18,2) NULL     DEFAULT NULL,
    income_amount        numeric(18,2) NULL     DEFAULT NULL,
    book_cost_amount     numeric(18,2) NULL     DEFAULT NULL,
    stage_codes          varchar(255)  NULL     DEFAULT NULL,
    max_stage_code       varchar(64)   NULL     DEFAULT NULL,
    subsystem_name       varchar(255)  NULL     DEFAULT NULL,
    product_short_name   varchar(255)  NULL     DEFAULT NULL,
    quantity             int4          NULL     DEFAULT NULL,
    vertical_division    bool          NULL     DEFAULT NULL,
    disabled             bool          NULL     DEFAULT false,
    approved_amount      numeric(18,2) NULL     DEFAULT NULL,
    status               varchar(32)   NULL     DEFAULT NULL,
    remark               varchar(500)  NULL     DEFAULT NULL,
    import_batch_id      int8          NULL     DEFAULT NULL,
    dept_id              int8          NULL     DEFAULT NULL,
    owner_user_id        int8          NULL     DEFAULT NULL,
    creator              varchar(64)   NULL     DEFAULT '',
    create_time          timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater              varchar(64)   NULL     DEFAULT '',
    update_time          timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted              int2          NOT NULL DEFAULT 0,
    tenant_id            int8          NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_work_order PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS cost_work_order_ledger_detail
(
    id                   int8          NOT NULL DEFAULT nextval('cost_work_order_ledger_detail_seq'),
    source_detail_id     varchar(128)  NOT NULL,
    fiscal_year          varchar(16)   NULL     DEFAULT NULL,
    accounting_period    varchar(16)   NULL     DEFAULT NULL,
    voucher_date         date          NULL     DEFAULT NULL,
    voucher_no           varchar(128)  NULL     DEFAULT NULL,
    accounting_unit_id   varchar(128)  NULL     DEFAULT NULL,
    accounting_unit_code varchar(128)  NULL     DEFAULT NULL,
    accounting_unit_name varchar(255)  NULL     DEFAULT NULL,
    manage_unit_name     varchar(255)  NULL     DEFAULT NULL,
    subject_id           varchar(128)  NULL     DEFAULT NULL,
    subject_code         varchar(128)  NULL     DEFAULT NULL,
    subject_name         varchar(255)  NULL     DEFAULT NULL,
    project_code         varchar(128)  NULL     DEFAULT NULL,
    source_project_id    varchar(128)  NULL     DEFAULT NULL,
    project_name         varchar(255)  NULL     DEFAULT NULL,
    source_work_order_id varchar(128)  NULL     DEFAULT NULL,
    work_order_no        varchar(128)  NULL     DEFAULT NULL,
    work_order_name      varchar(255)  NULL     DEFAULT NULL,
    debit_credit         varchar(32)   NULL     DEFAULT NULL,
    amount               numeric(18,2) NULL     DEFAULT NULL,
    amount_wan           numeric(18,2) NULL     DEFAULT NULL,
    summary_text         varchar(1000) NULL     DEFAULT NULL,
    source_lastmodify    timestamp     NULL     DEFAULT NULL,
    second_subject_code  varchar(128)  NULL     DEFAULT NULL,
    second_subject_name  varchar(255)  NULL     DEFAULT NULL,
    source_timestamp     varchar(64)   NULL     DEFAULT NULL,
    resolved_stage_code  varchar(64)   NULL     DEFAULT NULL,
    project_id           int8          NULL     DEFAULT NULL,
    work_order_id        int8          NULL     DEFAULT NULL,
    remark               varchar(500)  NULL     DEFAULT NULL,
    creator              varchar(64)   NULL     DEFAULT '',
    create_time          timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater              varchar(64)   NULL     DEFAULT '',
    update_time          timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted              int2          NOT NULL DEFAULT 0,
    tenant_id            int8          NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_work_order_ledger_detail PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS cost_unit_dict
(
    id                   int8         NOT NULL DEFAULT nextval('cost_unit_dict_seq'),
    accounting_unit_id   varchar(128) NULL     DEFAULT NULL,
    accounting_unit_code varchar(128) NULL     DEFAULT NULL,
    accounting_unit_name varchar(255) NULL     DEFAULT NULL,
    manage_unit_code     varchar(128) NULL     DEFAULT NULL,
    manage_unit_name     varchar(255) NULL     DEFAULT NULL,
    manage_unit_group    varchar(32)  NULL     DEFAULT NULL,
    contact_unit_code    varchar(128) NULL     DEFAULT NULL,
    contact_unit_name    varchar(255) NULL     DEFAULT NULL,
    inside_group         bool         NULL     DEFAULT false,
    inside_institute     bool         NULL     DEFAULT false,
    unit_id              int8         NULL     DEFAULT NULL,
    status               varchar(32)  NOT NULL DEFAULT 'ENABLE',
    remark               varchar(500) NULL     DEFAULT NULL,
    creator              varchar(64)  NULL     DEFAULT '',
    create_time          timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater              varchar(64)  NULL     DEFAULT '',
    update_time          timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted              int2         NOT NULL DEFAULT 0,
    tenant_id            int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_unit_dict PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS cost_subsystem_dict
(
    id             int8         NOT NULL DEFAULT nextval('cost_subsystem_dict_seq'),
    subsystem_name varchar(100) NOT NULL,
    sort_no        int4         NOT NULL DEFAULT 0,
    status         varchar(32)  NOT NULL DEFAULT 'ENABLE',
    remark         varchar(500) NULL     DEFAULT NULL,
    creator        varchar(64)  NULL     DEFAULT '',
    create_time    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater        varchar(64)  NULL     DEFAULT '',
    update_time    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted        int2         NOT NULL DEFAULT 0,
    tenant_id      int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_subsystem_dict PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS cost_unit_cost_detail
(
    id                 int8          NOT NULL DEFAULT nextval('cost_unit_cost_detail_seq'),
    project_id         int8          NULL     DEFAULT NULL,
    project_code       varchar(128)  NOT NULL,
    project_name       varchar(255)  NULL     DEFAULT NULL,
    domain_code        varchar(128)  NULL     DEFAULT NULL,
    domain_name        varchar(255)  NULL     DEFAULT NULL,
    model_node_id      int8          NULL     DEFAULT NULL,
    model_code         varchar(128)  NULL     DEFAULT NULL,
    model_name         varchar(255)  NULL     DEFAULT NULL,
    unit_id            int8          NULL     DEFAULT NULL,
    unit_name          varchar(255)  NOT NULL,
    stage_code         varchar(64)   NOT NULL DEFAULT 'ALL',
    source_record_id   varchar(128)  NULL     DEFAULT NULL,
    source_update_time timestamp     NULL     DEFAULT NULL,
    contract_amount    numeric(18,2) NULL     DEFAULT NULL,
    income_amount      numeric(18,2) NULL     DEFAULT NULL,
    target_cost_amount numeric(18,2) NULL     DEFAULT NULL,
    book_cost_amount   numeric(18,2) NULL     DEFAULT NULL,
    approved_amount    numeric(18,2) NULL     DEFAULT NULL,
    salary_amount      numeric(18,2) NULL     DEFAULT NULL,
    material_amount    numeric(18,2) NULL     DEFAULT NULL,
    outsource_amount   numeric(18,2) NULL     DEFAULT NULL,
    manage_amount      numeric(18,2) NULL     DEFAULT NULL,
    fuel_power_amount  numeric(18,2) NULL     DEFAULT NULL,
    other_amount       numeric(18,2) NULL     DEFAULT NULL,
    remark             varchar(500)  NULL     DEFAULT NULL,
    creator            varchar(64)   NULL     DEFAULT '',
    create_time        timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater            varchar(64)   NULL     DEFAULT '',
    update_time        timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted            int2          NOT NULL DEFAULT 0,
    tenant_id          int8          NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_unit_cost_detail PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS cost_user_project_scope
(
    id           int8         NOT NULL DEFAULT nextval('cost_user_project_scope_seq'),
    user_id      int8         NOT NULL,
    project_code varchar(128) NOT NULL,
    creator      varchar(64)  NULL     DEFAULT '',
    create_time  timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater      varchar(64)  NULL     DEFAULT '',
    update_time  timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted      int2         NOT NULL DEFAULT 0,
    tenant_id    int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_user_project_scope PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS cost_user_unit_scope
(
    id               int8         NOT NULL DEFAULT nextval('cost_user_unit_scope_seq'),
    user_id          int8         NOT NULL,
    manage_unit_code varchar(128) NOT NULL,
    manage_unit_name varchar(255) NOT NULL,
    creator          varchar(64)  NULL     DEFAULT '',
    create_time      timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater          varchar(64)  NULL     DEFAULT '',
    update_time      timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted          int2         NOT NULL DEFAULT 0,
    tenant_id        int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_user_unit_scope PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS cost_user_domain_scope
(
    id          int8         NOT NULL DEFAULT nextval('cost_user_domain_scope_seq'),
    user_id     int8         NOT NULL,
    domain_code varchar(128) NOT NULL,
    creator     varchar(64)  NULL     DEFAULT '',
    create_time timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater     varchar(64)  NULL     DEFAULT '',
    update_time timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted     int2         NOT NULL DEFAULT 0,
    tenant_id   int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_user_domain_scope PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS cost_import_batch
(
    id             int8         NOT NULL DEFAULT nextval('cost_import_batch_seq'),
    import_type    varchar(64)  NOT NULL,
    file_name      varchar(255) NULL     DEFAULT NULL,
    file_url       varchar(500) NULL     DEFAULT NULL,
    total_count    int4         NULL     DEFAULT 0,
    success_count  int4         NULL     DEFAULT 0,
    failure_count  int4         NULL     DEFAULT 0,
    update_support bool         NULL     DEFAULT false,
    status         varchar(32)  NULL     DEFAULT NULL,
    error_file_url varchar(500) NULL     DEFAULT NULL,
    remark         varchar(500) NULL     DEFAULT NULL,
    creator        varchar(64)  NULL     DEFAULT '',
    create_time    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater        varchar(64)  NULL     DEFAULT '',
    update_time    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted        int2         NOT NULL DEFAULT 0,
    tenant_id      int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_import_batch PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS cost_import_error
(
    id            int8          NOT NULL DEFAULT nextval('cost_import_error_seq'),
    batch_id      int8          NOT NULL,
    row_num       int4          NULL     DEFAULT NULL,
    field_name    varchar(128)  NULL     DEFAULT NULL,
    error_message varchar(1000) NULL     DEFAULT NULL,
    raw_data      text          NULL,
    creator       varchar(64)   NULL     DEFAULT '',
    create_time   timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater       varchar(64)   NULL     DEFAULT '',
    update_time   timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted       int2          NOT NULL DEFAULT 0,
    tenant_id     int8          NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_import_error PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS cost_warning_record
(
    id                    int8          NOT NULL DEFAULT nextval('cost_warning_record_seq'),
    project_id            int8          NULL     DEFAULT NULL,
    work_order_id         int8          NULL     DEFAULT NULL,
    project_code          varchar(100)  NULL     DEFAULT NULL,
    project_name          varchar(255)  NULL     DEFAULT NULL,
    domain_code           varchar(100)  NULL     DEFAULT NULL,
    domain_name           varchar(255)  NULL     DEFAULT NULL,
    model_code            varchar(100)  NULL     DEFAULT NULL,
    model_name            varchar(255)  NULL     DEFAULT NULL,
    warning_source        varchar(32)   NULL     DEFAULT NULL,
    warning_title         varchar(255)  NULL     DEFAULT NULL,
    target_cost_amount    numeric(18,2) NULL     DEFAULT NULL,
    actual_cost_amount    numeric(18,2) NULL     DEFAULT NULL,
    over_amount           numeric(18,2) NULL     DEFAULT NULL,
    over_rate             numeric(18,4) NULL     DEFAULT NULL,
    threshold_rate        numeric(18,4) NULL     DEFAULT NULL,
    warning_level         varchar(32)   NULL     DEFAULT NULL,
    responsible_unit_name varchar(255)  NULL     DEFAULT NULL,
    push_status           varchar(32)   NULL     DEFAULT NULL,
    pushed_time           timestamp     NULL     DEFAULT NULL,
    receiver_scope        varchar(1000) NULL     DEFAULT NULL,
    message_id            int8          NULL     DEFAULT NULL,
    status                varchar(32)   NULL     DEFAULT NULL,
    remark                varchar(500)  NULL     DEFAULT NULL,
    cycle_no              int4          NULL     DEFAULT NULL,
    workflow_status       varchar(32)   NULL     DEFAULT NULL,
    active_marker         int2          NULL     DEFAULT NULL,
    initiator_user_id     int8          NULL     DEFAULT NULL,
    initiator_user_name   varchar(128)  NULL     DEFAULT NULL,
    initiated_time        timestamp     NULL     DEFAULT NULL,
    disposition_user_id   int8          NULL     DEFAULT NULL,
    disposition_user_name varchar(128)  NULL     DEFAULT NULL,
    cause_analysis        varchar(1000) NULL     DEFAULT NULL,
    disposal_measure      varchar(1000) NULL     DEFAULT NULL,
    expected_completion_date date       NULL     DEFAULT NULL,
    disposition_time      timestamp     NULL     DEFAULT NULL,
    close_user_id         int8          NULL     DEFAULT NULL,
    close_user_name       varchar(128)  NULL     DEFAULT NULL,
    close_time            timestamp     NULL     DEFAULT NULL,
    return_reason         varchar(500)  NULL     DEFAULT NULL,
    creator               varchar(64)   NULL     DEFAULT '',
    create_time           timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater               varchar(64)   NULL     DEFAULT '',
    update_time           timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted               int2          NOT NULL DEFAULT 0,
    tenant_id             int8          NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_warning_record PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS cost_warning_receiver (
    id int8 NOT NULL DEFAULT nextval('cost_warning_receiver_seq'), warning_record_id int8 NOT NULL,
    user_id int8 NOT NULL, username varchar(64), nickname varchar(128),
    notify_status varchar(32) NOT NULL DEFAULT 'PENDING', message_id int8,
    notified_time timestamp, failure_reason varchar(500), creator varchar(64) DEFAULT '',
    create_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, updater varchar(64) DEFAULT '',
    update_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, deleted int2 NOT NULL DEFAULT 0,
    tenant_id int8 NOT NULL DEFAULT 0, CONSTRAINT pk_cost_warning_receiver PRIMARY KEY (id));

CREATE TABLE IF NOT EXISTS cost_warning_action_log (
    id int8 NOT NULL DEFAULT nextval('cost_warning_action_log_seq'), warning_record_id int8 NOT NULL,
    action_type varchar(32) NOT NULL, operator_user_id int8 NOT NULL,
    operator_user_name varchar(128), operator_role_code varchar(100), from_status varchar(32),
    to_status varchar(32), action_content varchar(1000), creator varchar(64) DEFAULT '',
    create_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, updater varchar(64) DEFAULT '',
    update_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, deleted int2 NOT NULL DEFAULT 0,
    tenant_id int8 NOT NULL DEFAULT 0, CONSTRAINT pk_cost_warning_action_log PRIMARY KEY (id));

CREATE TABLE IF NOT EXISTS cost_schema_migration
(
    version         varchar(32)  NOT NULL,
    description     varchar(255) NOT NULL,
    installed_on    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    installed_by    varchar(128) NOT NULL DEFAULT CURRENT_USER,
    CONSTRAINT pk_cost_schema_migration PRIMARY KEY (version)
);