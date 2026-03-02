#!/bin/bash
# play-sound.sh — Plays sounds based on Copilot CLI hook events.
# Supports MP3, WAV, and any format handled by afplay/ffplay on macOS.
# Usage: play-sound.sh <event_name>
# Event name is passed as a CLI argument from hooks.json.

set -euo pipefail

SOUNDS_DIR="/System/Library/Sounds"
VOLUME="0.10"
MIN_DURATION="30"
LOG_FILE="/tmp/copilot-jungle-sounds-$(date '+%Y-%m-%d').log"
USAGE_DIR="${HOME}/.copilot-jungle-sounds"
USAGE_DB="${USAGE_DIR}/usage.db"
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TRACK_USAGE_SCRIPT="$PLUGIN_DIR/scripts/track-tool-usage.py"

EVENT="${1:-}"
HOOK_PAYLOAD="$(cat 2>/dev/null || true)"

# Log invocation
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Hook invoked: event='$EVENT'" >> "$LOG_FILE"

record_tool_usage() {
  local event="$1"
  local payload="$2"

  [[ "$event" != "preToolUse" ]] && return 0
  [[ -z "${payload//[[:space:]]/}" ]] && return 0

  if ! command -v python3 &>/dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Cannot record usage: python3 not found" >> "$LOG_FILE"
    return 0
  fi

  if [[ ! -f "$TRACK_USAGE_SCRIPT" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Cannot record usage: tracker script not found" >> "$LOG_FILE"
    return 0
  fi

  if ! printf '%s' "$payload" | EVENT_NAME="$event" USAGE_DB_PATH="$USAGE_DB" python3 "$TRACK_USAGE_SCRIPT"
  then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to persist tool usage data" >> "$LOG_FILE"
  fi
}

record_tool_usage "$EVENT" "$HOOK_PAYLOAD"

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

# Set max playback duration based on event type
case "$EVENT" in
  preToolUse|postToolUse) MAX_DURATION="60" ;;
  *)                      MAX_DURATION="120" ;;
esac

SOUND_FILE="$SOUNDS_DIR/$SOUND"

# Check for custom sounds in sounds/<event>/ directory
CUSTOM_SOUNDS_DIR="$PLUGIN_DIR/sounds/$EVENT"
CUSTOM_FILES=()
if [[ -d "$CUSTOM_SOUNDS_DIR" ]]; then
  while IFS= read -r -d '' f; do
    CUSTOM_FILES+=("$f")
  done < <(find -L "$CUSTOM_SOUNDS_DIR" -maxdepth 1 -type f -print0 2>/dev/null)
fi

if [[ ${#CUSTOM_FILES[@]} -gt 0 ]]; then
  SOUND_FILE="${CUSTOM_FILES[$((RANDOM % ${#CUSTOM_FILES[@]}))]}"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Custom sound selected: $SOUND_FILE (${#CUSTOM_FILES[@]} available)" >> "$LOG_FILE"
fi

if [[ ! -f "$SOUND_FILE" ]]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Cannot play: file=$SOUND_FILE not found" >> "$LOG_FILE"
elif command -v afplay &>/dev/null; then
  # Check if the file is short and needs looping
  NEEDS_LOOP=false
  if command -v ffprobe &>/dev/null; then
    FILE_DURATION=$(ffprobe -i "$SOUND_FILE" -show_entries format=duration -v quiet -of csv="p=0" 2>/dev/null || echo "")
    FILE_DURATION_INT=${FILE_DURATION%.*}
    if [[ -n "$FILE_DURATION_INT" ]] && [[ "$FILE_DURATION_INT" -lt "$MIN_DURATION" ]]; then
      NEEDS_LOOP=true
    fi
  fi

  if [[ "$NEEDS_LOOP" == true ]] && command -v ffplay &>/dev/null; then
    FFPLAY_VOLUME=$(awk "BEGIN {printf \"%d\", $VOLUME * 100}")
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Looping short file (${FILE_DURATION_INT}s < ${MIN_DURATION}s): $SOUND_FILE" >> "$LOG_FILE"
    ffplay -nodisp -autoexit -loglevel quiet -volume "$FFPLAY_VOLUME" -stream_loop -1 -t "$MAX_DURATION" "$SOUND_FILE" </dev/null >/dev/null 2>&1 &
    disown
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Playing: $SOUND_FILE" >> "$LOG_FILE"
    afplay -v "$VOLUME" -t "$MAX_DURATION" "$SOUND_FILE" </dev/null >/dev/null 2>&1 &
    disown
  fi
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Cannot play: afplay not found" >> "$LOG_FILE"
fi

exit 0
