# Kept so that scripts that call it keep working. Downloads the IP
# Intelligence Lite and Asn files with ../get-data-files.ps1, which gets them
# from the Distributor and saves them in this folder.
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Lite,
    [switch]$Asn
)
$ErrorActionPreference = 'Stop'

# Both files unless one is asked for.
$names = @()
if ($Lite -or -not $Asn) { $names += '51Degrees-LiteV41.ipi' }
if ($Asn -or -not $Lite) { $names += '51Degrees-IPIV4AsnIpiV41.ipi' }
& (Join-Path (Split-Path $PSScriptRoot -Parent) 'get-data-files.ps1') @names -Force:$Force
exit $LASTEXITCODE
