param(
    [switch]$Apply
)

. "$PSScriptRoot\config.ps1"

$state = Get-OrCreateState

if (-not $state.functionName) {
    throw "Function name is missing from state. Run scripts/deploy-all.ps1 -Apply first."
}

if (-not $Apply) {
    Write-Host "[DRY-RUN] Invoke $($state.functionName):replica-a with maintenanceAction=migrate."
    Write-Host "Schema file: infra/schema.yql"
    Write-Host "Run with -Apply to create/update YDB schema."
    exit 0
}

$payload = '{"maintenanceAction":"migrate"}'
$result = Invoke-Yc -Arguments @(
    "serverless", "function", "invoke", $state.functionName,
    "--tag", "replica-a",
    "--data", $payload,
    "--folder-id", $state.folderId
)

Write-Host ($result | Out-String)
Write-Host "YDB schema migration completed."
