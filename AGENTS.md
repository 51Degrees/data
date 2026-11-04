# Working in this repository

If you have been asked to get the data files, or to show what this repository
does, follow [Get the data files](#get-the-data-files). It gives every step in
order. The sections after it are notes on what is not obvious from the
scripts, for changing them. Keep them short and current.

This repository has no example programs of its own. It holds a `.link` file
for each free data file, two scripts that download the files, and the test
evidence. The 51Degrees SDKs take it as a submodule named `data`. To run an
example that uses the files, follow the AGENTS.md of an SDK repository
instead, such as [51degrees-cxx](https://github.com/51Degrees/51degrees-cxx).
The [README](README.md) lists every file and every SDK.

## Get the data files

Run each command from the repository root. No licence key is needed. The
Device Detection files come to about 42 MB. The IP Intelligence Lite file is
about 456 MB once unpacked, so download it only when it is needed.

### Prerequisites

- Git.
- For `get-data-files.ps1`, PowerShell 7 (`pwsh`) on any system, or Windows
  PowerShell on Windows.
- For `get-data-files.sh`, `sh`, `curl` and `gzip`. The script checks each
  download against its `Content-MD5` header with `md5sum`, or `md5` on macOS,
  and skips the check when neither is installed.
- Network access to `distributor.51degrees.com`, and to
  `media.githubusercontent.com` for `20000 User Agents.csv`.

Clone the repository.

```sh
git clone https://github.com/51Degrees/data.git
cd data
```

### Download

Download the Device Detection files first.

```sh
./get-data-files.sh device-detection
```

In PowerShell, run `./get-data-files.ps1 device-detection` instead. Where the
shell script is not executable, `sh ./get-data-files.sh device-detection` does
the same.

Then download the IP Intelligence Lite and Asn files.

```sh
./get-data-files.sh ip-intelligence
```

With no name, either script downloads every file. A name can also be one
file, such as `51Degrees-LiteV4.1.hash`. A file that is already there is kept.
Add `-u` (`-Update` in PowerShell) to replace a file that has a newer version,
or `-f` (`-Force`) to download it again. The shell script reads options only
before the first name, so put them first, as in
`./get-data-files.sh -u device-detection`.

### Correct output

Each file gives one line when its download starts and one when it is saved.
These lines are from the PowerShell script in CI on 4 November 2026.

```text
Downloading device-detection/51Degrees-LiteV4.1.hash
Saved device-detection/51Degrees-LiteV4.1.hash, 35.3 MB
```

The shell script gives the size in whole megabytes, such as `35 MB`. A second
run prints `device-detection/51Degrees-LiteV4.1.hash is already there`, and a
run with `-u` prints `... is up to date` when nothing is newer. The exit code
is 0 when every file was saved or kept, and 1 when any was not.

The files are then beside their links. The Download scripts workflow fails a
file smaller than the minimum below, and the sizes were those in CI on
4 November 2026. Each new release of a file changes its size.

| File | Minimum | Size |
| --- | --- | --- |
| `device-detection/51Degrees-LiteV4.1.hash` | 10 MB | 35.3 MB |
| `device-detection/20000 Evidence Records.yml` | 1 MB | 4.0 MB |
| `device-detection/20000 User Agents.csv` | 1 MB | 2.6 MB |
| `ip-intelligence/51Degrees-IPIV4AsnIpiV41.ipi` | 1 MB | 6.3 MB |
| `ip-intelligence/51Degrees-LiteV41.ipi` | 100 MB | 455.9 MB |

`git status` stays clean, because `.gitignore` lists every downloaded file.

### Cloud examples

There are none here, because the cloud service needs no data file. The cloud
examples in the SDK repositories need a resource key, as their AGENTS.md files
say.

### Pitfalls

- **The download limit.** The Distributor allows each file to be downloaded a
  limited number of times an hour from one address. Past the limit a script
  prints that the file `was not saved`, with when to try again, and exits 1.
  Wait, or keep the files already downloaded. A file that is already there is
  not downloaded again unless `-u` or `-f` is given, and with `-u` only when a
  newer one exists.
- **The old scripts in `ip-intelligence`.** On `rc` and `main`,
  `get-lite-file-from-azure.ps1` and `get-lite-file-from-azure.sh` still
  download the Lite and Asn files from Azure blob storage into the folder they
  run in, although `ip-intelligence/README.md` says they download the same
  files as the root scripts. Use the root scripts. The draft pull request
  [#2](https://github.com/51Degrees/data/pull/2) turns them into wrappers
  around the root scripts.
- **An unknown name.** A name that is no file or folder here stops the script
  with `No data file or folder is called <name>` before anything is
  downloaded.
- **Windows PowerShell's execution policy.** Windows PowerShell can refuse to
  run a script file under the policy Windows sets by default. If it does, run
  the script the way the run book in
  [issue #1](https://github.com/51Degrees/data/issues/1) has the SDK examples
  run it.

  ```pwsh
  powershell -NoProfile -ExecutionPolicy Bypass -File get-data-files.ps1 device-detection
  ```

## Downloading a link without the scripts

Anything other than the two scripts that downloads a linked file has to do
what they do, because each rule comes from a fault found while testing them.
The run book in [issue #1](https://github.com/51Degrees/data/issues/1) gives
the evidence for each.

1. Ask over HTTP/1.1. Over HTTP/2 the Distributor answers `If-Modified-Since`
   with a 304 that has content, which curl rejects as a protocol error.
2. Unpack every gzip member. Each file arrives as more than one member, and a
   reader that stops after the first saves a 32 byte file with no error.
   Windows PowerShell's `GZipStream` does that, so `Expand-Gzip` in
   `get-data-files.ps1` unpacks each member in turn there.
3. Check `Content-MD5`, which is the hex MD5 of the gzip file as sent.
4. Send `source`. The scripts send `ci-<repository>` in GitHub Actions and
   `data` elsewhere, unless `-s` or `-Source` gives another. Never add a `utm_`
   parameter, which the UTM link lint forbids on `distributor.51degrees.com`.
5. Expect 429 with `Retry-After`.

## Changing the scripts

The [Download scripts](.github/workflows/download-scripts.yml) workflow runs
on every pull request, on Ubuntu, Windows and macOS. It checks that PowerShell
7, Windows PowerShell and the shell script unpack the same bytes, that a second
run keeps the files, that `-u` finds nothing newer, that each file is at least
its minimum size and no longer gzip-compressed, and that `git status` is clean
afterwards. Only the Ubuntu job downloads the IP Intelligence Lite file.

A new data file needs a `<file>.link` beside where the file goes, holding its
URL on one line, and a line in `.gitignore`, because the workflow fails when a
downloaded file shows in `git status`.
`.gitattributes` keeps `*.sh` and `*.link` files LF on every system, so the
shell script runs and each link reads the same everywhere.

`20000 User Agents.csv` links to the Git LFS copy in
[device-detection-data](https://github.com/51Degrees/device-detection-data)
until the Distributor serves it. Every other link is to the Distributor.

## Pull requests

Pull requests target `rc`. The "Only rc into main" check fails a pull request
into `main` from any branch but `rc`, so changes reach `main` together.
