Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $repoRoot

try {
    Write-Host "Checking PowerShell syntax..."
    $hasErrors = $false
    Get-ChildItem -Path ".\scripts" -Filter "*.ps1" | ForEach-Object {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
        if ($errors.Count -gt 0) {
            $hasErrors = $true
            Write-Host "ERROR in $($_.Name)"
            $errors | ForEach-Object { Write-Host $_.Message }
        }
    }
    if ($hasErrors) {
        throw "PowerShell syntax check failed."
    }

    Write-Host "Checking Python syntax..."
    python -m py_compile ".\app\function\index.py"
    if ($LASTEXITCODE -ne 0) {
        throw "Python syntax check failed."
    }

    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node) {
        Write-Host "Checking frontend JavaScript syntax..."
        node --check ".\app\frontend\app.js"
        if ($LASTEXITCODE -ne 0) {
            throw "JavaScript syntax check failed."
        }
    } else {
        Write-Host "Node.js not found, skipping JavaScript syntax check."
    }

    Write-Host "Checking deploy dry-run..."
    powershell -ExecutionPolicy Bypass -File ".\scripts\deploy-all.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "Deploy dry-run failed."
    }

    Write-Host "Local checks passed."
} finally {
    Pop-Location
}
