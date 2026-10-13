#!/usr/bin/env bash
set -euo pipefail

: "${PGHOST:?PGHOST is required}"
: "${PGUSER:?PGUSER is required}"
: "${PGDATABASE:?PGDATABASE is required}"
export PGPORT="${PGPORT:-5432}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CSV_DIR="${1:-$SCRIPT_DIR/csv}"
TENANT_ID="${COST_TENANT_ID:-124}"
BATCH_CODE="${COST_BATCH_CODE:-COST-$(date +%Y%m%d%H%M%S)}"

[[ "$TENANT_ID" =~ ^[0-9]+$ ]] || { echo 'COST_TENANT_ID must be numeric' >&2; exit 1; }
[[ "$BATCH_CODE" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo 'COST_BATCH_CODE contains invalid characters' >&2; exit 1; }
command -v psql >/dev/null 2>&1 || { echo 'psql is required' >&2; exit 1; }

tables=(
  unit_dict ads_lc_lshsxm2022 dwd_bd_bfcustomitem_gzl
  precontrol_project_unit_amount project_office_fill work_order_fill
  dws_bu_pz_pzmx_gzl
)

psql -X -w -v ON_ERROR_STOP=1 -f "$SCRIPT_DIR/00-create-staging.sql"
psql -X -w -v ON_ERROR_STOP=1 -c \
  "UPDATE cost_integration.sync_config SET tenant_id=$TENANT_ID, batch_code='$BATCH_CODE', update_time=CURRENT_TIMESTAMP WHERE id=1;"

truncate_sql='TRUNCATE TABLE '
for table in "${tables[@]}"; do truncate_sql+="cost_integration.$table, "; done
truncate_sql="${truncate_sql%, };"
psql -X -w -v ON_ERROR_STOP=1 -c "$truncate_sql"

for table in "${tables[@]}"; do
  file="$CSV_DIR/$table.csv"
  [[ -f "$file" ]] || { echo "Missing CSV file: $file" >&2; exit 1; }
  echo "Loading $table ..."
  columns=''
  if [[ "$table" == 'project_office_fill' ]]; then
    columns='(source_record_id, project_code, product_attachment_type, subsystem_name, quantity, product_short_name, vertical_division, user_name, acquire_method, batch_category, platform_series, research_unit_name, tax_exempt, cycle_start, cycle_end, stage_code, basic_info, status, source_update_time, source_deleted)'
  fi
  psql -X -w -v ON_ERROR_STOP=1 -c \
    "\copy cost_integration.$table$columns FROM '$file' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')"
done

psql -X -w -v ON_ERROR_STOP=1 -f "$SCRIPT_DIR/10-sync-to-cost.sql"
psql -X -w -v ON_ERROR_STOP=1 -f "$SCRIPT_DIR/20-verify-sync.sql"
echo "Cost integration batch completed: tenant=$TENANT_ID, batch=$BATCH_CODE"
