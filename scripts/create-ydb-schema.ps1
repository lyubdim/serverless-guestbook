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

$payload = "migrate"
$result = Invoke-Yc -Arguments @(
    "serverless", "function", "invoke", $state.functionName,
    "--tag", "replica-a",
    "--data", $payload,
    "--folder-id", $state.folderId
)

$resultText = ($result | Out-String).Trim()
Write-Host $resultText

try {
    $parsed = $resultText | ConvertFrom-Json
    if ($parsed.PSObject.Properties.Match("statusCode").Count -gt 0 -and [int]$parsed.statusCode -ge 400) {
        throw "Migration function returned HTTP $($parsed.statusCode): $($parsed.body)"
    }
    if ($parsed.PSObject.Properties.Match("ok").Count -gt 0 -and -not $parsed.ok) {
        throw "Migration function returned ok=false."
    }
} catch {
    throw "Could not confirm YDB schema migration success. Raw result: $resultText. Error: $_"
}

Write-Host "YDB schema migration completed."
