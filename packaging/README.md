# Packaging

This directory contains packaging configurations for various platforms.

## Available Packages

| Platform | Location | Status |
|----------|----------|--------|
| **Universal Installer** | `../install.sh` | ✅ Ready |
| **Homebrew** (macOS/Linux) | `homebrew/` | ✅ Ready |
| **AUR** (Arch Linux) | `aur/` | ✅ Ready |
| **DEB** (Debian/Ubuntu) | `debian/` | ✅ Ready |
| **RPM** (Fedora/RHEL) | `rpm/` | ✅ Ready |
| **Snap** (Ubuntu/Linux) | `snap/` | ✅ Ready |
| **Flatpak** (Universal Linux) | `flatpak/` | ✅ Ready |

## Quick Install Methods

### Universal (all platforms)

```bash
# Install to /usr/local (requires sudo)
curl -fsSL https://raw.githubusercontent.com/Spifuth/AutoVault/main/install.sh | bash

# Install to ~/.local (no sudo)
curl -fsSL https://raw.githubusercontent.com/Spifuth/AutoVault/main/install.sh | bash -s -- --user

# Specific version
curl -fsSL https://raw.githubusercontent.com/Spifuth/AutoVault/main/install.sh | bash -s -- --version v2.4.0
```

### Homebrew (macOS/Linux)

```bash
brew tap Spifuth/autovault
brew install autovault
```

### Arch Linux (AUR)

```bash
yay -S autovault
# or
paru -S autovault
```

### Manual Installation

```bash
git clone https://github.com/Spifuth/AutoVault.git
cd AutoVault
sudo ./install.sh
```

### Snap (Ubuntu/Linux)

```bash
# From Snap Store (when published)
sudo snap install autovault --classic

# From local build
cd packaging/snap
snapcraft --use-lxd
sudo snap install autovault_*.snap --classic --dangerous
```

### Flatpak (Universal Linux)

```bash
# From Flathub (when published)
flatpak install flathub io.github.spifuth.AutoVault

# From local build
cd packaging/flatpak
flatpak-builder --user --install --force-clean build-dir io.github.spifuth.AutoVault.yml
```

## Uninstallation

```bash
# If installed via install.sh
curl -fsSL https://raw.githubusercontent.com/Spifuth/AutoVault/main/install.sh | bash -s -- --uninstall

# Homebrew
brew uninstall autovault
brew untap Spifuth/autovault

# AUR
sudo pacman -R autovault

# Snap
sudo snap remove autovault

# Flatpak
flatpak uninstall io.github.spifuth.AutoVault
```

## Creating New Releases

1. Update version in `cust-run-config.sh`
2. Update `CHANGELOG.md`
3. Create git tag: `git tag -a v2.x.0 -m "Release v2.x.0"`
4. Push tag: `git push origin v2.x.0`
5. GitHub Actions will automatically:
   - Run tests
   - Create release with assets
   - Generate checksums

6. Update package files:
   - Homebrew: Update `sha256` in `autovault.rb`
   - AUR: Update `pkgver` and checksums in `PKGBUILD`
   - Snap: Update `version` in `snapcraft.yaml`
   - Flatpak: Update `tag` in manifest and `metainfo.xml`
   - AUR: Update `pkgver` and checksums in `PKGBUILD`
