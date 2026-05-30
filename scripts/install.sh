#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${REPO_ROOT}/themes/modified-layan"
THEME_NAME="Layan"
TARGET_ROOT="${HOME}/.local/share/plasma/desktoptheme"
BACKUP_ROOT="${HOME}/.local/share/plasma/desktoptheme/.liquid-glass-backups"
MODE="dry-run"
ASSUME_YES=0

bold=""
dim=""
reset=""
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
  bold="$(tput bold || true)"
  dim="$(tput dim || true)"
  reset="$(tput sgr0 || true)"
fi

usage() {
  cat <<EOF
KDE Plasma Liquid Glass installer

Usage:
  scripts/install.sh [options]

Options:
  -n, --dry-run            Preview actions without copying files (default)
  -i, --install            Copy the modified Layan files
  -y, --yes                Skip the confirmation prompt
      --theme-name NAME    Plasma theme folder to write into (default: Layan)
      --target-root DIR    Plasma desktoptheme root
      --backup-root DIR    Backup directory root
  -h, --help               Show this help

Examples:
  scripts/install.sh --dry-run
  scripts/install.sh --install
  scripts/install.sh --install --theme-name Layan-Liquid-Glass
EOF
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      MODE="dry-run"
      shift
      ;;
    -i|--install)
      MODE="install"
      shift
      ;;
    -y|--yes)
      ASSUME_YES=1
      shift
      ;;
    --theme-name)
      [[ $# -ge 2 ]] || fail "--theme-name requires a value"
      THEME_NAME="$2"
      shift 2
      ;;
    --target-root)
      [[ $# -ge 2 ]] || fail "--target-root requires a value"
      TARGET_ROOT="$2"
      shift 2
      ;;
    --backup-root)
      [[ $# -ge 2 ]] || fail "--backup-root requires a value"
      BACKUP_ROOT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

[[ -d "${SOURCE_DIR}" ]] || fail "missing source directory: ${SOURCE_DIR}"
[[ "${THEME_NAME}" != */* ]] || fail "--theme-name must be a folder name, not a path"
[[ -n "${THEME_NAME}" ]] || fail "--theme-name cannot be empty"

TARGET_DIR="${TARGET_ROOT}/${THEME_NAME}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${THEME_NAME}-${STAMP}"

SOURCE_FILES=()
while IFS= read -r -d '' file; do
  SOURCE_FILES+=("$file")
done < <(find "${SOURCE_DIR}" -type f -print0)
[[ ${#SOURCE_FILES[@]} -gt 0 ]] || fail "no files found in ${SOURCE_DIR}"

relative_path() {
  local file="$1"
  printf '%s\n' "${file#"${SOURCE_DIR}/"}"
}

destination_for() {
  local file="$1"
  printf '%s/%s\n' "${TARGET_DIR}" "$(relative_path "$file")"
}

count_existing=0
for file in "${SOURCE_FILES[@]}"; do
  dest="$(destination_for "$file")"
  if [[ -e "${dest}" ]]; then
    count_existing=$((count_existing + 1))
  fi
done

print_header() {
  printf '\n%sKDE Plasma Liquid Glass installer%s\n' "${bold}" "${reset}"
  printf '%s%s%s\n\n' "${dim}" "Modified Layan overlay with backup-aware copying" "${reset}"
}

print_summary() {
  printf '%-16s %s\n' "Mode:" "${MODE}"
  printf '%-16s %s\n' "Source:" "${SOURCE_DIR}"
  printf '%-16s %s\n' "Destination:" "${TARGET_DIR}"
  printf '%-16s %s\n' "Files:" "${#SOURCE_FILES[@]}"
  printf '%-16s %s\n' "Will backup:" "${count_existing}"
  if [[ "${MODE}" == "install" ]]; then
    printf '%-16s %s\n' "Backup dir:" "${BACKUP_DIR}"
  fi
  printf '\n'
}

print_preview() {
  local shown=0
  local rel dest action

  printf '%sPlanned file actions%s\n' "${bold}" "${reset}"
  printf '%-10s %s\n' "Action" "Path"
  printf '%-10s %s\n' "------" "----"

  for file in "${SOURCE_FILES[@]}"; do
    rel="$(relative_path "$file")"
    dest="$(destination_for "$file")"
    action="copy"
    if [[ -e "${dest}" ]]; then
      action="backup+copy"
    fi

    if [[ ${shown} -lt 14 ]]; then
      printf '%-10s %s\n' "${action}" "${rel}"
    fi
    shown=$((shown + 1))
  done

  if [[ ${shown} -gt 14 ]]; then
    printf '%-10s %s\n' "..." "$((shown - 14)) more files"
  fi
  printf '\n'
}

confirm_install() {
  if [[ ${ASSUME_YES} -eq 1 ]]; then
    return
  fi
  if [[ ! -t 0 ]]; then
    fail "refusing to install without an interactive terminal; pass --yes to confirm"
  fi

  local answer
  printf 'Install these files now? [y/N] '
  read -r answer
  case "${answer}" in
    y|Y|yes|YES)
      ;;
    *)
      printf 'Canceled.\n'
      exit 0
      ;;
  esac
}

copy_file() {
  local source="$1"
  local dest="$2"
  local rel
  rel="$(relative_path "$source")"

  mkdir -p -- "$(dirname -- "${dest}")"
  if [[ -e "${dest}" ]]; then
    mkdir -p -- "$(dirname -- "${BACKUP_DIR}/${rel}")"
    cp -p -- "${dest}" "${BACKUP_DIR}/${rel}"
  fi
  cp -p -- "${source}" "${dest}"
}

run_install() {
  local file dest copied=0

  mkdir -p -- "${TARGET_DIR}"
  for file in "${SOURCE_FILES[@]}"; do
    dest="$(destination_for "$file")"
    copy_file "$file" "$dest"
    copied=$((copied + 1))
  done

  printf '%sInstalled %s files.%s\n' "${bold}" "${copied}" "${reset}"
  if [[ ${count_existing} -gt 0 ]]; then
    printf 'Backed up replaced files to:\n  %s\n' "${BACKUP_DIR}"
  else
    printf 'No existing files needed backup.\n'
  fi
  printf '\nOpen KDE System Settings and reselect the Plasma Style to reload it.\n'
}

print_header
print_summary
print_preview

if [[ "${MODE}" == "dry-run" ]]; then
  printf 'Dry run only. Re-run with --install to copy files.\n'
  exit 0
fi

confirm_install
run_install
