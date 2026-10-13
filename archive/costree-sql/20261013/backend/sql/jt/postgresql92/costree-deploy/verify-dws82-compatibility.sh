#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SQL_CONTENT=$(find "$ROOT" -type f -name '*.sql' -print0 | xargs -0 cat | grep -v '^[[:space:]]*--' || true)

resolve_file() {
  local candidate
  for candidate in "$@"; do
    if [ -f "$ROOT/$candidate" ]; then
      printf '%s\n' "$ROOT/$candidate"
      return 0
    fi
  done
  echo "Missing file: $*" >&2
  return 1
}

for pattern in \
  'CREATE[[:space:]]+INDEX[[:space:]]+IF[[:space:]]+NOT[[:space:]]+EXISTS' \
  'ADD[[:space:]]+COLUMN[[:space:]]+IF[[:space:]]+NOT[[:space:]]+EXISTS' \
  'ON[[:space:]]+CONFLICT' \
  'WITH[[:space:]]*\([[:space:]]*FORMAT' \
  'CONSTRAINT[[:space:]]+[^[:space:]]+[[:space:]]+UNIQUE[[:space:]]*\('; do
  if printf '%s\n' "$SQL_CONTENT" | grep -Eiq "$pattern"; then
    echo "DWS 8.2.1 compatibility check failed: $pattern" >&2
    exit 1
  fi
done

DDL=$(resolve_file 'costree-cost.sql' '01-new-database/costree-cost.sql' 'new-database/costree-cost.sql')
UPGRADE=$(resolve_file 'costree-deploy/10-upgrade-existing-to-20260722.sql' '02-upgrade-existing/10-upgrade-existing-to-20260722.sql' 'upgrade-existing/10-upgrade-existing-to-20260722.sql')
DOMAIN_UPGRADE=$(resolve_file 'costree-deploy/13-upgrade-existing-to-20260818-domain-scope.sql' '02-upgrade-existing/13-upgrade-existing-to-20260818-domain-scope.sql' 'upgrade-existing/13-upgrade-existing-to-20260818-domain-scope.sql')
MANUAL_UPGRADE=$(resolve_file 'costree-deploy/14-upgrade-existing-to-20260819-manual-fields-subsystem.sql' '02-upgrade-existing/14-upgrade-existing-to-20260819-manual-fields-subsystem.sql' 'upgrade-existing/14-upgrade-existing-to-20260819-manual-fields-subsystem.sql')
WARNING_UPGRADE=$(resolve_file 'costree-deploy/15-upgrade-existing-to-20260820-warning-workflow.sql' '02-upgrade-existing/15-upgrade-existing-to-20260820-warning-workflow.sql' 'upgrade-existing/15-upgrade-existing-to-20260820-warning-workflow.sql')
SYNC=$(resolve_file 'costree-integration/10-sync-to-cost.sql' '03-data-integration/10-sync-to-cost.sql' 'data-integration/10-sync-to-cost.sql')
LOAD=$(resolve_file 'costree-integration/load-and-sync.sh' '03-data-integration/load-and-sync.sh' 'data-integration/load-and-sync.sh')

grep -qi 'CREATE INDEX uk_cost_work_order_business' "$DDL"
grep -qi 'CREATE INDEX uk_cost_ledger_source_detail' "$DDL"
grep -qi 'CREATE INDEX uk_cost_unit_cost_project_unit' "$DDL"
grep -qi 'IF v_is_dws THEN' "$UPGRADE"
grep -qi 'uk_cost_user_domain_scope_user' "$DOMAIN_UPGRADE"
grep -qi 'cost_subsystem_dict' "$MANUAL_UPGRADE"
grep -qi 'cost_warning_receiver' "$WARNING_UPGRADE"
grep -qi 'pg_advisory_xact_lock' "$SYNC"
grep -qi '暂存表存在重复' "$SYNC"
grep -qi 'gsql' "$LOAD"
grep -qi 'WITH CSV HEADER' "$LOAD"
echo 'GaussDB(DWS) 8.2.1 static compatibility check passed.'
