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

DISTRO_OVERRIDE=""
DISTRO_ID="unknown"
DISTRO_NAME="unknown"
DISTRO_FAMILY="unknown"
IMMUTABLE=0
IMMUTABLE_REASON=""
OS_RELEASE_FILE="${LIQUID_GLASS_OS_RELEASE:-/etc/os-release}"
PROBE_SYSTEM=1
if [[ -n "${LIQUID_GLASS_OS_RELEASE:-}" ]]; then
  PROBE_SYSTEM=0
fi
SESSION_TYPE=""
PRINT_PACKAGES=0
CHECK_PACKAGES=0
ALLOW_ROOT=0
PREFIX_EXPLICIT=0
PREFIX_AUTO_USER=0
DECORATION_EXPLICIT=0
ROOT_CMD=""
PLASMA_VERSION=""
BUILD_ROOT="${REPO_ROOT}/.build"
PLUGIN_ROOTS=""
INSTALLED_COMPONENTS=()
FAILED_COMPONENTS=()
SKIPPED_COMPONENTS=()
BLUR_DX_AVAILABLE=1
ROUNDED_CORNERS_AVAILABLE=1
BREEZE_ENHANCED_AVAILABLE=1
DARKLY_AVAILABLE=1
EFFECTIVE_BLUR_DX="true"
EFFECTIVE_CORNERS="true"
EFFECTIVE_DECORATION=""
AVAILABLE_PACKAGES=()
MISSING_PACKAGES=()

CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"

THEME_NAME="Layan"
PLASMA_STYLE="Layan"
LOOK_AND_FEEL="com.github.vinceliuice.Layan"
ICON_THEME="WhiteSur-dark"
APP_STYLE="Darkly"
COLOR_SCHEME="Darkly"
WINDOW_DECORATION="BreezeEnhanced"
INSTALL_PREFIX="/usr"
TARGET_ROOT="${DATA_HOME}/plasma/desktoptheme"
BACKUP_ROOT="${DATA_HOME}/plasma/desktoptheme/.liquid-glass-backups"
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
      --distro NAME          Override distro detection: arch, debian, fedora, suse, nixos,
                            alpine, void, gentoo (default: auto from /etc/os-release)
      --x11                  Build KWin effects for a KWin X11 session (default: auto-detect)
      --wayland              Build KWin effects for a KWin Wayland session (default: auto-detect)
      --build-root DIR       Out-of-tree CMake build directory (default: <repo>/.build)
      --print-packages       Print the build dependency list for this distro and exit
      --check-packages       Check that every dependency exists in this system's configured
                            repositories (installs nothing; exits 1 if any are missing)
      --allow-root           Allow running the installer directly as root
      --theme-name NAME     Plasma theme folder to write into (default: Layan)
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
  scripts/install.sh --distro fedora --print-packages

Package installs are automated on Arch (pacman), Debian/Ubuntu (apt), Fedora (dnf)
and openSUSE (zypper). NixOS prints a declarative configuration snippet instead of
touching /usr. Other distros (Alpine, Void, Gentoo, immutable/atomic systems) still
get the theme, settings and user-level components; build dependencies for the
KWin/Qt plugins must come from your own tooling (distrobox, toolbox, ...).
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
      PREFIX_EXPLICIT=1
      INSTALL_PREFIX="${HOME}/.local"
      shift
      ;;
    --distro)
      [[ $# -ge 2 ]] || fail "--distro requires a value"
      DISTRO_OVERRIDE="$2"
      shift 2
      ;;
    --x11)
      SESSION_TYPE="x11"
      shift
      ;;
    --wayland)
      SESSION_TYPE="wayland"
      shift
      ;;
    --build-root)
      [[ $# -ge 2 ]] || fail "--build-root requires a value"
      BUILD_ROOT="$2"
      shift 2
      ;;
    --print-packages)
      PRINT_PACKAGES=1
      shift
      ;;
    --check-packages)
      CHECK_PACKAGES=1
      shift
      ;;
    --allow-root)
      ALLOW_ROOT=1
      shift
      ;;
    --install-prefix)
      [[ $# -ge 2 ]] || fail "--install-prefix requires a value"
      INSTALL_PREFIX="$2"
      PREFIX_EXPLICIT=1
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
      DECORATION_EXPLICIT=1
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

lowercase() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

os_release_value() {
  local key="$1"
  local line

  [[ -r "${OS_RELEASE_FILE}" ]] || return 0
  line="$(grep -E "^${key}=" "${OS_RELEASE_FILE}" 2>/dev/null | head -n 1 || true)"
  line="${line#*=}"
  line="${line%\"}"
  line="${line#\"}"
  line="${line%\'}"
  line="${line#\'}"
  printf '%s' "${line}"
}

# Maps distro ids (an os-release ID followed by its ID_LIKE words) to the
# package family the installer knows how to handle.
distro_family_for() {
  local word
  for word in "$@"; do
    case "$(lowercase "${word}")" in
      arch|archlinux|manjaro|endeavouros|cachyos|garuda|artix|arcolinux|archcraft|steamos)
        printf 'arch'
        return 0
        ;;
      debian|ubuntu|linuxmint|neon|pop|zorin|elementary|raspbian|kali|devuan|mx|lmde|kubuntu|parrot)
        printf 'debian'
        return 0
        ;;
      fedora|rhel|centos|rocky|almalinux|nobara|ol|ultramarine|bazzite|aurora)
        printf 'fedora'
        return 0
        ;;
      opensuse*|suse|sles|sled|tumbleweed|leap|aeon|kalpa|slowroll)
        printf 'suse'
        return 0
        ;;
      nixos|nix)
        printf 'nixos'
        return 0
        ;;
      alpine|postmarketos)
        printf 'alpine'
        return 0
        ;;
      void)
        printf 'void'
        return 0
        ;;
      gentoo|funtoo|calculate)
        printf 'gentoo'
        return 0
        ;;
    esac
  done
  printf 'unknown'
}

detect_distro() {
  local id id_like variant

  if [[ -n "${DISTRO_OVERRIDE}" ]]; then
    DISTRO_ID="$(lowercase "${DISTRO_OVERRIDE}")"
    DISTRO_NAME="${DISTRO_OVERRIDE} (from --distro)"
    DISTRO_FAMILY="$(distro_family_for "${DISTRO_ID}")"
    [[ "${DISTRO_FAMILY}" != "unknown" ]] || fail "unknown --distro '${DISTRO_OVERRIDE}'; use arch, debian, ubuntu, fedora, suse, nixos, alpine, void or gentoo"
  else
    id="$(os_release_value ID)"
    id_like="$(os_release_value ID_LIKE)"
    variant="$(os_release_value VARIANT_ID)"
    DISTRO_ID="${id:-unknown}"
    DISTRO_NAME="$(os_release_value PRETTY_NAME)"
    DISTRO_NAME="${DISTRO_NAME:-${DISTRO_ID}}"
    # shellcheck disable=SC2086
    DISTRO_FAMILY="$(distro_family_for "${id}" ${id_like})"

    if [[ "${DISTRO_FAMILY}" == "unknown" && ${PROBE_SYSTEM} -eq 1 ]]; then
      if [[ -e /etc/NIXOS ]]; then
        DISTRO_FAMILY="nixos"
      elif have pacman; then
        DISTRO_FAMILY="arch"
      elif have apt-get; then
        DISTRO_FAMILY="debian"
      elif have dnf; then
        DISTRO_FAMILY="fedora"
      elif have zypper; then
        DISTRO_FAMILY="suse"
      elif have apk; then
        DISTRO_FAMILY="alpine"
      elif have xbps-install; then
        DISTRO_FAMILY="void"
      elif have emerge; then
        DISTRO_FAMILY="gentoo"
      fi
    fi

    case "$(lowercase "${id}:${variant}")" in
      steamos:*)
        IMMUTABLE=1
        IMMUTABLE_REASON="SteamOS keeps / read-only"
        ;;
      *:kinoite|*:silverblue|*:sericea|*:onyx|*:aeon|*:kalpa|*:microos)
        IMMUTABLE=1
        IMMUTABLE_REASON="${variant} is an image-based (atomic) system"
        ;;
    esac
    if [[ ${IMMUTABLE} -eq 0 && ${PROBE_SYSTEM} -eq 1 ]]; then
      if [[ -e /run/ostree-booted ]]; then
        IMMUTABLE=1
        IMMUTABLE_REASON="ostree/rpm-ostree image-based system"
      elif have transactional-update; then
        IMMUTABLE=1
        IMMUTABLE_REASON="transactional-update system"
      fi
    fi
  fi

  if [[ "${DISTRO_FAMILY}" == "nixos" ]]; then
    IMMUTABLE=1
    IMMUTABLE_REASON="NixOS manages /usr and system packages declaratively"
  fi
}

detect_session_type() {
  local detected
  [[ -z "${SESSION_TYPE}" ]] || return 0
  detected="$(lowercase "${XDG_SESSION_TYPE:-}")"
  case "${detected}" in
    x11)
      SESSION_TYPE="x11"
      ;;
    *)
      SESSION_TYPE="wayland"
      ;;
  esac
}

detect_plasma_version() {
  local output=""
  if have plasmashell; then
    output="$(plasmashell --version 2>/dev/null || true)"
  fi
  if [[ -z "${output}" ]] && have kwin_wayland; then
    output="$(kwin_wayland --version 2>/dev/null || true)"
  fi
  PLASMA_VERSION="$(printf '%s\n' "${output}" | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1 || true)"
}

# version_ge A B: true when A >= B, comparing major.minor.patch numerically.
version_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    na = split(a, x, "."); nb = split(b, y, ".")
    for (i = 1; i <= 3; i++) {
      xi = (i <= na) ? x[i] + 0 : 0
      yi = (i <= nb) ? y[i] + 0 : 0
      if (xi > yi) exit 0
      if (xi < yi) exit 1
    }
    exit 0
  }'
}

detect_root_command() {
  if [[ ${EUID} -eq 0 ]]; then
    ROOT_CMD=""
  elif have sudo; then
    ROOT_CMD="sudo"
  elif have doas; then
    ROOT_CMD="doas"
  elif [[ "${MODE}" == "dry-run" ]]; then
    ROOT_CMD="sudo"
  else
    ROOT_CMD="__missing__"
  fi
}

# Runs a command with root privileges: directly when already root, otherwise
# through sudo or doas.
as_root() {
  if [[ "${ROOT_CMD}" == "__missing__" ]]; then
    printf 'Error: root privileges are required but neither sudo nor doas is available. Re-run as root or use --user-install.\n' >&2
    return 1
  fi
  if [[ -n "${ROOT_CMD}" ]]; then
    run_or_print "${ROOT_CMD}" "$@"
  else
    run_or_print "$@"
  fi
}

qdbus_bin() {
  local candidate
  for candidate in qdbus6 qdbus-qt6 qdbus qdbus-qt5; do
    if have "${candidate}"; then
      printf '%s' "${candidate}"
      return 0
    fi
  done
  for candidate in /usr/lib/qt6/bin/qdbus /usr/lib64/qt6/bin/qdbus /usr/lib/x86_64-linux-gnu/qt6/bin/qdbus /usr/lib/qt5/bin/qdbus; do
    if [[ -x "${candidate}" ]]; then
      printf '%s' "${candidate}"
      return 0
    fi
  done
  return 1
}

# Escapes a string as a GVariant text literal so gdbus passes it through as-is.
gvariant_string() {
  local text="$1"
  text="${text//\\/\\\\}"
  text="${text//\'/\\\'}"
  text="${text//$'\n'/\\n}"
  printf "'%s'" "${text}"
}

dbus_tool_available() {
  qdbus_bin >/dev/null 2>&1 || have gdbus
}

# dbus_call SERVICE PATH INTERFACE.METHOD [STRING_ARG]
dbus_call() {
  local service="$1" object="$2" method="$3" arg="${4-}"
  local qdbus

  if qdbus="$(qdbus_bin)"; then
    if [[ $# -ge 4 ]]; then
      "${qdbus}" "${service}" "${object}" "${method}" "${arg}"
    else
      "${qdbus}" "${service}" "${object}" "${method}"
    fi
  elif have gdbus; then
    if [[ $# -ge 4 ]]; then
      gdbus call --session --dest "${service}" --object-path "${object}" --method "${method}" "$(gvariant_string "${arg}")"
    else
      gdbus call --session --dest "${service}" --object-path "${object}" --method "${method}"
    fi
  else
    return 127
  fi
}

# Window decoration ids: kwinrc wants the KDecoration plugin id and a theme name.
decoration_library() {
  case "$1" in
    org.kde.*) printf '%s' "$1" ;;
    BreezeEnhanced) printf 'org.kde.breezeenhanced' ;;
    Darkly) printf 'org.kde.darkly' ;;
    Breeze) printf 'org.kde.breeze' ;;
    *) printf '%s' "$1" ;;
  esac
}

decoration_theme() {
  case "$1" in
    org.kde.breezeenhanced|BreezeEnhanced) printf 'BreezeEnhanced' ;;
    org.kde.darkly|Darkly) printf 'Darkly' ;;
    org.kde.breeze|Breeze) printf 'Breeze' ;;
    *) printf '%s' "$1" ;;
  esac
}

package_manager_for_family() {
  case "${DISTRO_FAMILY}" in
    arch) printf 'pacman' ;;
    debian) printf 'apt-get' ;;
    fedora) printf 'dnf' ;;
    suse) printf 'zypper' ;;
    *) return 1 ;;
  esac
}

# Build dependencies for Darkly, BreezeEnhanced, Better Blur DX and KDE Rounded
# Corners (Plasma 6 / Qt 6 / KF6). Names verified against current Arch, Debian
# sid, Fedora rawhide and openSUSE Tumbleweed repositories.
package_list() {
  local x11=0
  [[ "${SESSION_TYPE}" == "x11" ]] && x11=1

  case "${DISTRO_FAMILY}" in
    arch)
      printf '%s' "base-devel git cmake extra-cmake-modules qt6-base qt6-declarative qt6-svg qt6-tools"
      if [[ ${x11} -eq 1 ]]; then
        printf ' %s' "kwin-x11"
      else
        printf ' %s' "kwin"
      fi
      printf ' %s' "kdecoration kconfig kconfigwidgets kcoreaddons kcolorscheme kcmutils kcrash kglobalaccel kguiaddons kiconthemes kio kirigami knotifications kpackage kservice ki18n kwindowsystem frameworkintegration libepoxy libdrm libxcb wayland vulkan-headers"
      ;;
    debian)
      printf '%s' "git cmake extra-cmake-modules build-essential pkg-config gettext qt6-base-dev qt6-base-private-dev qt6-base-dev-tools qt6-declarative-dev qt6-svg-dev qt6-tools-dev"
      if [[ ${x11} -eq 1 ]]; then
        printf ' %s' "kwin-x11-dev"
      else
        printf ' %s' "kwin-dev"
      fi
      printf ' %s' "libkdecorations3-dev libkf6colorscheme-dev libkf6config-dev libkf6configwidgets-dev libkf6coreaddons-dev libkf6crash-dev libkf6globalaccel-dev libkf6guiaddons-dev libkf6i18n-dev libkf6iconthemes-dev libkf6kcmutils-dev libkf6kio-dev libkf6notifications-dev libkf6service-dev libkf6style-dev libkf6widgetsaddons-dev libkf6windowsystem-dev libkirigami-dev libepoxy-dev libdrm-dev libwayland-dev libxcb1-dev libxcb-composite0-dev libxcb-randr0-dev libxcb-shm0-dev"
      ;;
    fedora)
      printf '%s' "git cmake extra-cmake-modules gcc-c++ make pkgconf-pkg-config qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtsvg-devel qt6-qttools-devel"
      if [[ ${x11} -eq 1 ]]; then
        printf ' %s' "kwin-x11-devel"
      else
        printf ' %s' "kwin-devel"
      fi
      printf ' %s' "plasma-workspace-devel libplasma-devel kdecoration-devel kf6-frameworkintegration-devel kf6-kcmutils-devel kf6-kcolorscheme-devel kf6-kconfig-devel kf6-kconfigwidgets-devel kf6-kcoreaddons-devel kf6-kcrash-devel kf6-kdeclarative-devel kf6-kglobalaccel-devel kf6-kguiaddons-devel kf6-ki18n-devel kf6-kiconthemes-devel kf6-kio-devel kf6-kirigami-devel kf6-knotifications-devel kf6-kpackage-devel kf6-kservice-devel kf6-kwidgetsaddons-devel kf6-kwindowsystem-devel libepoxy-devel libdrm-devel libxcb-devel wayland-devel"
      ;;
    suse)
      printf '%s' "git cmake-full gcc-c++ make pkgconf-pkg-config kf6-extra-cmake-modules qt6-base-devel qt6-base-private-devel qt6-core-private-devel qt6-declarative-devel qt6-quick-devel qt6-svg-devel qt6-tools-devel"
      if [[ ${x11} -eq 1 ]]; then
        printf ' %s' "kwin6-x11-devel"
      else
        printf ' %s' "kwin6-devel"
      fi
      printf ' %s' "cmake(KDecoration3) cmake(KF6ColorScheme) cmake(KF6Config) cmake(KF6ConfigWidgets) cmake(KF6CoreAddons) cmake(KF6Crash) cmake(KF6Declarative) cmake(KF6FrameworkIntegration) cmake(KF6GlobalAccel) cmake(KF6GuiAddons) cmake(KF6I18n) cmake(KF6IconThemes) cmake(KF6KCMUtils) cmake(KF6KIO) cmake(KF6KirigamiPlatform) cmake(KF6Notifications) cmake(KF6Package) cmake(KF6Service) cmake(KF6WidgetsAddons) cmake(KF6WindowSystem) libepoxy-devel libdrm-devel libxcb-devel wayland-devel"
      ;;
    *)
      return 1
      ;;
  esac
}

# Sets AVAILABLE_PACKAGES / MISSING_PACKAGES for managers that fail an entire
# transaction on one unknown name (apt, pacman).
filter_available_packages() {
  local manager="$1"
  shift
  local pkg candidate
  AVAILABLE_PACKAGES=()
  MISSING_PACKAGES=()

  for pkg in "$@"; do
    case "${manager}" in
      apt-get)
        candidate="$(apt-cache policy "${pkg}" 2>/dev/null | awk '/Candidate:/ {print $2}' || true)"
        if [[ -n "${candidate}" && "${candidate}" != "(none)" ]]; then
          AVAILABLE_PACKAGES+=("${pkg}")
        else
          MISSING_PACKAGES+=("${pkg}")
        fi
        ;;
      pacman)
        if pacman -Si "${pkg}" >/dev/null 2>&1 || pacman -Sg "${pkg}" >/dev/null 2>&1; then
          AVAILABLE_PACKAGES+=("${pkg}")
        else
          MISSING_PACKAGES+=("${pkg}")
        fi
        ;;
      dnf)
        if [[ -n "$(dnf -q repoquery --available --whatprovides "${pkg}" 2>/dev/null | head -n 1)" ]]; then
          AVAILABLE_PACKAGES+=("${pkg}")
        else
          MISSING_PACKAGES+=("${pkg}")
        fi
        ;;
      zypper)
        if zypper --non-interactive --quiet search --match-exact --provides "${pkg}" >/dev/null 2>&1; then
          AVAILABLE_PACKAGES+=("${pkg}")
        else
          MISSING_PACKAGES+=("${pkg}")
        fi
        ;;
      *)
        AVAILABLE_PACKAGES+=("${pkg}")
        ;;
    esac
  done
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
  local dir manager

  printf '\n%sPreflight%s\n' "${bold}" "${reset}"

  printf '%-18s %s\n' "Distro:" "${DISTRO_NAME} (family: ${DISTRO_FAMILY})"
  if [[ ${IMMUTABLE} -eq 1 ]]; then
    printf '%-18s %s\n' "System image:" "immutable/declarative: ${IMMUTABLE_REASON}"
  fi
  printf '%-18s %s\n' "KWin build target:" "${SESSION_TYPE}"
  if [[ -n "${PLASMA_VERSION}" ]]; then
    printf '%-18s %s\n' "Plasma version:" "${PLASMA_VERSION}"
  else
    printf '%-18s %s\n' "Plasma version:" "not detected; component version checks will be skipped"
  fi
  if [[ ${EUID} -eq 0 ]]; then
    printf '%-18s %s\n' "Privileges:" "running as root"
  elif [[ "${ROOT_CMD}" == "__missing__" ]]; then
    printf '%-18s %s\n' "Privileges:" "no sudo/doas found; system-wide steps will fail (use --user-install)"
  else
    printf '%-18s %s\n' "Privileges:" "${ROOT_CMD:-root} for system-wide steps"
  fi

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

  if [[ ${APPLY_LAYOUT} -eq 1 || ${RESTART_PLASMA} -eq 1 ]]; then
    if qdbus_bin >/dev/null 2>&1; then
      printf '%-18s %s\n' "D-Bus tool:" "$(qdbus_bin)"
    elif have gdbus; then
      printf '%-18s %s\n' "D-Bus tool:" "gdbus (fallback)"
    else
      printf '%-18s %s\n' "D-Bus tool:" "qdbus/gdbus missing; panel layout and live KWin reload will be skipped"
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

    if [[ "${DISTRO_FAMILY}" == "nixos" ]]; then
      printf '%-18s %s\n' "System install:" "disabled on NixOS; KWin/Qt plugins come from your Nix configuration"
    elif [[ ${SYSTEM_INSTALL} -eq 1 ]]; then
      printf '%-18s %s\n' "System install:" "source components will use ${ROOT_CMD:-direct} cmake --install"
    elif [[ ${PREFIX_AUTO_USER} -eq 1 ]]; then
      printf '%-18s %s\n' "System install:" "disabled automatically (${IMMUTABLE_REASON}); installing under ${INSTALL_PREFIX}"
    else
      printf '%-18s %s\n' "System install:" "disabled; source components install under ${INSTALL_PREFIX}"
    fi
  fi

  if [[ ${INSTALL_PACKAGES} -eq 1 ]]; then
    if [[ "${DISTRO_FAMILY}" == "nixos" ]]; then
      printf '%-18s %s\n' "Package manager:" "nix (declarative); a NixOS configuration snippet will be printed"
    elif [[ ${IMMUTABLE} -eq 1 ]]; then
      printf '%-18s %s\n' "Package manager:" "skipped; ${IMMUTABLE_REASON}"
    elif manager="$(package_manager_for_family)"; then
      if have "${manager}" || [[ "${MODE}" == "dry-run" ]]; then
        printf '%-18s %s\n' "Package manager:" "supported (${manager})"
      else
        printf '%-18s %s\n' "Package manager:" "${manager} not found on PATH"
      fi
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

print_packages() {
  local manager
  if [[ "${DISTRO_FAMILY}" == "nixos" ]]; then
    printf '%s\n' "darkly" "kde-rounded-corners" "whitesur-icon-theme" "kwin-effects-better-blur-dx (flake input: github:xarblu/kwin-effects-better-blur-dx)"
    return 0
  fi
  if ! manager="$(package_manager_for_family)"; then
    printf 'No package list for distro family "%s"; see README.\n' "${DISTRO_FAMILY}" >&2
    return 1
  fi
  printf '# %s packages (%s, %s build target)\n' "${manager}" "${DISTRO_FAMILY}" "${SESSION_TYPE}"
  package_list | tr ' ' '\n'
}

print_nixos_guidance() {
  [[ "${DISTRO_FAMILY}" == "nixos" ]] || return 0
  [[ ${INSTALL_BUILDS} -eq 1 || ${INSTALL_PACKAGES} -eq 1 ]] || return 0

  printf '\n%sNixOS%s\n' "${bold}" "${reset}"
  cat <<'NIXEOF'
NixOS keeps /usr read-only and loads KWin/Qt plugins from the Nix store, so the
KWin effects and Qt style must be declared in your configuration instead of being
built by this script. Layan, WhiteSur-dark, the modified overlay, KDE settings and
the Discord theme are still installed into your home directory.

Add to your NixOS configuration (check names against your nixpkgs channel):

  environment.systemPackages = with pkgs; [
    darkly                # Darkly application style and window decorations
    kde-rounded-corners   # KDE Rounded Corners KWin effect
    whitesur-icon-theme   # optional; the installer also copies WhiteSur-dark to ~/.local/share/icons
    # Better Blur DX is not in nixpkgs; use its flake:
    inputs.kwin-effects-better-blur-dx.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

and in flake.nix:

  inputs.kwin-effects-better-blur-dx = {
    url = "github:xarblu/kwin-effects-better-blur-dx";
    inputs.nixpkgs.follows = "nixpkgs";
  };

BreezeEnhanced has no nixpkgs package, so the window decoration defaults to the one
shipped with Darkly. Rebuild with `sudo nixos-rebuild switch`, then log out and in.
NIXEOF
}

apply_environment_policy() {
  if [[ "${DISTRO_FAMILY}" == "nixos" ]]; then
    SYSTEM_INSTALL=0
    if [[ ${DECORATION_EXPLICIT} -eq 0 ]]; then
      WINDOW_DECORATION="Darkly"
    fi
    return 0
  fi

  if [[ ${IMMUTABLE} -eq 1 ]]; then
    if [[ ${PREFIX_EXPLICIT} -eq 0 ]]; then
      SYSTEM_INSTALL=0
      INSTALL_PREFIX="${HOME}/.local"
      PREFIX_AUTO_USER=1
    fi
  fi
}

check_run_as_root() {
  [[ "${MODE}" == "install" ]] || return 0
  [[ ${EUID} -eq 0 ]] || return 0
  [[ ${ALLOW_ROOT} -eq 0 ]] || return 0

  if [[ -n "${SUDO_USER:-}" ]]; then
    fail "do not run this installer with sudo: user settings would be written to root's home. Run it as your normal user (it uses sudo only for system-wide steps), or pass --allow-root."
  fi
  note "Warning: running as root; KDE settings and theme files will be written to ${HOME}."
}

# Verifies every dependency resolves in the configured repositories without
# installing anything. Used by CI to catch package-name drift per distro.
check_packages() {
  local manager
  local packages=()

  if ! manager="$(package_manager_for_family)"; then
    printf 'Error: --check-packages needs a supported package manager (family: %s).\n' "${DISTRO_FAMILY}" >&2
    return 2
  fi
  if ! have "${manager}"; then
    printf 'Error: %s not found on PATH.\n' "${manager}" >&2
    return 2
  fi

  read -r -a packages <<<"$(package_list)"
  filter_available_packages "${manager}" "${packages[@]}"
  printf 'Checked %s packages with %s (%s, %s build target).\n' "${#packages[@]}" "${manager}" "${DISTRO_FAMILY}" "${SESSION_TYPE}"
  if [[ ${#MISSING_PACKAGES[@]} -gt 0 ]]; then
    printf 'Missing from the configured repositories:\n' >&2
    printf '  %s\n' "${MISSING_PACKAGES[@]}" >&2
    return 1
  fi
  printf 'All packages are available.\n'
}

print_header() {
  printf '\n%sKDE Plasma Liquid Glass installer%s\n' "${bold}" "${reset}"
  printf '%s%s%s\n\n' "${dim}" "Fresh KDE to riced setup with dry-run, backups and KDE config writes" "${reset}"
}

print_summary() {
  printf '%-18s %s\n' "Mode:" "${MODE}"
  printf '%-18s %s\n' "Repo:" "${REPO_ROOT}"
  printf '%-18s %s\n' "Distro:" "${DISTRO_NAME} (${DISTRO_FAMILY})"
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

immutable_guidance() {
  printf 'This system is image-based or declarative (%s), so system packages are not installed here.\n' "${IMMUTABLE_REASON}"
  case "${DISTRO_FAMILY}" in
    fedora)
      printf 'Fedora Atomic/Kinoite: build the KWin/Qt components inside a toolbox/distrobox and layer the resulting RPMs,\n'
      printf 'for example: distrobox create --name glass --image registry.fedoraproject.org/fedora-toolbox:latest\n'
      printf 'then run this installer there with --install-packages --user-install, or use the COPR packages\n'
      printf '(infinality/kwin-effects-better-blur-dx, matinlotfali/KDE-Rounded-Corners, deltacopy/darkly) via rpm-ostree.\n'
      ;;
    arch)
      printf 'SteamOS/Arch image: run `sudo steamos-readonly disable` to build into /usr (it resets on updates),\n'
      printf 'or build inside distrobox and use --user-install.\n'
      ;;
    suse)
      printf 'openSUSE Aeon/Kalpa/MicroOS: install build dependencies in a distrobox, or use `transactional-update pkg install` and reboot.\n'
      ;;
    *)
      printf 'Build the KWin/Qt components inside a container (distrobox/toolbox) and use --user-install.\n'
      ;;
  esac
  printf 'Package list for this distro: scripts/install.sh --distro %s --print-packages\n' "${DISTRO_FAMILY}"
}

install_packages() {
  local manager
  local packages=()
  local flags=()
  [[ ${INSTALL_PACKAGES} -eq 1 ]] || return 0

  printf '\n%sSystem packages%s\n' "${bold}" "${reset}"

  if [[ "${DISTRO_FAMILY}" == "nixos" ]]; then
    note "NixOS: skipping imperative package installs; see the NixOS section for a declarative snippet."
    return 0
  fi
  if [[ ${IMMUTABLE} -eq 1 ]]; then
    immutable_guidance
    return 0
  fi
  if ! manager="$(package_manager_for_family)"; then
    note "No automated package install for '${DISTRO_FAMILY}'. Install CMake, Extra CMake Modules, Qt 6, KF6 and KWin development packages manually."
    note "Required: cmake, extra-cmake-modules, Qt6 base/declarative/svg/tools (+private headers), KF6 (ConfigWidgets, KCMUtils, ColorScheme, GuiAddons, I18n, IconThemes, WindowSystem, FrameworkIntegration, Kirigami), KWin + KDecoration3 dev files, libepoxy, libdrm, libxcb."
    return 0
  fi
  if [[ "${MODE}" == "install" ]] && ! have "${manager}"; then
    note "${manager} not found on PATH; skipping package installation."
    return 0
  fi

  read -r -a packages <<<"$(package_list)"

  if [[ "${MODE}" == "install" ]]; then
    case "${manager}" in
      apt-get)
        as_root apt-get update || note "apt-get update failed; continuing with cached package lists."
        ;;
    esac
    case "${manager}" in
      apt-get|pacman)
        filter_available_packages "${manager}" "${packages[@]}"
        if [[ ${#MISSING_PACKAGES[@]} -gt 0 ]]; then
          note "Not available in your configured repositories (skipped): ${MISSING_PACKAGES[*]}"
          note "Plasma 6.5+ packages are required for BreezeEnhanced and Better Blur DX; older distro releases may not provide them."
        fi
        if [[ ${#AVAILABLE_PACKAGES[@]} -eq 0 ]]; then
          note "No installable packages found; skipping."
          return 0
        fi
        packages=("${AVAILABLE_PACKAGES[@]}")
        ;;
    esac
  else
    case "${manager}" in
      apt-get)
        as_root apt-get update
        ;;
    esac
  fi

  case "${manager}" in
    pacman)
      [[ ${ASSUME_YES} -eq 1 ]] && flags+=(--noconfirm)
      as_root pacman -S --needed ${flags[@]+"${flags[@]}"} "${packages[@]}" || note "pacman failed; component builds may fail without these packages."
      ;;
    apt-get)
      [[ ${ASSUME_YES} -eq 1 ]] && flags+=(-y)
      as_root env DEBIAN_FRONTEND=noninteractive apt-get install ${flags[@]+"${flags[@]}"} "${packages[@]}" || note "apt-get failed; component builds may fail without these packages."
      ;;
    dnf)
      [[ ${ASSUME_YES} -eq 1 ]] && flags+=(-y)
      as_root dnf install ${flags[@]+"${flags[@]}"} "${packages[@]}" || note "dnf failed; component builds may fail without these packages."
      ;;
    zypper)
      [[ ${ASSUME_YES} -eq 1 ]] && flags+=(--non-interactive)
      as_root zypper ${flags[@]+"${flags[@]}"} install --no-recommends "${packages[@]}" || note "zypper failed; component builds may fail without these packages."
      ;;
  esac
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

any_submodule_uninitialized() {
  local dir
  for dir in Layan-kde WhiteSur-icon-theme Darkly BreezeEnhanced Better-Blur-DX KDE-Rounded-Corners; do
    if is_uninitialized_submodule "${REPO_ROOT}/${dir}"; then
      return 0
    fi
  done
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
    return 3
  fi
  # Upstream scripts use #!/bin/bash or #!/bin/env; run them through bash so
  # hosts without those paths (NixOS) work too.
  if [[ -f "${dir}/install.sh" ]]; then
    printf '%-18s %s\n' "${name}:" "install.sh"
    run_in_dir_or_print "${dir}" bash ./install.sh "$@"
  elif will_exist_after_submodule_init "${dir}"; then
    printf '%-18s %s\n' "${name}:" "install.sh after submodule init"
    run_in_dir_or_print "${dir}" bash ./install.sh "$@"
  elif is_uninitialized_submodule "${dir}"; then
    printf '%-18s %s\n' "${name}:" "submodule not initialized; pass --init-submodules"
    return 3
  else
    printf '%-18s %s\n' "${name}:" "no install.sh found"
    return 3
  fi
}

# cmake_install_project NAME DIR SLUG [EXTRA_CMAKE_ARGS...]
cmake_install_project() {
  local name="$1"
  local dir="$2"
  local slug="$3"
  shift 3
  local build_dir="${BUILD_ROOT}/${slug}"
  local cmake_args=(-DCMAKE_BUILD_TYPE=Release "-DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}" -DBUILD_TESTING=OFF -Wno-dev)

  if [[ ${SYSTEM_INSTALL} -eq 1 ]]; then
    # Install plugins into Qt's own plugin directory, which differs per distro
    # (lib, lib64, lib/x86_64-linux-gnu) and is where KWin looks for them.
    cmake_args+=(-DKDE_INSTALL_USE_QT_SYS_PATHS=ON)
  fi

  if [[ ! -f "${dir}/CMakeLists.txt" ]]; then
    if will_exist_after_submodule_init "${dir}"; then
      printf '%-18s %s\n' "${name}:" "cmake configure/build/install after submodule init"
      run_or_print cmake -S "${dir}" -B "${build_dir}" "${cmake_args[@]}" "$@"
      run_or_print cmake --build "${build_dir}" --parallel
      if [[ ${SYSTEM_INSTALL} -eq 1 ]]; then
        as_root cmake --install "${build_dir}"
      else
        run_or_print cmake --install "${build_dir}"
      fi
      return 0
    fi
    if is_uninitialized_submodule "${dir}"; then
      printf '%-18s %s\n' "${name}:" "submodule not initialized; pass --init-submodules"
      return 3
    fi
    printf '%-18s %s\n' "${name}:" "no CMakeLists.txt found"
    return 3
  fi

  printf '%-18s %s\n' "${name}:" "cmake configure/build/install"
  if [[ "${MODE}" == "install" ]] && ! have cmake; then
    printf 'Error: cmake not found; rerun with --install-packages or install CMake.\n' >&2
    return 1
  fi

  # Always configure from scratch: KWin effects are tied to the exact KWin
  # version they were built against, and stale caches break rebuilds.
  run_or_print rm -rf "${build_dir}" || return 1
  run_or_print cmake -S "${dir}" -B "${build_dir}" "${cmake_args[@]}" "$@" || return 1
  run_or_print cmake --build "${build_dir}" --parallel || return 1
  if [[ ${SYSTEM_INSTALL} -eq 1 ]]; then
    as_root cmake --install "${build_dir}" || return 1
  else
    run_or_print cmake --install "${build_dir}" || return 1
    if [[ "${MODE}" == "install" ]]; then
      collect_plugin_roots "${build_dir}/install_manifest.txt"
    fi
  fi
}

# Records a component's outcome so later steps (settings) can adapt.
mark_component_unavailable() {
  case "$1" in
    "Darkly") DARKLY_AVAILABLE=0 ;;
    "BreezeEnhanced") BREEZE_ENHANCED_AVAILABLE=0 ;;
    "Better Blur DX") BLUR_DX_AVAILABLE=0 ;;
    "Rounded Corners") ROUNDED_CORNERS_AVAILABLE=0 ;;
  esac
}

run_component() {
  local name="$1"
  shift

  if [[ "${MODE}" == "dry-run" ]]; then
    "$@" || true
    return 0
  fi

  local rc=0
  "$@" || rc=$?
  case ${rc} in
    0)
      INSTALLED_COMPONENTS+=("${name}")
      ;;
    3)
      SKIPPED_COMPONENTS+=("${name} (not available)")
      mark_component_unavailable "${name}"
      ;;
    *)
      FAILED_COMPONENTS+=("${name}")
      mark_component_unavailable "${name}"
      printf 'Warning: %s failed; continuing with the remaining components.\n' "${name}" >&2
      ;;
  esac
}

# component_gate NAME MIN_PLASMA: false (and recorded as skipped) when the
# detected Plasma is older than the component supports.
component_gate() {
  local name="$1"
  local minimum="$2"

  if [[ -n "${PLASMA_VERSION}" ]] && ! version_ge "${PLASMA_VERSION}" "${minimum}"; then
    printf '%-18s %s\n' "${name}:" "skipped; needs Plasma ${minimum}+ (found ${PLASMA_VERSION})"
    SKIPPED_COMPONENTS+=("${name} (needs Plasma ${minimum}+)")
    mark_component_unavailable "${name}"
    return 1
  fi
  return 0
}

collect_plugin_roots() {
  local manifest="$1"
  local roots

  [[ -f "${manifest}" ]] || return 0
  roots="$(awk '{ i = index($0, "/plugins/"); if (i > 0) print substr($0, 1, i + 7) }' "${manifest}" | sort -u)"
  if [[ -n "${roots}" ]]; then
    PLUGIN_ROOTS="${PLUGIN_ROOTS}${PLUGIN_ROOTS:+$'\n'}${roots}"
  fi
}

# User-prefix installs are invisible to KWin/Qt until the plugin directory is on
# QT_PLUGIN_PATH. Plasma sources ~/.config/plasma-workspace/env/*.sh at login.
write_user_plugin_env() {
  local env_dir="${CONFIG_HOME}/plasma-workspace/env"
  local env_file="${env_dir}/liquid-glass.sh"
  local roots path_value="" root

  [[ ${INSTALL_BUILDS} -eq 1 && ${SYSTEM_INSTALL} -eq 0 ]] || return 0
  [[ "${DISTRO_FAMILY}" != "nixos" ]] || return 0

  printf '\n%sUser-prefix plugin environment%s\n' "${bold}" "${reset}"
  if [[ "${MODE}" == "dry-run" ]]; then
    printf 'would write: %s (QT_PLUGIN_PATH for plugins under %s)\n' "${env_file}" "${INSTALL_PREFIX}"
    return 0
  fi

  roots="$(printf '%s\n' "${PLUGIN_ROOTS}" | sort -u | sed '/^$/d')"
  if [[ -z "${roots}" ]]; then
    note "No user-prefix plugins were installed; nothing to export."
    return 0
  fi
  while IFS= read -r root; do
    path_value="${path_value}${path_value:+:}${root}"
  done <<<"${roots}"

  mkdir -p -- "${env_dir}"
  {
    printf '# Generated by the KDE Plasma Liquid Glass installer.\n'
    printf '# Makes plugins installed under %s visible to KWin and Qt.\n' "${INSTALL_PREFIX}"
    printf 'export QT_PLUGIN_PATH="%s${QT_PLUGIN_PATH:+:${QT_PLUGIN_PATH}}"\n' "${path_value}"
    if [[ "${INSTALL_PREFIX}" != "${HOME}/.local" ]]; then
      printf 'export XDG_DATA_DIRS="%s/share${XDG_DATA_DIRS:+:${XDG_DATA_DIRS}}"\n' "${INSTALL_PREFIX}"
    fi
  } >"${env_file}"
  printf 'Wrote %s\n' "${env_file}"
  printf 'Log out and back in so KWin picks up the user-installed effects.\n'
}

# The WhiteSur installer aborts after the first variant when gtk-update-icon-cache
# is missing, so WhiteSur-dark never gets installed. The cache is optional for
# KDE, so provide a no-op stand-in for the duration of the install.
install_whitesur_icons() {
  local shim_dir old_path rc=0

  if [[ "${MODE}" == "install" ]] && ! have gtk-update-icon-cache; then
    note "gtk-update-icon-cache not found; skipping icon cache generation (KDE does not need it)."
    shim_dir="$(mktemp -d)"
    printf '#!/bin/sh\nexit 0\n' >"${shim_dir}/gtk-update-icon-cache"
    chmod +x "${shim_dir}/gtk-update-icon-cache"
    old_path="${PATH}"
    PATH="${shim_dir}:${PATH}"
    run_upstream_installer "WhiteSur icons" "${REPO_ROOT}/WhiteSur-icon-theme" --dest "${DATA_HOME}/icons" --kde-plasma || rc=$?
    PATH="${old_path}"
    rm -rf "${shim_dir}"
    return ${rc}
  fi

  run_upstream_installer "WhiteSur icons" "${REPO_ROOT}/WhiteSur-icon-theme" --dest "${DATA_HOME}/icons" --kde-plasma
}

install_components() {
  [[ ${INSTALL_BUILDS} -eq 1 ]] || return 0

  printf '\n%sComponent installers%s\n' "${bold}" "${reset}"
  run_component "Layan KDE" run_upstream_installer "Layan KDE" "${REPO_ROOT}/Layan-kde"
  run_component "WhiteSur icons" install_whitesur_icons

  if [[ "${DISTRO_FAMILY}" == "nixos" ]]; then
    printf '%-18s %s\n' "KWin/Qt plugins:" "managed by Nix; see the NixOS section below"
    return 0
  fi

  if component_gate "Darkly" 6.3; then
    run_component "Darkly" cmake_install_project "Darkly" "${REPO_ROOT}/Darkly" darkly -DBUILD_QT5=OFF -DBUILD_QT6=ON
  fi
  if component_gate "BreezeEnhanced" 6.5; then
    run_component "BreezeEnhanced" cmake_install_project "BreezeEnhanced" "${REPO_ROOT}/BreezeEnhanced" breezeenhanced
  fi
  if component_gate "Better Blur DX" 6.5; then
    if [[ -n "${PLASMA_VERSION}" ]] && version_ge "${PLASMA_VERSION}" 6.7; then
      note "Better Blur DX officially supports Plasma 6.5-6.6; building against ${PLASMA_VERSION} may fail (the built-in blur is used if it does)."
    fi
    if [[ "${SESSION_TYPE}" == "x11" ]]; then
      run_component "Better Blur DX" cmake_install_project "Better Blur DX" "${REPO_ROOT}/Better-Blur-DX" better-blur-dx -DBETTERBLUR_X11=ON
    else
      run_component "Better Blur DX" cmake_install_project "Better Blur DX" "${REPO_ROOT}/Better-Blur-DX" better-blur-dx
    fi
  fi
  if component_gate "Rounded Corners" 6.0; then
    if [[ "${SESSION_TYPE}" == "x11" ]]; then
      run_component "Rounded Corners" cmake_install_project "Rounded Corners" "${REPO_ROOT}/KDE-Rounded-Corners" rounded-corners -DKWIN_X11=ON
    else
      run_component "Rounded Corners" cmake_install_project "Rounded Corners" "${REPO_ROOT}/KDE-Rounded-Corners" rounded-corners
    fi
  fi

  write_user_plugin_env
}

write_kde_config() {
  local writer="$1"
  shift
  run_or_print "${writer}" "$@"
}

backup_kde_configs() {
  local files=(
    "${CONFIG_HOME}/kdeglobals"
    "${CONFIG_HOME}/plasmarc"
    "${CONFIG_HOME}/kwinrc"
    "${CONFIG_HOME}/kwinrulesrc"
    "${CONFIG_HOME}/plasma-org.kde.plasma.desktop-appletsrc"
    "${CONFIG_HOME}/plasmashellrc"
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
  local decoration="${WINDOW_DECORATION}"
  [[ ${APPLY_SETTINGS} -eq 1 ]] || return 0

  # Fall back gracefully when a component could not be installed on this system.
  if [[ ${DECORATION_EXPLICIT} -eq 0 && ${BREEZE_ENHANCED_AVAILABLE} -eq 0 ]]; then
    if [[ ${DARKLY_AVAILABLE} -eq 1 ]]; then
      decoration="Darkly"
    else
      decoration="Breeze"
    fi
    note "BreezeEnhanced is unavailable; using the ${decoration} window decoration instead."
  fi
  EFFECTIVE_DECORATION="${decoration}"
  if [[ ${BLUR_DX_AVAILABLE} -eq 0 ]]; then
    EFFECTIVE_BLUR_DX="false"
    note "Better Blur DX is unavailable; keeping KWin's built-in blur enabled."
  fi
  if [[ ${ROUNDED_CORNERS_AVAILABLE} -eq 0 ]]; then
    EFFECTIVE_CORNERS="false"
    note "KDE Rounded Corners is unavailable; leaving the effect disabled."
  fi

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
  write_kde_config "${writer}" --file kwinrc --group org.kde.kdecoration2 --key library "$(decoration_library "${decoration}")"
  write_kde_config "${writer}" --file kwinrc --group org.kde.kdecoration2 --key theme "$(decoration_theme "${decoration}")"
  if [[ "${EFFECTIVE_BLUR_DX}" == "true" ]]; then
    write_kde_config "${writer}" --file kwinrc --group Plugins --key blurEnabled false
  else
    write_kde_config "${writer}" --file kwinrc --group Plugins --key blurEnabled true
  fi
  write_kde_config "${writer}" --file kwinrc --group Plugins --key contrastEnabled true
  write_kde_config "${writer}" --file kwinrc --group Plugins --key better_blur_dxEnabled "${EFFECTIVE_BLUR_DX}"
  write_kde_config "${writer}" --file kwinrc --group Plugins --key kwin4_effect_shapecornersEnabled "${EFFECTIVE_CORNERS}"
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
    printf 'would run: qdbus6|gdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript <liquid-glass-layout.js>\n'
    printf 'would create top floating panel with Kickoff, icon tasks, system tray and clock\n'
    return 0
  fi

  if ! dbus_tool_available; then
    note "qdbus/gdbus not found; skipping Plasma panel layout."
    return 0
  fi
  if ! dbus_call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "${script}" >/dev/null; then
    note "Could not reach plasmashell over D-Bus; skipping the panel layout. Re-run with --apply-layout from inside your Plasma session."
    return 0
  fi
  printf 'Applied Liquid Glass Plasma panel layout.\n'
}

install_window_rules() {
  local writer
  local rules_file="${CONFIG_HOME}/kwinrulesrc"
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

# Theme directories for Vesktop/Vencord, including Flatpak installs when present.
discord_theme_targets() {
  local flatpak_app flatpak_config
  printf '%s\n' "${CONFIG_HOME}/vesktop/themes/${DISCORD_THEME_NAME}"
  printf '%s\n' "${CONFIG_HOME}/Vencord/themes/${DISCORD_THEME_NAME}"
  for flatpak_app in dev.vencord.Vesktop com.discordapp.Discord; do
    flatpak_config="${HOME}/.var/app/${flatpak_app}/config"
    if [[ -d "${flatpak_config}" ]]; then
      if [[ "${flatpak_app}" == "dev.vencord.Vesktop" ]]; then
        printf '%s\n' "${flatpak_config}/vesktop/themes/${DISCORD_THEME_NAME}"
      else
        printf '%s\n' "${flatpak_config}/Vencord/themes/${DISCORD_THEME_NAME}"
      fi
    fi
  done
}

install_discord_theme() {
  local target

  [[ ${INSTALL_DISCORD_THEME} -eq 1 ]] || return 0

  printf '\n%sDiscord / Vesktop theme%s\n' "${bold}" "${reset}"
  if [[ ! -f "${DISCORD_THEME_SOURCE}" ]]; then
    note "Discord theme source not found: ${DISCORD_THEME_SOURCE}"
    return 0
  fi

  while IFS= read -r target; do
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
  done < <(discord_theme_targets)
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

# True when two files have identical contents. Minimal containers lack cmp
# (diffutils), so fall back to diff and then to checksums.
files_identical() {
  if have cmp; then
    cmp -s -- "$1" "$2"
  elif have diff; then
    diff -q -- "$1" "$2" >/dev/null 2>&1
  else
    [[ "$(cksum <"$1")" == "$(cksum <"$2")" ]]
  fi
}

verify_file_match() {
  local source="$1"
  local dest="$2"

  if [[ ! -f "${dest}" ]]; then
    printf 'Verification warning: missing installed file %s\n' "${dest}" >&2
    return 1
  fi
  if ! files_identical "${source}" "${dest}"; then
    printf 'Verification warning: installed file differs from source: %s\n' "${dest}" >&2
    return 1
  fi
}

verify_install() {
  local reader failed=0
  local file dest checked=0

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
    while IFS= read -r dest; do
      verify_file_match "${DISCORD_THEME_SOURCE}" "${dest}" || failed=1
    done < <(discord_theme_targets)
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
      verify_value "${reader}" kwinrc Plugins better_blur_dxEnabled "${EFFECTIVE_BLUR_DX}" || failed=1
      verify_value "${reader}" kwinrc Plugins kwin4_effect_shapecornersEnabled "${EFFECTIVE_CORNERS}" || failed=1
      verify_value "${reader}" kwinrc org.kde.kdecoration2 library "$(decoration_library "${EFFECTIVE_DECORATION}")" || failed=1
      verify_value "${reader}" kwinrc Effect-better-blur-dx BlurStrength 20 || failed=1
      verify_value "${reader}" kwinrc Round-Corners Size 14 || failed=1
    fi

    if [[ ${INSTALL_WINDOW_RULES} -eq 1 ]] && ! grep -F "liquid-glass-borderless" "${CONFIG_HOME}/kwinrulesrc" >/dev/null 2>&1; then
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
    run_or_print kbuildsycoca6 || true
  elif have kbuildsycoca5; then
    run_or_print kbuildsycoca5 || true
  else
    note "kbuildsycoca not found; skipping KDE service cache refresh."
  fi

  if [[ "${MODE}" == "install" ]] && ! plasma_session_detected; then
    note "No running Plasma session detected; settings will apply the next time you log in to Plasma."
    return 0
  fi

  if [[ "${MODE}" == "dry-run" ]]; then
    printf 'would run: %s org.kde.KWin /KWin org.kde.KWin.reconfigure\n' "$(qdbus_bin 2>/dev/null || printf 'qdbus6|gdbus')"
  elif dbus_tool_available; then
    dbus_call org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || note "KWin did not answer on D-Bus; log out and back in to load the effects."
  else
    note "qdbus/gdbus not found; skipping KWin reconfigure."
  fi

  if reader="$(kreadconfig_bin)" && [[ "${MODE}" == "install" ]]; then
    "${reader}" --file plasmarc --group Theme --key name >/dev/null 2>&1 || true
  fi

  if have systemctl && { [[ "${MODE}" == "dry-run" ]] || systemctl --user is-active --quiet plasma-plasmashell.service 2>/dev/null; }; then
    run_or_print systemctl --user restart plasma-plasmashell.service || note "Could not restart plasmashell; log out and back in."
  elif have kquitapp6 && { have kstart6 || have kstart; }; then
    run_or_print kquitapp6 plasmashell || true
    run_or_print "$(have kstart6 && printf kstart6 || printf kstart)" plasmashell || true
  elif have kquitapp5 && have kstart5; then
    run_or_print kquitapp5 plasmashell || true
    run_or_print kstart5 plasmashell || true
  else
    note "kquitapp/kstart/systemctl not found; log out and back in to refresh Plasma."
  fi
}

print_component_summary() {
  [[ ${INSTALL_BUILDS} -eq 1 ]] || return 0
  if [[ ${#INSTALLED_COMPONENTS[@]} -eq 0 && ${#SKIPPED_COMPONENTS[@]} -eq 0 && ${#FAILED_COMPONENTS[@]} -eq 0 ]]; then
    return 0
  fi

  printf '\n%sComponent summary%s\n' "${bold}" "${reset}"
  if [[ ${#INSTALLED_COMPONENTS[@]} -gt 0 ]]; then
    printf '%-18s %s\n' "Installed:" "$(IFS=,; printf '%s' "${INSTALLED_COMPONENTS[*]}" | sed 's/,/, /g')"
  fi
  if [[ ${#SKIPPED_COMPONENTS[@]} -gt 0 ]]; then
    printf '%-18s %s\n' "Skipped:" "$(IFS=,; printf '%s' "${SKIPPED_COMPONENTS[*]}" | sed 's/,/, /g')"
  fi
  if [[ ${#FAILED_COMPONENTS[@]} -gt 0 ]]; then
    printf '%-18s %s\n' "Failed:" "$(IFS=,; printf '%s' "${FAILED_COMPONENTS[*]}" | sed 's/,/, /g')"
    printf 'Failed components usually mean missing build dependencies or a Plasma version mismatch.\n'
    printf 'Package list for this system: scripts/install.sh --distro %s --print-packages\n' "${DISTRO_FAMILY}"
  fi
}

print_next_steps() {
  printf '\n%sDone.%s\n' "${bold}" "${reset}"
  if [[ ${INIT_SUBMODULES} -eq 0 ]] && any_submodule_uninitialized; then
    printf 'For a fresh clone, rerun with --init-submodules so upstream components are available.\n'
  fi
  if [[ ${INSTALL_PACKAGES} -eq 0 && ${INSTALL_BUILDS} -eq 1 && "${DISTRO_FAMILY}" != "nixos" && ${IMMUTABLE} -eq 0 ]]; then
    printf 'If component builds fail, rerun with --install-packages or install KDE build dependencies manually.\n'
  fi
  if [[ ${INSTALL_BUILDS} -eq 1 && "${DISTRO_FAMILY}" != "nixos" ]]; then
    printf 'KWin effects only work with the exact KWin version they were built against: rerun this installer after Plasma upgrades.\n'
  fi
}

detect_distro
detect_session_type
detect_plasma_version
detect_root_command
apply_environment_policy

if [[ ${PRINT_PACKAGES} -eq 1 ]]; then
  print_packages
  exit $?
fi

if [[ ${CHECK_PACKAGES} -eq 1 ]]; then
  check_packages
  exit $?
fi

check_run_as_root
print_header
print_summary
print_preview
preflight_checks

if [[ "${MODE}" == "dry-run" ]]; then
  install_packages
  init_submodules
  install_components
  print_nixos_guidance
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
print_component_summary
print_nixos_guidance
print_next_steps

if [[ ${#FAILED_COMPONENTS[@]} -gt 0 ]]; then
  exit 2
fi
