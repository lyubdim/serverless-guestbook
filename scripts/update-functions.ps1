param(
    [switch]$Apply
)

. "$PSScriptRoot\config.ps1"

$state = Get-OrCreateState

if (-not $state.serviceAccountId -or -not $state.ydbEndpoint -or -not $state.ydbDatabase) {
    throw "State is incomplete. Run scripts/deploy-all.ps1 -Apply first."
}

if (-not $Apply) {
    Write-Host "[DRY-RUN] Package and deploy two Cloud Function versions:"
    Write-Host "          replica-a and replica-b for $($state.functionName)."
    Write-Host "Run with -Apply to create new versions."
    exit 0
}

if (-not (Test-Yc -Arguments @("serverless", "function", "get", "--name", $state.functionName, "--folder-id", $state.folderId))) {
    Invoke-Yc -Arguments @(
        "serverless", "function", "create",
        "--name", $state.functionName,
        "--description", "Guestbook API backend with two serverless replicas",
        "--folder-id", $state.folderId
    ) | Out-Null
}

$function = Invoke-YcJson -Arguments @("serverless", "function", "get", "--name", $state.functionName, "--folder-id", $state.folderId)
$state.functionId = $function.id
Save-State -State $state

$zipPath = New-FunctionPackage

foreach ($replica in @("a", "b")) {
    $tag = "replica-$replica"
    $version = Invoke-YcJson -Arguments @(
        "serverless", "function", "version", "create",
        "--function-name", $state.functionName,
        "--memory", "256m",
        "--execution-timeout", "20s",
        "--runtime", $Script:FunctionRuntime,
        "--entrypoint", "index.handler",
        "--service-account-id", $state.serviceAccountId,
        "--environment", "USE_METADATA_CREDENTIALS=1",
        "--environment", "endpoint=$($state.ydbEndpoint)",
        "--environment", "database=$($state.ydbDatabase)",
        "--environment", "TABLE_NAME=$Script:TableName",
        "--environment", "BACKEND_VERSION=$($state.backendVersion)",
        "--environment", "BACKEND_REPLICA=$replica",
        "--source-path", $zipPath,
        "--folder-id", $state.folderId
    )

    Invoke-Yc -Arguments @(
        "serverless", "function", "version", "set-tag",
        "--id", $version.id,
        "--tag", $tag,
        "--folder-id", $state.folderId
    ) | Out-Null

    Write-Host "Published $tag as version $($version.id)."
}

Write-Host "Function update completed."
