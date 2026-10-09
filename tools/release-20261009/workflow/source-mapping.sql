-- 唯一可编辑的源 SELECT 区。保留六个标记与 INSERT 目标列，不改成写业务表。

-- BEGIN SOURCE stg_unit_dict
INSERT INTO cost_sync_stage.stg_unit_dict (
    source_record_id, accounting_unit_id, accounting_unit_code, accounting_unit_name,
    manage_unit_code, manage_unit_name, manage_unit_group,
    contact_unit_code, contact_unit_name, inside_group, inside_institute,
    disabled, source_update_time, source_deleted
)
SELECT
    source_record_id::varchar(255),
    accounting_unit_id::varchar(255),
    accounting_unit_code::varchar(255),
    accounting_unit_name::varchar(255),
    manage_unit_code::varchar(255),
    manage_unit_name::varchar(255),
    manage_unit_group::varchar(32),
    contact_unit_code::varchar(255),
    contact_unit_name::varchar(255),
    inside_group::varchar(16),
    inside_institute::varchar(16),
    disabled::varchar(16),
    source_update_time::varchar(64),
    source_deleted::varchar(16)
FROM "<源系统schema>"."unit_dict";
-- END SOURCE stg_unit_dict

-- BEGIN SOURCE stg_model_node
INSERT INTO cost_sync_stage.stg_model_node (
    node_code, parent_node_code, node_name, node_type, domain_code,
    sort_no, status, source_update_time, source_deleted
)
SELECT
    btrim(lshsxm_xmnm)::varchar(255),
    NULLIF(btrim(parent_xmnm), '')::varchar(255),
    btrim(lshsxm_xmmc)::varchar(255),
    CASE btrim(lshsxm_js)
        WHEN '1' THEN 'DOMAIN'
        WHEN '2' THEN 'SERIES'
        WHEN '3' THEN 'MODEL'
        ELSE NULL
    END::varchar(32),
    CASE WHEN btrim(lshsxm_js) = '1'
         THEN btrim(lshsxm_xmnm) ELSE NULL END::varchar(128),
    CASE WHEN btrim(lshsxm_js) = '1' THEN '100' ELSE '10' END::varchar(32),
    CASE WHEN lower(btrim(COALESCE(disabled, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN 'DISABLE' ELSE 'ENABLE' END::varchar(32),
    lastmodifiedtime::varchar(64),
    source_deleted::varchar(16)
FROM "<源系统schema>"."ads_lc_lshsxm2022";
-- END SOURCE stg_model_node

-- BEGIN SOURCE stg_project
INSERT INTO cost_sync_stage.stg_project (
    source_project_id, project_code, project_name, model_node_code,
    domain_code, domain_name, category_code, category_name,
    model_code, model_name, source_update_time, source_deleted
)
SELECT
    lshsxm_id::varchar(255),
    btrim(lshsxm_xmbh)::varchar(255),
    btrim(lshsxm_xmmc)::varchar(255),
    btrim(lshsxm_xmnm)::varchar(255),
    NULL::varchar(128), NULL::varchar(255),
    NULL::varchar(128), NULL::varchar(255),
    btrim(lshsxm_xmnm)::varchar(128),
    btrim(lshsxm_xmmc)::varchar(255),
    lastmodifiedtime::varchar(64),
    source_deleted::varchar(16)
FROM "<源系统schema>"."ads_lc_lshsxm2022"
WHERE btrim(lshsxm_js) = '3';
-- END SOURCE stg_project

-- BEGIN SOURCE stg_unit_amount
INSERT INTO cost_sync_stage.stg_unit_amount (
    source_record_id, source_update_time, project_code, project_name,
    accounting_unit_code, contract_amount_wan, income_amount_wan, source_deleted
)
SELECT
    source_record_id::varchar(255),
    source_update_time::varchar(64),
    btrim(project_code)::varchar(255),
    project_name::varchar(255),
    btrim(accounting_unit_code)::varchar(255),
    contract_amount::varchar(64),
    income_amount::varchar(64),
    source_deleted::varchar(16)
FROM "<源系统schema>"."precontrol_project_unit_amount";
-- END SOURCE stg_unit_amount

-- BEGIN SOURCE stg_work_order
INSERT INTO cost_sync_stage.stg_work_order (
    source_work_order_id, project_code, project_name, accounting_unit_code,
    work_order_no, work_order_name, disabled, source_update_time, source_deleted
)
SELECT
    id::varchar(255),
    btrim(zyxmcode)::varchar(255),
    zyxmname::varchar(255),
    btrim(accountorgcode)::varchar(255),
    btrim(cusitemcode)::varchar(255),
    cusitemname::varchar(255),
    isdisabled::varchar(16),
    COALESCE(timestamp_lastchangedon2, timestamp_lastchangedon)::varchar(64),
    source_deleted::varchar(16)
FROM "<源系统schema>"."dwd_bd_bfcustomitem_gzl";
-- END SOURCE stg_work_order

-- BEGIN SOURCE stg_ledger_detail
INSERT INTO cost_sync_stage.stg_ledger_detail (
    source_detail_id, fiscal_year, accounting_period, voucher_date, voucher_no,
    accounting_unit_id, accounting_unit_code,
    subject_id, subject_code, subject_name,
    project_code, source_project_id, project_name,
    source_work_order_id, work_order_no, work_order_name,
    debit_credit, amount_yuan, summary_text, source_lastmodify,
    second_subject_code, second_subject_name, source_timestamp, source_deleted
)
SELECT
    ysnm::varchar(255), kjnd::varchar(16), kjqj::varchar(16), pzrq::varchar(32),
    pzbh::varchar(255), dwid::varchar(255), btrim(dwbh)::varchar(255),
    kmid::varchar(255), kmbh::varchar(255), kmmc::varchar(255),
    btrim(xmbh)::varchar(255), xmnm::varchar(255), xmmc::varchar(255),
    gzlnm::varchar(255), btrim(gzllb)::varchar(255), gzlmc::varchar(255),
    jzfx::varchar(32), je::varchar(64), yt::varchar(1000),
    lastmodifiedtime::varchar(64), ejkmbh::varchar(255), ejkmmc::varchar(255),
    dwts::varchar(64), source_deleted::varchar(16)
FROM "<源系统schema>"."dws_bu_pz_pzmx_gzl";
-- END SOURCE stg_ledger_detail
