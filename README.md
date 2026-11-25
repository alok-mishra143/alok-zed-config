# alok-zed-config

Zed settings, keymap and the bundled **Aura Dark Custom** theme.

<img width="2400" height="1350" alt="image" src="https://github.com/user-attachments/assets/925e2716-d265-4ea8-aca8-922daeea6728" />


## Install

Quit Zed, then paste one line into a terminal. No clone, no extra tools.

**macOS / Linux / Windows (Git Bash or WSL):**

```bash
curl -fsSL https://raw.githubusercontent.com/alok-mishra143/alok-zed-config/main/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/alok-mishra143/alok-zed-config/main/install.ps1 | iex
```

The command asks which parts to install — **settings.json**, **keymap.json**
and the **Aura Dark Custom** theme — with all three selected by default. Press
Enter to install all, or toggle components with `1`–`3` first. It backs up your
old files and installs the selection. Then quit and reopen Zed, open the theme
selector (`theme selector: toggle`) and pick **Aura Dark Custom**.

To skip the prompt:

```bash
# Install everything without asking
curl -fsSL https://raw.githubusercontent.com/alok-mishra143/alok-zed-config/main/install.sh | bash -s -- --yes

# Install only the keymap and theme
curl -fsSL https://raw.githubusercontent.com/alok-mishra143/alok-zed-config/main/install.sh | bash -s -- --only keymap,theme
```

Other `--only` values: `settings`, `theme`, `all`. From a checkout you can also
run `./install.sh --only settings` directly. On Windows the installer shows the
same checklist, and `install.ps1 -Only keymap,theme` / `-Yes` work when run from
a checkout.

## Keybindings

`keymap.json` layers a few ctrl-based conveniences on top of the **VSCode**
base keymap:

| Shortcut | Action |
| --- | --- |
| `⌃B` | Toggle the right dock |
| `⌃P` | Focus the project panel |
| ``⌃` `` | Toggle the terminal panel |
| `⌃⇧F` / `⌃⇧H` | Project search / search and replace |
| `⌃⇧T` | Reopen the last closed tab |
| `⌃⌥P` | Toggle AI edit predictions |
| `⌃⌥I` / `⌃⌥G` | Toggle inlay hints / inline git blame |
| `⇧` `⇧` | File finder |

Everything else stays on the familiar VS Code shortcuts. See
[KEYBINDINGS.md](KEYBINDINGS.md) for the custom bindings plus a cheat sheet of
the defaults worth memorizing.

Edit the keymap with `⌘K ⌘S`; run `zed: open default keymap` from the command
palette to inspect the defaults.

## Quality of life

Settings added on top of the original config:

- **Which-key menu** — pending chords show their possible continuations.
- **Preview tabs** from the file finder — `⌘P` reuses a tab instead of opening
  a new one each time, like VS Code.
- **Keep window open** when the last tab is closed (`⌘W` no longer quits the
  window).
- **Faster scanning** — `node_modules`, `.next`, `dist`, `build`, `target`,
  `.venv` and `__pycache__` are excluded from project scans and search.
- **Web formatting** — format-on-save for JavaScript, JSON, CSS, SCSS and
  HTML, with 2-space indentation for web languages.

## Optional

- **Comments Highlighter** extension — colored `TODO` / `INFO` / `WARN` /
  `FIXME` tags.
- **Material Icon Theme** extension — used by `icon_theme`, or change it to a
  built-in theme.
- Fill in the `YOUR_*` placeholders in `settings.json` if you use GitHub MCP,
  Context7, or WakaTime.
- `terminal.font_family` is set to **JetBrainsMono Nerd Font**; install it or
  change the family if it is missing.

## Run from a clone instead

```bash
git clone https://github.com/alok-mishra143/alok-zed-config.git
cd alok-zed-config
./install.sh
```

Uninstall: delete `keymap.json`, `themes/aura-dark-custom.json` and restore the
newest `*.backup-*` files in your Zed config folder (`~/.config/zed` on
macOS/Linux, `%APPDATA%\Zed` on Windows).
