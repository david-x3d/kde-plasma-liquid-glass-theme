#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

assert_contains() {
  local file="$1"
  local needle="$2"

  if ! grep -F -- "${needle}" "${file}" >/dev/null; then
    printf 'Expected dry-run output to contain:\n  %s\n' "${needle}" >&2
    printf '\nActual output:\n' >&2
    sed -n '1,220p' "${file}" >&2
    exit 1
  fi
}

assert_contains_any() {
  local file="$1"
  shift
  local needle

  for needle in "$@"; do
    if grep -F -- "${needle}" "${file}" >/dev/null; then
      return 0
    fi
  done

  printf 'Expected output to contain one of:\n' >&2
  for needle in "$@"; do
    printf '  %s\n' "${needle}" >&2
  done
  printf '\nActual output:\n' >&2
  sed -n '1,220p' "${file}" >&2
  exit 1
}

full_output="$(mktemp)"
full_setup_output="$(mktemp)"
overlay_output="$(mktemp)"
install_output="$(mktemp)"
tmp_home="$(mktemp -d)"
tmp_target="$(mktemp -d)"
tmp_backup="$(mktemp -d)"
trap 'rm -f "${full_output}" "${full_setup_output}" "${overlay_output}" "${install_output}"; rm -rf "${tmp_home}" "${tmp_target}" "${tmp_backup}"' EXIT

bash -n "${REPO_ROOT}/scripts/install.sh"
if command -v node >/dev/null 2>&1; then
  awk '/^plasma_layout_script\(\)/{infunc=1} infunc && /^EOF$/{exit} infunc && start{print} infunc && /cat <<'\''EOF'\''/{start=1}' "${REPO_ROOT}/scripts/install.sh" | node --check >/dev/null
fi

while IFS= read -r path; do
  name="$(git -C "${REPO_ROOT}" config --file .gitmodules --get-regexp "submodule\\..*\\.path" | awk -v target="${path}" '$2 == target {print $1}' | sed 's/\.path$/.shallow/')"
  [[ -n "${name}" ]] || {
    printf 'No .gitmodules submodule name found for path %s\n' "${path}" >&2
    exit 1
  }
  shallow="$(git -C "${REPO_ROOT}" config --file .gitmodules --get "${name}")"
  [[ "${shallow}" == "true" ]] || {
    printf 'Expected .gitmodules %s to be true, got %s\n' "${name}" "${shallow}" >&2
    exit 1
  }
done < <(git -C "${REPO_ROOT}" config --file .gitmodules --get-regexp "submodule\\..*\\.path" | awk '{print $2}')

"${REPO_ROOT}/scripts/install.sh" --dry-run --full-setup --yes --skip-plasma-restart >"${full_setup_output}"
assert_contains "${full_setup_output}" "Mode:              dry-run"
assert_contains "${full_setup_output}" "Init submodules:   1"
assert_contains "${full_setup_output}" "Submodule depth:   1"
assert_contains "${full_setup_output}" "Install packages:  1"
assert_contains "${full_setup_output}" "Build/install:     1"
assert_contains "${full_setup_output}" "Apply settings:    1"
assert_contains "${full_setup_output}" "Apply layout:      1"
assert_contains "${full_setup_output}" "Discord theme:     1"
assert_contains "${full_setup_output}" "Window rules:      1"
assert_contains "${full_setup_output}" "Plasma layout"
assert_contains "${full_setup_output}" "would create top floating panel with Kickoff, icon tasks, system tray and clock"

"${REPO_ROOT}/scripts/install.sh" --full-setup --yes --skip-plasma-restart --dry-run >"${full_setup_output}"
assert_contains "${full_setup_output}" "Mode:              dry-run"
assert_contains "${full_setup_output}" "Apply layout:      1"

"${REPO_ROOT}/scripts/install.sh" --dry-run --init-submodules --install-packages >"${full_output}"
assert_contains "${full_output}" "Install prefix:    /usr"
assert_contains "${full_output}" "Install packages:  1"
assert_contains "${full_output}" "System packages"
assert_contains "${full_output}" "Preflight"
assert_contains_any "${full_output}" "will initialize before component install" "Submodules:        available"
assert_contains "${full_output}" "Package manager:"
assert_contains "${full_output}" "would run: git -C ${REPO_ROOT} submodule update --init --recursive --depth 1"
assert_contains_any "${full_output}" "install.sh after submodule init" "Layan KDE:         install.sh"
assert_contains_any "${full_output}" "cmake configure/build/install after submodule init" "Darkly:            cmake configure/build/install"
assert_contains "${full_output}" "would run: cmake -S ${REPO_ROOT}/Darkly"
assert_contains "${full_output}" "-DBUILD_QT5=OFF -DBUILD_QT6=ON"
assert_contains "${full_output}" "KDE config backup"
assert_contains "${full_output}" "would run: kwriteconfig"
assert_contains "${full_output}" "--group Plugins --key better_blur_dxEnabled true"
assert_contains "${full_output}" "--group Plugins --key kwin4_effect_shapecornersEnabled true"
assert_contains "${full_output}" "--group Effect-better-blur-dx --key BlurStrength 20"
assert_contains "${full_output}" "--group Round-Corners --key Size 14"
assert_contains "${full_output}" "Apply layout:      0"
assert_contains "${full_output}" "would run: plasma-apply-lookandfeel --apply com.github.vinceliuice.Layan"
assert_contains "${full_output}" "--file kwinrulesrc --group General --key count"
assert_contains "${full_output}" "--file kwinrulesrc --group General --key rules"
assert_contains "${full_output}" "liquid-glass-borderless"
assert_contains "${full_output}" "--file kwinrulesrc --group liquid-glass-borderless --key noborder true"
assert_contains "${full_output}" "would run: plasma-apply-wallpaperimage ${REPO_ROOT}/screenshots/Desktop.png"
assert_contains "${full_output}" "would copy: ${REPO_ROOT}/themes/discord-theme/modified-midnight.theme.css ->"
assert_contains "${full_output}" "would verify KDE config values and installed optional theme files"
assert_contains "${full_output}" "Discord theme:     1"

# Distro detection, package tables and special cases, driven by fake os-release files.
distro_dir="$(mktemp -d)"
trap 'rm -f "${full_output}" "${full_setup_output}" "${overlay_output}" "${install_output}"; rm -rf "${tmp_home}" "${tmp_target}" "${tmp_backup}" "${distro_dir}"' EXIT

write_os_release() {
  printf '%s\n' "$2" >"${distro_dir}/$1"
}
write_os_release arch 'ID=cachyos
ID_LIKE=arch
PRETTY_NAME="CachyOS"'
write_os_release debian 'ID=neon
ID_LIKE="ubuntu debian"
PRETTY_NAME="KDE neon"'
write_os_release fedora 'ID=nobara
ID_LIKE="rhel centos fedora"
PRETTY_NAME="Nobara"'
write_os_release kinoite 'ID=fedora
VARIANT_ID=kinoite
PRETTY_NAME="Fedora Kinoite"'
write_os_release suse 'ID="opensuse-tumbleweed"
ID_LIKE="opensuse suse"
PRETTY_NAME="openSUSE Tumbleweed"'
write_os_release nixos 'ID=nixos
PRETTY_NAME="NixOS"'
write_os_release alpine 'ID=alpine
PRETTY_NAME="Alpine Linux"'

distro_dry_run() {
  LIQUID_GLASS_OS_RELEASE="${distro_dir}/$1" "${REPO_ROOT}/scripts/install.sh" --dry-run --full-setup --yes --skip-plasma-restart --skip-discord-theme
}

distro_dry_run arch >"${full_output}"
assert_contains "${full_output}" "Distro:            CachyOS (family: arch)"
assert_contains "${full_output}" "Package manager:   supported (pacman)"
assert_contains "${full_output}" "would run: pacman -S --needed --noconfirm base-devel git cmake"

distro_dry_run debian >"${full_output}"
assert_contains "${full_output}" "Package manager:   supported (apt-get)"
assert_contains "${full_output}" "would run: apt-get update"
assert_contains "${full_output}" "apt-get install -y git cmake extra-cmake-modules build-essential"
assert_contains "${full_output}" "libkirigami-dev"

distro_dry_run fedora >"${full_output}"
assert_contains "${full_output}" "Package manager:   supported (dnf)"
assert_contains "${full_output}" "would run: dnf install -y git cmake extra-cmake-modules gcc-c++"
assert_contains "${full_output}" "kf6-kirigami-devel"

distro_dry_run suse >"${full_output}"
assert_contains "${full_output}" "Package manager:   supported (zypper)"
assert_contains "${full_output}" "would run: zypper --non-interactive install --no-recommends git"
assert_contains "${full_output}" "kwin6-devel"

distro_dry_run kinoite >"${full_output}"
assert_contains "${full_output}" "System image:      immutable/declarative"
assert_contains "${full_output}" "Install prefix:    ${HOME}/.local"
assert_contains "${full_output}" "toolbox/distrobox"
assert_contains "${full_output}" "plasma-workspace/env/liquid-glass.sh"

distro_dry_run nixos >"${full_output}"
assert_contains "${full_output}" "Distro:            NixOS (family: nixos)"
assert_contains "${full_output}" "disabled on NixOS"
assert_contains "${full_output}" "kde-rounded-corners"
assert_contains "${full_output}" "kwin-effects-better-blur-dx"
assert_contains "${full_output}" "--key library org.kde.darkly"
if grep -F -- "cmake -S" "${full_output}" >/dev/null; then
  printf 'NixOS dry-run must not plan cmake builds\n' >&2
  exit 1
fi

distro_dry_run alpine >"${full_output}"
assert_contains "${full_output}" "Package manager:   unsupported"

"${REPO_ROOT}/scripts/install.sh" --distro fedora --x11 --print-packages >"${full_output}"
assert_contains "${full_output}" "kwin-x11-devel"
"${REPO_ROOT}/scripts/install.sh" --distro debian --print-packages >"${full_output}"
assert_contains "${full_output}" "kwin-dev"

"${REPO_ROOT}/scripts/install.sh" --dry-run --distro arch --skip-settings --skip-discord-theme --skip-builds >"${full_output}"
assert_contains "${full_output}" "Build/install:     0"

if "${REPO_ROOT}/scripts/install.sh" --distro alpine --check-packages >/dev/null 2>&1; then
  printf 'Expected --check-packages to fail without a supported package manager\n' >&2
  exit 1
fi

if "${REPO_ROOT}/scripts/install.sh" --dry-run --distro nonsense >/dev/null 2>&1; then
  printf 'Expected --distro nonsense to fail\n' >&2
  exit 1
fi

"${REPO_ROOT}/scripts/install.sh" --dry-run --overlay-only >"${overlay_output}"
assert_contains "${overlay_output}" "Build/install:     0"
assert_contains "${overlay_output}" "Apply settings:    0"
assert_contains "${overlay_output}" "Apply layout:      0"
assert_contains "${overlay_output}" "Config backup:     0"
assert_contains "${overlay_output}" "Discord theme:     0"
assert_contains "${overlay_output}" "Window rules:      0"
assert_contains "${overlay_output}" "Restart Plasma:    0"

HOME="${tmp_home}" XDG_CONFIG_HOME="${tmp_home}/.config" XDG_DATA_HOME="${tmp_home}/.local/share" "${REPO_ROOT}/scripts/install.sh" \
  --install \
  --yes \
  --skip-builds \
  --skip-settings \
  --skip-plasma-restart \
  --target-root "${tmp_target}" \
  --backup-root "${tmp_backup}" >"${install_output}"
assert_contains "${install_output}" "Installed 123 modified Layan files."
assert_contains "${install_output}" "Verified 123 modified Layan files."
assert_contains "${install_output}" "Verified Discord/Vesktop theme files."
assert_contains "${install_output}" "Install verification passed."
test -f "${tmp_target}/Layan/colors"
test -f "${tmp_home}/.config/vesktop/themes/liquid-glass-midnight.theme.css"
test -f "${tmp_home}/.config/Vencord/themes/liquid-glass-midnight.theme.css"

printf 'Installer validation passed.\n'
