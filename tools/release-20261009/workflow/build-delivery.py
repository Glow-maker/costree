"""Maintainer-only: derive reviewed delivery templates from the existing snapshot package.
Does not connect to a database. Operators use render-workflow.py, not this builder.
"""
from pathlib import Path
import hashlib
import json
import re

OUT = Path(__file__).resolve().parent
BASE = OUT.parents[2] / 'deploy/cost-server-offline-template/database/postgresql92/03-data-integration/snapshot-upsert'
T = OUT / 'templates'
T.mkdir(parents=True, exist_ok=True)

def read(n):
    return next(BASE.glob(f'{n:02d}-*')).read_text(encoding='utf-8-sig').replace(
        'PostgreSQL 9.2.4 / GaussDB 8.2.1 兼容',
        '目标方言：PostgreSQL 9.2.4 / GaussDB 8.2.1（现场引擎兼容性待验）')

def write(name, text):
    (T / name).write_text(text.replace('cost_sync_stage', 'cost_sync_stage_v20261009'), encoding='utf-8')

def body(n):
    s = read(n)
    s = re.sub(r'^BEGIN;\s*', '', s, flags=re.M)
    s = re.sub(r'^COMMIT;\s*', '', s, flags=re.M)
    return s

guard = """DO $$
BEGIN
  IF '__BATCH_CODE__' LIKE 'REPLACE%' THEN RAISE EXCEPTION '必须生成本批参数'; END IF;
  IF NOT EXISTS (SELECT 1 FROM cost_sync_stage.sync_control
      WHERE id=1 AND tenant_id=__TENANT_ID__ AND batch_code='__BATCH_CODE__'
        AND load_status='LOADING') THEN
    RAISE EXCEPTION '批次不一致或不是 LOADING；停止，不能串批';
  END IF;
END $$;
"""

setup = read(1)
setup = setup.replace('COMMIT;', """CREATE TABLE IF NOT EXISTS cost_sync_stage.load_receipt (
 batch_code varchar(64) NOT NULL, stage_table varchar(64) NOT NULL,
 row_count bigint NOT NULL, expected_rows bigint NOT NULL,
 snapshot_tag varchar(128) NOT NULL, finished_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY (batch_code, stage_table)
);
CREATE TABLE IF NOT EXISTS cost_sync_stage.batch_register (
 batch_code varchar(64) PRIMARY KEY, tenant_id bigint NOT NULL,
 snapshot_tag varchar(128) NOT NULL, started_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMIT;""")
write('00-setup.sql', setup)

start = """-- 一个批次只启动一次；默认占位值不能执行。失败批次先查原因，不得自动清空重开。
BEGIN;
LOCK TABLE cost_sync_stage.sync_control IN EXCLUSIVE MODE;
DO $$ BEGIN
 IF '__BATCH_CODE__' LIKE 'REPLACE%' OR '__SNAPSHOT_TAG__' LIKE 'REPLACE%' THEN
   RAISE EXCEPTION '批次号和一致快照标识未适配';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM cost_sync_stage.sync_control WHERE id=1
    AND load_status IN ('EMPTY','SUCCESS','ABORTED')) THEN
   RAISE EXCEPTION '上一批仍在处理或失败待核查，拒绝并发/自动重置';
 END IF;
END $$;
INSERT INTO cost_sync_stage.batch_register(batch_code,tenant_id,snapshot_tag)
VALUES ('__BATCH_CODE__',__TENANT_ID__,'__SNAPSHOT_TAG__');
TRUNCATE TABLE cost_sync_stage.stg_unit_dict,cost_sync_stage.stg_model_node,
 cost_sync_stage.stg_project,cost_sync_stage.stg_unit_amount,
 cost_sync_stage.stg_work_order,cost_sync_stage.stg_ledger_detail;
UPDATE cost_sync_stage.sync_control SET tenant_id=__TENANT_ID__,batch_code='__BATCH_CODE__',
 source_tag='cost_snapshot_sync',load_status='LOADING',loaded_at=NULL,synced_at=NULL,
 remark='20261009 完整快照装载；任何业务更新尚未开始' WHERE id=1;
COMMIT;
SELECT * FROM cost_sync_stage.sync_control WHERE id=1;
"""
write('10-begin-batch.sql', start)

load = read(3)
inserts = re.findall(r'INSERT INTO cost_sync_stage\.(stg_\w+)\s*\([\s\S]*?;', load)
full = re.findall(r'(INSERT INTO cost_sync_stage\.stg_\w+\s*\([\s\S]*?;)', load)
assert len(inserts) == len(full) == 6
mapping = '-- 唯一可编辑的源 SELECT 区。保留六个标记与 INSERT 目标列，不改成写业务表。\n'
for table, sql in zip(inserts, full):
    mapping += f'\n-- BEGIN SOURCE {table}\n{sql}\n-- END SOURCE {table}\n'
(OUT / 'source-mapping.sql').write_text(mapping, encoding='utf-8')

order = ['stg_model_node','stg_project','stg_unit_dict','stg_unit_amount','stg_work_order','stg_ledger_detail']
for i, table in enumerate(order, 1):
    text = f"""-- 仅装载 {table}，不得混入业务表更新。完整 SQL 在同一连接执行。
BEGIN;
LOCK TABLE cost_sync_stage.sync_control IN EXCLUSIVE MODE;
{guard}
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM cost_sync_stage.load_receipt
   WHERE batch_code='__BATCH_CODE__' AND stage_table='{table}') THEN
   RAISE EXCEPTION '本源已成功装载，不可再次追加；请跳过该成功节点';
 END IF;
END $$;
TRUNCATE TABLE cost_sync_stage.{table};
__SOURCE_{table}__
DO $$ DECLARE v_count bigint; BEGIN
 SELECT count(*) INTO v_count FROM cost_sync_stage.{table};
 IF v_count <> __COUNT_{table}__ THEN
   RAISE EXCEPTION '完整性失败 {table}: expected=%, actual=%',__COUNT_{table}__,v_count;
 END IF;
END $$;
INSERT INTO cost_sync_stage.load_receipt(batch_code,stage_table,row_count,expected_rows,snapshot_tag)
SELECT '__BATCH_CODE__','{table}',count(*),__COUNT_{table}__,'__SNAPSHOT_TAG__'
FROM cost_sync_stage.{table};
COMMIT;
"""
    write(f'{20+i:02d}-load-{table}.template.sql', text)

pre = """-- FINAL NODE: one connection, one transaction. No cross-node transaction assumption.
BEGIN;
SET LOCAL statement_timeout='15min';
LOCK TABLE cost_sync_stage.sync_control IN EXCLUSIVE MODE;
__GUARD__
LOCK TABLE cost_sync_stage.stg_unit_dict,cost_sync_stage.stg_model_node,
 cost_sync_stage.stg_project,cost_sync_stage.stg_unit_amount,
 cost_sync_stage.stg_work_order,cost_sync_stage.stg_ledger_detail IN SHARE MODE;
DO $$ BEGIN
 IF (SELECT count(*) FROM cost_sync_stage.load_receipt
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
UPDATE cost_sync_stage.sync_control SET load_status='READY',loaded_at=CURRENT_TIMESTAMP WHERE id=1;
""".replace('__GUARD__', guard)

checks = """-- Additional safety checks before any business write.
DO $$
DECLARE r record; v_sql text; v_bad boolean; v_seq text; v_next numeric;
 v_max numeric; v_increment bigint; v_cycle boolean; v_limit numeric; v_last numeric;
BEGIN
 FOR r IN SELECT * FROM (VALUES
 ('stg_unit_dict','accounting_unit_code'),('stg_model_node','node_code'),
 ('stg_project','project_code'),('stg_unit_amount','source_record_id'),
 ('stg_work_order','source_work_order_id'),('stg_ledger_detail','source_detail_id')) AS x(tbl,keycol)
 LOOP
   EXECUTE 'SELECT EXISTS(SELECT 1 FROM cost_sync_stage.'||quote_ident(r.tbl)||
     ' WHERE '||quote_ident(r.keycol)||' IS NULL OR btrim('||quote_ident(r.keycol)||')='''')'
     INTO v_bad;
   IF v_bad THEN RAISE EXCEPTION '缺少稳定源业务键 %.%',r.tbl,r.keycol; END IF;
   EXECUTE 'SELECT EXISTS(SELECT 1 FROM cost_sync_stage.'||quote_ident(r.tbl)||
     ' GROUP BY btrim('||quote_ident(r.keycol)||') HAVING count(*)>1)' INTO v_bad;
   IF v_bad THEN RAISE EXCEPTION '规范化后稳定源键重复 %.%',r.tbl,r.keycol; END IF;
   EXECUTE 'SELECT EXISTS(SELECT 1 FROM cost_sync_stage.'||quote_ident(r.tbl)||
     ' WHERE NULLIF(btrim(source_deleted),'''') IS NOT NULL AND lower(btrim(source_deleted)) NOT IN (''0'',''false'',''f'',''否'',''no'',''n''))' INTO v_bad;
   IF v_bad THEN RAISE EXCEPTION '源删除语义尚未批准或标志非法：% 本批停止，不能自动删/停业务数据',r.tbl; END IF;
 END LOOP;
 -- No implicit truncation of long external identifiers to varchar(128).
 FOR r IN SELECT table_name,column_name FROM information_schema.columns
    WHERE table_schema='cost_sync_stage' AND table_name LIKE 'stg_%'
      AND (column_name LIKE '%code' OR column_name LIKE '%_id' OR column_name='work_order_no')
 LOOP
   EXECUTE 'SELECT EXISTS(SELECT 1 FROM cost_sync_stage.'||quote_ident(r.table_name)||
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
   v_seq := substring(r.column_default FROM '^nextval\\(''([^'']+)''::regclass\\)$');
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
 IF EXISTS (SELECT 1 FROM cost_sync_stage.stg_model_node n
    JOIN cost_sync_stage.stg_model_node p ON btrim(p.node_code)=btrim(n.parent_node_code)
    WHERE (n.node_type='SERIES' AND p.node_type<>'DOMAIN')
       OR (n.node_type='MODEL' AND p.node_type<>'SERIES')) THEN
    RAISE EXCEPTION '树层级必须 DOMAIN→SERIES→MODEL，不能任意推断父节点';
 END IF;
END $$;
-- Normalize business keys once, using the exact same form used by target matching.
"""
for table, cols in {
 'stg_unit_dict':['accounting_unit_code','accounting_unit_name'],
 'stg_model_node':['node_code','parent_node_code','node_type'],
 'stg_project':['project_code','model_node_code'],
 'stg_unit_amount':['source_record_id','project_code','accounting_unit_code'],
 'stg_work_order':['source_work_order_id','project_code','accounting_unit_code','work_order_no'],
 'stg_ledger_detail':['source_detail_id','source_work_order_id','project_code','accounting_unit_code','work_order_no'],
}.items():
    checks += f"UPDATE cost_sync_stage.{table} SET "+','.join(f'{c}=btrim({c})' for c in cols)+';\n'
checks += """DO $$ BEGIN
 IF EXISTS(SELECT a.project_code,u.accounting_unit_name FROM cost_sync_stage.stg_unit_amount a
   JOIN cost_sync_stage.stg_unit_dict u ON u.accounting_unit_code=a.accounting_unit_code
   GROUP BY a.project_code,u.accounting_unit_name HAVING count(*)>1) THEN
   RAISE EXCEPTION '同名历史单位异码归一到同一项目单位金额键；禁止 SUM/MAX/任选一条，请人工确认源权威记录';
 END IF;
 IF EXISTS(SELECT w.project_code,u.accounting_unit_name,w.work_order_no FROM cost_sync_stage.stg_work_order w
   JOIN cost_sync_stage.stg_unit_dict u ON u.accounting_unit_code=w.accounting_unit_code
   GROUP BY w.project_code,u.accounting_unit_name,w.work_order_no HAVING count(*)>1) THEN
   RAISE EXCEPTION '同名历史单位异码归一到同一工作令键；必须显式映射，不能按名称自动合并';
 END IF;
 IF EXISTS(SELECT 1 FROM cost_sync_stage.stg_ledger_detail d
   JOIN cost_sync_stage.stg_work_order w ON w.source_work_order_id=d.source_work_order_id
   WHERE (w.project_code,w.accounting_unit_code,w.work_order_no)
     IS DISTINCT FROM (d.project_code,d.accounting_unit_code,d.work_order_no)) THEN
   RAISE EXCEPTION '账面源工作令ID与项目/实际单位编码/工作令号矛盾';
 END IF;
END $$;
"""

for tbl, idcol, keys in [
 ('cost_unit_cost_detail','source_record_id',['project_code','unit_name']),
 ('cost_work_order','source_work_order_id',['project_code','unit_name','work_order_no']),
]:
    checks += f"""DO $$ BEGIN
 IF EXISTS(SELECT {idcol} FROM "costree_mvp".{tbl} WHERE tenant_id=__TENANT_ID__
   AND NULLIF(btrim({idcol}),'') IS NOT NULL GROUP BY {idcol} HAVING count(*)>1) THEN
   RAISE EXCEPTION '目标表 {tbl} 稳定源 ID 不唯一';
 END IF;
 IF EXISTS(SELECT 1 FROM "costree_mvp".{tbl} WHERE tenant_id=__TENANT_ID__ AND (
 {' OR '.join(f'{k} IS DISTINCT FROM btrim({k})' for k in keys)})) THEN
   RAISE EXCEPTION '目标表 {tbl} 业务键包含首尾空格，先核查不能另建重复记录';
 END IF;
END $$;
"""

for tbl,key in [('cost_unit_dict','accounting_unit_code'),('cost_model_node','node_code'),
                ('cost_project','project_code'),('cost_work_order_ledger_detail','source_detail_id')]:
    checks+=f"""DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM "costree_mvp".{tbl} WHERE tenant_id=__TENANT_ID__
   AND {key} IS DISTINCT FROM btrim({key})) THEN
   RAISE EXCEPTION '目标 {tbl}.{key} 含首尾空格，不能新建重复记录';
 END IF;
END $$;
"""

sync = body(5)
for tmp, table, alias, idcol, keys in [
 ('tmp_cost_sync_amount_match','cost_unit_cost_detail','x','source_record_id',['project_code','unit_name']),
 ('tmp_cost_sync_work_order_match','cost_work_order','w','source_work_order_id',['project_code','unit_name','work_order_no']),
]:
    gate = f"""DO $$ BEGIN
 IF EXISTS(SELECT target_id FROM {tmp} WHERE target_id IS NOT NULL GROUP BY target_id HAVING count(*)>1) THEN
   RAISE EXCEPTION '{table}: 多源命中同一个 target_id，拒绝不确定更新';
 END IF;
 IF EXISTS(SELECT 1 FROM {tmp} s JOIN "costree_mvp".{table} old ON old.id=s.target_id
    WHERE ({','.join('old.'+k for k in keys)}) IS DISTINCT FROM ({','.join('s.'+k for k in keys)})
      OR old.deleted<>0 OR (NULLIF(old.{idcol},'') IS NOT NULL AND old.{idcol} IS DISTINCT FROM s.{idcol})) THEN
   RAISE EXCEPTION '{table}: 源ID与逻辑键冲突、源ID换代或目标已逻辑删除；人工核查，不迁移手填/不复活';
 END IF;
END $$;
"""
    needle = f'UPDATE "costree_mvp".{table} {alias}\n'
    assert needle in sync
    sync = sync.replace(needle, gate+'\n'+needle, 1)

# Do not restore any logical deletion. Default policy rejects all source tombstones.
sync = sync.replace('    deleted = s.deleted,\n','')
sync = sync.replace("domain_code = CASE WHEN s.node_type = 'DOMAIN' THEN s.node_code ELSE s.domain_code END,",
                    "domain_code = CASE WHEN s.node_type = 'DOMAIN' THEN s.node_code ELSE n.domain_code END,")

# Keep raw yuan authoritative. Round once at the destination work-order amount.
recalc = body(6)
zero_start = recalc.index('-- 先把本批活动工作令清零')
zero_end = recalc.index('UPDATE cost_sync_stage.sync_control', zero_start)
recalc = recalc[:zero_start] + """-- One final amount write: SUM yuan first; fallback only when raw amount is absent.
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
WHERE w.id=a.work_order_id;

""" + recalc[zero_end:]
verify = body(7)
for name in ['recalc','verify']:
    s=locals()[name].replace('COALESCE(d.amount_wan, d.amount / 10000.0)', 'COALESCE(d.amount, d.amount_wan * 10000.0) / 10000.0')
    locals()[name]=s

# Add book_cost_amount to the protected unit-fill baseline on BOTH sides.
precheck = body(4).replace('unit_cost.target_cost_amount, unit_cost.approved_amount,',
    'unit_cost.target_cost_amount, unit_cost.approved_amount, unit_cost.book_cost_amount,')
verify = verify.replace('unit_cost.target_cost_amount, unit_cost.approved_amount,',
    'unit_cost.target_cost_amount, unit_cost.approved_amount, unit_cost.book_cost_amount,')

def split_assignments(s):
    result=[]; start=0; depth=0; quoted=False; i=0
    while i<len(s):
        c=s[i]
        if c=="'":
            if quoted and i+1<len(s) and s[i+1]=="'": i+=2; continue
            quoted=not quoted
        if not quoted:
            if c=='(': depth+=1
            if c==')': depth-=1
            if c==',' and depth==0: result.append(s[start:i]); start=i+1
        i+=1
    result.append(s[start:]); return result

def differences(s):
    def change(m):
        table,alias,sets,frm,where=m.groups()
        pairs=[x.strip().split('=',1) for x in split_assignments(sets)]
        pairs=[(a.strip(),b.strip()) for a,b in pairs if a.strip() not in ('updater','update_time')]
        assert pairs
        old=','.join(alias+'.'+a for a,b in pairs); new=','.join(b for a,b in pairs)
        return f'UPDATE {table} {alias}\nSET {sets}\nFROM {frm}\nWHERE ({where})\n  AND {alias}.deleted=0\n  AND ROW({old}) IS DISTINCT FROM ROW({new});'
    return re.sub(r'UPDATE ("costree_mvp"\.\w+) (\w+)\nSET ([\s\S]*?)\nFROM ([\s\S]*?)\nWHERE ([\s\S]*?);', change,s)

atomic = pre+checks+precheck+differences(sync)+differences(recalc)+verify+'\nCOMMIT;\n'
atomic = re.sub(r'DROP TABLE IF EXISTS (tmp_\w+);',r'DROP TABLE IF EXISTS pg_temp.\1;',atomic)
write('90-atomic-sync.template.sql',atomic)
write('95-missing-report.sql',read(8).replace('确认源系统明确状态后，再随下一批传 source_deleted/disabled。',
 '默认遇到源删除标志停止；缺失和删除均需现场评审，不进入自动日常删除。'))

abort = """-- Manual recovery only: STOP scheduler and all active nodes BEFORE using this file.
-- Never use as automatic failure handler. No business table is changed.
BEGIN;
LOCK TABLE cost_sync_stage.sync_control IN EXCLUSIVE MODE;
DO $$ BEGIN
 IF '__BATCH_CODE__' LIKE 'REPLACE%' THEN RAISE EXCEPTION '必须指定要放弃的确切批次'; END IF;
 IF NOT EXISTS(SELECT 1 FROM cost_sync_stage.sync_control WHERE id=1
     AND batch_code='__BATCH_CODE__' AND tenant_id=__TENANT_ID__ AND load_status='LOADING') THEN
   RAISE EXCEPTION '只能放弃本版未提交的 LOADING 批次；其它状态须单独调查';
 END IF;
END $$;
UPDATE cost_sync_stage.sync_control SET load_status='ABORTED',remark='人工确认停止所有节点后放弃；业务数据未改' WHERE id=1;
COMMIT;
"""
write('99-manual-abort.template.sql',abort)

manifest=[]
for n in [1,2,3,4,5,6,7,8]:
    f=next(BASE.glob(f'{n:02d}-*'))
    manifest.append({'path':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
(OUT/'provenance.json').write_text(json.dumps({'base_files':manifest,'note':'交付副本增加安全门禁/合并事务/差异写入/金额精度修正；旧文件未修改'},ensure_ascii=False,indent=2),encoding='utf-8')
print('Generated',len(list(T.glob('*.sql'))),'SQL templates; source mapping and provenance saved')
