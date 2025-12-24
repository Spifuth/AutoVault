# AutoVault Homebrew Tap

This directory contains the Homebrew formula for macOS/Linux installation.

## Installation

### Quick Install (recommended)

```bash
brew tap Spifuth/autovault
brew install autovault
```

### Direct Install

```bash
brew install Spifuth/autovault/autovault
```

### From HEAD (development)

```bash
brew install --HEAD Spifuth/autovault/autovault
```

## Creating a Tap Repository

To publish this formula, create a new GitHub repository named `homebrew-autovault`:

1. Create repo: `https://github.com/Spifuth/homebrew-autovault`
2. Add the formula:
   ```bash
   mkdir -p Formula
   cp autovault.rb Formula/
   git add Formula/autovault.rb
   git commit -m "Add autovault formula"
   git push
   ```

## Updating the Formula

1. Create a new release on GitHub
2. Download the release tarball
3. Calculate SHA256:
   ```bash
   curl -LO https://github.com/Spifuth/AutoVault/archive/refs/tags/v2.8.0.tar.gz
   shasum -a 256 v2.8.0.tar.gz
   ```
4. Update `url` and `sha256` in the formula
5. Test: `brew install --build-from-source ./autovault.rb`
6. Commit and push to the tap repository

## Testing

```bash
# Audit the formula
brew audit --strict autovault.rb

# Test installation
brew install --build-from-source autovault.rb

# Run tests
brew test autovault
```

## Dependencies

The formula requires:
- bash >= 4.0 (macOS ships with bash 3.x, so we install newer)
- jq
- rsync
