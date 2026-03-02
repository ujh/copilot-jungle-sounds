#!/bin/bash
# play-sound.sh — Plays macOS system sounds based on Copilot CLI / Claude Code hook events.
# Reads hook event JSON from stdin and maps hook_event_name to a sound file.

set -euo pipefail

SOUNDS_DIR="/System/Library/Sounds"
VOLUME="0.3"

# Read the hook event name from stdin JSON
EVENT=$(jq -r '.hook_event_name // empty' 2>/dev/null)

case "$EVENT" in
  PreToolUse)      SOUND="Tink.aiff" ;;
  PostToolUse)     SOUND="Pop.aiff" ;;
  Stop)            SOUND="Glass.aiff" ;;
  SubagentStart)   SOUND="Morse.aiff" ;;
  SubagentStop)    SOUND="Purr.aiff" ;;
  Notification)    SOUND="Hero.aiff" ;;
  *)               exit 0 ;;
esac

SOUND_FILE="$SOUNDS_DIR/$SOUND"

if [[ -f "$SOUND_FILE" ]] && command -v afplay &>/dev/null; then
  afplay -v "$VOLUME" "$SOUND_FILE" &
fi

exit 0
