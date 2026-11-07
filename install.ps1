<#
.SYNOPSIS
    Installs the alok-zed-config setup into Zed on Windows.

.DESCRIPTION
    Copies settings.json and themes\aura-dark-custom.json into
    %APPDATA%\Zed, backing up any files that already exist.

.PARAMETER Destination
    Install into this directory instead of %APPDATA%\Zed.

.PARAMETER BaseUrl
    Download settings.json and the theme from this URL (used when running
    the script remotely, e.g. via `irm ... | iex`).

.PARAMETER NoBackup
    Do not back up existing settings/theme files.

.PARAMETER DryRun
    Show what would happen without changing anything.

.PARAMETER Help
    Show this help text.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
    irm https://raw.githubusercontent.com/alok-mishra143/alok-zed-config/main/install.ps1 | iex

.EXAMPLE
    .\install.ps1 -Destination "$env:TEMP\zed-test" -DryRun
#>
[CmdletBinding()]
param(
    [string]$Destination = "",
    [string]$BaseUrl = "",
    [switch]$NoBackup,
    [switch]$DryRun,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$ScriptDir = $null
if ($PSScriptRoot) {
    $ScriptDir = $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$ThemeFile = "aura-dark-custom.json"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$SettingsSrc = $null
$ThemeSrc = $null
if ($ScriptDir) {
    $SettingsSrc = Join-Path $ScriptDir "settings.json"
    $ThemeSrc = Join-Path (Join-Path $ScriptDir "themes") $ThemeFile
}

# Used when the script is piped into iex (`irm ... | iex`) instead of run from
# a checkout. Change this if you fork or rename the repo.
if (-not $BaseUrl) { $BaseUrl = $env:ALOK_ZED_CONFIG_BASE_URL }
if (-not $BaseUrl) {
    $BaseUrl = "https://raw.githubusercontent.com/alok-mishra143/alok-zed-config/main"
}
$BaseUrl = $BaseUrl.TrimEnd("/")

function Write-Info($Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Step($Message) { Write-Host "--> $Message" -ForegroundColor DarkGray }
function Write-Ok($Message) { Write-Host " ok $Message" -ForegroundColor Green }
function Write-Warn($Message) { Write-Host "warn $Message" -ForegroundColor Yellow }
function Fail($Message) {
    if ($script:TempDir) {
        Remove-Item -LiteralPath $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($script:ScriptDir) {
        Write-Host "error: $Message" -ForegroundColor Red
        exit 1
    }
    # Running via `irm ... | iex`: throw instead of exit so the window stays open.
    throw "error: $Message"
}

function Show-Usage {
    @"
alok-zed-config installer (Windows)

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 [options]

Options:
  -Destination PATH   Install into PATH instead of %APPDATA%\Zed
  -BaseUrl URL        Download settings/theme from URL instead of this checkout
  -NoBackup           Do not back up existing settings/theme files
  -DryRun             Show what would happen without changing anything
  -Help               Show this help

Environment:
  ZED_CONFIG_DIR      Alternative way to set the target config directory
"@ | Write-Host
}

if ($Help) {
    Show-Usage
    exit 0
}

$needDownload = $true
if ($SettingsSrc -and $ThemeSrc -and
    (Test-Path -LiteralPath $SettingsSrc) -and
    (Test-Path -LiteralPath $ThemeSrc)) {
    $needDownload = $false
}

$TempDir = $null
if ($needDownload) {
    Write-Info "Downloading settings.json and $ThemeFile"
    $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("alok-zed-config-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path (Join-Path $TempDir "themes") | Out-Null
    $SettingsSrc = Join-Path $TempDir "settings.json"
    $ThemeSrc = Join-Path (Join-Path $TempDir "themes") $ThemeFile

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/settings.json" -OutFile $SettingsSrc
        Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/themes/$ThemeFile" -OutFile $ThemeSrc
    } catch {
        Fail "Download failed from $BaseUrl. Use -BaseUrl or ALOK_ZED_CONFIG_BASE_URL. ($($_.Exception.Message))"
    }
}

# ---------------------------------------------------------------- target dir

$ConfigDir = $Destination
if (-not $ConfigDir) { $ConfigDir = $env:ZED_CONFIG_DIR }
if (-not $ConfigDir) {
    if ($env:APPDATA) {
        $ConfigDir = Join-Path $env:APPDATA "Zed"
    } else {
        Fail "APPDATA is not set. Pass -Destination <path>."
    }
}

if ($ConfigDir.StartsWith("~")) {
    $rest = $ConfigDir.Substring(1).TrimStart("\", "/")
    $ConfigDir = if ($rest) { Join-Path $HOME $rest } else { $HOME }
}
if (-not [System.IO.Path]::IsPathRooted($ConfigDir)) {
    $ConfigDir = Join-Path $PWD.Path $ConfigDir
}
$ConfigDir = [System.IO.Path]::GetFullPath($ConfigDir)

$SettingsDest = Join-Path $ConfigDir "settings.json"
$ThemeDest = Join-Path (Join-Path $ConfigDir "themes") $ThemeFile

# ---------------------------------------------------------------- helpers

function Invoke-Step([string]$Description, [scriptblock]$Action) {
    if ($DryRun) {
        Write-Host "    [dry-run] $Description" -ForegroundColor DarkGray
    } else {
        & $Action
    }
}

function Backup-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if ($NoBackup) {
        Write-Warn "Skipping backup of $(Split-Path -Leaf $Path) (-NoBackup)"
        return
    }

    $backup = "$Path.backup-$Timestamp"
    $n = 2
    while (Test-Path -LiteralPath $backup) {
        $backup = "$Path.backup-$Timestamp-$n"
        $n++
    }

    Invoke-Step "Copy-Item '$Path' -> '$backup'" {
        Copy-Item -LiteralPath $Path -Destination $backup -Force
    }
    if (-not $DryRun) {
        Write-Ok "Backed up $(Split-Path -Leaf $Path) -> $backup"
    }
}

# ---------------------------------------------------------------- install

Write-Host ""
Write-Info "alok-zed-config installer"
Write-Host "    platform : windows"
$sourceLabel = if ($ScriptDir) { $ScriptDir } else { $BaseUrl }
Write-Host "    source   : $sourceLabel"
Write-Host "    target   : $ConfigDir"
Write-Host ""

if ($DryRun) { Write-Warn "Dry run: no files will be changed." }

Write-Step "Creating $ConfigDir"
Invoke-Step "New-Item -ItemType Directory '$ConfigDir\themes'" {
    New-Item -ItemType Directory -Force -Path (Join-Path $ConfigDir "themes") | Out-Null
}

Write-Step "Backing up existing files"
Backup-File $SettingsDest
Backup-File $ThemeDest

Write-Step "Installing settings.json"
Invoke-Step "Copy-Item '$SettingsSrc' -> '$SettingsDest'" {
    Copy-Item -LiteralPath $SettingsSrc -Destination $SettingsDest -Force
}
if (-not $DryRun) {
    Write-Ok "Settings -> $SettingsDest"
}

Write-Step "Installing $ThemeFile"
Invoke-Step "Copy-Item '$ThemeSrc' -> '$ThemeDest'" {
    Copy-Item -LiteralPath $ThemeSrc -Destination $ThemeDest -Force
}
if (-not $DryRun) {
    Write-Ok "Theme    -> $ThemeDest"
}

# ---------------------------------------------------------------- post-install

$zedFound = $false
$candidates = @()
if ($env:LOCALAPPDATA) {
    $candidates += Join-Path $env:LOCALAPPDATA "Programs\Zed\zed.exe"
}
if ($env:ProgramFiles) {
    $candidates += Join-Path $env:ProgramFiles "Zed\zed.exe"
}
foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) { $zedFound = $true; break }
}
if (-not $zedFound -and (Get-Command zed -ErrorAction SilentlyContinue)) {
    $zedFound = $true
}
if (-not $zedFound) {
    Write-Warn "Zed was not detected. Install it from https://zed.dev/download if you haven't yet."
}

if ((Test-Path -LiteralPath $SettingsDest) -and
    (Select-String -LiteralPath $SettingsDest -Pattern 'YOUR_[A-Z0-9_]*' -Quiet)) {
    Write-Warn "settings.json still contains placeholder API keys (YOUR_*)."
}

Write-Host ""
Write-Host "Done. Restart Zed, then choose Aura Dark Custom from the theme selector." -ForegroundColor White
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Quit Zed completely and reopen it (local themes load at startup)."
Write-Host "  2. Open the command palette and run ""theme selector: toggle""."
Write-Host "  3. Pick ""Aura Dark Custom"" for dark mode (light mode uses Ayu Light)."
Write-Host "  4. Replace the YOUR_* placeholders in:"
Write-Host "       $SettingsDest"
Write-Host ""
Write-Host "Notes:"
Write-Host "  - ""Material Icon Theme"" is referenced by settings.json. Install that"
Write-Host "    extension, or change ""icon_theme"" to a built-in theme."
Write-Host "  - Colored TODO/INFO/WARN/FIXME tags need the Comments Highlighter extension."
Write-Host "  - See README.md for secrets, extensions, and troubleshooting."
Write-Host ""

if ($TempDir) {
    Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
