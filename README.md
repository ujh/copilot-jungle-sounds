# 🌴 copilot-jungle-sounds

Audio feedback plugin for **GitHub Copilot CLI** that plays jungle and nature sounds during agent lifecycle events. Hear tropical birds when tools run, forest ambience when sessions start, and wildlife calls when the agent needs your attention.

The plugin ships with pre-loaded jungle-themed MP3s in a central `sounds/library/` directory, with symlinks distributed across event directories. Each time an event fires, a random sound is picked from the corresponding directory — so your coding sessions get a unique tropical soundscape.

## Hook Events

| Event                 | Sounds | Description               |
| --------------------- | ------ | ------------------------- |
| `preToolUse`          | 23     | A tool is about to run    |
| `postToolUse`         | 23     | A tool just completed     |
| `sessionStart`        | 11     | A session started         |
| `sessionEnd`          | 11     | A session ended           |
| `userPromptSubmitted` | 8      | User submitted a prompt   |
| `agentStop`           | 8      | Agent finished responding |
| `subagentStop`        | 8      | A subagent completed      |
| `errorOccurred`       | 8      | An error occurred         |

Tool-use events (`preToolUse`, `postToolUse`) include all sounds for maximum variety, while other events use duration-based subsets — shorter sounds for frequent events, longer atmospheric sounds for rarer ones like `sessionStart`. Event directories contain symlinks to the central `sounds/library/` to avoid file duplication. If a `sounds/<event>/` directory is empty, a macOS system sound is used as a fallback.

## Requirements

- **macOS** (uses `afplay` and `/System/Library/Sounds/`)
- **ffmpeg** (only needed for normalizing/distributing sound files)

## Installation

```bash
# Install from the GitHub repository
copilot plugin install ujh/copilot-jungle-sounds

# Or install from a local clone
git clone https://github.com/ujh/copilot-jungle-sounds.git
copilot plugin install ./copilot-jungle-sounds
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

Hook invocations are logged to `/tmp/copilot-jungle-sounds-YYYY-MM-DD.log` (daily file). Check today's file to verify hooks are firing:

```bash
tail -f "/tmp/copilot-jungle-sounds-$(date +%Y-%m-%d).log"
```

## Customization

### Replacing or adding sounds

All sound files live in `sounds/library/`. Event directories contain symlinks pointing to `../library/`, so each file is stored only once on disk. You can also drop files directly into a `sounds/<event>/` directory for event-specific sounds. The plugin randomly picks one file each time the event fires. Any audio format supported by `afplay` works (`.aiff`, `.wav`, `.mp3`, `.aac`, etc.).

```
sounds/
├── library/             # 23 unique MP3s (single source of truth)
├── preToolUse/          # 23 symlinks (all files)
├── postToolUse/         # 23 symlinks (all files)
├── sessionStart/        # 11 symlinks (longer atmospheric sounds)
├── sessionEnd/          # 11 symlinks (longer atmospheric sounds)
├── userPromptSubmitted/ # 8 symlinks (short-to-medium sounds)
├── agentStop/           # 8 symlinks (medium sounds)
├── subagentStop/        # 8 symlinks (short-medium sounds)
└── errorOccurred/       # 8 symlinks (medium sounds)
```

### Changing fallback system sounds

If a `sounds/<event>/` directory is empty, the plugin falls back to a macOS system sound. Edit `scripts/play-sound.sh` and swap the sound file names in the `case` block. Available macOS system sounds:

```
Basso  Blow  Bottle  Frog  Funk  Glass  Hero  Morse  Ping  Pop  Purr  Sosumi  Submarine  Tink
```

All located at `/System/Library/Sounds/*.aiff`.

### Adjusting volume

Change the `VOLUME` variable at the top of `scripts/play-sound.sh` (0.0 = silent, 1.0 = full volume, default is 0.3).

### Adjusting max duration

Sounds are capped at **60 seconds** of playback. Change the `MAX_DURATION` variable at the top of `scripts/play-sound.sh` to adjust (value is in seconds).

### After making changes

Re-install the plugin to pick up your edits:

```bash
copilot plugin install ./copilot-jungle-sounds
```

### Adding new sound files

To add new MP3 files to the plugin:

1. Drop your `.mp3` files into the `sounds/library/` directory
2. Run the normalize-and-distribute script:

```bash
./scripts/normalize-and-distribute.sh
```

This script:
- **Normalizes volume** of all `*.mp3` files in `sounds/library/` to -23 LUFS using ffmpeg's `loudnorm` filter ([EBU R128](https://en.wikipedia.org/wiki/EBU_R_128) standard, two-pass for accuracy)
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
