-- 全量快照导入前检查。任何异常都会中止，不修改业务表。
-- 现场需把业务 schema costree_mvp 和租户 124 调整为实际值。

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
          'cost_work_order_ledger_detail'
      );
    IF v_table_count <> 6 THEN
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
    ) THEN
        RAISE EXCEPTION '业务表不是当前版本，缺少管理单位、溯源、到款或万元金额字段';
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

SELECT 'precheck passed' AS result,
       tenant_id, batch_code, source_tag, load_status, loaded_at
FROM cost_sync_stage.sync_control
WHERE id = 1;
