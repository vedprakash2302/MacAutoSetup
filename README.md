# Vedup

Vedup sets up a comfortable development environment on macOS and Linux, then
keeps it synchronized without taking over software or settings it does not own.

## Set up a machine

Run one command:

```sh
bash -c "$(curl -fsSL https://github.com/vedprakash2302/MacAutoSetup/releases/latest/download/bootstrap)"
```

Vedup detects the operating system, inspects what is already present, and shows
one short review. Choose **Set up this machine** and it installs only what is
missing. You do not need to remember separate setup commands or flags.

On a previously configured machine, run the same command again. Vedup restores
your choices and either shows only the work that remains or says that everything
is current. It does not reinstall every tool.

Supported systems:

- macOS on Apple Silicon or Intel;
- Ubuntu 22.04 and 24.04 on x86_64 or ARM64;
- Amazon Linux 2023 on x86_64 or ARM64.

## What the installer looks like

The first screen contains a plain-language summary:

```text
Ready to set up this Mac

✓ Development tools, terminal configuration and Zsh
✓ Recommended Mac applications
✓ Safe macOS preferences

Install       18 missing items
Configure      3 setting groups
Already ready 22 existing items preserved

Set up this machine   Customize   Show details   Exit
```

**Customize** opens a small set of bundles such as Recommended Apps, AWS tools,
Docker, and Optional Apps. On macOS, **Choose individual applications** lets you
select every app separately. No application is compulsory. New apps added to a
future Vedup release inherit the bundle choice, while your individual overrides
remain saved.

High-impact macOS changes—Dock replacement, shortcut replacement, and
experimental preferences—live under **Advanced**. Existing selections are
preserved, but a normal setup never puts these controls in the main flow.

During installation, a fixed dashboard shows the current task, elapsed time,
progress, and the latest five activity lines. Full output is written to:

```text
~/.local/state/vedup/logs/
```

## After installation

Run `vedup` with no arguments for the friendly home menu:

```text
Sync this machine
Customize setup
Save local changes
Update Vedup
Update applications        # macOS
Diagnose a problem
Advanced                   # macOS
Exit
```

The command names are optional shortcuts, not steps you must memorize:

```sh
vedup sync
vedup customize
vedup update
vedup save
vedup apps update
vedup doctor
vedup advanced
```

`vedup update` updates only the Vedup program. It downloads and verifies the
latest immutable release, switches the `current` link atomically, and leaves
applications, tools, dotfiles, and system settings untouched. Run `vedup sync`
separately when you want to apply setup changes introduced by that release.

`vedup save` reviews local edits and newly installed applications, excludes
secret-like files, runs a pinned secret scan and the full test suite, and saves
the selected changes on a dedicated branch. With publishing enabled it opens a
**draft** pull request; it never merges, tags, or releases captured changes.

## Safe by default

Vedup inventories before it changes anything. A normal sync:

- installs missing software;
- updates only release-pinned tools and configuration owned by Vedup;
- preserves compatible externally installed software;
- preserves unselected software rather than uninstalling it;
- never performs general Homebrew, APT, DNF/YUM, App Store, or OS upgrades;
- never silently upgrades an installed GUI application;
- never edits `.gitconfig`, Git credential helpers, GitHub credentials, or
  Keychain permissions.

On macOS, Vedup uses Apple Command Line Tools Git. An existing Homebrew Git is
left untouched. GUI updates are available separately through
`vedup apps update` and begin unchecked.

Configuration linking and macOS preference changes are backed up and rolled
back if verification fails. Package installation is additive and resumable.
The `current` CLI may update independently, while the separate `applied`
release changes only after synchronization passes its health check.

## What gets installed

The terminal environment includes Git, Zsh, tmux, Neovim, Starship, Mise,
Node, Python, modern search/file tools, GitHub CLI, lazygit, shell completions,
autosuggestions, syntax highlighting, history search, Git aliases, and the
tracked Zsh/tmux plugins.

The Recommended Mac Apps bundle includes Ghostty, Cursor, Zed, Docker Desktop,
Chrome, Dia, ChatGPT, Raycast, Aerospace, Borders, Shottr, Jump Desktop,
Hidden Bar, Logi Options+, Bitwarden CLI, Amphetamine, Peek, Focus, Linear,
PDFgear, T3 Code Nightly, and the JetBrains Mono Nerd Font. The exact,
deduplicated inventory is [profiles/macos/apps.tsv](profiles/macos/apps.tsv).

## More detail

- [Automation and flags](docs/automation.md)
- [Safety, state, recovery, and reruns](docs/safety.md)
- [Architecture](docs/architecture.md)
- [Contributing and releasing](docs/contributing.md)
