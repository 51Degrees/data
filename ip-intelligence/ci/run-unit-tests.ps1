#!/usr/bin/env pwsh
# Entry point / wrapper for this repo's unit tests.
#
# Runs the Pester test suite (tests/check-dl-script.tests.ps1) which exercises
# the data-file download scripts (get-lite-file-from-azure.ps1/.sh).
# An NUnit XML report is written to test-results/ for CI publishing.

[CmdletBinding()]
param(
    [string]$ResultsDir = "test-results/unit",
    [string]$ResultsFileName = "check-dl-script.xml"
)

$ErrorActionPreference = "Stop"

# Ensure Pester 5.x is available
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0.0' -and $_.Version -lt '6.0.0' })) {
    Write-Host "Installing Pester 5.x..."
    Install-Module -Name Pester -Force -Scope CurrentUser -SkipPublisherCheck -MaximumVersion 5.99.99
}
Import-Module Pester -MinimumVersion 5.0 -MaximumVersion 5.99.99

# Repo root is the parent of this ci/ directory.
$RepoRoot = Split-Path -Parent $PSScriptRoot
$TestFile = Join-Path $RepoRoot "tests/check-dl-script.tests.ps1"

if (-not (Test-Path -Path $TestFile -PathType Leaf)) {
    Write-Error "Test file not found: $TestFile"
    exit 1
}

# Ensure results directory exists.
$ResultsPath = Join-Path $RepoRoot $ResultsDir
New-Item -ItemType Directory -Force -Path $ResultsPath | Out-Null

# Tell the test suite where the download scripts live.
$env:DL_SCRIPTS_DIR = $RepoRoot

Write-Host "Running unit tests: $TestFile"

# Configure Pester.
$config = New-PesterConfiguration
$config.Run.Path = $TestFile
$config.Output.Verbosity = "Detailed"
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = Join-Path $ResultsPath $ResultsFileName
$config.TestResult.OutputFormat = "NUnitXml"

# Run Pester.
Invoke-Pester -Configuration $config

$code = $LASTEXITCODE
Write-Host "Unit tests finished with exit code $code. Report: $(Join-Path $ResultsPath $ResultsFileName)"
exit $code


