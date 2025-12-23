#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT - build-packages.sh
#
#===============================================================================
#
#  DESCRIPTION:    Build DEB and RPM packages for AutoVault
#
#  USAGE:          ./packaging/build-packages.sh [deb|rpm|all]
#
#  REQUIREMENTS:   
#                  DEB: dpkg-deb, fakeroot
#                  RPM: rpmbuild, rpm
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/dist"
VERSION="${VERSION:-2.5.0}"
RELEASE="${RELEASE:-1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

#######################################
# Check dependencies
#######################################
check_deb_deps() {
    local missing=()
    command -v dpkg-deb >/dev/null 2>&1 || missing+=("dpkg-deb")
    command -v fakeroot >/dev/null 2>&1 || missing+=("fakeroot")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing DEB build dependencies: ${missing[*]}"
        log_info "Install with: sudo apt install dpkg-dev fakeroot"
        return 1
    fi
    return 0
}

check_rpm_deps() {
    local missing=()
    command -v rpmbuild >/dev/null 2>&1 || missing+=("rpmbuild")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing RPM build dependencies: ${missing[*]}"
        log_info "Install with: sudo dnf install rpm-build (Fedora) or sudo apt install rpm (Debian)"
        return 1
    fi
    return 0
}

#######################################
# Build DEB package
#######################################
build_deb() {
    log_info "Building DEB package..."
    
    if ! check_deb_deps; then
        return 1
    fi
    
    local pkg_name="autovault"
    local pkg_dir="$BUILD_DIR/deb/${pkg_name}_${VERSION}-${RELEASE}_all"
    
    # Clean and create build directory
    rm -rf "$BUILD_DIR/deb"
    mkdir -p "$pkg_dir/DEBIAN"
    mkdir -p "$pkg_dir/usr/share/autovault/bash/lib"
    mkdir -p "$pkg_dir/usr/share/autovault/config"
    mkdir -p "$pkg_dir/usr/share/autovault/hooks"
    mkdir -p "$pkg_dir/usr/share/autovault/docs"
    mkdir -p "$pkg_dir/usr/bin"
    mkdir -p "$pkg_dir/usr/share/bash-completion/completions"
    mkdir -p "$pkg_dir/usr/share/zsh/vendor-completions"
    mkdir -p "$pkg_dir/usr/share/doc/autovault"
    
    # Create control file
    cat > "$pkg_dir/DEBIAN/control" << EOF
Package: autovault
Version: ${VERSION}-${RELEASE}
Section: utils
Priority: optional
Architecture: all
Depends: bash (>= 4.0), jq, coreutils
Recommends: git, pandoc, age
Suggests: wkhtmltopdf, gnupg
Maintainer: Spifuth <spifuth@protonmail.com>
Homepage: https://github.com/Spifuth/AutoVault
Description: CLI tool for managing Obsidian vaults
 AutoVault is a powerful command-line tool for managing Obsidian vaults
 with support for multi-customer folder structures, templates, backups,
 encryption, and export to PDF/HTML.
 .
 Features:
  - Multi-customer vault organization
  - Template management and synchronization
  - Backup creation and restoration
  - Export to PDF, HTML, and Markdown
  - Remote vault synchronization via SSH
  - Age/GPG encryption support
EOF
    
    # Create postinst script
    cat > "$pkg_dir/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

# Create config directory for user
if [[ -n "${SUDO_USER:-}" ]]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    if [[ -d "$USER_HOME" ]]; then
        mkdir -p "$USER_HOME/.config/autovault"
        chown "$SUDO_USER:$SUDO_USER" "$USER_HOME/.config/autovault"
    fi
fi

echo "AutoVault installed successfully!"
echo "Run 'autovault --help' to get started."
EOF
    chmod 755 "$pkg_dir/DEBIAN/postinst"
    
    # Copy files
    cp "$PROJECT_ROOT/cust-run-config.sh" "$pkg_dir/usr/share/autovault/"
    chmod 755 "$pkg_dir/usr/share/autovault/cust-run-config.sh"
    
    cp "$PROJECT_ROOT/bash/"*.sh "$pkg_dir/usr/share/autovault/bash/"
    chmod 755 "$pkg_dir/usr/share/autovault/bash/"*.sh
    
    cp "$PROJECT_ROOT/bash/lib/"*.sh "$pkg_dir/usr/share/autovault/bash/lib/"
    
    cp "$PROJECT_ROOT/config/"*.json "$pkg_dir/usr/share/autovault/config/"
    
    # Copy hooks if they exist
    if ls "$PROJECT_ROOT/hooks/"*.example >/dev/null 2>&1; then
        cp "$PROJECT_ROOT/hooks/"*.example "$pkg_dir/usr/share/autovault/hooks/"
    fi
    [[ -f "$PROJECT_ROOT/hooks/README.md" ]] && cp "$PROJECT_ROOT/hooks/README.md" "$pkg_dir/usr/share/autovault/hooks/"
    
    # Copy docs
    cp "$PROJECT_ROOT/docs/"*.md "$pkg_dir/usr/share/autovault/docs/"
    cp "$PROJECT_ROOT/README.md" "$pkg_dir/usr/share/doc/autovault/"
    cp "$PROJECT_ROOT/CHANGELOG.md" "$pkg_dir/usr/share/doc/autovault/"
    
    # Copy completions
    cp "$PROJECT_ROOT/completions/autovault.bash" "$pkg_dir/usr/share/bash-completion/completions/autovault"
    cp "$PROJECT_ROOT/completions/_autovault" "$pkg_dir/usr/share/zsh/vendor-completions/"
    
    # Create symlink
    ln -sf /usr/share/autovault/cust-run-config.sh "$pkg_dir/usr/bin/autovault"
    
    # Build package
    fakeroot dpkg-deb --build "$pkg_dir"
    
    # Move to dist root
    mv "$BUILD_DIR/deb/${pkg_name}_${VERSION}-${RELEASE}_all.deb" "$BUILD_DIR/"
    
    local pkg_file="$BUILD_DIR/${pkg_name}_${VERSION}-${RELEASE}_all.deb"
    log_success "DEB package built: $pkg_file"
    
    # Show package info
    dpkg-deb --info "$pkg_file"
}

#######################################
# Build RPM package
#######################################
build_rpm() {
    log_info "Building RPM package..."
    
    if ! check_rpm_deps; then
        return 1
    fi
    
    local pkg_name="autovault"
    local rpmbuild_dir="$BUILD_DIR/rpmbuild"
    
    # Clean and create build directories
    rm -rf "$rpmbuild_dir"
    mkdir -p "$rpmbuild_dir"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    
    # Create source tarball
    local tarball_name="${pkg_name}-${VERSION}"
    local tarball_dir="$BUILD_DIR/$tarball_name"
    
    rm -rf "$tarball_dir"
    mkdir -p "$tarball_dir"
    
    # Copy source files
    cp "$PROJECT_ROOT/cust-run-config.sh" "$tarball_dir/"
    cp -r "$PROJECT_ROOT/bash" "$tarball_dir/"
    cp -r "$PROJECT_ROOT/config" "$tarball_dir/"
    cp -r "$PROJECT_ROOT/completions" "$tarball_dir/"
    cp -r "$PROJECT_ROOT/docs" "$tarball_dir/"
    cp -r "$PROJECT_ROOT/hooks" "$tarball_dir/"
    cp -r "$PROJECT_ROOT/packaging" "$tarball_dir/"
    cp "$PROJECT_ROOT/README.md" "$tarball_dir/"
    cp "$PROJECT_ROOT/CHANGELOG.md" "$tarball_dir/"
    
    # Create tarball
    (cd "$BUILD_DIR" && tar czf "$rpmbuild_dir/SOURCES/${tarball_name}.tar.gz" "$tarball_name")
    rm -rf "$tarball_dir"
    
    # Copy spec file
    cp "$PROJECT_ROOT/packaging/rpm/autovault.spec" "$rpmbuild_dir/SPECS/"
    
    # Update version in spec
    sed -i "s/^Version:.*/Version:        ${VERSION}/" "$rpmbuild_dir/SPECS/autovault.spec"
    sed -i "s/^Release:.*/Release:        ${RELEASE}%{?dist}/" "$rpmbuild_dir/SPECS/autovault.spec"
    
    # Build RPM
    rpmbuild --define "_topdir $rpmbuild_dir" -bb "$rpmbuild_dir/SPECS/autovault.spec"
    
    # Move to dist root
    find "$rpmbuild_dir/RPMS" -name "*.rpm" -exec mv {} "$BUILD_DIR/" \;
    
    local rpm_file
    rpm_file=$(find "$BUILD_DIR" -maxdepth 1 -name "autovault-*.rpm" | head -1)
    
    if [[ -n "$rpm_file" ]]; then
        log_success "RPM package built: $rpm_file"
        rpm -qip "$rpm_file"
    else
        log_error "RPM package not found"
        return 1
    fi
}

#######################################
# Build all packages
#######################################
build_all() {
    log_info "Building all packages..."
    
    mkdir -p "$BUILD_DIR"
    
    local failed=0
    
    if check_deb_deps 2>/dev/null; then
        build_deb || failed=$((failed + 1))
    else
        log_warn "Skipping DEB build (missing dependencies)"
    fi
    
    if check_rpm_deps 2>/dev/null; then
        build_rpm || failed=$((failed + 1))
    else
        log_warn "Skipping RPM build (missing dependencies)"
    fi
    
    echo ""
    log_info "Build complete!"
    echo ""
    echo "Packages in $BUILD_DIR:"
    ls -lh "$BUILD_DIR"/*.{deb,rpm} 2>/dev/null || echo "No packages built"
    
    return $failed
}

#######################################
# Show usage
#######################################
usage() {
    cat << EOF
${CYAN}AUTOVAULT - Package Builder${NC}

${YELLOW}USAGE${NC}
    $0 [command]

${YELLOW}COMMANDS${NC}
    deb         Build DEB package only
    rpm         Build RPM package only
    all         Build all packages (default)
    clean       Remove build artifacts
    help        Show this help

${YELLOW}ENVIRONMENT${NC}
    VERSION     Package version (default: 2.5.0)
    RELEASE     Package release (default: 1)

${YELLOW}EXAMPLES${NC}
    $0                      # Build all packages
    $0 deb                  # Build DEB only
    VERSION=3.0.0 $0 all    # Build with custom version

${YELLOW}REQUIREMENTS${NC}
    DEB: dpkg-deb, fakeroot (apt install dpkg-dev fakeroot)
    RPM: rpmbuild (dnf install rpm-build / apt install rpm)

EOF
}

#######################################
# Clean build artifacts
#######################################
clean() {
    log_info "Cleaning build artifacts..."
    rm -rf "$BUILD_DIR"
    log_success "Clean complete"
}

#######################################
# Main
#######################################
main() {
    cd "$PROJECT_ROOT"
    
    case "${1:-all}" in
        deb)
            mkdir -p "$BUILD_DIR"
            build_deb
            ;;
        rpm)
            mkdir -p "$BUILD_DIR"
            build_rpm
            ;;
        all)
            build_all
            ;;
        clean)
            clean
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
