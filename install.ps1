<#
.SYNOPSIS
    Installs the alok-zed-config setup into Zed on Windows.

.DESCRIPTION
    Copies settings.json, keymap.json and themes\aura-dark-custom.json into
    %APPDATA%\Zed, backing up any files that already exist.

.PARAMETER Destination
    Install into this directory instead of %APPDATA%\Zed.

.PARAMETER BaseUrl
    Download the config files from this URL (used when running the script
    remotely, e.g. via `irm ... | iex`).

.PARAMETER Only
    Install only these components (comma-separated): settings, keymap, theme,
    or all. Implies -Yes.

.PARAMETER Yes
    Install all components without asking.

.PARAMETER NoBackup
    Do not back up existing settings/keymap/theme files.

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

.EXAMPLE
    .\install.ps1 -Only keymap,theme

.EXAMPLE
    .\install.ps1 -Yes
#>
[CmdletBinding()]
param(
    [string]$Destination = "",
    [string]$BaseUrl = "",
    [string]$Only = "",
    [switch]$Yes,
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
$KeymapFile = "keymap.json"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$SettingsSrc = $null
$KeymapSrc = $null
$ThemeSrc = $null
if ($ScriptDir) {
    $SettingsSrc = Join-Path $ScriptDir "settings.json"
    $KeymapSrc = Join-Path $ScriptDir $KeymapFile
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
  -BaseUrl URL        Download config files from URL instead of this checkout
  -Only LIST          Install only these components (comma-separated):
                      settings, keymap, theme, or all (implies -Yes)
  -Yes                Install all components without asking
  -NoBackup           Do not back up existing settings/keymap/theme files
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

# ---------------------------------------------------------------- components

$WantSettings = $true
$WantKeymap = $true
$WantTheme = $true

function Set-AllComponents {
    $script:WantSettings = $true
    $script:WantKeymap = $true
    $script:WantTheme = $true
}

function Any-Selected {
    return ($WantSettings -or $WantKeymap -or $WantTheme)
}

function Get-SelectionSummary {
    $names = @()
    if ($WantSettings) { $names += "settings" }
    if ($WantKeymap) { $names += "keymap" }
    if ($WantTheme) { $names += "theme" }
    return ($names -join " ")
}

$onlyProvided = $null -ne $PSBoundParameters -and $PSBoundParameters.ContainsKey("Only")
if ($onlyProvided) {
    if (-not $Only) {
        Fail "-Only needs settings, keymap, theme, or all"
    }
    $WantSettings = $false
    $WantKeymap = $false
    $WantTheme = $false
    foreach ($item in ($Only -split '[, ]+' | Where-Object { $_ })) {
        switch ($item.ToLower()) {
            "all" { Set-AllComponents }
            "settings" { $script:WantSettings = $true }
            "settings.json" { $script:WantSettings = $true }
            "keymap" { $script:WantKeymap = $true }
            "keymap.json" { $script:WantKeymap = $true }
            "theme" { $script:WantTheme = $true }
            "themes" { $script:WantTheme = $true }
            "theme.json" { $script:WantTheme = $true }
            default { Fail "Unknown -Only component: $item (use settings, keymap, theme, or all)" }
        }
    }
    if (-not (Any-Selected)) {
        Fail "-Only did not select any components."
    }
} elseif (-not $Yes) {
    $canPrompt = $true
    try {
        if ([Console]::IsInputRedirected) { $canPrompt = $false }
    } catch {
        $canPrompt = $false
    }

    if (-not $canPrompt) {
        Write-Info "No interactive input; installing all components (use -Only to choose)."
    } else {
        while ($true) {
            Write-Host ""
            Write-Host "Select what to install (Enter = install, default: all)" -ForegroundColor White
            $m1 = if ($WantSettings) { "[x]" } else { "[ ]" }
            $m2 = if ($WantKeymap) { "[x]" } else { "[ ]" }
            $m3 = if ($WantTheme) { "[x]" } else { "[ ]" }
            Write-Host "  $m1 1) settings.json"
            Write-Host "  $m2 2) keymap.json"
            Write-Host "  $m3 3) Aura Dark Custom theme"

            $answer = $null
            try {
                $answer = Read-Host 'Toggle 1-3 (e.g. "1 3"), a=all, Enter=install'
            } catch {
                break
            }
            if ($null -eq $answer) { break }
            $normalized = ($answer -replace '\s', '').ToLower()
            if ($normalized -eq "") { break }
            if ($normalized -eq "a" -or $normalized -eq "all") {
                Set-AllComponents
                continue
            }
            foreach ($token in ($answer -split '[, ]+' | Where-Object { $_ })) {
                switch ($token) {
                    "1" { $script:WantSettings = -not $WantSettings }
                    "2" { $script:WantKeymap = -not $WantKeymap }
                    "3" { $script:WantTheme = -not $WantTheme }
                    default { Write-Warn "Unknown choice: $token" }
                }
            }
        }
        if (-not (Any-Selected)) {
            Write-Warn "Nothing selected; installing all components."
            Set-AllComponents
        }
    }
}

$needSettingsDownload = $WantSettings -and (-not $SettingsSrc -or -not (Test-Path -LiteralPath $SettingsSrc))
$needKeymapDownload = $WantKeymap -and (-not $KeymapSrc -or -not (Test-Path -LiteralPath $KeymapSrc))
$needThemeDownload = $WantTheme -and (-not $ThemeSrc -or -not (Test-Path -LiteralPath $ThemeSrc))

$TempDir = $null
if ($needSettingsDownload -or $needKeymapDownload -or $needThemeDownload) {
    $downloads = @()
    $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("alok-zed-config-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path (Join-Path $TempDir "themes") | Out-Null

    if ($needSettingsDownload) {
        $SettingsSrc = Join-Path $TempDir "settings.json"
        $downloads += "settings.json"
    }
    if ($needKeymapDownload) {
        $KeymapSrc = Join-Path $TempDir $KeymapFile
        $downloads += $KeymapFile
    }
    if ($needThemeDownload) {
        $ThemeSrc = Join-Path (Join-Path $TempDir "themes") $ThemeFile
        $downloads += $ThemeFile
    }

    Write-Info "Downloading $($downloads -join ', ')"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        if ($needSettingsDownload) {
            Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/settings.json" -OutFile $SettingsSrc
        }
        if ($needKeymapDownload) {
            Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/$KeymapFile" -OutFile $KeymapSrc
        }
        if ($needThemeDownload) {
            Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/themes/$ThemeFile" -OutFile $ThemeSrc
        }
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
$KeymapDest = Join-Path $ConfigDir $KeymapFile
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
Write-Host "    install  : $(Get-SelectionSummary)"
Write-Host ""

if ($DryRun) { Write-Warn "Dry run: no files will be changed." }

Write-Step "Creating $ConfigDir"
Invoke-Step "New-Item -ItemType Directory '$ConfigDir'" {
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
}
if ($WantTheme) {
    Invoke-Step "New-Item -ItemType Directory '$ConfigDir\themes'" {
        New-Item -ItemType Directory -Force -Path (Join-Path $ConfigDir "themes") | Out-Null
    }
}

Write-Step "Backing up existing files"
if ($WantSettings) { Backup-File $SettingsDest }
if ($WantKeymap) { Backup-File $KeymapDest }
if ($WantTheme) { Backup-File $ThemeDest }

if ($WantSettings) {
    Write-Step "Installing settings.json"
    Invoke-Step "Copy-Item '$SettingsSrc' -> '$SettingsDest'" {
        Copy-Item -LiteralPath $SettingsSrc -Destination $SettingsDest -Force
    }
    if (-not $DryRun) {
        Write-Ok "Settings -> $SettingsDest"
    }
}

if ($WantKeymap) {
    Write-Step "Installing $KeymapFile"
    Invoke-Step "Copy-Item '$KeymapSrc' -> '$KeymapDest'" {
        Copy-Item -LiteralPath $KeymapSrc -Destination $KeymapDest -Force
    }
    if (-not $DryRun) {
        Write-Ok "Keymap   -> $KeymapDest"
    }
}

if ($WantTheme) {
    Write-Step "Installing $ThemeFile"
    Invoke-Step "Copy-Item '$ThemeSrc' -> '$ThemeDest'" {
        Copy-Item -LiteralPath $ThemeSrc -Destination $ThemeDest -Force
    }
    if (-not $DryRun) {
        Write-Ok "Theme    -> $ThemeDest"
    }
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

if ($WantSettings -and (Test-Path -LiteralPath $SettingsDest) -and
    (Select-String -LiteralPath $SettingsDest -Pattern 'YOUR_[A-Z0-9_]*' -Quiet)) {
    Write-Warn "settings.json still contains placeholder API keys (YOUR_*)."
}

Write-Host ""
if ($WantTheme) {
    Write-Host "Done. Restart Zed, then choose Aura Dark Custom from the theme selector." -ForegroundColor White
} else {
    Write-Host "Done." -ForegroundColor White
}
Write-Host "Installed: $(Get-SelectionSummary)"

$step = 1
if ($WantTheme -or $WantSettings) {
    Write-Host ""
    Write-Host "Next steps:"
    if ($WantTheme) {
        Write-Host "  $($step). Quit Zed completely and reopen it (local themes load at startup)."
        $step++
        Write-Host "  $($step). Open the command palette and run ""theme selector: toggle""."
        $step++
        Write-Host "  $($step). Pick ""Aura Dark Custom"" for dark mode (light mode uses Ayu Light)."
        $step++
    }
    if ($WantSettings) {
        Write-Host "  $($step). Replace the YOUR_* placeholders in:"
        Write-Host "       $SettingsDest"
    }
}

Write-Host ""
Write-Host "Notes:"
if ($WantKeymap) {
    Write-Host "  - keymap.json adds ctrl/ctrl-alt shortcuts on top of the VSCode base"
    Write-Host "    keymap. See KEYBINDINGS.md for the full list."
}
if ($WantSettings) {
    Write-Host "  - ""Material Icon Theme"" is referenced by settings.json. Install that"
    Write-Host "    extension, or change ""icon_theme"" to a built-in theme."
    Write-Host "  - Colored TODO/INFO/WARN/FIXME tags need the Comments Highlighter extension."
}
Write-Host "  - See README.md for secrets, extensions, and troubleshooting."
Write-Host ""

if ($TempDir) {
    Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
