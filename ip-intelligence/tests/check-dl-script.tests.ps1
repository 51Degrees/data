#!/usr/bin/env pwsh
# Pester test suite for get-lite-file-from-azure.ps1/.sh download scripts.
#
# Data-driven tests: one case per (script x invocation mode). Each case
# performs a REAL download from Azure blob storage into an isolated temp dir.

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Describe "get-lite-file-from-azure.ps1" {
    BeforeAll {
        # File names produced by the scripts
        $script:LiteIpi = "51Degrees-LiteV41.ipi"
        $script:AsnIpi = "51Degrees-IPIV4AsnIpiV41.ipi"
        $script:LiteGz = "$script:LiteIpi.gz"
        $script:AsnGz = "$script:AsnIpi.gz"

        # Resolve repo root
        $script:RepoRoot = $env:DL_SCRIPTS_DIR ?? $PSScriptRoot
        if (-not (Test-Path (Join-Path $script:RepoRoot "get-lite-file-from-azure.ps1"))) {
            $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        }

        function New-TestDir {
            $baseDir = [System.IO.Path]::GetTempPath()
            $dir = Join-Path $baseDir "dl-script-test-$(New-Guid)"
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            return $dir
        }

        function Invoke-DownloadScript {
            param(
                [string]$ScriptName,
                [string]$WorkDir,
                [string[]]$ScriptArgs = @()
            )
            
            $scriptPath = Join-Path $script:RepoRoot $ScriptName
            if (-not (Test-Path $scriptPath)) {
                throw "Script not found: $scriptPath"
            }
            
            $isSh = $ScriptName.EndsWith(".sh")
            
            Write-Host "Executing: $ScriptName $ScriptArgs" -ForegroundColor Cyan
            Push-Location $WorkDir
            try {
                if ($isSh) {
                    & bash $scriptPath @ScriptArgs 2>&1 | Out-String | Write-Host
                    $exitCode = $LASTEXITCODE
                }
                else {
                    & pwsh -NoProfile -File $scriptPath @ScriptArgs 2>&1 | Out-String | Write-Host
                    $exitCode = $LASTEXITCODE
                }
            }
            finally {
                Pop-Location
            }
            
            Write-Host "Exit code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { "Green" } else { "Red" })
            return $exitCode
        }

        function Test-ValidDownload {
            param(
                [string]$WorkDir,
                [string]$GzName,
                [string]$IpiName
            )
            
            $gzPath = Join-Path $WorkDir $GzName
            $ipiPath = Join-Path $WorkDir $IpiName
            
            Write-Host "Checking: $GzName"
            (Test-Path $gzPath) | Should -BeTrue -Because "$GzName should exist"
            
            $gzInfo = Get-Item $gzPath
            $gzInfo.Length | Should -BeGreaterThan 0 -Because "$GzName should not be empty"
            Write-Host "  Size: $([math]::Round($gzInfo.Length / 1MB, 2)) MB"
            
            Write-Host "Checking: $IpiName"
            (Test-Path $ipiPath) | Should -BeTrue -Because "$IpiName should exist"
            
            $ipiInfo = Get-Item $ipiPath
            $ipiInfo.Length | Should -BeGreaterThan $gzInfo.Length -Because "$IpiName should be larger than archive"
            Write-Host "  Size: $([math]::Round($ipiInfo.Length / 1MB, 2)) MB (extracted)"
        }

        function Test-FileAbsent {
            param(
                [string]$WorkDir,
                [string]$GzName,
                [string]$IpiName
            )
            
            Write-Host "Verifying absent: $GzName, $IpiName"
            (Test-Path (Join-Path $WorkDir $GzName)) | Should -BeFalse -Because "$GzName should NOT exist"
            (Test-Path (Join-Path $WorkDir $IpiName)) | Should -BeFalse -Because "$IpiName should NOT exist"
        }
    }

    BeforeEach {
        $script:TestDir = New-TestDir
        Write-Host "`n--- Test directory: $script:TestDir ---" -ForegroundColor Yellow
    }
    
    AfterEach {
        Write-Host "--- Cleaning up: $script:TestDir ---" -ForegroundColor Yellow
        Remove-Item $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    It "Downloads both files (no args)" {
        $exitCode = Invoke-DownloadScript -ScriptName "get-lite-file-from-azure.ps1" -WorkDir $script:TestDir
        $exitCode | Should -Be 0
        
        Test-ValidDownload -WorkDir $script:TestDir -GzName $script:LiteGz -IpiName $script:LiteIpi
        Test-ValidDownload -WorkDir $script:TestDir -GzName $script:AsnGz -IpiName $script:AsnIpi
    }
    
    It "Downloads Lite only (-Lite)" {
        $exitCode = Invoke-DownloadScript -ScriptName "get-lite-file-from-azure.ps1" -WorkDir $script:TestDir -ScriptArgs "-Lite"
        $exitCode | Should -Be 0
        
        Test-ValidDownload -WorkDir $script:TestDir -GzName $script:LiteGz -IpiName $script:LiteIpi
        Test-FileAbsent -WorkDir $script:TestDir -GzName $script:AsnGz -IpiName $script:AsnIpi
    }
    
    It "Downloads Asn only (-Asn)" {
        $exitCode = Invoke-DownloadScript -ScriptName "get-lite-file-from-azure.ps1" -WorkDir $script:TestDir -ScriptArgs "-Asn"
        $exitCode | Should -Be 0
        
        Test-FileAbsent -WorkDir $script:TestDir -GzName $script:LiteGz -IpiName $script:LiteIpi
        Test-ValidDownload -WorkDir $script:TestDir -GzName $script:AsnGz -IpiName $script:AsnIpi
    }
    
    It "Forces re-download (-Force)" {
        # Pre-seed dummy files
        $stale = (Get-Date).AddDays(-1)
        @($script:LiteGz, $script:AsnGz, $script:LiteIpi, $script:AsnIpi) | ForEach-Object {
            $path = Join-Path $script:TestDir $_
            "dummy" | Out-File -FilePath $path
            (Get-Item $path).LastWriteTime = $stale
            Write-Host "Seeded dummy: $_"
        }
        
        $exitCode = Invoke-DownloadScript -ScriptName "get-lite-file-from-azure.ps1" -WorkDir $script:TestDir -ScriptArgs "-Force"
        $exitCode | Should -Be 0
        
        Test-ValidDownload -WorkDir $script:TestDir -GzName $script:LiteGz -IpiName $script:LiteIpi
        Test-ValidDownload -WorkDir $script:TestDir -GzName $script:AsnGz -IpiName $script:AsnIpi
    }
}

# Skip .sh tests on Windows
if (-not $IsWindows) {
    Describe "get-lite-file-from-azure.sh" {
        BeforeAll {
            # File names produced by the scripts
            $script:LiteIpi = "51Degrees-LiteV41.ipi"
            $script:AsnIpi = "51Degrees-IPIV4AsnIpiV41.ipi"
            $script:LiteGz = "$script:LiteIpi.gz"
            $script:AsnGz = "$script:AsnIpi.gz"

            # Resolve repo root
            $script:RepoRoot = $env:DL_SCRIPTS_DIR ?? $PSScriptRoot
            if (-not (Test-Path (Join-Path $script:RepoRoot "get-lite-file-from-azure.ps1"))) {
                $script:RepoRoot = Split-Path -Parent $PSScriptRoot
            }

            function New-TestDir {
                $baseDir = [System.IO.Path]::GetTempPath()
                $dir = Join-Path $baseDir "dl-script-test-$(New-Guid)"
                New-Item -ItemType Directory -Force -Path $dir | Out-Null
                return $dir
            }

            function Invoke-DownloadScript {
                param([string]$ScriptName, [string]$WorkDir, [string[]]$ScriptArgs = @())
                $scriptPath = Join-Path $script:RepoRoot $ScriptName
                Write-Host "Executing: $ScriptName $ScriptArgs" -ForegroundColor Cyan
                Push-Location $WorkDir
                try { 
                    & bash $scriptPath @ScriptArgs 2>&1 | Out-String | Write-Host
                    $exitCode = $LASTEXITCODE 
                }
                finally { Pop-Location }
                Write-Host "Exit code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { "Green" } else { "Red" })
                return $exitCode
            }

            function Test-ValidDownload {
                param([string]$WorkDir, [string]$GzName, [string]$IpiName)
                $gzPath = Join-Path $WorkDir $GzName
                $ipiPath = Join-Path $WorkDir $IpiName
                Write-Host "Checking: $GzName"
                (Test-Path $gzPath) | Should -BeTrue
                $gzInfo = Get-Item $gzPath
                $gzInfo.Length | Should -BeGreaterThan 0
                Write-Host "  Size: $([math]::Round($gzInfo.Length / 1MB, 2)) MB"
                Write-Host "Checking: $IpiName"
                (Test-Path $ipiPath) | Should -BeTrue
                $ipiInfo = Get-Item $ipiPath
                $ipiInfo.Length | Should -BeGreaterThan $gzInfo.Length
                Write-Host "  Size: $([math]::Round($ipiInfo.Length / 1MB, 2)) MB (extracted)"
            }

            function Test-FileAbsent {
                param([string]$WorkDir, [string]$GzName, [string]$IpiName)
                Write-Host "Verifying absent: $GzName, $IpiName"
                (Test-Path (Join-Path $WorkDir $GzName)) | Should -BeFalse
                (Test-Path (Join-Path $WorkDir $IpiName)) | Should -BeFalse
            }
        }

        BeforeEach {
            $script:TestDir = New-TestDir
            Write-Host "`n--- Test directory: $script:TestDir ---" -ForegroundColor Yellow
        }
        
        AfterEach {
            Write-Host "--- Cleaning up: $script:TestDir ---" -ForegroundColor Yellow
            Remove-Item $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        It "Downloads both files (no args)" {
            $exitCode = Invoke-DownloadScript -ScriptName "get-lite-file-from-azure.sh" -WorkDir $script:TestDir
            $exitCode | Should -Be 0
            Test-ValidDownload -WorkDir $script:TestDir -GzName $script:LiteGz -IpiName $script:LiteIpi
            Test-ValidDownload -WorkDir $script:TestDir -GzName $script:AsnGz -IpiName $script:AsnIpi
        }
        
        It "Downloads Lite only (-lite)" {
            $exitCode = Invoke-DownloadScript -ScriptName "get-lite-file-from-azure.sh" -WorkDir $script:TestDir -ScriptArgs "-lite"
            $exitCode | Should -Be 0
            Test-ValidDownload -WorkDir $script:TestDir -GzName $script:LiteGz -IpiName $script:LiteIpi
            Test-FileAbsent -WorkDir $script:TestDir -GzName $script:AsnGz -IpiName $script:AsnIpi
        }
        
        It "Downloads Asn only (-asn)" {
            $exitCode = Invoke-DownloadScript -ScriptName "get-lite-file-from-azure.sh" -WorkDir $script:TestDir -ScriptArgs "-asn"
            $exitCode | Should -Be 0
            Test-FileAbsent -WorkDir $script:TestDir -GzName $script:LiteGz -IpiName $script:LiteIpi
            Test-ValidDownload -WorkDir $script:TestDir -GzName $script:AsnGz -IpiName $script:AsnIpi
        }
        
        It "Forces re-download (-force)" {
            $stale = (Get-Date).AddDays(-1)
            @($script:LiteGz, $script:AsnGz, $script:LiteIpi, $script:AsnIpi) | ForEach-Object {
                $path = Join-Path $script:TestDir $_
                "dummy" | Out-File -FilePath $path
                (Get-Item $path).LastWriteTime = $stale
                Write-Host "Seeded dummy: $_"
            }
            $exitCode = Invoke-DownloadScript -ScriptName "get-lite-file-from-azure.sh" -WorkDir $script:TestDir -ScriptArgs "-force"
            $exitCode | Should -Be 0
            Test-ValidDownload -WorkDir $script:TestDir -GzName $script:LiteGz -IpiName $script:LiteIpi
            Test-ValidDownload -WorkDir $script:TestDir -GzName $script:AsnGz -IpiName $script:AsnIpi
        }
    }
}
else {
    Write-Host "Skipping get-lite-file-from-azure.sh tests on Windows" -ForegroundColor DarkGray
}

