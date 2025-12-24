# Flatpak Package for AutoVault

## Overview

This directory contains the Flatpak manifest for building AutoVault as a Flatpak package.

## Prerequisites

```bash
# Install flatpak and flatpak-builder
# Debian/Ubuntu
sudo apt install flatpak flatpak-builder

# Fedora
sudo dnf install flatpak flatpak-builder

# Arch
sudo pacman -S flatpak flatpak-builder

# Add Flathub repository
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install required runtime and SDK
flatpak install flathub org.freedesktop.Platform//23.08 org.freedesktop.Sdk//23.08
```

## Building

### Local build

```bash
cd packaging/flatpak

# Build and install locally
flatpak-builder --user --install --force-clean build-dir io.github.spifuth.AutoVault.yml
```

### Export to repository

```bash
# Build to a repository
flatpak-builder --repo=repo --force-clean build-dir io.github.spifuth.AutoVault.yml

# Create a single-file bundle
flatpak build-bundle repo autovault.flatpak io.github.spifuth.AutoVault
```

## Installation

### From local bundle

```bash
flatpak install autovault.flatpak
```

### From Flathub (when published)

```bash
flatpak install flathub io.github.spifuth.AutoVault
```

## Running

```bash
# Run via flatpak
flatpak run io.github.spifuth.AutoVault --version

# Or use the command directly (if exported to PATH)
autovault --version
```

## Permissions

The Flatpak has the following permissions:
- `--filesystem=home` - Access to home directory for vault management
- `--filesystem=/media` - Access to external media
- `--filesystem=/mnt` - Access to mounted filesystems
- `--share=network` - Network access for git sync
- `--socket=ssh-auth` - SSH agent for remote operations
- `--talk-name=org.freedesktop.Notifications` - Desktop notifications

## File Structure

After installation:
- Binary: `/app/bin/autovault`
- Libraries: `/app/lib/autovault/`
- Config templates: `/app/share/autovault/config/`
- Documentation: `/app/share/doc/autovault/`
- Completions: `/app/share/bash-completion/completions/`

## Publishing to Flathub

1. Fork the Flathub repository
2. Create a new branch for your app
3. Add your manifest and required files
4. Submit a pull request
5. Follow the review process

See: https://github.com/flathub/flathub/blob/master/CONTRIBUTING.md

## Troubleshooting

### Filesystem access issues

If you need to access directories outside the sandbox:
```bash
flatpak override --user --filesystem=/path/to/vault io.github.spifuth.AutoVault
```

### Shell completions

Add to your shell config:
```bash
# Bash
source /var/lib/flatpak/exports/share/bash-completion/completions/autovault 2>/dev/null || \
source ~/.local/share/flatpak/exports/share/bash-completion/completions/autovault 2>/dev/null

# Zsh
fpath=(/var/lib/flatpak/exports/share/zsh/site-functions $fpath)
```

### SSH key access

Ensure your SSH agent is running:
```bash
eval $(ssh-agent)
ssh-add ~/.ssh/id_rsa
```

The flatpak connects to your SSH agent via `--socket=ssh-auth`.
