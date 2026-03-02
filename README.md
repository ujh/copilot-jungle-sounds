# 🌴 copilot-jungle-sounds

Audio feedback plugin for **GitHub Copilot CLI** and **Claude Code** that plays macOS system sounds during agent lifecycle events. Hear when tools run, complete, and when the agent needs your attention.

## Sound Mapping

| Event           | Sound               | Description                  |
|-----------------|---------------------|------------------------------|
| `PreToolUse`    | Tink (soft tick)    | A tool is about to run       |
| `PostToolUse`   | Pop (subtle pop)    | A tool just completed        |
| `Stop`          | Glass (chime)       | Agent finished responding    |
| `SubagentStart` | Morse (dot)         | A subagent was spawned       |
| `SubagentStop`  | Purr (purr)         | A subagent finished          |
| `Notification`  | Hero (alert)        | Agent needs your attention   |

All hooks run asynchronously (non-blocking) except `Notification`, which plays synchronously to make sure you hear the alert.

## Requirements

- **macOS** (uses `afplay` and `/System/Library/Sounds/`)
- **jq** — for parsing JSON hook input (`brew install jq`)

## Installation

### GitHub Copilot CLI

```bash
# Install from the GitHub repository
copilot plugin install ujh/copilot-jungle-sounds

# Or install from a local clone
git clone https://github.com/ujh/copilot-jungle-sounds.git
copilot plugin install ./copilot-jungle-sounds
```

### Claude Code

```bash
# Install from the GitHub repository
claude plugin install ujh/copilot-jungle-sounds

# Or install from a local clone
git clone https://github.com/ujh/copilot-jungle-sounds.git
claude plugin install ./copilot-jungle-sounds
```

### Verify installation

```bash
# Copilot CLI
copilot plugin list

# Claude Code
claude plugin list
```

## Temporarily Disabling

You can disable the plugin without uninstalling it:

```bash
# Copilot CLI
copilot plugin disable copilot-jungle-sounds

# Claude Code
claude plugin disable copilot-jungle-sounds
```

To re-enable:

```bash
# Copilot CLI
copilot plugin enable copilot-jungle-sounds

# Claude Code
claude plugin enable copilot-jungle-sounds
```

Alternatively, you can disable **all hooks** (from all sources) by adding `"disableAllHooks": true` to your settings file:

- **Copilot CLI**: `~/.copilot/settings.json`
- **Claude Code**: `~/.claude/settings.json`

## Customization

### Changing sounds

Edit `scripts/play-sound.sh` and swap the sound file names in the `case` block. Available macOS system sounds:

```
Basso  Blow  Bottle  Frog  Funk  Glass  Hero  Morse  Ping  Pop  Purr  Sosumi  Submarine  Tink
```

All located at `/System/Library/Sounds/*.aiff`.

### Adjusting volume

Change the `VOLUME` variable at the top of `scripts/play-sound.sh` (0.0 = silent, 1.0 = full volume, default is 0.3).

### After making changes

Re-install the plugin to pick up your edits:

```bash
# Copilot CLI
copilot plugin install ./copilot-jungle-sounds

# Claude Code
claude plugin install ./copilot-jungle-sounds
```

## Uninstalling

```bash
# Copilot CLI
copilot plugin uninstall copilot-jungle-sounds

# Claude Code
claude plugin uninstall copilot-jungle-sounds
```

## License

MIT
