param(
    [string]$RepositoryUrl = "https://github.com/<username>/serverless-guestbook"
)

. "$PSScriptRoot\config.ps1"

$state = Get-State
if (-not $state) {
    throw "State file was not found. Run scripts/deploy-all.ps1 at least once in dry-run mode."
}

$folderUrl = "https://console.yandex.cloud/folders/$($state.folderId)"
$appUrl = if ($state.gatewayDomain) { $state.gatewayDomain } else { "https://<api_gateway_domain>" }

Write-Host "Folder URL"
Write-Host $folderUrl
Write-Host ""
Write-Host "Repository URL"
Write-Host $RepositoryUrl
Write-Host ""
Write-Host "Application URL"
Write-Host $appUrl
Write-Host ""
Write-Host "Comments"
Write-Host @"
Application: unauthenticated serverless guestbook.
Frontend is stored in Object Storage and served through API Gateway. The UI shows frontend version v$($state.frontendVersion).
Backend is implemented with Yandex Cloud Functions: two function versions tagged replica-a and replica-b. The UI shows backend version v$($state.backendVersion) and the current replica.
API Gateway uses canary release 50/50, so repeated requests are routed to different backend replicas.
Guestbook messages are stored in Serverless YDB table messages.
PowerShell scripts for deployment, function updates, and YDB schema creation are in scripts/.
"@
