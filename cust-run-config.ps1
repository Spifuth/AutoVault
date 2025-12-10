<#
Shared config loader for CUST Run scripts.
Creates and reads cust-run-config.json so Bash and PowerShell runners share
the same vault settings.

Exposes:
  $VaultRoot
  $CustomerIdWidth
  $CustomerIds
  $CustSections
  $TemplateRoot
#>

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configJsonPath = Join-Path $ScriptRoot 'cust-run-config.json'

# Base values used to seed cust-run-config.json. Re-running the script refreshes
# the JSON so both shells stay aligned with these values (or env overrides).
$VaultRoot            = $env:CUST_VAULT_ROOT            ? $env:CUST_VAULT_ROOT            : 'D:\Obsidian\Work-Vault'
$CustomerIdWidth      = $env:CUST_CUSTOMER_ID_WIDTH     ? [int]$env:CUST_CUSTOMER_ID_WIDTH : 3
$CustomerIds          = if ($env:CUST_CUSTOMER_IDS) { $env:CUST_CUSTOMER_IDS -split '\s+' | Where-Object { $_ } | ForEach-Object { [int]$_ } } else { @(2,4,5,7,10,11,12,14,15,18,25,27,29,30) }
$CustSections         = if ($env:CUST_SECTIONS) { $env:CUST_SECTIONS -split '\s+' | Where-Object { $_ } } else { @('FP','RAISED','INFORMATIONS','DIVERS') }
$TemplateRelativeRoot = $env:CUST_TEMPLATE_RELATIVE_ROOT ? $env:CUST_TEMPLATE_RELATIVE_ROOT : '_templates\Run'

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
        Write-Output "INFO: Writing configuration file: $Path" | Out-Host
        Set-Content -Path $Path -Value $json -Encoding UTF8 -NoNewline
    }

    return $json
}

$jsonText = Ensure-ConfigJson -Path $configJsonPath
$config = $jsonText | ConvertFrom-Json

if (-not $config.VaultRoot) {
    throw "Config error: VaultRoot missing from $configJsonPath"
}

$VaultRoot            = [string]$config.VaultRoot
$CustomerIdWidth      = [int]$config.CustomerIdWidth
$CustomerIds          = @($config.CustomerIds)
$CustSections         = @($config.Sections)
$TemplateRelativeRoot = [string]$config.TemplateRelativeRoot

$env:CUST_VAULT_ROOT            = $VaultRoot
$env:CUST_CUSTOMER_ID_WIDTH     = $CustomerIdWidth
$env:CUST_CUSTOMER_IDS          = ($CustomerIds -join ' ')
$env:CUST_SECTIONS              = ($CustSections -join ' ')
$env:CUST_TEMPLATE_RELATIVE_ROOT = $TemplateRelativeRoot

$TemplateRoot = Join-Path $VaultRoot $TemplateRelativeRoot
