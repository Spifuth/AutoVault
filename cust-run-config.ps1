<#
.SYNOPSIS
    Orchestrator + config for CUST Run PowerShell scripts (Windows).

.DESCRIPTION
    Creates and reads cust-run-config.json so Bash and PowerShell runners share
    the same vault settings. When executed directly, provides CLI commands to
    manage the CUST Run structure.

.PARAMETER Command
    The command to execute: structure, templates, test, cleanup

.EXAMPLE
    .\cust-run-config.ps1 structure
    .\cust-run-config.ps1 templates
    .\cust-run-config.ps1 test
    .\cust-run-config.ps1 cleanup
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('install', 'requirements', 'config', 'setup', 'init', 'structure', 'new', 'templates', 'apply', 'test', 'verify', 'cleanup', '')]
    [string]$Command
)

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configJsonPath = Join-Path $ScriptRoot 'config' 'cust-run-config.json'

#--------------------------------------
# LOGGING HELPERS
#--------------------------------------

function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO ] $Message" -ForegroundColor Blue
}

function Write-LogWarn {
    param([string]$Message)
    Write-Host "[WARN ] $Message" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

#######################################
# REQUIREMENTS CHECK & AUTO-INSTALL
#######################################

function Test-Requirements {
    $missing = @()
    
    # Check for Git (optional but useful)
    if (-not (Get-Command 'git' -ErrorAction SilentlyContinue)) {
        $missing += 'git'
    }
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion.Major
    if ($psVersion -lt 5) {
        Write-LogWarn "PowerShell version $psVersion detected. Version 5.1+ recommended."
    }
    
    return $missing
}

function Get-PackageManager {
    # Check for winget (Windows Package Manager)
    if (Get-Command 'winget' -ErrorAction SilentlyContinue) {
        return 'winget'
    }
    
    # Check for Chocolatey
    if (Get-Command 'choco' -ErrorAction SilentlyContinue) {
        return 'choco'
    }
    
    # Check for Scoop
    if (Get-Command 'scoop' -ErrorAction SilentlyContinue) {
        return 'scoop'
    }
    
    return $null
}

function Install-Requirements {
    $missing = Test-Requirements
    
    if ($missing.Count -eq 0) {
        Write-LogInfo "All requirements are already installed"
        Write-LogInfo "PowerShell version: $($PSVersionTable.PSVersion)"
        return $true
    }
    
    Write-LogWarn "Missing optional tools: $($missing -join ', ')"
    
    $pkgManager = Get-PackageManager
    
    if (-not $pkgManager) {
        Write-LogWarn "No supported package manager found (winget, choco, scoop)"
        Write-LogInfo "You can install winget from the Microsoft Store (App Installer)"
        Write-LogInfo "Or install Chocolatey: https://chocolatey.org/install"
        Write-LogInfo "Or install Scoop: https://scoop.sh"
        Write-Host ""
        Write-LogInfo "Manual installation commands:"
        Write-Host "  winget install Git.Git"
        Write-Host "  choco install git -y"
        Write-Host "  scoop install git"
        return $false
    }
    
    Write-LogInfo "Detected package manager: $pkgManager"
    
    $confirm = Read-Host "Install missing tools using $pkgManager? [Y/n]"
    if ($confirm -match '^[Nn]') {
        Write-LogWarn "Installation cancelled"
        return $false
    }
    
    foreach ($pkg in $missing) {
        $installCmd = switch ($pkgManager) {
            'winget' { "winget install --id $pkg --accept-package-agreements --accept-source-agreements" }
            'choco'  { "choco install $pkg -y" }
            'scoop'  { "scoop install $pkg" }
        }
        
        # Map package names
        $pkgName = switch ($pkg) {
            'git' { 
                switch ($pkgManager) {
                    'winget' { 'Git.Git' }
                    default  { 'git' }
                }
            }
            default { $pkg }
        }
        
        $installCmd = switch ($pkgManager) {
            'winget' { "winget install --id $pkgName --accept-package-agreements --accept-source-agreements" }
            'choco'  { "choco install $pkgName -y" }
            'scoop'  { "scoop install $pkgName" }
        }
        
        Write-LogInfo "Running: $installCmd"
        try {
            Invoke-Expression $installCmd
            Write-LogInfo "$pkg installed successfully"
        } catch {
            Write-LogError "Failed to install $pkg : $_"
            return $false
        }
    }
    
    Write-LogInfo "All requirements installed successfully"
    return $true
}

#######################################
# CONFIGURATION SOURCE
#######################################

# Base values used to seed cust-run-config.json. Adjust these to match your
# vault and customer list. Re-running the script will refresh the JSON to match
# these values (or environment overrides) so Bash and PowerShell stay aligned.
$VaultRoot            = $env:CUST_VAULT_ROOT            ? $env:CUST_VAULT_ROOT            : 'D:\Obsidian\Work-Vault'
$CustomerIdWidth      = $env:CUST_CUSTOMER_ID_WIDTH     ? [int]$env:CUST_CUSTOMER_ID_WIDTH : 3
$CustomerIds          = if ($env:CUST_CUSTOMER_IDS) { $env:CUST_CUSTOMER_IDS -split '\s+' | Where-Object { $_ } | ForEach-Object { [int]$_ } } else { @(2,4,5,7,10,11,12,14,15,18,25,27,29,30) }
$CustSections         = if ($env:CUST_SECTIONS) { $env:CUST_SECTIONS -split '\s+' | Where-Object { $_ } } else { @('FP','RAISED','INFORMATIONS','DIVERS') }
$TemplateRelativeRoot = $env:CUST_TEMPLATE_RELATIVE_ROOT ? $env:CUST_TEMPLATE_RELATIVE_ROOT : '_templates\Run'

#######################################
# INTERACTIVE CONFIGURATION
#######################################

function Prompt-Value {
    param(
        [string]$Prompt,
        [string]$Default
    )
    
    if ($Default) {
        $result = Read-Host "$Prompt [$Default]"
    } else {
        $result = Read-Host "$Prompt"
    }
    
    if ([string]::IsNullOrWhiteSpace($result)) {
        return $Default
    }
    return $result
}

function Prompt-List {
    param(
        [string]$Prompt,
        [array]$Default
    )
    
    $defaultStr = $Default -join ' '
    $result = Read-Host "$Prompt (space-separated) [$defaultStr]"
    
    if ([string]::IsNullOrWhiteSpace($result)) {
        return $Default
    }
    return ($result -split '\s+' | Where-Object { $_ })
}

function Invoke-InteractiveConfig {
    Write-LogInfo "Interactive configuration mode"
    Write-LogInfo "Press Enter to keep current/default values"
    Write-Host ""
    
    # Display current configuration
    Write-Host "Current configuration:"
    Write-Host "  1. VaultRoot:            $VaultRoot"
    Write-Host "  2. CustomerIdWidth:      $CustomerIdWidth"
    Write-Host "  3. CustomerIds:          $($CustomerIds -join ' ')"
    Write-Host "  4. Sections:             $($CustSections -join ' ')"
    Write-Host "  5. TemplateRelativeRoot: $TemplateRelativeRoot"
    Write-Host ""
    
    # VaultRoot
    $script:VaultRoot = Prompt-Value -Prompt "Vault root path" -Default $VaultRoot
    
    # CustomerIdWidth
    $widthStr = Prompt-Value -Prompt "Customer ID width (padding)" -Default $CustomerIdWidth.ToString()
    $script:CustomerIdWidth = [int]$widthStr
    
    # CustomerIds
    $newIds = Prompt-List -Prompt "Customer IDs" -Default $CustomerIds
    $script:CustomerIds = @($newIds | ForEach-Object { [int]$_ })
    
    # Sections
    $newSections = Prompt-List -Prompt "Sections" -Default $CustSections
    $script:CustSections = @($newSections)
    
    # TemplateRelativeRoot
    $script:TemplateRelativeRoot = Prompt-Value -Prompt "Template relative root" -Default $TemplateRelativeRoot
    
    Write-Host ""
    Write-LogInfo "Configuration summary:"
    Write-Host "  VaultRoot:            $VaultRoot"
    Write-Host "  CustomerIdWidth:      $CustomerIdWidth"
    Write-Host "  CustomerIds:          $($CustomerIds -join ' ')"
    Write-Host "  Sections:             $($CustSections -join ' ')"
    Write-Host "  TemplateRelativeRoot: $TemplateRelativeRoot"
    Write-Host ""
    
    $confirm = Read-Host "Save this configuration? [Y/n]"
    if ($confirm -match '^[Nn]') {
        Write-LogWarn "Configuration cancelled"
        return $false
    }
    
    # Force write the new config
    $json = Get-ConfigPayload | ConvertTo-Json -Depth 4
    $parentDir = Split-Path -Parent $configJsonPath
    if (-not (Test-Path -LiteralPath $parentDir -PathType Container)) {
        Write-LogInfo "Creating config directory: $parentDir"
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    Write-LogInfo "Writing configuration file: $configJsonPath"
    Set-Content -Path $configJsonPath -Value $json -Encoding UTF8 -NoNewline
    
    Write-LogInfo "Configuration saved to $configJsonPath"
    return $true
}

#######################################
# CONFIG (written to + loaded from cust-run-config.json)
#######################################

function Get-ConfigPayload {
    [ordered]@{
        VaultRoot            = $VaultRoot
        CustomerIdWidth      = $CustomerIdWidth
        CustomerIds          = $CustomerIds
        Sections             = $CustSections
        TemplateRelativeRoot = $TemplateRelativeRoot
    }
}

function Ensure-ConfigJson {
    param([string]$Path)

    $json = Get-ConfigPayload | ConvertTo-Json -Depth 4
    $existing = if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    } else {
        $null
    }

    if ($json -ne $existing) {
        $parentDir = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $parentDir -PathType Container)) {
            Write-LogInfo "Creating config directory: $parentDir"
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        Write-LogInfo "Writing configuration file: $Path"
        Set-Content -Path $Path -Value $json -Encoding UTF8 -NoNewline
    }

    return $json
}

# Load configuration
$jsonText = Ensure-ConfigJson -Path $configJsonPath
$config = $jsonText | ConvertFrom-Json

if (-not $config.VaultRoot) {
    throw "Config error: VaultRoot missing from $configJsonPath"
}

$script:VaultRoot            = [string]$config.VaultRoot
$script:CustomerIdWidth      = [int]$config.CustomerIdWidth
$script:CustomerIds          = @($config.CustomerIds)
$script:CustSections         = @($config.Sections)
$script:TemplateRelativeRoot = [string]$config.TemplateRelativeRoot
$script:TemplateRoot         = Join-Path $VaultRoot $TemplateRelativeRoot

# Export to environment for child scripts
$env:CUST_VAULT_ROOT             = $VaultRoot
$env:CUST_CUSTOMER_ID_WIDTH      = $CustomerIdWidth
$env:CUST_CUSTOMER_IDS           = ($CustomerIds -join ' ')
$env:CUST_SECTIONS               = ($CustSections -join ' ')
$env:CUST_TEMPLATE_RELATIVE_ROOT = $TemplateRelativeRoot

#######################################
# INTERNAL: run PowerShell scripts
#######################################

function Invoke-CustScript {
    param([string]$ScriptName)
    
    $scriptPath = Join-Path $ScriptRoot 'powershell' $ScriptName
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        Write-LogError "Script not found: $scriptPath"
        exit 1
    }
    
    & $scriptPath
}

#######################################
# CLI (only when executed with command)
#######################################

function Show-Usage {
    @"
Usage: .\cust-run-config.ps1 <command>

Commands:
  install     Check and install missing requirements (git, etc.)
  config      Interactive configuration wizard
  structure   Create / refresh CUST Run folder structure
  templates   Apply markdown templates to indexes
  test        Verify structure & indexes
  cleanup     Remove CUST folders (uses Cleanup script safety flags)

Examples:
  .\cust-run-config.ps1 install
  .\cust-run-config.ps1 config
  .\cust-run-config.ps1 structure
  .\cust-run-config.ps1 templates
  .\cust-run-config.ps1 test
  .\cust-run-config.ps1 cleanup
"@
}

if ($Command) {
    switch ($Command) {
        { $_ -in 'install', 'requirements' } {
            Install-Requirements
        }
        { $_ -in 'config', 'setup', 'init' } {
            Invoke-InteractiveConfig
        }
        { $_ -in 'structure', 'new' } {
            Write-LogInfo "Using configuration from $configJsonPath"
            Invoke-CustScript 'New-CustRunStructure.ps1'
        }
        { $_ -in 'templates', 'apply' } {
            Write-LogInfo "Using configuration from $configJsonPath"
            Invoke-CustScript 'Apply-CustRunTemplates.ps1'
        }
        { $_ -in 'test', 'verify' } {
            Write-LogInfo "Using configuration from $configJsonPath"
            Invoke-CustScript 'Test-CustRunStructure.ps1'
        }
        'cleanup' {
            Write-LogWarn "Using configuration from $configJsonPath"
            Invoke-CustScript 'Cleanup-CustRunStructure.ps1'
        }
        default {
            Write-LogError "Unknown command: $Command"
            Show-Usage
            exit 1
        }
    }
}
elseif ($MyInvocation.InvocationName -ne '.') {
    # Script was executed directly without command (not dot-sourced)
    Show-Usage
    exit 1
}

# When dot-sourced, variables are available to the caller:
# $VaultRoot, $CustomerIdWidth, $CustomerIds, $CustSections, $TemplateRoot
