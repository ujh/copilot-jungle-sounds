# 🌴 copilot-jungle-sounds

Audio feedback plugin for **GitHub Copilot CLI** that plays jungle and nature sounds during agent lifecycle events. Hear tropical birds when tools run, forest ambience when sessions start, and wildlife calls when the agent needs your attention.

The plugin ships with pre-loaded jungle-themed audio files (MP3 and WAV) in a central `sounds/library/` directory, with symlinks distributed across event directories. Each time an event fires, a random sound is picked from the corresponding directory — so your coding sessions get a unique tropical soundscape.

## Hook Events

| Event                 | Sounds                   | Description               |
| --------------------- | ------------------------ | ------------------------- |
| `preToolUse`          | All library sounds       | A tool is about to run    |
| `postToolUse`         | All library sounds       | A tool just completed     |
| `sessionStart`        | Longer-duration subset   | A session started         |
| `sessionEnd`          | Longer-duration subset   | A session ended           |
| `userPromptSubmitted` | Short-to-medium subset   | User submitted a prompt   |
| `agentStop`           | Medium subset            | Agent finished responding (includes ask-for-input moments) |
| `subagentStop`        | Short-medium subset      | A subagent completed      |
| `errorOccurred`       | Medium/distinctive subset | An error occurred         |

Tool-use events (`preToolUse`, `postToolUse`) include all sounds for maximum variety, while other events use duration-based subsets — shorter sounds for frequent events, longer atmospheric sounds for rarer ones like `sessionStart`. Event directories contain symlinks to the central `sounds/library/` to avoid file duplication. If a `sounds/<event>/` directory is empty, a macOS system sound is used as a fallback.

> **Soundscape design:** Sounds are intentionally allowed to overlap — when multiple events fire in quick succession (e.g., rapid tool calls), the layered audio creates an evolving jungle soundscape rather than cutting off abruptly.

## Requirements

- **macOS** (uses `afplay` and `/System/Library/Sounds/`)
- **ffmpeg** (needed for normalizing/distributing sound files, and for looping short sounds during playback via `ffplay`/`ffprobe`)

## Installation

```bash
# Install from the GitHub repository
copilot plugin install ujh/copilot-jungle-sounds

# Or install from a local clone (use the full path to the directory)
git clone https://github.com/ujh/copilot-jungle-sounds.git
copilot plugin install /full/path/to/copilot-jungle-sounds
```

### Verify installation

```bash
copilot plugin list
```

## Temporarily Disabling

You can disable the plugin without uninstalling it:

```bash
copilot plugin disable copilot-jungle-sounds
```

To re-enable:

```bash
copilot plugin enable copilot-jungle-sounds
```

Alternatively, you can disable **all hooks** (from all sources) by adding `"disableAllHooks": true` to `~/.copilot/settings.json`.

## Debugging

Hook invocations and the received hook payload input are logged to `/tmp/copilot-jungle-sounds-YYYY-MM-DD.log` (daily file). Check today's file to verify hooks are firing and inspect payload shape:

```bash
tail -f "/tmp/copilot-jungle-sounds-$(date +%Y-%m-%d).log"
```

## Tool Usage Statistics

Tool usage is tracked from `preToolUse` hook payloads into SQLite at:

```text
~/.copilot-jungle-sounds/usage.db
```

Stored fields are limited to:
- hook event
- tool name
- executable name for shell tools (for example `find`)

The full command text is not stored.

Generate stats on demand:

```bash
./scripts/tool-stats.sh
./scripts/tool-stats.sh --today
./scripts/tool-stats.sh --since 2026-03-01T00:00:00
```

## Customization

### Replacing or adding sounds

All sound files live in `sounds/library/`. Event directories contain symlinks pointing to `../library/`, so each file is stored only once on disk. You can also drop files directly into a `sounds/<event>/` directory for event-specific sounds. The plugin randomly picks one file each time the event fires. Any audio format supported by `afplay` works (`.aiff`, `.wav`, `.mp3`, `.aac`, etc.).

```
sounds/
├── library/             # Unique audio files — MP3 and WAV (single source of truth)
├── preToolUse/          # symlinks to all library files
├── postToolUse/         # symlinks to all library files
├── sessionStart/        # longer atmospheric subset
├── sessionEnd/          # longer atmospheric subset
├── userPromptSubmitted/ # short-to-medium subset
├── agentStop/           # medium subset
├── subagentStop/        # short-medium subset
└── errorOccurred/       # medium/distinctive subset
```

### Changing fallback system sounds

If a `sounds/<event>/` directory is empty, the plugin falls back to a macOS system sound. Edit `scripts/play-sound.sh` and swap the sound file names in the `case` block. Available macOS system sounds:

```
Basso  Blow  Bottle  Frog  Funk  Glass  Hero  Morse  Ping  Pop  Purr  Sosumi  Submarine  Tink
```

All located at `/System/Library/Sounds/*.aiff`.

### Adjusting volume

Change the `VOLUME` variable at the top of `scripts/play-sound.sh` (0.0 = silent, 1.0 = full volume, default is `0.10`). The `agentStop` event is played at 2x this base value (capped at `1.0`) to create a stronger attention cue.

### Adjusting max duration

Playback duration is set in `scripts/play-sound.sh` by event type:
- `preToolUse` and `postToolUse`: `60` seconds
- all other events: `120` seconds

Adjust those values in the event-duration `case` block to customize max playback time.

### Adjusting minimum duration (short file looping)

Sound files shorter than **30 seconds** are automatically looped using `ffplay` so playback can fill the configured event duration window. The original audio files are not modified. Change the `MIN_DURATION` variable at the top of `scripts/play-sound.sh` to adjust. Set to `0` to disable looping. Requires `ffprobe` and `ffplay` (both included with ffmpeg).

### After making changes

Re-install the plugin to pick up your edits:

```bash
copilot plugin install /full/path/to/copilot-jungle-sounds
```

### Adding new sound files

To add new sound files to the plugin:

1. Drop your `.mp3` or `.wav` files into the `sounds/library/` directory
2. Run the normalize-and-distribute script:

```bash
./scripts/normalize-and-distribute.sh
```

This script:
- **Normalizes volume** of all audio files (`*.mp3`, `*.wav`) in `sounds/library/` to -23 LUFS using ffmpeg's `loudnorm` filter ([EBU R128](https://en.wikipedia.org/wiki/EBU_R_128) standard, two-pass for accuracy). Each format is normalized in-place (WAV stays WAV, MP3 stays MP3).
- **Distributes** symlinks into the `sounds/<event>/` directories based on duration — shorter sounds go to more frequently-fired events (like `preToolUse`), longer atmospheric sounds go to rarer events (like `sessionStart`)

The script is safe to re-run — it re-normalizes all files and recreates symlinks in `sounds/<event>/` directories.

> **Prerequisite:** ffmpeg must be installed (`brew install ffmpeg`).

## Uninstalling

```bash
copilot plugin uninstall copilot-jungle-sounds
```

## Copilot CLI Documentation

This plugin uses the **hooks** system of GitHub Copilot CLI. The official documentation lives at:

- **Copilot CLI overview**: https://docs.github.com/en/copilot/how-tos/copilot-cli
- **Using hooks**: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-hooks
- **Hooks configuration reference**: https://docs.github.com/en/copilot/reference/hooks-configuration
- **About hooks (conceptual)**: https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-hooks
- **Plugin reference**: https://docs.github.com/en/copilot/reference/cli-plugin-reference
- **Creating plugins**: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-creating

> **Tip for LLMs:** The GitHub Docs API serves article bodies as markdown at
> `https://docs.github.com/api/article/body?pathname=<PATH>` where `<PATH>` is
> the URL path (e.g. `/en/copilot/reference/hooks-configuration`). Use this
> endpoint to fetch the full content of any docs page listed above.
