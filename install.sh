#!/usr/bin/env bash
#
# install.sh - install the alok-zed-config setup into Zed.
#
# Supported platforms:
#   macOS                   -> ~/.config/zed
#   Linux                   -> ${XDG_CONFIG_HOME:-~/.config}/zed
#   Windows (Git Bash/MSYS) -> %APPDATA%\Zed
#   WSL                     -> Linux config (use --dir for Zed for Windows)
#
# Usage:
#   ./install.sh [options]
#   curl -fsSL <repo>/install.sh | bash
#
# Options:
#   -d, --dir PATH      Install into PATH instead of the default Zed config dir
#   -n, --no-backup     Do not back up existing settings/keymap/theme files
#   -y, --yes           Install all components without asking
#       --only LIST     Install only these components (comma-separated):
#                       settings, keymap, theme, or all (implies --yes)
#       --base-url URL  Download config files from URL instead of this checkout
#       --dry-run       Show what would happen without changing anything
#   -h, --help          Show this help
#
# ZED_CONFIG_DIR and ALOK_ZED_CONFIG_BASE_URL can be set instead of the matching
# options. Set NO_COLOR=1 to disable color.

# Re-exec under bash when started with a POSIX shell such as dash.
if [ -z "${BASH_VERSION:-}" ]; then
  if [ -f "$0" ]; then
    exec bash "$0" "$@"
  fi
  printf 'error: run this with bash, e.g. curl ... | bash\n' >&2
  exit 1
fi

set -euo pipefail

# Used when the script is piped into bash (`curl ... | bash`) instead of run
# from a checkout. Change this if you fork or rename the repo.
BASE_URL="${ALOK_ZED_CONFIG_BASE_URL:-https://raw.githubusercontent.com/alok-mishra143/alok-zed-config/main}"

THEME_FILE="aura-dark-custom.json"
KEYMAP_FILE="keymap.json"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# BASH_SOURCE is empty when the script is piped into bash.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

SETTINGS_SRC=""
KEYMAP_SRC=""
THEME_SRC=""
if [ -n "$SCRIPT_DIR" ]; then
  SETTINGS_SRC="$SCRIPT_DIR/settings.json"
  KEYMAP_SRC="$SCRIPT_DIR/$KEYMAP_FILE"
  THEME_SRC="$SCRIPT_DIR/themes/$THEME_FILE"
fi

TMP_DIR=""
cleanup() {
  if [ -n "${TMP_DIR:-}" ]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

TARGET_DIR=""
DO_BACKUP=true
DRY_RUN=false
ASSUME_YES=false
ONLY_COMPONENTS=""
WANT_SETTINGS=true
WANT_KEYMAP=true
WANT_THEME=true

# ---------------------------------------------------------------- pretty output

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
  BOLD="$(printf '\033[1m')"
  DIM="$(printf '\033[2m')"
  RED="$(printf '\033[31m')"
  GREEN="$(printf '\033[32m')"
  YELLOW="$(printf '\033[33m')"
  CYAN="$(printf '\033[36m')"
  RESET="$(printf '\033[0m')"
else
  BOLD="" DIM="" RED="" GREEN="" YELLOW="" CYAN="" RESET=""
fi

info() { printf '%s==>%s %s\n' "$CYAN" "$RESET" "$*"; }
step() { printf '%s-->%s %s\n' "$DIM" "$RESET" "$*"; }
ok()   { printf '%s ok %s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%swarn%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die()  { printf '%serror:%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
alok-zed-config installer

Usage:
  ./install.sh [options]

Options:
  -d, --dir PATH      Install into PATH instead of the default Zed config dir
  -n, --no-backup     Do not back up existing settings/keymap/theme files
  -y, --yes           Install all components without asking
      --only LIST     Install only these components (comma-separated):
                      settings, keymap, theme, or all (implies --yes)
      --base-url URL  Download config files from URL instead of this checkout
      --dry-run       Show what would happen without changing anything
  -h, --help          Show this help

Environment:
  ZED_CONFIG_DIR            Alternative way to set the target config directory
  ALOK_ZED_CONFIG_BASE_URL  Alternative way to set --base-url
  NO_COLOR                  Set to any value to disable colored output

Zed config directories:
  macOS    ~/.config/zed
  Linux    ${XDG_CONFIG_HOME:-~/.config}/zed
  Windows  %APPDATA%\Zed   (Git Bash / MSYS2 / Cygwin)

Examples:
  ./install.sh
  ./install.sh --only keymap,theme
  ./install.sh --yes
  ./install.sh --dry-run
  ./install.sh --dir "$HOME/zed-test"
  ./install.sh --dir "/mnt/c/Users/you/AppData/Roaming/Zed"
EOF
}

# ---------------------------------------------------------------- arg parsing

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--dir)
      [ $# -ge 2 ] || die "Missing value for $1"
      TARGET_DIR="$2"
      shift 2
      ;;
    --dir=*)
      TARGET_DIR="${1#*=}"
      shift
      ;;
    -n|--no-backup)
      DO_BACKUP=false
      shift
      ;;
    -y|--yes)
      ASSUME_YES=true
      shift
      ;;
    --only)
      [ $# -ge 2 ] || die "Missing value for $1"
      [ -n "$2" ] || die "--only needs settings, keymap, theme, or all"
      ONLY_COMPONENTS="$2"
      shift 2
      ;;
    --only=*)
      ONLY_COMPONENTS="${1#*=}"
      [ -n "$ONLY_COMPONENTS" ] || die "--only needs settings, keymap, theme, or all"
      shift
      ;;
    --base-url)
      [ $# -ge 2 ] || die "Missing value for $1"
      BASE_URL="$2"
      shift 2
      ;;
    --base-url=*)
      BASE_URL="${1#*=}"
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1 (run ./install.sh --help)"
      ;;
  esac
done

# ---------------------------------------------------------------- environment

detect_os() {
  case "$(uname -s 2>/dev/null || echo unknown)" in
    Darwin) echo macos ;;
    Linux)
      if [ -r /proc/version ] && grep -qi microsoft /proc/version; then
        echo wsl
      else
        echo linux
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    *) echo unknown ;;
  esac
}

windows_config_dir() {
  local base="${APPDATA:-}"
  [ -n "$base" ] || base="$HOME/AppData/Roaming"
  if command -v cygpath >/dev/null 2>&1; then
    base="$(cygpath -u "$base")"
  fi
  printf '%s/Zed\n' "$base"
}

OS="$(detect_os)"

CONFIG_DIR="${TARGET_DIR:-${ZED_CONFIG_DIR:-}}"
if [ -z "$CONFIG_DIR" ]; then
  case "$OS" in
    windows) CONFIG_DIR="$(windows_config_dir)" ;;
    *) CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed" ;;
  esac
fi

# Expand a leading ~ supplied via --dir / ZED_CONFIG_DIR.
case "$CONFIG_DIR" in
  "~") CONFIG_DIR="$HOME" ;;
  "~/"*) CONFIG_DIR="$HOME/${CONFIG_DIR#\~/}" ;;
esac

SETTINGS_DEST="$CONFIG_DIR/settings.json"
KEYMAP_DEST="$CONFIG_DIR/$KEYMAP_FILE"
THEME_DEST="$CONFIG_DIR/themes/$THEME_FILE"

# ---------------------------------------------------------------- helpers

run() {
  if $DRY_RUN; then
    printf '    %s[dry-run]%s %s\n' "$DIM" "$RESET" "$*"
  else
    "$@"
  fi
}

unique_path() {
  local base="$1" candidate="$1" n=2
  while [ -e "$candidate" ]; do
    candidate="$base-$n"
    n=$((n + 1))
  done
  printf '%s\n' "$candidate"
}

backup_if_exists() {
  local file="$1" backup
  [ -e "$file" ] || return 0
  if ! $DO_BACKUP; then
    warn "Skipping backup of $(basename "$file") (--no-backup)"
    return 0
  fi
  backup="$(unique_path "$file.backup-$TIMESTAMP")"
  run cp "$file" "$backup"
  if ! $DRY_RUN; then
    ok "Backed up $(basename "$file") -> $backup"
  fi
}

# ---------------------------------------------------------------- components

have_tty() {
  ( exec 3<>/dev/tty ) 2>/dev/null
}

any_selected() {
  $WANT_SETTINGS || $WANT_KEYMAP || $WANT_THEME
}

selection_names() {
  local names=""
  $WANT_SETTINGS && names="${names}settings "
  $WANT_KEYMAP && names="${names}keymap "
  $WANT_THEME && names="${names}theme "
  printf '%s' "${names% }"
}

set_all_components() {
  WANT_SETTINGS=true
  WANT_KEYMAP=true
  WANT_THEME=true
}

select_components() {
  if [ -n "$ONLY_COMPONENTS" ]; then
    WANT_SETTINGS=false
    WANT_KEYMAP=false
    WANT_THEME=false
    local items item item_lower
    items="${ONLY_COMPONENTS//,/ }"
    for item in $items; do
      item_lower="$(printf '%s' "$item" | tr '[:upper:]' '[:lower:]')"
      case "$item_lower" in
        all) set_all_components ;;
        settings|settings.json) WANT_SETTINGS=true ;;
        keymap|keymap.json) WANT_KEYMAP=true ;;
        theme|themes|theme.json) WANT_THEME=true ;;
        *) die "Unknown --only component: $item (use settings, keymap, theme, or all)" ;;
      esac
    done
    any_selected || die "--only did not select any components."
    return
  fi

  if $ASSUME_YES; then
    set_all_components
    return
  fi

  if ! have_tty; then
    info "No interactive terminal; installing all components (use --only to choose)."
    set_all_components
    return
  fi

  local choice normalized token mark
  while :; do
    {
      printf '\n%sSelect what to install%s (Enter = install, default: all)\n' "$BOLD" "$RESET"
      if $WANT_SETTINGS; then mark="[x]"; else mark="[ ]"; fi
      printf '  %s 1) settings.json\n' "$mark"
      if $WANT_KEYMAP; then mark="[x]"; else mark="[ ]"; fi
      printf '  %s 2) keymap.json\n' "$mark"
      if $WANT_THEME; then mark="[x]"; else mark="[ ]"; fi
      printf '  %s 3) Aura Dark Custom theme\n' "$mark"
      printf 'Toggle 1-3 (e.g. "1 3"), a=all, Enter=install: '
    } > /dev/tty

    if ! IFS= read -r choice < /dev/tty; then
      break
    fi

    normalized="$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    case "$normalized" in
      "") break ;;
      a|all) set_all_components ;;
      *)
        choice="${choice//,/ }"
        for token in $choice; do
          case "$token" in
            1) if $WANT_SETTINGS; then WANT_SETTINGS=false; else WANT_SETTINGS=true; fi ;;
            2) if $WANT_KEYMAP; then WANT_KEYMAP=false; else WANT_KEYMAP=true; fi ;;
            3) if $WANT_THEME; then WANT_THEME=false; else WANT_THEME=true; fi ;;
            *) printf 'Unknown choice: %s\n' "$token" > /dev/tty ;;
          esac
        done
        ;;
    esac
  done

  if ! any_selected; then
    printf 'Nothing selected; installing all components.\n' > /dev/tty 2>/dev/null || true
    set_all_components
  fi
}

# ---------------------------------------------------------------- run

printf '\n%s==>%s %salok-zed-config installer%s\n' "$CYAN" "$RESET" "$BOLD" "$RESET"
printf '    platform : %s\n' "$OS"
printf '    source   : %s\n' "${SCRIPT_DIR:-$BASE_URL}"
printf '    target   : %s\n\n' "$CONFIG_DIR"

if $DRY_RUN; then
  warn "Dry run: no files will be changed."
fi

select_components
printf '    install  : %s\n\n' "$(selection_names)"

# ---------------------------------------------------------------- preflight

fetch() {
  local url="$1" dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    die "curl or wget is required to download the config files."
  fi
}

BASE_URL="${BASE_URL%/}"

# Running from a checkout: the files sit next to this script. Running from a
# pipe (curl ... | bash): download only the selected files from BASE_URL.
NEED_SETTINGS_DOWNLOAD=false
NEED_KEYMAP_DOWNLOAD=false
NEED_THEME_DOWNLOAD=false
if $WANT_SETTINGS && [ ! -f "$SETTINGS_SRC" ]; then NEED_SETTINGS_DOWNLOAD=true; fi
if $WANT_KEYMAP && [ ! -f "$KEYMAP_SRC" ]; then NEED_KEYMAP_DOWNLOAD=true; fi
if $WANT_THEME && [ ! -f "$THEME_SRC" ]; then NEED_THEME_DOWNLOAD=true; fi

if $NEED_SETTINGS_DOWNLOAD || $NEED_KEYMAP_DOWNLOAD || $NEED_THEME_DOWNLOAD; then
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/alok-zed-config.XXXXXX" 2>/dev/null || true)"
  [ -n "$TMP_DIR" ] || die "Could not create a temporary directory."
  downloads=""
  if $NEED_SETTINGS_DOWNLOAD; then
    SETTINGS_SRC="$TMP_DIR/settings.json"
    downloads="${downloads:+$downloads, }settings.json"
  fi
  if $NEED_KEYMAP_DOWNLOAD; then
    KEYMAP_SRC="$TMP_DIR/$KEYMAP_FILE"
    downloads="${downloads:+$downloads, }${KEYMAP_FILE}"
  fi
  if $NEED_THEME_DOWNLOAD; then
    THEME_SRC="$TMP_DIR/$THEME_FILE"
    downloads="${downloads:+$downloads, }${THEME_FILE}"
  fi
  info "Downloading $downloads"
  if $NEED_SETTINGS_DOWNLOAD; then
    fetch "$BASE_URL/settings.json" "$SETTINGS_SRC" ||
      die "Could not download settings.json from $BASE_URL"
  fi
  if $NEED_KEYMAP_DOWNLOAD; then
    fetch "$BASE_URL/$KEYMAP_FILE" "$KEYMAP_SRC" ||
      die "Could not download $KEYMAP_FILE from $BASE_URL"
  fi
  if $NEED_THEME_DOWNLOAD; then
    fetch "$BASE_URL/themes/$THEME_FILE" "$THEME_SRC" ||
      die "Could not download themes/$THEME_FILE from $BASE_URL"
  fi
fi

# ---------------------------------------------------------------- install

step "Creating $CONFIG_DIR"
run mkdir -p "$CONFIG_DIR"
if $WANT_THEME; then
  run mkdir -p "$CONFIG_DIR/themes"
fi

step "Backing up existing files"
if $WANT_SETTINGS; then backup_if_exists "$SETTINGS_DEST"; fi
if $WANT_KEYMAP; then backup_if_exists "$KEYMAP_DEST"; fi
if $WANT_THEME; then backup_if_exists "$THEME_DEST"; fi

if $WANT_SETTINGS; then
  step "Installing settings.json"
  run cp "$SETTINGS_SRC" "$SETTINGS_DEST"
  if ! $DRY_RUN; then
    ok "Settings -> $SETTINGS_DEST"
  fi
fi

if $WANT_KEYMAP; then
  step "Installing $KEYMAP_FILE"
  run cp "$KEYMAP_SRC" "$KEYMAP_DEST"
  if ! $DRY_RUN; then
    ok "Keymap   -> $KEYMAP_DEST"
  fi
fi

if $WANT_THEME; then
  step "Installing $THEME_FILE"
  run cp "$THEME_SRC" "$THEME_DEST"
  if ! $DRY_RUN; then
    ok "Theme    -> $THEME_DEST"
  fi
fi

# ---------------------------------------------------------------- post-install

# Soft check: don't fail when Zed lives somewhere unusual.
have_zed=false
if [ "$OS" = "macos" ]; then
  if [ -d "/Applications/Zed.app" ] || command -v zed >/dev/null 2>&1; then
    have_zed=true
  fi
elif command -v zed >/dev/null 2>&1; then
  have_zed=true
fi
if ! $have_zed; then
  warn "Zed was not detected. Install it from https://zed.dev/download if you haven't yet."
fi

if [ "$OS" = "wsl" ]; then
  win_user=""
  if command -v cmd.exe >/dev/null 2>&1; then
    win_user="$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r' || true)"
  fi
  if [ -n "$win_user" ] && [ -d "/mnt/c/Users/$win_user/AppData/Roaming" ]; then
    warn "WSL detected: this installed into Zed for Linux."
    warn "For Zed for Windows, run: ./install.sh --dir \"/mnt/c/Users/$win_user/AppData/Roaming/Zed\""
  fi
fi

if $WANT_SETTINGS && [ -f "$SETTINGS_DEST" ] &&
  grep -q 'YOUR_[A-Z0-9_]*' "$SETTINGS_DEST" 2>/dev/null; then
  warn "settings.json still contains placeholder API keys (YOUR_*)."
fi

printf '\n%sDone.%s' "$BOLD" "$RESET"
if $WANT_THEME; then
  printf ' Restart Zed, then choose %sAura Dark Custom%s from the theme selector.' "$BOLD" "$RESET"
fi
printf '\n'
printf 'Installed: %s\n' "$(selection_names)"

if $WANT_THEME || $WANT_SETTINGS; then
  printf '\nNext steps:\n'
  step_number=1
  if $WANT_THEME; then
    printf '  %d. Quit Zed completely and reopen it (local themes load at startup).\n' "$step_number"
    step_number=$((step_number + 1))
    printf '  %d. Open the command palette and run "theme selector: toggle".\n' "$step_number"
    step_number=$((step_number + 1))
    printf '  %d. Pick "Aura Dark Custom" for dark mode (light mode uses Ayu Light).\n' "$step_number"
    step_number=$((step_number + 1))
  fi
  if $WANT_SETTINGS; then
    printf '  %d. Replace the YOUR_* placeholders in:\n       %s\n' "$step_number" "$SETTINGS_DEST"
  fi
fi

printf '\nNotes:\n'
if $WANT_KEYMAP; then
  printf '  - keymap.json adds ctrl/ctrl-alt shortcuts on top of the VSCode base\n'
  printf '    keymap. See KEYBINDINGS.md for the full list.\n'
fi
if $WANT_SETTINGS; then
  printf '  - "Material Icon Theme" is referenced by settings.json. Install that\n'
  printf '    extension, or change "icon_theme" to a built-in theme.\n'
  printf '  - Colored TODO/INFO/WARN/FIXME tags need the Comments Highlighter extension.\n'
fi
printf '  - See README.md for secrets, extensions, and troubleshooting.\n\n'
