"""Exercise delivery SQL only in explicitly named, isolated disposable containers."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'note/80-deployment/20260910-cost-upgrade'
results = []

def run(args, ok=True):
    p = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = p.stdout.decode('utf-8', errors='replace')
    if ok and p.returncode:
        raise RuntimeError(output[-5000:])
    return p.returncode, output

for container in ('costree-sql-review-20260910', 'costree-sql-review92-20260910'):
    info = json.loads(run(['docker', 'inspect', container])[1])[0]
    assert info['HostConfig']['NetworkMode'] == 'none'
    assert not info['HostConfig']['Binds'] and not info['HostConfig']['PortBindings']
    def sql(text, ok=True):
        return run(['docker', 'exec', container, 'psql', '-U', 'postgres', '-v', 'ON_ERROR_STOP=1', '-At', '-c', text], ok)
    def file(name, ok=True):
        run(['docker', 'cp', str(OUT / name), container + ':/tmp/test.sql'])
        return run(['docker', 'exec', container, 'psql', '-U', 'postgres', '-v', 'ON_ERROR_STOP=1', '-f', '/tmp/test.sql'], ok)
    # This database lives only inside the verified disposable container.
    sql('DROP SCHEMA IF EXISTS cost_verify CASCADE; DROP SCHEMA public CASCADE; CREATE SCHEMA public;')
    file('02-backup-create-missing-tables.sql')
    assert sql("SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")[1].strip() == '20'
    sql("INSERT INTO cost_project(id,project_code,project_name,tenant_id) VALUES (900,'VERIFY_ONLY','Verification project',124)")
    file('01-full-upgrade.sql')
    file('01-full-upgrade.sql')
    # Future migration markers must not prevent missing table or column repair.
    sql("INSERT INTO cost_schema_migration(version,description) VALUES ('20990101','fixture only'); DROP TABLE cost_user_role; DROP TABLE cost_user_domain_scope; ALTER TABLE cost_auth_user_lock DROP COLUMN revision;")
    before = sql('SELECT count(*) FROM cost_schema_migration')[1]
    file('02-backup-create-missing-tables.sql')
    file('02-backup-create-missing-tables.sql')
    assert sql("SELECT count(*) FROM information_schema.columns WHERE table_name='cost_auth_user_lock' AND column_name='revision'")[1].strip() == '0'
    assert sql('SELECT count(*) FROM cost_schema_migration')[1] == before
    file('01-full-upgrade.sql')
    assert sql("SELECT count(*) FROM information_schema.columns WHERE table_name='cost_auth_user_lock' AND column_name='revision'")[1].strip() == '1'
    assert sql("SELECT project_name FROM cost_project WHERE id=900")[1].strip() == 'Verification project'
    # A tenant guard failure must roll back earlier schema creation in the full script.
    sql('DROP TABLE cost_user_role; UPDATE cost_project SET tenant_id=999;')
    code, output = file('01-full-upgrade.sql', ok=False)
    assert code != 0 and 'ERROR' in output
    assert sql("SELECT count(*) FROM information_schema.tables WHERE table_name='cost_user_role'")[1].strip() == '0'
    sql('UPDATE cost_project SET tenant_id=124;')
    file('01-full-upgrade.sql')
    # Shared revision and scope write roll back together.
    sql('INSERT INTO cost_auth_user_lock(tenant_id,user_id) VALUES(124,42);')
    sql('BEGIN; UPDATE cost_auth_user_lock SET revision=revision+1 WHERE tenant_id=124 AND user_id=42; ROLLBACK;')
    assert sql('SELECT revision FROM cost_auth_user_lock WHERE tenant_id=124 AND user_id=42')[1].strip() == '0'
    file('03-verify-structure.sql')
    # Test the actual schema substitution with same-named public tables present.
    sql('CREATE SCHEMA cost_verify;')
    def other_schema(name):
        body = (OUT / name).read_text(encoding='utf-8').replace('search_path TO "public"', 'search_path TO "cost_verify"')
        p = subprocess.run(['docker', 'exec', '-i', container, 'psql', '-U', 'postgres', '-v', 'ON_ERROR_STOP=1'], input=body.encode('utf-8'), stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        assert p.returncode == 0, p.stdout.decode('utf-8', errors='replace')[-3000:]
    other_schema('02-backup-create-missing-tables.sql')
    sql("INSERT INTO cost_verify.cost_project(id,project_code,project_name,tenant_id) VALUES (901,'OTHER_SCHEMA','Other schema fixture',124)")
    other_schema('01-full-upgrade.sql')
    assert sql('SELECT count(*) FROM public.cost_project WHERE id=901')[1].strip() == '0'
    assert sql('SELECT count(*) FROM cost_verify.cost_project WHERE id=901')[1].strip() == '1'
    assert sql("SELECT count(*) FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='cost_verify' AND c.relkind='r' AND a.attnum>0 AND NOT a.attisdropped AND col_description(c.oid,a.attnum) IS NULL")[1].strip() == '0'
    results.append({'container': container, 'version': sql('SELECT version()')[1].strip(), 'passed': ['empty backup creates 20 tables', 'full upgrade and repeat', 'future marker with missing tables', 'backup leaves existing columns and migration rows untouched', 'full repairs missing revision', 'existing project preserved', 'full failure rolls back schema', 'revision rollback', 'structure verification', 'explicit schema isolation', 'all columns commented']})

(OUT / 'local-validation.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(results, ensure_ascii=True, indent=2))
