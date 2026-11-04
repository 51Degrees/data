<#
.SYNOPSIS
Downloads the data files that this repository links to.

.DESCRIPTION
Each data file is listed as a .link file, in the folder where the examples
and tests look for it, holding the address the file is downloaded from. The
file is saved beside its link, under the link's name without .link, and is
unpacked when it arrives gzip-compressed. A file that is already there is
kept, unless -Update or -Force is given.

.PARAMETER Name
The files to download, by file or folder name, for example
51Degrees-LiteV4.1.hash or ip-intelligence-data. Every linked file when
none is given.

.PARAMETER Update
Asks again for each file that is already there, and replaces it only when a
newer one is available.

.PARAMETER Force
Downloads every file again.

.PARAMETER Source
Sent with each download from the Distributor, so that downloads can be
counted by where they come from. Defaults to ci-<repository> in GitHub
Actions and to data elsewhere.

.EXAMPLE
./get-data-files.ps1

.EXAMPLE
./get-data-files.ps1 51Degrees-LiteV4.1.hash -Update
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Name,
    [switch]$Update,
    [switch]$Force,
    [string]$Source
)
$ErrorActionPreference = 'Stop'

$DistributorHost = 'distributor.51degrees.com'
$HeadersTimeoutMinutes = 5
$UserAgent = 'get-data-files/1.0 (PowerShell; +https://github.com/51Degrees/data)'

function Get-DataFileName($Link) {
    $Link.Name.Substring(0, $Link.Name.Length - '.link'.Length)
}

function Test-Gzip([string]$Path) {
    $file = [System.IO.File]::OpenRead($Path)
    try { $file.ReadByte() -eq 0x1f -and $file.ReadByte() -eq 0x8b }
    finally { $file.Dispose() }
}

function Expand-Gzip([string]$Path, [string]$Destination) {
    $in = [System.IO.File]::OpenRead($Path)
    try {
        $gzip = New-Object System.IO.Compression.GZipStream($in,
            [System.IO.Compression.CompressionMode]::Decompress)
        $out = [System.IO.File]::Create($Destination)
        try { $gzip.CopyTo($out) } finally { $out.Dispose(); $gzip.Dispose() }
    } finally { $in.Dispose() }
}

# Content-MD5 in hex or base64, as upper case hex, or null.
function ConvertTo-Md5Hex([string]$Header) {
    $text = $Header.Trim()
    if ($text -match '^[0-9a-fA-F]{32}$') { return $text.ToUpperInvariant() }
    try {
        $bytes = [Convert]::FromBase64String($text)
        if ($bytes.Length -eq 16) {
            return [BitConverter]::ToString($bytes).Replace('-', '')
        }
    } catch { }
    return $null
}

# Throws when a Content-MD5 header matches neither the bytes received nor
# the bytes unpacked from them.
function Assert-Md5($Response, [string[]]$Paths) {
    $values = $null
    if (-not $Response.Content.Headers.TryGetValues('Content-MD5', [ref]$values)) {
        return
    }
    $header = @($values)[0]
    $expected = ConvertTo-Md5Hex $header
    if (-not $expected) { return }
    foreach ($path in $Paths) {
        if ((Get-FileHash -LiteralPath $path -Algorithm MD5).Hash -eq $expected) {
            return
        }
    }
    throw 'The file received does not match its Content-MD5 header.'
}

function Save-DataFile([string]$Url, [string]$Target, [string]$Label,
    [bool]$Conditional) {
    $request = New-Object System.Net.Http.HttpRequestMessage(
        [System.Net.Http.HttpMethod]::Get, $Url)
    if ($Conditional) {
        $request.Headers.IfModifiedSince = [DateTimeOffset](
            Get-Item -LiteralPath $Target).LastWriteTimeUtc
        Write-Host "Checking $Label"
    } else {
        Write-Host "Downloading $Label"
    }
    $response = $client.SendAsync($request,
        [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
    ).GetAwaiter().GetResult()
    $part = "$Target.part"
    $unpacked = "$Target.unpacked"
    try {
        $status = [int]$response.StatusCode
        if ($status -eq 304) {
            Write-Host "$Label is up to date"
            return
        }
        if ($status -eq 429) {
            $wait = $response.Headers.RetryAfter
            $when = 'later'
            if ($wait -and $wait.Delta) {
                $when = "in $([Math]::Ceiling($wait.Delta.TotalMinutes)) minutes"
            } elseif ($wait -and $wait.Date) {
                $when = "after $($wait.Date.UtcDateTime.ToString('u'))"
            }
            throw ('Each file can only be downloaded a few times an hour ' +
                "from one address. Try again $when.")
        }
        if (-not $response.IsSuccessStatusCode) {
            throw "The server answered $status $($response.ReasonPhrase)."
        }
        $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $file = [System.IO.File]::Create($part)
        try { $stream.CopyTo($file) } finally { $file.Dispose(); $stream.Dispose() }
        if ((Get-Item -LiteralPath $part).Length -eq 0) {
            throw 'The server sent an empty file.'
        }
        $saved = $part
        if (Test-Gzip $part) {
            Expand-Gzip $part $unpacked
            $saved = $unpacked
        }
        Assert-Md5 $response @($part, $saved)
        Move-Item -LiteralPath $saved -Destination $Target -Force
        $lastModified = $response.Content.Headers.LastModified
        if ($lastModified) {
            (Get-Item -LiteralPath $Target).LastWriteTimeUtc = $lastModified.UtcDateTime
        }
        Write-Host ('Saved {0}, {1:N1} MB' -f $Label,
            ((Get-Item -LiteralPath $Target).Length / 1MB))
    } finally {
        $response.Dispose()
        foreach ($leftover in $part, $unpacked) {
            if (Test-Path -LiteralPath $leftover) {
                Remove-Item -LiteralPath $leftover -Force
            }
        }
    }
}

if (-not $Source) {
    $Source = 'data'
    if ($env:GITHUB_ACTIONS -eq 'true' -and $env:GITHUB_REPOSITORY) {
        $Source = 'ci-' + $env:GITHUB_REPOSITORY.Split('/')[-1]
    }
}

$links = @(Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File |
    Where-Object { $_.Extension -eq '.link' -and
        $_.FullName -notmatch '[\\/]\.git[\\/]' })
if ($Name) {
    foreach ($wanted in $Name) {
        if (-not ($links | Where-Object {
                    (Get-DataFileName $_) -eq $wanted -or
                    $_.Directory.Name -eq $wanted })) {
            throw "No data file or folder is called $wanted"
        }
    }
    $links = @($links | Where-Object {
            $Name -contains (Get-DataFileName $_) -or
            $Name -contains $_.Directory.Name })
}

if ($PSVersionTable.PSEdition -ne 'Core') {
    # Windows PowerShell does not offer TLS 1.2 unless asked.
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor
        [Net.SecurityProtocolType]::Tls12
}
Add-Type -AssemblyName System.Net.Http
$client = New-Object System.Net.Http.HttpClient
$client.Timeout = [TimeSpan]::FromMinutes($HeadersTimeoutMinutes)
$null = $client.DefaultRequestHeaders.UserAgent.TryParseAdd($UserAgent)

$failed = 0
try {
    foreach ($link in $links) {
        $fileName = Get-DataFileName $link
        $path = Join-Path $link.DirectoryName $fileName
        $label = "$($link.Directory.Name)/$fileName"
        $exists = Test-Path -LiteralPath $path
        if ($exists -and -not ($Update -or $Force)) {
            Write-Host "$label is already there"
            continue
        }
        $url = (Get-Content -LiteralPath $link.FullName -TotalCount 1).Trim()
        if (([Uri]$url).Host -eq $DistributorHost) {
            $separator = '?'
            if ($url.Contains('?')) { $separator = '&' }
            $url += $separator + 'source=' + [Uri]::EscapeDataString($Source)
        }
        try {
            Save-DataFile $url $path $label ($exists -and -not $Force)
        } catch {
            Write-Warning "$label was not saved. $($_.Exception.Message)"
            $failed++
        }
    }
} finally {
    $client.Dispose()
}
if ($failed) { exit 1 }
