<#
.SYNOPSIS
    Install required dependencies for AutoVault (Windows)

.DESCRIPTION
    Checks and installs PowerShell 7+ if needed.
    AutoVault requires PowerShell 7+ to run.

.EXAMPLE
    .\Install-Requirements.ps1
#>

[CmdletBinding()]
param()

#--------------------------------------
# Logging helpers
#--------------------------------------
function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[OK] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-LogWarn {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

#--------------------------------------
# Check PowerShell version
#--------------------------------------
function Test-PowerShellVersion {
    $version = $PSVersionTable.PSVersion
    $isCore = $PSVersionTable.PSEdition -eq 'Core'

    if ($isCore -and $version.Major -ge 7) {
        Write-LogSuccess "PowerShell $version (Core) - meets requirements"
        return $true
    }
    elseif ($isCore) {
        Write-LogWarn "PowerShell $version (Core) - version 7+ required"
        return $false
    }
    else {
        Write-LogWarn "Windows PowerShell $version detected - PowerShell 7+ (Core) required"
        return $false
    }
}

#--------------------------------------
# Detect available package managers
#--------------------------------------
function Get-AvailableInstaller {
    $installers = @()

    # Check for winget
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $installers += 'winget'
    }

    # Check for chocolatey
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        $installers += 'choco'
    }

    # Check for scoop
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        $installers += 'scoop'
    }

    return $installers
}

#--------------------------------------
# Install PowerShell 7
#--------------------------------------
function Install-PowerShell7 {
    param([string]$Method)

    switch ($Method) {
        'winget' {
            Write-LogInfo "Installing PowerShell 7 via winget..."
            winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements
            return $LASTEXITCODE -eq 0
        }
        'choco' {
            Write-LogInfo "Installing PowerShell 7 via Chocolatey..."
            Write-LogWarn "This requires Administrator privileges"
            choco install powershell-core -y
            return $LASTEXITCODE -eq 0
        }
        'scoop' {
            Write-LogInfo "Installing PowerShell 7 via Scoop..."
            scoop install pwsh
            return $LASTEXITCODE -eq 0
        }
        'manual' {
            Write-LogInfo "Opening PowerShell download page..."
            Start-Process "https://github.com/PowerShell/PowerShell/releases/latest"
            return $false
        }
        default {
            Write-LogError "Unknown installation method: $Method"
            return $false
        }
    }
}

#--------------------------------------
# Main
#--------------------------------------
function Main {
    Write-Host "=========================================="
    Write-Host "  AutoVault - Requirements Installer"
    Write-Host "  (Windows)"
    Write-Host "=========================================="
    Write-Host ""

    # Check PowerShell version
    Write-LogInfo "Checking PowerShell version..."
    if (Test-PowerShellVersion) {
        Write-Host ""
        Write-Host "=========================================="
        Write-LogSuccess "All requirements are already installed!"
        Write-Host "=========================================="
        Write-Host ""
        Write-LogInfo "You can run AutoVault with: .\cust-run-config.ps1 <command>"
        return
    }

    Write-Host ""

    # Detect available installers
    $installers = Get-AvailableInstaller

    if ($installers.Count -eq 0) {
        Write-LogWarn "No package manager detected (winget, choco, or scoop)"
        Write-Host ""
        Write-Host "You can install PowerShell 7 manually:"
        Write-Host "  1. Download from: https://github.com/PowerShell/PowerShell/releases/latest"
        Write-Host "  2. Or install winget first: https://aka.ms/getwinget"
        Write-Host ""

        $response = Read-Host "Open the download page in your browser? [Y/n]"
        if ($response -notmatch '^[Nn]') {
            Start-Process "https://github.com/PowerShell/PowerShell/releases/latest"
        }
        return
    }

    Write-LogInfo "Available package managers: $($installers -join ', ')"
    Write-Host ""

    # Prefer winget, then scoop, then choco
    $preferredOrder = @('winget', 'scoop', 'choco')
    $selectedInstaller = $null

    foreach ($installer in $preferredOrder) {
        if ($installers -contains $installer) {
            $selectedInstaller = $installer
            break
        }
    }

    Write-Host "PowerShell 7+ is required to run AutoVault."
    Write-Host ""
    Write-Host "Installation options:"

    $options = @()
    $i = 1
    foreach ($installer in $installers) {
        $desc = switch ($installer) {
            'winget' { "winget (recommended)" }
            'choco' { "Chocolatey (requires Admin)" }
            'scoop' { "Scoop" }
        }
        Write-Host "  $i. Install via $desc"
        $options += $installer
        $i++
    }
    Write-Host "  $i. Download manually (opens browser)"
    $options += 'manual'
    Write-Host "  0. Cancel"

    Write-Host ""
    $choice = Read-Host "Select option [1]"

    if ([string]::IsNullOrWhiteSpace($choice)) {
        $choice = "1"
    }

    if ($choice -eq "0") {
        Write-LogInfo "Installation cancelled"
        return
    }

    $choiceIndex = [int]$choice - 1
    if ($choiceIndex -lt 0 -or $choiceIndex -ge $options.Count) {
        Write-LogError "Invalid option"
        return
    }

    $method = $options[$choiceIndex]
    Write-Host ""

    if ($method -eq 'manual') {
        Install-PowerShell7 -Method 'manual'
        Write-Host ""
        Write-LogInfo "After installing PowerShell 7, run this script again from pwsh to verify."
        return
    }

    $success = Install-PowerShell7 -Method $method

    Write-Host ""
    if ($success) {
        Write-Host "=========================================="
        Write-LogSuccess "PowerShell 7 installation initiated!"
        Write-Host "=========================================="
        Write-Host ""
        Write-LogInfo "Please restart your terminal and run 'pwsh' to use PowerShell 7"
        Write-LogInfo "Then run AutoVault with: pwsh .\cust-run-config.ps1 <command>"
    }
    else {
        Write-LogWarn "Installation may have failed or requires a restart."
        Write-LogInfo "Please check for errors above and try again."
    }
}

Main
