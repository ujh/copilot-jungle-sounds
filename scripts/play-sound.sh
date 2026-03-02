#!/bin/bash
# play-sound.sh — Plays macOS system sounds based on Copilot CLI hook events.
# Usage: play-sound.sh <event_name>
# Event name is passed as a CLI argument from hooks.json.

set -euo pipefail

SOUNDS_DIR="/System/Library/Sounds"
VOLUME="0.15"
MAX_DURATION="60"
LOG_FILE="/tmp/copilot-jungle-sounds.log"

EVENT="${1:-}"

# Log invocation
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Hook invoked: event='$EVENT'" >> "$LOG_FILE"

# Drain stdin (Copilot CLI sends JSON on stdin; we don't need it but must consume it)
cat > /dev/null 2>/dev/null || true

case "$EVENT" in
  preToolUse)            SOUND="Tink.aiff" ;;
  postToolUse)           SOUND="Pop.aiff" ;;
  sessionStart)          SOUND="Morse.aiff" ;;
  sessionEnd)            SOUND="Glass.aiff" ;;
  userPromptSubmitted)   SOUND="Submarine.aiff" ;;
  agentStop)             SOUND="Purr.aiff" ;;
  subagentStop)          SOUND="Blow.aiff" ;;
  errorOccurred)         SOUND="Hero.aiff" ;;
  *)
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Unknown event: '$EVENT'" >> "$LOG_FILE"
    exit 0
    ;;
esac

SOUND_FILE="$SOUNDS_DIR/$SOUND"

# Check for custom sounds in sounds/<event>/ directory
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CUSTOM_SOUNDS_DIR="$PLUGIN_DIR/sounds/$EVENT"
CUSTOM_FILES=()
if [[ -d "$CUSTOM_SOUNDS_DIR" ]]; then
  while IFS= read -r -d '' f; do
    CUSTOM_FILES+=("$f")
  done < <(find "$CUSTOM_SOUNDS_DIR" -maxdepth 1 -type f ! -name '.keep' -print0 2>/dev/null)
fi

if [[ ${#CUSTOM_FILES[@]} -gt 0 ]]; then
  SOUND_FILE="${CUSTOM_FILES[$((RANDOM % ${#CUSTOM_FILES[@]}))]}"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Custom sound selected: $SOUND_FILE (${#CUSTOM_FILES[@]} available)" >> "$LOG_FILE"
fi

if [[ -f "$SOUND_FILE" ]] && command -v afplay &>/dev/null; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Playing: $SOUND_FILE" >> "$LOG_FILE"
  afplay -v "$VOLUME" -t "$MAX_DURATION" "$SOUND_FILE" &
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Cannot play: file=$SOUND_FILE afplay=$(command -v afplay 2>/dev/null || echo 'not found')" >> "$LOG_FILE"
fi

exit 0
