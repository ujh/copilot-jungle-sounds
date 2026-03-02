#!/usr/bin/env python3
"""Extract tool usage from hook JSON and persist compact stats to SQLite."""

import json
import os
import re
import shlex
import sqlite3
import sys


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


def main():
    event_name = os.environ.get("EVENT_NAME", "")
    db_path = os.path.expanduser(os.environ.get("USAGE_DB_PATH", "~/.copilot-jungle-sounds/usage.db"))
    payload = sys.stdin.read().strip()
    if not payload or event_name != "preToolUse":
        return 0

    try:
        data = json.loads(payload)
    except json.JSONDecodeError:
        return 0

    tool_name = find_first_string(
        data,
        [
            "toolName",
            "tool_name",
            "tool",
            "name",
            "toolCallName",
            "tool_call_name",
            "toolIdentifier",
            "tool_identifier",
        ],
    )
    if not tool_name:
        return 0

    command_text = extract_command_text(data)
    executable = extract_executable(command_text) if command_text else ""
    if tool_name not in {"bash", "shell", "sh"}:
        executable = ""

    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    conn = sqlite3.connect(db_path)
    try:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS tool_usage (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              recorded_at TEXT NOT NULL DEFAULT (datetime('now')),
              hook_event TEXT NOT NULL,
              tool_name TEXT NOT NULL,
              executable TEXT
            )
            """
        )
        conn.execute("CREATE INDEX IF NOT EXISTS idx_tool_usage_recorded_at ON tool_usage(recorded_at)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_tool_usage_tool_name ON tool_usage(tool_name)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_tool_usage_executable ON tool_usage(executable)")
        conn.execute(
            "INSERT INTO tool_usage (hook_event, tool_name, executable) VALUES (?, ?, ?)",
            (event_name, tool_name, executable or None),
        )
        conn.commit()
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
