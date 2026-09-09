-- PostgreSQL 9.2+ / GaussDB(DWS). SQL only; not MySQL or DM.
-- CHANGE public below to the schema actually used by cost-server, not the database name.
-- Execute as a whole with stop-on-error; stop cost writes first and keep your backup.
BEGIN;
SET LOCAL search_path TO "public";
DO $schema_guard$ BEGIN
 IF current_schema() IS NULL THEN RAISE EXCEPTION 'Target schema does not exist or is inaccessible'; END IF;
END $schema_guard$;
-- NO migration gates, ALTER/UPDATE/DELETE/INSERT, or sequence resets.

-- Create only when absent: cost_model_node
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_model_node') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_model_node_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_model_node_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_model_node (
    id          int8         NOT NULL DEFAULT nextval(''cost_model_node_seq''),
    parent_id   int8         NULL     DEFAULT NULL,
    node_code   varchar(128) NULL     DEFAULT NULL,
    node_name   varchar(255) NOT NULL,
    node_type   varchar(32)  NOT NULL,
    domain_code varchar(128) NULL     DEFAULT NULL,
    sort        int4         NULL     DEFAULT 0,
    status      varchar(32)  NOT NULL DEFAULT ''ENABLE'',
    remark      varchar(500) NULL     DEFAULT NULL,
    creator     varchar(64)  NULL     DEFAULT '''',
    create_time timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater     varchar(64)  NULL     DEFAULT '''',
    update_time timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted     int2         NOT NULL DEFAULT 0,
    tenant_id   int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_model_node PRIMARY KEY (id)
)' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_model_node IS ''成本库型号树节点表'';';
  EXECUTE 'COMMENT ON COLUMN cost_model_node.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_model_node.parent_id IS ''父节点编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_model_node.node_code IS ''节点编码'';';
  EXECUTE 'COMMENT ON COLUMN cost_model_node.node_name IS ''节点名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_model_node.node_type IS ''节点类型：DOMAIN/SERIES/MODEL'';';
  EXECUTE 'COMMENT ON COLUMN cost_model_node.domain_code IS ''所属领域编码'';';
  EXECUTE 'COMMENT ON COLUMN cost_model_node.sort IS ''排序'';';
  EXECUTE 'COMMENT ON COLUMN cost_model_node.status IS ''状态：ENABLE/DISABLE'';';
  EXECUTE 'COMMENT ON COLUMN cost_model_node.remark IS ''备注'';';
  EXECUTE 'COMMENT ON COLUMN cost_model_node.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_model_node.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_model_node.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_model_node.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_model_node.deleted IS ''是否删除'';';
  EXECUTE 'COMMENT ON COLUMN cost_model_node.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_project
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_project') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_project_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_project_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_project (
    id                    int8         NOT NULL DEFAULT nextval(''cost_project_seq''),
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
    creator               varchar(64)  NULL     DEFAULT '''',
    create_time           timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater               varchar(64)  NULL     DEFAULT '''',
    update_time           timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted               int2         NOT NULL DEFAULT 0,
    tenant_id             int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_project PRIMARY KEY (id)
)' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_project IS ''成本库主业项目表'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.project_code IS ''主业项目编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.project_name IS ''主业项目名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.model_node_id IS ''型号树节点编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.domain_code IS ''所属领域编码'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.domain_name IS ''所属领域名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.category_code IS ''所属类别/系列编码'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.category_name IS ''所属类别/系列名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.model_code IS ''型号/项目编码'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.model_name IS ''型号/项目名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.batch_no IS ''批次'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.stage_codes IS ''阶段集合，逗号分隔'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.unit_id IS ''单位编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.unit_name IS ''单位名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.unit_type IS ''单位属性'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.project_office_status IS ''项目办填报状态：NOT_FILLED/PART_FILLED/FILLED'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.unit_fill_status IS ''研制单位填报状态：NOT_FILLED/PART_FILLED/FILLED'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.audit_status IS ''审批/提交状态：DRAFT/SUBMITTED/APPROVED/REJECTED'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.dept_id IS ''数据权限部门编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.owner_user_id IS ''项目负责人用户编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.warning_status IS ''预警状态：NORMAL/OVER'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.remark IS ''备注'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.deleted IS ''是否删除'';';
  EXECUTE 'COMMENT ON COLUMN cost_project.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_project_basic
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_project_basic') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_project_basic_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_project_basic_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_project_basic (
    id                 int8          NOT NULL DEFAULT nextval(''cost_project_basic_seq''),
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
    creator            varchar(64)   NULL     DEFAULT '''',
    create_time        timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater            varchar(64)   NULL     DEFAULT '''',
    update_time        timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted            int2          NOT NULL DEFAULT 0,
    tenant_id          int8          NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_project_basic PRIMARY KEY (id)
)' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_project_basic IS ''成本库项目基本信息表'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.project_id IS ''主业项目主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.project_code IS ''主业项目编号冗余'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.project_name IS ''主业项目名称冗余'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.product_attachment_type IS ''是否产品附件、发射车等：产品/产品附件/发射车/否'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.subsystem_name IS ''分系统/产品配套'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.quantity IS ''配套数'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.product_short_name IS ''产品简称'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.vertical_division IS ''是否纵向分工'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.user_name IS ''用户'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.acquire_method IS ''项目获取方式'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.batch_category IS ''批次/类别'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.platform_series IS ''所属平台/系列'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.research_unit_id IS ''承研单位编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.research_unit_name IS ''承研单位名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.target_price IS ''投标/目标价格，单位万元'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.competitor_unit_1 IS ''对手单位1'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.competitor_price_1 IS ''对手竞标价格1，单位万元'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.competitor_unit_2 IS ''对手单位2'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.competitor_price_2 IS ''对手竞标价格2，单位万元'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.contract_amount IS ''型号项目合同金额，单位万元'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.tax_exempt IS ''是否免税'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.target_cost_amount IS ''型号项目目标成本，单位万元'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.approved_amount IS ''审定金额，单位万元'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.cycle_start IS ''研制周期起，格式YYYY-MM'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.cycle_end IS ''研制周期止，格式YYYY-MM'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.stage_code IS ''阶段编码集合，逗号分隔'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.basic_info IS ''基本情况'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.status IS ''记录状态：DRAFT/SUBMITTED/APPROVED/REJECTED'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.remark IS ''备注'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.import_batch_id IS ''导入批次编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.dept_id IS ''数据权限部门编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.owner_user_id IS ''填报负责人用户编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.deleted IS ''是否删除'';';
  EXECUTE 'COMMENT ON COLUMN cost_project_basic.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_work_order
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_work_order') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_work_order_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_work_order_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_work_order (
    id                   int8          NOT NULL DEFAULT nextval(''cost_work_order_seq''),
    source_work_order_id varchar(128)  NULL     DEFAULT NULL,
    project_id           int8          NULL     DEFAULT NULL,
    project_code         varchar(128)  NOT NULL,
    project_name         varchar(255)  NULL     DEFAULT NULL,
    unit_id              int8          NULL     DEFAULT NULL,
    unit_name            varchar(255)  NOT NULL,
    accounting_unit_code varchar(128)  NULL     DEFAULT NULL,
    accounting_unit_name varchar(255)  NULL     DEFAULT NULL,
    fiscal_year          varchar(16)   NOT NULL DEFAULT '''',
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
    creator              varchar(64)   NULL     DEFAULT '''',
    create_time          timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater              varchar(64)   NULL     DEFAULT '''',
    update_time          timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted              int2          NOT NULL DEFAULT 0,
    tenant_id            int8          NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_work_order PRIMARY KEY (id)
)' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_work_order IS ''成本库工作令表'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.source_work_order_id IS ''源系统工作令主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.project_id IS ''主业项目主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.project_code IS ''主业项目编号冗余'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.project_name IS ''主业项目名称冗余'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.unit_id IS ''单位编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.unit_name IS ''单位名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.accounting_unit_code IS ''核算单位编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.accounting_unit_name IS ''核算单位名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.fiscal_year IS ''废弃兼容字段，逻辑工作令固定为空'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.work_order_no IS ''工作令编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.work_order_name IS ''工作令名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.product_target_cost IS ''工作令目标成本，单位万元，仅工作令层展示'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.contract_amount IS ''工作令合同金额，单位万元，仅工作令层展示'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.income_amount IS ''工作令到款金额，单位万元，仅工作令层展示'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.book_cost_amount IS ''工作令跨年度借方账面快照，单位万元，可由明细重建'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.stage_codes IS ''阶段集合，逗号分隔'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.max_stage_code IS ''最高阶段'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.subsystem_name IS ''所属分系统'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.product_short_name IS ''产品简称'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.quantity IS ''配套数量'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.vertical_division IS ''是否属于纵向分工；NULL 表示尚未填报'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.disabled IS ''是否停用'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.approved_amount IS ''审定金额，单位万元'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.status IS ''记录状态：DRAFT/SUBMITTED/APPROVED/REJECTED'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.remark IS ''备注'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.import_batch_id IS ''导入批次编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.dept_id IS ''数据权限部门编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.owner_user_id IS ''填报负责人用户编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.deleted IS ''是否删除'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_work_order_ledger_detail
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_work_order_ledger_detail') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_work_order_ledger_detail_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_work_order_ledger_detail_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_work_order_ledger_detail (
    id                   int8          NOT NULL DEFAULT nextval(''cost_work_order_ledger_detail_seq''),
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
    creator              varchar(64)   NULL     DEFAULT '''',
    create_time          timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater              varchar(64)   NULL     DEFAULT '''',
    update_time          timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted              int2          NOT NULL DEFAULT 0,
    tenant_id            int8          NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_work_order_ledger_detail PRIMARY KEY (id)
)' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_work_order_ledger_detail IS ''成本库工作令账面成本明细表'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.source_detail_id IS ''源明细内码，业务参考字段 ysnm'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.fiscal_year IS ''会计年度，业务参考字段 kjnd'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.accounting_period IS ''会计期间，业务参考字段 kjqj'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.voucher_date IS ''凭证日期，业务参考字段 pzrq'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.voucher_no IS ''凭证编号，业务参考字段 pzbh'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.accounting_unit_id IS ''单位主键，业务参考字段 dwid'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.accounting_unit_code IS ''单位编号，业务参考字段 dwbh'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.accounting_unit_name IS ''单位名称，业务参考字段 dwmc'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.manage_unit_name IS ''管理单位，业务参考字段 gldw'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.subject_id IS ''科目主键，业务参考字段 kmid'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.subject_code IS ''科目编号，业务参考字段 kmbh'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.subject_name IS ''科目名称，业务参考字段 kmmc'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.project_code IS ''项目编号，业务参考字段 xmbh'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.source_project_id IS ''项目主键，业务参考字段 xmnm'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.project_name IS ''项目名称，业务参考字段 xmmc'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.source_work_order_id IS ''工作令主键，业务参考字段 gzlnm'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.work_order_no IS ''工作令编号，业务参考字段 gzllb'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.work_order_name IS ''工作令名称，业务参考字段 gzlmc'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.debit_credit IS ''记账方向，业务参考字段 jzfx'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.amount IS ''源系统金额，单位元'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.amount_wan IS ''金额折算万元兼容字段，按 amount/10000 生成'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.summary_text IS ''辅助摘要，业务参考字段 yt'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.source_lastmodify IS ''源系统最后修改时间，业务参考字段 lastmodify'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.second_subject_code IS ''二级科目编号，业务参考字段 ejkmbh'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.second_subject_name IS ''二级科目名称，业务参考字段 ejkmmc'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.source_timestamp IS ''源时间戳，业务参考字段 dwts'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.resolved_stage_code IS ''成本库归集阶段，按工作令最高阶段解析后写入'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.project_id IS ''成本库项目主键，匹配后写入'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.work_order_id IS ''成本库工作令主键，匹配后写入'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.remark IS ''备注'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.deleted IS ''是否删除'';';
  EXECUTE 'COMMENT ON COLUMN cost_work_order_ledger_detail.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_unit_dict
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_unit_dict') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_unit_dict_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_unit_dict_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_unit_dict (
    id                   int8         NOT NULL DEFAULT nextval(''cost_unit_dict_seq''),
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
    status               varchar(32)  NOT NULL DEFAULT ''ENABLE'',
    remark               varchar(500) NULL     DEFAULT NULL,
    creator              varchar(64)  NULL     DEFAULT '''',
    create_time          timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater              varchar(64)  NULL     DEFAULT '''',
    update_time          timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted              int2         NOT NULL DEFAULT 0,
    tenant_id            int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_unit_dict PRIMARY KEY (id)
)' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_unit_dict IS ''成本库单位字典表'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.accounting_unit_id IS ''核算单位 ID'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.accounting_unit_code IS ''核算单位编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.accounting_unit_name IS ''核算单位名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.manage_unit_code IS ''管理单位编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.manage_unit_name IS ''管理单位名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.manage_unit_group IS ''管理单位分类：HEAD_OFFICE/OVERALL/ASSEMBLY/PROFESSIONAL/FOUNDATION/OUTER'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.contact_unit_code IS ''往来单位编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.contact_unit_name IS ''往来单位名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.inside_group IS ''是否集团内'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.inside_institute IS ''是否院内'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.unit_id IS ''中台单位编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.status IS ''状态：ENABLE/DISABLE'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.remark IS ''备注'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.deleted IS ''是否删除'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_dict.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_subsystem_dict
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_subsystem_dict') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_subsystem_dict_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_subsystem_dict_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_subsystem_dict (
    id             int8         NOT NULL DEFAULT nextval(''cost_subsystem_dict_seq''),
    subsystem_name varchar(100) NOT NULL,
    sort_no        int4         NOT NULL DEFAULT 0,
    status         varchar(32)  NOT NULL DEFAULT ''ENABLE'',
    remark         varchar(500) NULL     DEFAULT NULL,
    creator        varchar(64)  NULL     DEFAULT '''',
    create_time    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater        varchar(64)  NULL     DEFAULT '''',
    update_time    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted        int2         NOT NULL DEFAULT 0,
    tenant_id      int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_subsystem_dict PRIMARY KEY (id)
)' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_subsystem_dict IS ''成本库分系统字典表'';';
  EXECUTE 'COMMENT ON COLUMN cost_subsystem_dict.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_subsystem_dict.subsystem_name IS ''分系统名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_subsystem_dict.sort_no IS ''显示排序'';';
  EXECUTE 'COMMENT ON COLUMN cost_subsystem_dict.status IS ''状态：ENABLE/DISABLE'';';
  EXECUTE 'COMMENT ON COLUMN cost_subsystem_dict.remark IS ''备注'';';
  EXECUTE 'COMMENT ON COLUMN cost_subsystem_dict.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_subsystem_dict.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_subsystem_dict.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_subsystem_dict.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_subsystem_dict.deleted IS ''是否删除'';';
  EXECUTE 'COMMENT ON COLUMN cost_subsystem_dict.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_unit_cost_detail
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_unit_cost_detail') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_unit_cost_detail_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_unit_cost_detail_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_unit_cost_detail (
    id                 int8          NOT NULL DEFAULT nextval(''cost_unit_cost_detail_seq''),
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
    stage_code         varchar(64)   NOT NULL DEFAULT ''ALL'',
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
    creator            varchar(64)   NULL     DEFAULT '''',
    create_time        timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater            varchar(64)   NULL     DEFAULT '''',
    update_time        timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted            int2          NOT NULL DEFAULT 0,
    tenant_id          int8          NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_unit_cost_detail PRIMARY KEY (id)
)' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_unit_cost_detail IS ''预分预控项目单位累计金额表'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.project_id IS ''主业项目编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.project_code IS ''主业项目编号冗余'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.project_name IS ''主业项目名称冗余'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.domain_code IS ''所属领域编码'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.domain_name IS ''所属领域名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.model_node_id IS ''型号树节点编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.model_code IS ''型号/项目编码'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.model_name IS ''型号/项目名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.unit_id IS ''研制单位编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.unit_name IS ''研制单位名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.stage_code IS ''累计金额固定阶段标识'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.source_record_id IS ''预分预控源记录主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.source_update_time IS ''预分预控源记录更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.contract_amount IS ''预分预控项目单位累计合同金额，单位万元'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.income_amount IS ''预分预控项目单位累计到款金额，单位万元'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.target_cost_amount IS ''预分预控项目单位累计目标成本，单位万元'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.book_cost_amount IS ''历史兼容账面字段，不参与现行汇总'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.approved_amount IS ''预分预控项目单位累计审定金额，单位万元'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.salary_amount IS ''历史六类组成兼容字段，不参与现行账面组成'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.material_amount IS ''历史六类组成兼容字段，不参与现行账面组成'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.outsource_amount IS ''历史六类组成兼容字段，不参与现行账面组成'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.manage_amount IS ''历史六类组成兼容字段，不参与现行账面组成'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.fuel_power_amount IS ''历史六类组成兼容字段，不参与现行账面组成'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.other_amount IS ''历史六类组成兼容字段，不参与现行账面组成'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.remark IS ''备注'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.deleted IS ''是否删除'';';
  EXECUTE 'COMMENT ON COLUMN cost_unit_cost_detail.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_user_project_scope
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_user_project_scope') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_user_project_scope_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_user_project_scope_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_user_project_scope (
    id           int8         NOT NULL DEFAULT nextval(''cost_user_project_scope_seq''),
    user_id      int8         NOT NULL,
    project_code varchar(128) NOT NULL,
    creator      varchar(64)  NULL     DEFAULT '''',
    create_time  timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater      varchar(64)  NULL     DEFAULT '''',
    update_time  timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted      int2         NOT NULL DEFAULT 0,
    tenant_id    int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_user_project_scope PRIMARY KEY (id)
)' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_user_project_scope IS ''成本库用户项目数据授权表'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_project_scope.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_project_scope.user_id IS ''系统用户编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_project_scope.project_code IS ''授权主业项目编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_project_scope.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_project_scope.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_project_scope.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_project_scope.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_project_scope.deleted IS ''是否删除'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_project_scope.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_user_unit_scope
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_user_unit_scope') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_user_unit_scope_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_user_unit_scope_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_user_unit_scope (
    id               int8         NOT NULL DEFAULT nextval(''cost_user_unit_scope_seq''),
    user_id          int8         NOT NULL,
    manage_unit_code varchar(128) NOT NULL,
    manage_unit_name varchar(255) NOT NULL,
    creator          varchar(64)  NULL     DEFAULT '''',
    create_time      timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater          varchar(64)  NULL     DEFAULT '''',
    update_time      timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted          int2         NOT NULL DEFAULT 0,
    tenant_id        int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_user_unit_scope PRIMARY KEY (id)
)' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_user_unit_scope IS ''成本库用户管理单位数据授权表'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_unit_scope.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_unit_scope.user_id IS ''系统用户编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_unit_scope.manage_unit_code IS ''授权管理单位编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_unit_scope.manage_unit_name IS ''授权时管理单位名称快照'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_unit_scope.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_unit_scope.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_unit_scope.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_unit_scope.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_unit_scope.deleted IS ''是否删除'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_unit_scope.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_user_domain_scope
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_user_domain_scope') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_user_domain_scope_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_user_domain_scope_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_user_domain_scope (
    id          int8         NOT NULL DEFAULT nextval(''cost_user_domain_scope_seq''),
    user_id     int8         NOT NULL,
    domain_code varchar(128) NOT NULL,
    creator     varchar(64)  NULL     DEFAULT '''',
    create_time timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater     varchar(64)  NULL     DEFAULT '''',
    update_time timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted     int2         NOT NULL DEFAULT 0,
    tenant_id   int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_user_domain_scope PRIMARY KEY (id)
)' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_user_domain_scope IS ''成本库科研部用户领域数据授权表；每账号一个领域，授权更新使用物理替换'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_domain_scope.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_domain_scope.user_id IS ''系统用户编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_domain_scope.domain_code IS ''授权领域编码'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_domain_scope.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_domain_scope.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_domain_scope.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_domain_scope.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_domain_scope.deleted IS ''是否删除；领域授权使用物理替换'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_domain_scope.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_import_batch
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_import_batch') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_import_batch_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_import_batch_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_import_batch (
    id             int8         NOT NULL DEFAULT nextval(''cost_import_batch_seq''),
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
    creator        varchar(64)  NULL     DEFAULT '''',
    create_time    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater        varchar(64)  NULL     DEFAULT '''',
    update_time    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted        int2         NOT NULL DEFAULT 0,
    tenant_id      int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_import_batch PRIMARY KEY (id)
)' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_import_batch IS ''成本库导入批次表'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.import_type IS ''导入类型：PROJECT_BASIC/WORK_ORDER'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.file_name IS ''原始文件名'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.file_url IS ''文件地址'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.total_count IS ''总行数'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.success_count IS ''成功行数'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.failure_count IS ''失败行数'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.update_support IS ''是否支持覆盖更新'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.status IS ''导入状态：SUCCESS/PART_SUCCESS/FAILED'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.error_file_url IS ''错误文件地址'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.remark IS ''备注'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.deleted IS ''是否删除'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_batch.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_import_error
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_import_error') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_import_error_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_import_error_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_import_error (
    id            int8          NOT NULL DEFAULT nextval(''cost_import_error_seq''),
    batch_id      int8          NOT NULL,
    row_num       int4          NULL     DEFAULT NULL,
    field_name    varchar(128)  NULL     DEFAULT NULL,
    error_message varchar(1000) NULL     DEFAULT NULL,
    raw_data      text          NULL,
    creator       varchar(64)   NULL     DEFAULT '''',
    create_time   timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater       varchar(64)   NULL     DEFAULT '''',
    update_time   timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted       int2          NOT NULL DEFAULT 0,
    tenant_id     int8          NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_import_error PRIMARY KEY (id)
)' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_import_error IS ''成本库导入错误表'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_error.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_error.batch_id IS ''导入批次编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_error.row_num IS ''Excel 行号'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_error.field_name IS ''字段名'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_error.error_message IS ''错误原因'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_error.raw_data IS ''原始行数据 JSON'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_error.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_error.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_error.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_error.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_error.deleted IS ''是否删除'';';
  EXECUTE 'COMMENT ON COLUMN cost_import_error.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_warning_record
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_warning_record') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_warning_record_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_warning_record_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_warning_record (
    id                    int8          NOT NULL DEFAULT nextval(''cost_warning_record_seq''),
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
    creator               varchar(64)   NULL     DEFAULT '''',
    create_time           timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater               varchar(64)   NULL     DEFAULT '''',
    update_time           timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted               int2          NOT NULL DEFAULT 0,
    tenant_id             int8          NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_warning_record PRIMARY KEY (id)
)' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_warning_record IS ''成本库预警记录表'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.project_id IS ''主业项目编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.work_order_id IS ''工作令编号，可为空'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.project_code IS ''项目编号快照'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.project_name IS ''项目名称快照'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.domain_code IS ''领域编码快照'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.domain_name IS ''领域名称快照'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.model_code IS ''型号编码快照'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.model_name IS ''型号名称快照'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.warning_source IS ''预警来源：PROJECT/WORK_ORDER'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.warning_title IS ''预警标题'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.target_cost_amount IS ''目标成本，单位万元'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.actual_cost_amount IS ''实际/账面成本，单位万元'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.over_amount IS ''超支金额，单位万元'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.over_rate IS ''超支比例'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.threshold_rate IS ''阈值比例'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.warning_level IS ''预警等级：NORMAL/OVER'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.responsible_unit_name IS ''责任单位'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.push_status IS ''推送状态：NOT_PUSHED/PUSHED/FAILED'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.pushed_time IS ''推送时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.receiver_scope IS ''接收范围'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.message_id IS ''中心消息编号【需确认】'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.status IS ''处理状态：OPEN/CLOSED'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.remark IS ''备注'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.cycle_no IS ''处置周期'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.workflow_status IS ''处置工作流状态'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.active_marker IS ''活动周期标记：1；关闭/历史为NULL'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.initiator_user_id IS ''发起人'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.initiator_user_name IS ''发起人快照'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.initiated_time IS ''发起时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.disposition_user_id IS ''处置人'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.disposition_user_name IS ''处置人快照'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.cause_analysis IS ''原因分析'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.disposal_measure IS ''处置措施'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.expected_completion_date IS ''预计完成日期'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.disposition_time IS ''反馈时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.close_user_id IS ''闭环人'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.close_user_name IS ''闭环人快照'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.close_time IS ''闭环时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.return_reason IS ''退回原因'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.deleted IS ''是否删除'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_record.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_warning_receiver
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_warning_receiver') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_warning_receiver_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_warning_receiver_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_warning_receiver (
    id int8 NOT NULL DEFAULT nextval(''cost_warning_receiver_seq''), warning_record_id int8 NOT NULL,
    user_id int8 NOT NULL, username varchar(64), nickname varchar(128),
    notify_status varchar(32) NOT NULL DEFAULT ''PENDING'', message_id int8,
    notified_time timestamp, failure_reason varchar(500), creator varchar(64) DEFAULT '''',
    create_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, updater varchar(64) DEFAULT '''',
    update_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, deleted int2 NOT NULL DEFAULT 0,
    tenant_id int8 NOT NULL DEFAULT 0, CONSTRAINT pk_cost_warning_receiver PRIMARY KEY (id))' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_warning_receiver IS ''成本预警通知接收记录表'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_receiver.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_receiver.warning_record_id IS ''预警记录编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_receiver.user_id IS ''用户编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_receiver.username IS ''用户账号'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_receiver.nickname IS ''用户昵称'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_receiver.notify_status IS ''通知状态'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_receiver.message_id IS ''消息编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_receiver.notified_time IS ''通知时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_receiver.failure_reason IS ''通知失败原因'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_receiver.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_receiver.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_receiver.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_receiver.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_receiver.deleted IS ''是否删除：0 未删除，1 已删除'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_receiver.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_warning_action_log
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_warning_action_log') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_warning_action_log_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_warning_action_log_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (id)'; END IF;
  EXECUTE 'CREATE TABLE cost_warning_action_log (
    id int8 NOT NULL DEFAULT nextval(''cost_warning_action_log_seq''), warning_record_id int8 NOT NULL,
    action_type varchar(32) NOT NULL, operator_user_id int8 NOT NULL,
    operator_user_name varchar(128), operator_role_code varchar(100), from_status varchar(32),
    to_status varchar(32), action_content varchar(1000), creator varchar(64) DEFAULT '''',
    create_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, updater varchar(64) DEFAULT '''',
    update_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, deleted int2 NOT NULL DEFAULT 0,
    tenant_id int8 NOT NULL DEFAULT 0, CONSTRAINT pk_cost_warning_action_log PRIMARY KEY (id))' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_warning_action_log IS ''成本预警处置操作日志表'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_action_log.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_action_log.warning_record_id IS ''预警记录编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_action_log.action_type IS ''操作类型'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_action_log.operator_user_id IS ''操作用户编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_action_log.operator_user_name IS ''操作用户名称'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_action_log.operator_role_code IS ''操作用户角色编码'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_action_log.from_status IS ''操作前状态'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_action_log.to_status IS ''操作后状态'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_action_log.action_content IS ''操作内容'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_action_log.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_action_log.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_action_log.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_action_log.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_action_log.deleted IS ''是否删除：0 未删除，1 已删除'';';
  EXECUTE 'COMMENT ON COLUMN cost_warning_action_log.tenant_id IS ''租户编号'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_schema_migration
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_schema_migration') THEN

  EXECUTE 'CREATE TABLE cost_schema_migration (
    version         varchar(32)  NOT NULL,
    description     varchar(255) NOT NULL,
    installed_on    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    installed_by    varchar(128) NOT NULL DEFAULT CURRENT_USER,
    CONSTRAINT pk_cost_schema_migration PRIMARY KEY (version)
)' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_schema_migration IS ''成本库数据库结构版本记录表'';';
  EXECUTE 'COMMENT ON COLUMN cost_schema_migration.version IS ''业务结构版本号'';';
  EXECUTE 'COMMENT ON COLUMN cost_schema_migration.description IS ''版本说明'';';
  EXECUTE 'COMMENT ON COLUMN cost_schema_migration.installed_on IS ''安装时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_schema_migration.installed_by IS ''安装数据库用户'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_user_role
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_user_role') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_user_role_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_user_role_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (tenant_id)'; END IF;
  EXECUTE 'CREATE TABLE cost_user_role (
        id bigint NOT NULL DEFAULT nextval(''cost_user_role_seq''),
        tenant_id bigint NOT NULL,
        user_id bigint NOT NULL,
        role_code varchar(64),
        username varchar(128) NOT NULL,
        nickname varchar(255),
        revision bigint NOT NULL DEFAULT 1,
        creator varchar(64) DEFAULT '''', updater varchar(64) DEFAULT '''',
        create_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        update_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        deleted smallint NOT NULL DEFAULT 0 CHECK (deleted=0),
        CONSTRAINT pk_cost_user_role PRIMARY KEY (tenant_id,id),
        CONSTRAINT uk_cost_user_role_user UNIQUE (tenant_id,user_id),
        CONSTRAINT ck_cost_user_role_code CHECK (role_code IS NULL OR role_code IN
            (''cost_global_viewer'',''cost_research_department'',''cost_project_office'',''cost_unit_user''))
    )' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_user_role IS ''成本本地角色覆盖；无记录沿用中台，role_code为空表示显式撤销，禁止同步清理'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role.tenant_id IS ''租户编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role.user_id IS ''用户编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role.role_code IS ''本地成本角色编码：cost_global_viewer、cost_research_department、cost_project_office、cost_unit_user；NULL 表示显式撤销，禁止删除撤销记录'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role.username IS ''用户账号'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role.nickname IS ''用户昵称'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role.revision IS ''角色变更版本号；当前数据范围保存不递增此值'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role.creator IS ''创建者'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role.updater IS ''更新者'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role.create_time IS ''创建时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role.update_time IS ''更新时间'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role.deleted IS ''固定为 0；撤销通过 role_code=NULL 表达，不使用逻辑删除'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_user_role_action
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_user_role_action') THEN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_user_role_action_seq' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.cost_user_role_action_seq'; END IF;
  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (tenant_id)'; END IF;
  EXECUTE 'CREATE TABLE cost_user_role_action (
        id bigint NOT NULL DEFAULT nextval(''cost_user_role_action_seq''),
        tenant_id bigint NOT NULL, user_id bigint NOT NULL, actor_id bigint NOT NULL,
        old_role_code varchar(255), new_role_code varchar(64), revision bigint NOT NULL,
        create_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT pk_cost_user_role_action PRIMARY KEY (tenant_id,id)
    )' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_user_role_action IS ''成本角色分配追加式审计，不参与外部源同步或业务清库'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role_action.id IS ''主键'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role_action.tenant_id IS ''租户编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role_action.user_id IS ''用户编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role_action.actor_id IS ''执行角色变更的用户编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role_action.old_role_code IS ''变更前角色编码'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role_action.new_role_code IS ''变更后角色编码；NULL 表示撤销'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role_action.revision IS ''角色变更版本号'';';
  EXECUTE 'COMMENT ON COLUMN cost_user_role_action.create_time IS ''创建时间'';';
 END IF;
END $create_missing$;

-- Create only when absent: cost_auth_user_lock
DO $create_missing$
DECLARE suffix text := '';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='cost_auth_user_lock') THEN

  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH (tenant_id)'; END IF;
  EXECUTE 'CREATE TABLE cost_auth_user_lock (
        tenant_id bigint NOT NULL, user_id bigint NOT NULL, revision bigint NOT NULL DEFAULT 0,
        CONSTRAINT pk_cost_auth_user_lock PRIMARY KEY (tenant_id,user_id)
    )' || suffix;
  EXECUTE 'COMMENT ON TABLE cost_auth_user_lock IS ''成本授权用户互斥锁表；按租户与用户串行化角色和范围写入，不参与同步清理'';';
  EXECUTE 'COMMENT ON COLUMN cost_auth_user_lock.tenant_id IS ''租户编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_auth_user_lock.user_id IS ''用户编号'';';
  EXECUTE 'COMMENT ON COLUMN cost_auth_user_lock.revision IS ''授权快照版本；角色或范围每次成功保存递增，拒绝陈旧页面覆盖'';';
 END IF;
END $create_missing$;

COMMIT;
