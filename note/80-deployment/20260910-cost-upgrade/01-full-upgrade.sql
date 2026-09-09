-- PostgreSQL 9.2+ / GaussDB(DWS). SQL only; not MySQL or DM.
-- CHANGE public below to the schema actually used by cost-server, not the database name.
-- Execute as a whole with stop-on-error; stop cost writes first and keep your backup.
BEGIN;
SET LOCAL search_path TO "public";
DO $schema_guard$ BEGIN
 IF current_schema() IS NULL THEN RAISE EXCEPTION 'Target schema does not exist or is inaccessible'; END IF;
END $schema_guard$;
-- Existing tenant is 124; change tenant literal below if needed.

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
LOCK TABLE cost_schema_migration IN EXCLUSIVE MODE;

-- Reconcile missing columns from current canonical schema; independent of migration versions.
DO $missing_columns$
DECLARE spec record;
BEGIN
 FOR spec IN SELECT * FROM (VALUES
 ('cost_model_node','id','int8         NOT NULL DEFAULT nextval(''cost_model_node_seq'')'),
 ('cost_model_node','parent_id','int8         NULL     DEFAULT NULL'),
 ('cost_model_node','node_code','varchar(128) NULL     DEFAULT NULL'),
 ('cost_model_node','node_name','varchar(255) NOT NULL'),
 ('cost_model_node','node_type','varchar(32)  NOT NULL'),
 ('cost_model_node','domain_code','varchar(128) NULL     DEFAULT NULL'),
 ('cost_model_node','sort','int4         NULL     DEFAULT 0'),
 ('cost_model_node','status','varchar(32)  NOT NULL DEFAULT ''ENABLE'''),
 ('cost_model_node','remark','varchar(500) NULL     DEFAULT NULL'),
 ('cost_model_node','creator','varchar(64)  NULL     DEFAULT '''''),
 ('cost_model_node','create_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_model_node','updater','varchar(64)  NULL     DEFAULT '''''),
 ('cost_model_node','update_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_model_node','deleted','int2         NOT NULL DEFAULT 0'),
 ('cost_model_node','tenant_id','int8         NOT NULL DEFAULT 0'),
 ('cost_project','id','int8         NOT NULL DEFAULT nextval(''cost_project_seq'')'),
 ('cost_project','project_code','varchar(128) NOT NULL'),
 ('cost_project','project_name','varchar(255) NOT NULL'),
 ('cost_project','model_node_id','int8         NULL     DEFAULT NULL'),
 ('cost_project','domain_code','varchar(128) NULL     DEFAULT NULL'),
 ('cost_project','domain_name','varchar(255) NULL     DEFAULT NULL'),
 ('cost_project','category_code','varchar(128) NULL     DEFAULT NULL'),
 ('cost_project','category_name','varchar(255) NULL     DEFAULT NULL'),
 ('cost_project','model_code','varchar(128) NULL     DEFAULT NULL'),
 ('cost_project','model_name','varchar(255) NULL     DEFAULT NULL'),
 ('cost_project','batch_no','varchar(128) NULL     DEFAULT NULL'),
 ('cost_project','stage_codes','varchar(255) NULL     DEFAULT NULL'),
 ('cost_project','unit_id','int8         NULL     DEFAULT NULL'),
 ('cost_project','unit_name','varchar(255) NULL     DEFAULT NULL'),
 ('cost_project','unit_type','varchar(64)  NULL     DEFAULT NULL'),
 ('cost_project','project_office_status','varchar(32)  NULL     DEFAULT NULL'),
 ('cost_project','unit_fill_status','varchar(32)  NULL     DEFAULT NULL'),
 ('cost_project','audit_status','varchar(32)  NULL     DEFAULT NULL'),
 ('cost_project','dept_id','int8         NULL     DEFAULT NULL'),
 ('cost_project','owner_user_id','int8         NULL     DEFAULT NULL'),
 ('cost_project','warning_status','varchar(32)  NULL     DEFAULT NULL'),
 ('cost_project','remark','varchar(500) NULL     DEFAULT NULL'),
 ('cost_project','creator','varchar(64)  NULL     DEFAULT '''''),
 ('cost_project','create_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_project','updater','varchar(64)  NULL     DEFAULT '''''),
 ('cost_project','update_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_project','deleted','int2         NOT NULL DEFAULT 0'),
 ('cost_project','tenant_id','int8         NOT NULL DEFAULT 0'),
 ('cost_project_basic','id','int8          NOT NULL DEFAULT nextval(''cost_project_basic_seq'')'),
 ('cost_project_basic','project_id','int8          NULL     DEFAULT NULL'),
 ('cost_project_basic','project_code','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_project_basic','project_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_project_basic','product_attachment_type','varchar(32) NULL DEFAULT NULL'),
 ('cost_project_basic','subsystem_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_project_basic','quantity','int4          NULL     DEFAULT NULL'),
 ('cost_project_basic','product_short_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_project_basic','vertical_division','bool          NULL     DEFAULT NULL'),
 ('cost_project_basic','user_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_project_basic','acquire_method','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_project_basic','batch_category','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_project_basic','platform_series','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_project_basic','research_unit_id','int8          NULL     DEFAULT NULL'),
 ('cost_project_basic','research_unit_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_project_basic','target_price','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_project_basic','competitor_unit_1','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_project_basic','competitor_price_1','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_project_basic','competitor_unit_2','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_project_basic','competitor_price_2','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_project_basic','contract_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_project_basic','tax_exempt','varchar(16)   NULL     DEFAULT NULL'),
 ('cost_project_basic','target_cost_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_project_basic','approved_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_project_basic','cycle_start','varchar(16)   NULL     DEFAULT NULL'),
 ('cost_project_basic','cycle_end','varchar(16)   NULL     DEFAULT NULL'),
 ('cost_project_basic','stage_code','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_project_basic','basic_info','text          NULL'),
 ('cost_project_basic','status','varchar(32)   NULL     DEFAULT NULL'),
 ('cost_project_basic','remark','varchar(500)  NULL     DEFAULT NULL'),
 ('cost_project_basic','import_batch_id','int8          NULL     DEFAULT NULL'),
 ('cost_project_basic','dept_id','int8          NULL     DEFAULT NULL'),
 ('cost_project_basic','owner_user_id','int8          NULL     DEFAULT NULL'),
 ('cost_project_basic','creator','varchar(64)   NULL     DEFAULT '''''),
 ('cost_project_basic','create_time','timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_project_basic','updater','varchar(64)   NULL     DEFAULT '''''),
 ('cost_project_basic','update_time','timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_project_basic','deleted','int2          NOT NULL DEFAULT 0'),
 ('cost_project_basic','tenant_id','int8          NOT NULL DEFAULT 0'),
 ('cost_work_order','id','int8          NOT NULL DEFAULT nextval(''cost_work_order_seq'')'),
 ('cost_work_order','source_work_order_id','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_work_order','project_id','int8          NULL     DEFAULT NULL'),
 ('cost_work_order','project_code','varchar(128)  NOT NULL'),
 ('cost_work_order','project_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_work_order','unit_id','int8          NULL     DEFAULT NULL'),
 ('cost_work_order','unit_name','varchar(255)  NOT NULL'),
 ('cost_work_order','accounting_unit_code','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_work_order','accounting_unit_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_work_order','fiscal_year','varchar(16)   NOT NULL DEFAULT '''''),
 ('cost_work_order','work_order_no','varchar(128)  NOT NULL'),
 ('cost_work_order','work_order_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_work_order','product_target_cost','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_work_order','contract_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_work_order','income_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_work_order','book_cost_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_work_order','stage_codes','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_work_order','max_stage_code','varchar(64)   NULL     DEFAULT NULL'),
 ('cost_work_order','subsystem_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_work_order','product_short_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_work_order','quantity','int4          NULL     DEFAULT NULL'),
 ('cost_work_order','vertical_division','bool          NULL     DEFAULT NULL'),
 ('cost_work_order','disabled','bool          NULL     DEFAULT false'),
 ('cost_work_order','approved_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_work_order','status','varchar(32)   NULL     DEFAULT NULL'),
 ('cost_work_order','remark','varchar(500)  NULL     DEFAULT NULL'),
 ('cost_work_order','import_batch_id','int8          NULL     DEFAULT NULL'),
 ('cost_work_order','dept_id','int8          NULL     DEFAULT NULL'),
 ('cost_work_order','owner_user_id','int8          NULL     DEFAULT NULL'),
 ('cost_work_order','creator','varchar(64)   NULL     DEFAULT '''''),
 ('cost_work_order','create_time','timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_work_order','updater','varchar(64)   NULL     DEFAULT '''''),
 ('cost_work_order','update_time','timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_work_order','deleted','int2          NOT NULL DEFAULT 0'),
 ('cost_work_order','tenant_id','int8          NOT NULL DEFAULT 0'),
 ('cost_work_order_ledger_detail','id','int8          NOT NULL DEFAULT nextval(''cost_work_order_ledger_detail_seq'')'),
 ('cost_work_order_ledger_detail','source_detail_id','varchar(128)  NOT NULL'),
 ('cost_work_order_ledger_detail','fiscal_year','varchar(16)   NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','accounting_period','varchar(16)   NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','voucher_date','date          NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','voucher_no','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','accounting_unit_id','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','accounting_unit_code','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','accounting_unit_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','manage_unit_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','subject_id','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','subject_code','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','subject_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','project_code','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','source_project_id','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','project_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','source_work_order_id','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','work_order_no','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','work_order_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','debit_credit','varchar(32)   NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','amount_wan','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','summary_text','varchar(1000) NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','source_lastmodify','timestamp     NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','second_subject_code','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','second_subject_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','source_timestamp','varchar(64)   NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','resolved_stage_code','varchar(64)   NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','project_id','int8          NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','work_order_id','int8          NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','remark','varchar(500)  NULL     DEFAULT NULL'),
 ('cost_work_order_ledger_detail','creator','varchar(64)   NULL     DEFAULT '''''),
 ('cost_work_order_ledger_detail','create_time','timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_work_order_ledger_detail','updater','varchar(64)   NULL     DEFAULT '''''),
 ('cost_work_order_ledger_detail','update_time','timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_work_order_ledger_detail','deleted','int2          NOT NULL DEFAULT 0'),
 ('cost_work_order_ledger_detail','tenant_id','int8          NOT NULL DEFAULT 0'),
 ('cost_unit_dict','id','int8         NOT NULL DEFAULT nextval(''cost_unit_dict_seq'')'),
 ('cost_unit_dict','accounting_unit_id','varchar(128) NULL     DEFAULT NULL'),
 ('cost_unit_dict','accounting_unit_code','varchar(128) NULL     DEFAULT NULL'),
 ('cost_unit_dict','accounting_unit_name','varchar(255) NULL     DEFAULT NULL'),
 ('cost_unit_dict','manage_unit_code','varchar(128) NULL     DEFAULT NULL'),
 ('cost_unit_dict','manage_unit_name','varchar(255) NULL     DEFAULT NULL'),
 ('cost_unit_dict','manage_unit_group','varchar(32)  NULL     DEFAULT NULL'),
 ('cost_unit_dict','contact_unit_code','varchar(128) NULL     DEFAULT NULL'),
 ('cost_unit_dict','contact_unit_name','varchar(255) NULL     DEFAULT NULL'),
 ('cost_unit_dict','inside_group','bool         NULL     DEFAULT false'),
 ('cost_unit_dict','inside_institute','bool         NULL     DEFAULT false'),
 ('cost_unit_dict','unit_id','int8         NULL     DEFAULT NULL'),
 ('cost_unit_dict','status','varchar(32)  NOT NULL DEFAULT ''ENABLE'''),
 ('cost_unit_dict','remark','varchar(500) NULL     DEFAULT NULL'),
 ('cost_unit_dict','creator','varchar(64)  NULL     DEFAULT '''''),
 ('cost_unit_dict','create_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_unit_dict','updater','varchar(64)  NULL     DEFAULT '''''),
 ('cost_unit_dict','update_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_unit_dict','deleted','int2         NOT NULL DEFAULT 0'),
 ('cost_unit_dict','tenant_id','int8         NOT NULL DEFAULT 0'),
 ('cost_subsystem_dict','id','int8         NOT NULL DEFAULT nextval(''cost_subsystem_dict_seq'')'),
 ('cost_subsystem_dict','subsystem_name','varchar(100) NOT NULL'),
 ('cost_subsystem_dict','sort_no','int4         NOT NULL DEFAULT 0'),
 ('cost_subsystem_dict','status','varchar(32)  NOT NULL DEFAULT ''ENABLE'''),
 ('cost_subsystem_dict','remark','varchar(500) NULL     DEFAULT NULL'),
 ('cost_subsystem_dict','creator','varchar(64)  NULL     DEFAULT '''''),
 ('cost_subsystem_dict','create_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_subsystem_dict','updater','varchar(64)  NULL     DEFAULT '''''),
 ('cost_subsystem_dict','update_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_subsystem_dict','deleted','int2         NOT NULL DEFAULT 0'),
 ('cost_subsystem_dict','tenant_id','int8         NOT NULL DEFAULT 0'),
 ('cost_unit_cost_detail','id','int8          NOT NULL DEFAULT nextval(''cost_unit_cost_detail_seq'')'),
 ('cost_unit_cost_detail','project_id','int8          NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','project_code','varchar(128)  NOT NULL'),
 ('cost_unit_cost_detail','project_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','domain_code','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','domain_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','model_node_id','int8          NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','model_code','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','model_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','unit_id','int8          NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','unit_name','varchar(255)  NOT NULL'),
 ('cost_unit_cost_detail','stage_code','varchar(64)   NOT NULL DEFAULT ''ALL'''),
 ('cost_unit_cost_detail','source_record_id','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','source_update_time','timestamp     NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','contract_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','income_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','target_cost_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','book_cost_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','approved_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','salary_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','material_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','outsource_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','manage_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','fuel_power_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','other_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','remark','varchar(500)  NULL     DEFAULT NULL'),
 ('cost_unit_cost_detail','creator','varchar(64)   NULL     DEFAULT '''''),
 ('cost_unit_cost_detail','create_time','timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_unit_cost_detail','updater','varchar(64)   NULL     DEFAULT '''''),
 ('cost_unit_cost_detail','update_time','timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_unit_cost_detail','deleted','int2          NOT NULL DEFAULT 0'),
 ('cost_unit_cost_detail','tenant_id','int8          NOT NULL DEFAULT 0'),
 ('cost_user_project_scope','id','int8         NOT NULL DEFAULT nextval(''cost_user_project_scope_seq'')'),
 ('cost_user_project_scope','user_id','int8         NOT NULL'),
 ('cost_user_project_scope','project_code','varchar(128) NOT NULL'),
 ('cost_user_project_scope','creator','varchar(64)  NULL     DEFAULT '''''),
 ('cost_user_project_scope','create_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_user_project_scope','updater','varchar(64)  NULL     DEFAULT '''''),
 ('cost_user_project_scope','update_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_user_project_scope','deleted','int2         NOT NULL DEFAULT 0'),
 ('cost_user_project_scope','tenant_id','int8         NOT NULL DEFAULT 0'),
 ('cost_user_unit_scope','id','int8         NOT NULL DEFAULT nextval(''cost_user_unit_scope_seq'')'),
 ('cost_user_unit_scope','user_id','int8         NOT NULL'),
 ('cost_user_unit_scope','manage_unit_code','varchar(128) NOT NULL'),
 ('cost_user_unit_scope','manage_unit_name','varchar(255) NOT NULL'),
 ('cost_user_unit_scope','creator','varchar(64)  NULL     DEFAULT '''''),
 ('cost_user_unit_scope','create_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_user_unit_scope','updater','varchar(64)  NULL     DEFAULT '''''),
 ('cost_user_unit_scope','update_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_user_unit_scope','deleted','int2         NOT NULL DEFAULT 0'),
 ('cost_user_unit_scope','tenant_id','int8         NOT NULL DEFAULT 0'),
 ('cost_user_domain_scope','id','int8         NOT NULL DEFAULT nextval(''cost_user_domain_scope_seq'')'),
 ('cost_user_domain_scope','user_id','int8         NOT NULL'),
 ('cost_user_domain_scope','domain_code','varchar(128) NOT NULL'),
 ('cost_user_domain_scope','creator','varchar(64)  NULL     DEFAULT '''''),
 ('cost_user_domain_scope','create_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_user_domain_scope','updater','varchar(64)  NULL     DEFAULT '''''),
 ('cost_user_domain_scope','update_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_user_domain_scope','deleted','int2         NOT NULL DEFAULT 0'),
 ('cost_user_domain_scope','tenant_id','int8         NOT NULL DEFAULT 0'),
 ('cost_import_batch','id','int8         NOT NULL DEFAULT nextval(''cost_import_batch_seq'')'),
 ('cost_import_batch','import_type','varchar(64)  NOT NULL'),
 ('cost_import_batch','file_name','varchar(255) NULL     DEFAULT NULL'),
 ('cost_import_batch','file_url','varchar(500) NULL     DEFAULT NULL'),
 ('cost_import_batch','total_count','int4         NULL     DEFAULT 0'),
 ('cost_import_batch','success_count','int4         NULL     DEFAULT 0'),
 ('cost_import_batch','failure_count','int4         NULL     DEFAULT 0'),
 ('cost_import_batch','update_support','bool         NULL     DEFAULT false'),
 ('cost_import_batch','status','varchar(32)  NULL     DEFAULT NULL'),
 ('cost_import_batch','error_file_url','varchar(500) NULL     DEFAULT NULL'),
 ('cost_import_batch','remark','varchar(500) NULL     DEFAULT NULL'),
 ('cost_import_batch','creator','varchar(64)  NULL     DEFAULT '''''),
 ('cost_import_batch','create_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_import_batch','updater','varchar(64)  NULL     DEFAULT '''''),
 ('cost_import_batch','update_time','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_import_batch','deleted','int2         NOT NULL DEFAULT 0'),
 ('cost_import_batch','tenant_id','int8         NOT NULL DEFAULT 0'),
 ('cost_import_error','id','int8          NOT NULL DEFAULT nextval(''cost_import_error_seq'')'),
 ('cost_import_error','batch_id','int8          NOT NULL'),
 ('cost_import_error','row_num','int4          NULL     DEFAULT NULL'),
 ('cost_import_error','field_name','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_import_error','error_message','varchar(1000) NULL     DEFAULT NULL'),
 ('cost_import_error','raw_data','text          NULL'),
 ('cost_import_error','creator','varchar(64)   NULL     DEFAULT '''''),
 ('cost_import_error','create_time','timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_import_error','updater','varchar(64)   NULL     DEFAULT '''''),
 ('cost_import_error','update_time','timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_import_error','deleted','int2          NOT NULL DEFAULT 0'),
 ('cost_import_error','tenant_id','int8          NOT NULL DEFAULT 0'),
 ('cost_warning_record','id','int8          NOT NULL DEFAULT nextval(''cost_warning_record_seq'')'),
 ('cost_warning_record','project_id','int8          NULL     DEFAULT NULL'),
 ('cost_warning_record','work_order_id','int8          NULL     DEFAULT NULL'),
 ('cost_warning_record','project_code','varchar(100)  NULL     DEFAULT NULL'),
 ('cost_warning_record','project_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_warning_record','domain_code','varchar(100)  NULL     DEFAULT NULL'),
 ('cost_warning_record','domain_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_warning_record','model_code','varchar(100)  NULL     DEFAULT NULL'),
 ('cost_warning_record','model_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_warning_record','warning_source','varchar(32)   NULL     DEFAULT NULL'),
 ('cost_warning_record','warning_title','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_warning_record','target_cost_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_warning_record','actual_cost_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_warning_record','over_amount','numeric(18,2) NULL     DEFAULT NULL'),
 ('cost_warning_record','over_rate','numeric(18,4) NULL     DEFAULT NULL'),
 ('cost_warning_record','threshold_rate','numeric(18,4) NULL     DEFAULT NULL'),
 ('cost_warning_record','warning_level','varchar(32)   NULL     DEFAULT NULL'),
 ('cost_warning_record','responsible_unit_name','varchar(255)  NULL     DEFAULT NULL'),
 ('cost_warning_record','push_status','varchar(32)   NULL     DEFAULT NULL'),
 ('cost_warning_record','pushed_time','timestamp     NULL     DEFAULT NULL'),
 ('cost_warning_record','receiver_scope','varchar(1000) NULL     DEFAULT NULL'),
 ('cost_warning_record','message_id','int8          NULL     DEFAULT NULL'),
 ('cost_warning_record','status','varchar(32)   NULL     DEFAULT NULL'),
 ('cost_warning_record','remark','varchar(500)  NULL     DEFAULT NULL'),
 ('cost_warning_record','cycle_no','int4          NULL     DEFAULT NULL'),
 ('cost_warning_record','workflow_status','varchar(32)   NULL     DEFAULT NULL'),
 ('cost_warning_record','active_marker','int2          NULL     DEFAULT NULL'),
 ('cost_warning_record','initiator_user_id','int8          NULL     DEFAULT NULL'),
 ('cost_warning_record','initiator_user_name','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_warning_record','initiated_time','timestamp     NULL     DEFAULT NULL'),
 ('cost_warning_record','disposition_user_id','int8          NULL     DEFAULT NULL'),
 ('cost_warning_record','disposition_user_name','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_warning_record','cause_analysis','varchar(1000) NULL     DEFAULT NULL'),
 ('cost_warning_record','disposal_measure','varchar(1000) NULL     DEFAULT NULL'),
 ('cost_warning_record','expected_completion_date','date       NULL     DEFAULT NULL'),
 ('cost_warning_record','disposition_time','timestamp     NULL     DEFAULT NULL'),
 ('cost_warning_record','close_user_id','int8          NULL     DEFAULT NULL'),
 ('cost_warning_record','close_user_name','varchar(128)  NULL     DEFAULT NULL'),
 ('cost_warning_record','close_time','timestamp     NULL     DEFAULT NULL'),
 ('cost_warning_record','return_reason','varchar(500)  NULL     DEFAULT NULL'),
 ('cost_warning_record','creator','varchar(64)   NULL     DEFAULT '''''),
 ('cost_warning_record','create_time','timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_warning_record','updater','varchar(64)   NULL     DEFAULT '''''),
 ('cost_warning_record','update_time','timestamp     NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_warning_record','deleted','int2          NOT NULL DEFAULT 0'),
 ('cost_warning_record','tenant_id','int8          NOT NULL DEFAULT 0'),
 ('cost_warning_receiver','id','int8 NOT NULL DEFAULT nextval(''cost_warning_receiver_seq'')'),
 ('cost_warning_receiver','warning_record_id','int8 NOT NULL'),
 ('cost_warning_receiver','user_id','int8 NOT NULL'),
 ('cost_warning_receiver','username','varchar(64)'),
 ('cost_warning_receiver','nickname','varchar(128)'),
 ('cost_warning_receiver','notify_status','varchar(32) NOT NULL DEFAULT ''PENDING'''),
 ('cost_warning_receiver','message_id','int8'),
 ('cost_warning_receiver','notified_time','timestamp'),
 ('cost_warning_receiver','failure_reason','varchar(500)'),
 ('cost_warning_receiver','creator','varchar(64) DEFAULT '''''),
 ('cost_warning_receiver','create_time','timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_warning_receiver','updater','varchar(64) DEFAULT '''''),
 ('cost_warning_receiver','update_time','timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_warning_receiver','deleted','int2 NOT NULL DEFAULT 0'),
 ('cost_warning_receiver','tenant_id','int8 NOT NULL DEFAULT 0'),
 ('cost_warning_action_log','id','int8 NOT NULL DEFAULT nextval(''cost_warning_action_log_seq'')'),
 ('cost_warning_action_log','warning_record_id','int8 NOT NULL'),
 ('cost_warning_action_log','action_type','varchar(32) NOT NULL'),
 ('cost_warning_action_log','operator_user_id','int8 NOT NULL'),
 ('cost_warning_action_log','operator_user_name','varchar(128)'),
 ('cost_warning_action_log','operator_role_code','varchar(100)'),
 ('cost_warning_action_log','from_status','varchar(32)'),
 ('cost_warning_action_log','to_status','varchar(32)'),
 ('cost_warning_action_log','action_content','varchar(1000)'),
 ('cost_warning_action_log','creator','varchar(64) DEFAULT '''''),
 ('cost_warning_action_log','create_time','timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_warning_action_log','updater','varchar(64) DEFAULT '''''),
 ('cost_warning_action_log','update_time','timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_warning_action_log','deleted','int2 NOT NULL DEFAULT 0'),
 ('cost_warning_action_log','tenant_id','int8 NOT NULL DEFAULT 0'),
 ('cost_schema_migration','version','varchar(32)  NOT NULL'),
 ('cost_schema_migration','description','varchar(255) NOT NULL'),
 ('cost_schema_migration','installed_on','timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_schema_migration','installed_by','varchar(128) NOT NULL DEFAULT CURRENT_USER'),
 ('cost_user_role','id','bigint NOT NULL DEFAULT nextval(''cost_user_role_seq'')'),
 ('cost_user_role','tenant_id','bigint NOT NULL'),
 ('cost_user_role','user_id','bigint NOT NULL'),
 ('cost_user_role','role_code','varchar(64)'),
 ('cost_user_role','username','varchar(128) NOT NULL'),
 ('cost_user_role','nickname','varchar(255)'),
 ('cost_user_role','revision','bigint NOT NULL DEFAULT 1'),
 ('cost_user_role','creator','varchar(64) DEFAULT '''''),
 ('cost_user_role','updater','varchar(64) DEFAULT '''''),
 ('cost_user_role','create_time','timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_user_role','update_time','timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_user_role','deleted','smallint NOT NULL DEFAULT 0 CHECK (deleted=0)'),
 ('cost_user_role_action','id','bigint NOT NULL DEFAULT nextval(''cost_user_role_action_seq'')'),
 ('cost_user_role_action','tenant_id','bigint NOT NULL'),
 ('cost_user_role_action','user_id','bigint NOT NULL'),
 ('cost_user_role_action','actor_id','bigint NOT NULL'),
 ('cost_user_role_action','old_role_code','varchar(255)'),
 ('cost_user_role_action','new_role_code','varchar(64)'),
 ('cost_user_role_action','revision','bigint NOT NULL'),
 ('cost_user_role_action','create_time','timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP'),
 ('cost_auth_user_lock','tenant_id','bigint NOT NULL'),
 ('cost_auth_user_lock','user_id','bigint NOT NULL'),
 ('cost_auth_user_lock','revision','bigint NOT NULL DEFAULT 0')
 ) AS required(table_name,column_name,definition) LOOP
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema()
     AND table_name=spec.table_name AND column_name=spec.column_name) THEN
   RAISE NOTICE 'Adding %.%', spec.table_name, spec.column_name;
   EXECUTE 'ALTER TABLE ' || quote_ident(current_schema()) || '.' || quote_ident(spec.table_name)
      || ' ADD COLUMN ' || quote_ident(spec.column_name) || ' ' || spec.definition;
  END IF;
 END LOOP;
END $missing_columns$;
-- Costree 发布 20260907；仅执行于已备份、停止写入的成本库。
-- GaussDB(DWS) / PostgreSQL 9.2 引擎识别与兼容性预检查。
-- 只读脚本，可在空库或已有库执行。

SELECT current_database() AS database_name,
       current_user AS database_user,
       current_schema() AS current_schema,
       version() AS database_version,
       current_setting('server_version_num') AS server_version_num,
       CASE WHEN position('gaussdb' in lower(version())) > 0
                  OR position('dws' in lower(version())) > 0
            THEN 'GaussDB(DWS)'
            ELSE 'PostgreSQL' END AS detected_engine;

DO $$
DECLARE
    v_is_dws bool;
BEGIN
    v_is_dws := position('gaussdb' in lower(version())) > 0
                OR position('dws' in lower(version())) > 0;
    IF v_is_dws THEN
        RAISE NOTICE '已识别 GaussDB(DWS)。业务防重索引将使用 DWS 兼容模式；同步脚本负责串行锁和重复键强校验。';
    ELSIF current_setting('server_version_num')::integer >= 90200 THEN
        RAISE NOTICE 'PostgreSQL 9.2+ detected; native unique indexes apply.';
    ELSE
        RAISE EXCEPTION 'postgresql92 目录不适用于当前数据库：%', version();
    END IF;
END $$;

SELECT t.table_name AS existing_cost_table
FROM information_schema.tables t
WHERE t.table_schema = current_schema()
  AND t.table_name LIKE 'cost_%'
ORDER BY t.table_name;

SELECT i.indexname,
       CASE WHEN i.indexdef LIKE 'CREATE UNIQUE INDEX%' THEN 'UNIQUE' ELSE 'NON_UNIQUE' END AS index_mode,
       i.indexdef
FROM pg_indexes i
WHERE i.schemaname = current_schema()
  AND i.indexname IN (
      'uk_cost_unit_cost_project_unit',
      'uk_cost_work_order_business',
      'uk_cost_ledger_source_detail'
  )
ORDER BY i.indexname;

-- DWS 上以上三个索引显示 NON_UNIQUE 是预期结果；20-verify.sql 会继续强校验实际重复键为 0。

-- 成本库 PostgreSQL 9.2 / GaussDB(DWS) 8.2.1 迁移前只读检查。
-- 本文件不修改业务数据。目标结构版本：20260722。

SELECT current_database() AS database_name,
       current_user AS database_user,
       current_setting('server_version') AS server_version,
       current_setting('server_version_num')::integer AS server_version_num,
       CASE WHEN position('gaussdb' in lower(version())) > 0
                  OR position('dws' in lower(version())) > 0
            THEN 'GaussDB(DWS)'
            ELSE 'PostgreSQL' END AS database_engine,
       CASE WHEN position('gaussdb' in lower(version())) > 0
                  OR position('dws' in lower(version())) > 0
                  OR (current_setting('server_version_num')::integer >= 90200)
            THEN 'OK' ELSE 'BLOCK: require PostgreSQL 9.2.x or GaussDB(DWS) 8.2.1' END AS version_check;

WITH required_table(table_name) AS (
    VALUES ('cost_project_basic'),
           ('cost_unit_cost_detail'),
           ('cost_unit_dict'),
           ('cost_work_order'),
           ('cost_work_order_ledger_detail'),
           ('cost_warning_record')
)
SELECT r.table_name AS missing_required_table
FROM required_table r
LEFT JOIN information_schema.tables t
  ON t.table_schema = current_schema() AND t.table_name = r.table_name
WHERE t.table_name IS NULL
ORDER BY r.table_name;

DO $$
DECLARE
    missing_tables text;
BEGIN
    SELECT string_agg(required.table_name, ', ' ORDER BY required.table_name)
      INTO missing_tables
    FROM (VALUES ('cost_project_basic'),
                 ('cost_unit_cost_detail'),
                 ('cost_unit_dict'),
                 ('cost_work_order'),
                 ('cost_work_order_ledger_detail'),
                 ('cost_warning_record')) AS required(table_name)
    WHERE NOT EXISTS (
        SELECT 1
        FROM information_schema.tables t
        WHERE t.table_schema = current_schema()
          AND t.table_name = required.table_name
    );

    IF missing_tables IS NOT NULL THEN
        RAISE EXCEPTION '缺少成本库基础表：%。空库请执行 costree-cost.sql', missing_tables;
    END IF;
END $$;

WITH required_column(table_name, column_name) AS (
    VALUES
        ('cost_project_basic', 'product_attachment_type'),
        ('cost_project_basic', 'tax_exempt'),
        ('cost_unit_cost_detail', 'approved_amount'),
        ('cost_unit_cost_detail', 'source_record_id'),
        ('cost_unit_cost_detail', 'source_update_time'),
        ('cost_unit_dict', 'manage_unit_group'),
        ('cost_work_order', 'source_work_order_id'),
        ('cost_work_order', 'accounting_unit_code'),
        ('cost_work_order', 'accounting_unit_name'),
        ('cost_work_order', 'fiscal_year'),
        ('cost_work_order', 'contract_amount'),
        ('cost_work_order', 'income_amount'),
        ('cost_work_order', 'disabled'),
        ('cost_work_order', 'approved_amount')
)
SELECT r.table_name, r.column_name AS missing_required_column
FROM required_column r
LEFT JOIN information_schema.columns c
  ON c.table_schema = current_schema()
 AND c.table_name = r.table_name
 AND c.column_name = r.column_name
WHERE c.column_name IS NULL
ORDER BY r.table_name, r.column_name;

SELECT tenant_id, project_code, unit_name, count(*) AS duplicate_count
FROM cost_unit_cost_detail
GROUP BY tenant_id, project_code, unit_name
HAVING count(*) > 1
ORDER BY duplicate_count DESC, tenant_id, project_code, unit_name;

SELECT tenant_id, project_code, unit_name, work_order_no, count(*) AS yearly_row_count
FROM cost_work_order
WHERE deleted = 0
GROUP BY tenant_id, project_code, unit_name, work_order_no
HAVING count(*) > 1
ORDER BY yearly_row_count DESC, tenant_id, project_code, unit_name, work_order_no;

-- 9.2 没有 to_jsonb。新增金额列尚未全部存在时跳过本项；升级脚本补列后会再次强校验。
DO $$
DECLARE
    conflict_count bigint;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_work_order' AND column_name = 'contract_amount')
       AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_work_order' AND column_name = 'income_amount')
       AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_work_order' AND column_name = 'approved_amount') THEN
        EXECUTE $sql$
            SELECT count(*)
            FROM (
                SELECT 1
                FROM cost_work_order
                WHERE deleted = 0
                GROUP BY tenant_id, project_code, unit_name, work_order_no
                HAVING count(DISTINCT CASE WHEN product_target_cost IS NOT NULL THEN product_target_cost END) > 1
                    OR count(DISTINCT CASE WHEN contract_amount IS NOT NULL THEN contract_amount END) > 1
                    OR count(DISTINCT CASE WHEN income_amount IS NOT NULL THEN income_amount END) > 1
                    OR count(DISTINCT CASE WHEN approved_amount IS NOT NULL THEN approved_amount END) > 1
            ) conflict_rows
        $sql$ INTO conflict_count;
        RAISE NOTICE '同一逻辑工作令固定金额冲突组数：%', conflict_count;
    ELSE
        RAISE NOTICE '工作令新增金额列尚未齐全，固定金额冲突检查由升级脚本补列后执行';
    END IF;
END $$;

SELECT 'cost_unit_cost_detail' AS table_name, count(*) AS invalid_business_key_count
FROM cost_unit_cost_detail
WHERE project_code IS NULL OR btrim(project_code) = ''
   OR unit_name IS NULL OR btrim(unit_name) = ''
UNION ALL
SELECT 'cost_work_order', count(*)
FROM cost_work_order
WHERE project_code IS NULL OR btrim(project_code) = ''
   OR unit_name IS NULL OR btrim(unit_name) = ''
   OR work_order_no IS NULL OR btrim(work_order_no) = ''
UNION ALL
SELECT 'cost_work_order_ledger_detail', count(*)
FROM cost_work_order_ledger_detail
WHERE source_detail_id IS NULL OR btrim(source_detail_id) = '';

SELECT tenant_id, source_detail_id, count(*) AS duplicate_count
FROM cost_work_order_ledger_detail
WHERE source_detail_id IS NOT NULL AND btrim(source_detail_id) <> ''
GROUP BY tenant_id, source_detail_id
HAVING count(*) > 1
ORDER BY duplicate_count DESC, tenant_id, source_detail_id;

SELECT debit_credit, count(*) AS detail_count,
       sum(COALESCE(amount / 10000.0, amount_wan, 0)) AS amount_wan
FROM cost_work_order_ledger_detail
WHERE deleted = 0
GROUP BY debit_credit
ORDER BY debit_credit;

DO $dup$ BEGIN
 IF EXISTS (SELECT 1 FROM cost_work_order GROUP BY tenant_id, project_code, unit_name, work_order_no HAVING count(*)>1)
 OR EXISTS (SELECT 1 FROM cost_unit_cost_detail GROUP BY tenant_id, project_code, unit_name HAVING count(*)>1) THEN
 RAISE EXCEPTION '存在重复业务键，禁止自动合并或删除填报数据；请保留本次只读检查结果'; END IF;
 IF NOT EXISTS (SELECT 1 FROM cost_project WHERE tenant_id=124) THEN
 RAISE EXCEPTION '此成本 schema 内没有所填租户的项目，请确认租户及 schema'; END IF;
END $dup$;
CREATE TABLE IF NOT EXISTS cost_schema_migration (
 version varchar(32) PRIMARY KEY, description varchar(255) NOT NULL,
 installed_on timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, installed_by varchar(128) NOT NULL DEFAULT CURRENT_USER);

-- 10-upgrade-existing-to-20260722.sql: 已达到此版本则跳过，避免重跑旧数据归并。
DO $gate20260722$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM cost_schema_migration WHERE version >= '20260722') THEN
 EXECUTE $migration20260722$-- 成本库 PostgreSQL 9.2 / GaussDB(DWS) 8.2.1 旧库统一升级脚本。
-- 目标结构版本：20260722。
-- 必须先执行 00-precheck.sql 并完成备份，迁移期间停止应用和同步任务。



DO $$
DECLARE
    missing_tables text;
    v_is_dws bool;
BEGIN
    v_is_dws := position('gaussdb' in lower(version())) > 0
                OR position('dws' in lower(version())) > 0;
    IF NOT v_is_dws
       AND (current_setting('server_version_num')::integer < 90200) THEN
        RAISE EXCEPTION '本迁移脚本仅适用于 PostgreSQL 9.2.x 或 GaussDB(DWS) 8.2.1，当前版本为 %', version();
    END IF;
    RAISE NOTICE 'Costree database engine: %', CASE WHEN v_is_dws THEN 'GaussDB(DWS)' ELSE 'PostgreSQL 9.2' END;

    SELECT string_agg(required.table_name, ', ' ORDER BY required.table_name)
      INTO missing_tables
    FROM (VALUES ('cost_project'),
                 ('cost_project_basic'),
                 ('cost_unit_cost_detail'),
                 ('cost_unit_dict'),
                 ('cost_work_order'),
                 ('cost_work_order_ledger_detail'),
                 ('cost_warning_record')) AS required(table_name)
    WHERE NOT EXISTS (
        SELECT 1
        FROM information_schema.tables t
        WHERE t.table_schema = current_schema()
          AND t.table_name = required.table_name
    );

    IF missing_tables IS NOT NULL THEN
        RAISE EXCEPTION '缺少成本库基础表：%。空库请执行 costree-cost.sql，不要执行旧库升级脚本', missing_tables;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS cost_schema_migration
(
    version         varchar(32)  NOT NULL,
    description     varchar(255) NOT NULL,
    installed_on    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    installed_by    varchar(128) NOT NULL DEFAULT CURRENT_USER,
    CONSTRAINT pk_cost_schema_migration PRIMARY KEY (version)
);

-- PostgreSQL 9.2 不支持 ADD COLUMN IF NOT EXISTS，改用系统目录条件判断。
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'product_attachment_type') THEN
        ALTER TABLE cost_project_basic ADD COLUMN product_attachment_type varchar(32) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'tax_exempt') THEN
        ALTER TABLE cost_project_basic ADD COLUMN tax_exempt varchar(16) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'cycle_start') THEN
        ALTER TABLE cost_project_basic ADD COLUMN cycle_start varchar(16) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'cycle_end') THEN
        ALTER TABLE cost_project_basic ADD COLUMN cycle_end varchar(16) NULL DEFAULT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_unit_cost_detail' AND column_name = 'approved_amount') THEN
        ALTER TABLE cost_unit_cost_detail ADD COLUMN approved_amount numeric(18,2) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_unit_cost_detail' AND column_name = 'source_record_id') THEN
        ALTER TABLE cost_unit_cost_detail ADD COLUMN source_record_id varchar(128) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_unit_cost_detail' AND column_name = 'source_update_time') THEN
        ALTER TABLE cost_unit_cost_detail ADD COLUMN source_update_time timestamp NULL DEFAULT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_unit_dict' AND column_name = 'manage_unit_group') THEN
        ALTER TABLE cost_unit_dict ADD COLUMN manage_unit_group varchar(32) NULL DEFAULT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_work_order' AND column_name = 'source_work_order_id') THEN
        ALTER TABLE cost_work_order ADD COLUMN source_work_order_id varchar(128) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_work_order' AND column_name = 'accounting_unit_code') THEN
        ALTER TABLE cost_work_order ADD COLUMN accounting_unit_code varchar(128) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_work_order' AND column_name = 'accounting_unit_name') THEN
        ALTER TABLE cost_work_order ADD COLUMN accounting_unit_name varchar(255) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_work_order' AND column_name = 'fiscal_year') THEN
        ALTER TABLE cost_work_order ADD COLUMN fiscal_year varchar(16) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_work_order' AND column_name = 'contract_amount') THEN
        ALTER TABLE cost_work_order ADD COLUMN contract_amount numeric(18,2) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_work_order' AND column_name = 'income_amount') THEN
        ALTER TABLE cost_work_order ADD COLUMN income_amount numeric(18,2) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_work_order' AND column_name = 'disabled') THEN
        ALTER TABLE cost_work_order ADD COLUMN disabled boolean NULL DEFAULT false;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_work_order' AND column_name = 'approved_amount') THEN
        ALTER TABLE cost_work_order ADD COLUMN approved_amount numeric(18,2) NULL DEFAULT NULL;
    END IF;
END $$;

ALTER TABLE cost_project_basic
    ALTER COLUMN cycle_start TYPE varchar(16)
        USING NULLIF(substring(cycle_start::text FROM 1 FOR 7), ''),
    ALTER COLUMN cycle_end TYPE varchar(16)
        USING NULLIF(substring(cycle_end::text FROM 1 FOR 7), '');

-- 仅自动归并仓库自带的 cost_seed 测试样本。真实数据重复时由后续校验阻断。
DROP TABLE IF EXISTS tmp_cost_seed_unit_merge;
CREATE TEMP TABLE tmp_cost_seed_unit_merge ON COMMIT DELETE ROWS AS
SELECT min(id) AS keep_id, tenant_id, project_code, unit_name,
       sum(COALESCE(contract_amount, 0)) AS contract_amount,
       sum(COALESCE(income_amount, 0)) AS income_amount,
       sum(COALESCE(target_cost_amount, 0)) AS target_cost_amount,
       sum(COALESCE(book_cost_amount, 0)) AS book_cost_amount,
       sum(COALESCE(approved_amount, 0)) AS approved_amount,
       sum(COALESCE(salary_amount, 0)) AS salary_amount,
       sum(COALESCE(material_amount, 0)) AS material_amount,
       sum(COALESCE(outsource_amount, 0)) AS outsource_amount,
       sum(COALESCE(manage_amount, 0)) AS manage_amount,
       sum(COALESCE(fuel_power_amount, 0)) AS fuel_power_amount,
       sum(COALESCE(other_amount, 0)) AS other_amount
FROM cost_unit_cost_detail
WHERE creator = 'cost_seed'
GROUP BY tenant_id, project_code, unit_name;

UPDATE cost_unit_cost_detail detail
SET stage_code = 'ALL',
    contract_amount = merged.contract_amount,
    income_amount = merged.income_amount,
    target_cost_amount = merged.target_cost_amount,
    book_cost_amount = merged.book_cost_amount,
    approved_amount = merged.approved_amount,
    salary_amount = merged.salary_amount,
    material_amount = merged.material_amount,
    outsource_amount = merged.outsource_amount,
    manage_amount = merged.manage_amount,
    fuel_power_amount = merged.fuel_power_amount,
    other_amount = merged.other_amount
FROM tmp_cost_seed_unit_merge merged
WHERE detail.id = merged.keep_id;

DELETE FROM cost_unit_cost_detail detail
USING tmp_cost_seed_unit_merge merged
WHERE detail.creator = 'cost_seed'
  AND detail.tenant_id = merged.tenant_id
  AND detail.project_code = merged.project_code
  AND detail.unit_name = merged.unit_name
  AND detail.id <> merged.keep_id;

UPDATE cost_unit_cost_detail
SET stage_code = 'ALL'
WHERE stage_code IS DISTINCT FROM 'ALL';

-- 业务键和源明细 ID 不完整时禁止继续，避免迁移后产生不可追溯数据。
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM cost_unit_cost_detail
        WHERE project_code IS NULL OR btrim(project_code) = ''
           OR unit_name IS NULL OR btrim(unit_name) = ''
    ) THEN
        RAISE EXCEPTION 'cost_unit_cost_detail 存在空项目编码或空单位名称，请先修复';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_unit_cost_detail
        GROUP BY tenant_id, project_code, unit_name HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'cost_unit_cost_detail 存在项目单位重复记录，请先按预分预控权威快照清理';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_work_order
        WHERE project_code IS NULL OR btrim(project_code) = ''
           OR unit_name IS NULL OR btrim(unit_name) = ''
           OR work_order_no IS NULL OR btrim(work_order_no) = ''
    ) THEN
        RAISE EXCEPTION 'cost_work_order 存在空项目编码、空单位名称或空工作令编号，请先修复';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_work_order_ledger_detail
        WHERE source_detail_id IS NULL OR btrim(source_detail_id) = ''
    ) THEN
        RAISE EXCEPTION 'cost_work_order_ledger_detail 存在空源明细 ID，请先补齐或隔离';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_work_order_ledger_detail
        GROUP BY tenant_id, source_detail_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'cost_work_order_ledger_detail 存在重复源明细 ID，请先去重';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM cost_work_order
        WHERE deleted = 0
        GROUP BY tenant_id, project_code, unit_name, work_order_no
        HAVING count(DISTINCT CASE WHEN product_target_cost IS NOT NULL THEN product_target_cost END) > 1
            OR count(DISTINCT CASE WHEN contract_amount IS NOT NULL THEN contract_amount END) > 1
            OR count(DISTINCT CASE WHEN income_amount IS NOT NULL THEN income_amount END) > 1
            OR count(DISTINCT CASE WHEN approved_amount IS NOT NULL THEN approved_amount END) > 1
    ) THEN
        RAISE EXCEPTION '同一逻辑工作令存在合同、到款、目标或审定金额冲突，请先确认权威值';
    END IF;
END $$;

ALTER TABLE cost_unit_cost_detail
    ALTER COLUMN project_code SET NOT NULL,
    ALTER COLUMN unit_name SET NOT NULL,
    ALTER COLUMN stage_code SET DEFAULT 'ALL',
    ALTER COLUMN stage_code SET NOT NULL;

ALTER TABLE cost_work_order
    ALTER COLUMN project_code SET NOT NULL,
    ALTER COLUMN unit_name SET NOT NULL;

ALTER TABLE cost_work_order_ledger_detail
    ALTER COLUMN source_detail_id SET NOT NULL;

-- 同一工作令跨年度旧行合并为一条逻辑工作令。
DROP TABLE IF EXISTS tmp_cost_work_order_merge_map;
CREATE TEMP TABLE tmp_cost_work_order_merge_map ON COMMIT DELETE ROWS AS
SELECT id AS old_id,
       first_value(id) OVER (
           PARTITION BY tenant_id, project_code, unit_name, work_order_no
           ORDER BY deleted ASC,
                    CASE WHEN COALESCE(btrim(fiscal_year), '') = '' THEN 0 ELSE 1 END,
                    CASE WHEN fiscal_year ~ '^[0-9]{4}$' THEN fiscal_year::integer ELSE 0 END DESC,
                    update_time DESC,
                    id DESC
       ) AS keep_id
FROM cost_work_order;

UPDATE cost_work_order keeper
SET product_target_cost = fixed.product_target_cost,
    contract_amount = fixed.contract_amount,
    income_amount = fixed.income_amount,
    approved_amount = fixed.approved_amount,
    update_time = CURRENT_TIMESTAMP
FROM (
    SELECT mapping.keep_id,
           COALESCE(max(CASE WHEN work_order.deleted = 0 THEN work_order.product_target_cost END),
                    max(work_order.product_target_cost)) AS product_target_cost,
           COALESCE(max(CASE WHEN work_order.deleted = 0 THEN work_order.contract_amount END),
                    max(work_order.contract_amount)) AS contract_amount,
           COALESCE(max(CASE WHEN work_order.deleted = 0 THEN work_order.income_amount END),
                    max(work_order.income_amount)) AS income_amount,
           COALESCE(max(CASE WHEN work_order.deleted = 0 THEN work_order.approved_amount END),
                    max(work_order.approved_amount)) AS approved_amount
    FROM tmp_cost_work_order_merge_map mapping
    JOIN cost_work_order work_order ON work_order.id = mapping.old_id
    GROUP BY mapping.keep_id
) fixed
WHERE keeper.id = fixed.keep_id;

UPDATE cost_work_order_ledger_detail detail
SET work_order_id = mapping.keep_id,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_work_order_merge_map mapping
WHERE detail.work_order_id = mapping.old_id
  AND mapping.old_id <> mapping.keep_id;

UPDATE cost_warning_record warning
SET work_order_id = mapping.keep_id,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_work_order_merge_map mapping
WHERE warning.work_order_id = mapping.old_id
  AND mapping.old_id <> mapping.keep_id;

DELETE FROM cost_work_order work_order
USING tmp_cost_work_order_merge_map mapping
WHERE work_order.id = mapping.old_id
  AND mapping.old_id <> mapping.keep_id;

UPDATE cost_work_order
SET fiscal_year = '',
    update_time = CURRENT_TIMESTAMP;

ALTER TABLE cost_work_order
    ALTER COLUMN fiscal_year SET DEFAULT '',
    ALTER COLUMN fiscal_year SET NOT NULL;

-- 用当前统一业务键补齐历史明细关联。无法匹配的明细由验收脚本列出。
UPDATE cost_work_order_ledger_detail detail
SET work_order_id = work_order.id,
    project_id = COALESCE(detail.project_id, work_order.project_id),
    update_time = CURRENT_TIMESTAMP
FROM cost_work_order work_order
WHERE detail.tenant_id = work_order.tenant_id
  AND detail.project_code = work_order.project_code
  AND detail.accounting_unit_name = work_order.unit_name
  AND detail.work_order_no = work_order.work_order_no
  AND detail.deleted = 0
  AND work_order.deleted = 0
  AND detail.work_order_id IS DISTINCT FROM work_order.id;

-- 金额统一：amount 保存元，amount_wan 保存万元；贷方保留但不进入成本统计。
UPDATE cost_work_order_ledger_detail
SET amount_wan = round(amount / 10000.0, 2),
    update_time = CURRENT_TIMESTAMP
WHERE amount IS NOT NULL
  AND amount_wan IS DISTINCT FROM round(amount / 10000.0, 2);

UPDATE cost_work_order work_order
SET book_cost_amount = COALESCE(summary.book_cost_amount, 0),
    update_time = CURRENT_TIMESTAMP
FROM (
    SELECT work_order.id,
           sum(COALESCE(detail.amount / 10000.0, detail.amount_wan, 0)) AS book_cost_amount
    FROM cost_work_order work_order
    LEFT JOIN cost_work_order_ledger_detail detail
      ON detail.work_order_id = work_order.id
     AND detail.deleted = 0
     AND btrim(COALESCE(detail.debit_credit, '')) = '借'
    GROUP BY work_order.id
) summary
WHERE work_order.id = summary.id;

-- 管理单位分类。未命中的院内单位保留 NULL，页面归入“未分类院内单位”。
UPDATE cost_unit_dict
SET manage_unit_group = CASE
    WHEN manage_unit_name = '院部' THEN 'HEAD_OFFICE'
    WHEN manage_unit_name IN ('八部', '509所') THEN 'OVERALL'
    WHEN manage_unit_name IN ('800所', '149厂', '812所') THEN 'ASSEMBLY'
    WHEN manage_unit_name IN ('电子所', '动力所', '811所', '802所', '803所') THEN 'PROFESSIONAL'
    WHEN manage_unit_name = '基础所' THEN 'FOUNDATION'
    WHEN inside_institute = false THEN 'OUTER'
    ELSE manage_unit_group
END
WHERE deleted = 0;

-- 清理旧版本可能存在的约束/索引名称，再建立当前业务唯一键。
ALTER TABLE cost_unit_cost_detail DROP CONSTRAINT IF EXISTS uk_cost_unit_cost_detail_unit_stage;
ALTER TABLE cost_unit_cost_detail DROP CONSTRAINT IF EXISTS uk_cost_unit_cost_project_unit;
ALTER TABLE cost_work_order DROP CONSTRAINT IF EXISTS uk_cost_work_order_no;
ALTER TABLE cost_work_order DROP CONSTRAINT IF EXISTS uk_cost_work_order_business;
ALTER TABLE cost_work_order_ledger_detail DROP CONSTRAINT IF EXISTS uk_cost_work_order_ledger_detail_source;
ALTER TABLE cost_work_order_ledger_detail DROP CONSTRAINT IF EXISTS uk_cost_ledger_source_detail;
DROP INDEX IF EXISTS uk_cost_unit_cost_detail_unit_stage;
DROP INDEX IF EXISTS uk_cost_unit_cost_project_unit;
DROP INDEX IF EXISTS uk_cost_work_order_no;
DROP INDEX IF EXISTS uk_cost_work_order_ledger_detail_source;
DROP INDEX IF EXISTS uk_cost_ledger_source_detail;
DROP INDEX IF EXISTS uk_cost_work_order_business;

DO $$
DECLARE
    v_is_dws bool;
BEGIN
    v_is_dws := position('gaussdb' in lower(version())) > 0
                OR position('dws' in lower(version())) > 0;
    IF v_is_dws THEN
        -- DWS 分布表的唯一索引必须包含分布键。保留同名普通索引加速匹配，
        -- 业务唯一性由升级/同步脚本的重复键强校验和串行同步锁保证。
        EXECUTE 'CREATE INDEX uk_cost_unit_cost_project_unit ON cost_unit_cost_detail (tenant_id, project_code, unit_name)';
        EXECUTE 'CREATE INDEX uk_cost_work_order_business ON cost_work_order (tenant_id, project_code, unit_name, work_order_no)';
        EXECUTE 'CREATE INDEX uk_cost_ledger_source_detail ON cost_work_order_ledger_detail (tenant_id, source_detail_id)';
    ELSE
        EXECUTE 'CREATE UNIQUE INDEX uk_cost_unit_cost_project_unit ON cost_unit_cost_detail (tenant_id, project_code, unit_name)';
        EXECUTE 'CREATE UNIQUE INDEX uk_cost_work_order_business ON cost_work_order (tenant_id, project_code, unit_name, work_order_no)';
        EXECUTE 'CREATE UNIQUE INDEX uk_cost_ledger_source_detail ON cost_work_order_ledger_detail (tenant_id, source_detail_id)';
    END IF;
END $$;

DROP INDEX IF EXISTS idx_cost_unit_dict_manage_group;
DROP INDEX IF EXISTS idx_cost_work_order_source;
CREATE INDEX idx_cost_unit_dict_manage_group
    ON cost_unit_dict (tenant_id, manage_unit_group, deleted);
CREATE INDEX idx_cost_work_order_source
    ON cost_work_order (source_work_order_id);

COMMENT ON COLUMN cost_work_order.fiscal_year IS '废弃兼容字段，逻辑工作令固定为空；会计年度保留在账面明细表';
COMMENT ON COLUMN cost_work_order.income_amount IS '工作令到款金额，单位万元，仅工作令层展示';
COMMENT ON COLUMN cost_work_order.book_cost_amount IS '工作令跨年度借方账面快照，单位万元，可由账面明细重建';
COMMENT ON TABLE cost_unit_cost_detail IS '预分预控项目单位累计金额表';

UPDATE cost_schema_migration
SET description = 'PostgreSQL 9.2 / GaussDB(DWS)：统一金额来源、管理单位分组和逻辑工作令',
    installed_on = CURRENT_TIMESTAMP,
    installed_by = CURRENT_USER
WHERE version = '20260722';

INSERT INTO cost_schema_migration(version, description, installed_on, installed_by)
SELECT '20260722', 'PostgreSQL 9.2 / GaussDB(DWS)：统一金额来源、管理单位分组和逻辑工作令',
       CURRENT_TIMESTAMP, CURRENT_USER
WHERE NOT EXISTS (
    SELECT 1 FROM cost_schema_migration WHERE version = '20260722'
);

$migration20260722$;
 END IF;
END $gate20260722$;

-- 11-upgrade-existing-to-20260728-project-office-form.sql: 已达到此版本则跳过，避免重跑旧数据归并。
DO $gate20260728$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM cost_schema_migration WHERE version >= '20260728') THEN
 EXECUTE $migration20260728$-- 项目办按单位填报与院部直属分类增量脚本。
-- 兼容 PostgreSQL 9.2.x 与 GaussDB(DWS) 8.2.1，可重复执行。



CREATE TABLE IF NOT EXISTS cost_schema_migration
(
    version         varchar(32)  NOT NULL,
    description     varchar(255) NOT NULL,
    installed_on    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    installed_by    varchar(128) NOT NULL DEFAULT CURRENT_USER,
    CONSTRAINT pk_cost_schema_migration PRIMARY KEY (version)
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'cost_project_basic'
          AND column_name = 'quantity'
    ) THEN
        ALTER TABLE cost_project_basic ADD COLUMN quantity int4 NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'cost_project_basic'
          AND column_name = 'product_short_name'
    ) THEN
        ALTER TABLE cost_project_basic ADD COLUMN product_short_name varchar(255) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'cost_project_basic'
          AND column_name = 'vertical_division'
    ) THEN
        ALTER TABLE cost_project_basic ADD COLUMN vertical_division bool NULL DEFAULT NULL;
    END IF;
END $$;

UPDATE cost_unit_dict
SET manage_unit_group = CASE
    WHEN manage_unit_name = '院部' THEN 'HEAD_OFFICE'
    WHEN manage_unit_name IN ('八部', '509所') THEN 'OVERALL'
    WHEN manage_unit_name IN ('800所', '149厂', '812所') THEN 'ASSEMBLY'
    WHEN manage_unit_name IN ('电子所', '动力所', '811所', '802所', '803所') THEN 'PROFESSIONAL'
    WHEN manage_unit_name = '基础所' THEN 'FOUNDATION'
    WHEN inside_institute = false THEN 'OUTER'
    ELSE manage_unit_group
END
WHERE deleted = 0;

INSERT INTO cost_schema_migration (version, description)
SELECT '20260728', 'project office form fields and head office unit group'
WHERE NOT EXISTS (
    SELECT 1 FROM cost_schema_migration WHERE version = '20260728'
);

$migration20260728$;
 END IF;
END $gate20260728$;

-- 12-upgrade-existing-to-20260817-access-scope.sql: 已达到此版本则跳过，避免重跑旧数据归并。
DO $gate20260817$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM cost_schema_migration WHERE version >= '20260817') THEN
 EXECUTE $migration20260817$-- 成本树平台三级数据权限增量脚本。
-- 兼容 PostgreSQL 9.2.x 与 GaussDB(DWS) 8.2.1，可重复执行。



CREATE TABLE IF NOT EXISTS cost_schema_migration
(
    version         varchar(32)  NOT NULL,
    description     varchar(255) NOT NULL,
    installed_on    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    installed_by    varchar(128) NOT NULL DEFAULT CURRENT_USER,
    CONSTRAINT pk_cost_schema_migration PRIMARY KEY (version)
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relkind = 'S' AND relname = 'cost_user_project_scope_seq') THEN
        EXECUTE 'CREATE SEQUENCE cost_user_project_scope_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relkind = 'S' AND relname = 'cost_user_unit_scope_seq') THEN
        EXECUTE 'CREATE SEQUENCE cost_user_unit_scope_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1';
    END IF;
END $$;

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

DO $$
DECLARE
    v_is_dws bool;
BEGIN
    v_is_dws := position('gaussdb' in lower(version())) > 0
                OR position('dws' in lower(version())) > 0;
    IF EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = current_schema() AND indexname = 'uk_cost_user_project_scope'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = current_schema()
          AND tablename = 'cost_user_project_scope'
          AND indexname = 'uk_cost_user_project_scope'
          AND (v_is_dws OR indexdef LIKE 'CREATE UNIQUE INDEX%')
          AND indexdef LIKE '%(tenant_id, user_id, project_code)%'
    ) THEN
        RAISE EXCEPTION '索引 uk_cost_user_project_scope 已存在但定义错误，请 DBA 核对后处理';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = current_schema() AND indexname = 'uk_cost_user_project_scope') THEN
        IF v_is_dws THEN
            EXECUTE 'CREATE INDEX uk_cost_user_project_scope ON cost_user_project_scope (tenant_id, user_id, project_code)';
        ELSE
            EXECUTE 'CREATE UNIQUE INDEX uk_cost_user_project_scope ON cost_user_project_scope (tenant_id, user_id, project_code)';
        END IF;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = current_schema() AND indexname = 'idx_cost_user_project_scope_user') THEN
        EXECUTE 'CREATE INDEX idx_cost_user_project_scope_user ON cost_user_project_scope (tenant_id, user_id, deleted)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = current_schema() AND indexname = 'idx_cost_user_project_scope_project') THEN
        EXECUTE 'CREATE INDEX idx_cost_user_project_scope_project ON cost_user_project_scope (tenant_id, project_code, deleted)';
    END IF;
    IF EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = current_schema() AND indexname = 'uk_cost_user_unit_scope'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = current_schema()
          AND tablename = 'cost_user_unit_scope'
          AND indexname = 'uk_cost_user_unit_scope'
          AND (v_is_dws OR indexdef LIKE 'CREATE UNIQUE INDEX%')
          AND indexdef LIKE '%(tenant_id, user_id, manage_unit_code)%'
    ) THEN
        RAISE EXCEPTION '索引 uk_cost_user_unit_scope 已存在但定义错误，请 DBA 核对后处理';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = current_schema() AND indexname = 'uk_cost_user_unit_scope') THEN
        IF v_is_dws THEN
            EXECUTE 'CREATE INDEX uk_cost_user_unit_scope ON cost_user_unit_scope (tenant_id, user_id, manage_unit_code)';
        ELSE
            EXECUTE 'CREATE UNIQUE INDEX uk_cost_user_unit_scope ON cost_user_unit_scope (tenant_id, user_id, manage_unit_code)';
        END IF;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = current_schema() AND indexname = 'idx_cost_user_unit_scope_user') THEN
        EXECUTE 'CREATE INDEX idx_cost_user_unit_scope_user ON cost_user_unit_scope (tenant_id, user_id, deleted)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = current_schema() AND indexname = 'idx_cost_user_unit_scope_unit') THEN
        EXECUTE 'CREATE INDEX idx_cost_user_unit_scope_unit ON cost_user_unit_scope (tenant_id, manage_unit_code, deleted)';
    END IF;
END $$;

COMMENT ON TABLE cost_user_project_scope IS '成本库用户项目数据授权表';
COMMENT ON TABLE cost_user_unit_scope IS '成本库用户管理单位数据授权表';

UPDATE cost_schema_migration
SET description = '成本树平台三级数据权限',
    installed_on = CURRENT_TIMESTAMP,
    installed_by = CURRENT_USER
WHERE version = '20260817';

INSERT INTO cost_schema_migration(version, description, installed_on, installed_by)
SELECT '20260817', '成本树平台三级数据权限', CURRENT_TIMESTAMP, CURRENT_USER
WHERE NOT EXISTS (
    SELECT 1 FROM cost_schema_migration WHERE version = '20260817'
);

$migration20260817$;
 END IF;
END $gate20260817$;

-- 13-upgrade-existing-to-20260818-domain-scope.sql: 已达到此版本则跳过，避免重跑旧数据归并。
DO $gate20260818$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM cost_schema_migration WHERE version >= '20260818') THEN
 EXECUTE $migration20260818$-- 成本树科研部单领域数据权限增量脚本。
-- 兼容 PostgreSQL 9.2.x 与 GaussDB(DWS) 8.2.1，可重复执行。
-- 每个账号只允许一个领域；后端更新授权时必须物理删除旧记录后再插入新记录。



CREATE TABLE IF NOT EXISTS cost_schema_migration
(
    version         varchar(32)  NOT NULL,
    description     varchar(255) NOT NULL,
    installed_on    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    installed_by    varchar(128) NOT NULL DEFAULT CURRENT_USER,
    CONSTRAINT pk_cost_schema_migration PRIMARY KEY (version)
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relkind = 'S' AND relname = 'cost_user_domain_scope_seq') THEN
        EXECUTE 'CREATE SEQUENCE cost_user_domain_scope_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1';
    END IF;
END $$;

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

DO $$
DECLARE
    v_is_dws bool;
BEGIN
    v_is_dws := position('gaussdb' in lower(version())) > 0
                OR position('dws' in lower(version())) > 0;
    IF EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = current_schema() AND indexname = 'uk_cost_user_domain_scope_user'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = current_schema()
          AND tablename = 'cost_user_domain_scope'
          AND indexname = 'uk_cost_user_domain_scope_user'
          AND (v_is_dws OR indexdef LIKE 'CREATE UNIQUE INDEX%')
          AND indexdef LIKE '%(tenant_id, user_id)%'
    ) THEN
        RAISE EXCEPTION '索引 uk_cost_user_domain_scope_user 已存在但定义错误，请 DBA 核对后处理';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = current_schema() AND indexname = 'uk_cost_user_domain_scope_user'
    ) THEN
        IF v_is_dws THEN
            EXECUTE 'CREATE INDEX uk_cost_user_domain_scope_user ON cost_user_domain_scope (tenant_id, user_id)';
        ELSE
            EXECUTE 'CREATE UNIQUE INDEX uk_cost_user_domain_scope_user ON cost_user_domain_scope (tenant_id, user_id)';
        END IF;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = current_schema() AND indexname = 'idx_cost_user_domain_scope_domain'
    ) THEN
        EXECUTE 'CREATE INDEX idx_cost_user_domain_scope_domain ON cost_user_domain_scope (tenant_id, domain_code)';
    END IF;
END $$;

COMMENT ON TABLE cost_user_domain_scope IS '成本库科研部用户领域数据授权表；每账号一个领域，授权更新使用物理替换';

UPDATE cost_schema_migration
SET description = '科研部单领域数据权限',
    installed_on = CURRENT_TIMESTAMP,
    installed_by = CURRENT_USER
WHERE version = '20260818';

INSERT INTO cost_schema_migration(version, description, installed_on, installed_by)
SELECT '20260818', '科研部单领域数据权限', CURRENT_TIMESTAMP, CURRENT_USER
WHERE NOT EXISTS (
    SELECT 1 FROM cost_schema_migration WHERE version = '20260818'
);

$migration20260818$;
 END IF;
END $gate20260818$;

-- 14-upgrade-existing-to-20260819-manual-fields-subsystem.sql: 已达到此版本则跳过，避免重跑旧数据归并。
DO $gate20260819$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM cost_schema_migration WHERE version >= '20260819') THEN
 EXECUTE $migration20260819$-- 20260819 项目办填报字段、阶段多选、成本分系统字典和纵向分工空值语义升级。
-- 兼容 PostgreSQL 9.2.x 与 GaussDB(DWS) 8.2.1，可重复执行。
-- 不批量修改历史 vertical_division=false；脚本末尾只输出审计清单。



DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'product_attachment_type') THEN
        ALTER TABLE cost_project_basic ADD COLUMN product_attachment_type varchar(32) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'user_name') THEN
        ALTER TABLE cost_project_basic ADD COLUMN user_name varchar(255) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'acquire_method') THEN
        ALTER TABLE cost_project_basic ADD COLUMN acquire_method varchar(128) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'batch_category') THEN
        ALTER TABLE cost_project_basic ADD COLUMN batch_category varchar(128) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'platform_series') THEN
        ALTER TABLE cost_project_basic ADD COLUMN platform_series varchar(128) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'target_price') THEN
        ALTER TABLE cost_project_basic ADD COLUMN target_price numeric(18,2) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'competitor_unit_1') THEN
        ALTER TABLE cost_project_basic ADD COLUMN competitor_unit_1 varchar(255) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'competitor_price_1') THEN
        ALTER TABLE cost_project_basic ADD COLUMN competitor_price_1 numeric(18,2) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'competitor_unit_2') THEN
        ALTER TABLE cost_project_basic ADD COLUMN competitor_unit_2 varchar(255) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'competitor_price_2') THEN
        ALTER TABLE cost_project_basic ADD COLUMN competitor_price_2 numeric(18,2) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'tax_exempt') THEN
        ALTER TABLE cost_project_basic ADD COLUMN tax_exempt varchar(16) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'cycle_start') THEN
        ALTER TABLE cost_project_basic ADD COLUMN cycle_start varchar(16) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'cycle_end') THEN
        ALTER TABLE cost_project_basic ADD COLUMN cycle_end varchar(16) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relkind = 'S' AND relname = 'cost_subsystem_dict_seq') THEN
        EXECUTE 'CREATE SEQUENCE cost_subsystem_dict_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1';
    END IF;
END $$;

ALTER TABLE cost_project_basic ALTER COLUMN stage_code TYPE varchar(255);
ALTER TABLE cost_work_order ALTER COLUMN vertical_division DROP DEFAULT;

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

DO $$
DECLARE
    v_is_dws bool;
BEGIN
    v_is_dws := position('gaussdb' in lower(version())) > 0 OR position('dws' in lower(version())) > 0;
    IF EXISTS (
        SELECT 1 FROM pg_indexes WHERE schemaname = current_schema() AND indexname = 'uk_cost_subsystem_dict_name'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = current_schema()
          AND tablename = 'cost_subsystem_dict'
          AND indexname = 'uk_cost_subsystem_dict_name'
          AND (v_is_dws OR indexdef LIKE 'CREATE UNIQUE INDEX%')
          AND indexdef LIKE '%(tenant_id, subsystem_name)%'
    ) THEN
        RAISE EXCEPTION '索引 uk_cost_subsystem_dict_name 已存在但定义错误，请 DBA 核对后处理';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = current_schema() AND indexname = 'uk_cost_subsystem_dict_name') THEN
        IF v_is_dws THEN
            EXECUTE 'CREATE INDEX uk_cost_subsystem_dict_name ON cost_subsystem_dict (tenant_id, subsystem_name)';
        ELSE
            EXECUTE 'CREATE UNIQUE INDEX uk_cost_subsystem_dict_name ON cost_subsystem_dict (tenant_id, subsystem_name)';
        END IF;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = current_schema() AND indexname = 'idx_cost_subsystem_dict_status') THEN
        EXECUTE 'CREATE INDEX idx_cost_subsystem_dict_status ON cost_subsystem_dict (tenant_id, status, sort_no, deleted)';
    END IF;
END $$;

INSERT INTO cost_subsystem_dict
    (subsystem_name, sort_no, status, creator, create_time, updater, update_time, deleted, tenant_id)
SELECT source.subsystem_name,
       row_number() OVER (PARTITION BY source.tenant_id ORDER BY source.subsystem_name) * 10,
       'ENABLE', 'upgrade-20260819', CURRENT_TIMESTAMP, 'upgrade-20260819', CURRENT_TIMESTAMP, 0,
       source.tenant_id
FROM (
    SELECT DISTINCT tenant_id, btrim(regexp_split_to_table(subsystem_name, ',')) AS subsystem_name
    FROM cost_project_basic
    WHERE deleted = 0 AND subsystem_name IS NOT NULL AND btrim(subsystem_name) <> ''
    UNION
    SELECT DISTINCT tenant_id, btrim(regexp_split_to_table(subsystem_name, ',')) AS subsystem_name
    FROM cost_work_order
    WHERE deleted = 0 AND subsystem_name IS NOT NULL AND btrim(subsystem_name) <> ''
) source
WHERE source.subsystem_name <> ''
  AND NOT EXISTS (
      SELECT 1 FROM cost_subsystem_dict target
      WHERE target.tenant_id = source.tenant_id
        AND target.subsystem_name = source.subsystem_name
  );

UPDATE cost_schema_migration
SET description = '项目办填报字段、阶段多选和成本分系统字典',
    installed_on = CURRENT_TIMESTAMP,
    installed_by = CURRENT_USER
WHERE version = '20260819';

INSERT INTO cost_schema_migration(version, description, installed_on, installed_by)
SELECT '20260819', '项目办填报字段、阶段多选和成本分系统字典', CURRENT_TIMESTAMP, CURRENT_USER
WHERE NOT EXISTS (SELECT 1 FROM cost_schema_migration WHERE version = '20260819');


SELECT tenant_id, project_code, unit_name, work_order_no, work_order_name,
       vertical_division, status, updater, update_time
FROM cost_work_order
WHERE deleted = 0 AND vertical_division = false
ORDER BY tenant_id, project_code, unit_name, work_order_no;
$migration20260819$;
 END IF;
END $gate20260819$;

-- 15-upgrade-existing-to-20260820-warning-workflow.sql: 已达到此版本则跳过，避免重跑旧数据归并。
DO $gate20260820$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM cost_schema_migration WHERE version >= '20260820') THEN
 EXECUTE $migration20260820$-- 20260820 预警分析与闭环处置升级。
-- 兼容 PostgreSQL 9.2.x 与 GaussDB(DWS) 8.2.1，可重复执行。
-- Direct anonymous block: no session-local function and no cross-node pg_temp lookup.
DO $warning_columns$
DECLARE column_spec record; target_schema text := current_schema();
BEGIN
 IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema=target_schema AND table_name='cost_warning_record') THEN
  RAISE EXCEPTION 'Missing %.cost_warning_record; run the create-missing-tables script first', target_schema;
 END IF;
 FOR column_spec IN SELECT * FROM (VALUES
  ('project_code','varchar(100)'),
  ('project_name','varchar(255)'),
  ('domain_code','varchar(100)'),
  ('domain_name','varchar(255)'),
  ('model_code','varchar(100)'),
  ('model_name','varchar(255)'),
  ('cycle_no','int4'),
  ('workflow_status','varchar(32)'),
  ('active_marker','int2'),
  ('initiator_user_id','int8'),
  ('initiator_user_name','varchar(128)'),
  ('initiated_time','timestamp'),
  ('disposition_user_id','int8'),
  ('disposition_user_name','varchar(128)'),
  ('cause_analysis','varchar(1000)'),
  ('disposal_measure','varchar(1000)'),
  ('expected_completion_date','date'),
  ('disposition_time','timestamp'),
  ('close_user_id','int8'),
  ('close_user_name','varchar(128)'),
  ('close_time','timestamp'),
  ('return_reason','varchar(500)')
 ) AS columns_to_add(column_name, definition) LOOP
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=target_schema AND table_name='cost_warning_record' AND column_name=column_spec.column_name) THEN
   EXECUTE 'ALTER TABLE ' || quote_ident(target_schema) || '.cost_warning_record ADD COLUMN ' || quote_ident(column_spec.column_name) || ' ' || column_spec.definition;
  END IF;
 END LOOP;
END $warning_columns$;

UPDATE cost_warning_record SET workflow_status='LEGACY', active_marker=NULL WHERE workflow_status IS NULL;

DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relkind='S' AND relnamespace=(SELECT oid FROM pg_namespace WHERE nspname=current_schema()) AND relname='cost_warning_receiver_seq') THEN
  EXECUTE 'CREATE SEQUENCE cost_warning_receiver_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relkind='S' AND relnamespace=(SELECT oid FROM pg_namespace WHERE nspname=current_schema()) AND relname='cost_warning_action_log_seq') THEN
  EXECUTE 'CREATE SEQUENCE cost_warning_action_log_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1';
 END IF;
END $$;

CREATE TABLE IF NOT EXISTS cost_warning_receiver (
 id int8 NOT NULL DEFAULT nextval('cost_warning_receiver_seq'), warning_record_id int8 NOT NULL,
 user_id int8 NOT NULL, username varchar(64), nickname varchar(128), notify_status varchar(32) NOT NULL DEFAULT 'PENDING',
 message_id int8, notified_time timestamp, failure_reason varchar(500), creator varchar(64) DEFAULT '',
 create_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, updater varchar(64) DEFAULT '',
 update_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, deleted int2 NOT NULL DEFAULT 0,
 tenant_id int8 NOT NULL DEFAULT 0, CONSTRAINT pk_cost_warning_receiver PRIMARY KEY(id));
CREATE TABLE IF NOT EXISTS cost_warning_action_log (
 id int8 NOT NULL DEFAULT nextval('cost_warning_action_log_seq'), warning_record_id int8 NOT NULL,
 action_type varchar(32) NOT NULL, operator_user_id int8 NOT NULL, operator_user_name varchar(128),
 operator_role_code varchar(100), from_status varchar(32), to_status varchar(32), action_content varchar(1000),
 creator varchar(64) DEFAULT '', create_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updater varchar(64) DEFAULT '', update_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
 deleted int2 NOT NULL DEFAULT 0, tenant_id int8 NOT NULL DEFAULT 0,
 CONSTRAINT pk_cost_warning_action_log PRIMARY KEY(id));

DO $$
DECLARE v_is_dws bool;
BEGIN
 v_is_dws := position('gaussdb' in lower(version())) > 0 OR position('dws' in lower(version())) > 0;
 IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='uk_cost_warning_receiver_user') THEN
  EXECUTE 'CREATE ' || CASE WHEN v_is_dws THEN '' ELSE 'UNIQUE ' END ||
          'INDEX uk_cost_warning_receiver_user ON cost_warning_receiver(tenant_id, warning_record_id, user_id)';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_warning_receiver_task') THEN
  EXECUTE 'CREATE INDEX idx_cost_warning_receiver_task ON cost_warning_receiver(tenant_id, warning_record_id, notify_status)';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_warning_action_task') THEN
  EXECUTE 'CREATE INDEX idx_cost_warning_action_task ON cost_warning_action_log(tenant_id, warning_record_id, create_time)';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_warning_workflow') THEN
  EXECUTE 'CREATE INDEX idx_cost_warning_workflow ON cost_warning_record(tenant_id, workflow_status, active_marker)';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='uk_cost_warning_active') THEN
  EXECUTE 'CREATE ' || CASE WHEN v_is_dws THEN '' ELSE 'UNIQUE ' END ||
          'INDEX uk_cost_warning_active ON cost_warning_record(tenant_id, warning_source, project_id, responsible_unit_name, active_marker)';
 END IF;
END $$;

UPDATE cost_schema_migration SET description='预警分析与闭环处置', installed_on=CURRENT_TIMESTAMP,
 installed_by=CURRENT_USER WHERE version='20260820';
INSERT INTO cost_schema_migration(version, description, installed_on, installed_by)
SELECT '20260820','预警分析与闭环处置',CURRENT_TIMESTAMP,CURRENT_USER
WHERE NOT EXISTS (SELECT 1 FROM cost_schema_migration WHERE version='20260820');

-- 活动任务和接收人不得重复；DWS 由该验收弥补分布式唯一索引限制。
SELECT tenant_id, project_id, responsible_unit_name, count(*) duplicate_count
FROM cost_warning_record WHERE deleted=0 AND active_marker=1
GROUP BY tenant_id, project_id, responsible_unit_name HAVING count(*)>1;
SELECT tenant_id, warning_record_id, user_id, count(*) duplicate_count
FROM cost_warning_receiver WHERE deleted=0
GROUP BY tenant_id, warning_record_id, user_id HAVING count(*)>1;
$migration20260820$;
 END IF;
END $gate20260820$;

-- 0907 发布修补；结构版本仍为 20260820。不修改任何业务行。
DO $repair$
DECLARE v_dws boolean; v_index text;
BEGIN
  v_dws := position('gaussdb' in lower(version())) > 0 OR position('dws' in lower(version())) > 0;
  IF NOT v_dws THEN
    FOR v_index IN SELECT indexname FROM pg_indexes
      WHERE schemaname=current_schema()
        AND indexname IN ('uk_cost_warning_active','uk_cost_warning_receiver_user')
        AND indexdef NOT LIKE 'CREATE UNIQUE INDEX%'
    LOOP
      EXECUTE 'DROP INDEX ' || quote_ident(current_schema()) || '.' || quote_ident(v_index);
    END LOOP;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='uk_cost_warning_active') THEN
    EXECUTE 'CREATE ' || CASE WHEN v_dws THEN '' ELSE 'UNIQUE ' END ||
      'INDEX uk_cost_warning_active ON cost_warning_record (tenant_id,warning_source,project_id,responsible_unit_name,active_marker)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='uk_cost_warning_receiver_user') THEN
    EXECUTE 'CREATE ' || CASE WHEN v_dws THEN '' ELSE 'UNIQUE ' END ||
      'INDEX uk_cost_warning_receiver_user ON cost_warning_receiver (tenant_id,warning_record_id,user_id)';
  END IF;
END $repair$;

-- Cost PG9.2/DWS only. Keep user assignments and revocation tombstones permanently.
-- Run after the existing schema upgrade. Uses the caller's validated search_path.
DO $$
DECLARE
    distribution text := '';
BEGIN
    IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN
        distribution := ' WITH (orientation=row) DISTRIBUTE BY HASH (tenant_id)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                   WHERE n.nspname=current_schema() AND c.relname='cost_user_role_seq') THEN
        EXECUTE 'CREATE SEQUENCE cost_user_role_seq';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                   WHERE n.nspname=current_schema() AND c.relname='cost_user_role_action_seq') THEN
        EXECUTE 'CREATE SEQUENCE cost_user_role_action_seq';
    END IF;
    EXECUTE 'CREATE TABLE IF NOT EXISTS cost_user_role (
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
    )' || distribution;
    EXECUTE 'CREATE TABLE IF NOT EXISTS cost_user_role_action (
        id bigint NOT NULL DEFAULT nextval(''cost_user_role_action_seq''),
        tenant_id bigint NOT NULL, user_id bigint NOT NULL, actor_id bigint NOT NULL,
        old_role_code varchar(255), new_role_code varchar(64), revision bigint NOT NULL,
        create_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT pk_cost_user_role_action PRIMARY KEY (tenant_id,id)
    )' || distribution;
    -- Serialize role/range edits even before a legacy account has a local override.
    EXECUTE 'CREATE TABLE IF NOT EXISTS cost_auth_user_lock (
        tenant_id bigint NOT NULL, user_id bigint NOT NULL, revision bigint NOT NULL DEFAULT 0,
        CONSTRAINT pk_cost_auth_user_lock PRIMARY KEY (tenant_id,user_id)
    )' || distribution;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid
                   JOIN pg_namespace n ON n.oid=t.relnamespace
                   WHERE n.nspname=current_schema() AND t.relname='cost_user_role'
                   AND c.conname='uk_cost_user_role_user' AND c.contype='u') THEN
        RAISE EXCEPTION 'cost_user_role requires tenant/user unique constraint. Stop; do not disable it.';
    END IF;
END $$;
COMMENT ON TABLE cost_user_role IS '成本本地角色覆盖；无记录沿用中台，role_code为空表示显式撤销，禁止同步清理';
COMMENT ON TABLE cost_user_role_action IS '成本角色分配追加式审计，不参与外部源同步或业务清库';

-- Role changes and scope replacement share this monotonically increasing revision.
DO $auth_revision$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema()
                AND table_name='cost_auth_user_lock' AND column_name='revision') THEN
  EXECUTE 'ALTER TABLE ' || quote_ident(current_schema()) || '.cost_auth_user_lock ADD COLUMN revision bigint NOT NULL DEFAULT 0';
 END IF;
END $auth_revision$;
COMMENT ON COLUMN cost_auth_user_lock.revision IS '授权快照版本；角色或范围每次成功保存递增，拒绝陈旧页面覆盖';


-- Repair absent indexes after historical data upgrades.
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_model_node_parent') THEN EXECUTE 'CREATE INDEX idx_cost_model_node_parent ON cost_model_node (parent_id)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_model_node_code') THEN EXECUTE 'CREATE INDEX idx_cost_model_node_code ON cost_model_node (node_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_model_node_domain') THEN EXECUTE 'CREATE INDEX idx_cost_model_node_domain ON cost_model_node (domain_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_model_node_tenant_deleted') THEN EXECUTE 'CREATE INDEX idx_cost_model_node_tenant_deleted ON cost_model_node (tenant_id, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_project_code') THEN EXECUTE 'CREATE INDEX idx_cost_project_code ON cost_project (project_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_project_model_node') THEN EXECUTE 'CREATE INDEX idx_cost_project_model_node ON cost_project (model_node_id)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_project_unit') THEN EXECUTE 'CREATE INDEX idx_cost_project_unit ON cost_project (unit_name)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_project_stage') THEN EXECUTE 'CREATE INDEX idx_cost_project_stage ON cost_project (stage_codes)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_project_tenant_deleted') THEN EXECUTE 'CREATE INDEX idx_cost_project_tenant_deleted ON cost_project (tenant_id, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_project_basic_project') THEN EXECUTE 'CREATE INDEX idx_cost_project_basic_project ON cost_project_basic (project_id)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_project_basic_code') THEN EXECUTE 'CREATE INDEX idx_cost_project_basic_code ON cost_project_basic (project_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_project_basic_unit') THEN EXECUTE 'CREATE INDEX idx_cost_project_basic_unit ON cost_project_basic (research_unit_name)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_project_basic_stage') THEN EXECUTE 'CREATE INDEX idx_cost_project_basic_stage ON cost_project_basic (stage_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_project_basic_tenant_deleted') THEN EXECUTE 'CREATE INDEX idx_cost_project_basic_tenant_deleted ON cost_project_basic (tenant_id, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_work_order_project') THEN EXECUTE 'CREATE INDEX idx_cost_work_order_project ON cost_work_order (project_id)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_work_order_project_code') THEN EXECUTE 'CREATE INDEX idx_cost_work_order_project_code ON cost_work_order (project_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_work_order_no') THEN EXECUTE 'CREATE INDEX idx_cost_work_order_no ON cost_work_order (work_order_no)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_work_order_source') THEN EXECUTE 'CREATE INDEX idx_cost_work_order_source ON cost_work_order (source_work_order_id)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_work_order_unit') THEN EXECUTE 'CREATE INDEX idx_cost_work_order_unit ON cost_work_order (unit_name)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_work_order_stage') THEN EXECUTE 'CREATE INDEX idx_cost_work_order_stage ON cost_work_order (max_stage_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_work_order_tenant_deleted') THEN EXECUTE 'CREATE INDEX idx_cost_work_order_tenant_deleted ON cost_work_order (tenant_id, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='uk_cost_work_order_business') THEN EXECUTE 'CREATE ' || CASE WHEN lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN '' ELSE 'UNIQUE ' END || 'INDEX uk_cost_work_order_business ON cost_work_order (tenant_id, project_code, unit_name, work_order_no)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_ledger_project_code') THEN EXECUTE 'CREATE INDEX idx_cost_ledger_project_code ON cost_work_order_ledger_detail (project_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_ledger_work_order_no') THEN EXECUTE 'CREATE INDEX idx_cost_ledger_work_order_no ON cost_work_order_ledger_detail (work_order_no)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_ledger_source_work_order') THEN EXECUTE 'CREATE INDEX idx_cost_ledger_source_work_order ON cost_work_order_ledger_detail (source_work_order_id)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_ledger_accounting_unit') THEN EXECUTE 'CREATE INDEX idx_cost_ledger_accounting_unit ON cost_work_order_ledger_detail (accounting_unit_name)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_ledger_stage') THEN EXECUTE 'CREATE INDEX idx_cost_ledger_stage ON cost_work_order_ledger_detail (resolved_stage_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_ledger_subject') THEN EXECUTE 'CREATE INDEX idx_cost_ledger_subject ON cost_work_order_ledger_detail (second_subject_code, subject_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_ledger_tenant_deleted') THEN EXECUTE 'CREATE INDEX idx_cost_ledger_tenant_deleted ON cost_work_order_ledger_detail (tenant_id, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='uk_cost_ledger_source_detail') THEN EXECUTE 'CREATE ' || CASE WHEN lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN '' ELSE 'UNIQUE ' END || 'INDEX uk_cost_ledger_source_detail ON cost_work_order_ledger_detail (tenant_id, source_detail_id)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_unit_dict_accounting_code') THEN EXECUTE 'CREATE INDEX idx_cost_unit_dict_accounting_code ON cost_unit_dict (accounting_unit_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_unit_dict_accounting_name') THEN EXECUTE 'CREATE INDEX idx_cost_unit_dict_accounting_name ON cost_unit_dict (accounting_unit_name)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_unit_dict_manage') THEN EXECUTE 'CREATE INDEX idx_cost_unit_dict_manage ON cost_unit_dict (manage_unit_code, manage_unit_name)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_unit_dict_manage_group') THEN EXECUTE 'CREATE INDEX idx_cost_unit_dict_manage_group ON cost_unit_dict (tenant_id, manage_unit_group, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_unit_dict_tenant_deleted') THEN EXECUTE 'CREATE INDEX idx_cost_unit_dict_tenant_deleted ON cost_unit_dict (tenant_id, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='uk_cost_subsystem_dict_name') THEN EXECUTE 'CREATE ' || CASE WHEN lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN '' ELSE 'UNIQUE ' END || 'INDEX uk_cost_subsystem_dict_name ON cost_subsystem_dict (tenant_id, subsystem_name)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_subsystem_dict_status') THEN EXECUTE 'CREATE INDEX idx_cost_subsystem_dict_status
    ON cost_subsystem_dict (tenant_id, status, sort_no, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_unit_cost_project') THEN EXECUTE 'CREATE INDEX idx_cost_unit_cost_project ON cost_unit_cost_detail (project_id)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_unit_cost_project_code') THEN EXECUTE 'CREATE INDEX idx_cost_unit_cost_project_code ON cost_unit_cost_detail (project_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_unit_cost_unit') THEN EXECUTE 'CREATE INDEX idx_cost_unit_cost_unit ON cost_unit_cost_detail (unit_name)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_unit_cost_stage') THEN EXECUTE 'CREATE INDEX idx_cost_unit_cost_stage ON cost_unit_cost_detail (stage_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_unit_cost_tenant_deleted') THEN EXECUTE 'CREATE INDEX idx_cost_unit_cost_tenant_deleted ON cost_unit_cost_detail (tenant_id, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='uk_cost_unit_cost_project_unit') THEN EXECUTE 'CREATE ' || CASE WHEN lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN '' ELSE 'UNIQUE ' END || 'INDEX uk_cost_unit_cost_project_unit ON cost_unit_cost_detail (tenant_id, project_code, unit_name)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_user_project_scope_user') THEN EXECUTE 'CREATE INDEX idx_cost_user_project_scope_user
    ON cost_user_project_scope (tenant_id, user_id, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_user_project_scope_project') THEN EXECUTE 'CREATE INDEX idx_cost_user_project_scope_project
    ON cost_user_project_scope (tenant_id, project_code, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_user_unit_scope_user') THEN EXECUTE 'CREATE INDEX idx_cost_user_unit_scope_user
    ON cost_user_unit_scope (tenant_id, user_id, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_user_unit_scope_unit') THEN EXECUTE 'CREATE INDEX idx_cost_user_unit_scope_unit
    ON cost_user_unit_scope (tenant_id, manage_unit_code, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_user_domain_scope_domain') THEN EXECUTE 'CREATE INDEX idx_cost_user_domain_scope_domain
    ON cost_user_domain_scope (tenant_id, domain_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='uk_cost_user_project_scope') THEN EXECUTE 'CREATE ' || CASE WHEN lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN '' ELSE 'UNIQUE ' END || 'INDEX uk_cost_user_project_scope ON cost_user_project_scope (tenant_id, user_id, project_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='uk_cost_user_unit_scope') THEN EXECUTE 'CREATE ' || CASE WHEN lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN '' ELSE 'UNIQUE ' END || 'INDEX uk_cost_user_unit_scope ON cost_user_unit_scope (tenant_id, user_id, manage_unit_code)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='uk_cost_user_domain_scope_user') THEN EXECUTE 'CREATE ' || CASE WHEN lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN '' ELSE 'UNIQUE ' END || 'INDEX uk_cost_user_domain_scope_user ON cost_user_domain_scope (tenant_id, user_id)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_import_batch_type') THEN EXECUTE 'CREATE INDEX idx_cost_import_batch_type ON cost_import_batch (import_type)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_import_batch_status') THEN EXECUTE 'CREATE INDEX idx_cost_import_batch_status ON cost_import_batch (status)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_import_batch_tenant_deleted') THEN EXECUTE 'CREATE INDEX idx_cost_import_batch_tenant_deleted ON cost_import_batch (tenant_id, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_import_error_batch') THEN EXECUTE 'CREATE INDEX idx_cost_import_error_batch ON cost_import_error (batch_id)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_import_error_tenant_deleted') THEN EXECUTE 'CREATE INDEX idx_cost_import_error_tenant_deleted ON cost_import_error (tenant_id, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_warning_project') THEN EXECUTE 'CREATE INDEX idx_cost_warning_project ON cost_warning_record (project_id)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_warning_work_order') THEN EXECUTE 'CREATE INDEX idx_cost_warning_work_order ON cost_warning_record (work_order_id)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_warning_source') THEN EXECUTE 'CREATE INDEX idx_cost_warning_source ON cost_warning_record (warning_source, warning_level)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_warning_status') THEN EXECUTE 'CREATE INDEX idx_cost_warning_status ON cost_warning_record (status)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_warning_tenant_deleted') THEN EXECUTE 'CREATE INDEX idx_cost_warning_tenant_deleted ON cost_warning_record (tenant_id, deleted)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_warning_workflow') THEN EXECUTE 'CREATE INDEX idx_cost_warning_workflow ON cost_warning_record (tenant_id, workflow_status, active_marker)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='uk_cost_warning_active') THEN EXECUTE 'CREATE ' || CASE WHEN lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN '' ELSE 'UNIQUE ' END || 'INDEX uk_cost_warning_active ON cost_warning_record (tenant_id, warning_source, project_id, responsible_unit_name, active_marker)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='uk_cost_warning_receiver_user') THEN EXECUTE 'CREATE ' || CASE WHEN lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN '' ELSE 'UNIQUE ' END || 'INDEX uk_cost_warning_receiver_user ON cost_warning_receiver (tenant_id, warning_record_id, user_id)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_warning_receiver_task') THEN EXECUTE 'CREATE INDEX idx_cost_warning_receiver_task ON cost_warning_receiver (tenant_id, warning_record_id, notify_status)'; END IF; END $index_repair$;
DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='idx_cost_warning_action_task') THEN EXECUTE 'CREATE INDEX idx_cost_warning_action_task ON cost_warning_action_log (tenant_id, warning_record_id, create_time)'; END IF; END $index_repair$;
-- 成本库 PostgreSQL 9.2 / GaussDB(DWS) 8.2.1 升级后验收脚本。
-- 目标结构版本：20260820。所有 error_count 应为 0。

SELECT current_database() AS database_name,
       current_user AS database_user,
       current_setting('server_version') AS server_version,
       CASE WHEN position('gaussdb' in lower(version())) > 0
                  OR position('dws' in lower(version())) > 0
            THEN 'GaussDB(DWS)' ELSE 'PostgreSQL 9.2' END AS database_engine,
       CURRENT_TIMESTAMP AS verified_at;

SELECT version, description, installed_on, installed_by
FROM cost_schema_migration
ORDER BY installed_on DESC, version DESC;

WITH required_column(table_name, column_name) AS (
    VALUES
        ('cost_project_basic', 'product_attachment_type'),
        ('cost_project_basic', 'tax_exempt'),
        ('cost_project_basic', 'cycle_start'),
        ('cost_project_basic', 'cycle_end'),
        ('cost_project_basic', 'quantity'),
        ('cost_project_basic', 'product_short_name'),
        ('cost_project_basic', 'vertical_division'),
        ('cost_project_basic', 'user_name'),
        ('cost_project_basic', 'acquire_method'),
        ('cost_project_basic', 'batch_category'),
        ('cost_project_basic', 'platform_series'),
        ('cost_project_basic', 'target_price'),
        ('cost_project_basic', 'competitor_unit_1'),
        ('cost_project_basic', 'competitor_price_1'),
        ('cost_project_basic', 'competitor_unit_2'),
        ('cost_project_basic', 'competitor_price_2'),
        ('cost_unit_cost_detail', 'approved_amount'),
        ('cost_unit_cost_detail', 'source_record_id'),
        ('cost_unit_cost_detail', 'source_update_time'),
        ('cost_unit_dict', 'manage_unit_group'),
        ('cost_work_order', 'source_work_order_id'),
        ('cost_work_order', 'accounting_unit_code'),
        ('cost_work_order', 'accounting_unit_name'),
        ('cost_work_order', 'fiscal_year'),
        ('cost_work_order', 'contract_amount'),
        ('cost_work_order', 'income_amount'),
        ('cost_work_order', 'disabled'),
        ('cost_work_order', 'approved_amount'),
        ('cost_warning_record', 'workflow_status'),
        ('cost_warning_record', 'active_marker'),
        ('cost_warning_record', 'cycle_no'),
        ('cost_warning_record', 'cause_analysis'),
        ('cost_warning_record', 'disposal_measure'),
        ('cost_warning_record', 'expected_completion_date')
)
SELECT r.table_name, r.column_name AS missing_required_column
FROM required_column r
LEFT JOIN information_schema.columns c
  ON c.table_schema = current_schema()
 AND c.table_name = r.table_name
 AND c.column_name = r.column_name
WHERE c.column_name IS NULL
ORDER BY r.table_name, r.column_name;

WITH required_index(index_name) AS (
    VALUES ('uk_cost_unit_cost_project_unit'),
           ('uk_cost_work_order_business'),
           ('uk_cost_ledger_source_detail'),
           ('idx_cost_unit_dict_manage_group'),
           ('idx_cost_work_order_source'),
           ('uk_cost_user_project_scope'),
           ('uk_cost_user_unit_scope'),
           ('uk_cost_user_domain_scope_user'),
           ('idx_cost_user_domain_scope_domain'),
           ('uk_cost_subsystem_dict_name'),
           ('idx_cost_subsystem_dict_status'),
           ('uk_cost_warning_active'),
           ('uk_cost_warning_receiver_user'),
           ('idx_cost_warning_receiver_task'),
           ('idx_cost_warning_action_task')
)
SELECT r.index_name AS missing_required_index
FROM required_index r
WHERE NOT EXISTS (
    SELECT 1 FROM pg_indexes i
    WHERE i.schemaname = current_schema() AND i.indexname = r.index_name
)
ORDER BY r.index_name;


DROP TABLE IF EXISTS tmp_cost_verify_results;
CREATE TEMP TABLE tmp_cost_verify_results
(
    check_name  varchar(128) NOT NULL,
    error_count bigint       NOT NULL
) ON COMMIT DELETE ROWS;

INSERT INTO tmp_cost_verify_results(check_name, error_count)
    SELECT 'schema_version_20260820',
           CASE WHEN EXISTS (
               SELECT 1 FROM cost_schema_migration WHERE version = '20260820'
           ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'subsystem_dict_table', CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = current_schema() AND table_name = 'cost_subsystem_dict'
    ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'project_basic_stage_code_length', CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema() AND table_name = 'cost_project_basic'
          AND column_name = 'stage_code' AND character_maximum_length >= 255
    ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'work_order_vertical_division_default', CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema() AND table_name = 'cost_work_order'
          AND column_name = 'vertical_division' AND column_default IS NOT NULL
    ) THEN 1::bigint ELSE 0::bigint END
    UNION ALL
    SELECT 'project_scope_table', CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = current_schema() AND table_name = 'cost_user_project_scope'
    ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'unit_scope_table', CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = current_schema() AND table_name = 'cost_user_unit_scope'
    ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'domain_scope_table', CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = current_schema() AND table_name = 'cost_user_domain_scope'
    ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'project_scope_duplicate_key', count(*)
    FROM (
        SELECT 1 FROM cost_user_project_scope
        GROUP BY tenant_id, user_id, project_code HAVING count(*) > 1
    ) duplicate_scope
    UNION ALL
    SELECT 'unit_scope_duplicate_key', count(*)
    FROM (
        SELECT 1 FROM cost_user_unit_scope
        GROUP BY tenant_id, user_id, manage_unit_code HAVING count(*) > 1
    ) duplicate_scope
    UNION ALL
    SELECT 'domain_scope_duplicate_user', count(*)
    FROM (
        SELECT 1 FROM cost_user_domain_scope
        GROUP BY tenant_id, user_id HAVING count(*) > 1
    ) duplicate_scope
    UNION ALL
    SELECT 'project_scope_business_guard_index',
           CASE WHEN EXISTS (
               SELECT 1 FROM pg_indexes i
               WHERE i.schemaname = current_schema()
                 AND i.tablename = 'cost_user_project_scope'
                 AND i.indexname = 'uk_cost_user_project_scope'
                 AND ((position('gaussdb' in lower(version())) > 0
                       OR position('dws' in lower(version())) > 0)
                      OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
                 AND i.indexdef LIKE '%(tenant_id, user_id, project_code)%'
           )
           THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'unit_scope_business_guard_index',
           CASE WHEN EXISTS (
               SELECT 1 FROM pg_indexes i
               WHERE i.schemaname = current_schema()
                 AND i.tablename = 'cost_user_unit_scope'
                 AND i.indexname = 'uk_cost_user_unit_scope'
                 AND ((position('gaussdb' in lower(version())) > 0
                       OR position('dws' in lower(version())) > 0)
                      OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
                 AND i.indexdef LIKE '%(tenant_id, user_id, manage_unit_code)%'
           )
           THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'domain_scope_business_guard_index',
           CASE WHEN EXISTS (
               SELECT 1 FROM pg_indexes i
               WHERE i.schemaname = current_schema()
                 AND i.tablename = 'cost_user_domain_scope'
                 AND i.indexname = 'uk_cost_user_domain_scope_user'
                 AND ((position('gaussdb' in lower(version())) > 0
                       OR position('dws' in lower(version())) > 0)
                      OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
                 AND i.indexdef LIKE '%(tenant_id, user_id)%'
           )
           THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'domain_scope_invalid_business_key', count(*)
    FROM cost_user_domain_scope
    WHERE user_id IS NULL
       OR domain_code IS NULL OR btrim(domain_code) = ''
    UNION ALL
    SELECT 'domain_scope_non_active_record', count(*)
    FROM cost_user_domain_scope
    WHERE deleted <> 0
    UNION ALL
    SELECT 'domain_scope_orphan_domain', count(*)
    FROM cost_user_domain_scope domain_scope
    WHERE domain_scope.deleted = 0
      AND NOT EXISTS (
          SELECT 1
          FROM cost_project project
          WHERE project.tenant_id = domain_scope.tenant_id
            AND project.domain_code = domain_scope.domain_code
            AND project.deleted = 0
      )
    UNION ALL
    SELECT 'unit_cost_business_guard_index',
           CASE WHEN EXISTS (
               SELECT 1 FROM pg_indexes i
               WHERE i.schemaname = current_schema()
                 AND i.indexname = 'uk_cost_unit_cost_project_unit'
                  AND ((position('gaussdb' in lower(version())) > 0
                        OR position('dws' in lower(version())) > 0)
                       OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
                  AND i.indexdef LIKE '%(tenant_id, project_code, unit_name)%'
           )
           THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'work_order_business_guard_index',
           CASE WHEN EXISTS (
               SELECT 1 FROM pg_indexes i
               WHERE i.schemaname = current_schema()
                 AND i.indexname = 'uk_cost_work_order_business'
                  AND ((position('gaussdb' in lower(version())) > 0
                        OR position('dws' in lower(version())) > 0)
                       OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
                 AND i.indexdef LIKE '%(tenant_id, project_code, unit_name, work_order_no)%'
           )
           THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'ledger_business_guard_index',
           CASE WHEN EXISTS (
               SELECT 1 FROM pg_indexes i
               WHERE i.schemaname = current_schema()
                 AND i.indexname = 'uk_cost_ledger_source_detail'
                  AND ((position('gaussdb' in lower(version())) > 0
                        OR position('dws' in lower(version())) > 0)
                       OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
                 AND i.indexdef LIKE '%(tenant_id, source_detail_id)%'
           )
           THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'unit_cost_invalid_business_key', count(*)
    FROM cost_unit_cost_detail
    WHERE project_code IS NULL OR btrim(project_code) = ''
       OR unit_name IS NULL OR btrim(unit_name) = ''
    UNION ALL
    SELECT 'unit_cost_duplicate_business_key', count(*)
    FROM (
        SELECT 1
        FROM cost_unit_cost_detail
        GROUP BY tenant_id, project_code, unit_name
        HAVING count(*) > 1
    ) duplicate_key
    UNION ALL
    SELECT 'unit_cost_non_all_stage', count(*)
    FROM cost_unit_cost_detail
    WHERE stage_code IS DISTINCT FROM 'ALL'
    UNION ALL
    SELECT 'work_order_invalid_business_key', count(*)
    FROM cost_work_order
    WHERE project_code IS NULL OR btrim(project_code) = ''
       OR unit_name IS NULL OR btrim(unit_name) = ''
       OR work_order_no IS NULL OR btrim(work_order_no) = ''
    UNION ALL
    SELECT 'work_order_duplicate_business_key', count(*)
    FROM (
        SELECT 1
        FROM cost_work_order
        GROUP BY tenant_id, project_code, unit_name, work_order_no
        HAVING count(*) > 1
    ) duplicate_key
    UNION ALL
    SELECT 'work_order_legacy_fiscal_year', count(*)
    FROM cost_work_order
    WHERE fiscal_year IS DISTINCT FROM ''
    UNION ALL
    SELECT 'ledger_missing_source_detail_id', count(*)
    FROM cost_work_order_ledger_detail
    WHERE source_detail_id IS NULL OR btrim(source_detail_id) = ''
    UNION ALL
    SELECT 'ledger_duplicate_source_detail_id', count(*)
    FROM (
        SELECT 1
        FROM cost_work_order_ledger_detail
        GROUP BY tenant_id, source_detail_id
        HAVING count(*) > 1
    ) duplicate_source
    UNION ALL
    SELECT 'ledger_unmatched_active_work_order', count(*)
    FROM cost_work_order_ledger_detail
    WHERE deleted = 0 AND work_order_id IS NULL
    UNION ALL
    SELECT 'ledger_orphan_work_order_id', count(*)
    FROM cost_work_order_ledger_detail detail
    LEFT JOIN cost_work_order work_order ON work_order.id = detail.work_order_id
    WHERE detail.work_order_id IS NOT NULL AND work_order.id IS NULL
    UNION ALL
    SELECT 'warning_orphan_work_order_id', count(*)
    FROM cost_warning_record warning
    LEFT JOIN cost_work_order work_order ON work_order.id = warning.work_order_id
    WHERE warning.work_order_id IS NOT NULL AND work_order.id IS NULL
    UNION ALL
    SELECT 'ledger_amount_wan_mismatch', count(*)
    FROM cost_work_order_ledger_detail
    WHERE amount IS NOT NULL
      AND amount_wan IS DISTINCT FROM round(amount / 10000.0, 2)
    UNION ALL
    SELECT 'work_order_debit_snapshot_mismatch', count(*)
    FROM (
        SELECT work_order.id,
               COALESCE(work_order.book_cost_amount, 0) AS snapshot_amount,
               COALESCE(sum(CASE
                   WHEN detail.deleted = 0
                    AND btrim(COALESCE(detail.debit_credit, '')) = '借'
                   THEN COALESCE(detail.amount / 10000.0, detail.amount_wan, 0)
                   ELSE 0
               END), 0) AS debit_amount
        FROM cost_work_order work_order
        LEFT JOIN cost_work_order_ledger_detail detail ON detail.work_order_id = work_order.id
        GROUP BY work_order.id, work_order.book_cost_amount
    ) snapshot
    WHERE abs(snapshot.snapshot_amount - snapshot.debit_amount) > 0.01
    UNION ALL
    SELECT 'unit_dict_invalid_manage_group', count(*)
    FROM cost_unit_dict
    WHERE manage_unit_group IS NOT NULL
      AND manage_unit_group NOT IN ('HEAD_OFFICE', 'OVERALL', 'ASSEMBLY', 'PROFESSIONAL', 'FOUNDATION', 'OUTER')
    UNION ALL
    SELECT 'subsystem_dict_duplicate_name', count(*)
    FROM (
        SELECT 1 FROM cost_subsystem_dict
        GROUP BY tenant_id, subsystem_name HAVING count(*) > 1
    ) duplicate_subsystem
    UNION ALL
    SELECT 'subsystem_dict_invalid_record', count(*)
    FROM cost_subsystem_dict
    WHERE subsystem_name IS NULL OR btrim(subsystem_name) = ''
       OR status NOT IN ('ENABLE', 'DISABLE') OR deleted <> 0
    UNION ALL
    SELECT 'subsystem_dict_business_guard_index',
           CASE WHEN EXISTS (
               SELECT 1 FROM pg_indexes i
               WHERE i.schemaname = current_schema()
                 AND i.tablename = 'cost_subsystem_dict'
                 AND i.indexname = 'uk_cost_subsystem_dict_name'
                 AND ((position('gaussdb' in lower(version())) > 0
                       OR position('dws' in lower(version())) > 0)
                      OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
                 AND i.indexdef LIKE '%(tenant_id, subsystem_name)%'
           ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'warning_receiver_table', CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables WHERE table_schema = current_schema() AND table_name = 'cost_warning_receiver'
    ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'warning_action_log_table', CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables WHERE table_schema = current_schema() AND table_name = 'cost_warning_action_log'
    ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'legacy_status_missing', count(*)
    FROM cost_warning_record
    WHERE workflow_status IS NULL
    UNION ALL
    SELECT 'warning_active_duplicate_key', count(*)
    FROM (
        SELECT 1 FROM cost_warning_record
        WHERE deleted = 0 AND active_marker = 1
        GROUP BY tenant_id, warning_source, project_id, responsible_unit_name, active_marker
        HAVING count(*) > 1
    ) duplicate_warning
    UNION ALL
    SELECT 'warning_receiver_duplicate_key', count(*)
    FROM (
        SELECT 1 FROM cost_warning_receiver
        WHERE deleted = 0
        GROUP BY tenant_id, warning_record_id, user_id HAVING count(*) > 1
    ) duplicate_receiver
    UNION ALL
    SELECT 'warning_active_business_guard_index', CASE WHEN EXISTS (
        SELECT 1 FROM pg_indexes i
        WHERE i.schemaname = current_schema() AND i.tablename = 'cost_warning_record'
          AND i.indexname = 'uk_cost_warning_active'
          AND ((position('gaussdb' in lower(version())) > 0 OR position('dws' in lower(version())) > 0)
               OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
          AND i.indexdef LIKE '%(tenant_id, warning_source, project_id, responsible_unit_name, active_marker)%'
    ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'warning_receiver_business_guard_index', CASE WHEN EXISTS (
        SELECT 1 FROM pg_indexes i
        WHERE i.schemaname = current_schema() AND i.tablename = 'cost_warning_receiver'
          AND i.indexname = 'uk_cost_warning_receiver_user'
          AND ((position('gaussdb' in lower(version())) > 0 OR position('dws' in lower(version())) > 0)
               OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
          AND i.indexdef LIKE '%(tenant_id, warning_record_id, user_id)%'
    ) THEN 0::bigint ELSE 1::bigint END
;

SELECT check_name, error_count,
       CASE WHEN error_count = 0 THEN 'OK' ELSE 'ERROR' END AS status
FROM tmp_cost_verify_results
ORDER BY check_name;

SELECT btrim(COALESCE(debit_credit, '')) AS debit_credit,
       count(*) AS detail_count,
       sum(COALESCE(amount / 10000.0, amount_wan, 0)) AS amount_wan
FROM cost_work_order_ledger_detail
WHERE deleted = 0
GROUP BY btrim(COALESCE(debit_credit, ''))
ORDER BY debit_credit;

SELECT sum(CASE WHEN inside_institute = true AND manage_unit_group IS NULL THEN 1 ELSE 0 END)
           AS unclassified_internal_unit_count,
       sum(CASE WHEN inside_institute = false AND manage_unit_group = 'OUTER' THEN 1 ELSE 0 END)
           AS classified_outer_unit_count
FROM cost_unit_dict
WHERE deleted = 0;

DO $$
DECLARE
    failed_checks text;
BEGIN
    SELECT string_agg(check_name || '=' || error_count, ', ' ORDER BY check_name)
      INTO failed_checks
    FROM tmp_cost_verify_results
    WHERE error_count <> 0;

    IF failed_checks IS NOT NULL THEN
        RAISE EXCEPTION '成本库升级后验收失败：%', failed_checks;
    END IF;
END $$;


DO $local_role_verify$ BEGIN
 IF (SELECT count(*) FROM information_schema.tables WHERE table_schema=current_schema()
     AND table_name IN ('cost_user_role','cost_user_role_action','cost_auth_user_lock')) <> 3 THEN
 RAISE EXCEPTION '成本本地角色结构缺失，不能部署新cost'; END IF;
 IF EXISTS(SELECT 1 FROM cost_user_role GROUP BY tenant_id,user_id HAVING count(*)>1) THEN
 RAISE EXCEPTION '成本本地角色重复，请停止'; END IF;
END $local_role_verify$;


COMMENT ON TABLE cost_model_node IS '成本库型号树节点表';
COMMENT ON TABLE cost_project IS '成本库主业项目表';
COMMENT ON TABLE cost_project_basic IS '成本库项目基本信息表';
COMMENT ON TABLE cost_work_order IS '成本库工作令表';
COMMENT ON TABLE cost_work_order_ledger_detail IS '成本库工作令账面成本明细表';
COMMENT ON TABLE cost_unit_dict IS '成本库单位字典表';
COMMENT ON TABLE cost_subsystem_dict IS '成本库分系统字典表';
COMMENT ON TABLE cost_unit_cost_detail IS '预分预控项目单位累计金额表';
COMMENT ON TABLE cost_user_project_scope IS '成本库用户项目数据授权表';
COMMENT ON TABLE cost_user_unit_scope IS '成本库用户管理单位数据授权表';
COMMENT ON TABLE cost_user_domain_scope IS '成本库科研部用户领域数据授权表；每账号一个领域，授权更新使用物理替换';
COMMENT ON TABLE cost_import_batch IS '成本库导入批次表';
COMMENT ON TABLE cost_import_error IS '成本库导入错误表';
COMMENT ON TABLE cost_warning_record IS '成本库预警记录表';
COMMENT ON TABLE cost_schema_migration IS '成本库数据库结构版本记录表';
COMMENT ON COLUMN cost_model_node.id IS '主键';
COMMENT ON COLUMN cost_model_node.parent_id IS '父节点编号';
COMMENT ON COLUMN cost_model_node.node_code IS '节点编码';
COMMENT ON COLUMN cost_model_node.node_name IS '节点名称';
COMMENT ON COLUMN cost_model_node.node_type IS '节点类型：DOMAIN/SERIES/MODEL';
COMMENT ON COLUMN cost_model_node.domain_code IS '所属领域编码';
COMMENT ON COLUMN cost_model_node.sort IS '排序';
COMMENT ON COLUMN cost_model_node.status IS '状态：ENABLE/DISABLE';
COMMENT ON COLUMN cost_model_node.remark IS '备注';
COMMENT ON COLUMN cost_model_node.creator IS '创建者';
COMMENT ON COLUMN cost_model_node.create_time IS '创建时间';
COMMENT ON COLUMN cost_model_node.updater IS '更新者';
COMMENT ON COLUMN cost_model_node.update_time IS '更新时间';
COMMENT ON COLUMN cost_model_node.deleted IS '是否删除';
COMMENT ON COLUMN cost_model_node.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_project.id IS '主键';
COMMENT ON COLUMN cost_project.project_code IS '主业项目编号';
COMMENT ON COLUMN cost_project.project_name IS '主业项目名称';
COMMENT ON COLUMN cost_project.model_node_id IS '型号树节点编号';
COMMENT ON COLUMN cost_project.domain_code IS '所属领域编码';
COMMENT ON COLUMN cost_project.domain_name IS '所属领域名称';
COMMENT ON COLUMN cost_project.category_code IS '所属类别/系列编码';
COMMENT ON COLUMN cost_project.category_name IS '所属类别/系列名称';
COMMENT ON COLUMN cost_project.model_code IS '型号/项目编码';
COMMENT ON COLUMN cost_project.model_name IS '型号/项目名称';
COMMENT ON COLUMN cost_project.batch_no IS '批次';
COMMENT ON COLUMN cost_project.stage_codes IS '阶段集合，逗号分隔';
COMMENT ON COLUMN cost_project.unit_id IS '单位编号';
COMMENT ON COLUMN cost_project.unit_name IS '单位名称';
COMMENT ON COLUMN cost_project.unit_type IS '单位属性';
COMMENT ON COLUMN cost_project.project_office_status IS '项目办填报状态：NOT_FILLED/PART_FILLED/FILLED';
COMMENT ON COLUMN cost_project.unit_fill_status IS '研制单位填报状态：NOT_FILLED/PART_FILLED/FILLED';
COMMENT ON COLUMN cost_project.audit_status IS '审批/提交状态：DRAFT/SUBMITTED/APPROVED/REJECTED';
COMMENT ON COLUMN cost_project.dept_id IS '数据权限部门编号';
COMMENT ON COLUMN cost_project.owner_user_id IS '项目负责人用户编号';
COMMENT ON COLUMN cost_project.warning_status IS '预警状态：NORMAL/OVER';
COMMENT ON COLUMN cost_project.remark IS '备注';
COMMENT ON COLUMN cost_project.creator IS '创建者';
COMMENT ON COLUMN cost_project.create_time IS '创建时间';
COMMENT ON COLUMN cost_project.updater IS '更新者';
COMMENT ON COLUMN cost_project.update_time IS '更新时间';
COMMENT ON COLUMN cost_project.deleted IS '是否删除';
COMMENT ON COLUMN cost_project.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_project_basic.id IS '主键';
COMMENT ON COLUMN cost_project_basic.project_id IS '主业项目主键';
COMMENT ON COLUMN cost_project_basic.project_code IS '主业项目编号冗余';
COMMENT ON COLUMN cost_project_basic.project_name IS '主业项目名称冗余';
COMMENT ON COLUMN cost_project_basic.product_attachment_type IS '是否产品附件、发射车等：产品/产品附件/发射车/否';
COMMENT ON COLUMN cost_project_basic.subsystem_name IS '分系统/产品配套';
COMMENT ON COLUMN cost_project_basic.quantity IS '配套数';
COMMENT ON COLUMN cost_project_basic.product_short_name IS '产品简称';
COMMENT ON COLUMN cost_project_basic.vertical_division IS '是否纵向分工';
COMMENT ON COLUMN cost_project_basic.user_name IS '用户';
COMMENT ON COLUMN cost_project_basic.acquire_method IS '项目获取方式';
COMMENT ON COLUMN cost_project_basic.batch_category IS '批次/类别';
COMMENT ON COLUMN cost_project_basic.platform_series IS '所属平台/系列';
COMMENT ON COLUMN cost_project_basic.research_unit_id IS '承研单位编号';
COMMENT ON COLUMN cost_project_basic.research_unit_name IS '承研单位名称';
COMMENT ON COLUMN cost_project_basic.target_price IS '投标/目标价格，单位万元';
COMMENT ON COLUMN cost_project_basic.competitor_unit_1 IS '对手单位1';
COMMENT ON COLUMN cost_project_basic.competitor_price_1 IS '对手竞标价格1，单位万元';
COMMENT ON COLUMN cost_project_basic.competitor_unit_2 IS '对手单位2';
COMMENT ON COLUMN cost_project_basic.competitor_price_2 IS '对手竞标价格2，单位万元';
COMMENT ON COLUMN cost_project_basic.contract_amount IS '型号项目合同金额，单位万元';
COMMENT ON COLUMN cost_project_basic.tax_exempt IS '是否免税';
COMMENT ON COLUMN cost_project_basic.target_cost_amount IS '型号项目目标成本，单位万元';
COMMENT ON COLUMN cost_project_basic.approved_amount IS '审定金额，单位万元';
COMMENT ON COLUMN cost_project_basic.cycle_start IS '研制周期起，格式YYYY-MM';
COMMENT ON COLUMN cost_project_basic.cycle_end IS '研制周期止，格式YYYY-MM';
COMMENT ON COLUMN cost_project_basic.stage_code IS '阶段编码集合，逗号分隔';
COMMENT ON COLUMN cost_project_basic.basic_info IS '基本情况';
COMMENT ON COLUMN cost_project_basic.status IS '记录状态：DRAFT/SUBMITTED/APPROVED/REJECTED';
COMMENT ON COLUMN cost_project_basic.remark IS '备注';
COMMENT ON COLUMN cost_project_basic.import_batch_id IS '导入批次编号';
COMMENT ON COLUMN cost_project_basic.dept_id IS '数据权限部门编号';
COMMENT ON COLUMN cost_project_basic.owner_user_id IS '填报负责人用户编号';
COMMENT ON COLUMN cost_project_basic.creator IS '创建者';
COMMENT ON COLUMN cost_project_basic.create_time IS '创建时间';
COMMENT ON COLUMN cost_project_basic.updater IS '更新者';
COMMENT ON COLUMN cost_project_basic.update_time IS '更新时间';
COMMENT ON COLUMN cost_project_basic.deleted IS '是否删除';
COMMENT ON COLUMN cost_project_basic.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_work_order.id IS '主键';
COMMENT ON COLUMN cost_work_order.source_work_order_id IS '源系统工作令主键';
COMMENT ON COLUMN cost_work_order.project_id IS '主业项目主键';
COMMENT ON COLUMN cost_work_order.project_code IS '主业项目编号冗余';
COMMENT ON COLUMN cost_work_order.project_name IS '主业项目名称冗余';
COMMENT ON COLUMN cost_work_order.unit_id IS '单位编号';
COMMENT ON COLUMN cost_work_order.unit_name IS '单位名称';
COMMENT ON COLUMN cost_work_order.accounting_unit_code IS '核算单位编号';
COMMENT ON COLUMN cost_work_order.accounting_unit_name IS '核算单位名称';
COMMENT ON COLUMN cost_work_order.fiscal_year IS '废弃兼容字段，逻辑工作令固定为空';
COMMENT ON COLUMN cost_work_order.work_order_no IS '工作令编号';
COMMENT ON COLUMN cost_work_order.work_order_name IS '工作令名称';
COMMENT ON COLUMN cost_work_order.product_target_cost IS '工作令目标成本，单位万元，仅工作令层展示';
COMMENT ON COLUMN cost_work_order.contract_amount IS '工作令合同金额，单位万元，仅工作令层展示';
COMMENT ON COLUMN cost_work_order.income_amount IS '工作令到款金额，单位万元，仅工作令层展示';
COMMENT ON COLUMN cost_work_order.book_cost_amount IS '工作令跨年度借方账面快照，单位万元，可由明细重建';
COMMENT ON COLUMN cost_work_order.stage_codes IS '阶段集合，逗号分隔';
COMMENT ON COLUMN cost_work_order.max_stage_code IS '最高阶段';
COMMENT ON COLUMN cost_work_order.subsystem_name IS '所属分系统';
COMMENT ON COLUMN cost_work_order.product_short_name IS '产品简称';
COMMENT ON COLUMN cost_work_order.quantity IS '配套数量';
COMMENT ON COLUMN cost_work_order.vertical_division IS '是否属于纵向分工；NULL 表示尚未填报';
COMMENT ON COLUMN cost_work_order.disabled IS '是否停用';
COMMENT ON COLUMN cost_work_order.approved_amount IS '审定金额，单位万元';
COMMENT ON COLUMN cost_work_order.status IS '记录状态：DRAFT/SUBMITTED/APPROVED/REJECTED';
COMMENT ON COLUMN cost_work_order.remark IS '备注';
COMMENT ON COLUMN cost_work_order.import_batch_id IS '导入批次编号';
COMMENT ON COLUMN cost_work_order.dept_id IS '数据权限部门编号';
COMMENT ON COLUMN cost_work_order.owner_user_id IS '填报负责人用户编号';
COMMENT ON COLUMN cost_work_order.creator IS '创建者';
COMMENT ON COLUMN cost_work_order.create_time IS '创建时间';
COMMENT ON COLUMN cost_work_order.updater IS '更新者';
COMMENT ON COLUMN cost_work_order.update_time IS '更新时间';
COMMENT ON COLUMN cost_work_order.deleted IS '是否删除';
COMMENT ON COLUMN cost_work_order.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_work_order_ledger_detail.id IS '主键';
COMMENT ON COLUMN cost_work_order_ledger_detail.source_detail_id IS '源明细内码，业务参考字段 ysnm';
COMMENT ON COLUMN cost_work_order_ledger_detail.fiscal_year IS '会计年度，业务参考字段 kjnd';
COMMENT ON COLUMN cost_work_order_ledger_detail.accounting_period IS '会计期间，业务参考字段 kjqj';
COMMENT ON COLUMN cost_work_order_ledger_detail.voucher_date IS '凭证日期，业务参考字段 pzrq';
COMMENT ON COLUMN cost_work_order_ledger_detail.voucher_no IS '凭证编号，业务参考字段 pzbh';
COMMENT ON COLUMN cost_work_order_ledger_detail.accounting_unit_id IS '单位主键，业务参考字段 dwid';
COMMENT ON COLUMN cost_work_order_ledger_detail.accounting_unit_code IS '单位编号，业务参考字段 dwbh';
COMMENT ON COLUMN cost_work_order_ledger_detail.accounting_unit_name IS '单位名称，业务参考字段 dwmc';
COMMENT ON COLUMN cost_work_order_ledger_detail.manage_unit_name IS '管理单位，业务参考字段 gldw';
COMMENT ON COLUMN cost_work_order_ledger_detail.subject_id IS '科目主键，业务参考字段 kmid';
COMMENT ON COLUMN cost_work_order_ledger_detail.subject_code IS '科目编号，业务参考字段 kmbh';
COMMENT ON COLUMN cost_work_order_ledger_detail.subject_name IS '科目名称，业务参考字段 kmmc';
COMMENT ON COLUMN cost_work_order_ledger_detail.project_code IS '项目编号，业务参考字段 xmbh';
COMMENT ON COLUMN cost_work_order_ledger_detail.source_project_id IS '项目主键，业务参考字段 xmnm';
COMMENT ON COLUMN cost_work_order_ledger_detail.project_name IS '项目名称，业务参考字段 xmmc';
COMMENT ON COLUMN cost_work_order_ledger_detail.source_work_order_id IS '工作令主键，业务参考字段 gzlnm';
COMMENT ON COLUMN cost_work_order_ledger_detail.work_order_no IS '工作令编号，业务参考字段 gzllb';
COMMENT ON COLUMN cost_work_order_ledger_detail.work_order_name IS '工作令名称，业务参考字段 gzlmc';
COMMENT ON COLUMN cost_work_order_ledger_detail.debit_credit IS '记账方向，业务参考字段 jzfx';
COMMENT ON COLUMN cost_work_order_ledger_detail.amount IS '源系统金额，单位元';
COMMENT ON COLUMN cost_work_order_ledger_detail.amount_wan IS '金额折算万元兼容字段，按 amount/10000 生成';
COMMENT ON COLUMN cost_work_order_ledger_detail.summary_text IS '辅助摘要，业务参考字段 yt';
COMMENT ON COLUMN cost_work_order_ledger_detail.source_lastmodify IS '源系统最后修改时间，业务参考字段 lastmodify';
COMMENT ON COLUMN cost_work_order_ledger_detail.second_subject_code IS '二级科目编号，业务参考字段 ejkmbh';
COMMENT ON COLUMN cost_work_order_ledger_detail.second_subject_name IS '二级科目名称，业务参考字段 ejkmmc';
COMMENT ON COLUMN cost_work_order_ledger_detail.source_timestamp IS '源时间戳，业务参考字段 dwts';
COMMENT ON COLUMN cost_work_order_ledger_detail.resolved_stage_code IS '成本库归集阶段，按工作令最高阶段解析后写入';
COMMENT ON COLUMN cost_work_order_ledger_detail.project_id IS '成本库项目主键，匹配后写入';
COMMENT ON COLUMN cost_work_order_ledger_detail.work_order_id IS '成本库工作令主键，匹配后写入';
COMMENT ON COLUMN cost_work_order_ledger_detail.remark IS '备注';
COMMENT ON COLUMN cost_work_order_ledger_detail.creator IS '创建者';
COMMENT ON COLUMN cost_work_order_ledger_detail.create_time IS '创建时间';
COMMENT ON COLUMN cost_work_order_ledger_detail.updater IS '更新者';
COMMENT ON COLUMN cost_work_order_ledger_detail.update_time IS '更新时间';
COMMENT ON COLUMN cost_work_order_ledger_detail.deleted IS '是否删除';
COMMENT ON COLUMN cost_work_order_ledger_detail.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_unit_dict.id IS '主键';
COMMENT ON COLUMN cost_unit_dict.accounting_unit_id IS '核算单位 ID';
COMMENT ON COLUMN cost_unit_dict.accounting_unit_code IS '核算单位编号';
COMMENT ON COLUMN cost_unit_dict.accounting_unit_name IS '核算单位名称';
COMMENT ON COLUMN cost_unit_dict.manage_unit_code IS '管理单位编号';
COMMENT ON COLUMN cost_unit_dict.manage_unit_name IS '管理单位名称';
COMMENT ON COLUMN cost_unit_dict.manage_unit_group IS '管理单位分类：HEAD_OFFICE/OVERALL/ASSEMBLY/PROFESSIONAL/FOUNDATION/OUTER';
COMMENT ON COLUMN cost_unit_dict.contact_unit_code IS '往来单位编号';
COMMENT ON COLUMN cost_unit_dict.contact_unit_name IS '往来单位名称';
COMMENT ON COLUMN cost_unit_dict.inside_group IS '是否集团内';
COMMENT ON COLUMN cost_unit_dict.inside_institute IS '是否院内';
COMMENT ON COLUMN cost_unit_dict.unit_id IS '中台单位编号';
COMMENT ON COLUMN cost_unit_dict.status IS '状态：ENABLE/DISABLE';
COMMENT ON COLUMN cost_unit_dict.remark IS '备注';
COMMENT ON COLUMN cost_unit_dict.creator IS '创建者';
COMMENT ON COLUMN cost_unit_dict.create_time IS '创建时间';
COMMENT ON COLUMN cost_unit_dict.updater IS '更新者';
COMMENT ON COLUMN cost_unit_dict.update_time IS '更新时间';
COMMENT ON COLUMN cost_unit_dict.deleted IS '是否删除';
COMMENT ON COLUMN cost_unit_dict.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_subsystem_dict.id IS '主键';
COMMENT ON COLUMN cost_subsystem_dict.subsystem_name IS '分系统名称';
COMMENT ON COLUMN cost_subsystem_dict.sort_no IS '显示排序';
COMMENT ON COLUMN cost_subsystem_dict.status IS '状态：ENABLE/DISABLE';
COMMENT ON COLUMN cost_subsystem_dict.remark IS '备注';
COMMENT ON COLUMN cost_subsystem_dict.creator IS '创建者';
COMMENT ON COLUMN cost_subsystem_dict.create_time IS '创建时间';
COMMENT ON COLUMN cost_subsystem_dict.updater IS '更新者';
COMMENT ON COLUMN cost_subsystem_dict.update_time IS '更新时间';
COMMENT ON COLUMN cost_subsystem_dict.deleted IS '是否删除';
COMMENT ON COLUMN cost_subsystem_dict.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_unit_cost_detail.id IS '主键';
COMMENT ON COLUMN cost_unit_cost_detail.project_id IS '主业项目编号';
COMMENT ON COLUMN cost_unit_cost_detail.project_code IS '主业项目编号冗余';
COMMENT ON COLUMN cost_unit_cost_detail.project_name IS '主业项目名称冗余';
COMMENT ON COLUMN cost_unit_cost_detail.domain_code IS '所属领域编码';
COMMENT ON COLUMN cost_unit_cost_detail.domain_name IS '所属领域名称';
COMMENT ON COLUMN cost_unit_cost_detail.model_node_id IS '型号树节点编号';
COMMENT ON COLUMN cost_unit_cost_detail.model_code IS '型号/项目编码';
COMMENT ON COLUMN cost_unit_cost_detail.model_name IS '型号/项目名称';
COMMENT ON COLUMN cost_unit_cost_detail.unit_id IS '研制单位编号';
COMMENT ON COLUMN cost_unit_cost_detail.unit_name IS '研制单位名称';
COMMENT ON COLUMN cost_unit_cost_detail.stage_code IS '累计金额固定阶段标识';
COMMENT ON COLUMN cost_unit_cost_detail.source_record_id IS '预分预控源记录主键';
COMMENT ON COLUMN cost_unit_cost_detail.source_update_time IS '预分预控源记录更新时间';
COMMENT ON COLUMN cost_unit_cost_detail.contract_amount IS '预分预控项目单位累计合同金额，单位万元';
COMMENT ON COLUMN cost_unit_cost_detail.income_amount IS '预分预控项目单位累计到款金额，单位万元';
COMMENT ON COLUMN cost_unit_cost_detail.target_cost_amount IS '预分预控项目单位累计目标成本，单位万元';
COMMENT ON COLUMN cost_unit_cost_detail.book_cost_amount IS '历史兼容账面字段，不参与现行汇总';
COMMENT ON COLUMN cost_unit_cost_detail.approved_amount IS '预分预控项目单位累计审定金额，单位万元';
COMMENT ON COLUMN cost_unit_cost_detail.salary_amount IS '历史六类组成兼容字段，不参与现行账面组成';
COMMENT ON COLUMN cost_unit_cost_detail.material_amount IS '历史六类组成兼容字段，不参与现行账面组成';
COMMENT ON COLUMN cost_unit_cost_detail.outsource_amount IS '历史六类组成兼容字段，不参与现行账面组成';
COMMENT ON COLUMN cost_unit_cost_detail.manage_amount IS '历史六类组成兼容字段，不参与现行账面组成';
COMMENT ON COLUMN cost_unit_cost_detail.fuel_power_amount IS '历史六类组成兼容字段，不参与现行账面组成';
COMMENT ON COLUMN cost_unit_cost_detail.other_amount IS '历史六类组成兼容字段，不参与现行账面组成';
COMMENT ON COLUMN cost_unit_cost_detail.remark IS '备注';
COMMENT ON COLUMN cost_unit_cost_detail.creator IS '创建者';
COMMENT ON COLUMN cost_unit_cost_detail.create_time IS '创建时间';
COMMENT ON COLUMN cost_unit_cost_detail.updater IS '更新者';
COMMENT ON COLUMN cost_unit_cost_detail.update_time IS '更新时间';
COMMENT ON COLUMN cost_unit_cost_detail.deleted IS '是否删除';
COMMENT ON COLUMN cost_unit_cost_detail.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_user_project_scope.id IS '主键';
COMMENT ON COLUMN cost_user_project_scope.user_id IS '系统用户编号';
COMMENT ON COLUMN cost_user_project_scope.project_code IS '授权主业项目编号';
COMMENT ON COLUMN cost_user_project_scope.creator IS '创建者';
COMMENT ON COLUMN cost_user_project_scope.create_time IS '创建时间';
COMMENT ON COLUMN cost_user_project_scope.updater IS '更新者';
COMMENT ON COLUMN cost_user_project_scope.update_time IS '更新时间';
COMMENT ON COLUMN cost_user_project_scope.deleted IS '是否删除';
COMMENT ON COLUMN cost_user_project_scope.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_user_unit_scope.id IS '主键';
COMMENT ON COLUMN cost_user_unit_scope.user_id IS '系统用户编号';
COMMENT ON COLUMN cost_user_unit_scope.manage_unit_code IS '授权管理单位编号';
COMMENT ON COLUMN cost_user_unit_scope.manage_unit_name IS '授权时管理单位名称快照';
COMMENT ON COLUMN cost_user_unit_scope.creator IS '创建者';
COMMENT ON COLUMN cost_user_unit_scope.create_time IS '创建时间';
COMMENT ON COLUMN cost_user_unit_scope.updater IS '更新者';
COMMENT ON COLUMN cost_user_unit_scope.update_time IS '更新时间';
COMMENT ON COLUMN cost_user_unit_scope.deleted IS '是否删除';
COMMENT ON COLUMN cost_user_unit_scope.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_user_domain_scope.id IS '主键';
COMMENT ON COLUMN cost_user_domain_scope.user_id IS '系统用户编号';
COMMENT ON COLUMN cost_user_domain_scope.domain_code IS '授权领域编码';
COMMENT ON COLUMN cost_user_domain_scope.creator IS '创建者';
COMMENT ON COLUMN cost_user_domain_scope.create_time IS '创建时间';
COMMENT ON COLUMN cost_user_domain_scope.updater IS '更新者';
COMMENT ON COLUMN cost_user_domain_scope.update_time IS '更新时间';
COMMENT ON COLUMN cost_user_domain_scope.deleted IS '是否删除；领域授权使用物理替换';
COMMENT ON COLUMN cost_user_domain_scope.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_import_batch.id IS '主键';
COMMENT ON COLUMN cost_import_batch.import_type IS '导入类型：PROJECT_BASIC/WORK_ORDER';
COMMENT ON COLUMN cost_import_batch.file_name IS '原始文件名';
COMMENT ON COLUMN cost_import_batch.file_url IS '文件地址';
COMMENT ON COLUMN cost_import_batch.total_count IS '总行数';
COMMENT ON COLUMN cost_import_batch.success_count IS '成功行数';
COMMENT ON COLUMN cost_import_batch.failure_count IS '失败行数';
COMMENT ON COLUMN cost_import_batch.update_support IS '是否支持覆盖更新';
COMMENT ON COLUMN cost_import_batch.status IS '导入状态：SUCCESS/PART_SUCCESS/FAILED';
COMMENT ON COLUMN cost_import_batch.error_file_url IS '错误文件地址';
COMMENT ON COLUMN cost_import_batch.remark IS '备注';
COMMENT ON COLUMN cost_import_batch.creator IS '创建者';
COMMENT ON COLUMN cost_import_batch.create_time IS '创建时间';
COMMENT ON COLUMN cost_import_batch.updater IS '更新者';
COMMENT ON COLUMN cost_import_batch.update_time IS '更新时间';
COMMENT ON COLUMN cost_import_batch.deleted IS '是否删除';
COMMENT ON COLUMN cost_import_batch.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_import_error.id IS '主键';
COMMENT ON COLUMN cost_import_error.batch_id IS '导入批次编号';
COMMENT ON COLUMN cost_import_error.row_num IS 'Excel 行号';
COMMENT ON COLUMN cost_import_error.field_name IS '字段名';
COMMENT ON COLUMN cost_import_error.error_message IS '错误原因';
COMMENT ON COLUMN cost_import_error.raw_data IS '原始行数据 JSON';
COMMENT ON COLUMN cost_import_error.creator IS '创建者';
COMMENT ON COLUMN cost_import_error.create_time IS '创建时间';
COMMENT ON COLUMN cost_import_error.updater IS '更新者';
COMMENT ON COLUMN cost_import_error.update_time IS '更新时间';
COMMENT ON COLUMN cost_import_error.deleted IS '是否删除';
COMMENT ON COLUMN cost_import_error.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_warning_record.id IS '主键';
COMMENT ON COLUMN cost_warning_record.project_id IS '主业项目编号';
COMMENT ON COLUMN cost_warning_record.work_order_id IS '工作令编号，可为空';
COMMENT ON COLUMN cost_warning_record.project_code IS '项目编号快照';
COMMENT ON COLUMN cost_warning_record.project_name IS '项目名称快照';
COMMENT ON COLUMN cost_warning_record.domain_code IS '领域编码快照';
COMMENT ON COLUMN cost_warning_record.domain_name IS '领域名称快照';
COMMENT ON COLUMN cost_warning_record.model_code IS '型号编码快照';
COMMENT ON COLUMN cost_warning_record.model_name IS '型号名称快照';
COMMENT ON COLUMN cost_warning_record.warning_source IS '预警来源：PROJECT/WORK_ORDER';
COMMENT ON COLUMN cost_warning_record.warning_title IS '预警标题';
COMMENT ON COLUMN cost_warning_record.target_cost_amount IS '目标成本，单位万元';
COMMENT ON COLUMN cost_warning_record.actual_cost_amount IS '实际/账面成本，单位万元';
COMMENT ON COLUMN cost_warning_record.over_amount IS '超支金额，单位万元';
COMMENT ON COLUMN cost_warning_record.over_rate IS '超支比例';
COMMENT ON COLUMN cost_warning_record.threshold_rate IS '阈值比例';
COMMENT ON COLUMN cost_warning_record.warning_level IS '预警等级：NORMAL/OVER';
COMMENT ON COLUMN cost_warning_record.responsible_unit_name IS '责任单位';
COMMENT ON COLUMN cost_warning_record.push_status IS '推送状态：NOT_PUSHED/PUSHED/FAILED';
COMMENT ON COLUMN cost_warning_record.pushed_time IS '推送时间';
COMMENT ON COLUMN cost_warning_record.receiver_scope IS '接收范围';
COMMENT ON COLUMN cost_warning_record.message_id IS '中心消息编号【需确认】';
COMMENT ON COLUMN cost_warning_record.status IS '处理状态：OPEN/CLOSED';
COMMENT ON COLUMN cost_warning_record.remark IS '备注';
COMMENT ON COLUMN cost_warning_record.cycle_no IS '处置周期';
COMMENT ON COLUMN cost_warning_record.workflow_status IS '处置工作流状态';
COMMENT ON COLUMN cost_warning_record.active_marker IS '活动周期标记：1；关闭/历史为NULL';
COMMENT ON COLUMN cost_warning_record.initiator_user_id IS '发起人';
COMMENT ON COLUMN cost_warning_record.initiator_user_name IS '发起人快照';
COMMENT ON COLUMN cost_warning_record.initiated_time IS '发起时间';
COMMENT ON COLUMN cost_warning_record.disposition_user_id IS '处置人';
COMMENT ON COLUMN cost_warning_record.disposition_user_name IS '处置人快照';
COMMENT ON COLUMN cost_warning_record.cause_analysis IS '原因分析';
COMMENT ON COLUMN cost_warning_record.disposal_measure IS '处置措施';
COMMENT ON COLUMN cost_warning_record.expected_completion_date IS '预计完成日期';
COMMENT ON COLUMN cost_warning_record.disposition_time IS '反馈时间';
COMMENT ON COLUMN cost_warning_record.close_user_id IS '闭环人';
COMMENT ON COLUMN cost_warning_record.close_user_name IS '闭环人快照';
COMMENT ON COLUMN cost_warning_record.close_time IS '闭环时间';
COMMENT ON COLUMN cost_warning_record.return_reason IS '退回原因';
COMMENT ON COLUMN cost_warning_record.creator IS '创建者';
COMMENT ON COLUMN cost_warning_record.create_time IS '创建时间';
COMMENT ON COLUMN cost_warning_record.updater IS '更新者';
COMMENT ON COLUMN cost_warning_record.update_time IS '更新时间';
COMMENT ON COLUMN cost_warning_record.deleted IS '是否删除';
COMMENT ON COLUMN cost_warning_record.tenant_id IS '租户编号';
COMMENT ON TABLE cost_warning_receiver IS '成本预警通知接收记录表';
COMMENT ON COLUMN cost_warning_receiver.id IS '主键';
COMMENT ON COLUMN cost_warning_receiver.warning_record_id IS '预警记录编号';
COMMENT ON COLUMN cost_warning_receiver.user_id IS '用户编号';
COMMENT ON COLUMN cost_warning_receiver.username IS '用户账号';
COMMENT ON COLUMN cost_warning_receiver.nickname IS '用户昵称';
COMMENT ON COLUMN cost_warning_receiver.notify_status IS '通知状态';
COMMENT ON COLUMN cost_warning_receiver.message_id IS '消息编号';
COMMENT ON COLUMN cost_warning_receiver.notified_time IS '通知时间';
COMMENT ON COLUMN cost_warning_receiver.failure_reason IS '通知失败原因';
COMMENT ON COLUMN cost_warning_receiver.creator IS '创建者';
COMMENT ON COLUMN cost_warning_receiver.create_time IS '创建时间';
COMMENT ON COLUMN cost_warning_receiver.updater IS '更新者';
COMMENT ON COLUMN cost_warning_receiver.update_time IS '更新时间';
COMMENT ON COLUMN cost_warning_receiver.deleted IS '是否删除：0 未删除，1 已删除';
COMMENT ON COLUMN cost_warning_receiver.tenant_id IS '租户编号';
COMMENT ON TABLE cost_warning_action_log IS '成本预警处置操作日志表';
COMMENT ON COLUMN cost_warning_action_log.id IS '主键';
COMMENT ON COLUMN cost_warning_action_log.warning_record_id IS '预警记录编号';
COMMENT ON COLUMN cost_warning_action_log.action_type IS '操作类型';
COMMENT ON COLUMN cost_warning_action_log.operator_user_id IS '操作用户编号';
COMMENT ON COLUMN cost_warning_action_log.operator_user_name IS '操作用户名称';
COMMENT ON COLUMN cost_warning_action_log.operator_role_code IS '操作用户角色编码';
COMMENT ON COLUMN cost_warning_action_log.from_status IS '操作前状态';
COMMENT ON COLUMN cost_warning_action_log.to_status IS '操作后状态';
COMMENT ON COLUMN cost_warning_action_log.action_content IS '操作内容';
COMMENT ON COLUMN cost_warning_action_log.creator IS '创建者';
COMMENT ON COLUMN cost_warning_action_log.create_time IS '创建时间';
COMMENT ON COLUMN cost_warning_action_log.updater IS '更新者';
COMMENT ON COLUMN cost_warning_action_log.update_time IS '更新时间';
COMMENT ON COLUMN cost_warning_action_log.deleted IS '是否删除：0 未删除，1 已删除';
COMMENT ON COLUMN cost_warning_action_log.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_schema_migration.version IS '业务结构版本号';
COMMENT ON COLUMN cost_schema_migration.description IS '版本说明';
COMMENT ON COLUMN cost_schema_migration.installed_on IS '安装时间';
COMMENT ON COLUMN cost_schema_migration.installed_by IS '安装数据库用户';
COMMENT ON TABLE cost_user_role IS '成本本地角色覆盖；无记录沿用中台，role_code为空表示显式撤销，禁止同步清理';
COMMENT ON TABLE cost_user_role_action IS '成本角色分配追加式审计，不参与外部源同步或业务清库';
COMMENT ON COLUMN cost_user_role.id IS '主键';
COMMENT ON COLUMN cost_user_role.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_user_role.user_id IS '用户编号';
COMMENT ON COLUMN cost_user_role.role_code IS '本地成本角色编码：cost_global_viewer、cost_research_department、cost_project_office、cost_unit_user；NULL 表示显式撤销，禁止删除撤销记录';
COMMENT ON COLUMN cost_user_role.username IS '用户账号';
COMMENT ON COLUMN cost_user_role.nickname IS '用户昵称';
COMMENT ON COLUMN cost_user_role.revision IS '角色变更版本号；当前数据范围保存不递增此值';
COMMENT ON COLUMN cost_user_role.creator IS '创建者';
COMMENT ON COLUMN cost_user_role.updater IS '更新者';
COMMENT ON COLUMN cost_user_role.create_time IS '创建时间';
COMMENT ON COLUMN cost_user_role.update_time IS '更新时间';
COMMENT ON COLUMN cost_user_role.deleted IS '固定为 0；撤销通过 role_code=NULL 表达，不使用逻辑删除';
COMMENT ON COLUMN cost_user_role_action.id IS '主键';
COMMENT ON COLUMN cost_user_role_action.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_user_role_action.user_id IS '用户编号';
COMMENT ON COLUMN cost_user_role_action.actor_id IS '执行角色变更的用户编号';
COMMENT ON COLUMN cost_user_role_action.old_role_code IS '变更前角色编码';
COMMENT ON COLUMN cost_user_role_action.new_role_code IS '变更后角色编码；NULL 表示撤销';
COMMENT ON COLUMN cost_user_role_action.revision IS '角色变更版本号';
COMMENT ON COLUMN cost_user_role_action.create_time IS '创建时间';
COMMENT ON TABLE cost_auth_user_lock IS '成本授权用户互斥锁表；按租户与用户串行化角色和范围写入，不参与同步清理';
COMMENT ON COLUMN cost_auth_user_lock.tenant_id IS '租户编号';
COMMENT ON COLUMN cost_auth_user_lock.user_id IS '用户编号';
COMMENT ON COLUMN cost_auth_user_lock.revision IS '授权快照版本；角色或范围每次成功保存递增，拒绝陈旧页面覆盖';
COMMIT;
