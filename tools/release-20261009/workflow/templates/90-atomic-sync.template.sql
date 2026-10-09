-- FINAL NODE: one connection, one transaction. No cross-node transaction assumption.
BEGIN;
SET LOCAL statement_timeout='15min';
LOCK TABLE cost_sync_stage_v20261009.sync_control IN EXCLUSIVE MODE;
DO $$
BEGIN
  IF '__BATCH_CODE__' LIKE 'REPLACE%' THEN RAISE EXCEPTION '必须生成本批参数'; END IF;
  IF NOT EXISTS (SELECT 1 FROM cost_sync_stage_v20261009.sync_control
      WHERE id=1 AND tenant_id=__TENANT_ID__ AND batch_code='__BATCH_CODE__'
        AND load_status='LOADING') THEN
    RAISE EXCEPTION '批次不一致或不是 LOADING；停止，不能串批';
  END IF;
END $$;

LOCK TABLE cost_sync_stage_v20261009.stg_unit_dict,cost_sync_stage_v20261009.stg_model_node,
 cost_sync_stage_v20261009.stg_project,cost_sync_stage_v20261009.stg_unit_amount,
 cost_sync_stage_v20261009.stg_work_order,cost_sync_stage_v20261009.stg_ledger_detail IN SHARE MODE;
DO $$ BEGIN
 IF (SELECT count(*) FROM cost_sync_stage_v20261009.load_receipt
     WHERE batch_code='__BATCH_CODE__' AND snapshot_tag='__SNAPSHOT_TAG__'
       AND row_count=expected_rows AND stage_table IN
       ('stg_unit_dict','stg_model_node','stg_project','stg_unit_amount','stg_work_order','stg_ledger_detail')) <> 6 THEN
   RAISE EXCEPTION '六个源尚未完整装载，本批禁止更新、禁止重算';
 END IF;
END $$;
LOCK TABLE "costree_mvp".cost_unit_dict,"costree_mvp".cost_model_node,
 "costree_mvp".cost_project,"costree_mvp".cost_unit_cost_detail,
 "costree_mvp".cost_work_order,"costree_mvp".cost_work_order_ledger_detail,
 "costree_mvp".cost_project_basic,"costree_mvp".cost_warning_record,
 "costree_mvp".cost_subsystem_dict IN SHARE ROW EXCLUSIVE MODE;
-- Existing keys/IDs are never rewritten. These locks also prevent a concurrent manual save
-- between baseline capture and validation. Readers continue; writers wait until commit.
UPDATE cost_sync_stage_v20261009.sync_control SET load_status='READY',loaded_at=CURRENT_TIMESTAMP WHERE id=1;
-- Additional safety checks before any business write.
DO $$
DECLARE r record; v_sql text; v_bad boolean; v_seq text; v_next numeric;
 v_max numeric; v_increment bigint; v_cycle boolean; v_limit numeric; v_last numeric;
BEGIN
 FOR r IN SELECT * FROM (VALUES
 ('stg_unit_dict','accounting_unit_code'),('stg_model_node','node_code'),
 ('stg_project','project_code'),('stg_unit_amount','source_record_id'),
 ('stg_work_order','source_work_order_id'),('stg_ledger_detail','source_detail_id')) AS x(tbl,keycol)
 LOOP
   EXECUTE 'SELECT EXISTS(SELECT 1 FROM cost_sync_stage_v20261009.'||quote_ident(r.tbl)||
     ' WHERE '||quote_ident(r.keycol)||' IS NULL OR btrim('||quote_ident(r.keycol)||')='''')'
     INTO v_bad;
   IF v_bad THEN RAISE EXCEPTION '缺少稳定源业务键 %.%',r.tbl,r.keycol; END IF;
   EXECUTE 'SELECT EXISTS(SELECT 1 FROM cost_sync_stage_v20261009.'||quote_ident(r.tbl)||
     ' GROUP BY btrim('||quote_ident(r.keycol)||') HAVING count(*)>1)' INTO v_bad;
   IF v_bad THEN RAISE EXCEPTION '规范化后稳定源键重复 %.%',r.tbl,r.keycol; END IF;
   EXECUTE 'SELECT EXISTS(SELECT 1 FROM cost_sync_stage_v20261009.'||quote_ident(r.tbl)||
     ' WHERE NULLIF(btrim(source_deleted),'''') IS NOT NULL AND lower(btrim(source_deleted)) NOT IN (''0'',''false'',''f'',''否'',''no'',''n''))' INTO v_bad;
   IF v_bad THEN RAISE EXCEPTION '源删除语义尚未批准或标志非法：% 本批停止，不能自动删/停业务数据',r.tbl; END IF;
 END LOOP;
 -- No implicit truncation of long external identifiers to varchar(128).
 FOR r IN SELECT table_name,column_name FROM information_schema.columns
    WHERE table_schema='cost_sync_stage_v20261009' AND table_name LIKE 'stg_%'
      AND (column_name LIKE '%code' OR column_name LIKE '%_id' OR column_name='work_order_no')
 LOOP
   EXECUTE 'SELECT EXISTS(SELECT 1 FROM cost_sync_stage_v20261009.'||quote_ident(r.table_name)||
    ' WHERE length(btrim('||quote_ident(r.column_name)||'))>128)' INTO v_bad;
   IF v_bad THEN RAISE EXCEPTION '外部键超过目标128字符 %.%',r.table_name,r.column_name; END IF;
 END LOOP;
 -- SQL inserts depend on an already commissioned DB default/sequence. Do not synthesize IDs.
 IF EXISTS (SELECT 1 FROM information_schema.columns
     WHERE table_schema='costree_mvp' AND column_name='id'
       AND table_name IN ('cost_unit_dict','cost_model_node','cost_project','cost_unit_cost_detail','cost_work_order','cost_work_order_ledger_detail')
       AND column_default IS NULL) THEN
    RAISE EXCEPTION '目标 id 缺少默认生成器，请先完成交付包主键迁移及序列核对；本流程不补主键';
 END IF;
 FOR r IN SELECT table_name,column_default FROM information_schema.columns
     WHERE table_schema='costree_mvp' AND column_name='id'
       AND table_name IN ('cost_unit_dict','cost_model_node','cost_project','cost_unit_cost_detail','cost_work_order','cost_work_order_ledger_detail')
 LOOP
   -- Resolve the actual DEFAULT, not an obsolete sequence that is only OWNED BY this column.
   v_seq := substring(r.column_default FROM '^nextval\(''([^'']+)''::regclass\)$');
   IF v_seq IS NULL THEN RAISE EXCEPTION '% 的主键生成器不是可核验序列，需现场适配',r.table_name; END IF;
   IF current_setting('server_version_num')::integer >= 100000 THEN
     EXECUTE 'SELECT seqincrement,seqcycle,seqmax FROM pg_catalog.pg_sequence WHERE seqrelid=$1'
       INTO v_increment,v_cycle,v_limit USING v_seq::regclass;
     EXECUTE 'SELECT last_value::numeric+CASE WHEN is_called THEN $1 ELSE 0 END FROM '||v_seq::regclass
       INTO v_next USING v_increment;
   ELSE
     EXECUTE 'SELECT last_value::numeric+CASE WHEN is_called THEN increment_by ELSE 0 END,increment_by,is_cycled,max_value FROM '||v_seq::regclass
       INTO v_next,v_increment,v_cycle,v_limit;
   END IF;
   EXECUTE 'SELECT COALESCE(max(id),0) FROM "costree_mvp".'||quote_ident(r.table_name) INTO v_max;
   IF v_increment<=0 OR v_cycle OR v_next>v_limit OR v_max+v_increment>v_limit THEN
     RAISE EXCEPTION '% 的序列配置/ID范围不可安全使用',r.table_name;
   END IF;
   -- Java ASSIGN_ID and SQL sequence inserts coexist. Locks above block table writers.
   -- Advance only, never reset IDs/sequence backwards. Sequence gaps do NOT roll back.
   IF v_next<=v_max THEN
     EXECUTE 'SELECT last_value FROM '||v_seq::regclass INTO v_last;
     PERFORM pg_catalog.setval(v_seq::regclass,GREATEST(v_last,v_max)::bigint,true);
   END IF;
 END LOOP;
 IF EXISTS (SELECT 1 FROM cost_sync_stage_v20261009.stg_model_node n
    JOIN cost_sync_stage_v20261009.stg_model_node p ON btrim(p.node_code)=btrim(n.parent_node_code)
    WHERE (n.node_type='SERIES' AND p.node_type<>'DOMAIN')
       OR (n.node_type='MODEL' AND p.node_type<>'SERIES')) THEN
    RAISE EXCEPTION '树层级必须 DOMAIN→SERIES→MODEL，不能任意推断父节点';
 END IF;
END $$;
-- Normalize business keys once, using the exact same form used by target matching.
UPDATE cost_sync_stage_v20261009.stg_unit_dict SET accounting_unit_code=btrim(accounting_unit_code),accounting_unit_name=btrim(accounting_unit_name);
UPDATE cost_sync_stage_v20261009.stg_model_node SET node_code=btrim(node_code),parent_node_code=btrim(parent_node_code),node_type=btrim(node_type);
UPDATE cost_sync_stage_v20261009.stg_project SET project_code=btrim(project_code),model_node_code=btrim(model_node_code);
UPDATE cost_sync_stage_v20261009.stg_unit_amount SET source_record_id=btrim(source_record_id),project_code=btrim(project_code),accounting_unit_code=btrim(accounting_unit_code);
UPDATE cost_sync_stage_v20261009.stg_work_order SET source_work_order_id=btrim(source_work_order_id),project_code=btrim(project_code),accounting_unit_code=btrim(accounting_unit_code),work_order_no=btrim(work_order_no);
UPDATE cost_sync_stage_v20261009.stg_ledger_detail SET source_detail_id=btrim(source_detail_id),source_work_order_id=btrim(source_work_order_id),project_code=btrim(project_code),accounting_unit_code=btrim(accounting_unit_code),work_order_no=btrim(work_order_no);
DO $$ BEGIN
 IF EXISTS(SELECT a.project_code,u.accounting_unit_name FROM cost_sync_stage_v20261009.stg_unit_amount a
   JOIN cost_sync_stage_v20261009.stg_unit_dict u ON u.accounting_unit_code=a.accounting_unit_code
   GROUP BY a.project_code,u.accounting_unit_name HAVING count(*)>1) THEN
   RAISE EXCEPTION '同名历史单位异码归一到同一项目单位金额键；禁止 SUM/MAX/任选一条，请人工确认源权威记录';
 END IF;
 IF EXISTS(SELECT w.project_code,u.accounting_unit_name,w.work_order_no FROM cost_sync_stage_v20261009.stg_work_order w
   JOIN cost_sync_stage_v20261009.stg_unit_dict u ON u.accounting_unit_code=w.accounting_unit_code
   GROUP BY w.project_code,u.accounting_unit_name,w.work_order_no HAVING count(*)>1) THEN
   RAISE EXCEPTION '同名历史单位异码归一到同一工作令键；必须显式映射，不能按名称自动合并';
 END IF;
 IF EXISTS(SELECT 1 FROM cost_sync_stage_v20261009.stg_ledger_detail d
   JOIN cost_sync_stage_v20261009.stg_work_order w ON w.source_work_order_id=d.source_work_order_id
   WHERE (w.project_code,w.accounting_unit_code,w.work_order_no)
     IS DISTINCT FROM (d.project_code,d.accounting_unit_code,d.work_order_no)) THEN
   RAISE EXCEPTION '账面源工作令ID与项目/实际单位编码/工作令号矛盾';
 END IF;
END $$;
DO $$ BEGIN
 IF EXISTS(SELECT source_record_id FROM "costree_mvp".cost_unit_cost_detail WHERE tenant_id=__TENANT_ID__
   AND NULLIF(btrim(source_record_id),'') IS NOT NULL GROUP BY source_record_id HAVING count(*)>1) THEN
   RAISE EXCEPTION '目标表 cost_unit_cost_detail 稳定源 ID 不唯一';
 END IF;
 IF EXISTS(SELECT 1 FROM "costree_mvp".cost_unit_cost_detail WHERE tenant_id=__TENANT_ID__ AND (
 project_code IS DISTINCT FROM btrim(project_code) OR unit_name IS DISTINCT FROM btrim(unit_name))) THEN
   RAISE EXCEPTION '目标表 cost_unit_cost_detail 业务键包含首尾空格，先核查不能另建重复记录';
 END IF;
END $$;
DO $$ BEGIN
 IF EXISTS(SELECT source_work_order_id FROM "costree_mvp".cost_work_order WHERE tenant_id=__TENANT_ID__
   AND NULLIF(btrim(source_work_order_id),'') IS NOT NULL GROUP BY source_work_order_id HAVING count(*)>1) THEN
   RAISE EXCEPTION '目标表 cost_work_order 稳定源 ID 不唯一';
 END IF;
 IF EXISTS(SELECT 1 FROM "costree_mvp".cost_work_order WHERE tenant_id=__TENANT_ID__ AND (
 project_code IS DISTINCT FROM btrim(project_code) OR unit_name IS DISTINCT FROM btrim(unit_name) OR work_order_no IS DISTINCT FROM btrim(work_order_no))) THEN
   RAISE EXCEPTION '目标表 cost_work_order 业务键包含首尾空格，先核查不能另建重复记录';
 END IF;
END $$;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM "costree_mvp".cost_unit_dict WHERE tenant_id=__TENANT_ID__
   AND accounting_unit_code IS DISTINCT FROM btrim(accounting_unit_code)) THEN
   RAISE EXCEPTION '目标 cost_unit_dict.accounting_unit_code 含首尾空格，不能新建重复记录';
 END IF;
END $$;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM "costree_mvp".cost_model_node WHERE tenant_id=__TENANT_ID__
   AND node_code IS DISTINCT FROM btrim(node_code)) THEN
   RAISE EXCEPTION '目标 cost_model_node.node_code 含首尾空格，不能新建重复记录';
 END IF;
END $$;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM "costree_mvp".cost_project WHERE tenant_id=__TENANT_ID__
   AND project_code IS DISTINCT FROM btrim(project_code)) THEN
   RAISE EXCEPTION '目标 cost_project.project_code 含首尾空格，不能新建重复记录';
 END IF;
END $$;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM "costree_mvp".cost_work_order_ledger_detail WHERE tenant_id=__TENANT_ID__
   AND source_detail_id IS DISTINCT FROM btrim(source_detail_id)) THEN
   RAISE EXCEPTION '目标 cost_work_order_ledger_detail.source_detail_id 含首尾空格，不能新建重复记录';
 END IF;
END $$;
-- 全量快照导入前检查。任何异常都会中止，不修改业务表。
-- 现场需把业务 schema costree_mvp 和租户 124 调整为实际值。

DO $$
DECLARE
    v_tenant_id int8;
    v_table_count int4;
BEGIN
    SELECT tenant_id INTO v_tenant_id
    FROM cost_sync_stage_v20261009.sync_control
    WHERE id = 1;

    IF v_tenant_id IS NULL THEN
        RAISE EXCEPTION 'cost_sync_stage_v20261009.sync_control 未初始化';
    END IF;

    IF (SELECT load_status FROM cost_sync_stage_v20261009.sync_control WHERE id = 1) <> 'READY' THEN
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

    IF NOT EXISTS (SELECT 1 FROM cost_sync_stage_v20261009.stg_model_node)
       OR NOT EXISTS (SELECT 1 FROM cost_sync_stage_v20261009.stg_project) THEN
        RAISE EXCEPTION '型号树或项目全量快照为空，拒绝同步';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage_v20261009.stg_unit_dict
        WHERE accounting_unit_code IS NULL OR btrim(accounting_unit_code) = ''
           OR accounting_unit_name IS NULL OR btrim(accounting_unit_name) = ''
    ) THEN
        RAISE EXCEPTION '单位中间表存在空核算单位编码或名称';
    END IF;
    IF EXISTS (
        SELECT accounting_unit_code FROM cost_sync_stage_v20261009.stg_unit_dict
        GROUP BY accounting_unit_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '单位中间表存在重复核算单位编码';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage_v20261009.stg_model_node
        WHERE node_code IS NULL OR btrim(node_code) = ''
           OR node_name IS NULL OR btrim(node_name) = ''
           OR node_type NOT IN ('DOMAIN', 'SERIES', 'MODEL')
    ) THEN
        RAISE EXCEPTION '型号树存在空编码、空名称或非法 node_type';
    END IF;
    IF EXISTS (
        SELECT node_code FROM cost_sync_stage_v20261009.stg_model_node
        GROUP BY node_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '型号树中间表存在重复 node_code';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM cost_sync_stage_v20261009.stg_model_node n
        WHERE n.node_type <> 'DOMAIN'
          AND lower(btrim(COALESCE(n.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND (
              n.parent_node_code IS NULL OR btrim(n.parent_node_code) = ''
              OR NOT EXISTS (
                  SELECT 1 FROM cost_sync_stage_v20261009.stg_model_node p
                  WHERE p.node_code = n.parent_node_code
                    AND lower(btrim(COALESCE(p.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
              )
          )
    ) THEN
        RAISE EXCEPTION '型号树存在活动子节点找不到活动父节点';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage_v20261009.stg_project
        WHERE project_code IS NULL OR btrim(project_code) = ''
           OR project_name IS NULL OR btrim(project_name) = ''
           OR model_node_code IS NULL OR btrim(model_node_code) = ''
    ) THEN
        RAISE EXCEPTION '项目中间表存在空项目编号、名称或型号节点编码';
    END IF;
    IF EXISTS (
        SELECT project_code FROM cost_sync_stage_v20261009.stg_project
        GROUP BY project_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '项目中间表存在重复项目编号';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM cost_sync_stage_v20261009.stg_project p
        WHERE lower(btrim(COALESCE(p.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND NOT EXISTS (
              SELECT 1 FROM cost_sync_stage_v20261009.stg_model_node n
              WHERE n.node_code = p.model_node_code AND n.node_type = 'MODEL'
                AND lower(btrim(COALESCE(n.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          )
    ) THEN
        RAISE EXCEPTION '活动项目无法匹配活动 MODEL 节点';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage_v20261009.stg_unit_amount
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
        FROM cost_sync_stage_v20261009.stg_unit_amount
        GROUP BY project_code, accounting_unit_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '单位金额中间表存在重复的项目 + 核算单位';
    END IF;
    IF EXISTS (
        SELECT 1 FROM cost_sync_stage_v20261009.stg_unit_amount a
        WHERE lower(btrim(COALESCE(a.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND (
              NOT EXISTS (SELECT 1 FROM cost_sync_stage_v20261009.stg_project p WHERE p.project_code = a.project_code)
              OR NOT EXISTS (SELECT 1 FROM cost_sync_stage_v20261009.stg_unit_dict u WHERE u.accounting_unit_code = a.accounting_unit_code)
          )
    ) THEN
        RAISE EXCEPTION '活动单位金额无法匹配本批项目或单位字典';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage_v20261009.stg_work_order
        WHERE project_code IS NULL OR btrim(project_code) = ''
           OR accounting_unit_code IS NULL OR btrim(accounting_unit_code) = ''
           OR work_order_no IS NULL OR btrim(work_order_no) = ''
    ) THEN
        RAISE EXCEPTION '工作令存在空项目、核算单位编码或工作令编号';
    END IF;
    IF EXISTS (
        SELECT project_code, accounting_unit_code, work_order_no
        FROM cost_sync_stage_v20261009.stg_work_order
        GROUP BY project_code, accounting_unit_code, work_order_no HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '工作令中间表存在重复业务键';
    END IF;
    IF EXISTS (
        SELECT 1 FROM cost_sync_stage_v20261009.stg_work_order w
        WHERE lower(btrim(COALESCE(w.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND (
              NOT EXISTS (SELECT 1 FROM cost_sync_stage_v20261009.stg_project p WHERE p.project_code = w.project_code)
              OR NOT EXISTS (SELECT 1 FROM cost_sync_stage_v20261009.stg_unit_dict u WHERE u.accounting_unit_code = w.accounting_unit_code)
          )
    ) THEN
        RAISE EXCEPTION '活动工作令无法匹配本批项目或单位字典';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage_v20261009.stg_ledger_detail
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
        SELECT source_detail_id FROM cost_sync_stage_v20261009.stg_ledger_detail
        GROUP BY source_detail_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '账面中间表 source_detail_id 不唯一';
    END IF;
    IF EXISTS (
        SELECT 1 FROM cost_sync_stage_v20261009.stg_ledger_detail d
        WHERE lower(btrim(COALESCE(d.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND NOT EXISTS (
              SELECT 1 FROM cost_sync_stage_v20261009.stg_work_order w
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

DELETE FROM cost_sync_stage_v20261009.manual_field_digest digest
USING cost_sync_stage_v20261009.sync_control control
WHERE control.id = 1
  AND digest.batch_code = control.batch_code
  AND digest.tenant_id = control.tenant_id;

DELETE FROM cost_sync_stage_v20261009.manual_field_baseline baseline
USING cost_sync_stage_v20261009.sync_control control
WHERE control.id = 1
  AND baseline.batch_code = control.batch_code
  AND baseline.tenant_id = control.tenant_id;

INSERT INTO cost_sync_stage_v20261009.manual_field_baseline
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
FROM cost_sync_stage_v20261009.sync_control control
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
FROM cost_sync_stage_v20261009.sync_control control
JOIN "costree_mvp".cost_project project ON project.tenant_id = control.tenant_id
WHERE control.id = 1
UNION ALL
SELECT control.batch_code, control.tenant_id, 'unit_fill', unit_cost.id,
       md5(ROW(
           unit_cost.id,
           unit_cost.target_cost_amount, unit_cost.approved_amount, unit_cost.book_cost_amount,
           unit_cost.salary_amount, unit_cost.material_amount, unit_cost.outsource_amount,
           unit_cost.manage_amount, unit_cost.fuel_power_amount, unit_cost.other_amount,
           unit_cost.remark, unit_cost.deleted
       )::text), CURRENT_TIMESTAMP
FROM cost_sync_stage_v20261009.sync_control control
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
FROM cost_sync_stage_v20261009.sync_control control
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
FROM cost_sync_stage_v20261009.sync_control control
JOIN "costree_mvp".cost_warning_record warning ON warning.tenant_id = control.tenant_id
WHERE control.id = 1;

INSERT INTO cost_sync_stage_v20261009.manual_field_digest
    (batch_code, tenant_id, object_name, row_count, digest_value, captured_at)
SELECT control.batch_code, control.tenant_id, object_type.object_name,
       count(baseline.record_id)::int8,
       md5(COALESCE(string_agg(baseline.digest_value, '' ORDER BY baseline.record_id), 'EMPTY')),
       CURRENT_TIMESTAMP
FROM cost_sync_stage_v20261009.sync_control control
CROSS JOIN (
    SELECT 'project_basic'::varchar(64) AS object_name
    UNION ALL SELECT 'project_state'::varchar(64)
    UNION ALL SELECT 'unit_fill'::varchar(64)
    UNION ALL SELECT 'work_order_fill'::varchar(64)
    UNION ALL SELECT 'warning_state'::varchar(64)
) object_type
LEFT JOIN cost_sync_stage_v20261009.manual_field_baseline baseline
  ON baseline.batch_code = control.batch_code
 AND baseline.tenant_id = control.tenant_id
 AND baseline.object_name = object_type.object_name
WHERE control.id = 1
GROUP BY control.batch_code, control.tenant_id, object_type.object_name;

SELECT 'precheck passed' AS result,
       tenant_id, batch_code, source_tag, load_status, loaded_at
FROM cost_sync_stage_v20261009.sync_control
WHERE id = 1;
-- 中间表到成本库业务表的幂等同步。
-- 目标方言：PostgreSQL 9.2.4 / GaussDB 8.2.1（现场引擎兼容性待验）：不用 MERGE、ON CONFLICT。
-- 现场需把业务 schema costree_mvp 和租户 124 调整为实际值。

LOCK TABLE cost_sync_stage_v20261009.sync_control IN EXCLUSIVE MODE;

DROP TABLE IF EXISTS pg_temp.tmp_cost_sync_context;
CREATE TEMP TABLE tmp_cost_sync_context ON COMMIT PRESERVE ROWS AS
SELECT tenant_id, batch_code, source_tag
FROM cost_sync_stage_v20261009.sync_control
WHERE id = 1 AND load_status = 'READY';

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tmp_cost_sync_context) THEN
        RAISE EXCEPTION '当前批次不是 READY，请先完成装载和 04 导入前检查';
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- 1. 单位字典：源系统拥有全部单位映射字段。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS pg_temp.tmp_cost_sync_unit;
CREATE TEMP TABLE tmp_cost_sync_unit ON COMMIT PRESERVE ROWS AS
SELECT
    NULLIF(btrim(s.accounting_unit_id), '')::varchar(128) AS accounting_unit_id,
    btrim(s.accounting_unit_code)::varchar(128) AS accounting_unit_code,
    btrim(s.accounting_unit_name)::varchar(255) AS accounting_unit_name,
    NULLIF(btrim(s.manage_unit_code), '')::varchar(128) AS manage_unit_code,
    NULLIF(btrim(s.manage_unit_name), '')::varchar(255) AS manage_unit_name,
    COALESCE(
        NULLIF(upper(btrim(s.manage_unit_group)), ''),
        CASE btrim(COALESCE(s.manage_unit_name, ''))
            WHEN '院部' THEN 'HEAD_OFFICE'
            WHEN '八部' THEN 'OVERALL'
            WHEN '509所' THEN 'OVERALL'
            WHEN '800所' THEN 'ASSEMBLY'
            WHEN '149厂' THEN 'ASSEMBLY'
            WHEN '812所' THEN 'ASSEMBLY'
            WHEN '电子所' THEN 'PROFESSIONAL'
            WHEN '动力所' THEN 'PROFESSIONAL'
            WHEN '811所' THEN 'PROFESSIONAL'
            WHEN '802所' THEN 'PROFESSIONAL'
            WHEN '803所' THEN 'PROFESSIONAL'
            WHEN '基础所' THEN 'FOUNDATION'
            WHEN '院外单位' THEN 'OUTER'
            ELSE NULL
        END
    )::varchar(32) AS manage_unit_group,
    NULLIF(btrim(s.contact_unit_code), '')::varchar(128) AS contact_unit_code,
    NULLIF(btrim(s.contact_unit_name), '')::varchar(128) AS contact_unit_name,
    CASE WHEN lower(btrim(COALESCE(s.inside_group, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN true ELSE false END AS inside_group,
    CASE WHEN lower(btrim(COALESCE(s.inside_institute, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN true ELSE false END AS inside_institute,
    CASE WHEN lower(btrim(COALESCE(s.disabled, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN 'DISABLE' ELSE 'ENABLE' END::varchar(32) AS status,
    CASE WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_sync_stage_v20261009.stg_unit_dict s;

UPDATE "costree_mvp".cost_unit_dict d
SET accounting_unit_id = s.accounting_unit_id,
    accounting_unit_name = s.accounting_unit_name,
    manage_unit_code = s.manage_unit_code,
    manage_unit_name = s.manage_unit_name,
    manage_unit_group = s.manage_unit_group,
    contact_unit_code = s.contact_unit_code,
    contact_unit_name = s.contact_unit_name,
    inside_group = s.inside_group,
    inside_institute = s.inside_institute,
    status = s.status,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_unit s
CROSS JOIN tmp_cost_sync_context c
WHERE (d.tenant_id = c.tenant_id
  AND d.accounting_unit_code = s.accounting_unit_code)
  AND d.deleted=0
  AND ROW(d.accounting_unit_id,d.accounting_unit_name,d.manage_unit_code,d.manage_unit_name,d.manage_unit_group,d.contact_unit_code,d.contact_unit_name,d.inside_group,d.inside_institute,d.status) IS DISTINCT FROM ROW(s.accounting_unit_id,s.accounting_unit_name,s.manage_unit_code,s.manage_unit_name,s.manage_unit_group,s.contact_unit_code,s.contact_unit_name,s.inside_group,s.inside_institute,s.status);

INSERT INTO "costree_mvp".cost_unit_dict (
    accounting_unit_id, accounting_unit_code, accounting_unit_name,
    manage_unit_code, manage_unit_name, manage_unit_group,
    contact_unit_code, contact_unit_name, inside_group, inside_institute,
    status, remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT
    s.accounting_unit_id, s.accounting_unit_code, s.accounting_unit_name,
    s.manage_unit_code, s.manage_unit_name, s.manage_unit_group,
    s.contact_unit_code, s.contact_unit_name, s.inside_group, s.inside_institute,
    s.status, '外部单位字典全量快照同步', c.source_tag, CURRENT_TIMESTAMP,
    c.source_tag, CURRENT_TIMESTAMP, s.deleted, c.tenant_id
FROM tmp_cost_sync_unit s
CROSS JOIN tmp_cost_sync_context c
WHERE s.deleted = 0
  AND NOT EXISTS (
      SELECT 1 FROM "costree_mvp".cost_unit_dict d
      WHERE d.tenant_id = c.tenant_id
        AND d.accounting_unit_code = s.accounting_unit_code
  );

-- ---------------------------------------------------------------------
-- 2. 型号目录树：先写节点，再回填父 ID 和领域编码。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS pg_temp.tmp_cost_sync_node;
CREATE TEMP TABLE tmp_cost_sync_node ON COMMIT PRESERVE ROWS AS
SELECT
    btrim(s.node_code)::varchar(128) AS node_code,
    NULLIF(btrim(s.parent_node_code), '')::varchar(128) AS parent_node_code,
    btrim(s.node_name)::varchar(255) AS node_name,
    upper(btrim(s.node_type))::varchar(32) AS node_type,
    NULLIF(btrim(s.domain_code), '')::varchar(128) AS domain_code,
    CASE WHEN btrim(COALESCE(s.sort_no, '')) ~ '^[+-]?[0-9]+$'
         THEN btrim(s.sort_no)::int4 ELSE 0 END AS sort_no,
    COALESCE(NULLIF(upper(btrim(s.status)), ''), 'ENABLE')::varchar(32) AS status,
    CASE WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_sync_stage_v20261009.stg_model_node s;

UPDATE "costree_mvp".cost_model_node n
SET node_name = s.node_name,
    node_type = s.node_type,
    domain_code = CASE WHEN s.node_type = 'DOMAIN' THEN s.node_code ELSE n.domain_code END,
    sort = s.sort_no,
    status = s.status,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_node s
CROSS JOIN tmp_cost_sync_context c
WHERE (n.tenant_id = c.tenant_id
  AND n.node_code = s.node_code)
  AND n.deleted=0
  AND ROW(n.node_name,n.node_type,n.domain_code,n.sort,n.status) IS DISTINCT FROM ROW(s.node_name,s.node_type,CASE WHEN s.node_type = 'DOMAIN' THEN s.node_code ELSE n.domain_code END,s.sort_no,s.status);

INSERT INTO "costree_mvp".cost_model_node (
    parent_id, node_code, node_name, node_type, domain_code, sort, status,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT
    0, s.node_code, s.node_name, s.node_type,
    CASE WHEN s.node_type = 'DOMAIN' THEN s.node_code ELSE s.domain_code END,
    s.sort_no, s.status, '外部主业项目树全量快照同步',
    c.source_tag, CURRENT_TIMESTAMP, c.source_tag, CURRENT_TIMESTAMP,
    s.deleted, c.tenant_id
FROM tmp_cost_sync_node s
CROSS JOIN tmp_cost_sync_context c
WHERE s.deleted = 0
  AND NOT EXISTS (
      SELECT 1 FROM "costree_mvp".cost_model_node n
      WHERE n.tenant_id = c.tenant_id AND n.node_code = s.node_code
  );

UPDATE "costree_mvp".cost_model_node n
SET parent_id = CASE WHEN s.node_type = 'DOMAIN' THEN 0 ELSE p.id END,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_node s
CROSS JOIN tmp_cost_sync_context c
LEFT JOIN "costree_mvp".cost_model_node p
  ON p.tenant_id = c.tenant_id AND p.node_code = s.parent_node_code
WHERE (n.tenant_id = c.tenant_id
  AND n.node_code = s.node_code)
  AND n.deleted=0
  AND ROW(n.parent_id) IS DISTINCT FROM ROW(CASE WHEN s.node_type = 'DOMAIN' THEN 0 ELSE p.id END);

UPDATE "costree_mvp".cost_model_node n
SET domain_code = CASE
        WHEN s.node_type = 'DOMAIN' THEN s.node_code
        WHEN s.node_type = 'SERIES' THEN COALESCE(s.domain_code, p.node_code)
        ELSE COALESCE(s.domain_code, gp.node_code, p.domain_code)
    END,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_node s
CROSS JOIN tmp_cost_sync_context c
LEFT JOIN "costree_mvp".cost_model_node p
  ON p.tenant_id = c.tenant_id AND p.node_code = s.parent_node_code
LEFT JOIN "costree_mvp".cost_model_node gp
  ON gp.tenant_id = c.tenant_id AND gp.id = p.parent_id
WHERE (n.tenant_id = c.tenant_id
  AND n.node_code = s.node_code)
  AND n.deleted=0
  AND ROW(n.domain_code) IS DISTINCT FROM ROW(CASE
        WHEN s.node_type = 'DOMAIN' THEN s.node_code
        WHEN s.node_type = 'SERIES' THEN COALESCE(s.domain_code, p.node_code)
        ELSE COALESCE(s.domain_code, gp.node_code, p.domain_code)
    END);

-- ---------------------------------------------------------------------
-- 3. 项目锚点：只更新源项目属性，保留填报、审核和预警状态。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS pg_temp.tmp_cost_sync_project;
CREATE TEMP TABLE tmp_cost_sync_project ON COMMIT PRESERVE ROWS AS
SELECT
    btrim(s.project_code)::varchar(128) AS project_code,
    btrim(s.project_name)::varchar(255) AS project_name,
    m.id AS model_node_id,
    COALESCE(NULLIF(btrim(s.domain_code), ''), dom.node_code, m.domain_code)::varchar(128) AS domain_code,
    COALESCE(NULLIF(btrim(s.domain_name), ''), dom.node_name)::varchar(255) AS domain_name,
    COALESCE(NULLIF(btrim(s.category_code), ''), series.node_code)::varchar(128) AS category_code,
    COALESCE(NULLIF(btrim(s.category_name), ''), series.node_name)::varchar(255) AS category_name,
    COALESCE(NULLIF(btrim(s.model_code), ''), m.node_code)::varchar(128) AS model_code,
    COALESCE(NULLIF(btrim(s.model_name), ''), m.node_name, s.project_name)::varchar(255) AS model_name,
    CASE WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_sync_stage_v20261009.stg_project s
CROSS JOIN tmp_cost_sync_context c
LEFT JOIN "costree_mvp".cost_model_node m
  ON m.tenant_id = c.tenant_id AND m.node_code = s.model_node_code
LEFT JOIN "costree_mvp".cost_model_node series
  ON series.tenant_id = c.tenant_id AND series.id = m.parent_id
LEFT JOIN "costree_mvp".cost_model_node dom
  ON dom.tenant_id = c.tenant_id AND dom.id = series.parent_id;

UPDATE "costree_mvp".cost_project p
SET project_name = s.project_name,
    model_node_id = s.model_node_id,
    domain_code = s.domain_code,
    domain_name = s.domain_name,
    category_code = s.category_code,
    category_name = s.category_name,
    model_code = s.model_code,
    model_name = s.model_name,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_project s
CROSS JOIN tmp_cost_sync_context c
WHERE (p.tenant_id = c.tenant_id
  AND p.project_code = s.project_code)
  AND p.deleted=0
  AND ROW(p.project_name,p.model_node_id,p.domain_code,p.domain_name,p.category_code,p.category_name,p.model_code,p.model_name) IS DISTINCT FROM ROW(s.project_name,s.model_node_id,s.domain_code,s.domain_name,s.category_code,s.category_name,s.model_code,s.model_name);

INSERT INTO "costree_mvp".cost_project (
    project_code, project_name, model_node_id,
    domain_code, domain_name, category_code, category_name, model_code, model_name,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT
    s.project_code, s.project_name, s.model_node_id,
    s.domain_code, s.domain_name, s.category_code, s.category_name, s.model_code, s.model_name,
    '外部主业项目全量快照同步', c.source_tag, CURRENT_TIMESTAMP,
    c.source_tag, CURRENT_TIMESTAMP, s.deleted, c.tenant_id
FROM tmp_cost_sync_project s
CROSS JOIN tmp_cost_sync_context c
WHERE s.deleted = 0
  AND NOT EXISTS (
      SELECT 1 FROM "costree_mvp".cost_project p
      WHERE p.tenant_id = c.tenant_id AND p.project_code = s.project_code
  );

-- ---------------------------------------------------------------------
-- 4. 项目单位金额：只同步合同、到款；目标和审定保持项目办填写值。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS pg_temp.tmp_cost_sync_amount;
CREATE TEMP TABLE tmp_cost_sync_amount ON COMMIT PRESERVE ROWS AS
SELECT
    NULLIF(btrim(s.source_record_id), '')::varchar(128) AS source_record_id,
    CASE
        WHEN btrim(COALESCE(s.source_update_time, '')) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}:[0-9]{2}'
        THEN to_timestamp(replace(substr(btrim(s.source_update_time), 1, 19), 'T', ' '), 'YYYY-MM-DD HH24:MI:SS')
        ELSE NULL
    END AS source_update_time,
    btrim(s.project_code)::varchar(128) AS project_code,
    COALESCE(NULLIF(btrim(s.project_name), ''), p.project_name)::varchar(255) AS project_name,
    p.id AS project_id,
    p.domain_code, p.domain_name, p.model_node_id, p.model_code, p.model_name,
    d.unit_id,
    d.accounting_unit_code,
    d.accounting_unit_name AS unit_name,
    CASE WHEN btrim(COALESCE(s.contract_amount_wan, '')) = '' THEN NULL
         ELSE btrim(s.contract_amount_wan)::numeric(18,2) END AS contract_amount,
    CASE WHEN btrim(COALESCE(s.income_amount_wan, '')) = '' THEN NULL
         ELSE btrim(s.income_amount_wan)::numeric(18,2) END AS income_amount,
    CASE WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_sync_stage_v20261009.stg_unit_amount s
CROSS JOIN tmp_cost_sync_context c
LEFT JOIN "costree_mvp".cost_project p
  ON p.tenant_id = c.tenant_id AND p.project_code = s.project_code
LEFT JOIN "costree_mvp".cost_unit_dict d
  ON d.tenant_id = c.tenant_id AND d.accounting_unit_code = s.accounting_unit_code;

DROP TABLE IF EXISTS pg_temp.tmp_cost_sync_amount_match;
CREATE TEMP TABLE tmp_cost_sync_amount_match ON COMMIT PRESERVE ROWS AS
SELECT s.*,
       COALESCE(
           CASE WHEN s.source_record_id IS NOT NULL THEN (
               SELECT min(x.id) FROM "costree_mvp".cost_unit_cost_detail x
               WHERE x.tenant_id = c.tenant_id AND x.source_record_id = s.source_record_id
           ) ELSE NULL END,
           (
               SELECT min(x.id) FROM "costree_mvp".cost_unit_cost_detail x
               WHERE x.tenant_id = c.tenant_id
                 AND x.project_code = s.project_code AND x.unit_name = s.unit_name
           )
       ) AS target_id
FROM tmp_cost_sync_amount s
CROSS JOIN tmp_cost_sync_context c;

DO $$ BEGIN
 IF EXISTS(SELECT target_id FROM tmp_cost_sync_amount_match WHERE target_id IS NOT NULL GROUP BY target_id HAVING count(*)>1) THEN
   RAISE EXCEPTION 'cost_unit_cost_detail: 多源命中同一个 target_id，拒绝不确定更新';
 END IF;
 IF EXISTS(SELECT 1 FROM tmp_cost_sync_amount_match s JOIN "costree_mvp".cost_unit_cost_detail old ON old.id=s.target_id
    WHERE (old.project_code,old.unit_name) IS DISTINCT FROM (s.project_code,s.unit_name)
      OR old.deleted<>0 OR (NULLIF(old.source_record_id,'') IS NOT NULL AND old.source_record_id IS DISTINCT FROM s.source_record_id)) THEN
   RAISE EXCEPTION 'cost_unit_cost_detail: 源ID与逻辑键冲突、源ID换代或目标已逻辑删除；人工核查，不迁移手填/不复活';
 END IF;
END $$;

UPDATE "costree_mvp".cost_unit_cost_detail x
SET source_record_id = COALESCE(s.source_record_id, x.source_record_id),
    source_update_time = COALESCE(s.source_update_time, x.source_update_time),
    contract_amount = s.contract_amount,
    income_amount = s.income_amount,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_amount_match s
CROSS JOIN tmp_cost_sync_context c
WHERE (x.id = s.target_id)
  AND x.deleted=0
  AND ROW(x.source_record_id,x.source_update_time,x.contract_amount,x.income_amount) IS DISTINCT FROM ROW(COALESCE(s.source_record_id, x.source_record_id),COALESCE(s.source_update_time, x.source_update_time),s.contract_amount,s.income_amount);

INSERT INTO "costree_mvp".cost_unit_cost_detail (
    project_id, project_code, project_name, domain_code, domain_name,
    model_node_id, model_code, model_name, unit_id, unit_name, stage_code,
    source_record_id, source_update_time, contract_amount, income_amount,
    target_cost_amount, book_cost_amount, approved_amount,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT
    s.project_id, s.project_code, s.project_name, s.domain_code, s.domain_name,
    s.model_node_id, s.model_code, s.model_name, s.unit_id, s.unit_name, 'ALL',
    s.source_record_id, s.source_update_time, s.contract_amount, s.income_amount,
    NULL, NULL, NULL,
    '预分预控项目单位金额全量快照同步；目标和审定由项目办维护',
    c.source_tag, CURRENT_TIMESTAMP, c.source_tag, CURRENT_TIMESTAMP, 0, c.tenant_id
FROM tmp_cost_sync_amount_match s
CROSS JOIN tmp_cost_sync_context c
WHERE s.deleted = 0 AND s.target_id IS NULL;

-- ---------------------------------------------------------------------
-- 5. 工作令：只同步字典归属；研制单位填写字段不在 UPDATE SET 中。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS pg_temp.tmp_cost_sync_work_order;
CREATE TEMP TABLE tmp_cost_sync_work_order ON COMMIT PRESERVE ROWS AS
SELECT
    NULLIF(btrim(s.source_work_order_id), '')::varchar(128) AS source_work_order_id,
    p.id AS project_id,
    btrim(s.project_code)::varchar(128) AS project_code,
    COALESCE(NULLIF(btrim(s.project_name), ''), p.project_name)::varchar(255) AS project_name,
    d.unit_id,
    d.accounting_unit_code,
    d.accounting_unit_name AS unit_name,
    btrim(s.work_order_no)::varchar(128) AS work_order_no,
    NULLIF(btrim(s.work_order_name), '')::varchar(255) AS work_order_name,
    CASE WHEN lower(btrim(COALESCE(s.disabled, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN true ELSE false END AS disabled,
    CASE WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_sync_stage_v20261009.stg_work_order s
CROSS JOIN tmp_cost_sync_context c
LEFT JOIN "costree_mvp".cost_project p
  ON p.tenant_id = c.tenant_id AND p.project_code = s.project_code
LEFT JOIN "costree_mvp".cost_unit_dict d
  ON d.tenant_id = c.tenant_id AND d.accounting_unit_code = s.accounting_unit_code;

DROP TABLE IF EXISTS pg_temp.tmp_cost_sync_work_order_match;
CREATE TEMP TABLE tmp_cost_sync_work_order_match ON COMMIT PRESERVE ROWS AS
SELECT s.*,
       COALESCE(
           CASE WHEN s.source_work_order_id IS NOT NULL THEN (
               SELECT min(x.id) FROM "costree_mvp".cost_work_order x
               WHERE x.tenant_id = c.tenant_id
                 AND x.source_work_order_id = s.source_work_order_id
           ) ELSE NULL END,
           (
               SELECT min(x.id) FROM "costree_mvp".cost_work_order x
               WHERE x.tenant_id = c.tenant_id
                 AND x.project_code = s.project_code
                 AND x.unit_name = s.unit_name
                 AND x.work_order_no = s.work_order_no
           )
       ) AS target_id
FROM tmp_cost_sync_work_order s
CROSS JOIN tmp_cost_sync_context c;

DO $$ BEGIN
 IF EXISTS(SELECT target_id FROM tmp_cost_sync_work_order_match WHERE target_id IS NOT NULL GROUP BY target_id HAVING count(*)>1) THEN
   RAISE EXCEPTION 'cost_work_order: 多源命中同一个 target_id，拒绝不确定更新';
 END IF;
 IF EXISTS(SELECT 1 FROM tmp_cost_sync_work_order_match s JOIN "costree_mvp".cost_work_order old ON old.id=s.target_id
    WHERE (old.project_code,old.unit_name,old.work_order_no) IS DISTINCT FROM (s.project_code,s.unit_name,s.work_order_no)
      OR old.deleted<>0 OR (NULLIF(old.source_work_order_id,'') IS NOT NULL AND old.source_work_order_id IS DISTINCT FROM s.source_work_order_id)) THEN
   RAISE EXCEPTION 'cost_work_order: 源ID与逻辑键冲突、源ID换代或目标已逻辑删除；人工核查，不迁移手填/不复活';
 END IF;
END $$;

UPDATE "costree_mvp".cost_work_order w
SET source_work_order_id = COALESCE(s.source_work_order_id, w.source_work_order_id),
    project_id = COALESCE(s.project_id, w.project_id),
    project_code = s.project_code,
    project_name = COALESCE(s.project_name, w.project_name),
    unit_id = COALESCE(s.unit_id, w.unit_id),
    unit_name = COALESCE(s.unit_name, w.unit_name),
    accounting_unit_code = COALESCE(s.accounting_unit_code, w.accounting_unit_code),
    accounting_unit_name = COALESCE(s.unit_name, w.accounting_unit_name),
    work_order_no = s.work_order_no,
    work_order_name = COALESCE(s.work_order_name, w.work_order_name),
    disabled = (s.disabled OR s.deleted <> 0),
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_work_order_match s
CROSS JOIN tmp_cost_sync_context c
WHERE (w.id = s.target_id)
  AND w.deleted=0
  AND ROW(w.source_work_order_id,w.project_id,w.project_code,w.project_name,w.unit_id,w.unit_name,w.accounting_unit_code,w.accounting_unit_name,w.work_order_no,w.work_order_name,w.disabled) IS DISTINCT FROM ROW(COALESCE(s.source_work_order_id, w.source_work_order_id),COALESCE(s.project_id, w.project_id),s.project_code,COALESCE(s.project_name, w.project_name),COALESCE(s.unit_id, w.unit_id),COALESCE(s.unit_name, w.unit_name),COALESCE(s.accounting_unit_code, w.accounting_unit_code),COALESCE(s.unit_name, w.accounting_unit_name),s.work_order_no,COALESCE(s.work_order_name, w.work_order_name),(s.disabled OR s.deleted <> 0));

INSERT INTO "costree_mvp".cost_work_order (
    source_work_order_id, project_id, project_code, project_name,
    unit_id, unit_name, accounting_unit_code, accounting_unit_name,
    work_order_no, work_order_name,
    product_target_cost, contract_amount, income_amount, book_cost_amount,
    stage_codes, max_stage_code, subsystem_name, product_short_name,
    quantity, vertical_division, disabled, approved_amount, status,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT
    s.source_work_order_id, s.project_id, s.project_code, s.project_name,
    s.unit_id, s.unit_name, s.accounting_unit_code, s.unit_name,
    s.work_order_no, s.work_order_name,
    NULL, NULL, NULL, 0,
    NULL, NULL, NULL, NULL,
    NULL, NULL, s.disabled, NULL, 'DRAFT',
    '外部工作令字典全量快照同步；填报字段由研制单位维护',
    c.source_tag, CURRENT_TIMESTAMP, c.source_tag, CURRENT_TIMESTAMP, 0, c.tenant_id
FROM tmp_cost_sync_work_order_match s
CROSS JOIN tmp_cost_sync_context c
WHERE s.deleted = 0 AND s.target_id IS NULL;

-- ---------------------------------------------------------------------
-- 6. 账面明细：源系统拥有全部明细字段，借贷都保留。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS pg_temp.tmp_cost_sync_ledger;
CREATE TEMP TABLE tmp_cost_sync_ledger ON COMMIT PRESERVE ROWS AS
SELECT
    btrim(s.source_detail_id)::varchar(128) AS source_detail_id,
    NULLIF(btrim(s.fiscal_year), '')::varchar(16) AS fiscal_year,
    NULLIF(btrim(s.accounting_period), '')::varchar(16) AS accounting_period,
    CASE
        WHEN btrim(COALESCE(s.voucher_date, '')) = '' THEN NULL
        WHEN btrim(s.voucher_date) ~ '^[0-9]{8}$' THEN to_date(btrim(s.voucher_date), 'YYYYMMDD')
        ELSE to_date(substr(btrim(s.voucher_date), 1, 10), 'YYYY-MM-DD')
    END AS voucher_date,
    NULLIF(btrim(s.voucher_no), '')::varchar(128) AS voucher_no,
    COALESCE(NULLIF(btrim(s.accounting_unit_id), ''), d.accounting_unit_id)::varchar(128) AS accounting_unit_id,
    d.accounting_unit_code,
    d.accounting_unit_name,
    d.manage_unit_name,
    NULLIF(btrim(s.subject_id), '')::varchar(128) AS subject_id,
    NULLIF(btrim(s.subject_code), '')::varchar(128) AS subject_code,
    NULLIF(btrim(s.subject_name), '')::varchar(255) AS subject_name,
    p.id AS project_id,
    btrim(s.project_code)::varchar(128) AS project_code,
    NULLIF(btrim(s.source_project_id), '')::varchar(128) AS source_project_id,
    COALESCE(NULLIF(btrim(s.project_name), ''), p.project_name)::varchar(255) AS project_name,
    NULLIF(btrim(s.source_work_order_id), '')::varchar(128) AS source_work_order_id,
    btrim(s.work_order_no)::varchar(128) AS work_order_no,
    NULLIF(btrim(s.work_order_name), '')::varchar(255) AS work_order_name,
    CASE WHEN upper(btrim(s.debit_credit)) IN ('借', 'DEBIT', 'D') THEN '借' ELSE '贷' END::varchar(32) AS debit_credit,
    btrim(s.amount_yuan)::numeric(18,2) AS amount,
    (btrim(s.amount_yuan)::numeric / 10000.0)::numeric(18,2) AS amount_wan,
    NULLIF(btrim(s.summary_text), '')::varchar(1000) AS summary_text,
    CASE
        WHEN btrim(COALESCE(s.source_lastmodify, '')) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}:[0-9]{2}'
        THEN to_timestamp(replace(substr(btrim(s.source_lastmodify), 1, 19), 'T', ' '), 'YYYY-MM-DD HH24:MI:SS')
        ELSE NULL
    END AS source_lastmodify,
    NULLIF(btrim(s.second_subject_code), '')::varchar(128) AS second_subject_code,
    NULLIF(btrim(s.second_subject_name), '')::varchar(255) AS second_subject_name,
    NULLIF(btrim(s.source_timestamp), '')::varchar(64) AS source_timestamp,
    CASE WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_sync_stage_v20261009.stg_ledger_detail s
CROSS JOIN tmp_cost_sync_context c
LEFT JOIN "costree_mvp".cost_project p
  ON p.tenant_id = c.tenant_id AND p.project_code = s.project_code
LEFT JOIN "costree_mvp".cost_unit_dict d
  ON d.tenant_id = c.tenant_id AND d.accounting_unit_code = s.accounting_unit_code;

DROP TABLE IF EXISTS pg_temp.tmp_cost_sync_ledger_match;
CREATE TEMP TABLE tmp_cost_sync_ledger_match ON COMMIT PRESERVE ROWS AS
SELECT s.*,
       COALESCE(
           CASE WHEN s.source_work_order_id IS NOT NULL THEN (
               SELECT min(w.id) FROM "costree_mvp".cost_work_order w
               WHERE w.tenant_id = c.tenant_id
                 AND w.source_work_order_id = s.source_work_order_id
           ) ELSE NULL END,
           (
               SELECT min(w.id) FROM "costree_mvp".cost_work_order w
               WHERE w.tenant_id = c.tenant_id
                 AND w.project_code = s.project_code
                 AND w.unit_name = s.accounting_unit_name
                 AND w.work_order_no = s.work_order_no
           )
       ) AS work_order_id,
       (
           SELECT min(d.id) FROM "costree_mvp".cost_work_order_ledger_detail d
           WHERE d.tenant_id = c.tenant_id AND d.source_detail_id = s.source_detail_id
       ) AS target_id
FROM tmp_cost_sync_ledger s
CROSS JOIN tmp_cost_sync_context c;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM tmp_cost_sync_ledger_match
        WHERE deleted = 0
          AND (project_id IS NULL OR accounting_unit_name IS NULL OR work_order_id IS NULL)
    ) THEN
        RAISE EXCEPTION '账面明细同步时仍有活动记录无法关联项目、实际单位或工作令';
    END IF;
END $$;

UPDATE "costree_mvp".cost_work_order_ledger_detail d
SET fiscal_year = s.fiscal_year,
    accounting_period = s.accounting_period,
    voucher_date = s.voucher_date,
    voucher_no = s.voucher_no,
    accounting_unit_id = COALESCE(s.accounting_unit_id, d.accounting_unit_id),
    accounting_unit_code = COALESCE(s.accounting_unit_code, d.accounting_unit_code),
    accounting_unit_name = COALESCE(s.accounting_unit_name, d.accounting_unit_name),
    manage_unit_name = COALESCE(s.manage_unit_name, d.manage_unit_name),
    subject_id = s.subject_id,
    subject_code = s.subject_code,
    subject_name = s.subject_name,
    project_code = s.project_code,
    source_project_id = s.source_project_id,
    project_name = COALESCE(s.project_name, d.project_name),
    source_work_order_id = COALESCE(s.source_work_order_id, d.source_work_order_id),
    work_order_no = s.work_order_no,
    work_order_name = COALESCE(s.work_order_name, d.work_order_name),
    debit_credit = s.debit_credit,
    amount = s.amount,
    amount_wan = s.amount_wan,
    summary_text = s.summary_text,
    source_lastmodify = s.source_lastmodify,
    second_subject_code = s.second_subject_code,
    second_subject_name = s.second_subject_name,
    source_timestamp = s.source_timestamp,
    project_id = COALESCE(s.project_id, d.project_id),
    work_order_id = COALESCE(s.work_order_id, d.work_order_id),
    remark = '外部账面明细全量快照同步',
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_ledger_match s
CROSS JOIN tmp_cost_sync_context c
WHERE (d.id = s.target_id)
  AND d.deleted=0
  AND ROW(d.fiscal_year,d.accounting_period,d.voucher_date,d.voucher_no,d.accounting_unit_id,d.accounting_unit_code,d.accounting_unit_name,d.manage_unit_name,d.subject_id,d.subject_code,d.subject_name,d.project_code,d.source_project_id,d.project_name,d.source_work_order_id,d.work_order_no,d.work_order_name,d.debit_credit,d.amount,d.amount_wan,d.summary_text,d.source_lastmodify,d.second_subject_code,d.second_subject_name,d.source_timestamp,d.project_id,d.work_order_id,d.remark) IS DISTINCT FROM ROW(s.fiscal_year,s.accounting_period,s.voucher_date,s.voucher_no,COALESCE(s.accounting_unit_id, d.accounting_unit_id),COALESCE(s.accounting_unit_code, d.accounting_unit_code),COALESCE(s.accounting_unit_name, d.accounting_unit_name),COALESCE(s.manage_unit_name, d.manage_unit_name),s.subject_id,s.subject_code,s.subject_name,s.project_code,s.source_project_id,COALESCE(s.project_name, d.project_name),COALESCE(s.source_work_order_id, d.source_work_order_id),s.work_order_no,COALESCE(s.work_order_name, d.work_order_name),s.debit_credit,s.amount,s.amount_wan,s.summary_text,s.source_lastmodify,s.second_subject_code,s.second_subject_name,s.source_timestamp,COALESCE(s.project_id, d.project_id),COALESCE(s.work_order_id, d.work_order_id),'外部账面明细全量快照同步');

INSERT INTO "costree_mvp".cost_work_order_ledger_detail (
    source_detail_id, fiscal_year, accounting_period, voucher_date, voucher_no,
    accounting_unit_id, accounting_unit_code, accounting_unit_name, manage_unit_name,
    subject_id, subject_code, subject_name,
    project_code, source_project_id, project_name,
    source_work_order_id, work_order_no, work_order_name,
    debit_credit, amount, amount_wan, summary_text, source_lastmodify,
    second_subject_code, second_subject_name, source_timestamp,
    resolved_stage_code, project_id, work_order_id,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT
    s.source_detail_id, s.fiscal_year, s.accounting_period, s.voucher_date, s.voucher_no,
    s.accounting_unit_id, s.accounting_unit_code, s.accounting_unit_name, s.manage_unit_name,
    s.subject_id, s.subject_code, s.subject_name,
    s.project_code, s.source_project_id, s.project_name,
    s.source_work_order_id, s.work_order_no, s.work_order_name,
    s.debit_credit, s.amount, s.amount_wan, s.summary_text, s.source_lastmodify,
    s.second_subject_code, s.second_subject_name, s.source_timestamp,
    w.max_stage_code, s.project_id, s.work_order_id,
    '外部账面明细全量快照同步', c.source_tag, CURRENT_TIMESTAMP,
    c.source_tag, CURRENT_TIMESTAMP, 0, c.tenant_id
FROM tmp_cost_sync_ledger_match s
CROSS JOIN tmp_cost_sync_context c
JOIN "costree_mvp".cost_work_order w ON w.id = s.work_order_id
WHERE s.deleted = 0 AND s.target_id IS NULL;

UPDATE cost_sync_stage_v20261009.sync_control
SET load_status = 'BUSINESS_SYNCED',
    synced_at = CURRENT_TIMESTAMP,
    remark = '业务表 UPDATE + INSERT 已完成，等待重算账面和最终验收'
WHERE id = 1;

UPDATE cost_sync_stage_v20261009.sync_history h
SET stage_row_count = (
        SELECT count(*) FROM cost_sync_stage_v20261009.stg_unit_dict
    ) + (
        SELECT count(*) FROM cost_sync_stage_v20261009.stg_model_node
    ) + (
        SELECT count(*) FROM cost_sync_stage_v20261009.stg_project
    ) + (
        SELECT count(*) FROM cost_sync_stage_v20261009.stg_unit_amount
    ) + (
        SELECT count(*) FROM cost_sync_stage_v20261009.stg_work_order
    ) + (
        SELECT count(*) FROM cost_sync_stage_v20261009.stg_ledger_detail
    ),
    sync_status = 'BUSINESS_SYNCED',
    finish_time = NULL,
    remark = '业务表幂等同步完成'
FROM tmp_cost_sync_context c
WHERE h.batch_code = c.batch_code AND h.tenant_id = c.tenant_id;

INSERT INTO cost_sync_stage_v20261009.sync_history (
    batch_code, tenant_id, source_tag, stage_row_count, sync_status, start_time, remark
)
SELECT c.batch_code, c.tenant_id, c.source_tag,
       (SELECT count(*) FROM cost_sync_stage_v20261009.stg_unit_dict)
       + (SELECT count(*) FROM cost_sync_stage_v20261009.stg_model_node)
       + (SELECT count(*) FROM cost_sync_stage_v20261009.stg_project)
       + (SELECT count(*) FROM cost_sync_stage_v20261009.stg_unit_amount)
       + (SELECT count(*) FROM cost_sync_stage_v20261009.stg_work_order)
       + (SELECT count(*) FROM cost_sync_stage_v20261009.stg_ledger_detail),
       'BUSINESS_SYNCED', CURRENT_TIMESTAMP, '业务表幂等同步完成'
FROM tmp_cost_sync_context c
WHERE NOT EXISTS (
    SELECT 1 FROM cost_sync_stage_v20261009.sync_history h
    WHERE h.batch_code = c.batch_code AND h.tenant_id = c.tenant_id
);

SELECT tenant_id, batch_code, load_status, loaded_at, synced_at, remark
FROM cost_sync_stage_v20261009.sync_control
WHERE id = 1;
-- 按全部年度借方明细重算逻辑工作令账面快照。
-- cost_work_order.book_cost_amount 是可重建快照；单位金额表的 book_cost_amount 不更新。

LOCK TABLE cost_sync_stage_v20261009.sync_control IN EXCLUSIVE MODE;

DROP TABLE IF EXISTS pg_temp.tmp_cost_recalc_context;
CREATE TEMP TABLE tmp_cost_recalc_context ON COMMIT PRESERVE ROWS AS
SELECT tenant_id, batch_code, source_tag
FROM cost_sync_stage_v20261009.sync_control
WHERE id = 1 AND load_status IN ('BUSINESS_SYNCED', 'RECALCULATED');

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tmp_cost_recalc_context) THEN
        RAISE EXCEPTION '业务表尚未同步，必须先执行 05-业务表幂等同步.sql';
    END IF;
END $$;

DROP TABLE IF EXISTS pg_temp.tmp_cost_recalc_work_order;
CREATE TEMP TABLE tmp_cost_recalc_work_order ON COMMIT PRESERVE ROWS AS
SELECT DISTINCT w.id AS work_order_id
FROM cost_sync_stage_v20261009.stg_work_order s
CROSS JOIN tmp_cost_recalc_context c
JOIN "costree_mvp".cost_unit_dict u
  ON u.tenant_id = c.tenant_id AND u.accounting_unit_code = s.accounting_unit_code
JOIN "costree_mvp".cost_work_order w
  ON w.tenant_id = c.tenant_id
 AND w.project_code = s.project_code
 AND w.unit_name = u.accounting_unit_name
 AND w.work_order_no = s.work_order_no
WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y');

-- 重新绑定本批账面明细到项目、实际单位和逻辑工作令。
DROP TABLE IF EXISTS pg_temp.tmp_cost_recalc_ledger_link;
CREATE TEMP TABLE tmp_cost_recalc_ledger_link ON COMMIT PRESERVE ROWS AS
SELECT
    s.source_detail_id,
    p.id AS project_id,
    p.project_name,
    u.accounting_unit_code,
    u.accounting_unit_name,
    u.manage_unit_name,
    COALESCE(
        CASE WHEN NULLIF(btrim(s.source_work_order_id), '') IS NOT NULL THEN (
            SELECT min(w1.id) FROM "costree_mvp".cost_work_order w1
            WHERE w1.tenant_id = c.tenant_id
              AND w1.source_work_order_id = btrim(s.source_work_order_id)
        ) ELSE NULL END,
        (
            SELECT min(w2.id) FROM "costree_mvp".cost_work_order w2
            WHERE w2.tenant_id = c.tenant_id
              AND w2.project_code = s.project_code
              AND w2.unit_name = u.accounting_unit_name
              AND w2.work_order_no = s.work_order_no
        )
    ) AS work_order_id
FROM cost_sync_stage_v20261009.stg_ledger_detail s
CROSS JOIN tmp_cost_recalc_context c
LEFT JOIN "costree_mvp".cost_project p
  ON p.tenant_id = c.tenant_id AND p.project_code = s.project_code
LEFT JOIN "costree_mvp".cost_unit_dict u
  ON u.tenant_id = c.tenant_id AND u.accounting_unit_code = s.accounting_unit_code;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM tmp_cost_recalc_ledger_link
        WHERE project_id IS NULL OR accounting_unit_name IS NULL OR work_order_id IS NULL
    ) THEN
        RAISE EXCEPTION '本批账面明细仍有无法绑定项目、实际单位或工作令的记录';
    END IF;
END $$;

UPDATE "costree_mvp".cost_work_order_ledger_detail d
SET project_id = s.project_id,
    project_name = s.project_name,
    accounting_unit_code = s.accounting_unit_code,
    accounting_unit_name = s.accounting_unit_name,
    manage_unit_name = s.manage_unit_name,
    work_order_id = s.work_order_id,
    source_work_order_id = COALESCE(w.source_work_order_id, d.source_work_order_id),
    work_order_no = w.work_order_no,
    work_order_name = COALESCE(d.work_order_name, w.work_order_name),
    resolved_stage_code = w.max_stage_code,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_recalc_ledger_link s
CROSS JOIN tmp_cost_recalc_context c
JOIN "costree_mvp".cost_work_order w ON w.id = s.work_order_id
WHERE (d.tenant_id = c.tenant_id
  AND d.source_detail_id = s.source_detail_id)
  AND d.deleted=0
  AND ROW(d.project_id,d.project_name,d.accounting_unit_code,d.accounting_unit_name,d.manage_unit_name,d.work_order_id,d.source_work_order_id,d.work_order_no,d.work_order_name,d.resolved_stage_code) IS DISTINCT FROM ROW(s.project_id,s.project_name,s.accounting_unit_code,s.accounting_unit_name,s.manage_unit_name,s.work_order_id,COALESCE(w.source_work_order_id, d.source_work_order_id),w.work_order_no,COALESCE(d.work_order_name, w.work_order_name),w.max_stage_code);

-- One final amount write: SUM yuan first; fallback only when raw amount is absent.
UPDATE "costree_mvp".cost_work_order w
SET book_cost_amount=a.book_cost_amount,
    updater=c.source_tag,
    update_time=CURRENT_TIMESTAMP
FROM (
 SELECT x.work_order_id,
        (COALESCE(sum(CASE WHEN d.debit_credit='借' AND d.deleted=0
            THEN COALESCE(d.amount,d.amount_wan*10000.0) ELSE 0 END),0)/10000.0)::numeric(18,2) AS book_cost_amount
 FROM tmp_cost_recalc_work_order x
 CROSS JOIN tmp_cost_recalc_context ctx
 LEFT JOIN "costree_mvp".cost_work_order_ledger_detail d
   ON d.work_order_id=x.work_order_id AND d.tenant_id=ctx.tenant_id
 GROUP BY x.work_order_id
) a
CROSS JOIN tmp_cost_recalc_context c
WHERE (w.id=a.work_order_id)
  AND w.deleted=0
  AND ROW(w.book_cost_amount) IS DISTINCT FROM ROW(a.book_cost_amount);

UPDATE cost_sync_stage_v20261009.sync_control
SET load_status = 'RECALCULATED',
    synced_at = CURRENT_TIMESTAMP,
    remark = '业务同步和借方账面快照重算完成，等待最终验收'
WHERE id = 1;

UPDATE cost_sync_stage_v20261009.sync_history h
SET sync_status = 'RECALCULATED',
    finish_time = NULL,
    remark = '业务同步和借方账面快照重算完成，等待最终验收'
FROM tmp_cost_recalc_context c
WHERE h.batch_code = c.batch_code AND h.tenant_id = c.tenant_id;

SELECT count(*) AS recalculated_work_order_count,
       sum(COALESCE(w.book_cost_amount, 0)) AS total_book_cost_wan
FROM "costree_mvp".cost_work_order w
JOIN tmp_cost_recalc_work_order x ON x.work_order_id = w.id;

SELECT d.debit_credit, count(*) AS detail_count,
       sum(COALESCE(d.amount, d.amount_wan * 10000.0) / 10000.0) AS amount_wan
FROM "costree_mvp".cost_work_order_ledger_detail d
JOIN tmp_cost_recalc_work_order x ON x.work_order_id = d.work_order_id
WHERE d.deleted = 0
GROUP BY d.debit_credit
ORDER BY d.debit_credit;
-- 同步后强制验收。异常时抛错；最后输出本批对账结果。

LOCK TABLE cost_sync_stage_v20261009.sync_control IN EXCLUSIVE MODE;

DO $$
DECLARE
    v_tenant_id int8 := (SELECT tenant_id FROM cost_sync_stage_v20261009.sync_control WHERE id = 1);
BEGIN
    IF (SELECT load_status FROM cost_sync_stage_v20261009.sync_control WHERE id = 1) IS DISTINCT FROM 'RECALCULATED' THEN
        RAISE EXCEPTION '本批状态不是 RECALCULATED，请先完成 05 和 06';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage_v20261009.stg_unit_dict s
        WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND NOT EXISTS (
              SELECT 1 FROM "costree_mvp".cost_unit_dict d
              WHERE d.tenant_id = v_tenant_id AND d.deleted = 0
                AND d.accounting_unit_code = s.accounting_unit_code
          )
    ) THEN
        RAISE EXCEPTION '验收失败：存在活动单位未写入业务表';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage_v20261009.stg_project s
        WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND NOT EXISTS (
              SELECT 1 FROM "costree_mvp".cost_project p
              WHERE p.tenant_id = v_tenant_id AND p.deleted = 0
                AND p.project_code = s.project_code
          )
    ) THEN
        RAISE EXCEPTION '验收失败：存在活动项目未写入业务表';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM cost_sync_stage_v20261009.stg_unit_amount s
        JOIN "costree_mvp".cost_unit_dict u
          ON u.tenant_id = v_tenant_id AND u.accounting_unit_code = s.accounting_unit_code
        JOIN "costree_mvp".cost_unit_cost_detail d
          ON d.tenant_id = v_tenant_id AND d.project_code = s.project_code
         AND d.unit_name = u.accounting_unit_name
        WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND (
              abs(COALESCE(d.contract_amount, 0) - COALESCE(NULLIF(btrim(s.contract_amount_wan), '')::numeric, 0)) > 0.01
              OR abs(COALESCE(d.income_amount, 0) - COALESCE(NULLIF(btrim(s.income_amount_wan), '')::numeric, 0)) > 0.01
          )
    ) THEN
        RAISE EXCEPTION '验收失败：单位合同或到款与本批快照不一致';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage_v20261009.stg_work_order s
        JOIN "costree_mvp".cost_unit_dict u
          ON u.tenant_id = v_tenant_id AND u.accounting_unit_code = s.accounting_unit_code
        WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND NOT EXISTS (
              SELECT 1 FROM "costree_mvp".cost_work_order w
              WHERE w.tenant_id = v_tenant_id AND w.deleted = 0
                AND w.project_code = s.project_code
                AND w.unit_name = u.accounting_unit_name
                AND w.work_order_no = s.work_order_no
          )
    ) THEN
        RAISE EXCEPTION '验收失败：存在活动工作令未写入业务表';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage_v20261009.stg_ledger_detail s
        WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND NOT EXISTS (
              SELECT 1 FROM "costree_mvp".cost_work_order_ledger_detail d
              WHERE d.tenant_id = v_tenant_id AND d.deleted = 0
                AND d.source_detail_id = s.source_detail_id
          )
    ) THEN
        RAISE EXCEPTION '验收失败：存在活动账面明细未写入业务表';
    END IF;

    IF EXISTS (
        SELECT 1 FROM "costree_mvp".cost_work_order_ledger_detail d
        WHERE d.tenant_id = v_tenant_id AND d.deleted = 0
          AND d.source_detail_id IN (SELECT source_detail_id FROM cost_sync_stage_v20261009.stg_ledger_detail)
          AND abs(COALESCE(d.amount_wan, 0) - COALESCE(d.amount, 0) / 10000.0) > 0.01
    ) THEN
        RAISE EXCEPTION '验收失败：账面元和万元换算不一致';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM "costree_mvp".cost_work_order w
        JOIN (
            SELECT w2.id AS work_order_id,
                   COALESCE(sum(CASE WHEN d.debit_credit = '借' AND d.deleted = 0
                                     THEN COALESCE(d.amount, d.amount_wan * 10000.0) / 10000.0
                                     ELSE 0 END), 0)::numeric(18,2) AS expected_book
            FROM cost_sync_stage_v20261009.stg_work_order s
            JOIN "costree_mvp".cost_unit_dict u
              ON u.tenant_id = v_tenant_id AND u.accounting_unit_code = s.accounting_unit_code
            JOIN "costree_mvp".cost_work_order w2
              ON w2.tenant_id = v_tenant_id AND w2.project_code = s.project_code
             AND w2.unit_name = u.accounting_unit_name AND w2.work_order_no = s.work_order_no
            LEFT JOIN "costree_mvp".cost_work_order_ledger_detail d
              ON d.tenant_id = v_tenant_id AND d.work_order_id = w2.id
            WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
            GROUP BY w2.id
        ) x ON x.work_order_id = w.id
        WHERE abs(COALESCE(w.book_cost_amount, 0) - x.expected_book) > 0.01
    ) THEN
        RAISE EXCEPTION '验收失败：工作令账面快照不等于全部年度借方明细合计';
    END IF;
END $$;

DROP TABLE IF EXISTS pg_temp.tmp_cost_current_manual_baseline;
CREATE TEMP TABLE tmp_cost_current_manual_baseline
(
    object_name  varchar(64) NOT NULL,
    record_id    int8        NOT NULL,
    digest_value varchar(32) NOT NULL
) ON COMMIT DELETE ROWS;

INSERT INTO tmp_cost_current_manual_baseline(object_name, record_id, digest_value)
SELECT baseline.object_name, baseline.record_id,
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
       )::text)
FROM cost_sync_stage_v20261009.sync_control control
JOIN cost_sync_stage_v20261009.manual_field_baseline baseline
  ON baseline.batch_code = control.batch_code AND baseline.tenant_id = control.tenant_id
 AND baseline.object_name = 'project_basic'
JOIN "costree_mvp".cost_project_basic basic
  ON basic.tenant_id = control.tenant_id AND basic.id = baseline.record_id
WHERE control.id = 1
UNION ALL
SELECT baseline.object_name, baseline.record_id,
       md5(ROW(
           project.id, project.project_code, project.batch_no, project.stage_codes,
           project.unit_id, project.unit_name, project.unit_type,
           project.project_office_status, project.unit_fill_status, project.audit_status,
           project.dept_id, project.owner_user_id, project.warning_status,
           project.remark
       )::text)
FROM cost_sync_stage_v20261009.sync_control control
JOIN cost_sync_stage_v20261009.manual_field_baseline baseline
  ON baseline.batch_code = control.batch_code AND baseline.tenant_id = control.tenant_id
 AND baseline.object_name = 'project_state'
JOIN "costree_mvp".cost_project project
  ON project.tenant_id = control.tenant_id AND project.id = baseline.record_id
WHERE control.id = 1
UNION ALL
SELECT baseline.object_name, baseline.record_id,
       md5(ROW(
           unit_cost.id,
           unit_cost.target_cost_amount, unit_cost.approved_amount, unit_cost.book_cost_amount,
           unit_cost.salary_amount, unit_cost.material_amount, unit_cost.outsource_amount,
           unit_cost.manage_amount, unit_cost.fuel_power_amount, unit_cost.other_amount,
           unit_cost.remark, unit_cost.deleted
       )::text)
FROM cost_sync_stage_v20261009.sync_control control
JOIN cost_sync_stage_v20261009.manual_field_baseline baseline
  ON baseline.batch_code = control.batch_code AND baseline.tenant_id = control.tenant_id
 AND baseline.object_name = 'unit_fill'
JOIN "costree_mvp".cost_unit_cost_detail unit_cost
  ON unit_cost.tenant_id = control.tenant_id AND unit_cost.id = baseline.record_id
WHERE control.id = 1
UNION ALL
SELECT baseline.object_name, baseline.record_id,
       md5(ROW(
           work_order.id, work_order.product_target_cost,
           work_order.contract_amount, work_order.income_amount, work_order.approved_amount,
           work_order.stage_codes, work_order.max_stage_code, work_order.subsystem_name,
           work_order.product_short_name, work_order.quantity, work_order.vertical_division,
           work_order.status, work_order.remark, work_order.import_batch_id,
           work_order.dept_id, work_order.owner_user_id, work_order.deleted
       )::text)
FROM cost_sync_stage_v20261009.sync_control control
JOIN cost_sync_stage_v20261009.manual_field_baseline baseline
  ON baseline.batch_code = control.batch_code AND baseline.tenant_id = control.tenant_id
 AND baseline.object_name = 'work_order_fill'
JOIN "costree_mvp".cost_work_order work_order
  ON work_order.tenant_id = control.tenant_id AND work_order.id = baseline.record_id
WHERE control.id = 1
UNION ALL
SELECT baseline.object_name, baseline.record_id,
       md5(ROW(
           warning.id, warning.project_id, warning.work_order_id, warning.warning_source,
           warning.warning_title, warning.target_cost_amount, warning.actual_cost_amount,
           warning.over_amount, warning.over_rate, warning.threshold_rate,
           warning.warning_level, warning.responsible_unit_name, warning.push_status,
           warning.pushed_time, warning.receiver_scope, warning.message_id,
           warning.status, warning.remark, warning.creator, warning.create_time,
           warning.updater, warning.update_time, warning.deleted
       )::text)
FROM cost_sync_stage_v20261009.sync_control control
JOIN cost_sync_stage_v20261009.manual_field_baseline baseline
  ON baseline.batch_code = control.batch_code AND baseline.tenant_id = control.tenant_id
 AND baseline.object_name = 'warning_state'
JOIN "costree_mvp".cost_warning_record warning
  ON warning.tenant_id = control.tenant_id AND warning.id = baseline.record_id
WHERE control.id = 1;

DO $$
DECLARE
    v_mismatch text;
BEGIN
    SELECT string_agg(baseline.object_name || '#' || baseline.record_id::text, ', ')
      INTO v_mismatch
    FROM cost_sync_stage_v20261009.sync_control control
    JOIN cost_sync_stage_v20261009.manual_field_baseline baseline
      ON baseline.batch_code = control.batch_code
     AND baseline.tenant_id = control.tenant_id
    LEFT JOIN tmp_cost_current_manual_baseline current_baseline
      ON current_baseline.object_name = baseline.object_name
     AND current_baseline.record_id = baseline.record_id
    WHERE control.id = 1
      AND (current_baseline.record_id IS NULL
           OR baseline.digest_value <> current_baseline.digest_value);

    IF v_mismatch IS NOT NULL THEN
        RAISE EXCEPTION '验收失败：常规同步改动了成本库手工字段或流程状态：%', v_mismatch;
    END IF;

    IF (SELECT count(*) FROM cost_sync_stage_v20261009.sync_control control
        JOIN cost_sync_stage_v20261009.manual_field_digest digest
          ON digest.batch_code = control.batch_code AND digest.tenant_id = control.tenant_id
        WHERE control.id = 1) <> 5 THEN
        RAISE EXCEPTION '验收失败：同步前手工字段摘要不完整，拒绝标记 SUCCESS';
    END IF;

    IF (SELECT COALESCE(sum(digest.row_count), 0)
        FROM cost_sync_stage_v20261009.sync_control control
        JOIN cost_sync_stage_v20261009.manual_field_digest digest
          ON digest.batch_code = control.batch_code AND digest.tenant_id = control.tenant_id
        WHERE control.id = 1) <>
       (SELECT count(*)
        FROM cost_sync_stage_v20261009.sync_control control
        JOIN cost_sync_stage_v20261009.manual_field_baseline baseline
          ON baseline.batch_code = control.batch_code AND baseline.tenant_id = control.tenant_id
        WHERE control.id = 1) THEN
        RAISE EXCEPTION '验收失败：手工字段摘要与逐行基线不一致';
    END IF;
END $$;

UPDATE cost_sync_stage_v20261009.sync_control
SET load_status = 'SUCCESS',
    synced_at = CURRENT_TIMESTAMP,
    remark = '业务同步、借方账面快照重算和最终验收完成'
WHERE id = 1;

UPDATE cost_sync_stage_v20261009.sync_history h
SET sync_status = 'SUCCESS',
    finish_time = CURRENT_TIMESTAMP,
    remark = '业务同步、借方账面快照重算和最终验收完成'
FROM cost_sync_stage_v20261009.sync_control c
WHERE c.id = 1
  AND h.batch_code = c.batch_code
  AND h.tenant_id = c.tenant_id;

SELECT 'sync accepted' AS result, tenant_id, batch_code, load_status, loaded_at, synced_at
FROM cost_sync_stage_v20261009.sync_control
WHERE id = 1;

SELECT 'unit_dict' AS object_name, count(*) AS stage_rows
FROM cost_sync_stage_v20261009.stg_unit_dict
UNION ALL SELECT 'model_node', count(*) FROM cost_sync_stage_v20261009.stg_model_node
UNION ALL SELECT 'project', count(*) FROM cost_sync_stage_v20261009.stg_project
UNION ALL SELECT 'unit_amount', count(*) FROM cost_sync_stage_v20261009.stg_unit_amount
UNION ALL SELECT 'work_order', count(*) FROM cost_sync_stage_v20261009.stg_work_order
UNION ALL SELECT 'ledger_detail', count(*) FROM cost_sync_stage_v20261009.stg_ledger_detail
ORDER BY object_name;

SELECT d.debit_credit, count(*) AS detail_count,
       sum(COALESCE(d.amount, d.amount_wan * 10000.0) / 10000.0) AS amount_wan
FROM "costree_mvp".cost_work_order_ledger_detail d
JOIN cost_sync_stage_v20261009.stg_ledger_detail s ON s.source_detail_id = d.source_detail_id
CROSS JOIN cost_sync_stage_v20261009.sync_control c
WHERE c.id = 1 AND d.tenant_id = c.tenant_id AND d.deleted = 0
GROUP BY d.debit_credit
ORDER BY d.debit_credit;

SELECT
    COALESCE(substr(NULLIF(d.second_subject_code, ''), 1, 6), substr(NULLIF(d.subject_code, ''), 1, 6), 'UNCLASSIFIED') AS item_code,
    count(*) AS detail_count,
    sum(COALESCE(d.amount, d.amount_wan * 10000.0) / 10000.0) AS amount_wan
FROM "costree_mvp".cost_work_order_ledger_detail d
JOIN cost_sync_stage_v20261009.stg_ledger_detail s ON s.source_detail_id = d.source_detail_id
CROSS JOIN cost_sync_stage_v20261009.sync_control c
WHERE c.id = 1 AND d.tenant_id = c.tenant_id
  AND d.deleted = 0 AND d.debit_credit = '借'
GROUP BY COALESCE(substr(NULLIF(d.second_subject_code, ''), 1, 6), substr(NULLIF(d.subject_code, ''), 1, 6), 'UNCLASSIFIED')
ORDER BY item_code;

SELECT batch_code, tenant_id, stage_row_count, sync_status, start_time, finish_time, remark
FROM cost_sync_stage_v20261009.sync_history
ORDER BY start_time DESC;

COMMIT;
