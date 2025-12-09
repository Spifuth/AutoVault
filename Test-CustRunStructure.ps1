# ==============================================
# Script 4 – Test-CustRunStructure.ps1
# ==============================================
<#
VERIFICATION SCRIPT – CHECKS Run STRUCTURE AND INDEX FILES

CHECKS:
  - <VaultRoot> exists.
  - <VaultRoot>\Run exists.
  - Run-Hub.md exists.
  - For each CUST in $CustomerIds:
      * Run\CUST-XXX\ exists.
      * Run\CUST-XXX\CUST-XXX-Index.md exists.
      * For each section in (FP, RAISED, INFORMATIONS, DIVERS):
          - Run\CUST-XXX\CUST-XXX-<SECTION>\ exists.
          - Run\CUST-XXX\CUST-XXX-<SECTION>\CUST-XXX-<SECTION>-Index.md exists.
  - Optionally checks that Run-Hub.md contains a link to each CUST-XXX-Index.

EXIT CODES:
  - 0 if everything is OK
  - 1 if there are missing elements

USAGE:
  - Save ONLY this block to: Test-CustRunStructure.ps1
  - Run: pwsh ./Test-CustRunStructure.ps1
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

$errors = [System.Collections.Generic.List[string]]::new()

# Basic checks
if (-not (Test-Path -LiteralPath $VaultRoot -PathType Container)) {
    $msg = "Vault root does NOT exist: $VaultRoot"
    Write-Log $msg 'ERROR'
    $errors.Add($msg) | Out-Null
}

$RunPath = Join-Path $VaultRoot 'Run'
if (-not (Test-Path -LiteralPath $RunPath -PathType Container)) {
    $msg = "Run folder does NOT exist: $RunPath"
    Write-Log $msg 'ERROR'
    $errors.Add($msg) | Out-Null
}
else {
    Write-Log "Run folder exists: $RunPath" 'INFO'
}

$hubPath = Join-Path $VaultRoot 'Run-Hub.md'
if (-not (Test-Path -LiteralPath $hubPath -PathType Leaf)) {
    $msg = "Run-Hub.md does NOT exist: $hubPath"
    Write-Log $msg 'ERROR'
    $errors.Add($msg) | Out-Null
    $hubContent = $null
}
else {
    Write-Log "Hub file exists: $hubPath" 'INFO'
    $hubContent = Get-Content -LiteralPath $hubPath -Raw
}

if (-not $CustomerIds -or $CustomerIds.Count -eq 0) {
    $msg = "No CUST ids defined in `$CustomerIds. Nothing to verify." 
    Write-Log $msg 'WARN'
    $errors.Add($msg) | Out-Null
}

foreach ($id in $CustomerIds) {
    $code = Get-CustCode -Id $id
    $custRoot = Join-Path $RunPath $code

    if (-not (Test-Path -LiteralPath $custRoot -PathType Container)) {
        $msg = "MISSING CUST folder: $custRoot"
        Write-Log $msg 'ERROR'
        $errors.Add($msg) | Out-Null
        continue
    }
    else {
        Write-Log "CUST folder OK: $custRoot" 'INFO'
    }

    # Root index
    $custIndexPath = Join-Path $custRoot ("$code-Index.md")
    if (-not (Test-Path -LiteralPath $custIndexPath -PathType Leaf)) {
        $msg = "MISSING root index for ${code}: $custIndexPath"
        Write-Log $msg 'ERROR'
        $errors.Add($msg) | Out-Null
    }
    else {
        Write-Log "Root index OK: $custIndexPath" 'DEBUG'
    }

    # Subfolders + indexes
    foreach ($section in $CustSections) {
        $subFolderName = "$code-$section"
        $subFolderPath = Join-Path $custRoot $subFolderName

        if (-not (Test-Path -LiteralPath $subFolderPath -PathType Container)) {
            $msg = "MISSING subfolder $subFolderName for ${code}: $subFolderPath"
            Write-Log $msg 'ERROR'
            $errors.Add($msg) | Out-Null
            continue
        }
        else {
            Write-Log "Subfolder OK: $subFolderPath" 'DEBUG'
        }

        $subIndexPath = Join-Path $subFolderPath ("$subFolderName-Index.md")
        if (-not (Test-Path -LiteralPath $subIndexPath -PathType Leaf)) {
            $msg = "MISSING subfolder index $subFolderName for ${code}: $subIndexPath"
            Write-Log $msg 'ERROR'
            $errors.Add($msg) | Out-Null
        }
        else {
            Write-Log "Subfolder index OK: $subIndexPath" 'DEBUG'
        }
    }

    # Optional: check hub content contains link to CUST-XXX-Index
    if ($hubContent) {
        $expectedToken = "$code-Index"
        if ($hubContent -notlike "*${expectedToken}*") {
            $msg = "Hub file does not contain reference to $expectedToken"
            Write-Log $msg 'WARN'
            $errors.Add($msg) | Out-Null
        }
        else {
            Write-Log "Hub contains reference to $expectedToken" 'DEBUG'
        }
    }
}

if ($errors.Count -eq 0) {
    Write-Log "VERIFICATION SUCCESS – Run structure and all CUST indexes are present." 'INFO'
    exit 0
}
else {
    Write-Log "VERIFICATION FAILED – Issues detected:" 'ERROR'
    foreach ($err in $errors) {
        Write-Host "  - $err"
    }
    exit 1
}
