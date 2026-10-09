#!/usr/bin/env python3
"""Exercise the delivered SQL templates against new, strictly bounded audit schemas."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from datetime import datetime, timezone

HERE = Path(__file__).resolve().parent
TEMPLATES = HERE.parent / "templates"
TENANT = 981009
TABLES = ["stg_model_node", "stg_project", "stg_unit_dict", "stg_unit_amount", "stg_work_order", "stg_ledger_detail"]
PROTECTED = {
    "cost_project_basic": set(),
    "cost_project": set("project_name model_node_id domain_code domain_name category_code category_name model_code model_name updater update_time".split()),
    "cost_unit_cost_detail": set("source_record_id source_update_time contract_amount income_amount updater update_time".split()),
    "cost_work_order": set("source_work_order_id project_id project_code project_name unit_id unit_name accounting_unit_code accounting_unit_name work_order_no work_order_name disabled book_cost_amount updater update_time".split()),
    "cost_subsystem_dict": set(),
    "cost_warning_record": set(),
}


def literal(value):
    return "NULL" if value is None else "'" + str(value).replace("'", "''") + "'"


def fixture():
    rows = {
        "stg_model_node": [
            dict(node_code="LAUNCH", node_name="运载火箭", node_type="DOMAIN", parent_node_code=None),
            dict(node_code="SER1", node_name="验收系列", node_type="SERIES", parent_node_code="LAUNCH"),
            dict(node_code="MOD1", node_name="验收型号", node_type="MODEL", parent_node_code="SER1"),
        ],
        "stg_project": [dict(source_project_id="SP1", project_code="P1", project_name="验收项目", model_node_code="MOD1")],
        "stg_unit_dict": [dict(accounting_unit_code="A1", accounting_unit_name="验收单位", manage_unit_code="M1", manage_unit_name="电子所", manage_unit_group="PROFESSIONAL", inside_group="1", inside_institute="1", disabled="0")],
        "stg_unit_amount": [dict(source_record_id="AM1", project_code="P1", accounting_unit_code="A1", contract_amount_wan="10.25", income_amount_wan="5.50")],
        "stg_work_order": [dict(source_work_order_id="SW1", project_code="P1", accounting_unit_code="A1", work_order_no="W1", work_order_name="验收工作令", disabled="0")],
        "stg_ledger_detail": [],
    }
    for number in range(1, 4):
        rows["stg_ledger_detail"].append(dict(source_detail_id="L" + str(number), fiscal_year="2024", voucher_date="2024-01-02", accounting_unit_code="A1", project_code="P1", source_work_order_id="SW1", work_order_no="W1", debit_credit="借", amount_yuan="60", second_subject_code="501102"))
    rows["stg_ledger_detail"].append(dict(source_detail_id="CREDIT", fiscal_year="2026", voucher_date="2026-01-02", accounting_unit_code="A1", project_code="P1", source_work_order_id="SW1", work_order_no="W1", debit_credit="贷", amount_yuan="99999", second_subject_code="501102"))
    return rows


class Audit:
    def __init__(self, args):
        self.args = args
        self.command = json.loads(args.psql_command_json)
        if not isinstance(self.command, list) or not self.command or not all(isinstance(x, str) for x in self.command):
            raise ValueError("--psql-command-json must be an argv string array")
        suffix = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S") + "_" + str(os.getpid())
        self.prefix = args.schema_prefix or "costree_workflow_audit_" + suffix
        if not re.fullmatch(r"costree_workflow_audit_[a-z0-9_]{1,30}", self.prefix):
            raise ValueError("Only a new costree_workflow_audit_* prefix of <= 53 chars is allowed")
        self.biz = self.prefix + "_biz"
        self.stage = self.prefix + "_stage"
        self.source = self.prefix + "_src"
        self.output = Path(args.output).resolve()
        self.output.mkdir(parents=True, exist_ok=True)
        self.results = []
        self.counter = 0
        self.sql_counter = 0
        self.created = False
        self.templates = {p.name: p.read_bytes() for p in TEMPLATES.glob("*.sql")}
        self.report = {"business_schema": self.biz, "stage_schema": self.stage, "tenant": TENANT,
                       "real_dws_verified": False, "tests": self.results,
                       "template_sha256": {name: hashlib.sha256(data).hexdigest() for name, data in self.templates.items()}}

    def sql(self, text, name="query", failure=False, expected_error=None):
        self.sql_counter += 1
        path = self.output / (str(self.sql_counter).zfill(3) + "-" + name + ".sql")
        path.write_text(text, encoding="utf-8")
        process = subprocess.run(self.command + ["-X", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1"],
                                 input=text, encoding="utf-8", errors="replace", capture_output=True, timeout=180)
        path.with_suffix(".out").write_text(process.stdout, encoding="utf-8")
        path.with_suffix(".err").write_text(process.stderr, encoding="utf-8")
        if failure:
            if process.returncode == 0:
                raise AssertionError(name + ": expected rejection, but SQL committed")
            if "ERROR:" not in process.stderr:
                raise AssertionError(name + ": failed without SQL ERROR; not a valid rejection test")
            if expected_error and expected_error not in process.stderr:
                raise AssertionError(name + ": rejection did not match expected reason " + expected_error)
        elif process.returncode:
            raise RuntimeError(name + " failed; see " + str(path.with_suffix(".err")))
        return process.stdout.strip()

    def render(self, name, batch="AUDIT", rows=None):
        text = self.templates[name].decode("utf-8-sig")
        text = text.replace("cost_sync_stage_v20261009", self.stage).replace("costree_mvp", self.biz)
        text = text.replace("__TENANT_ID__", str(TENANT)).replace("__BATCH_CODE__", batch).replace("__SNAPSHOT_TAG__", batch + "-snapshot")
        for table, values in (rows or {}).items():
            inserts = []
            for row in values:
                inserts.append("INSERT INTO " + self.stage + "." + table + " (" + ",".join(row) + ") VALUES (" + ",".join(literal(v) for v in row.values()) + ");")
            text = text.replace("__SOURCE_" + table + "__", "\n".join(inserts))
            text = text.replace("__COUNT_" + table + "__", str(len(values)))
        if re.search(r"__[A-Za-z_]+__", text):
            raise ValueError("Unresolved template marker: " + name)
        return text

    def rows(self, table):
        out = self.sql("SELECT row_to_json(t) FROM (SELECT * FROM " + self.biz + "." + table + " ORDER BY id) t;")
        return [json.loads(line) for line in out.splitlines() if line]

    def snapshot(self, tables):
        statements = ["SELECT " + literal(table) + " || '|' || replace(COALESCE(json_agg(t),'[]'::json)::text,chr(10),'') FROM (SELECT * FROM " + self.biz + "." + table + " ORDER BY id) t" for table in tables]
        out = self.sql(" UNION ALL ".join(statements) + ";")
        return {name: json.loads(rows) for name, rows in (line.split("|", 1) for line in out.splitlines())}

    def protected(self):
        snapshot = self.snapshot(PROTECTED)
        return {table: [{k: v for k, v in row.items() if k not in excluded} for row in snapshot[table]]
                for table, excluded in PROTECTED.items()}

    def business(self):
        tables = list(PROTECTED) + ["cost_unit_dict", "cost_model_node", "cost_work_order_ledger_detail"]
        return self.snapshot(tables)

    def ids(self):
        keys = [
            ("cost_project", "project_code"), ("cost_model_node", "node_code"), ("cost_unit_dict", "accounting_unit_code"),
            ("cost_unit_cost_detail", "source_record_id"), ("cost_work_order", "source_work_order_id"), ("cost_work_order_ledger_detail", "source_detail_id")]
        snapshot = self.snapshot(table for table, key in keys)
        return {table: [(row["id"], row.get(key)) for row in snapshot[table]] for table, key in keys}

    def batch(self, rows, label, bad=False, wrong_batch=False, late_failure=False, expected_error=None):
        self.counter += 1
        batch = "AUDIT-" + str(self.counter).zfill(3)
        self.sql(self.render("10-begin-batch.sql", batch), label + "-begin")
        for number, table in enumerate(TABLES, 21):
            self.sql(self.render(str(number) + "-load-" + table + ".template.sql", batch, rows), label + "-" + table)
        before = self.business()
        before_stage = self.sql("SELECT row_to_json(t) FROM " + self.stage + ".sync_control t;")
        if late_failure:
            self.sql("CREATE FUNCTION " + self.biz + ".audit_reject_ledger() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'AUDIT_EXPECTED_LATE_FAILURE'; END $$; CREATE TRIGGER audit_reject_ledger BEFORE UPDATE ON " + self.biz + ".cost_work_order_ledger_detail FOR EACH ROW EXECUTE PROCEDURE " + self.biz + ".audit_reject_ledger();", label + "-trigger")
        actual_batch = batch + "-WRONG" if wrong_batch else batch
        self.sql(self.render("90-atomic-sync.template.sql", actual_batch), label + "-atomic", failure=bad, expected_error=expected_error)
        if bad:
            assert before == self.business(), label + ": business changes survived failed transaction"
            assert before_stage == self.sql("SELECT row_to_json(t) FROM " + self.stage + ".sync_control t;"), label + ": control status survived failed transaction"
            if late_failure:
                self.sql("DROP TRIGGER audit_reject_ledger ON " + self.biz + ".cost_work_order_ledger_detail; DROP FUNCTION " + self.biz + ".audit_reject_ledger();", label + "-remove-trigger")
            # Explicit isolated-fixture recovery, never an automatic production handler.
            self.sql(self.render("99-manual-abort.template.sql", batch), label + "-fixture-abort")
        else:
            status = self.sql("SELECT load_status FROM " + self.stage + ".sync_control WHERE id=1;")
            assert status == "SUCCESS", label + ": no SUCCESS status"
        self.results.append({"name": label, "passed": True, "expected_rejection": bad, "expected_error": expected_error})

    def seed_manual(self):
        statements = []
        basic_columns = self.sql("SELECT column_name,data_type FROM information_schema.columns WHERE table_schema=" + literal(self.biz) + " AND table_name='cost_project_basic' ORDER BY ordinal_position;")
        columns, values = [], []
        for line in basic_columns.splitlines():
            column, dtype = line.split("|", 1)
            if column == "id":
                continue
            columns.append(column)
            if column == "tenant_id": value = str(TENANT)
            elif column == "project_id": value = "(SELECT id FROM " + self.biz + ".cost_project WHERE project_code='P1')"
            elif column == "project_code": value = "'P1'"
            elif column == "deleted": value = "0"
            elif dtype == "boolean": value = "TRUE"
            elif dtype in ("bigint", "integer", "smallint", "numeric"): value = "7"
            elif dtype.startswith("timestamp"): value = "'2024-01-02 03:04:05'"
            else: value = "'MANUAL'"
            values.append(value)
        statements.append("INSERT INTO " + self.biz + ".cost_project_basic (" + ",".join(columns) + ") VALUES (" + ",".join(values) + ");")
        statements += [
            "INSERT INTO " + self.biz + ".cost_unit_dict(id,accounting_unit_code,accounting_unit_name,manage_unit_code,manage_unit_name,status,tenant_id,deleted) VALUES (50001,'A_KEEP','手填保留单位','M_KEEP','手填管理单位','DISABLE'," + str(TENANT) + ",1);",
            "UPDATE " + self.biz + ".cost_project SET batch_no='MANUAL',stage_codes='S1',unit_id=71,unit_name='MANUAL',unit_type='MANUAL',project_office_status='FILLED',unit_fill_status='FILLED',audit_status='APPROVED',dept_id=72,owner_user_id=73,warning_status='MANUAL',remark='MANUAL';",
            "UPDATE " + self.biz + ".cost_unit_cost_detail SET target_cost_amount=21.23,approved_amount=19.34,book_cost_amount=23.45,salary_amount=1.11,material_amount=2.22,outsource_amount=3.33,manage_amount=4.44,fuel_power_amount=5.55,other_amount=6.66,remark='MANUAL';",
            "UPDATE " + self.biz + ".cost_work_order SET product_target_cost=31.23,contract_amount=32.34,income_amount=33.45,approved_amount=34.56,stage_codes='S1',max_stage_code='S1',subsystem_name='MANUAL',product_short_name='MANUAL',quantity=4,vertical_division=TRUE,status='APPROVED',remark='MANUAL',import_batch_id=81,dept_id=82,owner_user_id=83;",
            "INSERT INTO " + self.biz + ".cost_subsystem_dict(subsystem_name,sort_no,status,remark,tenant_id) VALUES ('MANUAL',7,'ENABLE','MANUAL'," + str(TENANT) + ");",
            "INSERT INTO " + self.biz + ".cost_warning_record(project_id,project_code,warning_source,warning_title,status,workflow_status,cause_analysis,disposal_measure,remark,tenant_id) SELECT id,project_code,'MANUAL','MANUAL','OPEN','DISPOSITION','MANUAL','MANUAL','MANUAL'," + str(TENANT) + " FROM " + self.biz + ".cost_project WHERE project_code='P1';",
        ]
        self.sql("\n".join(statements), "seed-manual-fields")

    def initialize(self):
        self.report["server"] = self.sql("SELECT version(),current_database(),current_user;", "server-identity")
        exists = self.sql("SELECT count(*) FROM pg_namespace WHERE nspname IN (" + literal(self.biz) + "," + literal(self.stage) + "," + literal(self.source) + ");", "check-new-schemas")
        if exists != "0":
            raise RuntimeError("Audit schema already exists; refusing reuse or deletion")
        self.sql("CREATE SCHEMA " + self.biz + ";", "create-audit-schema")
        self.created = True
        self.sql("SET search_path TO " + self.biz + ";\n" + (HERE / "fixture-schema.sql").read_text(encoding="utf-8"), "fixture-schema")
        self.sql(self.render("00-setup.sql"), "setup-real-template")

    def run(self):
        self.initialize()
        data = fixture()
        self.batch(data, "initial-source-insert")
        self.seed_manual()
        self.sql("CREATE SEQUENCE " + self.biz + ".audit_old_owned_seq; ALTER SEQUENCE " + self.biz + ".audit_old_owned_seq OWNED BY " + self.biz + ".cost_unit_dict.id;", "seed-stale-owned-by-sequence")
        ids = self.ids()
        protected = self.protected()
        self.batch(data, "same-snapshot-replay")
        assert ids == self.ids(), "Replay changed IDs/counts"
        assert protected == self.protected(), "Replay changed protected fields"
        assert int(self.sql("SELECT last_value FROM " + self.biz + ".cost_unit_dict_seq;")) >= 50001, "Low sequence was not advanced past an existing manually generated ID"
        assert self.sql("SELECT last_value FROM " + self.biz + ".audit_old_owned_seq;") == "1", "Sequence adjustment followed stale OWNED BY instead of actual DEFAULT"
        self.results.append({"name": "actual-default-sequence-advanced-stale-owned-by-not-changed", "passed": True})
        kept = [row for row in self.rows("cost_unit_dict") if row["accounting_unit_code"] == "A_KEEP"][0]
        assert kept["id"] == 50001 and kept["status"] == "DISABLE" and kept["deleted"] == 1, "Snapshot revived or removed a preserved soft-deleted manual row"
        self.results.append({"name": "sequence-advance-and-missing-soft-deleted-row-preserved", "passed": True})
        amount = self.sql("SELECT book_cost_amount FROM " + self.biz + ".cost_work_order WHERE work_order_no='W1';")
        assert amount == "0.02", "Expected 180 yuan aggregated then rounded to 0.02 wan; got " + amount
        self.results.append({"name": "all-manual-fields-and-ids-preserved-and-yuan-precision", "passed": True})
        changed = copy.deepcopy(data)
        changed["stg_project"][0]["project_name"] = "源变更后的项目"
        changed["stg_unit_amount"][0]["contract_amount_wan"] = "18.75"
        changed["stg_work_order"][0]["work_order_name"] = "源变更后的工作令"
        self.batch(changed, "source-owned-fields-update")
        assert ids == self.ids() and protected == self.protected(), "Source update changed protected rows or IDs"
        assert self.rows("cost_project")[0]["project_name"] == "源变更后的项目"
        assert self.rows("cost_unit_cost_detail")[0]["contract_amount"] == 18.75
        assert self.rows("cost_work_order")[0]["work_order_name"] == "源变更后的工作令"
        extended = copy.deepcopy(changed)
        extended["stg_work_order"].append(dict(source_work_order_id="SW2", project_code="P1", accounting_unit_code="A1", work_order_no="W2", work_order_name="新增工作令", disabled="0"))
        extended["stg_ledger_detail"].append(dict(source_detail_id="NEW", fiscal_year="2026", voucher_date="2026-01-02", accounting_unit_code="A1", project_code="P1", source_work_order_id="SW2", work_order_no="W2", debit_credit="借", amount_yuan="12000", second_subject_code="501102"))
        self.batch(extended, "new-source-rows")
        current_ids = self.ids()
        for table, pairs in ids.items():
            assert all(pair in current_ids[table] for pair in pairs), "New source moved old IDs"
        assert len(self.rows("cost_work_order")) == 2 and len(self.rows("cost_work_order_ledger_detail")) == 5
        baseline = copy.deepcopy(extended)
        bad = copy.deepcopy(baseline)
        bad["stg_unit_dict"].append(dict(bad["stg_unit_dict"][0], accounting_unit_code="A-OLD"))
        bad["stg_unit_amount"].append(dict(bad["stg_unit_amount"][0], source_record_id="AM-OLD", accounting_unit_code="A-OLD"))
        self.batch(bad, "same-name-historical-code-collision", bad=True, expected_error="同名历史单位异码归一")
        bad = copy.deepcopy(baseline)
        bad["stg_unit_amount"][0]["source_record_id"] = "AM-CHANGED"
        self.batch(bad, "stable-source-id-vs-logical-key-conflict", bad=True, expected_error="cost_unit_cost_detail: 源ID与逻辑键冲突")
        bad = copy.deepcopy(baseline)
        bad["stg_work_order"][0]["source_work_order_id"] = "SW2"
        bad["stg_work_order"][1]["source_work_order_id"] = "SW1"
        for row in bad["stg_ledger_detail"]:
            row["source_work_order_id"] = "SW2" if row["work_order_no"] == "W1" else "SW1"
        self.batch(bad, "source-id-target-key-crossing", bad=True, expected_error="cost_work_order: 源ID与逻辑键冲突")
        self.batch(baseline, "invalid-batch-no-business-write", bad=True, wrong_batch=True, expected_error="批次不一致或不是 LOADING")
        bad = copy.deepcopy(baseline)
        bad["stg_unit_amount"][0]["source_deleted"] = "1"
        self.batch(bad, "unapproved-source-delete-rejected", bad=True, expected_error="源删除语义尚未批准")
        self.sql("UPDATE " + self.biz + ".cost_work_order SET deleted=1 WHERE source_work_order_id='SW1';", "seed-matched-soft-deleted-target")
        self.batch(baseline, "matched-soft-deleted-target-not-revived", bad=True, expected_error="cost_work_order: 源ID与逻辑键冲突")
        self.sql("UPDATE " + self.biz + ".cost_work_order SET deleted=0 WHERE source_work_order_id='SW1';", "restore-isolated-target-for-next-case")
        bad = copy.deepcopy(baseline)
        bad["stg_project"][0]["project_name"] = "MUST-ROLL-BACK"
        self.sql("INSERT INTO " + self.biz + ".cost_unit_dict(id,accounting_unit_code,accounting_unit_name,status,tenant_id,deleted) VALUES (60001,'A_KEEP_2','手填保留单位2','DISABLE'," + str(TENANT) + ",1);", "seed-late-failure-high-id")
        sequence_before = int(self.sql("SELECT last_value FROM " + self.biz + ".cost_unit_dict_seq;"))
        self.batch(bad, "late-sql-error-rolls-back-previous-business-writes", bad=True, late_failure=True, expected_error="AUDIT_EXPECTED_LATE_FAILURE")
        sequence_after = int(self.sql("SELECT last_value FROM " + self.biz + ".cost_unit_dict_seq;"))
        assert sequence_after >= 60001 and sequence_after >= sequence_before, "Failed transaction rolled sequence backwards"
        self.results.append({"name": "failed-transaction-does-not-rewind-advanced-sequence", "passed": True})
        self.report["passed"] = True

    def finish(self):
        self.report["templates_unchanged_on_disk"] = all((TEMPLATES / name).read_bytes() == data for name, data in self.templates.items())
        (self.output / "result.json").write_text(json.dumps(self.report, ensure_ascii=False, indent=2), encoding="utf-8")
        cleanup = "DROP SCHEMA IF EXISTS " + self.source + " CASCADE;\nDROP SCHEMA IF EXISTS " + self.stage + " CASCADE;\nDROP SCHEMA IF EXISTS " + self.biz + " CASCADE;\n"
        (self.output / "cleanup-only-these-audit-schemas.sql").write_text(cleanup, encoding="utf-8")
        if self.args.cleanup and self.created:
            self.sql(cleanup, "cleanup-created-audit-schemas")
            remaining = self.sql("SELECT count(*) FROM pg_namespace WHERE nspname IN (" + ",".join(literal(name) for name in (self.biz, self.stage, self.source)) + ");", "verify-audit-schemas-cleaned")
            self.report["cleanup_verified"] = remaining == "0"
            (self.output / "result.json").write_text(json.dumps(self.report, ensure_ascii=False, indent=2), encoding="utf-8")
            assert self.report["cleanup_verified"], "Audit schemas remain after cleanup"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", help="Explicitly execute only new audit schemas")
    parser.add_argument("--psql-command-json", default='["psql"]', help="argv prefix; no shell invocation")
    parser.add_argument("--schema-prefix")
    parser.add_argument("--output", required=True)
    parser.add_argument("--cleanup", action="store_true", help="Drop only schemas created by this run after evidence is saved")
    args = parser.parse_args()
    if not args.execute:
        parser.error("No database action without --execute; use py_compile for offline syntax validation")
    audit = Audit(args)
    try:
        audit.run()
    except Exception as error:
        audit.report["passed"] = False
        audit.report["error"] = str(error)
        raise
    finally:
        audit.finish()
        print(json.dumps({"passed": audit.report.get("passed", False), "tests": len(audit.results), "output": str(audit.output)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
