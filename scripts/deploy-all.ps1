param(
    [switch]$Apply,
    [string]$FolderId = "",
    [string]$CloudId = ""
)

. "$PSScriptRoot\config.ps1"

if (-not $FolderId) {
    $FolderId = Get-YcConfigValue -Name "folder-id"
}
if (-not $CloudId) {
    $CloudId = Get-YcConfigValue -Name "cloud-id"
}

$state = Get-OrCreateState -FolderId $FolderId -CloudId $CloudId

if (-not $Apply) {
    Write-Host "[DRY-RUN] Full deployment plan:"
    Write-Host "  folder: $($state.folderId)"
    Write-Host "  service account: $($state.serviceAccountName)"
    Write-Host "  bucket: $($state.bucketName)"
    Write-Host "  YDB database: $($state.databaseName)"
    Write-Host "  function: $($state.functionName), tags replica-a/replica-b"
    Write-Host "  API Gateway: $($state.gatewayName), canary 50% to replica-b"
    Write-Host "Run with -Apply to create serverless resources."
    exit 0
}

Write-Host "Deploying $($state.projectName) to folder $($state.folderId)."

$serviceAccounts = Invoke-YcJson -Arguments @("iam", "service-account", "list", "--folder-id", $state.folderId)
$serviceAccount = $serviceAccounts | Where-Object { $_.name -eq $state.serviceAccountName } | Select-Object -First 1
if (-not $serviceAccount) {
    $serviceAccount = Invoke-YcJson -Arguments @(
        "iam", "service-account", "create",
        "--name", $state.serviceAccountName,
        "--description", "Service account for serverless guestbook",
        "--folder-id", $state.folderId
    )
}
$state.serviceAccountId = $serviceAccount.id
Save-State -State $state

foreach ($role in @("ydb.editor", "storage.viewer", "functions.functionInvoker")) {
    Invoke-Yc -Arguments @(
        "resource-manager", "folder", "add-access-binding", $state.folderId,
        "--subject", "serviceAccount:$($state.serviceAccountId)",
        "--role", $role
    ) -AllowFailure | Out-Null
}

if (-not (Test-Yc -Arguments @("storage", "bucket", "get", $state.bucketName, "--folder-id", $state.folderId))) {
    Invoke-Yc -Arguments @(
        "storage", "bucket", "create", $state.bucketName,
        "--max-size", "1073741824",
        "--default-storage-class", "STANDARD",
        "--folder-id", $state.folderId
    ) | Out-Null
}

if (-not (Test-Yc -Arguments @("ydb", "database", "get", "--name", $state.databaseName, "--folder-id", $state.folderId))) {
    Invoke-Yc -Arguments @(
        "ydb", "database", "create", $state.databaseName,
        "--serverless",
        "--sls-provisioned-rcu", "0",
        "--sls-storage-size", "1GB",
        "--folder-id", $state.folderId
    ) | Out-Null
}

$database = Invoke-YcJson -Arguments @("ydb", "database", "get", "--name", $state.databaseName, "--folder-id", $state.folderId)
$connection = Get-YdbConnection -Database $database
$state.ydbEndpoint = $connection.endpoint
$state.ydbDatabase = $connection.database
Save-State -State $state

& (Join-Path $PSScriptRoot "update-frontend.ps1") -Apply
& (Join-Path $PSScriptRoot "update-functions.ps1") -Apply
& (Join-Path $PSScriptRoot "create-ydb-schema.ps1") -Apply

$state = Get-State
$specPath = Write-GatewaySpec -State $state

if (Test-Yc -Arguments @("serverless", "api-gateway", "get", "--name", $state.gatewayName, "--folder-id", $state.folderId)) {
    Invoke-Yc -Arguments @(
        "serverless", "api-gateway", "update", $state.gatewayName,
        "--spec", $specPath,
        "--description", "Serverless guestbook frontend and API",
        "--variables", "backend.tag=replica-a",
        "--canary-weight", "50",
        "--canary-variables", "backend.tag=replica-b",
        "--folder-id", $state.folderId
    ) | Out-Null
} else {
    Invoke-Yc -Arguments @(
        "serverless", "api-gateway", "create",
        "--name", $state.gatewayName,
        "--spec", $specPath,
        "--description", "Serverless guestbook frontend and API",
        "--variables", "backend.tag=replica-a",
        "--canary-weight", "50",
        "--canary-variables", "backend.tag=replica-b",
        "--folder-id", $state.folderId
    ) | Out-Null
}

$gateway = Invoke-YcJson -Arguments @("serverless", "api-gateway", "get", "--name", $state.gatewayName, "--folder-id", $state.folderId)
$domain = $gateway.domain
if ($domain -and -not $domain.StartsWith("http")) {
    $domain = "https://$domain"
}
$state.gatewayDomain = $domain.TrimEnd("/")
Save-State -State $state

Write-Host "Deployment completed."
Write-Host "Application URL: $($state.gatewayDomain)"
Write-Host "Folder URL: https://console.yandex.cloud/folders/$($state.folderId)"
