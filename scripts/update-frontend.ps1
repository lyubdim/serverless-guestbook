param(
    [switch]$Apply
)

. "$PSScriptRoot\config.ps1"

$state = Get-OrCreateState
$frontendDir = Join-Path $Script:RepoRoot "app\frontend"

if (-not $Apply) {
    Write-Host "[DRY-RUN] Upload frontend files from $frontendDir to bucket $($state.bucketName)."
    Write-Host "Run with -Apply to upload objects."
    exit 0
}

foreach ($file in @(
    @{ Name = "index.html"; Type = "text/html; charset=utf-8" },
    @{ Name = "styles.css"; Type = "text/css; charset=utf-8" },
    @{ Name = "app.js"; Type = "application/javascript; charset=utf-8" }
)) {
    $path = Join-Path $frontendDir $file.Name
    Invoke-Yc -Arguments @(
        "storage", "s3", "cp", $path, "s3://$($state.bucketName)/$($file.Name)",
        "--content-type", $file.Type,
        "--cache-control", "no-cache"
    ) | Out-Null
}

Write-Host "Frontend uploaded to bucket $($state.bucketName)."
