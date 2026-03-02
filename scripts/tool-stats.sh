#!/bin/bash
# tool-stats.sh — Show Copilot tool usage statistics from SQLite.

set -euo pipefail

DB_PATH="${HOME}/.copilot-jungle-sounds/usage.db"
FILTER_MODE="all"
SINCE_VALUE=""

usage() {
  cat <<'EOF'
Usage: ./scripts/tool-stats.sh [--today] [--since YYYY-MM-DDTHH:MM:SS] [--db PATH]

Options:
  --today     Show only rows from the current UTC day.
  --since     Show only rows at/after the provided UTC timestamp.
  --db        Override database path (default: ~/.copilot-jungle-sounds/usage.db).
  --help      Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --today)
      FILTER_MODE="today"
      shift
      ;;
    --since)
      [[ $# -ge 2 ]] || { echo "ERROR: --since requires a timestamp." >&2; exit 1; }
      FILTER_MODE="since"
      SINCE_VALUE="$2"
      shift 2
      ;;
    --db)
      [[ $# -ge 2 ]] || { echo "ERROR: --db requires a path." >&2; exit 1; }
      DB_PATH="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 is required." >&2
  exit 1
fi

if [[ ! -f "$DB_PATH" ]]; then
  echo "No usage database found at: $DB_PATH"
  exit 0
fi

python3 - "$DB_PATH" "$FILTER_MODE" "$SINCE_VALUE" <<'PY'
import sqlite3
import sys


def print_table(headers, rows):
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(str(cell)))
    line = " | ".join(headers[i].ljust(widths[i]) for i in range(len(headers)))
    sep = "-+-".join("-" * widths[i] for i in range(len(headers)))
    print(line)
    print(sep)
    for row in rows:
        print(" | ".join(str(row[i]).ljust(widths[i]) for i in range(len(headers))))
    print()


db_path, filter_mode, since_value = sys.argv[1], sys.argv[2], sys.argv[3]
conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row

where_sql = ""
params = []
label = "all time"
if filter_mode == "today":
    where_sql = "WHERE recorded_at >= datetime('now', 'start of day')"
    label = "today (UTC)"
elif filter_mode == "since":
    where_sql = "WHERE recorded_at >= datetime(?)"
    params.append(since_value)
    label = f"since {since_value} (UTC)"

total = conn.execute(f"SELECT COUNT(*) AS c FROM tool_usage {where_sql}", params).fetchone()["c"]
print(f"Database: {db_path}")
print(f"Window: {label}")
print(f"Total tracked tool calls: {total}\n")

tool_rows = conn.execute(
    f"""
    SELECT tool_name, COUNT(*) AS count
    FROM tool_usage
    {where_sql}
    GROUP BY tool_name
    ORDER BY count DESC, tool_name ASC
    """,
    params,
).fetchall()
if tool_rows:
    print("By tool:")
    print_table(["Tool", "Count"], [(row["tool_name"], row["count"]) for row in tool_rows])
else:
    print("By tool:\n(no rows)\n")

exec_rows = conn.execute(
    f"""
    SELECT executable, COUNT(*) AS count
    FROM tool_usage
    {(where_sql + " AND executable IS NOT NULL AND executable != ''") if where_sql else "WHERE executable IS NOT NULL AND executable != ''"}
    GROUP BY executable
    ORDER BY count DESC, executable ASC
    """,
    params,
).fetchall()
if exec_rows:
    print("By executable (shell tools):")
    print_table(["Executable", "Count"], [(row["executable"], row["count"]) for row in exec_rows])
else:
    print("By executable (shell tools):\n(no rows)\n")
PY
