#!/bin/bash
# normalize-and-distribute.sh — Normalize audio volume and distribute into sounds/<event>/ directories
#
# Uses ffmpeg's loudnorm filter (EBU R128) for perceptual loudness normalization.
# Two-pass approach: first pass measures, second pass applies precise correction.
# Supports MP3 and WAV files. Each format is normalized in-place (WAV stays WAV,
# MP3 stays MP3).
#
# Usage:
#   ./scripts/normalize-and-distribute.sh
#
# Prerequisites:
#   - ffmpeg (with loudnorm filter support)
#
# The script reads *.mp3 and *.wav from sounds/library/, normalizes them in-place,
# and creates symlinks in sounds/<event>/ directories based on duration (shorter
# sounds go to more frequently-fired events).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIBRARY_DIR="$PLUGIN_DIR/sounds/library"

TARGET_LUFS="-23"
TARGET_TP="-1.0"
TARGET_LRA="11"

echo "=== Normalize and Distribute Audio Sounds ==="
echo "Target loudness: ${TARGET_LUFS} LUFS (EBU R128)"
echo ""

# Check ffmpeg and ffprobe are available
if ! command -v ffmpeg &>/dev/null; then
  echo "ERROR: ffmpeg is required but not found. Install it with: brew install ffmpeg" >&2
  exit 1
fi
if ! command -v ffprobe &>/dev/null; then
  echo "ERROR: ffprobe is required but not found. Install it with: brew install ffmpeg" >&2
  exit 1
fi

# Ensure library directory exists
mkdir -p "$LIBRARY_DIR"

# Collect MP3 and WAV files from sounds/library/
AUDIO_FILES=()
for f in "$LIBRARY_DIR"/*.mp3 "$LIBRARY_DIR"/*.wav; do
  [[ -f "$f" ]] && AUDIO_FILES+=("$(basename "$f")")
done

if [[ ${#AUDIO_FILES[@]} -eq 0 ]]; then
  echo "No audio files (MP3/WAV) found in $LIBRARY_DIR"
  exit 0
fi

echo "Found ${#AUDIO_FILES[@]} audio files in sounds/library/."
echo ""

# Create temp directory for normalized files and metadata
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# --- Pass 1 & 2: Normalize each file ---
echo "--- Normalizing volumes (two-pass loudnorm) ---"
echo ""

# Store duration→filename mappings in a temp file for sorting
DURATION_MAP="$TEMP_DIR/_durations.txt"
> "$DURATION_MAP"

# Store Attention Score→filename mappings in a temp file for sorting
SCORE_MAP="$TEMP_DIR/_score.txt"
> "$SCORE_MAP"

for f in "${AUDIO_FILES[@]}"; do
  echo "Processing: $f"

  src="$LIBRARY_DIR/$f"

  # Get duration
  duration=$(ffprobe -i "$src" -show_entries format=duration -v quiet -of csv="p=0")
  duration_int=${duration%.*}

  # Record duration for later sorting (tab-delimited for filenames with spaces)
  printf '%s\t%s\n' "${duration_int}" "${f}" >> "$DURATION_MAP"

  # Pass 1: Measure loudness
  measure=$(ffmpeg -hide_banner -i "$src" \
    -af "loudnorm=I=${TARGET_LUFS}:TP=${TARGET_TP}:LRA=${TARGET_LRA}:print_format=json" \
    -f null /dev/null 2>&1)

  input_i=$(echo "$measure" | grep '"input_i"' | sed 's/.*: "//;s/".*//')
  input_tp=$(echo "$measure" | grep '"input_tp"' | sed 's/.*: "//;s/".*//')
  input_lra=$(echo "$measure" | grep '"input_lra"' | sed 's/.*: "//;s/".*//')
  input_thresh=$(echo "$measure" | grep '"input_thresh"' | sed 's/.*: "//;s/".*//')

  # Calculate Attention Score
  # High LRA = good. Very short duration (< 5s) = good (assume burst). Long duration (> 45s) = bad.
  score=0
  lra_val=$(printf "%.0f" "$input_lra" 2>/dev/null || echo 0)
  
  if [[ "$duration_int" -lt 5 ]]; then
    score=25
  elif [[ "$duration_int" -gt 45 ]]; then
    score=0
  else
    score=$lra_val
  fi

  printf '%s\t%s\n' "${score}" "${f}" >> "$SCORE_MAP"

  # Validate measurements before pass 2
  if [[ -z "$input_i" || -z "$input_tp" || -z "$input_lra" || -z "$input_thresh" ]]; then
    echo "  ⚠ Skipping normalization (could not measure loudness): $f" >&2
    cp "$src" "$TEMP_DIR/$f"
    continue
  fi

  # Pass 2: Apply normalization with format-appropriate output options
  ext="${f##*.}"
  if [[ "$ext" == "wav" ]]; then
    ffmpeg -hide_banner -y -i "$src" \
      -af "loudnorm=I=${TARGET_LUFS}:TP=${TARGET_TP}:LRA=${TARGET_LRA}:measured_I=${input_i}:measured_TP=${input_tp}:measured_LRA=${input_lra}:measured_thresh=${input_thresh}:linear=true" \
      -c:a pcm_s16le -ar 44100 \
      "$TEMP_DIR/$f" 2>/dev/null
  else
    ffmpeg -hide_banner -y -i "$src" \
      -af "loudnorm=I=${TARGET_LUFS}:TP=${TARGET_TP}:LRA=${TARGET_LRA}:measured_I=${input_i}:measured_TP=${input_tp}:measured_LRA=${input_lra}:measured_thresh=${input_thresh}:linear=true" \
      -ar 44100 -b:a 192k \
      "$TEMP_DIR/$f" 2>/dev/null
  fi

  echo "  ✓ Normalized (${duration_int}s, measured ${input_i} LUFS → target ${TARGET_LUFS} LUFS)"
done

# Move normalized files back into library (overwrite originals)
for f in "${AUDIO_FILES[@]}"; do
  mv "$TEMP_DIR/$f" "$LIBRARY_DIR/$f"
done

echo ""
echo "--- Distributing symlinks into sounds/ directories ---"
echo ""

# Sort files by duration (shortest first) and read into array
sorted_files=()
sorted_durations=()
while IFS=$'\t' read -r dur fname; do
  sorted_files+=("$fname")
  sorted_durations+=("$dur")
done < <(sort -n "$DURATION_MAP")

total=${#sorted_files[@]}

# Sort files by Attention Score (highest first)
sorted_score_files=()
sorted_score_values=()
while IFS=$'\t' read -r score fname; do
  sorted_score_files+=("$fname")
  sorted_score_values+=("$score")
done < <(sort -rn "$SCORE_MAP")

total_score=${#sorted_score_files[@]}

# Assign files to an event directory based on percentage range of the sorted list
assign_files_to_event() {
  local event="$1"
  local start_pct="$2"
  local end_pct="$3"
  local sort_type="${4:-duration}" # duration (default) or lra
  local event_dir="$PLUGIN_DIR/sounds/$event"

  # Clear existing files and symlinks
  find "$event_dir" -maxdepth 1 \( -type f -o -type l \) -delete 2>/dev/null || true

  local count=0

  if [[ "$sort_type" == "attention" ]]; then
    local count_total=$total_score
    local start_idx=$(( count_total * start_pct / 100 ))
    local end_idx=$(( count_total * end_pct / 100 ))
    [[ $end_idx -gt $count_total ]] && end_idx=$count_total
    [[ $start_idx -ge $end_idx ]] && start_idx=$(( end_idx - 1 ))
    [[ $start_idx -lt 0 ]] && start_idx=0

    local i=$start_idx
    while [[ $i -lt $end_idx ]]; do
      local fname="${sorted_score_files[$i]}"
      if [[ -f "$LIBRARY_DIR/$fname" ]]; then
        ln -s "../library/$fname" "$event_dir/$fname"
        count=$((count + 1))
      fi
      i=$((i + 1))
    done
    echo "  $event: $count files (Attention Score sorted, top ${start_pct}-${end_pct}%)"
  else
    local count_total=$total
    local start_idx=$(( count_total * start_pct / 100 ))
    local end_idx=$(( count_total * end_pct / 100 ))
    [[ $end_idx -gt $count_total ]] && end_idx=$count_total
    [[ $start_idx -ge $end_idx ]] && start_idx=$(( end_idx - 1 ))
    [[ $start_idx -lt 0 ]] && start_idx=0

    local i=$start_idx
    while [[ $i -lt $end_idx ]]; do
      local fname="${sorted_files[$i]}"
      if [[ -f "$LIBRARY_DIR/$fname" ]]; then
        ln -s "../library/$fname" "$event_dir/$fname"
        count=$((count + 1))
      fi
      i=$((i + 1))
    done
    echo "  $event: $count files (duration ${sorted_durations[$start_idx]}s–${sorted_durations[$((end_idx - 1))]}s)"
  fi
}

# Distribution: percentage ranges of the sorted file list
# Overlapping ranges give some files to multiple events for variety
assign_files_to_event "preToolUse"          0  100  # all files (variety of lengths)
assign_files_to_event "postToolUse"         0  100  # all files (variety of lengths)
assign_files_to_event "userPromptSubmitted" 15 50   # short-to-medium
assign_files_to_event "subagentStop"        25 60   # short-medium
assign_files_to_event "agentStop"           0  40   "attention" # top 40% attention grabbing (short bursts or dynamic)
assign_files_to_event "errorOccurred"       40 75   # medium (distinctive)
assign_files_to_event "sessionStart"        55 100  # longer, atmospheric
assign_files_to_event "sessionEnd"          55 100  # longer, atmospheric (same as sessionStart)

echo ""
echo "=== Done! ==="
echo "Normalized audio files in sounds/library/."
echo "Symlinks distributed into sounds/<event>/ directories."
