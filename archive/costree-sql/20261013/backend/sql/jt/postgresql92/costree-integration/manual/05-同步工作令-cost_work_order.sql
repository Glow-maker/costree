-- 成本库内网分表同步 05：工作令字典 cost_work_order
-- 一条逻辑工作令只保留一行：项目 + 实际核算单位 + 工作令编号。
-- 年度属于账面明细，不属于工作令字典。

BEGIN;
SELECT pg_advisory_xact_lock(hashtext('costree-manual-work-order-sync'));

DROP TABLE IF EXISTS tmp_manual_context;
CREATE TEMP TABLE tmp_manual_context ON COMMIT PRESERVE ROWS AS
SELECT 124::int8 AS tenant_id, 'manual_work_order_sync'::varchar(64) AS source_tag;

DROP TABLE IF EXISTS tmp_manual_work_order_source;

-- =====================================================================
-- 【现场只修改本段】把内网工作令字典整理成以下固定输出列。
-- source_work_order_id 必须使用工作令字典真实稳定主键。
-- actual_unit_code/name 必须是实际核算单位，禁止使用电子所等管理简称。
-- =====================================================================
CREATE TEMP TABLE tmp_manual_work_order_source ON COMMIT PRESERVE ROWS AS
SELECT
    btrim(s.id)::varchar(128) AS source_work_order_id,
    btrim(s.zyxmcode)::varchar(128) AS project_code,
    NULLIF(btrim(s.zyxmname), '')::varchar(255) AS project_name,
    btrim(s.accountorgcode)::varchar(128) AS actual_unit_code,
    btrim(s.accountorgname)::varchar(255) AS actual_unit_name,
    btrim(s.cusitemcode)::varchar(128) AS work_order_no,
    NULLIF(btrim(s.cusitemname), '')::varchar(255) AS work_order_name,
    CASE WHEN lower(btrim(COALESCE(s.isdisabled, '0'))) IN
        ('1', 'true', 't', '是', 'yes', 'y', '停用') THEN true ELSE false END AS disabled,
    CASE WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN
        ('1', 'true', 't', '是', 'yes', 'y') THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_integration.dwd_bd_bfcustomitem_gzl s
WHERE COALESCE(btrim(s.treeinfo_isdetail), '1') IN ('1', 'true', 't', '是', 'yes', 'y');
-- =========================【现场字段映射区结束】=========================

DO $$
DECLARE
    v_tenant_id int8 := (SELECT tenant_id FROM tmp_manual_context);
BEGIN
    IF EXISTS (
        SELECT 1 FROM tmp_manual_work_order_source
        WHERE source_work_order_id IS NULL OR btrim(source_work_order_id) = ''
           OR project_code IS NULL OR btrim(project_code) = ''
           OR actual_unit_code IS NULL OR btrim(actual_unit_code) = ''
           OR actual_unit_name IS NULL OR btrim(actual_unit_name) = ''
           OR work_order_no IS NULL OR btrim(work_order_no) = ''
    ) THEN
        RAISE EXCEPTION '工作令映射存在空源主键、项目、实际单位或工作令编号';
    END IF;

    IF EXISTS (
        SELECT source_work_order_id FROM tmp_manual_work_order_source
        GROUP BY source_work_order_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '工作令映射存在重复 source_work_order_id';
    END IF;

    IF EXISTS (
        SELECT project_code, actual_unit_name, work_order_no
        FROM tmp_manual_work_order_source
        WHERE deleted = 0
        GROUP BY project_code, actual_unit_name, work_order_no
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '工作令映射存在重复的项目 + 实际单位 + 工作令编号';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_manual_work_order_source s
        WHERE s.deleted = 0
          AND NOT EXISTS (
              SELECT 1 FROM cost_project p
              WHERE p.tenant_id = v_tenant_id AND p.deleted = 0
                AND p.project_code = s.project_code
          )
    ) THEN
        RAISE EXCEPTION '工作令存在无法匹配 cost_project 的项目编号';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_manual_work_order_source s
        WHERE s.deleted = 0
          AND NOT EXISTS (
              SELECT 1 FROM cost_unit_dict d
              WHERE d.tenant_id = v_tenant_id AND d.deleted = 0
                AND d.accounting_unit_code = s.actual_unit_code
                AND d.accounting_unit_name = s.actual_unit_name
          )
    ) THEN
        RAISE EXCEPTION '工作令存在无法按编码 + 名称匹配单位字典的实际核算单位';
    END IF;

    IF EXISTS (
        SELECT source_work_order_id
        FROM cost_work_order
        WHERE tenant_id = v_tenant_id
          AND source_work_order_id IS NOT NULL
          AND btrim(source_work_order_id) <> ''
        GROUP BY source_work_order_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '目标工作令表存在重复 source_work_order_id';
    END IF;

    IF EXISTS (
        SELECT project_code, unit_name, work_order_no
        FROM cost_work_order
        WHERE tenant_id = v_tenant_id
        GROUP BY project_code, unit_name, work_order_no HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '目标工作令表存在重复业务键';
    END IF;
END $$;

DROP TABLE IF EXISTS tmp_manual_work_order_ready;
CREATE TEMP TABLE tmp_manual_work_order_ready ON COMMIT PRESERVE ROWS AS
SELECT
    s.source_work_order_id,
    p.id AS project_id, p.project_code, COALESCE(s.project_name, p.project_name) AS project_name,
    d.id AS unit_id, d.accounting_unit_code,
    d.accounting_unit_name AS actual_unit_name,
    s.work_order_no, s.work_order_name, s.disabled, s.deleted,
    COALESCE(
        (SELECT min(w.id) FROM cost_work_order w
         WHERE w.tenant_id = c.tenant_id
           AND w.source_work_order_id = s.source_work_order_id),
        (SELECT min(w.id) FROM cost_work_order w
         WHERE w.tenant_id = c.tenant_id
           AND w.project_code = s.project_code
           AND w.unit_name = d.accounting_unit_name
           AND w.work_order_no = s.work_order_no)
    ) AS target_id
FROM tmp_manual_work_order_source s
JOIN tmp_manual_context c ON 1 = 1
JOIN cost_project p
  ON p.tenant_id = c.tenant_id AND p.deleted = 0
 AND p.project_code = s.project_code
JOIN cost_unit_dict d
  ON d.tenant_id = c.tenant_id AND d.deleted = 0
 AND d.accounting_unit_code = s.actual_unit_code
 AND d.accounting_unit_name = s.actual_unit_name;

UPDATE cost_work_order w
SET source_work_order_id = s.source_work_order_id,
    project_id = s.project_id,
    project_code = s.project_code,
    project_name = s.project_name,
    unit_id = s.unit_id,
    unit_name = s.actual_unit_name,
    accounting_unit_code = s.accounting_unit_code,
    accounting_unit_name = s.actual_unit_name,
    fiscal_year = '',
    work_order_no = s.work_order_no,
    work_order_name = s.work_order_name,
    disabled = s.disabled,
    deleted = s.deleted,
    remark = '内网工作令字典分表同步；填报字段由研制单位维护',
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_manual_work_order_ready s
CROSS JOIN tmp_manual_context c
WHERE w.id = s.target_id;

INSERT INTO cost_work_order (
    source_work_order_id, project_id, project_code, project_name,
    unit_id, unit_name, accounting_unit_code, accounting_unit_name,
    fiscal_year, work_order_no, work_order_name,
    product_target_cost, contract_amount, income_amount, book_cost_amount,
    stage_codes, max_stage_code, subsystem_name, product_short_name,
    quantity, vertical_division, disabled, approved_amount, status,
    remark, creator, updater, deleted, tenant_id
)
SELECT
    s.source_work_order_id, s.project_id, s.project_code, s.project_name,
    s.unit_id, s.actual_unit_name, s.accounting_unit_code, s.actual_unit_name,
    '', s.work_order_no, s.work_order_name,
    NULL, NULL, NULL, 0,
    NULL, NULL, NULL, NULL,
    NULL, NULL, s.disabled, NULL, 'DRAFT',
    '内网工作令字典分表同步；填报字段由研制单位维护',
    c.source_tag, c.source_tag, s.deleted, c.tenant_id
FROM tmp_manual_work_order_ready s
CROSS JOIN tmp_manual_context c
WHERE s.target_id IS NULL;

-- 导入后验收：必须为 0。以下字段没有出现在 UPDATE SET 中，定时同步不会覆盖：
-- contract_amount、income_amount、product_target_cost、approved_amount、
-- stage_codes、max_stage_code、subsystem_name、product_short_name、quantity、vertical_division。
SELECT count(*) AS source_work_orders_not_written
FROM tmp_manual_work_order_ready s
CROSS JOIN tmp_manual_context c
WHERE NOT EXISTS (
    SELECT 1 FROM cost_work_order w
    WHERE w.tenant_id = c.tenant_id
      AND w.source_work_order_id = s.source_work_order_id
      AND w.project_code = s.project_code
      AND w.unit_name = s.actual_unit_name
      AND w.work_order_no = s.work_order_no
);

COMMIT;
