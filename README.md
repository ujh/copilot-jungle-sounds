# 🌴 copilot-jungle-sounds

Audio feedback plugin for **GitHub Copilot CLI** that plays jungle and nature sounds during hook events.

## Requirements

- **macOS** (uses `afplay` and `/System/Library/Sounds/`)
- **ffmpeg** (for normalizing/distributing sounds, and for looping short sounds via `ffplay`/`ffprobe`)

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

## Customization

1. Add or replace audio files in `sounds/library/` (`.mp3` and `.wav` are supported).
2. Run `./scripts/normalize-and-distribute.sh` to normalize loudness and refresh event symlinks.
3. For per-event sounds, place files directly in `sounds/<event>/`.
4. Tune playback behavior in `scripts/play-sound.sh` (`VOLUME`, `MIN_DURATION`, event duration case block).
5. Reinstall the plugin after changes:

   ```bash
   copilot plugin install /full/path/to/copilot-jungle-sounds
   ```

## Uninstalling

```bash
copilot plugin uninstall copilot-jungle-sounds
```

## Maintainer Notes

For internal architecture, event distribution details, usage tracking internals, and agent-focused references, see [`AGENTS.md`](AGENTS.md).
