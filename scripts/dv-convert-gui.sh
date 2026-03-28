#!/usr/bin/env bash
# GUI wrapper for DV conversion — accepts files as arguments (drag-and-drop)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

notify() { notify-send -i video-x-generic "DV Convert" "$1" 2>/dev/null || true; }

# If no file passed, open a file picker
if [[ $# -eq 0 ]]; then
    FILE=$(zenity --file-selection \
        --title="Select Dolby Vision video" \
        --file-filter="Video files|*.mkv *.mp4 *.MKV *.MP4 *.ts *.TS" \
        2>/dev/null) || exit 0
else
    FILE="$1"
fi

[[ -f "$FILE" ]] || { zenity --error --text="File not found:\n$FILE"; exit 1; }

BASENAME="$(basename "$FILE")"

# Ask what to do
ACTION=$(zenity --list \
    --title="DV Convert — $BASENAME" \
    --text="What do you want to do with this file?" \
    --column="Action" --column="Description" \
    --width=500 --height=300 \
    "play"      "Play with mpv (auto tone-map, no conversion)" \
    "strip"     "Strip DV layer → HDR10 (fast, lossless)" \
    "sdr"       "Tone-map → SDR (slow, re-encode)" \
    2>/dev/null) || exit 0

case "$ACTION" in
    play)
        "$SCRIPT_DIR/dv-play.sh" "$FILE"
        ;;
    strip)
        notify "Converting: $BASENAME (stripping DV)..."
        "$SCRIPT_DIR/dv-play.sh" --convert "$FILE" 2>&1 | \
            zenity --progress --pulsate --auto-close \
            --title="Converting..." --text="Stripping DV metadata from $BASENAME" \
            --no-cancel 2>/dev/null
        notify "Done: ${BASENAME%.*}_hdr10.${BASENAME##*.}"
        zenity --info --text="Done!\n\nSaved as:\n${FILE%.*}_hdr10.${FILE##*.}" 2>/dev/null
        ;;
    sdr)
        notify "Converting: $BASENAME (tone-mapping to SDR)..."
        "$SCRIPT_DIR/dv-play.sh" --tosdr "$FILE" 2>&1 | \
            zenity --progress --pulsate --auto-close \
            --title="Converting..." --text="Tone-mapping $BASENAME to SDR\nThis may take a while..." \
            --no-cancel 2>/dev/null
        notify "Done: ${BASENAME%.*}_sdr.mkv"
        zenity --info --text="Done!\n\nSaved as:\n${FILE%.*}_sdr.mkv" 2>/dev/null
        ;;
esac
