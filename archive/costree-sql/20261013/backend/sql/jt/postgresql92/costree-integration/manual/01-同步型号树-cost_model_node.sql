-- 成本库内网分表同步 01：型号树 cost_model_node
-- 报错后先执行 ROLLBACK;，再修正顶部字段映射区并完整重跑。

BEGIN;
SELECT pg_advisory_xact_lock(hashtext('costree-manual-model-node-sync'));

DROP TABLE IF EXISTS tmp_manual_context;
CREATE TEMP TABLE tmp_manual_context ON COMMIT PRESERVE ROWS AS
SELECT 124::int8 AS tenant_id, 'manual_tree_sync'::varchar(64) AS source_tag;

DROP TABLE IF EXISTS tmp_manual_node_source;

-- =====================================================================
-- 【现场只修改本段】把内网主业项目树整理成以下固定输出列。
-- node_code 必须稳定唯一；parent_node_code 是父节点的 node_code。
-- 内网原树不是三级时，可保留现有 substring/权限/资金筛选逻辑，
-- 但最终必须输出 DOMAIN、SERIES、MODEL 三类成本库展示节点。
-- =====================================================================
CREATE TEMP TABLE tmp_manual_node_source ON COMMIT PRESERVE ROWS AS
SELECT
    btrim(s.lshsxm_xmnm)::varchar(128) AS node_code,
    btrim(s.lshsxm_xmmc)::varchar(255) AS node_name,
    NULLIF(btrim(s.parent_xmnm), '')::varchar(128) AS parent_node_code,
    CASE btrim(s.lshsxm_js)
        WHEN '1' THEN 'DOMAIN'
        WHEN '2' THEN 'SERIES'
        WHEN '3' THEN 'MODEL'
    END::varchar(32) AS node_type,
    NULLIF(btrim(s.xmsx), '')::varchar(128) AS domain_code,
    CASE btrim(s.lshsxm_js) WHEN '1' THEN 100 ELSE 10 END::int4 AS sort_no,
    CASE
        WHEN lower(btrim(COALESCE(s.disabled, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
        THEN 'DISABLE' ELSE 'ENABLE'
    END::varchar(32) AS status,
    CASE
        WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
        THEN 1 ELSE 0
    END::int2 AS deleted
FROM cost_integration.ads_lc_lshsxm2022 s;
-- =========================【现场字段映射区结束】=========================

DO $$
DECLARE
    v_tenant_id int8 := (SELECT tenant_id FROM tmp_manual_context);
BEGIN
    IF EXISTS (
        SELECT 1 FROM tmp_manual_node_source
        WHERE node_code IS NULL OR btrim(node_code) = ''
           OR node_name IS NULL OR btrim(node_name) = ''
           OR node_type IS NULL
    ) THEN
        RAISE EXCEPTION '型号树映射存在空节点编码、名称或无法识别的节点类型';
    END IF;

    IF EXISTS (
        SELECT node_code FROM tmp_manual_node_source
        GROUP BY node_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '型号树映射存在重复 node_code';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_manual_node_source
        WHERE node_type NOT IN ('DOMAIN', 'SERIES', 'MODEL')
    ) THEN
        RAISE EXCEPTION 'node_type 只允许 DOMAIN/SERIES/MODEL';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_manual_node_source s
        WHERE s.node_type <> 'DOMAIN'
          AND (s.parent_node_code IS NULL OR NOT EXISTS (
              SELECT 1 FROM tmp_manual_node_source p
              WHERE p.node_code = s.parent_node_code
          ))
    ) THEN
        RAISE EXCEPTION '型号树存在非领域节点找不到父节点';
    END IF;

    IF EXISTS (
        SELECT node_code
        FROM cost_model_node
        WHERE tenant_id = v_tenant_id AND deleted = 0
          AND node_code IN (SELECT node_code FROM tmp_manual_node_source)
        GROUP BY node_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '目标表本批 node_code 已存在重复记录';
    END IF;
END $$;

UPDATE cost_model_node n
SET node_name = s.node_name,
    node_type = s.node_type,
    domain_code = s.domain_code,
    sort = s.sort_no,
    status = s.status,
    deleted = s.deleted,
    remark = '内网主业项目树分表同步',
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_manual_node_source s
CROSS JOIN tmp_manual_context c
WHERE n.tenant_id = c.tenant_id
  AND n.node_code = s.node_code;

INSERT INTO cost_model_node (
    parent_id, node_code, node_name, node_type, domain_code, sort, status,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT
    0, s.node_code, s.node_name, s.node_type, s.domain_code, s.sort_no, s.status,
    '内网主业项目树分表同步', c.source_tag, CURRENT_TIMESTAMP,
    c.source_tag, CURRENT_TIMESTAMP, s.deleted, c.tenant_id
FROM tmp_manual_node_source s
CROSS JOIN tmp_manual_context c
WHERE NOT EXISTS (
    SELECT 1 FROM cost_model_node n
    WHERE n.tenant_id = c.tenant_id AND n.node_code = s.node_code
);

-- 所有节点获得 ID 后统一回填 parent_id，不依赖源树插入顺序。
UPDATE cost_model_node n
SET parent_id = CASE
        WHEN s.node_type = 'DOMAIN' THEN 0
        ELSE (
            SELECT min(p.id)
            FROM cost_model_node p
            WHERE p.tenant_id = c.tenant_id
              AND p.node_code = s.parent_node_code
        )
    END,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_manual_node_source s
CROSS JOIN tmp_manual_context c
WHERE n.tenant_id = c.tenant_id
  AND n.node_code = s.node_code;

COMMIT;

-- 验收结果 1：应为 0。
SELECT count(*) AS node_without_parent_count
FROM cost_model_node n
CROSS JOIN tmp_manual_context c
WHERE n.tenant_id = c.tenant_id
  AND n.deleted = 0
  AND n.node_type <> 'DOMAIN'
  AND (n.parent_id IS NULL OR n.parent_id = 0);

-- 验收结果 2：核对各类型数量。
SELECT node_type, count(*) AS node_count
FROM cost_model_node n
CROSS JOIN tmp_manual_context c
WHERE n.tenant_id = c.tenant_id AND n.deleted = 0
GROUP BY node_type
ORDER BY node_type;

