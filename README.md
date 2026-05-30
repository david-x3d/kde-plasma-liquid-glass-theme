# KDE Plasma Liquid Glass Theme 💎

> A glossy KDE Plasma rice inspired by the macOS Tahoe / Liquid Glass look.

[![Validate](https://github.com/david-x3d/kde-plasma-liquid-glass-theme/actions/workflows/validate.yml/badge.svg)](https://github.com/david-x3d/kde-plasma-liquid-glass-theme/actions/workflows/validate.yml)
![KDE Plasma](https://img.shields.io/badge/KDE-Plasma-1d99f3?logo=kde&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-ready-fcc624?logo=linux&logoColor=111)
![Theme](https://img.shields.io/badge/style-liquid%20glass-9bdbff)
![License](https://img.shields.io/badge/license-MIT-blue)

This repo collects the pieces of a full KDE Plasma Liquid Glass setup: transparent Layan files, Darkly, BreezeEnhanced, WhiteSur icons, Better Blur DX, KDE Rounded Corners, screenshots, and a modified Discord/Vesktop theme. The installer is meant to take a fresh KDE user profile as far toward the finished rice as the local distro and available submodules allow.

## 🖼 Preview

<img src="./screenshots/Desktop.png" alt="KDE Plasma Liquid Glass desktop preview" width="100%">

## ⚡ Features

- Liquid Glass inspired KDE Plasma desktop with blur, transparency and rounded window geometry.
- Modified Layan Plasma theme files for a cleaner transparent panel/shell look.
- Better Blur DX guidance for deeper glass blur behind windows.
- BreezeEnhanced setup for borderless decorations.
- WhiteSur icon-theme pairing for a glossy desktop feel.
- Included modified Discord/Vesktop CSS theme.
- Validation workflow for README, screenshots, theme folders and submodule metadata.

## 📦 Components

| Part | Theme / Tool |
| --- | --- |
| Application style | [Darkly](./Darkly) |
| Window decorations | [BreezeEnhanced](./BreezeEnhanced) |
| Icons | [WhiteSur Icon Theme](./WhiteSur-icon-theme) |
| Plasma style | [Layan KDE](./Layan-kde) plus modified files |
| Blur | [Better Blur DX](./Better-Blur-DX) |
| Corners | [KDE Rounded Corners](./KDE-Rounded-Corners) |
| Discord / Vesktop | `themes/discord-theme/modified-midnight.theme.css` |
| Local overrides | `themes/modified-layan/` |

## 🚀 Installation

Clone with submodules:

```bash
git clone --recurse-submodules https://github.com/david-x3d/kde-plasma-liquid-glass-theme.git
cd kde-plasma-liquid-glass-theme
```

If you already cloned without submodules:

```bash
git submodule update --init --recursive --depth 1
```

Preview the full installer:

```bash
scripts/install.sh --dry-run
```

The dry run includes a preflight section that checks the current Plasma session, KDE helper tools, submodule state, package-manager support, install prefix, and wallpaper file before showing planned actions.

For a fresh clone, let the installer initialize submodules, install known KDE build dependencies, build available components, copy the modified Layan files, write KDE settings, enable the blur/corner effects, and reload Plasma:

```bash
scripts/install.sh --full-setup
```

During an interactive install, the script asks whether to install the Discord/Vesktop CSS theme. For a non-interactive run, `--yes` accepts defaults and installs it; use `--skip-discord-theme` to opt out:

```bash
scripts/install.sh --full-setup --yes
```

The installer always copies `themes/modified-layan/` into your local Plasma desktop theme directory, backs up replaced files, and prints the backup location when it changes existing files. Before writing KDE settings it backs up `kdeglobals`, `plasmarc`, `kwinrc`, `kwinrulesrc`, `plasma-org.kde.plasma.desktop-appletsrc`, and `plasmashellrc` when they exist. When component submodules are present, it also runs upstream `install.sh` scripts and CMake installs. Source-built KWin/style components install to `/usr` by default because KWin and Qt style plugins are most reliably discovered from the system KDE prefix; use `--user-install` if you want a best-effort `~/.local` build instead. The KDE settings pass writes `kdeglobals`, `plasmarc`, and `kwinrc` with the Plasma style, app style, icons, KWin decoration hint, Better Blur DX tuning, KDE Rounded Corners tuning, and wallpaper, then verifies key config values with `kreadconfig` when available. In `--full-setup`, it also applies a Plasma shell layout through KDE's Plasma scripting D-Bus API: it replaces current panels with a top floating panel containing Kickoff, icon-only tasks, system tray, and clock. It also copies the included Discord/Vesktop CSS theme into common Vencord/Vesktop theme directories.

If you only want the old overlay behavior:

```bash
scripts/install.sh --install --overlay-only
```

Useful switches:

| Option | Purpose |
| --- | --- |
| `--full-setup` | Enables the complete installer path: install mode, submodule init, package install, builds, settings, panel layout, wallpaper, KWin rule, Discord prompt, and Plasma reload. |
| `--init-submodules` | Runs `git submodule update --init --recursive --depth 1`. |
| `--full-submodule-history` | Uses complete submodule histories instead of shallow submodule checkouts. |
| `--install-packages` | Installs known build/runtime packages on pacman, apt, dnf or zypper systems. |
| `--user-install` | Builds source components into `~/.local` instead of `/usr`. |
| `--install-prefix DIR` | Overrides the CMake install prefix for source components. |
| `--wallpaper PATH` | Applies a custom wallpaper image. |
| `--skip-builds` | Skips upstream installers and CMake builds. |
| `--skip-settings` | Copies files without changing KDE config. |
| `--apply-layout` | Applies the Liquid Glass top-panel layout outside `--full-setup`. |
| `--skip-layout` | Skips the Plasma panel layout. |
| `--skip-discord-theme` | Skips the Discord/Vesktop CSS prompt and theme install. |
| `--skip-window-rules` | Skips the KWin borderless-window rule. |
| `--skip-config-backup` | Skips KDE config backups before settings writes. |
| `--skip-plasma-restart` | Leaves Plasma/KWin running as-is after config writes. |
| `--overlay-only` | Only installs `themes/modified-layan/`. |

## 💎 Modified Layan Plasma Theme

The full installer can install the normal Layan Plasma theme from the submodule before applying the modified files from this repo. If you skip builds or work from a clone without initialized submodules, install Layan first and then apply the overlay.

If you prefer to copy the files manually:

```bash
mkdir -p ~/.local/share/plasma/desktoptheme/Layan
cp -r themes/modified-layan/* ~/.local/share/plasma/desktoptheme/Layan/
```

After copying, the full installer writes the Plasma style setting automatically. If you used `--overlay-only`, open KDE System Settings and reselect or reload the Plasma theme.

## 🧩 Recommended KDE Setup

| Setting | Value |
| --- | --- |
| Session | KWin Wayland |
| Application Style | Darkly |
| Colors | Artim Dark or edited Breeze Dark |
| Window Decorations | BreezeEnhanced |
| Icons | WhiteSur-dark |
| Plasma Style | Modified Layan |
| Effects | Better Blur DX and KDE Rounded Corners |

## 🪟 Borderless Window Rule

The full installer creates a KWin rule named `liquid-glass-borderless` for the clean glass look. It matches:

```text
.*
```

The rule forces no visible borders and preserves any existing KWin rules. Pass `--skip-window-rules` to leave KWin rules untouched.

## 🌫 Better Blur DX

Recommended tweaks:

- Disable shadows if your wallpaper already has strong contrast.
- Increase blur strength until panels feel glassy instead of smoky.
- Darken the glass slightly for readability.
- Use darker wallpapers for better text contrast.
- Avoid pure white backgrounds behind transparent windows.

Settings examples:

<p align="center">
  <img src="./screenshots/BetterBlur-DX-Settings1.png" alt="Better Blur DX settings page 1" width="30%">
  <img src="./screenshots/BetterBlur-DX-Settings2.png" alt="Better Blur DX settings page 2" width="30%">
  <img src="./screenshots/BetterBlur-DX-Settings3.png" alt="Better Blur DX settings page 3" width="30%">
</p>

## 💬 Discord / Vesktop Theme

The included CSS file lives here:

```text
themes/discord-theme/modified-midnight.theme.css
```

Recommended pairing:

- Vesktop or another client with custom CSS support.
- Midnight theme base.
- Background layer removed or disabled.
- Transparent background.
- Better Blur DX handling the blur behind the window.

## 🖼 Wallpaper Tips

This setup works best with:

- Dark city or night skyline wallpapers.
- Blue, purple or cool-toned abstract wallpapers.
- Glassy abstract wallpapers with enough contrast.
- Darker cyberpunk-style scenes.

Bright wallpapers can make translucent UI text harder to read.

## 🗂 Repository Structure

| Path | Purpose |
| --- | --- |
| `screenshots/` | Desktop and settings screenshots |
| `scripts/install.sh` | Dry-run capable full KDE rice installer |
| `themes/modified-layan/` | Local Layan override files |
| `themes/discord-theme/` | Modified Discord/Vesktop CSS |
| `.gitmodules` | Linked upstream theme/tool repositories |
| `.github/workflows/validate.yml` | Cross-platform repository validation |

## 🧪 Validation

GitHub Actions validates the repo on Ubuntu, Windows and macOS for:

- `README.md`
- `LICENSE`
- `.gitmodules`
- `screenshots/`
- `themes/`
- configured submodule paths

You can run the same basic local checks with:

```bash
test -f README.md
test -f LICENSE
test -f .gitmodules
test -d screenshots
test -d themes
test -x scripts/install.sh
test -x scripts/validate-installer.sh
scripts/validate-installer.sh
git config --file .gitmodules --get-regexp path
```

## ⚠️ Notes

- This repo is a curated setup, not an official KDE, Apple, Layan, Darkly, BreezeEnhanced or WhiteSur project.
- Plasma theme internals can change between KDE versions.
- Keep backups of your current KDE settings before replacing theme files.
- Transparent desktop setups depend heavily on wallpaper contrast, panel opacity and blur configuration.

## Contributing

Small improvements are welcome. Keep screenshots current, do not vendor large unrelated assets, and document any KDE version assumptions when changing theme files.
