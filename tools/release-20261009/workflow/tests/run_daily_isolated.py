#!/usr/bin/env python3
"""Run actual daily-runner generated SQL in new audit-only business/stage/source schemas."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from run_isolated import Audit, HERE, TENANT, fixture, literal


def create_sources(audit):
    data = fixture()
    sql = ["CREATE SCHEMA " + audit.source + ";"]

    def table(name, fields, rows):
        columns = fields.split()
        sql.append("CREATE TABLE " + audit.source + "." + name + " (" + ",".join(c + " text" for c in columns) + ");")
        for row in rows:
            sql.append("INSERT INTO " + audit.source + "." + name + " VALUES (" + ",".join(literal(row.get(c)) for c in columns) + ");")

    table("unit_dict", "source_record_id accounting_unit_id accounting_unit_code accounting_unit_name manage_unit_code manage_unit_name manage_unit_group contact_unit_code contact_unit_name inside_group inside_institute disabled source_update_time source_deleted", data["stg_unit_dict"])
    nodes = [dict(lshsxm_xmnm=r["node_code"], lshsxm_xmmc=r["node_name"], parent_xmnm=r["parent_node_code"], lshsxm_js=str(i + 1), lshsxm_id="SP1" if i == 2 else None, lshsxm_xmbh="P1" if i == 2 else None) for i, r in enumerate(data["stg_model_node"])]
    table("ads_lc_lshsxm2022", "lshsxm_xmnm lshsxm_xmmc parent_xmnm lshsxm_js lshsxm_id lshsxm_xmbh disabled lastmodifiedtime source_deleted", nodes)
    table("precontrol_project_unit_amount", "source_record_id source_update_time project_code project_name accounting_unit_code contract_amount income_amount source_deleted", [dict(r, contract_amount=r["contract_amount_wan"], income_amount=r["income_amount_wan"]) for r in data["stg_unit_amount"]])
    table("dwd_bd_bfcustomitem_gzl", "id zyxmcode zyxmname accountorgcode cusitemcode cusitemname isdisabled timestamp_lastchangedon2 timestamp_lastchangedon source_deleted", [dict(id=r["source_work_order_id"], zyxmcode=r["project_code"], accountorgcode=r["accounting_unit_code"], cusitemcode=r["work_order_no"], cusitemname=r["work_order_name"], isdisabled="0") for r in data["stg_work_order"]])
    ledger_names = dict(ysnm="source_detail_id", kjnd="fiscal_year", pzrq="voucher_date", dwbh="accounting_unit_code", xmbh="project_code", gzlnm="source_work_order_id", gzllb="work_order_no", jzfx="debit_credit", je="amount_yuan", ejkmbh="second_subject_code")
    table("dws_bu_pz_pzmx_gzl", "ysnm kjnd kjqj pzrq pzbh dwid dwbh kmid kmbh kmmc xmbh xmnm xmmc gzlnm gzllb gzlmc jzfx je yt lastmodifiedtime ejkmbh ejkmmc dwts source_deleted", [{dst: r.get(src) for dst, src in ledger_names.items()} for r in data["stg_ledger_detail"]])
    sql.append("CREATE TABLE " + audit.source + ".publication(snapshot_tag text,is_complete boolean); INSERT INTO " + audit.source + ".publication VALUES ('FIXTURE-UPSTREAM-20261009-001',true);")
    audit.sql("\n".join(sql), "create-isolated-upstream-fixture")


def stage_state(audit):
    tables = ["sync_control", "batch_register", "sync_history", "load_receipt"]
    queries = ["SELECT " + literal(t) + "||'|'||COALESCE(json_agg(r),'[]'::json)::text FROM (SELECT * FROM " + audit.stage + "." + t + " ORDER BY 1) r" for t in tables]
    return audit.sql(" UNION ALL ".join(queries) + ";")


def daily(audit, config, readiness, label, expected_error=None):
    runner = HERE.parent / "daily-runner.py"
    result = subprocess.run([sys.executable, "-X", "utf8", str(runner), "--config", str(config), "--out", str(audit.output / "generated"), "--source-readiness", str(readiness)], capture_output=True, encoding="utf-8", errors="strict", check=True)
    (audit.output / (label + "-render.log")).write_text(result.stdout + result.stderr, encoding="utf-8")
    rendered = json.loads(result.stdout.splitlines()[0])
    path = audit.output / "generated" / rendered["batch_code"] / "daily-atomic.sql"
    audit.sql(path.read_text(encoding="utf-8"), label, failure=expected_error is not None, expected_error=expected_error)
    return rendered["batch_code"]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--execute", action="store_true")
    p.add_argument("--psql-command-json", default='["psql"]')
    p.add_argument("--schema-prefix")
    p.add_argument("--output", required=True)
    p.add_argument("--cleanup", action="store_true")
    args = p.parse_args()
    if not args.execute:
        p.error("No database action without --execute")
    audit = Audit(args)
    audit.report["kind"] = "actual-generated-daily-runner"
    audit.report["source_schema"] = audit.source
    audit.report["daily_runner_sha256"] = hashlib.sha256((HERE.parent / "daily-runner.py").read_bytes()).hexdigest()
    try:
        audit.initialize()
        create_sources(audit)
        config = audit.output / "fixture-config.json"
        config.write_text(json.dumps(dict(business_schema=audit.biz, stage_schema=audit.stage, source_schema=audit.source, tenant_id=TENANT, source_mapping_confirmed=True)), encoding="utf-8")
        readiness = audit.output / "fixture-readiness.sql"
        readiness.write_text("SELECT snapshot_tag,is_complete FROM " + audit.source + ".publication;", encoding="utf-8")
        first = daily(audit, config, readiness, "daily-first-import")
        audit.results.append(dict(name="actual-daily-generated-sql-first-import", passed=True))
        audit.seed_manual()
        protected, ids = audit.protected(), audit.ids()
        second = daily(audit, config, readiness, "daily-second-import")
        assert first != second, "Daily batch was reused"
        assert protected == audit.protected() and ids == audit.ids(), "Daily repeat changed protected fields or IDs"
        audit.results.append(dict(name="daily-unique-batch-and-protected-fields-id-preserved", passed=True))
        tag_count = audit.sql("SELECT count(*) FROM " + audit.stage + ".batch_register WHERE snapshot_tag='FIXTURE-UPSTREAM-20261009-001' AND batch_code IN (" + literal(first) + "," + literal(second) + ");")
        assert tag_count == "2", "Upstream publication tag was not recorded for both batches"
        audit.results.append(dict(name="real-upstream-tag-recorded-in-batch-register", passed=True))
        amount = audit.sql("SELECT book_cost_amount FROM " + audit.biz + ".cost_work_order WHERE work_order_no='W1';")
        assert amount == "0.02", "Daily runner changed original-yuan precision"
        audit.results.append(dict(name="daily-original-yuan-before-conversion-precision", passed=True))
        before, before_stage = audit.business(), stage_state(audit)
        audit.sql("UPDATE " + audit.source + ".publication SET is_complete=false;", "fixture-upstream-not-ready")
        daily(audit, config, readiness, "daily-upstream-not-ready", expected_error="上游完整发布证据缺失/不完整")
        assert before == audit.business() and before_stage == stage_state(audit), "Upstream false changed business or stage control"
        audit.results.append(dict(name="upstream-not-ready-rejects-and-rolls-back-daily-transaction", passed=True))
        audit.report["passed"] = True
    except Exception as error:
        audit.report.update(passed=False, error=str(error))
        raise
    finally:
        audit.finish()
        print(json.dumps(dict(passed=audit.report.get("passed", False), tests=len(audit.results), output=str(audit.output)), ensure_ascii=False))


if __name__ == "__main__":
    main()
