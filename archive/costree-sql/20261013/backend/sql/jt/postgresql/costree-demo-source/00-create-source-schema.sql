-- 成本库外部数据源模拟表（PostgreSQL 14+）
-- 只创建独立 schema，不修改 public 下的成本库业务表。

BEGIN;

CREATE SCHEMA IF NOT EXISTS cost_demo_source;

CREATE TABLE IF NOT EXISTS cost_demo_source.demo_config
(
    id          int2         NOT NULL DEFAULT 1,
    tenant_id   int8         NOT NULL DEFAULT 124,
    batch_code  varchar(64)  NOT NULL DEFAULT 'COST-DEMO-20260721',
    source_tag  varchar(64)  NOT NULL DEFAULT 'cost_demo_sync',
    update_time timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_cost_demo_config PRIMARY KEY (id),
    CONSTRAINT ck_cost_demo_config_singleton CHECK (id = 1)
);

INSERT INTO cost_demo_source.demo_config (id, tenant_id, batch_code, source_tag)
VALUES (1, 124, 'COST-DEMO-20260721', 'cost_demo_sync')
ON CONFLICT (id) DO NOTHING;

-- 单位字典源表。真实源表名称未确定，测试表保留导入所需的标准字段。
CREATE TABLE IF NOT EXISTS cost_demo_source.unit_dict
(
    source_record_id     varchar(255) NOT NULL,
    accounting_unit_id   varchar(255) NOT NULL,
    accounting_unit_code varchar(255) NOT NULL,
    accounting_unit_name varchar(255) NOT NULL,
    manage_unit_code     varchar(255),
    manage_unit_name     varchar(255),
    manage_unit_group    varchar(255),
    contact_unit_code    varchar(255),
    contact_unit_name    varchar(255),
    inside_group         varchar(255),
    inside_institute     varchar(255),
    disabled             varchar(255) NOT NULL DEFAULT '0',
    source_update_time   varchar(255),
    source_deleted       varchar(255) NOT NULL DEFAULT '0',
    CONSTRAINT pk_cost_demo_unit_dict PRIMARY KEY (source_record_id),
    CONSTRAINT uk_cost_demo_unit_dict_accounting_id UNIQUE (accounting_unit_id)
);

-- 主业项目树原表镜像。字段名和 varchar(255) 特征对齐 ads_lc_lshsxm2022。
CREATE TABLE IF NOT EXISTS cost_demo_source.ads_lc_lshsxm2022
(
    lshsxm_id          varchar(255) NOT NULL,
    lshsxm_xmnm        varchar(255) NOT NULL,
    lshsxm_xmbh        varchar(255),
    lshsxm_xmmc        varchar(255) NOT NULL,
    lshsxm_js          varchar(255) NOT NULL,
    lshsxm_mx          varchar(255),
    lshsxm_dwbh        varchar(255),
    lshsxm_fjnm        varchar(255),
    lshsxm_xmlx        varchar(255),
    parent_xmnm        varchar(255),
    lshsxm_ms          varchar(255),
    seclevel           varchar(255),
    lshsxm_zt          varchar(255),
    nfjm               varchar(255),
    nxmnm              varchar(255),
    disabled           varchar(255) NOT NULL DEFAULT '0',
    nparent_xmnm       varchar(255),
    jyrq               varchar(255),
    wglx               varchar(255),
    xmsx               varchar(255),
    lastmodifiedtime   varchar(255),
    source_deleted     varchar(255) NOT NULL DEFAULT '0',
    CONSTRAINT pk_cost_demo_project_tree PRIMARY KEY (lshsxm_id),
    CONSTRAINT uk_cost_demo_project_tree_xmnm UNIQUE (lshsxm_xmnm)
);

-- 工作令关联主业项目字典镜像。年度由账面明细中的 kjnd 补齐。
CREATE TABLE IF NOT EXISTS cost_demo_source.dwd_bd_bfcustomitem_gzl
(
    id                         varchar(255) NOT NULL,
    accountorg                 varchar(255),
    cusitemcategory            varchar(255),
    cusitemcode                varchar(255) NOT NULL,
    cusitemname                varchar(255),
    cusitemproperty            varchar(255),
    accountorgcode             varchar(255) NOT NULL,
    accountorgname             varchar(255) NOT NULL,
    ejname                     varchar(255),
    yjname                     varchar(255),
    ifstopname                 varchar(255),
    iscompleted                varchar(255),
    isdisabled                 varchar(255) NOT NULL DEFAULT '0',
    timestamp_createdby        varchar(255),
    timestamp_createdon        varchar(255),
    timestamp_lastchangedby    varchar(255),
    timestamp_lastchangedon    varchar(255),
    treeinfo_isdetail          varchar(255),
    treeinfo_layer             varchar(255),
    treeinfo_path              varchar(255),
    dwts                       varchar(255),
    zyxmid                     varchar(255) NOT NULL,
    zyxmcode                   varchar(255) NOT NULL,
    zyxmname                   varchar(255),
    seccode                    varchar(255),
    secname                    varchar(255),
    note                       varchar(255),
    timestamp_lastchangedon2   varchar(255),
    source_deleted             varchar(255) NOT NULL DEFAULT '0',
    CONSTRAINT pk_cost_demo_work_order_ref PRIMARY KEY (id)
);

-- 预分预控治理结果：项目 + 核算单位累计金额，金额单位为万元。
CREATE TABLE IF NOT EXISTS cost_demo_source.precontrol_project_unit_amount
(
    source_record_id   varchar(128)  NOT NULL,
    source_update_time timestamp     NOT NULL,
    project_code       varchar(128)  NOT NULL,
    project_name       varchar(255),
    accounting_unit_id varchar(128)  NOT NULL,
    unit_name          varchar(255)  NOT NULL,
    contract_amount    numeric(18,2),
    income_amount      numeric(18,2),
    target_cost_amount numeric(18,2),
    approved_amount    numeric(18,2),
    source_deleted     int2          NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_demo_precontrol_amount PRIMARY KEY (source_record_id),
    CONSTRAINT uk_cost_demo_precontrol_project_unit UNIQUE (project_code, unit_name)
);

-- 项目办非财务补充字段。合同、到款、目标和审定不在本表维护。
CREATE TABLE IF NOT EXISTS cost_demo_source.project_office_fill
(
    source_record_id        varchar(128) NOT NULL,
    project_code            varchar(128) NOT NULL,
    product_attachment_type varchar(32)  NOT NULL,
    subsystem_name          varchar(255),
    quantity                int4,
    product_short_name      varchar(255),
    vertical_division       bool,
    user_name               varchar(255),
    acquire_method          varchar(128),
    batch_category          varchar(128),
    platform_series         varchar(128),
    research_unit_name      varchar(255),
    tax_exempt              varchar(16),
    cycle_start             varchar(16),
    cycle_end               varchar(16),
    stage_code              varchar(64),
    basic_info              text,
    status                  varchar(32)  NOT NULL DEFAULT 'SUBMITTED',
    source_update_time      timestamp    NOT NULL,
    source_deleted          int2         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_demo_project_office_fill PRIMARY KEY (source_record_id),
    CONSTRAINT uk_cost_demo_project_office_project UNIQUE (project_code)
);

ALTER TABLE cost_demo_source.project_office_fill
    ADD COLUMN IF NOT EXISTS quantity int4,
    ADD COLUMN IF NOT EXISTS product_short_name varchar(255),
    ADD COLUMN IF NOT EXISTS vertical_division bool;

-- 研制单位工作令补充字段，按逻辑工作令 + 年度维护阶段等信息。
CREATE TABLE IF NOT EXISTS cost_demo_source.work_order_fill
(
    source_work_order_id varchar(128) NOT NULL,
    fiscal_year          varchar(16)  NOT NULL,
    stage_codes          varchar(255),
    max_stage_code       varchar(64),
    subsystem_name       varchar(255),
    product_short_name   varchar(255),
    quantity             int4,
    vertical_division    bool,
    source_update_time   timestamp    NOT NULL,
    source_deleted       int2         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_demo_work_order_fill PRIMARY KEY (source_work_order_id, fiscal_year)
);

-- 工作令凭证明细镜像。字段名和 varchar(255) 特征对齐 dws_bu_pz_pzmx_gzl。
CREATE TABLE IF NOT EXISTS cost_demo_source.dws_bu_pz_pzmx_gzl
(
    id                varchar(255) NOT NULL,
    ysnm              varchar(255) NOT NULL,
    kjnd              varchar(255) NOT NULL,
    kjqj              varchar(255),
    pzrq              varchar(255),
    pzbh              varchar(255),
    dwid              varchar(255),
    dwbh              varchar(255),
    dwmc              varchar(255) NOT NULL,
    gldw              varchar(255),
    gldwpxh           varchar(255),
    kmid              varchar(255),
    kmbh              varchar(255),
    kmmc              varchar(255),
    bmid              varchar(255),
    bmbh              varchar(255),
    bmmc              varchar(255),
    xmbh              varchar(255) NOT NULL,
    xmnm              varchar(255),
    xmmc              varchar(255),
    gzlnm             varchar(255) NOT NULL,
    gzllb             varchar(255) NOT NULL,
    gzlmc             varchar(255),
    wldwid            varchar(255),
    wldwbh            varchar(255),
    wldwmc            varchar(255),
    jzfx              varchar(255) NOT NULL,
    je                varchar(255) NOT NULL,
    yt                varchar(255),
    lastmodifiedtime  varchar(255),
    bizcode           varchar(255),
    bizdate           varchar(255),
    settlementdate    varchar(255),
    settlementnumber  varchar(255),
    dwts              varchar(255),
    ejkmbh            varchar(255),
    ejkmmc            varchar(255),
    source_deleted    varchar(255) NOT NULL DEFAULT '0',
    CONSTRAINT pk_cost_demo_ledger_raw PRIMARY KEY (id),
    CONSTRAINT uk_cost_demo_ledger_ysnm UNIQUE (ysnm)
);

CREATE INDEX IF NOT EXISTS idx_cost_demo_project_tree_parent
    ON cost_demo_source.ads_lc_lshsxm2022 (parent_xmnm);
CREATE INDEX IF NOT EXISTS idx_cost_demo_work_order_project
    ON cost_demo_source.dwd_bd_bfcustomitem_gzl (zyxmcode, accountorgname, cusitemcode);
CREATE INDEX IF NOT EXISTS idx_cost_demo_ledger_business
    ON cost_demo_source.dws_bu_pz_pzmx_gzl (xmbh, dwmc, gzllb, kjnd);

COMMENT ON SCHEMA cost_demo_source IS '成本库外部数据源闭环演示专用 schema';
COMMENT ON TABLE cost_demo_source.precontrol_project_unit_amount IS '预分预控项目单位累计金额模拟源，单位万元';
COMMENT ON TABLE cost_demo_source.dws_bu_pz_pzmx_gzl IS '工作令凭证明细模拟源，je 单位元';

COMMIT;
