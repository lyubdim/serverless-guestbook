param(
    [switch]$Apply
)

. "$PSScriptRoot\config.ps1"

$state = Get-State
if (-not $state) {
    Write-Host "No state file found."
    exit 0
}

if (-not $Apply) {
    Write-Host "[DRY-RUN] Delete API Gateway, function, YDB database, bucket objects, bucket, and service account."
    Write-Host "Run with -Apply only when the assignment no longer needs the app."
    exit 0
}

Invoke-Yc -Arguments @("serverless", "api-gateway", "delete", $state.gatewayName, "--folder-id", $state.folderId) -AllowFailure | Out-Null
Invoke-Yc -Arguments @("serverless", "function", "delete", $state.functionName, "--folder-id", $state.folderId) -AllowFailure | Out-Null
Invoke-Yc -Arguments @("ydb", "database", "delete", $state.databaseName, "--folder-id", $state.folderId) -AllowFailure | Out-Null

foreach ($object in @("index.html", "styles.css", "app.js")) {
    Invoke-Yc -Arguments @("storage", "s3", "rm", "s3://$($state.bucketName)/$object") -AllowFailure | Out-Null
}
Invoke-Yc -Arguments @("storage", "bucket", "delete", $state.bucketName, "--folder-id", $state.folderId) -AllowFailure | Out-Null
Invoke-Yc -Arguments @("iam", "service-account", "delete", $state.serviceAccountId, "--folder-id", $state.folderId) -AllowFailure | Out-Null

Write-Host "Cleanup completed."
