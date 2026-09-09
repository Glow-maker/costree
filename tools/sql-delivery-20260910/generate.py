"""Generate SQL only. Never builds or replaces application/offline ZIP artifacts."""
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT.parent / 'sqlbot_with_bcback/baback'
DEPLOY = BACKEND / 'sql/postgresql92/costree-deploy'
OUT = ROOT / 'note/80-deployment/20260910-cost-upgrade'
OUT.mkdir(parents=True, exist_ok=True)
read = lambda p: p.read_text(encoding='utf-8-sig')
baseline = read(BACKEND / 'sql/postgresql92/costree-cost.sql')
roles = read(DEPLOY / '17-cost-local-roles-20260907.sql')
tables = dict(re.findall(r'CREATE TABLE IF NOT EXISTS (\w+)\s*(\([\s\S]*?\));', baseline))
for name, body in re.findall(r"EXECUTE 'CREATE TABLE IF NOT EXISTS (\w+) (\([\s\S]*?\))' \|\| distribution;", roles):
    tables[name] = body.replace("''", "'")
assert len(tables) == 20, list(tables)
comments = re.findall(r"(?m)^COMMENT ON (?:TABLE|COLUMN) [a-z0-9_.]+ IS '(?:[^']|'')*';", read(BACKEND / 'yudao-module-cost/sql/DDL.sql'))

def literal(value):
    return "'" + value.replace("'", "''") + "'"

header = """-- PostgreSQL 9.2+ / GaussDB(DWS). SQL only; not MySQL or DM.
-- CHANGE public below to the schema actually used by cost-server, not the database name.
-- Execute as a whole with stop-on-error; stop cost writes first and keep your backup.
BEGIN;
SET LOCAL search_path TO "public";
DO $schema_guard$ BEGIN
 IF current_schema() IS NULL THEN RAISE EXCEPTION 'Target schema does not exist or is inaccessible'; END IF;
END $schema_guard$;
"""

def split_columns(body):
    parts, start, depth, quoted = [], 1, 0, False
    i = 1
    while i < len(body)-1:
        c = body[i]
        if c == "'":
            if quoted and i+1 < len(body) and body[i+1] == "'":
                i += 2
                continue
            quoted = not quoted
        if not quoted:
            if c == '(': depth += 1
            if c == ')': depth -= 1
            if c == ',' and depth == 0:
                parts.append(body[start:i].strip()); start = i+1
        i += 1
    parts.append(body[start:-1].strip())
    return parts

creation = ''
columns = []
for name, body in tables.items():
    sequence = re.findall(r"nextval\('([^']+)'\)", body)
    key = 'tenant_id' if name in ('cost_user_role', 'cost_user_role_action', 'cost_auth_user_lock') else 'id'
    # The migration ledger has no id; keep it local/replicated as in the canonical baseline.
    distributed = name != 'cost_schema_migration'
    statements = []
    for seq in sequence:
        statements.append(f"  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='{seq}' AND c.relkind='S') THEN EXECUTE 'CREATE SEQUENCE ' || quote_ident(current_schema()) || '.{seq}'; END IF;")
    sql = 'CREATE TABLE ' + name + ' ' + body
    creation += f"\n-- Create only when absent: {name}\nDO $create_missing$\nDECLARE suffix text := '';\nBEGIN\n IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=current_schema() AND c.relname='{name}') THEN\n"
    creation += '\n'.join(statements) + '\n'
    if distributed:
        creation += f"  IF lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN suffix := ' WITH (orientation=row) DISTRIBUTE BY HASH ({key})'; END IF;\n"
    creation += f"  EXECUTE {literal(sql)} || suffix;\n"
    for comment in comments:
        if re.match(r"COMMENT ON (?:TABLE|COLUMN) " + name + r"(?:[. ]|$)", comment):
            creation += "  EXECUTE " + literal(comment) + ";\n"
    creation += " END IF;\nEND $create_missing$;\n"
    for col in split_columns(body):
        if col.upper().startswith(('CONSTRAINT ', 'PRIMARY ', 'UNIQUE ', 'CHECK ', 'FOREIGN ')):
            continue
        colname, definition = col.split(None, 1)
        columns.append((name, colname, definition))

backup = header + '-- NO migration gates, ALTER/UPDATE/DELETE/INSERT, or sequence resets.\n' + creation + '\nCOMMIT;\n'
(OUT / '02-backup-create-missing-tables.sql').write_text(backup, encoding='utf-8')

repair = '\n-- Reconcile missing columns from current canonical schema; independent of migration versions.\n'
repair += 'DO $missing_columns$\nDECLARE spec record;\nBEGIN\n FOR spec IN SELECT * FROM (VALUES\n'
repair += ',\n'.join(' (' + ','.join(map(literal, c)) + ')' for c in columns)
repair += """
 ) AS required(table_name,column_name,definition) LOOP
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema()
     AND table_name=spec.table_name AND column_name=spec.column_name) THEN
   RAISE NOTICE 'Adding %.%', spec.table_name, spec.column_name;
   EXECUTE 'ALTER TABLE ' || quote_ident(current_schema()) || '.' || quote_ident(spec.table_name)
      || ' ADD COLUMN ' || quote_ident(spec.column_name) || ' ' || spec.definition;
  END IF;
 END LOOP;
END $missing_columns$;
"""

# Reuse historical business migrations and verification, never run the package generator.
raw = subprocess.check_output(['node', '-e', "process.stdout.write(JSON.stringify(require('./tools/release-0907/generate.cjs').templates))"], cwd=ROOT)
templates = json.loads(raw)
upgrade = next(v for k,v in templates.items() if k.startswith('02-'))
upgrade = upgrade.replace('BEGIN;\n', '', 1)
upgrade = re.sub(r'^SET search_path[^\n]+\n', '', upgrade, flags=re.M)
# Header's current_schema equality is redundant with the single schema guard above.
upgrade = re.sub(r'DO \$guard\$ BEGIN[\s\S]*?END \$guard\$;\n', '', upgrade, count=1)
upgrade = upgrade.replace('@@TENANT@@', '124')
upgrade = upgrade.replace("ELSIF current_setting('server_version_num')::integer >= 90200\n          AND current_setting('server_version_num')::integer < 90300 THEN", "ELSIF current_setting('server_version_num')::integer >= 90200 THEN")
upgrade = upgrade.replace("RAISE NOTICE '已识别原生 PostgreSQL 9.2，业务防重索引将使用唯一索引。';", "RAISE NOTICE 'PostgreSQL 9.2+ detected; native unique indexes apply.';")
upgrade = re.sub(r"\s+OR current_setting\('server_version_num'\)::integer >= 90300", '', upgrade)
upgrade = re.sub(r"\s+AND current_setting\('server_version_num'\)::integer < 90300", '', upgrade)
upgrade = re.sub(r'^SELECT pg_advisory_xact_lock[^\n]*\n', '', upgrade, flags=re.M)
upgrade = re.sub(r'COMMIT;\s*--[^\n]*\s*$', '', upgrade)
# Index repair is also independent of version markers; preserve the canonical DWS
# non-unique business indexes rather than introducing unsupported uniqueness.
index_sql = {}
for statement in re.findall(r"CREATE (?:UNIQUE )?INDEX [^;']+", baseline):
    name = re.search(r'INDEX (\w+)', statement)[1]
    if name not in index_sql or 'UNIQUE INDEX' in statement:
        index_sql[name] = statement
indexes = '\n-- Repair absent indexes after historical data upgrades.\n'
for name, statement in index_sql.items():
    expression = literal(statement)
    if 'UNIQUE INDEX' in statement:
        expression = "'CREATE ' || CASE WHEN lower(version()) LIKE '%gauss%' OR lower(version()) LIKE '%dws%' THEN '' ELSE 'UNIQUE ' END || " + literal(statement[len('CREATE UNIQUE '):])
    indexes += f"DO $index_repair$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname=current_schema() AND indexname='{name}') THEN EXECUTE {expression}; END IF; END $index_repair$;\n"
verify_source = re.sub(r'^(?:BEGIN|COMMIT);\n', '', read(DEPLOY / '20-verify.sql'), flags=re.M)
assert verify_source in upgrade
upgrade = upgrade.replace(verify_source, indexes + verify_source)
# Only historical data transforms depend on versions. Tables/columns always reconciled first.
full = header + '-- Existing tenant is 124; change tenant literal below if needed.\n' + creation + 'LOCK TABLE cost_schema_migration IN EXCLUSIVE MODE;\n' + repair + upgrade
full += '\n' + '\n'.join(comments) + '\nCOMMIT;\n'
assert 'pg_temp.costree_add_warning_column' not in full
assert '@@' not in full
(OUT / '01-full-upgrade.sql').write_text(full, encoding='utf-8')

verification = header.replace('BEGIN;\n', '').replace('SET LOCAL', 'SET')
verification += "SELECT current_database(), current_user, current_schema(), version();\n"
verification += "SELECT required.table_name, c.table_name IS NOT NULL AS exists_now FROM (VALUES\n" + ',\n'.join(' ('+literal(t)+')' for t in tables) + ") required(table_name) LEFT JOIN information_schema.tables c ON c.table_schema=current_schema() AND c.table_name=required.table_name;\n"
verification += "SELECT table_name,column_name,data_type,column_default,is_nullable FROM information_schema.columns WHERE table_schema=current_schema() AND ((table_name='cost_auth_user_lock' AND column_name='revision') OR (table_name IN ('cost_user_project_scope','cost_user_unit_scope','cost_user_domain_scope') AND column_name='id'));\n"
(OUT / '03-verify-structure.sql').write_text(verification, encoding='utf-8')
manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.sql')}
(OUT / 'SHA256.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(json.dumps({'tables': len(tables), 'columns': len(columns), 'output': str(OUT)}))
