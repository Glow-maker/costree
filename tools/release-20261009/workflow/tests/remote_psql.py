#!/usr/bin/env python3
"""Forward psql stdin/stdout to an existing remote container; never start services."""
import argparse
import re
import shlex
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--host", required=True)
parser.add_argument("--container", required=True)
parser.add_argument("--database", required=True)
args, psql_args = parser.parse_known_args()
if not re.fullmatch(r"[A-Za-z0-9_.@-]+", args.host):
    parser.error("Invalid SSH host")
if any(not re.fullmatch(r"[A-Za-z0-9_-]+", value) for value in (args.container, args.database)):
    parser.error("Invalid container/database name")
remote = "docker exec -i " + shlex.quote(args.container) + " sh -c " + shlex.quote(
    'exec psql -U "$POSTGRES_USER" -d ' + shlex.quote(args.database) + ' "$@"'
) + " psql " + " ".join(shlex.quote(value) for value in psql_args)
raise SystemExit(subprocess.call(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", args.host, remote]))
