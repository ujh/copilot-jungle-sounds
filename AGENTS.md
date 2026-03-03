# Copilot Instructions

## Documentation Split

- `README.md` is the human-facing quickstart and day-to-day usage guide.
- `AGENTS.md` is for internal architecture, conventions, and agent-oriented implementation details.

## Project Overview

This is a **GitHub Copilot CLI plugin** that plays jungle/nature sounds during agent lifecycle events (tool use, session start/end, prompts, errors, etc.). It targets **macOS only** (`afplay` for playback, `ffplay`/`ffprobe` for looping short files).

## Hook Events

| Event                 | Sounds                    | Description                                                       |
| --------------------- | ------------------------- | ----------------------------------------------------------------- |
| `preToolUse`          | All library sounds        | A tool is about to run                                            |
| `postToolUse`         | All library sounds        | A tool just completed                                             |
| `sessionStart`        | Longer-duration subset    | A session started                                                 |
| `sessionEnd`          | Longer-duration subset    | A session ended                                                   |
| `userPromptSubmitted` | Short-to-medium subset    | User submitted a prompt                                           |
| `agentStop`           | Attention-grabbing subset | Agent finished responding (includes ask-for-input moments)        |
| `subagentStop`        | Short-medium subset       | A subagent completed                                              |
| `errorOccurred`       | Medium/distinctive subset | An error occurred                                                 |

## Architecture

- **`plugin.json`** — Plugin manifest registered with `copilot plugin install`. Points to `hooks.json`.
- **`hooks.json`** — Maps each Copilot CLI hook event to `./scripts/play-sound.sh <event>`.
- **`scripts/play-sound.sh`** — Core playback script. Picks a random sound from `sounds/<event>/`, falls back to a macOS system sound. Short files (< `MIN_DURATION`) are looped via `ffplay`; others play via `afplay`. Drains stdin (Copilot sends JSON on stdin to hooks). All invocations log to `/tmp/copilot-jungle-sounds-YYYY-MM-DD.log`.
- **`scripts/track-tool-usage.py`** — Extracts minimal tool metadata from `preToolUse` payloads and stores it in SQLite.
- **`scripts/tool-stats.sh`** — Reads usage SQLite data and prints aggregate counts by tool/executable.
- **`scripts/normalize-and-distribute.sh`** — Normalizes MP3 volume to -23 LUFS (EBU R128, two-pass `loudnorm`) and distributes symlinks from `sounds/library/` into `sounds/<event>/` directories based on duration percentile ranges. Safe to re-run.
- **`sounds/library/`** — Single source of truth for sound files.
- **`sounds/<event>/`** — Contain symlinks to `../library/`. Tool-use events get all files; other events get duration-based subsets (shorter sounds for frequent events, longer atmospheric sounds for rare ones).

## Key Conventions

- Tool-use events (`preToolUse`, `postToolUse`) include all sounds; other events use duration-based subsets.
- Sound files are **never duplicated** — event directories use symlinks pointing to `../library/<file>`.
- Sounds are intentionally allowed to overlap; hooks do not cut off previous playback.
- If `sounds/<event>/` is empty, the plugin falls back to macOS system sounds.
- After adding/removing files in `sounds/library/`, run `./scripts/normalize-and-distribute.sh` to re-normalize and redistribute symlinks.
- After any changes, the plugin must be reinstalled: `copilot plugin install /path/to/copilot-jungle-sounds`.
- All shell scripts use `set -euo pipefail` and are Bash-specific.
- Configurable constants (`VOLUME`, `MAX_DURATION`, `MIN_DURATION`) live at the top of `scripts/play-sound.sh`.

## Tool Usage Tracking

Usage data from `preToolUse` events is written to:

```text
~/.copilot-jungle-sounds/usage.db
```

Stored fields are intentionally limited to:
- hook event
- tool name
- executable name for shell tools (for example `find`)

The full command text is not stored.

Generate stats:

```bash
./scripts/tool-stats.sh
./scripts/tool-stats.sh --today
./scripts/tool-stats.sh --since 2026-03-01T00:00:00
```

## Requirements

- macOS (uses `afplay` and `/System/Library/Sounds/`)
- ffmpeg/ffprobe/ffplay (for normalization, duration detection, and looping)

## Copilot CLI References

- **Copilot CLI overview**: https://docs.github.com/en/copilot/how-tos/copilot-cli
- **Using hooks**: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-hooks
- **Hooks configuration reference**: https://docs.github.com/en/copilot/reference/hooks-configuration
- **About hooks (conceptual)**: https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-hooks
- **Plugin reference**: https://docs.github.com/en/copilot/reference/cli-plugin-reference
- **Creating plugins**: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-creating

### LLM Retrieval Tip

GitHub Docs serves article bodies as markdown at:
`https://docs.github.com/api/article/body?pathname=<PATH>`

Use the docs page path as `<PATH>` (for example `/en/copilot/reference/hooks-configuration`).
