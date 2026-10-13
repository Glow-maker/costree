-- 成本库内网分表同步 02：项目 cost_project
-- project_code 必须是工作令、预分预控和账面都使用的主业项目编号。

BEGIN;
SELECT pg_advisory_xact_lock(hashtext('costree-manual-project-sync'));

DROP TABLE IF EXISTS tmp_manual_context;
CREATE TEMP TABLE tmp_manual_context ON COMMIT PRESERVE ROWS AS
SELECT 124::int8 AS tenant_id, 'manual_project_sync'::varchar(64) AS source_tag;

DROP TABLE IF EXISTS tmp_manual_project_source;

-- =====================================================================
-- 【现场只修改本段】把项目叶子整理成以下固定输出列。
-- model_node_code 用于关联 cost_model_node；它可以与 project_code 不同。
-- batch_no 没有权威来源时保持 NULL，不能编造。
-- =====================================================================
CREATE TEMP TABLE tmp_manual_project_source ON COMMIT PRESERVE ROWS AS
SELECT
    btrim(m.lshsxm_xmbh)::varchar(128) AS project_code,
    btrim(m.lshsxm_xmmc)::varchar(255) AS project_name,
    btrim(m.lshsxm_xmnm)::varchar(128) AS model_node_code,
    NULLIF(btrim(d.xmsx), '')::varchar(128) AS domain_code,
    btrim(d.lshsxm_xmmc)::varchar(255) AS domain_name,
    btrim(s.lshsxm_xmnm)::varchar(128) AS category_code,
    btrim(s.lshsxm_xmmc)::varchar(255) AS category_name,
    btrim(m.lshsxm_xmnm)::varchar(128) AS model_code,
    btrim(m.lshsxm_xmmc)::varchar(255) AS model_name,
    NULL::varchar(128) AS batch_no,
    CASE
        WHEN lower(btrim(COALESCE(m.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
        THEN 1 ELSE 0
    END::int2 AS deleted
FROM cost_integration.ads_lc_lshsxm2022 m
JOIN cost_integration.ads_lc_lshsxm2022 s
  ON s.lshsxm_xmnm = m.parent_xmnm
JOIN cost_integration.ads_lc_lshsxm2022 d
  ON d.lshsxm_xmnm = s.parent_xmnm
WHERE btrim(m.lshsxm_js) = '3';
-- =========================【现场字段映射区结束】=========================

DO $$
DECLARE
    v_tenant_id int8 := (SELECT tenant_id FROM tmp_manual_context);
BEGIN
    IF EXISTS (
        SELECT 1 FROM tmp_manual_project_source
        WHERE project_code IS NULL OR btrim(project_code) = ''
           OR project_name IS NULL OR btrim(project_name) = ''
           OR model_node_code IS NULL OR btrim(model_node_code) = ''
    ) THEN
        RAISE EXCEPTION '项目映射存在空主业项目编号、名称或型号节点编码';
    END IF;

    IF EXISTS (
        SELECT project_code FROM tmp_manual_project_source
        GROUP BY project_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '项目映射存在重复 project_code';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_manual_project_source s
        WHERE NOT EXISTS (
            SELECT 1 FROM cost_model_node n
            WHERE n.tenant_id = v_tenant_id
              AND n.deleted = 0
              AND n.node_code = s.model_node_code
              AND n.node_type = 'MODEL'
        )
    ) THEN
        RAISE EXCEPTION '项目映射存在找不到 MODEL 型号节点的记录';
    END IF;

    IF EXISTS (
        SELECT project_code
        FROM cost_project
        WHERE tenant_id = v_tenant_id AND deleted = 0
          AND project_code IN (SELECT project_code FROM tmp_manual_project_source)
        GROUP BY project_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '目标表本批 project_code 已存在重复记录';
    END IF;
END $$;

-- 只更新项目身份和树归属；不重置填报、审核状态及用户维护字段。
UPDATE cost_project p
SET project_name = s.project_name,
    model_node_id = (
        SELECT min(n.id) FROM cost_model_node n
        WHERE n.tenant_id = c.tenant_id AND n.node_code = s.model_node_code
    ),
    domain_code = s.domain_code,
    domain_name = s.domain_name,
    category_code = s.category_code,
    category_name = s.category_name,
    model_code = s.model_code,
    model_name = s.model_name,
    batch_no = COALESCE(s.batch_no, p.batch_no),
    deleted = s.deleted,
    remark = '内网主业项目分表同步',
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_manual_project_source s
CROSS JOIN tmp_manual_context c
WHERE p.tenant_id = c.tenant_id
  AND p.project_code = s.project_code;

INSERT INTO cost_project (
    project_code, project_name, model_node_id,
    domain_code, domain_name, category_code, category_name,
    model_code, model_name, batch_no,
    project_office_status, unit_fill_status, audit_status,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT
    s.project_code, s.project_name,
    (SELECT min(n.id) FROM cost_model_node n
     WHERE n.tenant_id = c.tenant_id AND n.node_code = s.model_node_code),
    s.domain_code, s.domain_name, s.category_code, s.category_name,
    s.model_code, s.model_name, s.batch_no,
    'NOT_FILLED', 'NOT_FILLED', 'DRAFT',
    '内网主业项目分表同步', c.source_tag, CURRENT_TIMESTAMP,
    c.source_tag, CURRENT_TIMESTAMP, s.deleted, c.tenant_id
FROM tmp_manual_project_source s
CROSS JOIN tmp_manual_context c
WHERE NOT EXISTS (
    SELECT 1 FROM cost_project p
    WHERE p.tenant_id = c.tenant_id
      AND p.project_code = s.project_code
);

COMMIT;

-- 验收结果 1：应为 0。
SELECT count(*) AS project_without_model_node_count
FROM cost_project p
CROSS JOIN tmp_manual_context c
WHERE p.tenant_id = c.tenant_id
  AND p.deleted = 0
  AND (p.model_node_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM cost_model_node n
      WHERE n.id = p.model_node_id AND n.deleted = 0 AND n.node_type = 'MODEL'
  ));

-- 验收结果 2：本次源项目数和目标有效项目数。
SELECT
    (SELECT count(*) FROM tmp_manual_project_source WHERE deleted = 0) AS source_project_count,
    (SELECT count(*) FROM cost_project p CROSS JOIN tmp_manual_context c
     WHERE p.tenant_id = c.tenant_id AND p.deleted = 0
       AND p.project_code IN (SELECT project_code FROM tmp_manual_project_source)) AS target_project_count;

