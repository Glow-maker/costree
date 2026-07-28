#!/usr/bin/env bash
set -euo pipefail
PACKAGE_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$PACKAGE_ROOT"
for file in RELEASE-INFO.txt backend/app/cost-server.jar frontend/dist/index.html \
  database/postgresql/01-new-database/costree-cost.sql \
  database/postgresql/02-upgrade-existing/00-precheck.sql \
  database/postgresql/02-upgrade-existing/10-upgrade-existing-to-20260722.sql \
  database/postgresql/02-upgrade-existing/11-upgrade-existing-to-20260728-project-office-form.sql \
  database/postgresql/02-upgrade-existing/20-verify.sql \
  database/postgresql/03-data-integration/10-sync-to-cost.sql \
  database/postgresql/03-data-integration/30-diagnose-book-zero.sql \
  database/postgresql92/01-new-database/costree-cost.sql \
  database/postgresql92/README.md \
  database/postgresql92/02-upgrade-existing/00-dws-precheck.sql \
  database/postgresql92/02-upgrade-existing/run-new-database.sh \
  database/postgresql92/02-upgrade-existing/run-upgrade.sh \
  database/postgresql92/02-upgrade-existing/verify-dws82-compatibility.sh \
  database/postgresql92/02-upgrade-existing/10-upgrade-existing-to-20260722.sql \
  database/postgresql92/02-upgrade-existing/11-upgrade-existing-to-20260728-project-office-form.sql \
  database/postgresql92/02-upgrade-existing/20-verify.sql \
  database/postgresql92/03-data-integration/load-and-sync.sh \
  database/postgresql92/03-data-integration/10-sync-to-cost.sql \
  database/postgresql92/03-data-integration/30-diagnose-book-zero.sql \
  docs/10-20260728字段与页面变更.md \
  SHA256SUMS.txt; do
  [[ -f "$file" ]] || { echo "Missing package file: $file" >&2; exit 1; }
done
sed 's/ \*/  /' SHA256SUMS.txt | sha256sum --check --strict
echo 'Package verification passed.'
