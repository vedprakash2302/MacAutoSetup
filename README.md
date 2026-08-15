# MacAutoSetup

One-command, repeatable development environment setup for macOS and Linux.

## Install or upgrade

```sh
bash -c "$(curl -fsSL https://github.com/vedprakash2302/MacAutoSetup/releases/latest/download/bootstrap)"
```

The same command upgrades an existing clean installation to the newest tested release.

Defaults are selected automatically:

- macOS: portable terminal tools, development runtimes, curated desktop applications, dotfiles, and tracked macOS preferences.
- Linux: portable terminal tools, development runtimes, and terminal dotfiles without GUI software.

Supported Linux targets are Ubuntu 22.04/24.04 and Amazon Linux 2/2023 on x86_64 or ARM64.

The bootstrap expects Bash, `curl`, outbound HTTPS, a supported package manager, and administrator access. Password and macOS permission prompts may still appear.

## Options

```sh
# Preview without changing the machine
~/.local/share/macautosetup/repo/bin/setup --dry-run

# Install Docker on Linux and its terminal UI
bash -c "$(curl -fsSL https://github.com/vedprakash2302/MacAutoSetup/releases/latest/download/bootstrap)" -- --with-docker

# Install AWS CLI
bash -c "$(curl -fsSL https://github.com/vedprakash2302/MacAutoSetup/releases/latest/download/bootstrap)" -- --with-aws

# Install optional personal Mac applications
bash -c "$(curl -fsSL https://github.com/vedprakash2302/MacAutoSetup/releases/latest/download/bootstrap)" -- --with-personal-apps

# Keep the current login shell or skip all macOS preferences
~/.local/share/macautosetup/repo/bin/setup --no-shell-change --no-macos-defaults

# Also empty the Dock, replace keyboard shortcuts, and apply undocumented tweaks
~/.local/share/macautosetup/repo/bin/setup \
  --minimal-dock --keyboard-shortcuts --experimental-macos-defaults
```

The macOS workstation profile applies a conservative set of keyboard, text-entry, Finder, Dock, and TextEdit preferences by default. The server profile does not change macOS preferences. Potentially destructive or hardware-sensitive changes are separate opt-ins:

- `--minimal-dock` removes every pinned Dock app and shows only running apps.
- `--keyboard-shortcuts` replaces the complete macOS symbolic-hotkey domain with the tracked snapshot.
- `--experimental-macos-defaults` applies opaque Finder enums and undocumented function-key, pointing-device, window-dragging, and Dock-animation keys. These are version-gated because Apple may change them between macOS releases.

Use `MACAUTOSETUP_ALLOW_UNTESTED_MACOS=1` to explicitly permit the last two options on a macOS major version not yet covered by this repository. Use `--dry-run` with any combination to inspect every `defaults` command without modifying the machine.

## Author mode

Stable installations use tested release tags. On a machine where you actively edit these dotfiles, install the `main` branch instead:

```sh
AUTHOR_MODE=1 bash -c "$(curl -fsSL https://github.com/vedprakash2302/MacAutoSetup/releases/latest/download/bootstrap)"
```

The managed checkout lives at `~/.local/share/macautosetup/repo`. Setup refuses to upgrade a dirty checkout so local work is never discarded.

## Profiles

- **Core:** Git, Zsh, fzf, fd, ripgrep, bat, jq, yq, tmux, Stow, Starship, zoxide, btop, and `tldr` via tlrc.
- **Development:** Mise-managed Node, Python, Neovim, Tree-sitter CLI, GitHub CLI, delta, and lazygit.
- **Workstation:** Cursor, Ghostty, Raycast, Docker Desktop, Aerospace, ChatGPT, Zed, Dia, Google Chrome, Shottr, Jump Desktop, Hidden Bar, Logitech Options+, Bitwarden CLI, Amphetamine, Peek, and JetBrains Mono Nerd Font.
- **Server:** terminal-only configuration; Docker and AWS CLI are opt-in.

Mise pins Node, Python, Neovim, and cross-platform CLI versions. Homebrew supplies the few tools without compatible macOS release assets. Direct bootstrap downloads are versioned and checksum-verified.
LazyVim restores its committed plugin lock and language tooling the first time Neovim opens.
Mac App Store installations require you to be signed into the App Store; Homebrew installs `mas` before those applications are requested.

## Safety and recovery

Existing unmanaged dotfiles are moved to:

```text
~/.local/state/macautosetup/backups/<timestamp>/
```

The installer never recursively deletes existing configuration. GNU Stow is required; if it cannot be installed, setup stops.
The backup ledger is retained after uninstall so recovery locations are not forgotten.

Before macOS preferences are changed, the affected domains are exported to:

```text
~/.local/state/macautosetup/macos-preferences/<timestamp>/
```

Restore the most recent snapshot, or a specific snapshot, with:

```sh
~/.local/share/macautosetup/repo/bin/macos-restore
~/.local/share/macautosetup/repo/bin/macos-restore ~/.local/state/macautosetup/macos-preferences/<timestamp>
```

Restoration replaces each affected preference domain with its saved version, so use the snapshot made immediately before the setup run you want to undo.

Check the installation:

```sh
~/.local/share/macautosetup/repo/bin/doctor
```

Remove managed links while leaving installed packages in place:

```sh
~/.local/share/macautosetup/repo/bin/uninstall
```

Restore all recorded conflict backups, oldest first, while unlinking:

```sh
~/.local/share/macautosetup/repo/bin/uninstall --restore-backup
```

Machine-specific or private shell configuration belongs in `~/.zshrc.local`, which is sourced when present and is not tracked by this repository.

## Development

```sh
./tests/test.sh
./bin/setup --dry-run
./bin/update-locks
```

Create a tagged release only after CI passes. The release workflow publishes a bootstrap asset containing the exact tag and commit it will install.
