# KDE Plasma Liquid Glass Theme 💎

> A glossy KDE Plasma rice inspired by the macOS Tahoe / Liquid Glass look.

[![Validate](https://github.com/david-x3d/kde-plasma-liquid-glass-theme/actions/workflows/validate.yml/badge.svg)](https://github.com/david-x3d/kde-plasma-liquid-glass-theme/actions/workflows/validate.yml)
![KDE Plasma](https://img.shields.io/badge/KDE-Plasma-1d99f3?logo=kde&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-ready-fcc624?logo=linux&logoColor=111)
![Theme](https://img.shields.io/badge/style-liquid%20glass-9bdbff)
![License](https://img.shields.io/badge/license-MIT-blue)

This repo collects the pieces of a full KDE Plasma Liquid Glass setup: transparent Layan files, Darkly, BreezeEnhanced, WhiteSur icons, Better Blur DX, KDE Rounded Corners, screenshots, and a modified Discord/Vesktop theme. It is meant as a practical rice kit, not a one-click distro installer.

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
git submodule update --init --recursive
```

## 💎 Modified Layan Plasma Theme

Install the normal Layan Plasma theme first, then overlay the modified files from this repo:

```bash
mkdir -p ~/.local/share/plasma/desktoptheme/Layan
cp -r themes/modified-layan/* ~/.local/share/plasma/desktoptheme/Layan/
```

After copying, open KDE System Settings and reselect or reload the Plasma theme.

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

For the clean glass look, create a BreezeEnhanced/KWin window rule that matches:

```text
.*
```

Use the rule to remove visible borders. Keep a fallback rule or easy settings access while tuning the setup.

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
git config --file .gitmodules --get-regexp path
```

## ⚠️ Notes

- This repo is a curated setup, not an official KDE, Apple, Layan, Darkly, BreezeEnhanced or WhiteSur project.
- Plasma theme internals can change between KDE versions.
- Keep backups of your current KDE settings before replacing theme files.
- Transparent desktop setups depend heavily on wallpaper contrast, panel opacity and blur configuration.

## 🗺 Roadmap

- Add a scripted installer with a dry-run mode.
- Add rollback instructions for every copied theme file.
- Add a KDE version compatibility matrix.
- Add more desktop and panel screenshots.

## Contributing

Small improvements are welcome. Keep screenshots current, do not vendor large unrelated assets, and document any KDE version assumptions when changing theme files.
