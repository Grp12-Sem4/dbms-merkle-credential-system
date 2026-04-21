param(
    [switch]$RefreshFirst,
    [switch]$NoExport
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$reportScript = Join-Path $PSScriptRoot "generate_integrity_report.py"
$reportsDir = Join-Path $repoRoot "reports"
$jsonOut = Join-Path $reportsDir "integrity_report.json"
$csvOut = Join-Path $reportsDir "integrity_report.csv"

. (Join-Path $PSScriptRoot "load_dotenv.ps1")
Import-DotEnvFile -Path (Join-Path $repoRoot ".env")

Write-Host "Integrity demo runner"
Write-Host ""
Write-Host "Prerequisites:"
Write-Host "  1. MySQL schema and sample data are loaded."
Write-Host "     Windows setup helper: .\scripts\load_integrity_db.ps1"
Write-Host "  2. Python dependencies are installed:"
Write-Host "     python -m pip install -r scripts/requirements.txt"
Write-Host "  3. DB_HOST, DB_PORT, DB_NAME, DB_USER, and DB_PASSWORD are in .env or process env."
Write-Host ""

$missing = @()
foreach ($name in @("DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD")) {
    if (-not [Environment]::GetEnvironmentVariable($name)) {
        $missing += $name
    }
}

if ($missing.Count -gt 0) {
    Write-Error ("Missing required environment variables: " + ($missing -join ", "))
    exit 2
}

$argsList = @(
    $reportScript,
    "--all-students",
    "--pretty"
)

if ($RefreshFirst) {
    $argsList += "--refresh-first"
}

if (-not $NoExport) {
    New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null
    $argsList += @("--json-out", $jsonOut, "--csv-out", $csvOut)
}

Write-Host "Running combined DB + Python integrity report..."
Write-Host ""

python @argsList
$exitCode = $LASTEXITCODE

if (-not $NoExport) {
    Write-Host ""
    Write-Host "Report files:"
    Write-Host "  $jsonOut"
    Write-Host "  $csvOut"
}

exit $exitCode
