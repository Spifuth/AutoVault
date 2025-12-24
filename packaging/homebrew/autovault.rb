# Homebrew formula for AutoVault
# Install: brew tap Spifuth/autovault && brew install autovault
# Or:      brew install Spifuth/autovault/autovault

class Autovault < Formula
  desc "CLI tool for managing Obsidian vaults for customer documentation"
  homepage "https://github.com/Spifuth/AutoVault"
  url "https://github.com/Spifuth/AutoVault/archive/refs/tags/v2.9.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"
  head "https://github.com/Spifuth/AutoVault.git", branch: "main"

  depends_on "bash" => "4.0"
  depends_on "jq"
  depends_on "rsync"

  def install
    # Install main script
    bin.install "cust-run-config.sh" => "autovault"

    # Install bash scripts
    libexec.install "bash"

    # Install config templates
    (share/"autovault").install "config"
    (share/"autovault").install "hooks"

    # Install completions
    bash_completion.install "completions/autovault.bash" => "autovault"
    zsh_completion.install "completions/_autovault"

    # Update script path in main script
    inreplace bin/"autovault", /^SCRIPT_DIR=.*/, "SCRIPT_DIR=\"#{libexec}\""
  end

  def caveats
    <<~EOS
      AutoVault has been installed!

      To get started:
        autovault --help         Show available commands
        autovault init           Initialize a new vault
        autovault doctor         Check your setup

      Documentation: https://github.com/Spifuth/AutoVault/wiki

      Shell completions have been installed. Restart your terminal or run:
        source #{bash_completion}/autovault
    EOS
  end

  test do
    assert_match "AutoVault", shell_output("#{bin}/autovault --version")
    assert_match "Usage:", shell_output("#{bin}/autovault --help")
  end
end
