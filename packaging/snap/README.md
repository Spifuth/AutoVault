# Snap Package for AutoVault

## Overview

This directory contains the Snapcraft configuration for building AutoVault as a Snap package.

## Prerequisites

```bash
# Install snapcraft
sudo snap install snapcraft --classic

# Install LXD for building (recommended)
sudo snap install lxd
sudo lxd init --auto
```

## Building

### Local build

```bash
cd packaging/snap
snapcraft --use-lxd
```

### Clean build

```bash
snapcraft clean
snapcraft --use-lxd
```

## Installation

### From local build

```bash
sudo snap install autovault_2.9.0_amd64.snap --classic --dangerous
```

### From Snap Store (when published)

```bash
sudo snap install autovault --classic
```

## Why Classic Confinement?

AutoVault requires classic confinement because:
- It needs full filesystem access to manage Obsidian vaults anywhere on the system
- It may need to execute external tools (git, pandoc, age, etc.)
- It manages SSH keys and remote connections for sync features

## Testing

```bash
# Verify installation
autovault --version

# Run doctor to check dependencies
autovault doctor

# Run demo
autovault demo
```

## Publishing to Snap Store

1. Create a Snap Store account at https://snapcraft.io/
2. Register the snap name:
   ```bash
   snapcraft login
   snapcraft register autovault
   ```
3. Upload the snap:
   ```bash
   snapcraft upload autovault_2.9.0_amd64.snap --release=stable
   ```

## File Structure

After installation, files are located at:
- Binary: `/snap/autovault/current/bin/autovault`
- Libraries: `/snap/autovault/current/lib/autovault/`
- Config templates: `/snap/autovault/current/share/autovault/config/`
- Documentation: `/snap/autovault/current/share/doc/autovault/`
- Completions: `/snap/autovault/current/share/bash-completion/completions/`

## Troubleshooting

### Permission denied errors
Snap uses classic confinement, so it should have full access. If issues persist:
```bash
sudo snap connect autovault:home
sudo snap connect autovault:removable-media
```

### Shell completions not working
Add to your shell config:
```bash
# Bash
source /snap/autovault/current/share/bash-completion/completions/autovault

# Zsh
fpath=(/snap/autovault/current/share/zsh/site-functions $fpath)
```
