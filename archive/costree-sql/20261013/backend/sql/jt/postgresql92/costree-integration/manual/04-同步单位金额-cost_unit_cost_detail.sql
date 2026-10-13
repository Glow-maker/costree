-- 成本库内网分表同步 04：预分预控单位金额 cost_unit_cost_detail
-- 权威粒度：租户 + 项目编号 + 实际核算单位名称，stage_code 固定为 ALL。
-- 本脚本只同步合同和到款；绝不覆盖项目办填写的目标、审定。

BEGIN;
SELECT pg_advisory_xact_lock(hashtext('costree-manual-unit-cost-sync'));

DROP TABLE IF EXISTS tmp_manual_context;
CREATE TEMP TABLE tmp_manual_context ON COMMIT PRESERVE ROWS AS
SELECT 124::int8 AS tenant_id, 'manual_unit_cost_sync'::varchar(64) AS source_tag;

DROP TABLE IF EXISTS tmp_manual_unit_cost_source;

-- =====================================================================
-- 【现场只修改本段】把预分预控治理结果整理成以下固定输出列。
-- 金额单位必须已经是“万元”；actual_unit_name 必须是实际核算单位名称。
-- 不要把 manage_unit_name 写入 actual_unit_name。
-- =====================================================================
CREATE TEMP TABLE tmp_manual_unit_cost_source ON COMMIT PRESERVE ROWS AS
SELECT
    btrim(s.source_record_id)::varchar(128) AS source_record_id,
    s.source_update_time::timestamp AS source_update_time,
    btrim(s.project_code)::varchar(128) AS project_code,
    NULLIF(btrim(s.project_name), '')::varchar(255) AS project_name,
    btrim(s.accounting_unit_id)::varchar(128) AS accounting_unit_id,
    btrim(s.unit_name)::varchar(255) AS actual_unit_name,
    s.contract_amount::numeric(18,2) AS contract_amount,
    s.income_amount::numeric(18,2) AS income_amount,
    COALESCE(s.source_deleted, 0)::int2 AS deleted
FROM cost_integration.precontrol_project_unit_amount s;
-- =========================【现场字段映射区结束】=========================

DO $$
DECLARE
    v_tenant_id int8 := (SELECT tenant_id FROM tmp_manual_context);
BEGIN
    IF EXISTS (
        SELECT 1 FROM tmp_manual_unit_cost_source
        WHERE source_record_id IS NULL OR btrim(source_record_id) = ''
           OR project_code IS NULL OR btrim(project_code) = ''
           OR accounting_unit_id IS NULL OR btrim(accounting_unit_id) = ''
           OR actual_unit_name IS NULL OR btrim(actual_unit_name) = ''
    ) THEN
        RAISE EXCEPTION '单位金额存在空源记录 ID、项目编号或实际核算单位';
    END IF;

    IF EXISTS (
        SELECT source_record_id FROM tmp_manual_unit_cost_source
        GROUP BY source_record_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '单位金额存在重复 source_record_id';
    END IF;

    IF EXISTS (
        SELECT project_code, actual_unit_name FROM tmp_manual_unit_cost_source
        WHERE deleted = 0
        GROUP BY project_code, actual_unit_name HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '单位金额存在重复的项目 + 实际核算单位';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_manual_unit_cost_source
        WHERE COALESCE(contract_amount, 0) < 0 OR COALESCE(income_amount, 0) < 0
    ) THEN
        RAISE EXCEPTION '单位金额合同或到款存在负数';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_manual_unit_cost_source s
        WHERE s.deleted = 0
          AND NOT EXISTS (
              SELECT 1 FROM cost_project p
              WHERE p.tenant_id = v_tenant_id AND p.deleted = 0
                AND p.project_code = s.project_code
          )
    ) THEN
        RAISE EXCEPTION '单位金额存在无法匹配 cost_project 的项目编号';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_manual_unit_cost_source s
        WHERE s.deleted = 0
          AND NOT EXISTS (
              SELECT 1 FROM cost_unit_dict d
              WHERE d.tenant_id = v_tenant_id AND d.deleted = 0
                AND d.accounting_unit_id = s.accounting_unit_id
                AND d.accounting_unit_name = s.actual_unit_name
          )
    ) THEN
        RAISE EXCEPTION '单位金额存在无法按 ID + 名称匹配单位字典的实际核算单位';
    END IF;

    IF EXISTS (
        SELECT project_code, unit_name
        FROM cost_unit_cost_detail
        WHERE tenant_id = v_tenant_id AND deleted = 0 AND stage_code = 'ALL'
        GROUP BY project_code, unit_name HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '目标单位金额表已存在重复项目 + 单位记录';
    END IF;
END $$;

DROP TABLE IF EXISTS tmp_manual_unit_cost_ready;
CREATE TEMP TABLE tmp_manual_unit_cost_ready ON COMMIT PRESERVE ROWS AS
SELECT
    s.source_record_id, s.source_update_time,
    p.id AS project_id, p.project_code,
    COALESCE(s.project_name, p.project_name) AS project_name,
    p.domain_code, p.domain_name, p.model_node_id, p.model_code, p.model_name,
    d.id AS unit_id, d.accounting_unit_name AS unit_name,
    s.contract_amount, s.income_amount, s.deleted
FROM tmp_manual_unit_cost_source s
JOIN tmp_manual_context c ON 1 = 1
JOIN cost_project p
  ON p.tenant_id = c.tenant_id AND p.deleted = 0
 AND p.project_code = s.project_code
JOIN cost_unit_dict d
  ON d.tenant_id = c.tenant_id AND d.deleted = 0
 AND d.accounting_unit_id = s.accounting_unit_id
 AND d.accounting_unit_name = s.actual_unit_name;

UPDATE cost_unit_cost_detail d
SET project_id = s.project_id,
    project_name = s.project_name,
    domain_code = s.domain_code,
    domain_name = s.domain_name,
    model_node_id = s.model_node_id,
    model_code = s.model_code,
    model_name = s.model_name,
    unit_id = s.unit_id,
    stage_code = 'ALL',
    source_record_id = s.source_record_id,
    source_update_time = s.source_update_time,
    contract_amount = s.contract_amount,
    income_amount = s.income_amount,
    deleted = s.deleted,
    remark = '预分预控项目单位累计金额分表同步',
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_manual_unit_cost_ready s
CROSS JOIN tmp_manual_context c
WHERE d.tenant_id = c.tenant_id
  AND d.project_code = s.project_code
  AND d.unit_name = s.unit_name
  AND d.stage_code = 'ALL';

INSERT INTO cost_unit_cost_detail (
    project_id, project_code, project_name, domain_code, domain_name,
    model_node_id, model_code, model_name, unit_id, unit_name, stage_code,
    source_record_id, source_update_time, contract_amount, income_amount,
    target_cost_amount, book_cost_amount, approved_amount,
    remark, creator, updater, deleted, tenant_id
)
SELECT
    s.project_id, s.project_code, s.project_name, s.domain_code, s.domain_name,
    s.model_node_id, s.model_code, s.model_name, s.unit_id, s.unit_name, 'ALL',
    s.source_record_id, s.source_update_time, s.contract_amount, s.income_amount,
    NULL, 0, NULL,
    '预分预控项目单位累计金额分表同步', c.source_tag, c.source_tag, s.deleted, c.tenant_id
FROM tmp_manual_unit_cost_ready s
CROSS JOIN tmp_manual_context c
WHERE NOT EXISTS (
    SELECT 1 FROM cost_unit_cost_detail d
    WHERE d.tenant_id = c.tenant_id
      AND d.project_code = s.project_code
      AND d.unit_name = s.unit_name
      AND d.stage_code = 'ALL'
);

-- 导入后验收：必须为 0。目标和审定列不在 UPDATE SET 中，定时同步不会覆盖填报值。
SELECT count(*) AS source_unit_amount_not_written
FROM tmp_manual_unit_cost_ready s
CROSS JOIN tmp_manual_context c
WHERE NOT EXISTS (
    SELECT 1 FROM cost_unit_cost_detail d
    WHERE d.tenant_id = c.tenant_id
      AND d.project_code = s.project_code
      AND d.unit_name = s.unit_name
      AND d.stage_code = 'ALL'
      AND COALESCE(d.contract_amount, 0) = COALESCE(s.contract_amount, 0)
      AND COALESCE(d.income_amount, 0) = COALESCE(s.income_amount, 0)
);

COMMIT;
