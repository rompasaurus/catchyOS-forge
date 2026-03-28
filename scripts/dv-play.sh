#!/usr/bin/env bash
# dv-play.sh — Play or convert Dolby Vision video files
# Usage:
#   dv-play.sh <file>              Play with mpv tone-mapping
#   dv-play.sh --convert <file>    Strip DV layer (keep HDR10, fast)
#   dv-play.sh --tosdr <file>      Tone-map to SDR (slow, re-encode)
#   dv-play.sh --batch <dir>       Convert all MKV/MP4 in directory

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { printf "${GREEN}[+]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
err()  { printf "${RED}[x]${NC} %s\n" "$*" >&2; exit 1; }

check_deps() {
    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        err "Missing dependencies: ${missing[*]}\nInstall with: sudo pacman -S ${missing[*]}"
    fi
}

setup_mpv_config() {
    local conf="$HOME/.config/mpv/mpv.conf"
    mkdir -p "$(dirname "$conf")"
    if [[ -f "$conf" ]] && grep -q "vo=gpu-next" "$conf"; then
        return
    fi
    warn "Adding HDR tone-mapping config to $conf"
    cat >> "$conf" << 'EOF'

# HDR/Dolby Vision tone-mapping
vo=gpu-next
tone-mapping=hable
tone-mapping-mode=hybrid
target-colorspace-hint=yes
EOF
    log "mpv config updated"
}

play() {
    local file="$1"
    check_deps mpv
    setup_mpv_config
    log "Playing with HDR tone-mapping: $(basename "$file")"
    mpv --vo=gpu-next --tone-mapping=hable --tone-mapping-mode=hybrid "$file"
}

strip_dv() {
    local file="$1"
    local out="${file%.*}_hdr10.${file##*.}"
    check_deps ffmpeg
    if [[ -f "$out" ]]; then
        err "Output already exists: $out"
    fi
    log "Stripping Dolby Vision metadata (keeping HDR10 base layer)..."
    ffmpeg -i "$file" \
        -c:v copy -c:a copy -c:s copy \
        -bsf:v filter_units=remove_types=62 \
        "$out"
    log "Done: $out"
}

tonemap_sdr() {
    local file="$1"
    local out="${file%.*}_sdr.mkv"
    check_deps ffmpeg
    if [[ -f "$out" ]]; then
        err "Output already exists: $out"
    fi
    log "Tone-mapping to SDR (this will take a while)..."
    ffmpeg -i "$file" \
        -vf "zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p" \
        -c:v libx265 -crf 18 -preset slow \
        -c:a copy -c:s copy \
        "$out"
    log "Done: $out"
}

batch_convert() {
    local dir="$1"
    local mode="${2:-strip}"
    local count=0
    for file in "$dir"/*.{mkv,mp4,MKV,MP4}; do
        [[ -f "$file" ]] || continue
        log "Processing: $(basename "$file")"
        if [[ "$mode" == "sdr" ]]; then
            tonemap_sdr "$file"
        else
            strip_dv "$file"
        fi
        ((count++))
    done
    log "Batch complete: $count files processed"
}

usage() {
    cat << 'EOF'
Usage: dv-play.sh [option] <file|dir>

Options:
  (none)              Play file with mpv + HDR tone-mapping
  --convert <file>    Strip DV layer, keep HDR10 (fast, lossless)
  --tosdr <file>      Tone-map to SDR (slow, re-encode)
  --batch <dir>       Strip DV from all MKV/MP4 in directory
  --batch-sdr <dir>   Tone-map all MKV/MP4 in directory to SDR
  -h, --help          Show this help
EOF
}

[[ $# -lt 1 ]] && { usage; exit 1; }

case "${1}" in
    --convert)
        [[ -z "${2:-}" ]] && err "No file specified"
        [[ -f "$2" ]] || err "File not found: $2"
        strip_dv "$2"
        ;;
    --tosdr)
        [[ -z "${2:-}" ]] && err "No file specified"
        [[ -f "$2" ]] || err "File not found: $2"
        tonemap_sdr "$2"
        ;;
    --batch)
        [[ -z "${2:-}" ]] && err "No directory specified"
        [[ -d "$2" ]] || err "Directory not found: $2"
        batch_convert "$2"
        ;;
    --batch-sdr)
        [[ -z "${2:-}" ]] && err "No directory specified"
        [[ -d "$2" ]] || err "Directory not found: $2"
        batch_convert "$2" sdr
        ;;
    -h|--help)
        usage
        ;;
    -*)
        err "Unknown option: $1"
        ;;
    *)
        [[ -f "$1" ]] || err "File not found: $1"
        play "$1"
        ;;
esac
