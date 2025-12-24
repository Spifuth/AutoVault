Name:           autovault
Version:        2.9.0
Release:        1%{?dist}
Summary:        CLI tool for managing Obsidian vaults

License:        MIT
URL:            https://github.com/Spifuth/AutoVault
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  bash

Requires:       bash >= 4.0
Requires:       jq
Requires:       coreutils
Recommends:     git
Recommends:     pandoc
Recommends:     age
Suggests:       wkhtmltopdf
Suggests:       gnupg2

%description
AutoVault is a powerful command-line tool for managing Obsidian vaults
with support for multi-customer folder structures, templates, backups,
encryption, and export to PDF/HTML.

Features:
- Multi-customer vault organization
- Template management and synchronization
- Backup creation and restoration
- Export to PDF, HTML, and Markdown
- Remote vault synchronization via SSH
- Age/GPG encryption support
- Bash and Zsh completions

%prep
%autosetup

%build
# Nothing to build for shell scripts

%check
# Syntax check all shell scripts
bash -n cust-run-config.sh
for f in bash/*.sh; do bash -n "$f"; done
for f in bash/lib/*.sh; do bash -n "$f"; done

%install
# Create directories
install -d %{buildroot}%{_datadir}/%{name}
install -d %{buildroot}%{_datadir}/%{name}/bash
install -d %{buildroot}%{_datadir}/%{name}/bash/lib
install -d %{buildroot}%{_datadir}/%{name}/config
install -d %{buildroot}%{_datadir}/%{name}/hooks
install -d %{buildroot}%{_datadir}/%{name}/docs
install -d %{buildroot}%{_bindir}
install -d %{buildroot}%{_datadir}/bash-completion/completions
install -d %{buildroot}%{_datadir}/zsh/site-functions
install -d %{buildroot}%{_docdir}/%{name}

# Install main script
install -m 755 cust-run-config.sh %{buildroot}%{_datadir}/%{name}/

# Install bash scripts
install -m 755 bash/*.sh %{buildroot}%{_datadir}/%{name}/bash/
install -m 644 bash/lib/*.sh %{buildroot}%{_datadir}/%{name}/bash/lib/

# Install config templates
install -m 644 config/*.json %{buildroot}%{_datadir}/%{name}/config/

# Install hook examples
install -m 644 hooks/*.example %{buildroot}%{_datadir}/%{name}/hooks/ || true
install -m 644 hooks/README.md %{buildroot}%{_datadir}/%{name}/hooks/ || true

# Install documentation
install -m 644 README.md %{buildroot}%{_docdir}/%{name}/
install -m 644 CHANGELOG.md %{buildroot}%{_docdir}/%{name}/
install -m 644 docs/*.md %{buildroot}%{_datadir}/%{name}/docs/

# Install completions
install -m 644 completions/autovault.bash %{buildroot}%{_datadir}/bash-completion/completions/autovault
install -m 644 completions/_autovault %{buildroot}%{_datadir}/zsh/site-functions/

# Create symlink for binary
ln -sf %{_datadir}/%{name}/cust-run-config.sh %{buildroot}%{_bindir}/autovault

%files
%license packaging/debian/copyright
%doc README.md CHANGELOG.md
%{_bindir}/autovault
%{_datadir}/%{name}/
%{_datadir}/bash-completion/completions/autovault
%{_datadir}/zsh/site-functions/_autovault
%{_docdir}/%{name}/

%changelog
* Tue Dec 24 2024 Spifuth <spifuth@protonmail.com> - 2.9.0-1
- Phase 4 Complete: Snap and Flatpak packaging
- Roadmap 100% complete
- 752 audit tasks verified

* Tue Dec 24 2025 Spifuth <spifuth@protonmail.com> - 2.8.0-1
- Phase 4.3: External Tool Integrations (Git-Sync, Nmap, Burp)
- 161 tests passing
- Full Bash and Zsh completions

* Mon Dec 23 2024 Spifuth <spifuth@protonmail.com> - 2.5.0-1
- Phase 4.1: Export & Reporting
- Phase 4.2: Extended Packaging (DEB/RPM)

* Sat Dec 21 2024 Spifuth <spifuth@protonmail.com> - 2.4.0-1
- Phase 3.1: CI/CD Pipeline
- Phase 3.2: Packaging (Homebrew, AUR)

* Fri Dec 20 2024 Spifuth <spifuth@protonmail.com> - 2.0.0-1
- Initial RPM package release
