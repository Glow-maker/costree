-- 全量快照导入前检查。任何异常都会中止，不修改业务表。
-- 现场需把业务 schema costree_mvp 和租户 124 调整为实际值。

BEGIN;

DO $$
DECLARE
    v_tenant_id int8;
    v_table_count int4;
BEGIN
    SELECT tenant_id INTO v_tenant_id
    FROM cost_sync_stage.sync_control
    WHERE id = 1;

    IF v_tenant_id IS NULL THEN
        RAISE EXCEPTION 'cost_sync_stage.sync_control 未初始化';
    END IF;

    IF (SELECT load_status FROM cost_sync_stage.sync_control WHERE id = 1) <> 'READY' THEN
        RAISE EXCEPTION '中间表尚未完成全量装载，load_status 必须为 READY';
    END IF;

    SELECT count(*) INTO v_table_count
    FROM information_schema.tables
    WHERE table_schema = 'costree_mvp'
      AND table_name IN (
          'cost_unit_dict', 'cost_model_node', 'cost_project',
          'cost_unit_cost_detail', 'cost_work_order',
          'cost_work_order_ledger_detail', 'cost_project_basic',
          'cost_warning_record', 'cost_subsystem_dict'
      );
    IF v_table_count <> 9 THEN
        RAISE EXCEPTION '成本库业务 schema costree_mvp 缺少必要业务表，请先执行当前完整 DDL/升级脚本';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'costree_mvp' AND table_name = 'cost_unit_dict'
          AND column_name = 'manage_unit_group'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'costree_mvp' AND table_name = 'cost_unit_cost_detail'
          AND column_name = 'source_record_id'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'costree_mvp' AND table_name = 'cost_work_order'
          AND column_name = 'income_amount'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'costree_mvp' AND table_name = 'cost_work_order_ledger_detail'
          AND column_name = 'amount_wan'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'costree_mvp' AND table_name = 'cost_project_basic'
          AND column_name = 'stage_code' AND character_maximum_length >= 255
    ) OR EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'costree_mvp' AND table_name = 'cost_work_order'
          AND column_name = 'vertical_division' AND column_default IS NOT NULL
    ) THEN
        RAISE EXCEPTION '业务表不是 20260819 结构，缺少字段、阶段长度不足或纵向分工仍有默认值';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM cost_sync_stage.stg_model_node)
       OR NOT EXISTS (SELECT 1 FROM cost_sync_stage.stg_project) THEN
        RAISE EXCEPTION '型号树或项目全量快照为空，拒绝同步';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage.stg_unit_dict
        WHERE accounting_unit_code IS NULL OR btrim(accounting_unit_code) = ''
           OR accounting_unit_name IS NULL OR btrim(accounting_unit_name) = ''
    ) THEN
        RAISE EXCEPTION '单位中间表存在空核算单位编码或名称';
    END IF;
    IF EXISTS (
        SELECT accounting_unit_code FROM cost_sync_stage.stg_unit_dict
        GROUP BY accounting_unit_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '单位中间表存在重复核算单位编码';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage.stg_model_node
        WHERE node_code IS NULL OR btrim(node_code) = ''
           OR node_name IS NULL OR btrim(node_name) = ''
           OR node_type NOT IN ('DOMAIN', 'SERIES', 'MODEL')
    ) THEN
        RAISE EXCEPTION '型号树存在空编码、空名称或非法 node_type';
    END IF;
    IF EXISTS (
        SELECT node_code FROM cost_sync_stage.stg_model_node
        GROUP BY node_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '型号树中间表存在重复 node_code';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM cost_sync_stage.stg_model_node n
        WHERE n.node_type <> 'DOMAIN'
          AND lower(btrim(COALESCE(n.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND (
              n.parent_node_code IS NULL OR btrim(n.parent_node_code) = ''
              OR NOT EXISTS (
                  SELECT 1 FROM cost_sync_stage.stg_model_node p
                  WHERE p.node_code = n.parent_node_code
                    AND lower(btrim(COALESCE(p.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
              )
          )
    ) THEN
        RAISE EXCEPTION '型号树存在活动子节点找不到活动父节点';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage.stg_project
        WHERE project_code IS NULL OR btrim(project_code) = ''
           OR project_name IS NULL OR btrim(project_name) = ''
           OR model_node_code IS NULL OR btrim(model_node_code) = ''
    ) THEN
        RAISE EXCEPTION '项目中间表存在空项目编号、名称或型号节点编码';
    END IF;
    IF EXISTS (
        SELECT project_code FROM cost_sync_stage.stg_project
        GROUP BY project_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '项目中间表存在重复项目编号';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM cost_sync_stage.stg_project p
        WHERE lower(btrim(COALESCE(p.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND NOT EXISTS (
              SELECT 1 FROM cost_sync_stage.stg_model_node n
              WHERE n.node_code = p.model_node_code AND n.node_type = 'MODEL'
                AND lower(btrim(COALESCE(n.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          )
    ) THEN
        RAISE EXCEPTION '活动项目无法匹配活动 MODEL 节点';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage.stg_unit_amount
        WHERE project_code IS NULL OR btrim(project_code) = ''
           OR accounting_unit_code IS NULL OR btrim(accounting_unit_code) = ''
           OR (contract_amount_wan IS NOT NULL AND btrim(contract_amount_wan) <> ''
               AND btrim(contract_amount_wan) !~ '^[+-]?[0-9]+([.][0-9]+)?$')
           OR (income_amount_wan IS NOT NULL AND btrim(income_amount_wan) <> ''
               AND btrim(income_amount_wan) !~ '^[+-]?[0-9]+([.][0-9]+)?$')
    ) THEN
        RAISE EXCEPTION '单位金额存在空业务键或无法转换的合同/到款金额';
    END IF;
    IF EXISTS (
        SELECT project_code, accounting_unit_code
        FROM cost_sync_stage.stg_unit_amount
        GROUP BY project_code, accounting_unit_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '单位金额中间表存在重复的项目 + 核算单位';
    END IF;
    IF EXISTS (
        SELECT 1 FROM cost_sync_stage.stg_unit_amount a
        WHERE lower(btrim(COALESCE(a.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND (
              NOT EXISTS (SELECT 1 FROM cost_sync_stage.stg_project p WHERE p.project_code = a.project_code)
              OR NOT EXISTS (SELECT 1 FROM cost_sync_stage.stg_unit_dict u WHERE u.accounting_unit_code = a.accounting_unit_code)
          )
    ) THEN
        RAISE EXCEPTION '活动单位金额无法匹配本批项目或单位字典';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage.stg_work_order
        WHERE project_code IS NULL OR btrim(project_code) = ''
           OR accounting_unit_code IS NULL OR btrim(accounting_unit_code) = ''
           OR work_order_no IS NULL OR btrim(work_order_no) = ''
    ) THEN
        RAISE EXCEPTION '工作令存在空项目、核算单位编码或工作令编号';
    END IF;
    IF EXISTS (
        SELECT project_code, accounting_unit_code, work_order_no
        FROM cost_sync_stage.stg_work_order
        GROUP BY project_code, accounting_unit_code, work_order_no HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '工作令中间表存在重复业务键';
    END IF;
    IF EXISTS (
        SELECT 1 FROM cost_sync_stage.stg_work_order w
        WHERE lower(btrim(COALESCE(w.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND (
              NOT EXISTS (SELECT 1 FROM cost_sync_stage.stg_project p WHERE p.project_code = w.project_code)
              OR NOT EXISTS (SELECT 1 FROM cost_sync_stage.stg_unit_dict u WHERE u.accounting_unit_code = w.accounting_unit_code)
          )
    ) THEN
        RAISE EXCEPTION '活动工作令无法匹配本批项目或单位字典';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage.stg_ledger_detail
        WHERE source_detail_id IS NULL OR btrim(source_detail_id) = ''
           OR project_code IS NULL OR btrim(project_code) = ''
           OR accounting_unit_code IS NULL OR btrim(accounting_unit_code) = ''
           OR work_order_no IS NULL OR btrim(work_order_no) = ''
           OR amount_yuan IS NULL OR btrim(amount_yuan) = ''
           OR btrim(amount_yuan) !~ '^[+-]?[0-9]+([.][0-9]+)?$'
           OR upper(btrim(debit_credit)) NOT IN ('借', '贷', 'DEBIT', 'CREDIT', 'D', 'C')
    ) THEN
        RAISE EXCEPTION '账面明细存在空业务键、非法金额或非法借贷方向';
    END IF;
    IF EXISTS (
        SELECT source_detail_id FROM cost_sync_stage.stg_ledger_detail
        GROUP BY source_detail_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '账面中间表 source_detail_id 不唯一';
    END IF;
    IF EXISTS (
        SELECT 1 FROM cost_sync_stage.stg_ledger_detail d
        WHERE lower(btrim(COALESCE(d.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND NOT EXISTS (
              SELECT 1 FROM cost_sync_stage.stg_work_order w
              WHERE w.project_code = d.project_code
                AND w.accounting_unit_code = d.accounting_unit_code
                AND w.work_order_no = d.work_order_no
          )
    ) THEN
        RAISE EXCEPTION '活动账面明细无法按项目 + 实际单位 + 工作令编号匹配本批工作令';
    END IF;

    IF EXISTS (
        SELECT node_code FROM "costree_mvp".cost_model_node
        WHERE tenant_id = v_tenant_id GROUP BY node_code HAVING count(*) > 1
    ) OR EXISTS (
        SELECT project_code FROM "costree_mvp".cost_project
        WHERE tenant_id = v_tenant_id GROUP BY project_code HAVING count(*) > 1
    ) OR EXISTS (
        SELECT accounting_unit_code FROM "costree_mvp".cost_unit_dict
        WHERE tenant_id = v_tenant_id GROUP BY accounting_unit_code HAVING count(*) > 1
    ) OR EXISTS (
        SELECT project_code, unit_name FROM "costree_mvp".cost_unit_cost_detail
        WHERE tenant_id = v_tenant_id GROUP BY project_code, unit_name HAVING count(*) > 1
    ) OR EXISTS (
        SELECT project_code, unit_name, work_order_no FROM "costree_mvp".cost_work_order
        WHERE tenant_id = v_tenant_id GROUP BY project_code, unit_name, work_order_no HAVING count(*) > 1
    ) OR EXISTS (
        SELECT source_detail_id FROM "costree_mvp".cost_work_order_ledger_detail
        WHERE tenant_id = v_tenant_id GROUP BY source_detail_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '成本库目标表已存在重复业务键，请先清理重复记录再同步';
    END IF;
END $$;

DELETE FROM cost_sync_stage.manual_field_digest digest
USING cost_sync_stage.sync_control control
WHERE control.id = 1
  AND digest.batch_code = control.batch_code
  AND digest.tenant_id = control.tenant_id;

DELETE FROM cost_sync_stage.manual_field_baseline baseline
USING cost_sync_stage.sync_control control
WHERE control.id = 1
  AND baseline.batch_code = control.batch_code
  AND baseline.tenant_id = control.tenant_id;

INSERT INTO cost_sync_stage.manual_field_baseline
    (batch_code, tenant_id, object_name, record_id, digest_value, captured_at)
SELECT control.batch_code, control.tenant_id, 'project_basic', basic.id,
       md5(ROW(
           basic.id, basic.project_id, basic.project_code, basic.project_name,
           basic.product_attachment_type, basic.subsystem_name, basic.quantity,
           basic.product_short_name, basic.vertical_division, basic.user_name,
           basic.acquire_method, basic.batch_category, basic.platform_series,
           basic.research_unit_id, basic.research_unit_name, basic.target_price,
           basic.competitor_unit_1, basic.competitor_price_1,
           basic.competitor_unit_2, basic.competitor_price_2,
           basic.contract_amount, basic.tax_exempt, basic.target_cost_amount,
           basic.approved_amount, basic.cycle_start, basic.cycle_end,
           basic.stage_code, basic.basic_info, basic.status, basic.remark,
           basic.import_batch_id, basic.dept_id, basic.owner_user_id,
           basic.creator, basic.create_time, basic.updater, basic.update_time, basic.deleted
       )::text), CURRENT_TIMESTAMP
FROM cost_sync_stage.sync_control control
JOIN "costree_mvp".cost_project_basic basic ON basic.tenant_id = control.tenant_id
WHERE control.id = 1
UNION ALL
SELECT control.batch_code, control.tenant_id, 'project_state', project.id,
       md5(ROW(
           project.id, project.project_code, project.batch_no, project.stage_codes,
           project.unit_id, project.unit_name, project.unit_type,
           project.project_office_status, project.unit_fill_status, project.audit_status,
           project.dept_id, project.owner_user_id, project.warning_status,
           project.remark
       )::text), CURRENT_TIMESTAMP
FROM cost_sync_stage.sync_control control
JOIN "costree_mvp".cost_project project ON project.tenant_id = control.tenant_id
WHERE control.id = 1
UNION ALL
SELECT control.batch_code, control.tenant_id, 'unit_fill', unit_cost.id,
       md5(ROW(
           unit_cost.id,
           unit_cost.target_cost_amount, unit_cost.approved_amount,
           unit_cost.salary_amount, unit_cost.material_amount, unit_cost.outsource_amount,
           unit_cost.manage_amount, unit_cost.fuel_power_amount, unit_cost.other_amount,
           unit_cost.remark, unit_cost.deleted
       )::text), CURRENT_TIMESTAMP
FROM cost_sync_stage.sync_control control
JOIN "costree_mvp".cost_unit_cost_detail unit_cost ON unit_cost.tenant_id = control.tenant_id
WHERE control.id = 1
UNION ALL
SELECT control.batch_code, control.tenant_id, 'work_order_fill', work_order.id,
       md5(ROW(
           work_order.id, work_order.product_target_cost,
           work_order.contract_amount, work_order.income_amount, work_order.approved_amount,
           work_order.stage_codes, work_order.max_stage_code, work_order.subsystem_name,
           work_order.product_short_name, work_order.quantity, work_order.vertical_division,
           work_order.status, work_order.remark, work_order.import_batch_id,
           work_order.dept_id, work_order.owner_user_id, work_order.deleted
       )::text), CURRENT_TIMESTAMP
FROM cost_sync_stage.sync_control control
JOIN "costree_mvp".cost_work_order work_order ON work_order.tenant_id = control.tenant_id
WHERE control.id = 1
UNION ALL
SELECT control.batch_code, control.tenant_id, 'warning_state', warning.id,
       md5(ROW(
           warning.id, warning.project_id, warning.work_order_id, warning.warning_source,
           warning.warning_title, warning.target_cost_amount, warning.actual_cost_amount,
           warning.over_amount, warning.over_rate, warning.threshold_rate,
           warning.warning_level, warning.responsible_unit_name, warning.push_status,
           warning.pushed_time, warning.receiver_scope, warning.message_id,
           warning.status, warning.remark, warning.creator, warning.create_time,
           warning.updater, warning.update_time, warning.deleted
       )::text), CURRENT_TIMESTAMP
FROM cost_sync_stage.sync_control control
JOIN "costree_mvp".cost_warning_record warning ON warning.tenant_id = control.tenant_id
WHERE control.id = 1;

INSERT INTO cost_sync_stage.manual_field_digest
    (batch_code, tenant_id, object_name, row_count, digest_value, captured_at)
SELECT control.batch_code, control.tenant_id, object_type.object_name,
       count(baseline.record_id)::int8,
       md5(COALESCE(string_agg(baseline.digest_value, '' ORDER BY baseline.record_id), 'EMPTY')),
       CURRENT_TIMESTAMP
FROM cost_sync_stage.sync_control control
CROSS JOIN (
    SELECT 'project_basic'::varchar(64) AS object_name
    UNION ALL SELECT 'project_state'::varchar(64)
    UNION ALL SELECT 'unit_fill'::varchar(64)
    UNION ALL SELECT 'work_order_fill'::varchar(64)
    UNION ALL SELECT 'warning_state'::varchar(64)
) object_type
LEFT JOIN cost_sync_stage.manual_field_baseline baseline
  ON baseline.batch_code = control.batch_code
 AND baseline.tenant_id = control.tenant_id
 AND baseline.object_name = object_type.object_name
WHERE control.id = 1
GROUP BY control.batch_code, control.tenant_id, object_type.object_name;

COMMIT;

SELECT 'precheck passed' AS result,
       tenant_id, batch_code, source_tag, load_status, loaded_at
FROM cost_sync_stage.sync_control
WHERE id = 1;
