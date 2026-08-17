-- 外部源全量装载模板。
-- 现场只需把下方 <源系统schema> 替换为实际 schema，并核对字段映射。
-- 如果使用 Navicat/数据治理工作流直接导入 cost_sync_stage 六张表，可跳过 INSERT，
-- 但必须执行文件末尾“装载完成标记”。

BEGIN;

-- 1. 权威单位字典。源表字段若不同，只调整本段 SELECT。
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

-- 2. 主业项目树。parent_xmnm 必须是已确认有效的父节点内码。
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

-- 3. 主业项目。默认把第三级叶子作为成本库型号项目。
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

-- 4. 预分预控项目单位累计金额，合同和到款单位必须为万元。
-- 目标、审定不从源覆盖，因此中间表不接收这两个字段。
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

-- 5. 工作令关联主业项目字典。一条逻辑工作令不按年度拆行。
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

-- 6. 工作令账面凭证明细。je 为元；借、贷全部装入中间表。
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

-- 装载完成标记。直接导入中间表时，单独执行本段即可。
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cost_sync_stage.stg_model_node)
       OR NOT EXISTS (SELECT 1 FROM cost_sync_stage.stg_project) THEN
        RAISE EXCEPTION '型号树或项目中间表为空，拒绝把空快照标记为 READY';
    END IF;
END $$;

UPDATE cost_sync_stage.sync_control
SET load_status = 'READY',
    loaded_at = CURRENT_TIMESTAMP,
    synced_at = NULL,
    remark = '本批外部源全量快照已装入中间表'
WHERE id = 1;

COMMIT;

SELECT 'stg_unit_dict' AS stage_table, count(*) AS row_count FROM cost_sync_stage.stg_unit_dict
UNION ALL SELECT 'stg_model_node', count(*) FROM cost_sync_stage.stg_model_node
UNION ALL SELECT 'stg_project', count(*) FROM cost_sync_stage.stg_project
UNION ALL SELECT 'stg_unit_amount', count(*) FROM cost_sync_stage.stg_unit_amount
UNION ALL SELECT 'stg_work_order', count(*) FROM cost_sync_stage.stg_work_order
UNION ALL SELECT 'stg_ledger_detail', count(*) FROM cost_sync_stage.stg_ledger_detail
ORDER BY stage_table;
