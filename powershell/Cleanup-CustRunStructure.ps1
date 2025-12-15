# ==============================================
# Script 3 – Cleanup-CustRunStructure.ps1
# ==============================================
<#
DANGEROUS SCRIPT – WILL DELETE CUST STRUCTURE UNDER Run

CONFIG:
  - By default, $EnableDeletion is $false to avoid accidents.
  - Set $EnableDeletion = $true manually INSIDE the script when you are sure.

BEHAVIOR:
  - Deletes the folder of each CUST defined in $CustomerIds under <VaultRoot>\Run.
  - Optionally deletes Run-Hub.md if $RemoveHub is $true.

USAGE:
  - Save ONLY this block to: Cleanup-CustRunStructure.ps1
  - Run: pwsh ./Cleanup-CustRunStructure.ps1
#>

# =============================
# Config from environment (cust-run-config.sh)
# =============================

$VaultRoot = $env:CUST_VAULT_ROOT
if (-not $VaultRoot) {
    throw "CUST_VAULT_ROOT not set. Run this script via cust-run-config.sh."
}

$CustomerIdWidth = if ($env:CUST_CUSTOMER_ID_WIDTH) {
    [int]$env:CUST_CUSTOMER_ID_WIDTH
} else {
    3
}

# CustomerIds: space-separated ints
$CustomerIds = @()
if ($env:CUST_CUSTOMER_IDS) {
    $CustomerIds = $env:CUST_CUSTOMER_IDS `
        -split '\s+' `
        | Where-Object { $_ } `
        | ForEach-Object { [int]$_ }
}

# Sections: space-separated strings
$CustSections = @('FP','RAISED','INFORMATIONS','DIVERS')
if ($env:CUST_SECTIONS) {
    $CustSections = $env:CUST_SECTIONS `
        -split '\s+' `
        | Where-Object { $_ }
}

# Template root (only really used by Apply-CustRunTemplates.ps1, harmless elsewhere)
$TemplateRoot = if ($env:CUST_TEMPLATE_RELATIVE_ROOT) {
    Join-Path $VaultRoot $env:CUST_TEMPLATE_RELATIVE_ROOT
} else {
    Join-Path $VaultRoot '_templates\Run'
}


# Safety flags
$EnableDeletion = $false   # MUST be set to $true to delete
$RemoveHub      = $false   # Set to $true if you also want to remove Run-Hub.md

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','DEBUG')]
        [string]$Level = 'INFO'
    )

    $utc   = [datetime]::UtcNow.ToString('o')
    $local = (Get-Date).ToString('o')
    Write-Host "[$Level][UTC:$utc][Local:$local] $Message"
}

function Get-CustCode {
    param(
        [int]$Id
    )

    return ('CUST-{0}' -f $Id.ToString("D$CustomerIdWidth"))
}

if (-not $EnableDeletion) {
    Write-Log "ABORT: Cleanup disabled. Set `$EnableDeletion = `$true inside the script if you really want to delete." 'ERROR'
    exit 1
}

if (-not $CustomerIds -or $CustomerIds.Count -eq 0) {
    Write-Log "No CUST ids defined in `$CustomerIds. Nothing to clean." 'WARN'
    exit 0
}

$RunPath = Join-Path $VaultRoot 'Run'

Write-Log "Starting cleanup of CUST folders under: $RunPath" 'WARN'

foreach ($id in $CustomerIds) {
    $code = Get-CustCode -Id $id
    $custRoot = Join-Path $RunPath $code

    if (Test-Path -LiteralPath $custRoot -PathType Container) {
        Write-Log "Removing CUST folder: $custRoot" 'WARN'
        Remove-Item -LiteralPath $custRoot -Recurse -Force
    }
    else {
        Write-Log "CUST folder not found (skip): $custRoot" 'DEBUG'
    }
}

if ($RemoveHub) {
    $hubPath = Join-Path $VaultRoot 'Run-Hub.md'
    if (Test-Path -LiteralPath $hubPath -PathType Leaf) {
        Write-Log "Removing hub file: $hubPath" 'WARN'
        Remove-Item -LiteralPath $hubPath -Force
    }
    else {
        Write-Log "Hub file not found (skip): $hubPath" 'DEBUG'
    }
}

Write-Log "Cleanup completed." 'INFO'