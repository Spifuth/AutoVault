# Packaging

This directory contains packaging configurations for various platforms.

## Available Packages

| Platform | Location | Status |
|----------|----------|--------|
| **Universal Installer** | `../install.sh` | ✅ Ready |
| **Homebrew** (macOS/Linux) | `homebrew/` | ✅ Ready |
| **AUR** (Arch Linux) | `aur/` | ✅ Ready |
| **DEB** (Debian/Ubuntu) | `deb/` | 🔄 Planned |
| **RPM** (Fedora/RHEL) | `rpm/` | 🔄 Planned |

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

## Uninstallation

```bash
# If installed via install.sh
curl -fsSL https://raw.githubusercontent.com/Spifuth/AutoVault/main/install.sh | bash -s -- --uninstall

# Homebrew
brew uninstall autovault
brew untap Spifuth/autovault

# AUR
sudo pacman -R autovault
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
