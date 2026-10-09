"""Verify server-built artifacts and assemble a new, non-overwriting offline release."""
import datetime
import hashlib
import json
import re
import shutil
import subprocess
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).parent
ARTIFACTS = ROOT / '.preview/release-20261009/server-artifacts'
SQL = ROOT / 'note/80-deployment/20260914-cost-upgrade'
BACK = ROOT.parent / 'sqlbot_with_bcback/baback'
FRONT = ROOT.parent / 'sqlbot_with_bcback/costree-frontend'
OUT = ROOT / 'cost-server-offline-package-20261009'
BACK_COMMIT = '82619751f3a4f9eb0e2a4eba864cdfc0d1d86045'
FRONT_COMMIT = '2a6a0d3802a1c032f67888fcd9c3dc868234c55c'


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1048576), b''):
            digest.update(block)
    return digest.hexdigest()


def write(name, content):
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8')


def copy(source, name):
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, path)
    assert sha(source) == sha(path), name


def copy_tree(source, destination):
    for path in sorted(source.rglob('*')):
        if (path.is_file() and '__pycache__' not in path.parts and path.suffix != '.pyc'
                and path.name != 'build-delivery.py'):
            copy(path, destination + '/' + path.relative_to(source).as_posix())


def check_zip(path):
    archive = zipfile.ZipFile(path)
    assert archive.testzip() is None, path
    names = archive.namelist()
    assert len(names) == len(set(names)), 'Duplicate ZIP entries'
    assert all(not PurePosixPath(n).is_absolute() and '..' not in PurePosixPath(n).parts
               and '\\' not in n for n in names), 'Unsafe ZIP path'
    return archive


assert not OUT.exists() and not OUT.with_suffix('.zip').exists(), 'Never overwrite an existing release'
for repo, expected in [(BACK, BACK_COMMIT), (FRONT, FRONT_COMMIT)]:
    actual = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
    assert actual == expected, (repo, actual)
    assert not subprocess.check_output(['git', '-C', str(repo), 'status', '--porcelain']), repo

server = json.loads((ARTIFACTS / 'build-manifest.json').read_text(encoding='utf-8-sig'))
assert server['status'] == 'PASS'
assert server['backendCommit'] == BACK_COMMIT
assert server['frontendCommit'] == FRONT_COMMIT
assert server['backend']['nonConfigIdentical'] is True
assert server['frontend']['typesCheck'] == 'PASS'
for name in ['cost-server.jar', 'dist-prod.zip', 'backend-package.zip']:
    expected = server['artifacts'][name]
    assert (ARTIFACTS / name).stat().st_size == expected['bytes'], name
    assert sha(ARTIFACTS / name) == expected['sha256'], name
assert server['backend']['deliveredSha256'] == server['artifacts']['cost-server.jar']['sha256']

backend_tests = json.loads((ARTIFACTS / 'backend-tests.json').read_text(encoding='utf-8-sig'))
test_keys = ['tests', 'failures', 'errors', 'skipped']
assert backend_tests['tests'] > 0
assert all(backend_tests[key] == 0 for key in test_keys[1:])
assert {key: backend_tests[key] for key in test_keys} == server['backend']['tests']
assert backend_tests['suites'] and len({s['name'] for s in backend_tests['suites']}) == len(backend_tests['suites'])
for key in test_keys:
    assert sum(suite[key] for suite in backend_tests['suites']) == backend_tests[key], key
backend_log = re.sub(r'\x1b\[[0-9;]*m', '', (ARTIFACTS / 'backend-build.log').read_text(encoding='utf-8-sig'))
assert 'BUILD SUCCESS' in backend_log and 'BUILD FAILURE' not in backend_log
logged_suites = re.findall(r'Tests run:\s*(\d+),\s*Failures:\s*(\d+),\s*Errors:\s*(\d+),\s*Skipped:\s*(\d+)[^\r\n]*?-+ in ([\w.$]+)', backend_log)
assert len(logged_suites) == len(backend_tests['suites']), 'Missing or repeated backend suite results in log'
assert {name: tuple(map(int, counts)) for *counts, name in logged_suites} == {
    suite['name']: tuple(suite[key] for key in test_keys) for suite in backend_tests['suites']
}, 'Backend log and XML summary disagree'
frontend_log = (ARTIFACTS / 'frontend-tests.log').read_text(encoding='utf-8-sig')
frontend_tests = {}
for key in ['tests', 'pass', 'fail', 'skipped']:
    values = re.findall(r'^# ' + key + r' (\d+)\s*$', frontend_log, re.M)
    assert len(values) == 1, 'Missing or repeated frontend test result: ' + key
    frontend_tests[key] = int(values[0])
assert frontend_tests == server['frontend']['tests']
assert frontend_tests['tests'] > 0 and frontend_tests['tests'] == frontend_tests['pass']
assert frontend_tests['fail'] == frontend_tests['skipped'] == 0
types_log = (ARTIFACTS / 'frontend-types.log').read_text(encoding='utf-8-sig')
assert 'vue-tsc' in types_log and not re.search(r'error TS\d+|ELIFECYCLE|ERR_PNPM', types_log), 'Frontend type check did not pass'
for name, digest in json.loads((SQL / 'SHA256.json').read_text()).items():
    assert sha(SQL / name) == digest, name

jar = ARTIFACTS / 'cost-server.jar'
frontend = ARTIFACTS / 'dist-prod.zip'
with check_zip(ARTIFACTS / 'backend-package.zip') as archive:
    assert hashlib.sha256(archive.read('cost-server.jar')).hexdigest() == sha(jar), 'Backend archive contains a different JAR'
    assert archive.read('EXTERNALIZED-CONFIG.txt') == (ARTIFACTS / 'EXTERNALIZED-CONFIG.txt').read_bytes()
with check_zip(jar) as archive:
    names = archive.namelist()
    assert not any(re.match(r'BOOT-INF/classes/application-.+\.ya?ml$', n) for n in names)
    assert b'CostServerApplication' in archive.read('META-INF/MANIFEST.MF')
    for name in ['BOOT-INF/classes/application.yml', 'BOOT-INF/classes/application.yaml']:
        if name not in names:
            continue
        config = archive.read(name).decode('utf-8')
        for line in config.splitlines():
            match = re.match(r'^\s*(password|accessToken|secret|api-key|client-secret|secret-key):\s*(.*?)\s*$', line, re.I)
            if match and match[2] and not match[2].startswith(('#', '${')):
                raise AssertionError('Non-externalized sensitive configuration key: ' + match[1])
    entities = [p.stem for p in (BACK / 'yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/dal/dataobject').rglob('*.java')
                if '@TableId' in p.read_text(encoding='utf-8')]
    assert len(entities) == 17, entities
    for name in entities:
        data = archive.read(next(n for n in names if n.endswith('/' + name + '.class')))
        assert b'ASSIGN_ID' in data and b'KeySequence' not in data, name
        assert int.from_bytes(data[6:8], 'big') == 52, name
    for name, marker in [('CostAccessScopeServiceImpl', b'getScopeRevision'),
                         ('CostOverviewController', b'/project-count'),
                         ('CostWorkOrderLedgerDetailMapper', b'd LEFT JOIN cost_project p')]:
        assert marker in archive.read(next(n for n in names if n.endswith('/' + name + '.class'))), name

with check_zip(frontend) as archive:
    names = set(archive.namelist())
    assert 'index.html' in names
    assert hashlib.sha256(archive.read('index.html')).hexdigest() == server['frontend']['indexSha256']
    code = '\n'.join(archive.read(n).decode('utf-8', 'replace') for n in names if n.endswith('.js'))
    for marker in ['/cost/overview/project-count', '/cost/role-assignment', 'scopeRevision', '八项账面成本']:
        assert marker in code, marker
    index = archive.read('index.html').decode('utf-8')
    for ref in re.findall(r'(?:src|href)=["\']([^"\']+)["\']', index):
        if not re.match(r'^(?:https?:|data:|//|#)', ref):
            asset = ref.split('?')[0].split('#')[0].lstrip('./')
            if asset:
                assert asset in names, ref
    refs = set(re.findall(r'["\'](?:\./)?([A-Za-z0-9_@.-]+-[A-Za-z0-9_-]{8,}\.(?:js|css))["\']', code))
    for ref in refs:
        assert 'assets/' + ref in names, ref
    frontend_check = {'entries': len(names), 'hashedReferences': len(refs), 'crc': 'pass', 'featureMarkers': 'pass'}

assert (TOOLS / 'workflow/README.md').is_file()
workflow_evidence = ROOT / 'note/70-testing/20261009-offline-release/workflow-isolated'
workflow_verified = json.loads((workflow_evidence / 'verification-summary.json').read_text(encoding='utf-8'))
assert workflow_verified['passed'] and workflow_verified['cleanup']['verified']
assert workflow_verified['total_final_checks'] == 20
workflow_results = {}
for kind, result_path, expected_count in [('core', 'final/result.json', 15), ('daily', 'daily-final/result.json', 5)]:
    assert workflow_verified[kind]['result_path'] == result_path
    result = json.loads((workflow_evidence / result_path).read_text(encoding='utf-8'))
    assert result['passed'] is True and result['templates_unchanged_on_disk'] is True
    assert len(result['tests']) == expected_count and all(test['passed'] is True for test in result['tests'])
    assert len({test['name'] for test in result['tests']}) == expected_count
    assert workflow_verified[kind]['passed'] is True and workflow_verified[kind]['tests'] == expected_count
    assert set(result['template_sha256']) == {path.name for path in (TOOLS / 'workflow/templates').glob('*.sql')}
    for name, digest in result['template_sha256'].items():
        assert sha(TOOLS / 'workflow/templates' / name) == digest, kind + ': ' + name
    assert result['server'] == workflow_verified['server'] and result['real_dws_verified'] is False
    workflow_results[kind] = result
assert workflow_results['daily']['daily_runner_sha256'] == sha(TOOLS / 'workflow/daily-runner.py')
assert workflow_results['core']['cleanup_verified'] is True
for name, digest in workflow_verified['current_file_sha256'].items():
    assert sha(TOOLS / 'workflow' / name) == digest, name
OUT.mkdir()
copy(jar, '03-app/cost-server.jar')
copy(frontend, '03-app/dist-prod.zip')
copy(ARTIFACTS / 'EXTERNALIZED-CONFIG.txt', '03-app/EXTERNALIZED-CONFIG.txt')
for name in ['00-START-HERE.md', '03-app/README.md']:
    copy(TOOLS / name, name)
for name in ['verify-package.ps1', '01-database/README.md', '02-permissions/01-role-and-scope.md']:
    copy(TOOLS / name, name)
for name in ['01-full-upgrade.sql', '02-backup-create-missing-tables.sql', '03-verify-structure.sql',
             '05-reporting-name-width.sql', 'SHA256.json', 'local-validation.json']:
    copy(SQL / name, '01-database/' + name)
copy(TOOLS / '02-permissions/02-notification-templates.md',
     '02-permissions/02-notification-templates.md')
copy(TOOLS / '01-database/00-identify-schema.sql',
     '01-database/00-identify-schema.sql')
copy(TOOLS / '01-database/04-optional-revision-only.sql',
     '01-database/04-optional-revision-only.sql')
readme = (OUT / '01-database/README.md').read_text(encoding='utf-8')
readme = readme.replace('04-evidence/local-acceptance 是历史本地记录，不代表本次最终包验收；最新边界见 04-evidence/20260923-review.md。',
                        '本文件中的 PG 隔离结果属于历史验证。最新构建、同步验证和现场边界见 RELEASE-INFO.json 与 04-evidence；05-workflow 是另行初始化的同步辅助结构。')
write('01-database/README.md', readme)
templates = {name: (OUT / '01-database' / name).read_text(encoding='utf-8') for name in
             ['01-full-upgrade.sql', '02-backup-create-missing-tables.sql', '03-verify-structure.sql',
              '04-optional-revision-only.sql', '05-reporting-name-width.sql']}
html = (TOOLS / 'sql-parameters.html').read_text(encoding='utf-8')
write('01-database/sql-parameters.html', html.replace('/*SQL_TEMPLATES*/{}', json.dumps(templates, ensure_ascii=False).replace('<', '\\u003c')))

copy_tree(TOOLS / 'workflow', '05-workflow')
copy(ROOT / 'note/70-testing/20261009-offline-release/manual-field-audit.md', '04-evidence/manual-field-audit.md')
copy_tree(workflow_evidence, '04-evidence/workflow-isolated')
for name in ['build-manifest.json', 'backend-tests.json', 'backend-build.log', 'frontend-build.log',
             'frontend-tests.log', 'frontend-types.log']:
    copy(ARTIFACTS / name, '04-evidence/server-build/' + name)
for name in ['backend-manifest.json', 'local-frontend-manifest.json', 'backend-font-build-environment.json',
             'backend-runtime-before.json', 'backend-runtime-after.json', 'frontend-checks-exit.json']:
    copy(ARTIFACTS / name, '04-evidence/server-build/' + name)
if (ARTIFACTS / 'reproduce').is_dir():
    copy_tree(ARTIFACTS / 'reproduce', '04-evidence/server-build/reproduce')
for name in ['README.md', '06-filter-options-sample.sql', '03-lightweight-check.sql']:
    source = ROOT / 'note/70-testing/20260923-intranet-diagnosis' / name
    if name != 'README.md':
        copy(source, '04-evidence/intranet-diagnosis/' + name)
filter_readme = (ROOT / 'note/70-testing/20261009-ledger-filter-scope/README.md').read_text(encoding='utf-8')
filter_readme = filter_readme.replace('../20260923-intranet-diagnosis/', '../intranet-diagnosis/')
filter_readme = filter_readme.replace('本轮未提交、未构建发布 JAR、未部署服务器或内网、未生成新离线包。当前预览和既有离线包不会自动包含新的后端源码修改。',
                                    '本报告是修复当时的证据。本次离线包已将修复提交并在 Linux 构建，当前包内新 JAR 包含该修复；没有替现场部署。')
write('04-evidence/ledger-filter-fix/README.md', filter_readme)
for name in ['before-fix-tests.log', 'targeted-tests.log', 'frontend-compatibility.cjs', 'frontend-compatibility-result.json']:
    copy(ROOT / 'note/70-testing/20261009-ledger-filter-scope' / name, '04-evidence/ledger-filter-fix/' + name)
for name in ['01-接口清单-MVP.md', '02-接口字段契约.md', '03-接口联调用例.md']:
    contract = (ROOT / 'note/40-api' / name).read_text(encoding='utf-8')
    contract = re.sub(r'\[([^\]]+)\]\((\.\./[^)]+)\)',
                      lambda match: match[1] + '（源码仓库参考：`' + match[2] + '`，不随离线包附带）', contract)
    write('04-evidence/api/' + name, contract)

info = {
    'release': '20261009', 'builtAt': datetime.datetime.now().astimezone().isoformat(),
    'backendCommit': BACK_COMMIT, 'frontendCommit': FRONT_COMMIT,
    'buildLocation': 'Linux backend server; Windows frontend build explicitly approved by user; fixed commits; no local services',
    'deliveredJarSha256': sha(jar), 'deliveredFrontendSha256': sha(frontend),
    'downloadedBackendPackageSha256': sha(ARTIFACTS / 'backend-package.zip'),
    'serverBuildManifestSha256': sha(ARTIFACTS / 'build-manifest.json'),
    'frontendChecks': frontend_check, 'entitiesWithExplicitIds': len(entities),
    'buildTests': {'backend': {key: backend_tests[key] for key in test_keys},
                   'frontend': frontend_tests, 'frontendTypes': 'PASS'},
    'workflowChecks': {'passed': True, 'core': 15, 'daily': 5, 'engine': 'PostgreSQL 17.11',
                       'verificationSha256': sha(workflow_evidence / 'verification-summary.json'),
                       'realDwsVerified': False, 'realYunJingVerified': False},
    'applicationSchemaChanged': False, 'workflowAuxiliarySchema': '05-workflow; initialize separately',
    'deploymentExecuted': False, 'intranetAcceptance': 'pending',
    'businessDatabaseModified': False,
    'sourceMapping': 'Full snapshot + difference updates; intranet source tables/columns must be adapted before execution',
    'limits': ['DWS and 云鲸 枢 2.2.1 must be verified onsite',
               'No genuine domain/model options can be inferred from missing project metadata',
               'Snapshot differences are not source deletion events',
               'Do not use old destructive synchronization SQL with this workflow'],
    'assemblerSha256': sha(Path(__file__)),
}
write('RELEASE-INFO.json', json.dumps(info, ensure_ascii=False, indent=2) + '\n')
manifest = ''.join(sha(p) + '  ' + p.relative_to(OUT).as_posix() + '\n'
                   for p in sorted(OUT.rglob('*')) if p.is_file())
write('SHA256SUMS.txt', manifest)
archive_path = OUT.with_suffix('.zip')
with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted(OUT.rglob('*')):
        if path.is_file():
            archive.write(path, OUT.name + '/' + path.relative_to(OUT).as_posix())
with check_zip(archive_path) as archive:
    for line in manifest.splitlines():
        digest, name = line.split('  ', 1)
        assert hashlib.sha256(archive.read(OUT.name + '/' + name)).hexdigest() == digest, name
archive_path.with_suffix('.zip.sha256').write_text(sha(archive_path) + '  ' + archive_path.name + '\n', encoding='utf-8')
result = {'archive': str(archive_path), 'bytes': archive_path.stat().st_size,
          'sha256': sha(archive_path), 'files': len(manifest.splitlines()) + 1, 'result': 'PASS'}
(ROOT / 'note/70-testing/20261009-offline-release/package-verification.json').write_text(
    json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(result, ensure_ascii=False))
