#!/usr/bin/env python3
"""Calculate volume factor based on tool usage frequency."""

import json
import math
import os
import re
import shlex
import sqlite3
import sys

# --- Parsing logic from track-tool-usage.py ---

def parse_json_container(value):
    if not isinstance(value, str):
        return None
    stripped = value.strip()
    if not stripped or stripped[0] not in "{[":
        return None
    try:
        parsed = json.loads(stripped)
    except json.JSONDecodeError:
        return None
    return parsed if isinstance(parsed, (dict, list)) else None


def walk(node):
    parsed = parse_json_container(node)
    if parsed is not None:
        node = parsed
    if isinstance(node, dict):
        yield node
        for value in node.values():
            yield from walk(value)
    elif isinstance(node, list):
        for value in node:
            yield from walk(value)


def find_first_string(node, keys):
    keyset = set(keys)
    for item in walk(node):
        if not isinstance(item, dict):
            continue
        for key in keys:
            value = item.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
        for key, value in item.items():
            if key in keyset and isinstance(value, str) and value.strip():
                return value.strip()
    return ""


def extract_command_text(data):
    command_keys = ["command", "cmd", "bash", "shellCommand", "shell_command"]
    for item in walk(data):
        if not isinstance(item, dict):
            continue
        for args_key in ("toolArgs", "tool_args"):
            args = item.get(args_key)
            parsed_args = parse_json_container(args)
            if parsed_args is not None:
                args = parsed_args
            if not isinstance(args, dict):
                continue
            for key in command_keys:
                value = args.get(key)
                if isinstance(value, str) and value.strip():
                    return value.strip()
    return find_first_string(data, command_keys)


def extract_executable(command_text):
    if not command_text:
        return ""
    try:
        tokens = shlex.split(command_text, posix=True)
    except ValueError:
        tokens = command_text.strip().split()
    if not tokens:
        return ""
    i = 0
    while i < len(tokens):
        token = tokens[i]
        if token in {"env", "/usr/bin/env"}:
            i += 1
            while i < len(tokens):
                candidate = tokens[i]
                if candidate.startswith("-"):
                    i += 1
                    continue
                if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=.*$", candidate):
                    i += 1
                    continue
                break
            continue
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=.*$", token):
            i += 1
            continue
        return os.path.basename(token)
    return ""

# --- End parsing logic ---

def get_median(values):
    if not values:
        return 0
    sorted_values = sorted(values)
    n = len(sorted_values)
    if n % 2 == 1:
        return sorted_values[n // 2]
    else:
        return (sorted_values[n // 2 - 1] + sorted_values[n // 2]) / 2

def main():
    db_path = os.path.expanduser(os.environ.get("USAGE_DB_PATH", "~/.copilot-jungle-sounds/usage.db"))
    
    # 1. Parse payload to identify current tool
    try:
        payload = sys.stdin.read().strip()
        if not payload:
            print("1.00")
            return
        data = json.loads(payload)
    except json.JSONDecodeError:
        print("1.00")
        return

    tool_name = find_first_string(
        data,
        [
            "toolName", "tool_name", "tool", "name", 
            "toolCallName", "tool_call_name", "toolIdentifier", "tool_identifier"
        ],
    )
    
    if not tool_name:
        print("1.00")
        return

    command_text = extract_command_text(data)
    executable = extract_executable(command_text) if command_text else ""
    if tool_name not in {"bash", "shell", "sh"}:
        executable = ""

    # Determine the "item name" for the current tool
    current_item_name = executable if executable else tool_name

    # 2. Connect to DB
    if not os.path.exists(db_path):
        print("1.00")
        return

    conn = sqlite3.connect(db_path)
    try:
        # Check if table exists
        cursor = conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='tool_usage'")
        if not cursor.fetchone():
            print("1.00")
            return

        # 3. Get counts of all items (grouping executables for shell tools)
        rows = conn.execute("""
            SELECT 
                CASE 
                    WHEN executable IS NOT NULL AND executable != '' THEN executable 
                    ELSE tool_name 
                END as name,
                COUNT(*) as cnt
            FROM tool_usage
            GROUP BY name
        """).fetchall()
        
        counts = {row[0]: row[1] for row in rows}
        
        if not counts:
            print("1.00")
            return

        # 4. Calculate median
        median = get_median(list(counts.values()))
        if median == 0:
            print("1.00")
            return

        # 5. Get current item count
        current_count = counts.get(current_item_name, 0)
        
        # If current item not in DB yet (e.g. tracking failed or lagged), treat as 1
        if current_count == 0:
            current_count = 1

        # 6. Calculate factor
        # Formula: clamp(1 / sqrt(count / median), 0.5, 2.0)
        ratio = current_count / median
        if ratio <= 0: # Should not happen if count >= 1
            ratio = 0.0001
            
        factor = 1.0 / math.sqrt(ratio)
        factor = max(0.5, min(2.0, factor))
        
        print(f"{factor:.2f}")

    except Exception:
        # Fallback to 1.0 on any error
        print("1.00")
    finally:
        conn.close()

if __name__ == "__main__":
    main()
