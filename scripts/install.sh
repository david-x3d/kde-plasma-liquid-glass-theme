#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

MODE="dry-run"
MODE_EXPLICIT=0
ASSUME_YES=0
INIT_SUBMODULES=0
SUBMODULE_DEPTH=1
INSTALL_PACKAGES=0
INSTALL_BUILDS=1
APPLY_SETTINGS=1
APPLY_LAYOUT=0
RESTART_PLASMA=1
SYSTEM_INSTALL=1
INSTALL_DISCORD_THEME=1
INSTALL_WINDOW_RULES=1
BACKUP_CONFIGS=1
CONFIGS_BACKED_UP=0
STAMP="$(date +%Y%m%d-%H%M%S)"

THEME_NAME="Layan"
PLASMA_STYLE="Layan"
LOOK_AND_FEEL="com.github.vinceliuice.Layan"
ICON_THEME="WhiteSur-dark"
APP_STYLE="Darkly"
COLOR_SCHEME="Darkly"
WINDOW_DECORATION="BreezeEnhanced"
INSTALL_PREFIX="/usr"
TARGET_ROOT="${HOME}/.local/share/plasma/desktoptheme"
BACKUP_ROOT="${HOME}/.local/share/plasma/desktoptheme/.liquid-glass-backups"
WALLPAPER_IMAGE="${REPO_ROOT}/screenshots/Desktop.png"
DISCORD_THEME_SOURCE="${REPO_ROOT}/themes/discord-theme/modified-midnight.theme.css"
DISCORD_THEME_NAME="liquid-glass-midnight.theme.css"
CONFIG_BACKUP_DIR=""

SOURCE_DIR="${REPO_ROOT}/themes/modified-layan"
TARGET_DIR=""
BACKUP_DIR=""

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

Default behavior is a dry run. Use --install to apply the full rice.

Options:
  -n, --dry-run              Preview actions without changing the system
  -i, --install              Install available components and apply settings
      --full-setup           Install, initialize submodules, install packages, build and apply settings
  -y, --yes                  Skip the confirmation prompt
      --init-submodules      Run git submodule update --init --recursive
      --full-submodule-history
                            Clone complete submodule histories instead of shallow checkouts
      --install-packages     Install build/runtime packages with the system package manager
      --skip-builds          Skip source builds/upstream installers
      --skip-settings        Copy files but do not write KDE settings
      --apply-layout         Apply the Liquid Glass Plasma panel layout
      --skip-layout          Do not apply the Plasma panel layout
      --skip-discord-theme   Do not install the Discord/Vesktop CSS theme
      --skip-window-rules    Do not install KWin borderless glass window rules
      --skip-config-backup   Do not back up KDE config files before writing settings
      --skip-plasma-restart  Do not restart plasmashell or reload KWin
      --overlay-only         Only copy themes/modified-layan, preserving old behavior
      --user-install         Build source components into ~/.local instead of the system prefix
      --install-prefix DIR   CMake install prefix for source components (default: /usr)
      --theme-name NAME      Plasma theme folder to write into (default: Layan)
      --plasma-style NAME    Plasma style name written to plasmarc (default: Layan)
      --look-and-feel ID     Global theme/look-and-feel package id
      --icon-theme NAME      Icon theme written to kdeglobals (default: WhiteSur-dark)
      --app-style NAME       Widget style written to kdeglobals (default: Darkly)
      --color-scheme NAME    Color scheme written to kdeglobals (default: Darkly)
      --window-decoration NAME
                            KWin decoration library/theme hint (default: BreezeEnhanced)
      --wallpaper PATH       Wallpaper image applied with plasma-apply-wallpaperimage
      --target-root DIR      Plasma desktoptheme root
      --backup-root DIR      Backup directory root
  -h, --help                 Show this help

Examples:
  scripts/install.sh --dry-run
  scripts/install.sh --full-setup
  scripts/install.sh --install --init-submodules --install-packages
  scripts/install.sh --install --yes
  scripts/install.sh --install --overlay-only
EOF
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

note() {
  printf '%s\n' "$1"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

run_or_print() {
  if [[ "${MODE}" == "dry-run" ]]; then
    printf 'would run:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

run_shell_or_print() {
  local command="$1"
  if [[ "${MODE}" == "dry-run" ]]; then
    printf 'would run: %s\n' "${command}"
  else
    bash -lc "${command}"
  fi
}

run_in_dir_or_print() {
  local dir="$1"
  shift

  if [[ "${MODE}" == "dry-run" ]]; then
    printf 'would run: cd %q &&' "${dir}"
    printf ' %q' "$@"
    printf '\n'
  else
    (cd "${dir}" && "$@")
  fi
}

install_command_or_print() {
  local build_dir="$1"

  if [[ ${SYSTEM_INSTALL} -eq 1 ]]; then
    run_or_print sudo cmake --install "${build_dir}"
  else
    run_or_print cmake --install "${build_dir}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      MODE="dry-run"
      MODE_EXPLICIT=1
      shift
      ;;
    -i|--install)
      MODE="install"
      MODE_EXPLICIT=1
      shift
      ;;
    --full-setup)
      if [[ ${MODE_EXPLICIT} -eq 0 ]]; then
        MODE="install"
      fi
      INIT_SUBMODULES=1
      INSTALL_PACKAGES=1
      APPLY_LAYOUT=1
      shift
      ;;
    -y|--yes)
      ASSUME_YES=1
      shift
      ;;
    --init-submodules)
      INIT_SUBMODULES=1
      shift
      ;;
    --full-submodule-history)
      SUBMODULE_DEPTH=0
      shift
      ;;
    --install-packages)
      INSTALL_PACKAGES=1
      shift
      ;;
    --skip-builds)
      INSTALL_BUILDS=0
      shift
      ;;
    --skip-settings)
      APPLY_SETTINGS=0
      APPLY_LAYOUT=0
      BACKUP_CONFIGS=0
      INSTALL_WINDOW_RULES=0
      shift
      ;;
    --apply-layout)
      APPLY_LAYOUT=1
      shift
      ;;
    --skip-layout)
      APPLY_LAYOUT=0
      shift
      ;;
    --skip-discord-theme)
      INSTALL_DISCORD_THEME=0
      shift
      ;;
    --skip-window-rules)
      INSTALL_WINDOW_RULES=0
      shift
      ;;
    --skip-config-backup)
      BACKUP_CONFIGS=0
      shift
      ;;
    --skip-plasma-restart)
      RESTART_PLASMA=0
      shift
      ;;
    --overlay-only)
      INSTALL_BUILDS=0
      APPLY_SETTINGS=0
      APPLY_LAYOUT=0
      RESTART_PLASMA=0
      INSTALL_DISCORD_THEME=0
      INSTALL_WINDOW_RULES=0
      BACKUP_CONFIGS=0
      shift
      ;;
    --user-install)
      SYSTEM_INSTALL=0
      INSTALL_PREFIX="${HOME}/.local"
      shift
      ;;
    --install-prefix)
      [[ $# -ge 2 ]] || fail "--install-prefix requires a value"
      INSTALL_PREFIX="$2"
      if [[ "${INSTALL_PREFIX}" == "${HOME}/.local" || "${INSTALL_PREFIX}" == "${HOME}/.local/"* ]]; then
        SYSTEM_INSTALL=0
      fi
      shift 2
      ;;
    --theme-name)
      [[ $# -ge 2 ]] || fail "--theme-name requires a value"
      THEME_NAME="$2"
      shift 2
      ;;
    --plasma-style)
      [[ $# -ge 2 ]] || fail "--plasma-style requires a value"
      PLASMA_STYLE="$2"
      shift 2
      ;;
    --look-and-feel)
      [[ $# -ge 2 ]] || fail "--look-and-feel requires a value"
      LOOK_AND_FEEL="$2"
      shift 2
      ;;
    --icon-theme)
      [[ $# -ge 2 ]] || fail "--icon-theme requires a value"
      ICON_THEME="$2"
      shift 2
      ;;
    --app-style)
      [[ $# -ge 2 ]] || fail "--app-style requires a value"
      APP_STYLE="$2"
      shift 2
      ;;
    --color-scheme)
      [[ $# -ge 2 ]] || fail "--color-scheme requires a value"
      COLOR_SCHEME="$2"
      shift 2
      ;;
    --window-decoration)
      [[ $# -ge 2 ]] || fail "--window-decoration requires a value"
      WINDOW_DECORATION="$2"
      shift 2
      ;;
    --wallpaper)
      [[ $# -ge 2 ]] || fail "--wallpaper requires a value"
      WALLPAPER_IMAGE="$2"
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
BACKUP_DIR="${BACKUP_ROOT}/${THEME_NAME}-${STAMP}"
CONFIG_BACKUP_DIR="${BACKUP_ROOT}/kde-config-${STAMP}"

SOURCE_FILES=()
while IFS= read -r -d '' file; do
  SOURCE_FILES+=("$file")
done < <(find "${SOURCE_DIR}" -type f -print0 | sort -z)
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

kwriteconfig_bin() {
  if have kwriteconfig6; then
    printf 'kwriteconfig6'
  elif have kwriteconfig5; then
    printf 'kwriteconfig5'
  else
    return 1
  fi
}

kreadconfig_bin() {
  if have kreadconfig6; then
    printf 'kreadconfig6'
  elif have kreadconfig5; then
    printf 'kreadconfig5'
  else
    return 1
  fi
}

detect_package_command() {
  if have pacman; then
    printf 'sudo pacman -S --needed git base-devel cmake extra-cmake-modules qt6-base qt6-declarative qt6-tools kwin kconfig kconfigwidgets kcoreaddons kdecoration kguiaddons kcmutils kcolorscheme kwindowsystem kglobalaccel kio knotifications ki18n kiconthemes kpackage frameworkintegration kirigami libepoxy'
  elif have apt-get; then
    printf 'sudo apt-get update && sudo apt-get install -y git cmake extra-cmake-modules build-essential pkg-config gettext kwin-dev qt6-base-dev qt6-base-private-dev qt6-base-dev-tools qt6-declarative-dev qt6-tools-dev libkf6config-dev libkf6configwidgets-dev libkf6coreaddons-dev libkf6crash-dev libkf6globalaccel-dev libkf6guiaddons-dev libkf6i18n-dev libkf6iconthemes-dev libkf6kcmutils-dev libkf6kio-dev libkf6notifications-dev libkf6service-dev libkf6windowsystem-dev libkdecorations3-dev libepoxy-dev libdrm-dev libxcb-composite0-dev libxcb-randr0-dev libxcb-shm0-dev'
  elif have dnf; then
    printf 'sudo dnf install -y git cmake extra-cmake-modules gcc-c++ make pkgconf-pkg-config kwin-devel plasma-workspace-devel libplasma-devel qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel kdecoration-devel kf6-kcmutils-devel kf6-kconfig-devel kf6-kconfigwidgets-devel kf6-kcoreaddons-devel kf6-kcrash-devel kf6-kglobalaccel-devel kf6-kguiaddons-devel kf6-ki18n-devel kf6-kiconthemes-devel kf6-kio-devel kf6-knotifications-devel kf6-kservice-devel kf6-kwindowsystem-devel kf6-kdeclarative-devel libepoxy-devel wayland-devel libdrm-devel'
  elif have zypper; then
    printf 'sudo zypper install -y git cmake-full gcc-c++ make pkgconf-pkg-config kf6-extra-cmake-modules kwin6-devel qt6-base-devel qt6-base-private-devel qt6-declarative-devel qt6-tools-devel kdecoration-devel kcoreaddons-devel kguiaddons-devel kconfigwidgets-devel kwindowsystem-devel ki18n-devel kiconthemes-devel kpackage-devel frameworkintegration-devel kcmutils-devel kirigami2-devel libepoxy-devel wayland-devel libdrm-devel'
  else
    return 1
  fi
}

plasma_session_detected() {
  [[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* ]] && return 0
  [[ "${KDE_FULL_SESSION:-}" == "true" ]] && return 0
  [[ "${DESKTOP_SESSION:-}" == *plasma* ]] && return 0
  return 1
}

preflight_checks() {
  local missing_helpers=()
  local submodule_warning=0
  local dir

  printf '\n%sPreflight%s\n' "${bold}" "${reset}"

  if plasma_session_detected; then
    printf '%-18s %s\n' "Plasma session:" "detected"
  else
    printf '%-18s %s\n' "Plasma session:" "not detected; config writes can still run, live reload/wallpaper may be skipped"
  fi

  if [[ ${APPLY_SETTINGS} -eq 1 ]]; then
    if kwriteconfig_bin >/dev/null 2>&1; then
      printf '%-18s %s\n' "KDE config tool:" "$(kwriteconfig_bin)"
    elif [[ "${MODE}" == "dry-run" ]]; then
      printf '%-18s %s\n' "KDE config tool:" "not found here; dry-run will show kwriteconfig6 commands"
    else
      printf '%-18s %s\n' "KDE config tool:" "missing; install KDE config tools or rerun with --install-packages"
    fi
  fi

  if [[ ${APPLY_SETTINGS} -eq 1 ]]; then
    have plasma-apply-lookandfeel || missing_helpers+=("plasma-apply-lookandfeel")
    have plasma-apply-desktoptheme || missing_helpers+=("plasma-apply-desktoptheme")
    have plasma-apply-colorscheme || missing_helpers+=("plasma-apply-colorscheme")
    have plasma-apply-wallpaperimage || missing_helpers+=("plasma-apply-wallpaperimage")
    if [[ ${#missing_helpers[@]} -eq 0 ]]; then
      printf '%-18s %s\n' "Plasma helpers:" "available"
    else
      printf '%-18s %s\n' "Plasma helpers:" "missing optional: ${missing_helpers[*]}"
    fi
  fi

  if [[ ${APPLY_LAYOUT} -eq 1 ]]; then
    if have qdbus6 || have qdbus; then
      printf '%-18s %s\n' "Layout apply:" "D-Bus available"
    else
      printf '%-18s %s\n' "Layout apply:" "qdbus missing; panel layout will be skipped"
    fi
  fi

  if [[ ${INSTALL_BUILDS} -eq 1 ]]; then
    for dir in \
      "${REPO_ROOT}/Layan-kde" \
      "${REPO_ROOT}/WhiteSur-icon-theme" \
      "${REPO_ROOT}/Darkly" \
      "${REPO_ROOT}/BreezeEnhanced" \
      "${REPO_ROOT}/Better-Blur-DX" \
      "${REPO_ROOT}/KDE-Rounded-Corners"; do
      if is_uninitialized_submodule "${dir}"; then
        submodule_warning=1
      fi
    done

    if [[ ${submodule_warning} -eq 1 && ${INIT_SUBMODULES} -eq 0 ]]; then
      printf '%-18s %s\n' "Submodules:" "not initialized; pass --init-submodules for full component install"
    elif [[ ${submodule_warning} -eq 1 ]]; then
      printf '%-18s %s\n' "Submodules:" "will initialize before component install"
    else
      printf '%-18s %s\n' "Submodules:" "available"
    fi

    if [[ ${SYSTEM_INSTALL} -eq 1 ]]; then
      printf '%-18s %s\n' "System install:" "source components will use sudo cmake --install"
    else
      printf '%-18s %s\n' "System install:" "disabled; source components install under ${INSTALL_PREFIX}"
    fi
  fi

  if [[ ${INSTALL_PACKAGES} -eq 1 ]]; then
    if detect_package_command >/dev/null 2>&1; then
      printf '%-18s %s\n' "Package manager:" "supported"
    else
      printf '%-18s %s\n' "Package manager:" "unsupported; install dependencies manually"
    fi
  fi

  if [[ ${APPLY_SETTINGS} -eq 1 ]]; then
    if [[ -f "${WALLPAPER_IMAGE}" ]]; then
      printf '%-18s %s\n' "Wallpaper file:" "found"
    else
      printf '%-18s %s\n' "Wallpaper file:" "missing: ${WALLPAPER_IMAGE}"
    fi
  fi
}

print_header() {
  printf '\n%sKDE Plasma Liquid Glass installer%s\n' "${bold}" "${reset}"
  printf '%s%s%s\n\n' "${dim}" "Fresh KDE to riced setup with dry-run, backups and KDE config writes" "${reset}"
}

print_summary() {
  printf '%-18s %s\n' "Mode:" "${MODE}"
  printf '%-18s %s\n' "Repo:" "${REPO_ROOT}"
  printf '%-18s %s\n' "Theme source:" "${SOURCE_DIR}"
  printf '%-18s %s\n' "Theme target:" "${TARGET_DIR}"
  printf '%-18s %s\n' "Theme files:" "${#SOURCE_FILES[@]}"
  printf '%-18s %s\n' "Will backup:" "${count_existing}"
  printf '%-18s %s\n' "Init submodules:" "${INIT_SUBMODULES}"
  if [[ ${INIT_SUBMODULES} -eq 1 ]]; then
    if [[ ${SUBMODULE_DEPTH} -gt 0 ]]; then
      printf '%-18s %s\n' "Submodule depth:" "${SUBMODULE_DEPTH}"
    else
      printf '%-18s %s\n' "Submodule depth:" "full history"
    fi
  fi
  printf '%-18s %s\n' "Install packages:" "${INSTALL_PACKAGES}"
  printf '%-18s %s\n' "Build/install:" "${INSTALL_BUILDS}"
  printf '%-18s %s\n' "Install prefix:" "${INSTALL_PREFIX}"
  printf '%-18s %s\n' "Apply settings:" "${APPLY_SETTINGS}"
  printf '%-18s %s\n' "Apply layout:" "${APPLY_LAYOUT}"
  printf '%-18s %s\n' "Config backup:" "${BACKUP_CONFIGS}"
  printf '%-18s %s\n' "Discord theme:" "${INSTALL_DISCORD_THEME}"
  printf '%-18s %s\n' "Window rules:" "${INSTALL_WINDOW_RULES}"
  printf '%-18s %s\n' "Restart Plasma:" "${RESTART_PLASMA}"
  printf '%-18s %s\n' "Wallpaper:" "${WALLPAPER_IMAGE}"
  if [[ "${MODE}" == "install" ]]; then
    printf '%-18s %s\n' "Backup dir:" "${BACKUP_DIR}"
  fi
  printf '\n'
}

print_preview() {
  local shown=0
  local rel dest action

  printf '%sPlanned modified Layan file actions%s\n' "${bold}" "${reset}"
  printf '%-12s %s\n' "Action" "Path"
  printf '%-12s %s\n' "------" "----"

  for file in "${SOURCE_FILES[@]}"; do
    rel="$(relative_path "$file")"
    dest="$(destination_for "$file")"
    action="copy"
    if [[ -e "${dest}" ]]; then
      action="backup+copy"
    fi

    if [[ ${shown} -lt 14 ]]; then
      printf '%-12s %s\n' "${action}" "${rel}"
    fi
    shown=$((shown + 1))
  done

  if [[ ${shown} -gt 14 ]]; then
    printf '%-12s %s\n' "..." "$((shown - 14)) more files"
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
  if [[ ${APPLY_LAYOUT} -eq 1 ]]; then
    printf 'This will replace the current Plasma panel layout after backing up Plasma config files.\n'
  fi
  printf 'Install packages/build components, copy theme files and apply KDE settings now? [y/N] '
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

confirm_discord_theme() {
  if [[ "${MODE}" != "install" ]]; then
    return
  fi
  if [[ ${INSTALL_DISCORD_THEME} -eq 0 ]]; then
    return
  fi
  if [[ ${ASSUME_YES} -eq 1 ]]; then
    return
  fi
  if [[ ! -t 0 ]]; then
    fail "refusing to choose Discord theme installation without an interactive terminal; pass --yes or --skip-discord-theme"
  fi

  local answer
  printf 'Install the Discord/Vesktop CSS theme too? [y/N] '
  read -r answer
  case "${answer}" in
    y|Y|yes|YES)
      ;;
    *)
      INSTALL_DISCORD_THEME=0
      printf 'Skipping Discord/Vesktop CSS theme.\n'
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

copy_modified_layan() {
  local file dest copied=0

  mkdir -p -- "${TARGET_DIR}"
  for file in "${SOURCE_FILES[@]}"; do
    dest="$(destination_for "$file")"
    copy_file "$file" "$dest"
    copied=$((copied + 1))
  done

  printf '%sInstalled %s modified Layan files.%s\n' "${bold}" "${copied}" "${reset}"
  if [[ ${count_existing} -gt 0 ]]; then
    printf 'Backed up replaced files to:\n  %s\n' "${BACKUP_DIR}"
  else
    printf 'No existing modified Layan files needed backup.\n'
  fi
}

install_packages() {
  local command
  [[ ${INSTALL_PACKAGES} -eq 1 ]] || return 0

  printf '\n%sSystem packages%s\n' "${bold}" "${reset}"
  if command="$(detect_package_command)"; then
    run_shell_or_print "${command}"
  else
    note "No supported package manager detected. Install build dependencies manually."
  fi
}

init_submodules() {
  [[ ${INIT_SUBMODULES} -eq 1 ]] || return 0

  printf '\n%sSubmodules%s\n' "${bold}" "${reset}"
  if [[ ${SUBMODULE_DEPTH} -gt 0 ]]; then
    run_or_print git -C "${REPO_ROOT}" submodule update --init --recursive --depth "${SUBMODULE_DEPTH}"
  else
    run_or_print git -C "${REPO_ROOT}" submodule update --init --recursive
  fi
}

is_uninitialized_submodule() {
  local dir="$1"
  local rel="${dir#"${REPO_ROOT}/"}"
  local status

  status="$(git -C "${REPO_ROOT}" submodule status -- "${rel}" 2>/dev/null || true)"
  if [[ "${status}" == -* ]]; then
    return 0
  fi
  if [[ -n "${status}" ]] && ! git -C "${dir}" rev-parse --verify HEAD >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

will_exist_after_submodule_init() {
  local dir="$1"
  [[ "${MODE}" == "dry-run" ]] || return 1
  [[ ${INIT_SUBMODULES} -eq 1 ]] || return 1
  is_uninitialized_submodule "${dir}"
}

run_upstream_installer() {
  local name="$1"
  local dir="$2"
  shift 2

  if [[ ! -d "${dir}" ]]; then
    printf '%-18s %s\n' "${name}:" "missing"
    return 0
  fi
  if [[ -x "${dir}/install.sh" ]]; then
    printf '%-18s %s\n' "${name}:" "install.sh"
    run_in_dir_or_print "${dir}" ./install.sh "$@"
  elif will_exist_after_submodule_init "${dir}"; then
    printf '%-18s %s\n' "${name}:" "install.sh after submodule init"
    run_in_dir_or_print "${dir}" ./install.sh "$@"
  elif is_uninitialized_submodule "${dir}"; then
    printf '%-18s %s\n' "${name}:" "submodule not initialized; pass --init-submodules"
  else
    printf '%-18s %s\n' "${name}:" "no install.sh found"
  fi
}

cmake_install_project() {
  local name="$1"
  local dir="$2"
  local build_dir="${dir}/build"

  if [[ ! -f "${dir}/CMakeLists.txt" ]]; then
    if will_exist_after_submodule_init "${dir}"; then
      printf '%-18s %s\n' "${name}:" "cmake configure/build/install after submodule init"
      run_or_print cmake -S "${dir}" -B "${build_dir}" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}"
      run_or_print cmake --build "${build_dir}" --parallel
      install_command_or_print "${build_dir}"
      return 0
    fi
    if is_uninitialized_submodule "${dir}"; then
      printf '%-18s %s\n' "${name}:" "submodule not initialized; pass --init-submodules"
      return 0
    fi
    printf '%-18s %s\n' "${name}:" "no CMakeLists.txt found"
    return 0
  fi

  printf '%-18s %s\n' "${name}:" "cmake configure/build/install"
  run_or_print cmake -S "${dir}" -B "${build_dir}" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}"
  run_or_print cmake --build "${build_dir}" --parallel
  install_command_or_print "${build_dir}"
}

install_components() {
  [[ ${INSTALL_BUILDS} -eq 1 ]] || return 0

  printf '\n%sComponent installers%s\n' "${bold}" "${reset}"
  run_upstream_installer "Layan KDE" "${REPO_ROOT}/Layan-kde"
  run_upstream_installer "WhiteSur icons" "${REPO_ROOT}/WhiteSur-icon-theme" --dest "${HOME}/.local/share/icons" --kde-plasma
  cmake_install_project "Darkly" "${REPO_ROOT}/Darkly"
  cmake_install_project "BreezeEnhanced" "${REPO_ROOT}/BreezeEnhanced"
  cmake_install_project "Better Blur DX" "${REPO_ROOT}/Better-Blur-DX"
  cmake_install_project "Rounded Corners" "${REPO_ROOT}/KDE-Rounded-Corners"
}

write_kde_config() {
  local writer="$1"
  shift
  run_or_print "${writer}" "$@"
}

backup_kde_configs() {
  local files=(
    "${HOME}/.config/kdeglobals"
    "${HOME}/.config/plasmarc"
    "${HOME}/.config/kwinrc"
    "${HOME}/.config/kwinrulesrc"
    "${HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc"
    "${HOME}/.config/plasmashellrc"
  )
  local file

  [[ ${APPLY_SETTINGS} -eq 1 ]] || return 0
  [[ ${BACKUP_CONFIGS} -eq 1 ]] || return 0
  [[ ${CONFIGS_BACKED_UP} -eq 0 ]] || return 0
  CONFIGS_BACKED_UP=1

  printf '\n%sKDE config backup%s\n' "${bold}" "${reset}"
  for file in "${files[@]}"; do
    if [[ "${MODE}" == "dry-run" ]]; then
      if [[ -e "${file}" ]]; then
        printf 'would backup: %s -> %s/%s\n' "${file}" "${CONFIG_BACKUP_DIR}" "$(basename -- "${file}")"
      else
        printf 'would skip missing config: %s\n' "${file}"
      fi
      continue
    fi

    if [[ -e "${file}" ]]; then
      mkdir -p -- "${CONFIG_BACKUP_DIR}"
      cp -p -- "${file}" "${CONFIG_BACKUP_DIR}/$(basename -- "${file}")"
      printf 'Backed up %s\n' "${file}"
    fi
  done
}

run_optional_command() {
  local label="$1"
  shift

  if [[ "${MODE}" == "dry-run" ]]; then
    run_or_print "$@"
  elif have "$1"; then
    "$@"
  else
    note "${label} not found; skipping."
  fi
}

apply_kde_settings() {
  local writer
  local force_blur_classes
  [[ ${APPLY_SETTINGS} -eq 1 ]] || return 0

  printf '\n%sKDE settings%s\n' "${bold}" "${reset}"
  if ! writer="$(kwriteconfig_bin)"; then
    if [[ "${MODE}" == "dry-run" ]]; then
      writer="kwriteconfig6"
    else
      note "kwriteconfig6/kwriteconfig5 not found. Install KDE CLI tools or apply settings manually."
      return 0
    fi
  fi

  write_kde_config "${writer}" --file kdeglobals --group KDE --key widgetStyle "${APP_STYLE}"
  write_kde_config "${writer}" --file kdeglobals --group General --key ColorScheme "${COLOR_SCHEME}"
  write_kde_config "${writer}" --file kdeglobals --group Icons --key Theme "${ICON_THEME}"
  write_kde_config "${writer}" --file plasmarc --group Theme --key name "${PLASMA_STYLE}"
  write_kde_config "${writer}" --file kwinrc --group org.kde.kdecoration2 --key library "${WINDOW_DECORATION}"
  write_kde_config "${writer}" --file kwinrc --group org.kde.kdecoration2 --key theme "${WINDOW_DECORATION}"
  write_kde_config "${writer}" --file kwinrc --group Plugins --key blurEnabled false
  write_kde_config "${writer}" --file kwinrc --group Plugins --key contrastEnabled true
  write_kde_config "${writer}" --file kwinrc --group Plugins --key better_blur_dxEnabled true
  write_kde_config "${writer}" --file kwinrc --group Plugins --key kwin4_effect_shapecornersEnabled true
  write_kde_config "${writer}" --file kwinrc --group Plugins --key krohnkiteEnabled false

  force_blur_classes=$'plasmashell\norg.kde.plasmashell\nkrunner\nyakuake\nvesktop\ndiscord'
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key BlurStrength 20
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key NoiseStrength 3
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key Brightness 86
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key Saturation 135
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key Contrast 112
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key ForceContrastParams true
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key CornerRadius 16
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key WindowClasses "${force_blur_classes}"
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key BlurMatching true
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key BlurNonMatching false
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key BlurDecorations true
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key BlurMenus true
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key BlurDocks true
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key RefractionStrength 8
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key RefractionMode 0
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key RefractionEdgeSize 20
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key RefractionCornerRadius 16
  write_kde_config "${writer}" --file kwinrc --group Effect-better-blur-dx --key RefractionRGBFringing 1

  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key Size 14
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key InactiveCornerRadius 12
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key AnimationDuration 180
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key UseNativeDecorationShadows true
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key ShadowSize 55
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key InactiveShadowSize 35
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key ActiveShadowAlpha 120
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key InactiveShadowAlpha 70
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key OutlineThickness 1
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key InactiveOutlineThickness 1
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key ActiveOutlineAlpha 120
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key InactiveOutlineAlpha 70
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key SecondOutlineThickness 1
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key InactiveSecondOutlineThickness 1
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key ActiveSecondOutlineAlpha 55
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key InactiveSecondOutlineAlpha 35
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key IncludeNormalWindows true
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key IncludeDialogs true
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key DisableRoundTile true
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key DisableOutlineTile true
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key DisableRoundMaximize true
  write_kde_config "${writer}" --file kwinrc --group Round-Corners --key DisableOutlineMaximize true

  printf '\n%sPlasma apply commands%s\n' "${bold}" "${reset}"
  run_optional_command "plasma-apply-lookandfeel" plasma-apply-lookandfeel --apply "${LOOK_AND_FEEL}"
  run_optional_command "plasma-apply-desktoptheme" plasma-apply-desktoptheme "${PLASMA_STYLE}"
  run_optional_command "plasma-apply-colorscheme" plasma-apply-colorscheme "${COLOR_SCHEME}"
}

plasma_layout_script() {
  cat <<'EOF'
function removeExistingPanels() {
  var existing = panels();
  for (var i = 0; i < existing.length; i++) {
    if (existing[i] && typeof existing[i].remove === "function") {
      existing[i].remove();
    }
  }
}

function configureWidget(widget, group, values) {
  if (!widget) {
    return;
  }
  widget.currentConfigGroup = group;
  for (var key in values) {
    widget.writeConfig(key, values[key]);
  }
  widget.reloadConfig();
}

removeExistingPanels();

var liquidGlassGridUnit = (typeof gridUnit === "number" && gridUnit > 0) ? gridUnit : 18;
var panel = new Panel;
panel.location = "top";
panel.height = Math.round(liquidGlassGridUnit * 2.25);
panel.hiding = "none";
panel.alignment = "center";
panel.floating = true;

panel.addWidget("org.kde.plasma.kickoff");
panel.addWidget("org.kde.plasma.marginsseparator");
var tasks = panel.addWidget("org.kde.plasma.icontasks");
panel.addWidget("org.kde.plasma.marginsseparator");
var tray = panel.addWidget("org.kde.plasma.systemtray");
var clock = panel.addWidget("org.kde.plasma.digitalclock");

configureWidget(tasks, ["General"], {
  launchers: "applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop,applications:firefox.desktop,applications:vesktop.desktop",
  showOnlyCurrentDesktop: "false",
  showOnlyCurrentActivity: "true",
  showOnlyCurrentScreen: "false",
  groupingStrategy: "1",
  sortingStrategy: "1",
  fill: "false"
});

configureWidget(clock, ["Appearance"], {
  showDate: "true",
  dateFormat: "shortDate",
  showSeconds: "false"
});

if (tray) {
  tray.reloadConfig();
}
EOF
}

apply_plasma_layout() {
  local script
  [[ ${APPLY_LAYOUT} -eq 1 ]] || return 0

  printf '\n%sPlasma layout%s\n' "${bold}" "${reset}"
  script="$(plasma_layout_script)"

  if [[ "${MODE}" == "dry-run" ]]; then
    printf 'would run: qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript <liquid-glass-layout.js>\n'
    printf 'would create top floating panel with Kickoff, icon tasks, system tray and clock\n'
    return 0
  fi

  if have qdbus6; then
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "${script}"
  elif have qdbus; then
    qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "${script}"
  else
    note "qdbus not found; skipping Plasma panel layout."
    return 0
  fi
  printf 'Applied Liquid Glass Plasma panel layout.\n'
}

install_window_rules() {
  local writer
  local rules_file="${HOME}/.config/kwinrulesrc"
  local rule_id="liquid-glass-borderless"
  local rules existing count

  [[ ${APPLY_SETTINGS} -eq 1 ]] || return 0
  [[ ${INSTALL_WINDOW_RULES} -eq 1 ]] || return 0

  printf '\n%sKWin window rules%s\n' "${bold}" "${reset}"
  if ! writer="$(kwriteconfig_bin)"; then
    if [[ "${MODE}" == "dry-run" ]]; then
      writer="kwriteconfig6"
    else
      note "kwriteconfig6/kwriteconfig5 not found. Install KDE CLI tools or add the borderless rule manually."
      return 0
    fi
  fi

  rules=""
  if [[ -f "${rules_file}" ]]; then
    existing="$(awk -F= '/^rules=/{print $2; exit}' "${rules_file}" || true)"
    rules="${existing}"
  fi
  if [[ -z "${rules}" ]]; then
    rules="${rule_id}"
  elif [[ ",${rules}," != *",${rule_id},"* ]]; then
    rules="${rules},${rule_id}"
  fi
  count="$(awk -F, '{print NF}' <<<"${rules}")"

  write_kde_config "${writer}" --file kwinrulesrc --group General --key count "${count}"
  write_kde_config "${writer}" --file kwinrulesrc --group General --key rules "${rules}"
  write_kde_config "${writer}" --file kwinrulesrc --group "${rule_id}" --key Description "Liquid Glass borderless windows"
  write_kde_config "${writer}" --file kwinrulesrc --group "${rule_id}" --key wmclass ".*"
  write_kde_config "${writer}" --file kwinrulesrc --group "${rule_id}" --key wmclassmatch 3
  write_kde_config "${writer}" --file kwinrulesrc --group "${rule_id}" --key types 1
  write_kde_config "${writer}" --file kwinrulesrc --group "${rule_id}" --key noborder true
  write_kde_config "${writer}" --file kwinrulesrc --group "${rule_id}" --key noborderrule 2
}

apply_wallpaper() {
  [[ ${APPLY_SETTINGS} -eq 1 ]] || return 0

  printf '\n%sWallpaper%s\n' "${bold}" "${reset}"
  if [[ ! -f "${WALLPAPER_IMAGE}" ]]; then
    note "Wallpaper image not found: ${WALLPAPER_IMAGE}"
    return 0
  fi

  if have plasma-apply-wallpaperimage; then
    run_or_print plasma-apply-wallpaperimage "${WALLPAPER_IMAGE}"
  elif [[ "${MODE}" == "dry-run" ]]; then
    run_or_print plasma-apply-wallpaperimage "${WALLPAPER_IMAGE}"
  else
    note "plasma-apply-wallpaperimage not found; skipping wallpaper application."
  fi
}

install_discord_theme() {
  local targets=(
    "${HOME}/.config/vesktop/themes/${DISCORD_THEME_NAME}"
    "${HOME}/.config/Vencord/themes/${DISCORD_THEME_NAME}"
  )
  local target

  [[ ${INSTALL_DISCORD_THEME} -eq 1 ]] || return 0

  printf '\n%sDiscord / Vesktop theme%s\n' "${bold}" "${reset}"
  if [[ ! -f "${DISCORD_THEME_SOURCE}" ]]; then
    note "Discord theme source not found: ${DISCORD_THEME_SOURCE}"
    return 0
  fi

  for target in "${targets[@]}"; do
    if [[ "${MODE}" == "dry-run" ]]; then
      printf 'would copy: %s -> %s\n' "${DISCORD_THEME_SOURCE}" "${target}"
      continue
    fi

    mkdir -p -- "$(dirname -- "${target}")"
    if [[ -e "${target}" ]]; then
      mkdir -p -- "${BACKUP_ROOT}/discord-theme-${STAMP}"
      cp -p -- "${target}" "${BACKUP_ROOT}/discord-theme-${STAMP}/$(basename -- "${target}")"
    fi
    cp -p -- "${DISCORD_THEME_SOURCE}" "${target}"
    printf 'Installed %s\n' "${target}"
  done
}

verify_value() {
  local reader="$1"
  local file="$2"
  local group="$3"
  local key="$4"
  local expected="$5"
  local actual

  actual="$("${reader}" --file "${file}" --group "${group}" --key "${key}" 2>/dev/null || true)"
  if [[ "${actual}" != "${expected}" ]]; then
    printf 'Verification warning: %s [%s] %s expected %q, got %q\n' "${file}" "${group}" "${key}" "${expected}" "${actual}" >&2
    return 1
  fi
}

verify_file_match() {
  local source="$1"
  local dest="$2"

  if [[ ! -f "${dest}" ]]; then
    printf 'Verification warning: missing installed file %s\n' "${dest}" >&2
    return 1
  fi
  if ! cmp -s -- "${source}" "${dest}"; then
    printf 'Verification warning: installed file differs from source: %s\n' "${dest}" >&2
    return 1
  fi
}

verify_install() {
  local reader failed=0
  local file dest checked=0
  local discord_targets=(
    "${HOME}/.config/vesktop/themes/${DISCORD_THEME_NAME}"
    "${HOME}/.config/Vencord/themes/${DISCORD_THEME_NAME}"
  )

  printf '\n%sVerification%s\n' "${bold}" "${reset}"
  if [[ "${MODE}" == "dry-run" ]]; then
    printf 'would verify KDE config values and installed optional theme files\n'
    return 0
  fi

  for file in "${SOURCE_FILES[@]}"; do
    dest="$(destination_for "${file}")"
    verify_file_match "${file}" "${dest}" || failed=1
    checked=$((checked + 1))
  done
  printf 'Verified %s modified Layan files.\n' "${checked}"

  if [[ ${INSTALL_DISCORD_THEME} -eq 1 && -f "${DISCORD_THEME_SOURCE}" ]]; then
    for dest in "${discord_targets[@]}"; do
      verify_file_match "${DISCORD_THEME_SOURCE}" "${dest}" || failed=1
    done
    printf 'Verified Discord/Vesktop theme files.\n'
  fi

  if [[ ${APPLY_SETTINGS} -eq 1 ]]; then
    if ! reader="$(kreadconfig_bin)"; then
      note "kreadconfig6/kreadconfig5 not found; skipping config verification."
    else
      verify_value "${reader}" kdeglobals KDE widgetStyle "${APP_STYLE}" || failed=1
      verify_value "${reader}" kdeglobals General ColorScheme "${COLOR_SCHEME}" || failed=1
      verify_value "${reader}" kdeglobals Icons Theme "${ICON_THEME}" || failed=1
      verify_value "${reader}" plasmarc Theme name "${PLASMA_STYLE}" || failed=1
      verify_value "${reader}" kwinrc Plugins better_blur_dxEnabled true || failed=1
      verify_value "${reader}" kwinrc Plugins kwin4_effect_shapecornersEnabled true || failed=1
      verify_value "${reader}" kwinrc Effect-better-blur-dx BlurStrength 20 || failed=1
      verify_value "${reader}" kwinrc Round-Corners Size 14 || failed=1
    fi

    if [[ ${INSTALL_WINDOW_RULES} -eq 1 ]] && ! grep -F "liquid-glass-borderless" "${HOME}/.config/kwinrulesrc" >/dev/null 2>&1; then
      printf 'Verification warning: kwinrulesrc does not include liquid-glass-borderless\n' >&2
      failed=1
    fi
  fi

  if [[ ${failed} -eq 0 ]]; then
    printf 'Install verification passed.\n'
  else
    printf 'Install verification found warnings; inspect the messages above.\n' >&2
  fi
}

reload_plasma() {
  local reader
  [[ ${RESTART_PLASMA} -eq 1 ]] || return 0

  printf '\n%sReload Plasma%s\n' "${bold}" "${reset}"
  if have kbuildsycoca6; then
    run_or_print kbuildsycoca6
  elif have kbuildsycoca5; then
    run_or_print kbuildsycoca5
  else
    note "kbuildsycoca not found; skipping KDE service cache refresh."
  fi

  if have qdbus6; then
    run_or_print qdbus6 org.kde.KWin /KWin reconfigure
  elif have qdbus; then
    run_or_print qdbus org.kde.KWin /KWin reconfigure
  else
    note "qdbus not found; skipping KWin reconfigure."
  fi

  if reader="$(kreadconfig_bin)" && [[ "${MODE}" == "install" ]]; then
    "${reader}" --file plasmarc --group Theme --key name >/dev/null 2>&1 || true
  fi

  if have kquitapp6 && have kstart6; then
    run_or_print kquitapp6 plasmashell
    run_or_print kstart6 plasmashell
  elif have kquitapp5 && have kstart5; then
    run_or_print kquitapp5 plasmashell
    run_or_print kstart5 plasmashell
  else
    note "kquitapp/kstart not found; log out and back in to refresh Plasma."
  fi
}

print_next_steps() {
  printf '\n%sDone.%s\n' "${bold}" "${reset}"
  if [[ ${INIT_SUBMODULES} -eq 0 ]]; then
    printf 'For a fresh clone, rerun with --init-submodules so upstream components are available.\n'
  fi
  if [[ ${INSTALL_PACKAGES} -eq 0 && ${INSTALL_BUILDS} -eq 1 ]]; then
    printf 'If component builds fail, rerun with --install-packages or install KDE build dependencies manually.\n'
  fi
}

print_header
print_summary
print_preview
preflight_checks

if [[ "${MODE}" == "dry-run" ]]; then
  install_packages
  init_submodules
  install_components
  backup_kde_configs
  apply_kde_settings
  apply_plasma_layout
  install_window_rules
  apply_wallpaper
  install_discord_theme
  verify_install
  reload_plasma
  printf 'Dry run only. Re-run with --install to apply changes.\n'
  exit 0
fi

confirm_install
confirm_discord_theme
install_packages
init_submodules
install_components
copy_modified_layan
backup_kde_configs
apply_kde_settings
apply_plasma_layout
install_window_rules
apply_wallpaper
install_discord_theme
verify_install
reload_plasma
print_next_steps
