# 🌴 copilot-jungle-sounds

Audio feedback plugin for **GitHub Copilot CLI** that plays macOS system sounds during agent lifecycle events. Hear when tools run, complete, and when the agent needs your attention.

## Sound Mapping

| Event                 | Sound              | Description               |
| --------------------- | ------------------ | ------------------------- |
| `preToolUse`          | Tink (soft tick)   | A tool is about to run    |
| `postToolUse`         | Pop (subtle pop)   | A tool just completed     |
| `sessionStart`        | Morse (dot)        | A session started         |
| `sessionEnd`          | Glass (chime)      | A session ended           |
| `userPromptSubmitted` | Submarine (sonar)  | User submitted a prompt   |
| `agentStop`           | Purr (gentle hum)  | Agent finished responding |
| `subagentStop`        | Blow (soft whoosh) | A subagent completed      |
| `errorOccurred`       | Hero (alert)       | An error occurred         |

## Requirements

- **macOS** (uses `afplay` and `/System/Library/Sounds/`)

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

Hook invocations are logged to `/tmp/copilot-jungle-sounds.log`. Check this file to verify hooks are firing:

```bash
tail -f /tmp/copilot-jungle-sounds.log
```

## Customization

### Custom sounds per hook

Drop audio files into the `sounds/<event>/` directory for any hook event. When custom files are present, the plugin randomly picks one each time the hook fires. If the directory is empty, the default system sound is used as a fallback.

```
sounds/
├── preToolUse/          # Drop custom sounds here for preToolUse
├── postToolUse/
├── sessionStart/
├── sessionEnd/
├── userPromptSubmitted/
├── agentStop/
├── subagentStop/
└── errorOccurred/
```

Any audio format supported by `afplay` works (`.aiff`, `.wav`, `.mp3`, `.aac`, etc.).

### Changing default sounds

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
copilot plugin install ./copilot-jungle-sounds
```

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
