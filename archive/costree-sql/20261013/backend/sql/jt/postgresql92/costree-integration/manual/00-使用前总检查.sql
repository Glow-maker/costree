-- 成本库内网分表同步：使用前总检查
-- 本脚本只读，不修改任何数据。

-- 结果 1：确认数据库版本。
SELECT version() AS database_version,
       current_database() AS database_name,
       current_user AS database_user;

-- 结果 2：下列结果必须为空；否则先执行当前版本建表或升级脚本。
SELECT required.table_name AS missing_table
FROM (
    VALUES ('cost_model_node'), ('cost_project'), ('cost_project_basic'),
           ('cost_unit_dict'), ('cost_unit_cost_detail'), ('cost_work_order'),
           ('cost_work_order_ledger_detail')
) required(table_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM information_schema.tables t
    WHERE t.table_schema = 'public'
      AND t.table_name = required.table_name
);

-- 结果 3：下列结果必须为空；它检查最近新增且同步依赖的字段。
SELECT required.table_name, required.column_name
FROM (
    VALUES
      ('cost_unit_dict', 'manage_unit_group'),
      ('cost_unit_cost_detail', 'source_record_id'),
      ('cost_unit_cost_detail', 'source_update_time'),
      ('cost_work_order', 'source_work_order_id'),
      ('cost_work_order', 'income_amount'),
      ('cost_work_order', 'quantity'),
      ('cost_work_order', 'product_short_name'),
      ('cost_work_order_ledger_detail', 'source_detail_id'),
      ('cost_work_order_ledger_detail', 'source_work_order_id'),
      ('cost_work_order_ledger_detail', 'second_subject_code'),
      ('cost_work_order_ledger_detail', 'resolved_stage_code')
) required(table_name, column_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = required.table_name
      AND c.column_name = required.column_name
);

-- 结果 4：目标表业务键重复检查，所有 duplicate_count 必须为 0。
SELECT 'cost_model_node: tenant + node_code' AS check_item, count(*) AS duplicate_count
FROM (
    SELECT tenant_id, node_code
    FROM cost_model_node
    WHERE deleted = 0
    GROUP BY tenant_id, node_code
    HAVING count(*) > 1
) x
UNION ALL
SELECT 'cost_project: tenant + project_code', count(*)
FROM (
    SELECT tenant_id, project_code
    FROM cost_project
    WHERE deleted = 0
    GROUP BY tenant_id, project_code
    HAVING count(*) > 1
) x
UNION ALL
SELECT 'cost_unit_cost_detail: tenant + project + actual unit', count(*)
FROM (
    SELECT tenant_id, project_code, unit_name
    FROM cost_unit_cost_detail
    WHERE deleted = 0
    GROUP BY tenant_id, project_code, unit_name
    HAVING count(*) > 1
) x
UNION ALL
SELECT 'cost_work_order: tenant + project + actual unit + work order', count(*)
FROM (
    SELECT tenant_id, project_code, unit_name, work_order_no
    FROM cost_work_order
    WHERE deleted = 0
    GROUP BY tenant_id, project_code, unit_name, work_order_no
    HAVING count(*) > 1
) x
UNION ALL
SELECT 'ledger: tenant + source_detail_id', count(*)
FROM (
    SELECT tenant_id, source_detail_id
    FROM cost_work_order_ledger_detail
    WHERE deleted = 0
    GROUP BY tenant_id, source_detail_id
    HAVING count(*) > 1
) x;

-- 结果 5：当前业务表规模，仅用于备份和执行前后对比。
SELECT 'cost_model_node' AS table_name, count(*) AS row_count FROM cost_model_node
UNION ALL SELECT 'cost_project', count(*) FROM cost_project
UNION ALL SELECT 'cost_project_basic', count(*) FROM cost_project_basic
UNION ALL SELECT 'cost_unit_dict', count(*) FROM cost_unit_dict
UNION ALL SELECT 'cost_unit_cost_detail', count(*) FROM cost_unit_cost_detail
UNION ALL SELECT 'cost_work_order', count(*) FROM cost_work_order
UNION ALL SELECT 'cost_work_order_ledger_detail', count(*) FROM cost_work_order_ledger_detail;

-- 结果 6：已有单位字典中关键字段缺失情况。
SELECT
    sum(CASE WHEN accounting_unit_id IS NULL OR btrim(accounting_unit_id) = '' THEN 1 ELSE 0 END) AS missing_accounting_unit_id,
    sum(CASE WHEN accounting_unit_code IS NULL OR btrim(accounting_unit_code) = '' THEN 1 ELSE 0 END) AS missing_accounting_unit_code,
    sum(CASE WHEN accounting_unit_name IS NULL OR btrim(accounting_unit_name) = '' THEN 1 ELSE 0 END) AS missing_accounting_unit_name,
    sum(CASE WHEN manage_unit_name IS NULL OR btrim(manage_unit_name) = '' THEN 1 ELSE 0 END) AS missing_manage_unit_name,
    sum(CASE WHEN manage_unit_group IS NULL OR btrim(manage_unit_group) = '' THEN 1 ELSE 0 END) AS missing_manage_unit_group
FROM cost_unit_dict
WHERE deleted = 0;

-- 结果 7：标准暂存层源表记录数。现场直连业务源表时，把实际源表记录数另行留档。
DROP TABLE IF EXISTS tmp_manual_source_counts;
CREATE TEMP TABLE tmp_manual_source_counts (
    source_table varchar(128),
    row_count int8,
    note varchar(255)
) ON COMMIT PRESERVE ROWS;

DO $$
DECLARE
    r record;
    v_count int8;
BEGIN
    FOR r IN
        SELECT source_table
        FROM (
            VALUES
              ('unit_dict'),
              ('ads_lc_lshsxm2022'),
              ('dwd_bd_bfcustomitem_gzl'),
              ('precontrol_project_unit_amount'),
              ('dws_bu_pz_pzmx_gzl')
        ) x(source_table)
    LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.tables t
            WHERE t.table_schema = 'cost_integration'
              AND t.table_name = r.source_table
        ) THEN
            EXECUTE 'SELECT count(*) FROM cost_integration.' || quote_ident(r.source_table)
                INTO v_count;
            INSERT INTO tmp_manual_source_counts VALUES
                (r.source_table, v_count, '标准暂存表');
        ELSE
            INSERT INTO tmp_manual_source_counts VALUES
                (r.source_table, NULL, '未创建；若直连内网业务源表可忽略');
        END IF;
    END LOOP;
END $$;

SELECT source_table, row_count, note
FROM tmp_manual_source_counts
ORDER BY source_table;

-- 关键字段空值不在 00 中猜测内网列名，由 01-06 的固定校验逐表阻断。
