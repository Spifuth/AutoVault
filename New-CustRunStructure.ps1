<#
CONFIGURE ME:
  - Set $VaultRoot to the root folder of your Obsidian vault.
  - Fill the $CustomerIds array with the list of CUST numbers (integers).

STRUCTURE CREATED:
  <VaultRoot>\Run\
      CUST-002\
          CUST-002-FP\
              CUST-002-FP-Index.md
          CUST-002-RAISED\
              CUST-002-RAISED-Index.md
          CUST-002-INFORMATIONS\
              CUST-002-INFORMATIONS-Index.md
          CUST-002-DIVERS\
              CUST-002-DIVERS-Index.md

  And next to the Run folder:
  <VaultRoot>\Run-Hub.md
      -> contains links to each CUST root index (CUST-002-Index, etc.)

NAMING RULES:
  - Customer code       : CUST-XXX   (zero-padded with width = $CustomerIdWidth)
  - Customer folder     : Run\CUST-XXX
  - Root index file     : Run\CUST-XXX\CUST-XXX-Index.md
  - Subfolders          : CUST-XXX-FP, CUST-XXX-RAISED, CUST-XXX-INFORMATIONS, CUST-XXX-DIVERS
  - Subfolder index file: <SubFolderName>-Index.md

USAGE:
  - Save ONLY this block into: New-CustRunStructure.ps1
  - Run:  pwsh ./New-CustRunStructure.ps1
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


# =============================
# Helper functions
# =============================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','DEBUG')]
        [string]$Level = 'INFO'
    )

    $utc   = [datetime]::UtcNow.ToString('o')   # ISO 8601 UTC
    $local = (Get-Date).ToString('o')           # Local time (your local tz)
    Write-Host "[$Level][UTC:$utc][Local:$local] $Message"
}

function Ensure-Directory {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        Write-Log "Creating directory: $Path" 'INFO'
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    else {
        Write-Log "Directory already exists: $Path" 'DEBUG'
    }
}

function New-EmptyFile-Overwrite {
    param(
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Write-Log "Overwriting file: $Path" 'INFO'
    }
    else {
        Write-Log "Creating file: $Path" 'INFO'
    }

    New-Item -ItemType File -Path $Path -Force | Out-Null
}

function Get-CustCode {
    param(
        [int]$Id
    )

    return ('CUST-{0}' -f $Id.ToString("D$CustomerIdWidth"))
}

# =============================
# Main logic
# =============================

Write-Log "Starting CUST Run structure creation" 'INFO'
Write-Log "Vault root: $VaultRoot" 'INFO'

if (-not $CustomerIds -or $CustomerIds.Count -eq 0) {
    Write-Log "No CUST ids defined in `$CustomerIds. Edit the configuration at the top of the script." 'ERROR'
    exit 1
}

# Ensure vault root and Run folder exist
Ensure-Directory -Path $VaultRoot
$RunPath = Join-Path $VaultRoot 'Run'
Ensure-Directory -Path $RunPath

# Prepare hub content lines
$hubLines = [System.Collections.Generic.List[string]]::new()
$hubLines.Add('# Run Hub') | Out-Null
$hubLines.Add('') | Out-Null
$hubLines.Add('## Customers') | Out-Null
$hubLines.Add('') | Out-Null

foreach ($id in $CustomerIds) {
    if (-not ($id -is [int])) {
        Write-Log "Invalid CUST id (not an integer): $id" 'ERROR'
        continue
    }

    $code = Get-CustCode -Id $id
    Write-Log "Processing $code" 'INFO'

    # Root CUST folder: Run\CUST-XXX
    $custRoot = Join-Path $RunPath $code
    Ensure-Directory -Path $custRoot

    # Root index: CUST-XXX-Index.md
    $custIndexName = "$code-Index.md"
    $custIndexPath = Join-Path $custRoot $custIndexName
    New-EmptyFile-Overwrite -Path $custIndexPath

    # Add link to hub (Obsidian wikilink syntax)
    # Relative path: Run/CUST-XXX/CUST-XXX-Index
    $relativeTarget = "Run/$code/$code-Index"
    $hubLines.Add("- [[$relativeTarget]]") | Out-Null

    # Subfolders and their index files
    foreach ($section in $CustSections) {
        $subFolderName = "$code-$section"
        $subFolderPath = Join-Path $custRoot $subFolderName
        Ensure-Directory -Path $subFolderPath

        $subIndexName = "$subFolderName-Index.md"
        $subIndexPath = Join-Path $subFolderPath $subIndexName
        New-EmptyFile-Overwrite -Path $subIndexPath
    }
}

# Write the Run-Hub.md file next to Run
$hubPath = Join-Path $VaultRoot 'Run-Hub.md'
$hubContent = $hubLines -join [Environment]::NewLine

[System.IO.File]::WriteAllText($hubPath, $hubContent, [System.Text.Encoding]::UTF8)
Write-Log "Hub file written: $hubPath" 'INFO'

Write-Log "CUST Run structure creation completed." 'INFO'
