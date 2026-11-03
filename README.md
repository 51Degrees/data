# ![51Degrees](https://51degrees.com/img/logo.png?utm_source=github&utm_medium=readme&utm_campaign=data&utm_content=readme&utm_term=top "Data rewards the curious") **Data files**

The free data files and test evidence for 51Degrees
[Device Detection](https://51degrees.com/device-detection?utm_source=github&utm_medium=readme&utm_campaign=data&utm_content=readme&utm_term=introduction)
and [IP Intelligence](https://51degrees.com/ip-intelligence?utm_source=github&utm_medium=readme&utm_campaign=data&utm_content=readme&utm_term=introduction),
used by the examples and tests in every 51Degrees SDK.

## Get the data files

The data files are not stored in this repository. Download the latest
copies from 51Degrees with one of these scripts. No License Key is needed.

```pwsh
./get-data-files.ps1
```

```sh
./get-data-files.sh
```

Each script saves the files in the folders the examples and tests look in,
and only downloads a file again when a newer one is available.

## What is here

### device-detection-data

| File | What it is |
| --- | --- |
| `51Degrees-LiteV4.1.hash` | The Lite on-premise Device Detection data file. Downloaded by the scripts. |
| `20000 User Agents.csv` | 20,000 of the most commonly seen User-Agents, one per line. Downloaded by the scripts. |
| `20000 Evidence Records.yml` | 20,000 of the most commonly seen sets of HTTP headers, including [User-Agent Client Hints](https://learnclienthints.com/), one YAML record per set. Downloaded by the scripts. |
| `metrics/` | Charts of the data's coverage of browsers, hardware, operating systems and crawlers. |

The Lite file gives IsMobile, ScreenPixelsHeight, ScreenPixelsWidth,
PlatformName, PlatformVersion, PlatformVendor, BrowserName, BrowserVersion,
BrowserVendor, SetHeaderBrowserAccept-CH, SetHeaderHardwareAccept-CH,
SetHeaderPlatformAccept-CH, JavascriptGetHighEntropyValues and
JavascriptHardwareProfile. It is built from a subset of all devices and
is updated less often than the paid data files.

### ip-intelligence-data

| File | What it is |
| --- | --- |
| `51Degrees-LiteV41.ipi` | The Lite on-premise IP Intelligence data file, giving RegisteredCountry, RegisteredName and RegisteredOwner. Downloaded by the scripts. |
| `51Degrees-IPIV4AsnIpiV41.ipi` | The Asn data file, giving Asn and AsnName. Downloaded by the scripts. |
| `evidence.csv`, `evidence.yml` | 20,000 random IPv4 and IPv6 addresses for the examples and tests. |
| `evidence-gen.ps1` | Makes a new set of random addresses, for example `./evidence-gen.ps1 -v4 10000 -v6 10000 "evidence.yml"`. |
| `CountryCodes.json`, `Translations/` | Country names in English and 16 other languages, used by the translation engine and its examples. |

## More properties

The Lite files carry a small set of properties. The
[cloud service](https://51degrees.com/developers?utm_source=github&utm_medium=readme&utm_campaign=data&utm_content=readme&utm_term=more-properties)
and the paid data files carry hundreds more, from hardware model and price
band to location, connection type and Human Confidence. See
[pricing](https://51degrees.com/pricing?utm_source=github&utm_medium=readme&utm_campaign=data&utm_content=readme&utm_term=more-properties)
for the options.

## Find out more

- Device Detection: https://51degrees.com/device-detection?utm_source=github&utm_medium=readme&utm_campaign=data&utm_content=readme&utm_term=find-out-more
- IP Intelligence: https://51degrees.com/ip-intelligence?utm_source=github&utm_medium=readme&utm_campaign=data&utm_content=readme&utm_term=find-out-more
- Documentation: https://51degrees.com/documentation/index.html?utm_source=github&utm_medium=readme&utm_campaign=data&utm_content=readme&utm_term=find-out-more
- The SDKs that use these files:
  - https://github.com/51Degrees/51degrees-cxx
  - https://github.com/51Degrees/51degrees-dotnet
  - https://github.com/51Degrees/51degrees-go
  - https://github.com/51Degrees/51degrees-java
  - https://github.com/51Degrees/51degrees-nginx
  - https://github.com/51Degrees/51degrees-node
  - https://github.com/51Degrees/51degrees-php
  - https://github.com/51Degrees/51degrees-rust
  - https://github.com/51Degrees/51degrees-varnish
