param(
    [string]$ReviewerLogin = "digisturm@yandex.ru",
    [switch]$Apply
)

. "$PSScriptRoot\config.ps1"

$state = Get-OrCreateState

if (-not $Apply) {
    Write-Host "[DRY-RUN] Grant reviewer access for $ReviewerLogin."
    Write-Host "Roles:"
    Write-Host "  cloud: resource-manager.clouds.member"
    Write-Host "  folder: admin"
    Write-Host "Run with -Apply after adding the account to the organization."
    exit 0
}

$user = Invoke-YcJson -Arguments @("iam", "user-account", "get", "--login", $ReviewerLogin)

Invoke-Yc -Arguments @(
    "resource-manager", "cloud", "add-access-binding", $state.cloudId,
    "--subject", "userAccount:$($user.id)",
    "--role", "resource-manager.clouds.member"
) | Out-Null

Invoke-Yc -Arguments @(
    "resource-manager", "folder", "add-access-binding", $state.folderId,
    "--subject", "userAccount:$($user.id)",
    "--role", "admin"
) | Out-Null

Write-Host "Access granted to $ReviewerLogin."
