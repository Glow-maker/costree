-- 成本库内网分表同步 03：单位字典 cost_unit_dict
-- 必须先于单位金额、工作令和账面明细执行。
-- accounting_unit_name 是实际核算单位；manage_unit_name 是成本树聚合简称。

BEGIN;
SELECT pg_advisory_xact_lock(hashtext('costree-manual-unit-dict-sync'));

DROP TABLE IF EXISTS tmp_manual_context;
CREATE TEMP TABLE tmp_manual_context ON COMMIT PRESERVE ROWS AS
SELECT 124::int8 AS tenant_id, 'manual_unit_dict_sync'::varchar(64) AS source_tag;

DROP TABLE IF EXISTS tmp_manual_unit_source;

-- =====================================================================
-- 【现场只修改本段】把内网权威单位字典整理成以下固定输出列。
-- accounting_unit_id/code/name 必须表示真实核算单位，不能写管理单位简称。
-- 如果源表已有管理分类可直接使用；否则按 manage_unit_name 生成。
-- =====================================================================
CREATE TEMP TABLE tmp_manual_unit_source ON COMMIT PRESERVE ROWS AS
SELECT
    btrim(s.accounting_unit_id)::varchar(128) AS accounting_unit_id,
    btrim(s.accounting_unit_code)::varchar(128) AS accounting_unit_code,
    btrim(s.accounting_unit_name)::varchar(255) AS accounting_unit_name,
    NULLIF(btrim(s.manage_unit_code), '')::varchar(128) AS manage_unit_code,
    COALESCE(NULLIF(btrim(s.manage_unit_name), ''), btrim(s.accounting_unit_name))::varchar(255)
        AS manage_unit_name,
    CASE
        WHEN NULLIF(btrim(s.manage_unit_group), '') IS NOT NULL
            THEN upper(btrim(s.manage_unit_group))
        WHEN btrim(s.manage_unit_name) = '院部' THEN 'HEAD_OFFICE'
        WHEN btrim(s.manage_unit_name) IN ('八部', '509所') THEN 'OVERALL'
        WHEN btrim(s.manage_unit_name) IN ('800所', '149厂', '812所') THEN 'ASSEMBLY'
        WHEN btrim(s.manage_unit_name) IN ('电子所', '动力所', '811所', '802所', '803所')
            THEN 'PROFESSIONAL'
        WHEN btrim(s.manage_unit_name) = '基础所' THEN 'FOUNDATION'
        WHEN lower(btrim(COALESCE(s.inside_institute, '0'))) NOT IN
             ('1', 'true', 't', '是', 'yes', 'y')
            THEN 'OUTER'
        ELSE NULL
    END::varchar(32) AS manage_unit_group,
    NULLIF(btrim(s.contact_unit_code), '')::varchar(128) AS contact_unit_code,
    NULLIF(btrim(s.contact_unit_name), '')::varchar(255) AS contact_unit_name,
    CASE WHEN lower(btrim(COALESCE(s.inside_group, '0'))) IN
        ('1', 'true', 't', '是', 'yes', 'y') THEN true ELSE false END AS inside_group,
    CASE WHEN lower(btrim(COALESCE(s.inside_institute, '0'))) IN
        ('1', 'true', 't', '是', 'yes', 'y') THEN true ELSE false END AS inside_institute,
    CASE WHEN lower(btrim(COALESCE(s.disabled, '0'))) IN
        ('1', 'true', 't', '是', 'yes', 'y') THEN 'DISABLE' ELSE 'ENABLE' END::varchar(32)
        AS status,
    CASE WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN
        ('1', 'true', 't', '是', 'yes', 'y') THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_integration.unit_dict s;
-- =========================【现场字段映射区结束】=========================

DO $$
DECLARE
    v_tenant_id int8 := (SELECT tenant_id FROM tmp_manual_context);
BEGIN
    IF EXISTS (
        SELECT 1 FROM tmp_manual_unit_source
        WHERE accounting_unit_id IS NULL OR btrim(accounting_unit_id) = ''
           OR accounting_unit_code IS NULL OR btrim(accounting_unit_code) = ''
           OR accounting_unit_name IS NULL OR btrim(accounting_unit_name) = ''
    ) THEN
        RAISE EXCEPTION '单位字典存在空核算单位 ID、编码或名称';
    END IF;

    IF EXISTS (
        SELECT accounting_unit_id FROM tmp_manual_unit_source
        GROUP BY accounting_unit_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '单位字典存在重复 accounting_unit_id';
    END IF;

    IF EXISTS (
        SELECT accounting_unit_code FROM tmp_manual_unit_source
        WHERE deleted = 0
        GROUP BY accounting_unit_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '单位字典存在重复的有效 accounting_unit_code';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_manual_unit_source
        WHERE manage_unit_group IS NOT NULL
          AND manage_unit_group NOT IN
              ('HEAD_OFFICE', 'OVERALL', 'ASSEMBLY', 'PROFESSIONAL', 'FOUNDATION', 'OUTER')
    ) THEN
        RAISE EXCEPTION 'manage_unit_group 存在非法值';
    END IF;

    IF EXISTS (
        SELECT accounting_unit_id
        FROM cost_unit_dict
        WHERE tenant_id = v_tenant_id AND deleted = 0
          AND accounting_unit_id IN (
              SELECT accounting_unit_id FROM tmp_manual_unit_source WHERE deleted = 0
          )
        GROUP BY accounting_unit_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '目标单位字典存在重复 accounting_unit_id';
    END IF;
END $$;

UPDATE cost_unit_dict d
SET accounting_unit_code = s.accounting_unit_code,
    accounting_unit_name = s.accounting_unit_name,
    manage_unit_code = s.manage_unit_code,
    manage_unit_name = s.manage_unit_name,
    manage_unit_group = s.manage_unit_group,
    contact_unit_code = s.contact_unit_code,
    contact_unit_name = s.contact_unit_name,
    inside_group = s.inside_group,
    inside_institute = s.inside_institute,
    status = s.status,
    deleted = s.deleted,
    remark = '内网权威单位字典分表同步',
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_manual_unit_source s
CROSS JOIN tmp_manual_context c
WHERE d.tenant_id = c.tenant_id
  AND d.accounting_unit_id = s.accounting_unit_id;

INSERT INTO cost_unit_dict (
    accounting_unit_id, accounting_unit_code, accounting_unit_name,
    manage_unit_code, manage_unit_name, manage_unit_group,
    contact_unit_code, contact_unit_name, inside_group, inside_institute,
    status, remark, creator, updater, deleted, tenant_id
)
SELECT
    s.accounting_unit_id, s.accounting_unit_code, s.accounting_unit_name,
    s.manage_unit_code, s.manage_unit_name, s.manage_unit_group,
    s.contact_unit_code, s.contact_unit_name, s.inside_group, s.inside_institute,
    s.status, '内网权威单位字典分表同步', c.source_tag, c.source_tag, s.deleted, c.tenant_id
FROM tmp_manual_unit_source s
CROSS JOIN tmp_manual_context c
WHERE NOT EXISTS (
    SELECT 1 FROM cost_unit_dict d
    WHERE d.tenant_id = c.tenant_id
      AND d.accounting_unit_id = s.accounting_unit_id
);

-- 导入后验收：第一个结果必须为 0；第二个结果是待人工归类的院内单位。
SELECT count(*) AS source_units_not_written
FROM tmp_manual_unit_source s
CROSS JOIN tmp_manual_context c
WHERE NOT EXISTS (
    SELECT 1 FROM cost_unit_dict d
    WHERE d.tenant_id = c.tenant_id
      AND d.accounting_unit_id = s.accounting_unit_id
      AND d.accounting_unit_code = s.accounting_unit_code
);

SELECT accounting_unit_code, accounting_unit_name, manage_unit_name
FROM tmp_manual_unit_source
WHERE deleted = 0
  AND inside_institute = true
  AND manage_unit_group IS NULL
ORDER BY accounting_unit_code;

COMMIT;
