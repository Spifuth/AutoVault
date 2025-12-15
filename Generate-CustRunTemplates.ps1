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
    throw "VaultRoot is not set. Please run via cust-run-config.ps1 or update cust-run-config.ps1 to set VaultRoot."
}

if (-not $TemplateRelativeRoot) {
    $TemplateRelativeRoot = '_templates\Run'
}

$NormalizedTemplateRoot = $TemplateRelativeRoot -replace '\\', [IO.Path]::DirectorySeparatorChar
$TemplateRoot = Join-Path $VaultRoot $NormalizedTemplateRoot

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

    # Harden $fileName against path traversal and absolute path issues
    if ([IO.Path]::IsPathRooted($fileName)) {
        Write-Warning "Template FileName is an absolute path: '$fileName'. Skipping."
        continue
    }
    if ($fileName -split '[\\/]' | Where-Object { $_ -eq '..' }) {
        Write-Warning "Template FileName contains parent directory traversal '..': '$fileName'. Skipping."
        continue
    }

    $content = [string]$tmpl.Content
    $targetPath = Join-Path $TemplateRoot $fileName
    # Resolve full paths for comparison
    $resolvedTemplateRoot = [IO.Path]::GetFullPath($TemplateRoot)
    $resolvedTargetPath = [IO.Path]::GetFullPath($targetPath)
    if (-not ($resolvedTargetPath.StartsWith($resolvedTemplateRoot, [StringComparison]::OrdinalIgnoreCase))) {
        Write-Warning "Template FileName escapes template root: '$fileName' -> '$resolvedTargetPath'. Skipping."
        continue
    }
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
