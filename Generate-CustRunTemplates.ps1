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
    throw "Failed to parse JSON from ${TemplateSpecPath}: $_"
}

$templates = @($spec.Templates)
if (-not $templates -or $templates.Count -eq 0) {
    Write-Warning "No templates found in $TemplateSpecPath (expected a 'Templates' array)."
    return
}

function Test-SafePath {
    param(
        [string]$FileName,
        [string]$TemplateRoot
    )

    # Reject absolute paths (check for root indicators)
    if ([IO.Path]::IsPathRooted($FileName)) {
        Write-Error "Rejected absolute path in FileName: $FileName"
        return $false
    }

    # Reject paths containing ".." segments (path traversal)
    # Regex matches ".." only as a complete path component (bounded by / or \ or start/end)
    # This allows legitimate filenames like "file..txt" while blocking "../" or "subdir/../"
    if ($FileName -match '(^|[\\/])\.\.($|[\\/])') {
        Write-Error "Rejected path with '..' segments in FileName: $FileName"
        return $false
    }

    # Construct and resolve the target path
    $targetPath = Join-Path $TemplateRoot $FileName
    try {
        $resolvedTarget = [IO.Path]::GetFullPath($targetPath)
        $resolvedRoot = [IO.Path]::GetFullPath($TemplateRoot)

        # Normalize path separators for comparison
        $resolvedTarget = $resolvedTarget.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $resolvedRoot = $resolvedRoot.Replace('/', [IO.Path]::DirectorySeparatorChar)

        # Ensure the resolved path is within the template root
        $rootWithSep = $resolvedRoot + [IO.Path]::DirectorySeparatorChar
        $isUnderRoot = $resolvedTarget.StartsWith($rootWithSep, [StringComparison]::OrdinalIgnoreCase)
        $isExactRoot = $resolvedTarget.Equals($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)
        
        if (-not ($isUnderRoot -or $isExactRoot)) {
            Write-Error "Rejected path outside template root: $FileName (resolves to $resolvedTarget, expected under $resolvedRoot)"
            return $false
        }
    } catch {
        Write-Error "Failed to resolve path for: $FileName"
        return $false
    }

    return $true
}

$count = 0
foreach ($tmpl in $templates) {
    $fileName = [string]$tmpl.FileName
    if ([string]::IsNullOrWhiteSpace($fileName)) {
        Write-Warning 'Encountered template entry without FileName. Skipping.'
        continue
    }

    # Validate the path before using it
    if (-not (Test-SafePath -FileName $fileName -TemplateRoot $TemplateRoot)) {
        Write-Warning "Skipping invalid template path: $fileName"
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
