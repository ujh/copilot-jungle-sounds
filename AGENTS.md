# Copilot Instructions

## Project Overview

This is a **GitHub Copilot CLI plugin** that plays jungle/nature sounds during agent lifecycle events (tool use, session start/end, prompts, errors, etc.). It targets **macOS only** (`afplay` for playback, `ffplay`/`ffprobe` for looping short files).

## Architecture

- **`plugin.json`** — Plugin manifest registered with `copilot plugin install`. Points to `hooks.json`.
- **`hooks.json`** — Maps each Copilot CLI hook event to `./scripts/play-sound.sh <event>`.
- **`scripts/play-sound.sh`** — Core playback script. Picks a random sound from `sounds/<event>/`, falls back to a macOS system sound. Short files (< `MIN_DURATION`) are looped via `ffplay`; others play via `afplay`. Drains stdin (Copilot sends JSON on stdin to hooks). All invocations log to `/tmp/copilot-jungle-sounds-YYYY-MM-DD.log`.
- **`scripts/normalize-and-distribute.sh`** — Normalizes MP3 volume to -23 LUFS (EBU R128, two-pass `loudnorm`) and distributes symlinks from `sounds/library/` into `sounds/<event>/` directories based on duration percentile ranges. Safe to re-run.
- **`sounds/library/`** — Single source of truth for all MP3 files.
- **`sounds/<event>/`** — Contain symlinks to `../library/`. Tool-use events get all files; other events get duration-based subsets (shorter sounds for frequent events, longer atmospheric sounds for rare ones).

## Key Conventions

- Sound files are **never duplicated** — event directories use symlinks pointing to `../library/<file>.mp3`.
- After adding/removing MP3s in `sounds/library/`, run `./scripts/normalize-and-distribute.sh` to re-normalize and redistribute symlinks.
- After any changes, the plugin must be reinstalled: `copilot plugin install /path/to/copilot-jungle-sounds`.
- All shell scripts use `set -euo pipefail` and are Bash-specific.
- Configurable constants (`VOLUME`, `MAX_DURATION`, `MIN_DURATION`) live at the top of `scripts/play-sound.sh`.

## Requirements

- macOS (uses `afplay` and `/System/Library/Sounds/`)
- ffmpeg/ffprobe/ffplay (for normalization, duration detection, and looping)
