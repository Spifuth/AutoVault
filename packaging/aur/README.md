# AutoVault AUR Package

This directory contains the PKGBUILD for Arch Linux (AUR) distribution.

## Installation from AUR

Once published to AUR, install with:

```bash
# Using yay
yay -S autovault

# Using paru
paru -S autovault

# Manual
git clone https://aur.archlinux.org/autovault.git
cd autovault
makepkg -si
```

## Building Locally

```bash
# Clone this repo
git clone https://github.com/Spifuth/AutoVault.git
cd AutoVault/packaging/aur

# Build package
makepkg -s

# Install
sudo pacman -U autovault-*.pkg.tar.zst
```

## Maintainer Notes

### Updating the package

1. Update `pkgver` in PKGBUILD
2. Update `sha256sums` (or use `SKIP` for development)
3. Test build: `makepkg -sf`
4. Update `.SRCINFO`: `makepkg --printsrcinfo > .SRCINFO`
5. Commit and push to AUR

### Generating checksums

```bash
# Download release
curl -LO https://github.com/Spifuth/AutoVault/archive/refs/tags/v2.9.0.tar.gz

# Generate SHA256
sha256sum v2.9.0.tar.gz
```

## Dependencies

- **Required**: bash>=4.0, jq, rsync
- **Optional**: fzf, age, gnupg, git, openssh
