param(
    [string]$HostName,
    [string]$Port,
    [string]$DatabaseName,
    [string]$User,
    [string]$Password,
    [switch]$LoadSchemaOnly,
    [switch]$LoadSampleData,
    [switch]$RunSmokeTest,
    [switch]$RunDemo,
    [switch]$SkipLoad
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$databaseDir = Join-Path $repoRoot "database"

. (Join-Path $PSScriptRoot "load_dotenv.ps1")
Import-DotEnvFile -Path (Join-Path $repoRoot ".env")

if ([string]::IsNullOrWhiteSpace($HostName)) {
    $HostName = [Environment]::GetEnvironmentVariable("DB_HOST", "Process")
}
if ([string]::IsNullOrWhiteSpace($Port)) {
    $Port = [Environment]::GetEnvironmentVariable("DB_PORT", "Process")
}
if ([string]::IsNullOrWhiteSpace($DatabaseName)) {
    $DatabaseName = [Environment]::GetEnvironmentVariable("DB_NAME", "Process")
}
if ([string]::IsNullOrWhiteSpace($User)) {
    $User = [Environment]::GetEnvironmentVariable("DB_USER", "Process")
}
if ([string]::IsNullOrWhiteSpace($Password)) {
    $Password = [Environment]::GetEnvironmentVariable("DB_PASSWORD", "Process")
}

function Require-Value {
    param(
        [string]$Name,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-Error "Missing required database setting: $Name. Set `$env:$Name or pass the corresponding parameter."
        exit 2
    }
}

function Invoke-MysqlSource {
    param(
        [string]$SqlPath,
        [switch]$UseDatabase
    )

    $fullPath = (Resolve-Path $SqlPath).Path.Replace("\", "/")
    $mysqlArgs = @(
        "--host=$HostName",
        "--port=$Port",
        "--user=$User",
        "--execute=SOURCE $fullPath"
    )

    if ($UseDatabase) {
        $mysqlArgs = @(
            "--host=$HostName",
            "--port=$Port",
            "--user=$User",
            $DatabaseName,
            "--execute=SOURCE $fullPath"
        )
    }

    $oldMysqlPwd = [Environment]::GetEnvironmentVariable("MYSQL_PWD", "Process")
    [Environment]::SetEnvironmentVariable("MYSQL_PWD", $Password, "Process")

    Push-Location $repoRoot
    try {
        mysql @mysqlArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "mysql failed while loading $SqlPath"
            exit $LASTEXITCODE
        }
    }
    finally {
        Pop-Location
        [Environment]::SetEnvironmentVariable("MYSQL_PWD", $oldMysqlPwd, "Process")
    }
}

Require-Value -Name "DB_HOST" -Value $HostName
Require-Value -Name "DB_PORT" -Value $Port
Require-Value -Name "DB_NAME" -Value $DatabaseName
Require-Value -Name "DB_USER" -Value $User
Require-Value -Name "DB_PASSWORD" -Value $Password

if (-not (Get-Command mysql -ErrorAction SilentlyContinue)) {
    Write-Error "mysql CLI was not found on PATH. Install MySQL client tools or add mysql.exe to PATH."
    exit 2
}

if ($DatabaseName -ne "credential_verifiability_system") {
    Write-Host "Warning: schema.sql creates database credential_verifiability_system."
    Write-Host "         Current DB_NAME/DatabaseName is $DatabaseName."
    Write-Host "         Use DB_NAME=credential_verifiability_system unless schema.sql is changed."
    Write-Host ""
}

if (-not ($LoadSchemaOnly -or $LoadSampleData -or $RunSmokeTest -or $RunDemo -or $SkipLoad)) {
    $LoadSampleData = $true
}

Write-Host "Integrity DB loader"
Write-Host "Host: $HostName"
Write-Host "Port: $Port"
Write-Host "Database: $DatabaseName"
Write-Host ""

if ($RunSmokeTest) {
    Write-Host "Running fresh smoke test: schema + sample data + integrity checks + demo"
    Invoke-MysqlSource -SqlPath (Join-Path $databaseDir "integrity_smoke_test.sql")
    Write-Host "Smoke test completed."
    exit 0
}

if (-not $SkipLoad) {
    Write-Host "Loading schema.sql"
    Invoke-MysqlSource -SqlPath (Join-Path $databaseDir "schema.sql")

    if (-not $LoadSchemaOnly -or $LoadSampleData) {
        Write-Host "Loading sample_data.sql"
        Invoke-MysqlSource -SqlPath (Join-Path $databaseDir "sample_data.sql") -UseDatabase
    }
}
elseif (-not $RunDemo) {
    Write-Error "Nothing to do. Use -RunDemo with -SkipLoad, or omit -SkipLoad to load schema/sample data."
    exit 2
}

if ($RunDemo) {
    Write-Host "Running integrity_demo.sql"
    Invoke-MysqlSource -SqlPath (Join-Path $databaseDir "integrity_demo.sql") -UseDatabase
}

Write-Host "Database load complete."
