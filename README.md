# alok-zed-config

Zed settings + the bundled **Aura Dark Custom** theme.

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

The command downloads the settings and theme, backs up your old
`settings.json`, and installs everything. Then quit and reopen Zed, open the
theme selector (`theme selector: toggle`) and pick **Aura Dark Custom**.

## Optional

- **Comments Highlighter** extension — colored `TODO` / `INFO` / `WARN` /
  `FIXME` tags.
- **Material Icon Theme** extension — used by `icon_theme`, or change it to a
  built-in theme.
- Fill in the `YOUR_*` placeholders in `settings.json` if you use GitHub MCP,
  Context7, or WakaTime.

## Run from a clone instead

```bash
git clone https://github.com/alok-mishra143/alok-zed-config.git
cd alok-zed-config
./install.sh
```

Uninstall: delete `themes/aura-dark-custom.json` and restore the newest
`settings.json.backup-*` in your Zed config folder (`~/.config/zed` on
macOS/Linux, `%APPDATA%\Zed` on Windows).
