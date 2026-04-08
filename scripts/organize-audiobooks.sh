#!/usr/bin/env bash
#
# organize-audiobooks.sh
# Scans a source directory for audiobook files, reads metadata via ffprobe,
# and COPIES them into a destination directory with the structure:
#   Author - Title/
#       <audiobook files>
#
# Original files are never modified or removed.
#
# Usage:
#   ./organize-audiobooks.sh                        # Interactive mode (CLI + GUI picker)
#   ./organize-audiobooks.sh --dry-run              # Preview only, interactive
#   ./organize-audiobooks.sh --source DIR --dest DIR # Non-interactive
#   ./organize-audiobooks.sh --gui                  # Force GUI folder picker
#   ./organize-audiobooks.sh --help

set -euo pipefail

# --- Config ---
AUDIO_EXTENSIONS=("mp3" "m4a" "m4b" "flac" "ogg" "opus" "wma" "aac")
COPY_EXTENSIONS=("jpg" "jpeg" "png" "cue" "nfo" "txt" "srt" "pdf" "opf" "xml")
DEFAULT_SOURCE="/mnt/dookintel/Steam/MEDIA/readarr"
DEFAULT_DEST="/mnt/dookintel/Steam/MEDIA/audiobooks"

DRY_RUN=false
USE_GUI=false
SOURCE_DIR=""
DEST_DIR=""

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Parse args ---
show_help() {
    cat <<'HELP'
Usage: organize-audiobooks.sh [OPTIONS]

Options:
  --dry-run          Preview what would be copied without touching any files
  --source DIR       Set source directory (skips interactive prompt)
  --dest DIR         Set destination directory (skips interactive prompt)
  --gui              Force GUI folder picker (kdialog/zenity)
  --help             Show this help

Interactive mode (default):
  If --source or --dest are not provided, you'll be prompted to use the
  default or pick a folder via the system file explorer.

Examples:
  ./organize-audiobooks.sh --dry-run
  ./organize-audiobooks.sh --source /path/to/books --dest /path/to/audiobooks
  ./organize-audiobooks.sh --gui --dry-run
HELP
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=true; shift ;;
        --gui)      USE_GUI=true; shift ;;
        --source)   SOURCE_DIR="$2"; shift 2 ;;
        --dest)     DEST_DIR="$2"; shift 2 ;;
        --help|-h)  show_help ;;
        *)          echo "Unknown option: $1"; show_help ;;
    esac
done

if ! command -v ffprobe &>/dev/null; then
    echo -e "${RED}ERROR: ffprobe is required (install ffmpeg)${NC}" >&2
    exit 1
fi

# --- GUI folder picker ---
pick_directory_gui() {
    local title="$1"
    local start_dir="$2"
    local picked=""

    if command -v kdialog &>/dev/null; then
        picked="$(kdialog --title "$title" --getexistingdirectory "$start_dir" 2>/dev/null)" || true
    elif command -v zenity &>/dev/null; then
        picked="$(zenity --file-selection --directory --title="$title" --filename="$start_dir/" 2>/dev/null)" || true
    fi
    echo "$picked"
}

# --- Interactive directory selection ---
# Writes the chosen path into the variable named by $1
select_directory() {
    local varname="$1"
    local label="$2"
    local default="$3"

    echo >&2
    echo -e "  ${BOLD}${label^^} directory${NC}" >&2
    echo -e "  Default: ${DIM}${default}${NC}" >&2
    echo >&2
    echo -e "  ${GREEN}1)${NC}  Use default" >&2
    echo -e "  ${GREEN}2)${NC}  Choose folder (opens file explorer)" >&2
    echo >&2

    read -r -p "$(echo -e "${BOLD}  Choose [1-2]: ${NC}")" method </dev/tty

    case "$method" in
        1|"")
            eval "$varname=\"$default\""
            ;;
        2)
            local gui_pick
            local start="${default}"
            [[ -d "$start" ]] || start="$HOME"
            gui_pick="$(pick_directory_gui "Select ${label} directory" "$start")"
            if [[ -n "$gui_pick" ]]; then
                eval "$varname=\"\$gui_pick\""
            else
                echo -e "  ${YELLOW}No folder selected, using default${NC}" >&2
                eval "$varname=\"$default\""
            fi
            ;;
        *)
            echo -e "  ${YELLOW}Invalid choice, using default${NC}" >&2
            eval "$varname=\"$default\""
            ;;
    esac
}

# --- Directory selection ---
if [[ "$USE_GUI" == true ]]; then
    # --gui flag: skip menus, straight to file explorer popups
    if [[ -z "$SOURCE_DIR" ]]; then
        SOURCE_DIR="$(pick_directory_gui "Select SOURCE directory (audiobooks to scan)" "$DEFAULT_SOURCE")"
        [[ -z "$SOURCE_DIR" ]] && SOURCE_DIR="$DEFAULT_SOURCE"
    fi
    if [[ -z "$DEST_DIR" ]]; then
        DEST_DIR="$(pick_directory_gui "Select DESTINATION directory (organized output)" "$DEFAULT_DEST")"
        [[ -z "$DEST_DIR" ]] && DEST_DIR="$DEFAULT_DEST"
    fi
elif [[ -z "$SOURCE_DIR" || -z "$DEST_DIR" ]]; then
    # Interactive mode — show banner then prompt for each missing dir
    echo -e "${BOLD}${CYAN}"
    echo "  Audiobook Organizer"
    echo -e "  ${DIM}Copies audiobooks into Author - Title/ folders"
    echo -e "  Originals are not modified${NC}"
    echo

    if [[ -z "$SOURCE_DIR" ]]; then
        select_directory SOURCE_DIR "source" "$DEFAULT_SOURCE"
    fi
    if [[ -z "$DEST_DIR" ]]; then
        select_directory DEST_DIR "destination" "$DEFAULT_DEST"
    fi
fi

# Validate source exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo -e "${RED}ERROR: Source directory does not exist: ${SOURCE_DIR}${NC}" >&2
    exit 1
fi

# --- Helpers ---
sanitize_name() {
    local name="$1"
    name="${name//\//-}"
    name="${name//\\/-}"
    name="${name//:/  -}"
    name="${name//\?/}"
    name="${name//\*/}"
    name="${name//\"/}"
    name="${name//</}"
    name="${name//>/}"
    name="${name//|/-}"
    name="$(echo "$name" | sed 's/^[[:space:].]*//' | sed 's/[[:space:].]*$//')"
    echo "$name"
}

get_metadata() {
    local file="$1"
    local field="$2"
    ffprobe -v quiet -print_format json -show_format "$file" 2>/dev/null \
        | python3 -c "
import sys, json
try:
    tags = json.load(sys.stdin).get('format', {}).get('tags', {})
    tags_lower = {k.lower(): v for k, v in tags.items()}
    print(tags_lower.get('$field', ''))
except:
    print('')
" 2>/dev/null
}

guess_from_filename() {
    local name="$1"
    name="${name%.*}"
    name="$(echo "$name" | sed -E 's/^\[M4B\]\s*//i')"
    name="$(echo "$name" | sed -E 's/\s*\(M4B\)//i')"
    name="$(echo "$name" | sed -E 's/\s*\(Unabridged\)//i')"
    name="$(echo "$name" | sed -E 's/\s*\[.*\]//g')"
    name="$(echo "$name" | sed -E 's/\s*\(AB\)//i')"
    name="$(echo "$name" | sed -E 's/\s*- *[0-9]+k(bts?)?//i')"
    name="$(echo "$name" | sed -E 's/\s*[0-9]+k(bts?)?//i')"
    name="$(echo "$name" | sed -E 's/\s*\([0-9]+ ?k(bts?)?\)//i')"

    local author=""
    local title=""

    if [[ "$name" =~ ^(.+)\ -\ (.+)$ ]]; then
        author="${BASH_REMATCH[1]}"
        title="${BASH_REMATCH[2]}"
    elif [[ "$name" =~ ^(.+)꞉\ (.+)$ ]]; then
        author="${BASH_REMATCH[1]}"
        title="${BASH_REMATCH[2]}"
    else
        title="$name"
    fi

    title="$(echo "$title" | sed -E 's/^[0-9]+\s+//')"
    author="$(echo "$author" | sed -E 's/^[0-9]+\.?\s*//')"

    echo "$author"
    echo "$title"
}

# --- Logging ---
log_file="/tmp/organize-audiobooks-$(date +%Y%m%d-%H%M%S).log"
log() {
    echo "$@" | tee -a "$log_file"
}

skipped_log="/tmp/organize-audiobooks-skipped-$(date +%Y%m%d-%H%M%S).log"

# --- Confirmation ---
echo
echo -e "${BOLD}=========================================${NC}"
echo -e "  ${CYAN}Audiobook Organizer${NC}"
echo -e "${BOLD}=========================================${NC}"
echo -e "  Source:      ${GREEN}$SOURCE_DIR${NC}"
echo -e "  Destination: ${GREEN}$DEST_DIR${NC}"
echo -e "  Dry run:     ${YELLOW}$DRY_RUN${NC}"
echo -e "  Log:         ${DIM}$log_file${NC}"
echo -e "${BOLD}=========================================${NC}"
echo
echo -e "  ${DIM}Files are COPIED — originals are never modified or removed.${NC}"
echo

if [[ "$DRY_RUN" == false ]]; then
    read -r -p "$(echo -e "${BOLD}Proceed? [Y/n]: ${NC}")" confirm
    case "$confirm" in
        n|N|no|No) echo "Aborted."; exit 0 ;;
    esac
    mkdir -p "$DEST_DIR"
fi

total=0
organized=0
skipped=0
failed=0

# --- Main loop ---
while IFS= read -r -d '' entry; do
    entry_name="$(basename "$entry")"
    audio_files=()

    if [[ -f "$entry" ]]; then
        ext="${entry_name##*.}"
        ext_lower="${ext,,}"
        is_audio=false
        for aext in "${AUDIO_EXTENSIONS[@]}"; do
            if [[ "$ext_lower" == "$aext" ]]; then
                is_audio=true
                break
            fi
        done
        if ! $is_audio; then
            continue
        fi
        audio_files=("$entry")
    elif [[ -d "$entry" ]]; then
        while IFS= read -r -d '' af; do
            audio_files+=("$af")
        done < <(/usr/bin/find "$entry" -type f \( -name "*.mp3" -o -name "*.m4a" -o -name "*.m4b" -o -name "*.flac" -o -name "*.ogg" -o -name "*.opus" -o -name "*.wma" -o -name "*.aac" \) -print0 2>/dev/null)

        if [[ ${#audio_files[@]} -eq 0 ]]; then
            continue
        fi
    else
        continue
    fi

    total=$((total + 1))

    # Read metadata from first audio file
    probe_file="${audio_files[0]}"
    artist="$(get_metadata "$probe_file" "artist")"
    album_artist="$(get_metadata "$probe_file" "album_artist")"
    title="$(get_metadata "$probe_file" "title")"
    album="$(get_metadata "$probe_file" "album")"

    author="${album_artist:-$artist}"
    book_title="${album:-$title}"

    book_title="$(echo "$book_title" | sed -E 's/\s*\(Unabridged\)//i')"
    book_title="$(echo "$book_title" | sed -E 's/\s*\(Abridged\)//i')"

    if [[ -z "$author" || -z "$book_title" ]]; then
        read -r guess_author <<< "$(guess_from_filename "$entry_name" | head -1)"
        read -r guess_title <<< "$(guess_from_filename "$entry_name" | tail -1)"
        author="${author:-$guess_author}"
        book_title="${book_title:-$guess_title}"
    fi

    if [[ -z "$book_title" ]]; then
        book_title="$entry_name"
    fi

    author="$(sanitize_name "$author")"
    book_title="$(sanitize_name "$book_title")"

    if [[ -n "$author" ]]; then
        dest_folder="$author - $book_title"
    else
        dest_folder="Unknown Author - $book_title"
    fi

    # Truncate folder name if it exceeds filesystem limit (255 bytes)
    if [[ ${#dest_folder} -gt 250 ]]; then
        # Keep first author only (before first comma) and truncate title if still too long
        short_author="${author%%,*}"
        short_author="$(echo "$short_author" | sed 's/[[:space:]]*$//')"
        dest_folder="$short_author - $book_title"
        if [[ ${#dest_folder} -gt 250 ]]; then
            dest_folder="${dest_folder:0:247}..."
        fi
    fi

    dest_path="$DEST_DIR/$dest_folder"

    if [[ -d "$dest_path" ]]; then
        log -e "  ${YELLOW}SKIP${NC} (exists): $dest_folder"
        echo "$entry -> $dest_folder (already exists)" >> "$skipped_log"
        skipped=$((skipped + 1))
        continue
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log -e "  ${GREEN}WOULD COPY${NC}: $entry_name"
        log -e "         ${DIM}->  $dest_folder${NC}"
        organized=$((organized + 1))
        continue
    fi

    # Copy files
    log -e "  ${GREEN}COPYING${NC}: $entry_name"
    log -e "       ${DIM}->  $dest_folder${NC}"

    mkdir -p "$dest_path"

    if [[ -f "$entry" ]]; then
        if cp "$entry" "$dest_path/"; then
            organized=$((organized + 1))
        else
            failed=$((failed + 1))
        fi
    elif [[ -d "$entry" ]]; then
        for af in "${audio_files[@]}"; do
            cp "$af" "$dest_path/" || true
        done
        for cext in "${COPY_EXTENSIONS[@]}"; do
            while IFS= read -r -d '' cf; do
                cp "$cf" "$dest_path/" 2>/dev/null || true
            done < <(/usr/bin/find "$entry" -maxdepth 2 -type f -name "*.$cext" -print0 2>/dev/null)
        done
        organized=$((organized + 1))
    fi

done < <(/usr/bin/find "$SOURCE_DIR" -maxdepth 1 -mindepth 1 -print0 2>/dev/null | sort -z)

echo
echo -e "${BOLD}=========================================${NC}"
echo -e "  ${CYAN}Results${NC}"
echo -e "${BOLD}=========================================${NC}"
echo -e "  Total audiobooks found:    ${BOLD}$total${NC}"
echo -e "  Organized (copied):        ${GREEN}$organized${NC}"
echo -e "  Skipped (already exist):   ${YELLOW}$skipped${NC}"
echo -e "  Failed:                    ${RED}$failed${NC}"
echo -e "  Log:         ${DIM}$log_file${NC}"
echo -e "  Skipped log: ${DIM}$skipped_log${NC}"
echo
echo -e "  ${DIM}Originals in ${SOURCE_DIR} were not modified.${NC}"
echo -e "${GREEN}Done!${NC}"
