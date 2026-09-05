#!/usr/bin/env bash
# Split PTB Diagnostic ECG (PhysioNet) zip into GitHub-safe chunks (<100 MiB).
# Also restore those chunks back into a usable unzipped dataset.
#
# Usage (from this directory, Git Bash / WSL / Linux / macOS):
#   bash setup.sh prepare   # verify + split into parts/
#   bash setup.sh restore   # cat parts/ -> unzip for local use
#   bash setup.sh verify    # reassemble parts and unzip -t only
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# Stay under GitHub's 100 MiB hard limit (leave headroom for encoding quirks).
CHUNK_SIZE="${CHUNK_SIZE:-95M}"
PARTS_DIR="${PARTS_DIR:-parts}"
PART_PREFIX="ptbdb-1.0.0.zip.part"
ZIP_NAME="ptbdb-1.0.0.zip"
EXTRACT_DIR="${EXTRACT_DIR:-extracted}"

log() { printf '[ptb] %s\n' "$*"; }
die() { printf '[ptb] ERROR: %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

human_size() {
  local bytes="$1"
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --suffix=B "$bytes"
  else
    printf '%s bytes' "$bytes"
  fi
}

list_source_volumes() {
  local vols=()
  local f
  for f in "$ROOT"/ptbdb-1.0.0.zip.[0-9][0-9][0-9]; do
    [[ -f "$f" ]] || continue
    vols+=("$f")
  done
  if ((${#vols[@]} > 0)); then
    printf '%s\n' "${vols[@]}" | LC_ALL=C sort
    return 0
  fi
  if [[ -f "$ROOT/$ZIP_NAME" ]]; then
    printf '%s\n' "$ROOT/$ZIP_NAME"
    return 0
  fi
  return 1
}

list_github_parts() {
  local parts=()
  local f
  for f in "$ROOT/$PARTS_DIR/${PART_PREFIX}"*; do
    [[ -f "$f" ]] || continue
    parts+=("$f")
  done
  ((${#parts[@]} > 0)) || return 1
  printf '%s\n' "${parts[@]}" | LC_ALL=C sort
}

join_sources_to_zip() {
  local out="$1"
  local -a vols=()
  mapfile -t vols < <(list_source_volumes) || die "no source archive found (expected $ZIP_NAME or ptbdb-1.0.0.zip.001...)"

  if ((${#vols[@]} == 1)) && [[ "${vols[0]}" == "$out" || "${vols[0]}" == "$ROOT/$ZIP_NAME" ]]; then
    if [[ "${vols[0]}" != "$out" ]]; then
      log "Using existing $ZIP_NAME"
      cp -f "${vols[0]}" "$out"
    fi
    return 0
  fi

  log "Joining ${#vols[@]} volume(s) -> $(basename "$out")"
  local v
  for v in "${vols[@]}"; do
    log "  + $(basename "$v") ($(human_size "$(wc -c < "$v")"))"
  done
  cat "${vols[@]}" > "$out"
}

join_parts_to_zip() {
  local out="$1"
  local -a parts=()
  mapfile -t parts < <(list_github_parts) || die "no parts found under $PARTS_DIR/${PART_PREFIX}*"

  log "Joining ${#parts[@]} GitHub part(s) -> $(basename "$out")"
  local p
  for p in "${parts[@]}"; do
    local sz
    sz="$(wc -c < "$p")"
    if (( sz > 100 * 1024 * 1024 )); then
      die "$(basename "$p") is $(human_size "$sz") (>100 MiB); refuse to treat as GitHub-safe"
    fi
    log "  + $(basename "$p") ($(human_size "$sz"))"
  done
  cat "${parts[@]}" > "$out"
}

verify_zip() {
  local zip="$1"
  need_cmd unzip
  log "Verifying zip integrity: $(basename "$zip")"
  unzip -t "$zip" >/dev/null
  log "Zip OK"
}

split_zip() {
  local zip="$1"
  need_cmd split

  mkdir -p "$ROOT/$PARTS_DIR"
  rm -f "$ROOT/$PARTS_DIR/${PART_PREFIX}"*

  log "Splitting $(basename "$zip") into $CHUNK_SIZE chunks -> $PARTS_DIR/"
  split -b "$CHUNK_SIZE" -d -a 3 "$zip" "$ROOT/$PARTS_DIR/${PART_PREFIX}"

  local -a parts=()
  mapfile -t parts < <(list_github_parts)
  local i=0 p sz max=0
  for p in "${parts[@]}"; do
    sz="$(wc -c < "$p")"
    if (( sz > max )); then max=$sz; fi
    if (( sz > 100 * 1024 * 1024 )); then
      die "$(basename "$p") exceeds 100 MiB; lower CHUNK_SIZE (current=$CHUNK_SIZE)"
    fi
    i=$((i + 1))
  done

  {
    echo "# PTB Diagnostic ECG GitHub-safe zip shards"
    echo "# Reassemble: cat ${PART_PREFIX}* > $ZIP_NAME && unzip $ZIP_NAME"
    echo "# chunk_size=$CHUNK_SIZE  count=$i  max_part_bytes=$max"
    echo "# created=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local name
    for p in "${parts[@]}"; do
      name="$(basename "$p")"
      sz="$(wc -c < "$p")"
      if command -v sha256sum >/dev/null 2>&1; then
        printf '%s  %s  %s\n' "$name" "$sz" "$(sha256sum "$p" | awk '{print $1}')"
      else
        printf '%s  %s\n' "$name" "$sz"
      fi
    done
  } > "$ROOT/$PARTS_DIR/MANIFEST.txt"

  log "Wrote ${#parts[@]} parts (max $(human_size "$max")) + $PARTS_DIR/MANIFEST.txt"
}

cleanup_sources_after_prepare() {
  local -a vols=()
  mapfile -t vols < <(list_source_volumes || true)
  local v
  for v in "${vols[@]}"; do
    [[ -f "$v" ]] || continue
    log "Removing source $(basename "$v") (replaced by $PARTS_DIR/)"
    rm -f "$v"
  done
  if [[ -f "$ROOT/$ZIP_NAME" ]]; then
    log "Removing $ZIP_NAME (replaced by $PARTS_DIR/)"
    rm -f "$ROOT/$ZIP_NAME"
  fi
}

cmd_prepare() {
  need_cmd cat
  need_cmd split
  need_cmd unzip

  local tmp
  tmp="$(mktemp "$ROOT/ptbdb.zip.XXXXXX")"
  # shellcheck disable=SC2064
  trap 'rm -f "$tmp"' EXIT

  join_sources_to_zip "$tmp"
  verify_zip "$tmp"
  split_zip "$tmp"
  rm -f "$tmp"
  trap - EXIT

  cleanup_sources_after_prepare

  log "Done. GitHub-safe shards are in $PARTS_DIR/"
  log "Local extract later: bash setup.sh restore"
  log "Note: datasets/.gitignore ignores payloads by default; allow $PARTS_DIR/ before commit."
}

cmd_restore() {
  need_cmd cat
  need_cmd unzip

  local tmp
  tmp="$(mktemp "$ROOT/ptbdb.zip.XXXXXX")"
  # shellcheck disable=SC2064
  trap 'rm -f "$tmp"' EXIT

  join_parts_to_zip "$tmp"
  verify_zip "$tmp"

  mkdir -p "$ROOT/$EXTRACT_DIR"
  log "Extracting -> $EXTRACT_DIR/"
  unzip -o "$tmp" -d "$ROOT/$EXTRACT_DIR"
  rm -f "$tmp"
  trap - EXIT
  log "Done. Data is under $EXTRACT_DIR/"
}

cmd_verify() {
  need_cmd cat
  need_cmd unzip
  local tmp
  tmp="$(mktemp "$ROOT/ptbdb.zip.XXXXXX")"
  # shellcheck disable=SC2064
  trap 'rm -f "$tmp"' EXIT
  join_parts_to_zip "$tmp"
  verify_zip "$tmp"
  rm -f "$tmp"
  trap - EXIT
  log "All parts reassemble into a valid zip."
}

usage() {
  cat <<EOF
Usage: bash setup.sh <prepare|restore|verify>

  prepare  Join $ZIP_NAME / ptbdb-1.0.0.zip.001+ , verify, split into $PARTS_DIR/ ($CHUNK_SIZE each)
  restore  Concatenate $PARTS_DIR/${PART_PREFIX}* and unzip into $EXTRACT_DIR/
  verify   Concatenate parts and run unzip -t only

Env overrides:
  CHUNK_SIZE=$CHUNK_SIZE
  PARTS_DIR=$PARTS_DIR
  EXTRACT_DIR=$EXTRACT_DIR
EOF
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    prepare) cmd_prepare ;;
    restore) cmd_restore ;;
    verify)  cmd_verify ;;
    -h|--help|help|"") usage; [[ -n "$cmd" ]] || exit 1 ;;
    *) die "unknown command: $cmd (try --help)" ;;
  esac
}

main "$@"
