#!/usr/bin/env bash
set -euo pipefail
PACKAGE_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$PACKAGE_ROOT"
for file in RELEASE-INFO.txt backend/app/cost-server.jar frontend/dist/index.html \
  database/postgresql/01-new-database/costree-cost.sql \
  database/postgresql/02-upgrade-existing/00-precheck.sql \
  database/postgresql/02-upgrade-existing/10-upgrade-existing-to-20260722.sql \
  database/postgresql/02-upgrade-existing/11-upgrade-existing-to-20260728-project-office-form.sql \
  database/postgresql/02-upgrade-existing/12-upgrade-existing-to-20260817-access-scope.sql \
  database/postgresql/02-upgrade-existing/13-upgrade-existing-to-20260818-domain-scope.sql \
  database/postgresql/02-upgrade-existing/14-upgrade-existing-to-20260819-manual-fields-subsystem.sql \
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
  database/postgresql92/02-upgrade-existing/12-upgrade-existing-to-20260817-access-scope.sql \
  database/postgresql92/02-upgrade-existing/13-upgrade-existing-to-20260818-domain-scope.sql \
  database/postgresql92/02-upgrade-existing/14-upgrade-existing-to-20260819-manual-fields-subsystem.sql \
  database/postgresql92/02-upgrade-existing/20-verify.sql \
  database/postgresql92/03-data-integration/load-and-sync.sh \
  database/postgresql92/03-data-integration/10-sync-to-cost.sql \
  database/postgresql92/03-data-integration/30-diagnose-book-zero.sql \
  database/postgresql92/03-data-integration/manual/00-使用前总检查.sql \
  database/postgresql92/03-data-integration/manual/01-同步型号树-cost_model_node.sql \
  database/postgresql92/03-data-integration/manual/02-同步项目-cost_project.sql \
  database/postgresql92/03-data-integration/manual/03-同步单位字典-cost_unit_dict.sql \
  database/postgresql92/03-data-integration/manual/04-同步单位金额-cost_unit_cost_detail.sql \
  database/postgresql92/03-data-integration/manual/05-同步工作令-cost_work_order.sql \
  database/postgresql92/03-data-integration/manual/06-同步账面明细-cost_work_order_ledger_detail.sql \
  database/postgresql92/03-data-integration/manual/07-重算工作令账面成本.sql \
  database/postgresql92/03-data-integration/manual/08-全链路验收.sql \
  database/postgresql92/03-data-integration/manual/09-定时任务执行顺序.md \
  database/postgresql92/03-data-integration/manual/README-内网字段映射说明.md \
  database/postgresql92/03-data-integration/snapshot-upsert/00-开始这里.md \
  database/postgresql92/03-data-integration/snapshot-upsert/01-创建标准中间表.sql \
  database/postgresql92/03-data-integration/snapshot-upsert/02-只清空中间表.sql \
  database/postgresql92/03-data-integration/snapshot-upsert/03-源数据全量装载模板.sql \
  database/postgresql92/03-data-integration/snapshot-upsert/04-导入前检查.sql \
  database/postgresql92/03-data-integration/snapshot-upsert/05-业务表幂等同步.sql \
  database/postgresql92/03-data-integration/snapshot-upsert/06-重算工作令账面.sql \
  database/postgresql92/03-data-integration/snapshot-upsert/07-同步后验收.sql \
  database/postgresql92/03-data-integration/snapshot-upsert/08-缺失数据差异清单.sql \
  database/postgresql92/03-data-integration/snapshot-upsert/09-定时任务最简顺序.md \
  database/postgresql92/03-data-integration/snapshot-upsert/10-最简过程.ps1 \
  database/postgresql92/03-data-integration/manual-preservation/00-开始这里.md \
  database/postgresql92/03-data-integration/manual-preservation/01-创建手工快照表.sql \
  database/postgresql92/03-data-integration/manual-preservation/02-生成清库前快照.sql \
  database/postgresql92/03-data-integration/manual-preservation/03-清库前验收.sql \
  database/postgresql92/03-data-integration/manual-preservation/04-清库后恢复.sql \
  database/postgresql92/03-data-integration/manual-preservation/05-恢复后验收.sql \
  database/postgresql92/03-data-integration/manual-preservation/10-旧清库保护过程.ps1 \
  database/postgresql92/03-data-integration/business-upgrade/00-开始这里.md \
  database/postgresql92/03-data-integration/business-upgrade/01-升级填报保护与分系统字典-20260819.sql \
  database/postgresql92/03-data-integration/business-upgrade/02-检查填报保护与分系统字典-20260819.sql \
  docs/10-20260728字段与页面变更.md \
  docs/11-三级权限升级与授权操作.md \
  docs/12-成本树三级权限与双库初始化.md \
  database/platform/costree-access-role-menu-mysql-20260817.sql \
  database/platform/costree-access-role-menu-postgresql-20260817.sql \
  database/platform/costree-access-role-menu-postgresql92-20260817.sql \
  database/platform/costree-access-role-menu-dm8-20260817.sql \
  database/platform/check-cost-permissions.sql \
  database/platform/check-cost-permissions-dm8.sql \
  database/platform/required-permissions.txt \
  SHA256SUMS.txt; do
  [[ -f "$file" ]] || { echo "Missing package file: $file" >&2; exit 1; }
done
for script in \
  database/platform/costree-access-role-menu-mysql-20260817.sql \
  database/platform/costree-access-role-menu-postgresql-20260817.sql \
  database/platform/costree-access-role-menu-postgresql92-20260817.sql \
  database/platform/costree-access-role-menu-dm8-20260817.sql; do
  for role in cost_global_viewer cost_research_department cost_project_office cost_unit_user; do
    grep -q "$role" "$script" || { echo "Platform role script is missing role $role: $script" >&2; exit 1; }
  done
done
grep -Eq 'expected_mapping_count|EXPECTED_MAPPING_COUNT' database/platform/check-cost-permissions.sql
grep -Eq '29' database/platform/check-cost-permissions.sql
grep -Eq 'EXPECTED_MAPPING_COUNT' database/platform/check-cost-permissions-dm8.sql
grep -Eq '29' database/platform/check-cost-permissions-dm8.sql
! grep -Eiq '^[[:space:]]*(TRUNCATE|DELETE[[:space:]]+FROM)[[:space:]]+(TABLE[[:space:]]+)?("?costree_mvp"?\.)' database/postgresql92/03-data-integration/snapshot-upsert/*.sql
! grep -Eiq '^[[:space:]]*(INSERT[[:space:]]+INTO|UPDATE|DELETE[[:space:]]+FROM|TRUNCATE([[:space:]]+TABLE)?)[[:space:]]+("?costree_mvp"?\.)?cost_project_basic\b' database/postgresql92/03-data-integration/snapshot-upsert/*.sql
grep -qi 'manual_field_digest' database/postgresql92/03-data-integration/snapshot-upsert/04-导入前检查.sql
grep -qi 'manual_field_baseline' database/postgresql92/03-data-integration/snapshot-upsert/07-同步后验收.sql
grep -qi '手工字段或流程状态' database/postgresql92/03-data-integration/snapshot-upsert/07-同步后验收.sql
SYNC_FILE=database/postgresql92/03-data-integration/snapshot-upsert/05-业务表幂等同步.sql
! sed -n '/UPDATE "costree_mvp"\.cost_project /,/FROM tmp_cost_sync_project/p' "$SYNC_FILE" | grep -Eiq '\b(batch_no|stage_codes|unit_id|unit_name|unit_type|project_office_status|unit_fill_status|audit_status|warning_status|owner_user_id)[[:space:]]*='
! sed -n '/UPDATE "costree_mvp"\.cost_unit_cost_detail /,/FROM tmp_cost_sync_amount_match/p' "$SYNC_FILE" | grep -Eiq '\b(target_cost_amount|book_cost_amount|approved_amount|salary_amount|material_amount|outsource_amount|manage_amount|fuel_power_amount|other_amount|remark)[[:space:]]*='
! sed -n '/UPDATE "costree_mvp"\.cost_work_order /,/FROM tmp_cost_sync_work_order_match/p' "$SYNC_FILE" | grep -Eiq '\b(product_target_cost|contract_amount|income_amount|book_cost_amount|stage_codes|max_stage_code|subsystem_name|product_short_name|quantity|vertical_division|approved_amount|status|remark|owner_user_id)[[:space:]]*='
grep -q 'I_UNDERSTAND_COST_BUSINESS_RESET' database/postgresql92/03-data-integration/manual-preservation/10-旧清库保护过程.ps1
grep -q 'BackupVerified' database/postgresql92/03-data-integration/manual-preservation/10-旧清库保护过程.ps1
grep -q 'RESTORED_PENDING_VERIFY' database/postgresql92/03-data-integration/manual-preservation/05-恢复后验收.sql
grep -qi 'cost_subsystem_dict' database/postgresql92/03-data-integration/business-upgrade/01-升级填报保护与分系统字典-20260819.sql
grep -qi 'vertical_division DROP DEFAULT' database/postgresql92/03-data-integration/business-upgrade/01-升级填报保护与分系统字典-20260819.sql
grep -qi 'subsystem_dict_duplicate_name' database/postgresql92/03-data-integration/business-upgrade/02-检查填报保护与分系统字典-20260819.sql
sed 's/ \*/  /' SHA256SUMS.txt | sha256sum --check --strict
echo 'Package verification passed.'
