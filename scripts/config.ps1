Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Script:DistDir = Join-Path $Script:RepoRoot "dist"
$Script:StatePath = Join-Path $Script:DistDir "state.json"
$Script:FunctionZipPath = Join-Path $Script:DistDir "function.zip"
$Script:GatewaySpecPath = Join-Path $Script:DistDir "api-gateway.yml"

$Script:ProjectName = "serverless-guestbook"
$Script:ServiceAccountName = "$Script:ProjectName-sa"
$Script:FunctionName = "$Script:ProjectName-api"
$Script:DatabaseName = "$Script:ProjectName-db"
$Script:GatewayName = "$Script:ProjectName-gw"
$Script:BackendVersion = "1.0.0"
$Script:FrontendVersion = "1.0.0"
$Script:FunctionRuntime = "python39"
$Script:TableName = "messages"

function Get-YcPath {
    if ($env:YC_PATH) {
        return $env:YC_PATH
    }

    $candidates = @(
        (Join-Path $Script:RepoRoot "..\tools\yc\yc.exe"),
        (Join-Path $Script:RepoRoot "tools\yc\yc.exe"),
        "yc"
    )

    foreach ($candidate in $candidates) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    throw "Yandex Cloud CLI was not found. Set YC_PATH or add yc to PATH."
}

$Script:YcPath = Get-YcPath

function Ensure-DistDir {
    New-Item -ItemType Directory -Force -Path $Script:DistDir | Out-Null
}

function Invoke-Yc {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $env:YC_CLI_INITIALIZATION_SILENCE = "true"
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $Script:YcPath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldErrorActionPreference
    }

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "yc failed: $($Arguments -join ' ')`n$output"
    }

    return $output
}

function Invoke-YcJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $jsonArgs = @($Arguments + @("--format", "json"))
    $env:YC_CLI_INITIALIZATION_SILENCE = "true"
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $Script:YcPath @jsonArgs 2>$null
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldErrorActionPreference
    }

    if ($exitCode -ne 0) {
        if ($AllowFailure) {
            return $null
        }
        throw "yc failed: $($jsonArgs -join ' ')"
    }

    if (-not $output) {
        return $null
    }

    return ($output | Out-String | ConvertFrom-Json)
}

function Test-Yc {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $env:YC_CLI_INITIALIZATION_SILENCE = "true"
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Script:YcPath @Arguments *> $null
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldErrorActionPreference
    }

    return ($exitCode -eq 0)
}

function Get-YcConfigValue {
    param([Parameter(Mandatory = $true)][string]$Name)

    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $value = & $Script:YcPath config get $Name 2>$null
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldErrorActionPreference
    }

    if ($exitCode -ne 0 -or -not $value) {
        throw "yc config value '$Name' is not set."
    }

    return ($value | Select-Object -First 1).Trim()
}

function Get-State {
    if (Test-Path -LiteralPath $Script:StatePath) {
        return Get-Content -LiteralPath $Script:StatePath -Raw | ConvertFrom-Json
    }

    return $null
}

function New-State {
    param(
        [Parameter(Mandatory = $true)][string]$FolderId,
        [Parameter(Mandatory = $true)][string]$CloudId
    )

    return [pscustomobject][ordered]@{
        projectName = $Script:ProjectName
        cloudId = $CloudId
        folderId = $FolderId
        bucketName = ("guestbook-$FolderId").ToLower()
        serviceAccountName = $Script:ServiceAccountName
        serviceAccountId = ""
        databaseName = $Script:DatabaseName
        ydbEndpoint = ""
        ydbDatabase = ""
        functionName = $Script:FunctionName
        functionId = ""
        gatewayName = $Script:GatewayName
        gatewayDomain = ""
        frontendVersion = $Script:FrontendVersion
        backendVersion = $Script:BackendVersion
    }
}

function Save-State {
    param([Parameter(Mandatory = $true)][object]$State)

    Ensure-DistDir
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Script:StatePath -Encoding ascii
}

function Get-OrCreateState {
    param([string]$FolderId = "", [string]$CloudId = "")

    Ensure-DistDir
    $state = Get-State

    if ($state) {
        return $state
    }

    if (-not $FolderId) {
        $FolderId = Get-YcConfigValue -Name "folder-id"
    }
    if (-not $CloudId) {
        $CloudId = Get-YcConfigValue -Name "cloud-id"
    }

    $state = New-State -FolderId $FolderId -CloudId $CloudId
    Save-State -State $state
    return Get-State
}

function Get-YdbConnection {
    param([Parameter(Mandatory = $true)][object]$Database)

    $rawEndpoint = ""
    $databasePath = ""

    if ($Database.PSObject.Properties.Match("endpoint").Count -gt 0) {
        $rawEndpoint = $Database.endpoint
    }
    if ($Database.PSObject.Properties.Match("database_path").Count -gt 0) {
        $databasePath = $Database.database_path
    }

    $endpoint = $rawEndpoint

    if ($rawEndpoint -match "^(?<endpoint>[^?]+)\?database=(?<database>.+)$") {
        $endpoint = $Matches.endpoint
        $databasePath = $Matches.database
    }

    if ($endpoint -and -not $endpoint.StartsWith("grpcs://")) {
        $endpoint = "grpcs://$endpoint"
    }
    if ($endpoint) {
        $endpoint = $endpoint.TrimEnd("/")
    }
    if (-not $databasePath -and $Database.PSObject.Properties.Match("path").Count -gt 0) {
        $databasePath = $Database.path
    }
    if (-not $endpoint -or -not $databasePath) {
        throw "Could not parse YDB endpoint/database from yc output."
    }

    return [pscustomobject]@{
        endpoint = $endpoint
        database = $databasePath
    }
}

function New-FunctionPackage {
    Ensure-DistDir

    if (Test-Path -LiteralPath $Script:FunctionZipPath) {
        Remove-Item -LiteralPath $Script:FunctionZipPath -Force
    }

    $functionDir = Join-Path $Script:RepoRoot "app\function"
    $packageFiles = Get-ChildItem -LiteralPath $functionDir -File | Where-Object {
        $_.Name -in @("index.py", "requirements.txt")
    }
    Compress-Archive -Path $packageFiles.FullName -DestinationPath $Script:FunctionZipPath -Force
    return $Script:FunctionZipPath
}

function Write-GatewaySpec {
    param([Parameter(Mandatory = $true)][object]$State)

    $templatePath = Join-Path $Script:RepoRoot "infra\api-gateway.yml.template"
    $spec = Get-Content -LiteralPath $templatePath -Raw
    $spec = $spec.Replace("__BUCKET_NAME__", $State.bucketName)
    $spec = $spec.Replace("__SERVICE_ACCOUNT_ID__", $State.serviceAccountId)
    $spec = $spec.Replace("__FUNCTION_ID__", $State.functionId)
    $spec | Set-Content -LiteralPath $Script:GatewaySpecPath -Encoding ascii
    return $Script:GatewaySpecPath
}
