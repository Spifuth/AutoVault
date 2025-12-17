# ==============================================
# Script 2 – Apply-CustRunTemplates.ps1
# ==============================================
<#
APPLY EXTERNAL MARKDOWN TEMPLATES TO ALL CUST RUN INDEX FILES

TEMPLATES:
  - Root index template:
      <VaultRoot>\_templates\Run\CUST-Root-Index.md
  - Section templates:
      <VaultRoot>\_templates\Run\CUST-Section-FP-Index.md
      <VaultRoot>\_templates\Run\CUST-Section-RAISED-Index.md
      <VaultRoot>\_templates\Run\CUST-Section-INFORMATIONS-Index.md
      <VaultRoot>\_templates\Run\CUST-Section-DIVERS-Index.md

PLACEHOLDERS SUPPORTED IN TEMPLATES:
  - {{CUST_CODE}}  -> e.g. CUST-002
  - {{SECTION}}    -> FP / RAISED / INFORMATIONS / DIVERS (for section templates)
  - {{NOW_UTC}}    -> ISO 8601 UTC datetime
  - {{NOW_LOCAL}}  -> ISO 8601 local datetime

BEHAVIOR:
  - For each CUST id in $CustomerIds:
      * Overwrites CUST-XXX-Index.md with expanded root template.
      * Overwrites each CUST-XXX-SECTION-Index.md with the corresponding section template.
  - If a CUST folder or index file is missing, logs a warning and continues.
  - If any template file is missing, the script logs an error and exits with code 1.

USAGE:
  - Ensure Script 1 has already created the structure (Run folders and index files).
  - Run: pwsh ./Apply-CustRunTemplates.ps1
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

# Template locations
$RootTemplatePath = Join-Path $TemplateRoot 'CUST-Root-Index.md'

# Function to get section template path dynamically
function Get-SectionTemplatePath {
    param([string]$Section)
    return Join-Path $TemplateRoot "CUST-Section-$Section-Index.md"
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

function Get-TemplateContent {
    param(
        [string]$Path,
        [string]$LogicalName
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Log ("Template missing for {0}: {1}" -f $LogicalName, $Path) 'ERROR'
        throw "TemplateMissing:$LogicalName"
    }

    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Expand-Template {
    param(
        [string]$TemplateText,
        [hashtable]$Context
    )

    $result = $TemplateText
    foreach ($key in $Context.Keys) {
        $placeholder = "{{$key}}"
        $value       = [string]$Context[$key]
        $result      = $result.Replace($placeholder, $value)
    }
    return $result
}

function Set-FileContent {
    param(
        [string]$Path,
        [string]$Content
    )

    $directory = Split-Path -Path $Path -Parent
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        Write-Log "Target directory does not exist, creating: $directory" 'WARN'
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.Encoding]::UTF8)
    Write-Log "Template applied to: $Path" 'INFO'
}

# =============================
# Load templates
# =============================

Write-Log "Loading templates from: $TemplateRoot" 'INFO'

try {
    $rootTemplateContent = Get-TemplateContent -Path $RootTemplatePath -LogicalName 'ROOT'
}
catch {
    Write-Log "Aborting: root template missing." 'ERROR'
    exit 1
}

$sectionTemplateContent = @{}
foreach ($section in $CustSections) {
    $tmplPath = Get-SectionTemplatePath -Section $section
    try {
        $sectionTemplateContent[$section] = Get-TemplateContent -Path $tmplPath -LogicalName $section
    }
    catch {
        Write-Log "Aborting: template missing for section '$section'." 'ERROR'
        exit 1
    }
}

# =============================
# Apply templates
# =============================

if (-not $CustomerIds -or $CustomerIds.Count -eq 0) {
    Write-Log "No CUST ids defined in `$CustomerIds. Edit the configuration at the top of the script." 'ERROR'
    exit 1
}

$RunPath = Join-Path $VaultRoot 'Run'

foreach ($id in $CustomerIds) {
    if (-not ($id -is [int])) {
        Write-Log "Invalid CUST id (not an integer): $id" 'ERROR'
        continue
    }

    $code     = Get-CustCode -Id $id
    $custRoot = Join-Path $RunPath $code

    if (-not (Test-Path -LiteralPath $custRoot -PathType Container)) {
        Write-Log "CUST folder missing, skipping ${code}: $custRoot" 'WARN'
        continue
    }

    # Context common to root & sections
    $ctxBase = @{
        'CUST_CODE' = $code
        'NOW_UTC'   = [datetime]::UtcNow.ToString('o')
        'NOW_LOCAL' = (Get-Date).ToString('o')
    }

    # Root index
    $rootIndexPath = Join-Path $custRoot ("$code-Index.md")
    if (-not (Test-Path -LiteralPath $rootIndexPath -PathType Leaf)) {
        Write-Log "Root index does not exist yet, will create: $rootIndexPath" 'WARN'
    }

    $rootContent = Expand-Template -TemplateText $rootTemplateContent -Context $ctxBase
    Set-FileContent -Path $rootIndexPath -Content $rootContent

    # Section indexes
    foreach ($section in $CustSections) {
        $subFolderName = "$code-$section"
        $subFolderPath = Join-Path $custRoot $subFolderName
        if (-not (Test-Path -LiteralPath $subFolderPath -PathType Container)) {
            Write-Log "Subfolder missing for ${code} ($section), skipping: $subFolderPath" 'WARN'
            continue
        }

        $subIndexPath = Join-Path $subFolderPath ("$subFolderName-Index.md")
        if (-not (Test-Path -LiteralPath $subIndexPath -PathType Leaf)) {
            Write-Log "Subfolder index does not exist yet for ${code} ($section), will create: $subIndexPath" 'WARN'
        }

        $ctx = $ctxBase.Clone()
        $ctx['SECTION'] = $section

        $tmplText = $sectionTemplateContent[$section]
        $expanded = Expand-Template -TemplateText $tmplText -Context $ctx
        Set-FileContent -Path $subIndexPath -Content $expanded
    }
}

Write-Log "Template application completed." 'INFO'
exit 0
