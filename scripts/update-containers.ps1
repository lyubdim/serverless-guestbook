param(
    [switch]$Apply
)

. "$PSScriptRoot\config.ps1"

Write-Host "This application uses Yandex Cloud Functions as backend replicas."
Write-Host "Serverless Containers are not part of this deployment."

if ($Apply) {
    Write-Host "Nothing to update for Serverless Containers."
} else {
    Write-Host "[DRY-RUN] Nothing to update for Serverless Containers."
}
