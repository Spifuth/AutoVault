<#
Generate-CustRunTemplates.ps1
Create markdown template files under the Vault _templates folder from a JSON spec.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TemplateSpecPath
)

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configScript = Join-Path $ScriptRoot 'cust-run-config.ps1'

if (Test-Path -LiteralPath $configScript -PathType Leaf) {
    . $configScript
}

if (-not $VaultRoot) {
    throw 'VAULT_ROOT is not set. Run via cust-run-config.ps1 or update cust-run-config.ps1.'
}

if (-not $TemplateRelativeRoot) {
    $TemplateRelativeRoot = '_templates\Run'
}

$normalizedTemplateRoot = $TemplateRelativeRoot -replace '\\', [IO.Path]::DirectorySeparatorChar
$TemplateRoot = Join-Path $VaultRoot $normalizedTemplateRoot

if (-not $TemplateSpecPath) {
    $TemplateSpecPath = Join-Path $ScriptRoot 'cust-run-templates.json'
}

if (-not (Test-Path -LiteralPath $TemplateSpecPath -PathType Leaf)) {
    throw "Template JSON not found: $TemplateSpecPath"
}

Write-Host "INFO: Writing templates to: $TemplateRoot"
New-Item -ItemType Directory -Force -Path $TemplateRoot | Out-Null

Write-Host "INFO: Reading template definitions from: $TemplateSpecPath"

try {
    $spec = Get-Content -LiteralPath $TemplateSpecPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    throw "Failed to parse JSON from $TemplateSpecPath: $_"
}

$templates = @($spec.Templates)
if (-not $templates -or $templates.Count -eq 0) {
    Write-Warning "No templates found in $TemplateSpecPath (expected a 'Templates' array)."
    return
}

$count = 0
foreach ($tmpl in $templates) {
    $fileName = [string]$tmpl.FileName
    if ([string]::IsNullOrWhiteSpace($fileName)) {
        Write-Warning 'Encountered template entry without FileName. Skipping.'
        continue
    }

    $content = [string]$tmpl.Content
    $targetPath = Join-Path $TemplateRoot $fileName
    $targetDir = Split-Path -Parent $targetPath

    if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
        Write-Host "INFO: Creating directory: $targetDir"
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }

    Set-Content -LiteralPath $targetPath -Value $content -Encoding UTF8 -NoNewline
    Write-Host "INFO: Template written: $targetPath"
    $count++
}

if ($count -eq 0) {
    Write-Warning "No templates were written."
} else {
    Write-Host "INFO: Completed writing $count template(s)."
}
