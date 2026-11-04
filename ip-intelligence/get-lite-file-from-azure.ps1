using namespace System.IO

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Lite,
    [switch]$Asn
)

# Base URL for all data files
$BaseUrl = "https://51ddatafiles.blob.core.windows.net/enterpriseipi/"

# Known files: remote basename + local .ipi name
$KnownFiles = @(
    [pscustomobject]@{ Key = "Lite"; Remote = "51Degrees-IPIV4LiteIpiV41.ipi.gz"; Name = "51Degrees-LiteV41.ipi" }
    [pscustomobject]@{ Key = "Asn";  Remote = "51Degrees-IPIV4AsnIpiV41.ipi.gz";  Name = "51Degrees-IPIV4AsnIpiV41.ipi" }
)

# Selection: if neither -Lite nor -Asn is passed, do all known files.
# Otherwise only the ones explicitly opted in.
$Selected = @($KnownFiles | Where-Object {
    ($_.Key -eq "Lite" -and $Lite) -or
    ($_.Key -eq "Asn"  -and $Asn)  -or
    $false
})
if (-not $Selected) { $Selected = $KnownFiles }

function Expand-GzipFile {
    param(
        [Parameter(Mandatory)] [string]$ArchiveName,
        [Parameter(Mandatory)] [string]$ArchivedName
    )
    Write-Host "Extracting '$ArchiveName' to '$ArchivedName'..."
    try {
        $src = [File]::OpenRead($ArchiveName)
        $dest = [File]::Create($ArchivedName)
        $gunzip = [Compression.GZipStream]::new($src, [Compression.CompressionMode]::Decompress)
        $gunzip.copyTo($dest)
    } finally {
        # Avoid calling Close on nulls
        if ($gunzip) { $gunzip.Close() }
        if ($dest) { $dest.Close() }
        if ($src) { $src.Close() }
    }
}

foreach ($file in $Selected) {
    $ArchiveUrl = $BaseUrl + $file.Remote
    $ArchivedName = (Join-Path (Get-Location) $file.Name)
    $ArchiveName = "$ArchivedName.gz"

    # Download/skip
    if ($Force -or !(Test-Path -Path $ArchiveName -PathType Leaf)) {
        Invoke-WebRequest -Uri $ArchiveUrl -OutFile $ArchiveName
    } else {
        Write-Debug "Archive found. Download skipped."
    }

    # MD5
    $ArchiveHash = (Get-FileHash -Algorithm MD5 -Path $ArchiveName).Hash
    Write-Output "MD5 (fetched $ArchiveName) = $ArchiveHash"

    # Unpack
    Write-Output "Extracting $ArchiveName"
    Expand-GzipFile -ArchiveName $ArchiveName -ArchivedName $ArchivedName
}