# Zed keybindings

`keymap.json` is layered on Zed's **VSCode** base keymap (`base_keymap` in
`settings.json`), so the usual VS Code shortcuts already work. This page
covers the custom bindings and the defaults worth memorizing.

> Edit the keymap with `⌘K ⌘S`, or run **zed: open default keymap** from the
> command palette to see every default. The which-key menu is enabled in
> `settings.json`, so pending chords show their options automatically; `⌥/`
> also opens the list.

## Custom bindings

| Shortcut | Action |
| --- | --- |
| `⌃B` | Toggle the right dock |
| `⌃P` | Focus the project panel |
| ``⌃` `` | Toggle the terminal panel |
| `⌃⇧F` | Search the project |
| `⌃⇧H` | Search and replace in the project |
| `⌃⇧T` | Reopen the last closed tab |
| `⌃⌥P` | Toggle AI edit predictions (autocomplete) |
| `⌃⌥I` | Toggle inlay hints |
| `⌃⌥G` | Toggle inline git blame |
| `⇧` `⇧` (double tap) | File finder |
| `⌃O` | Move cursor left (kept from the original keymap) |
| `⌥F` | Focus the search field (inside project search) |

To make room for the ctrl-based layout, these macOS defaults are unbound:
`⌘R` and `⌘J` (dock toggles) and `⌘⇧E` (project panel focus). Inside the
editor, the Emacs-style `⌃B` / `⌃P` / `⌃⇧F` cursor bindings are also removed
so the ctrl shortcuts above work while editing.

`⌃⌥P`, `⌃⌥I` and `⌃⌥G` are native Zed toggles for edit predictions, inlay
hints and inline git blame.

## Files and search

| Shortcut | Action |
| --- | --- |
| `⌘P` | Go to file |
| `⌘⇧P` | Command palette |
| `⌘⇧F` | Project search |
| `⌘⇧H` | Project search and replace |
| `⌘E` | Use selection for find |
| `⌘G` / `⌘⇧G` | Next / previous match |
| `⌃G` | Go to line |
| `⌘T` | Go to symbol in project |
| `⌘⇧O` | Go to symbol in file |
| `⌘K ⌘P` | Reopen the last picker |
| `⌃-` / `⌃_` | Go back / forward |

## Editing

| Shortcut | Action |
| --- | --- |
| `⌘/` | Toggle line comment |
| `⌘K ⌘/` | Toggle block comment |
| `⇧⌥F` | Format document |
| `⌥↑` / `⌥↓` | Move line up / down |
| `⇧⌥↑` / `⇧⌥↓` | Duplicate line up / down |
| `⌘⇧K` | Delete line |
| `⌘D` | Select next occurrence |
| `⌘⇧L` | Select all occurrences |
| `⌃J` | Join lines |
| `⌥Z` | Toggle soft wrap |
| `F2` | Rename symbol |
| `F12` / `⌥F12` | Go to definition / open it to the side |
| `F8` / `⇧F8` | Next / previous diagnostic |
| `⌘.` | Code actions |
| `⌃Space` | Trigger completions |

## Panes and tabs

| Shortcut | Action |
| --- | --- |
| `⌘\` | Split right |
| `⌘K ↑` `⌘K ↓` `⌘K ←` `⌘K →` | Split up / down / left / right |
| `⌘1` … `⌘9` | Focus pane 1–9 |
| `⌘K ←` / `⌘K →` | Focus pane left / right |
| `⌘K ⇧←` / `⌘K ⇧→` | Move pane left / right |
| `⌃Tab` / `⌃⇧Tab` | Tab switcher |
| `⌘W` | Close tab |
| `⌘⇧T` | Reopen closed tab |
| `⌘K W` | Close all tabs |
| `⇧Esc` | Zoom the active pane |
| `⌘K Z` | Centered layout (Zen-ish) |
| `⌃⌘F` | Toggle full screen |

## Panels, git, and AI

| Shortcut | Action |
| --- | --- |
| `⌘B` | Toggle the left dock |
| `⌃⇧G` | Focus the git panel |
| `⌘↵` | Commit (in the git panel) |
| `⌘⇧↵` | Amend commit |
| `⌘K ⌘B` | Show blame for the current line |
| `⌘⇧M` | Show diagnostics |
| `⌘?` | Toggle the agent panel |
| `⌃⌘I` | Toggle the agent panel (VS Code binding) |
| ``⌃` `` | Toggle the terminal panel |
| `⌃~` | New terminal |
| `⌘K R` | Reveal in Finder |
| `⌘K P` | Copy path |

## Handy chords to know

| Shortcut | Action |
| --- | --- |
| `⌘K ⌘S` | Open `keymap.json` |
| `⌘K ⌘T` | Theme selector |
| `⌘K ⌘⇧T` | Toggle light / dark mode |
| `⌘,` | Open settings |
| `⌘⇧X` | Extensions |
| `⌘⌥S` | Save all |
