<#
Shared config loader for CUST Run scripts.
Reads cust-run-config.sh (bash-style KEY=VALUE) and exposes:

  $VaultRoot
  $CustomerIdWidth
  $CustomerIds
  $CustSections
  $TemplateRoot
#>

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configPath = Join-Path $ScriptRoot 'cust-run-config.sh'

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Config file not found: $configPath"
}

$rawLines = Get-Content -LiteralPath $configPath -ErrorAction Stop

# Simple parser for lines like:
#   KEY=value
#   KEY="value"
#   KEY='value'
#   KEY=(a b c)
$kv = @{}

foreach ($line in $rawLines) {
    $trim = $line.Trim()
    if (-not $trim) { continue }
    if ($trim.StartsWith('#')) { continue }

    if ($trim -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)\s*$') {
        continue
    }

    $key = $matches[1]
    $raw = $matches[2].Trim()

    # Strip trailing inline comment: foo=bar # comment
    $commentIdx = $raw.IndexOf('#')
    if ($commentIdx -ge 0) {
        $raw = $raw.Substring(0, $commentIdx).Trim()
    }

    $value = $null

    if ($raw.StartsWith('(') -and $raw.EndsWith(')')) {
        # Array syntax: (a b c)
        $inside = $raw.Substring(1, $raw.Length - 2).Trim()
        $items = @()
        if ($inside.Length -gt 0) {
            foreach ($tok in [regex]::Split($inside, '\s+')) {
                if (-not $tok) { continue }
                if ($tok.StartsWith('"') -and $tok.EndsWith('"')) {
                    $items += $tok.Trim('"')
                }
                elseif ($tok.StartsWith("'") -and $tok.EndsWith("'")) {
                    $items += $tok.Trim("'")
                }
                else {
                    $items += $tok
                }
            }
        }
        $value = $items
    }
    elseif (
        ($raw.StartsWith('"') -and $raw.EndsWith('"')) -or
        ($raw.StartsWith("'") -and $raw.EndsWith("'"))
    ) {
        $value = $raw.Substring(1, $raw.Length - 2)
    }
    else {
        $value = $raw
    }

    $kv[$key] = $value
}

if (-not $kv.ContainsKey('VAULT_ROOT')) {
    throw "Config error: VAULT_ROOT is required in cust-run-config.sh"
}

# Exposed variables for the scripts
$VaultRoot       = [string]$kv['VAULT_ROOT']
$CustomerIdWidth = [int]($kv['CUSTOMER_ID_WIDTH'] ?? 3)

# CustomerIds: int array
$CustomerIds = @()
if ($kv.ContainsKey('CUSTOMER_IDS')) {
    $rawIds = $kv['CUSTOMER_IDS']
    if ($rawIds -is [array]) {
        $CustomerIds = $rawIds | ForEach-Object { [int]$_ }
    }
    elseif ($rawIds -is [string]) {
        $CustomerIds = $rawIds -split '[\s,;]+' | Where-Object { $_ } | ForEach-Object { [int]$_ }
    }
}

# Sections
if ($kv.ContainsKey('SECTIONS')) {
    $rawSections = $kv['SECTIONS']
    if ($rawSections -is [array]) {
        $CustSections = $rawSections
    }
    elseif ($rawSections -is [string]) {
        $CustSections = $rawSections -split '[\s,;]+' | Where-Object { $_ }
    }
} else {
    $CustSections = @('FP', 'RAISED', 'INFORMATIONS', 'DIVERS')
}

# TemplateRoot (for Script 2)
if ($kv.ContainsKey('TEMPLATE_RELATIVE_ROOT')) {
    $TemplateRoot = Join-Path $VaultRoot ([string]$kv['TEMPLATE_RELATIVE_ROOT'])
} else {
    $TemplateRoot = Join-Path $VaultRoot '_templates\Run'
}
