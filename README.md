# Vedup

Vedup is a one-command, safe machine synchronizer for macOS and Linux. It can
bootstrap an empty machine, fill gaps on an existing machine, update only the
configuration it owns, or resume an interrupted run.

## Run it

After `v1.0.0` is published:

```sh
bash -c "$(curl -fsSL https://github.com/vedprakash2302/MacAutoSetup/releases/latest/download/bootstrap)"
```

With a terminal, no arguments opens the adaptive installer. It detects the
machine and one of four workflows: fresh, existing unmanaged, existing Vedup,
or interrupted. Existing Vedup choices are restored automatically. The review
shows counts for missing, updating, configuring, unchanged, reviewed, and
conflicting resources before anything changes.

For automation, pass flags after `--`:

```sh
bash -c "$(curl -fsSL https://github.com/vedprakash2302/MacAutoSetup/releases/latest/download/bootstrap)" -- \
  --non-interactive --profile server --with-aws
```

Supported targets are macOS on Intel and Apple Silicon, Ubuntu 22.04/24.04,
and Amazon Linux 2023 on x86_64 or ARM64. A fresh machine needs Bash, curl,
tar, a SHA-256 utility, outbound HTTPS, and administrator access for whichever
planned resources require it. Git is not a bootstrap dependency.
Amazon Linux 2 reached end-of-support on June 30, 2026; Vedup refuses to alter
it and directs the user to migrate to Amazon Linux 2023.

## What Safe sync means

Vedup inventories the machine before asking for sudo or making changes. Every
resource is classified as `vedup-managed`, `external`, or
`unmanaged-conflict`; every action is `install`, `update`, `keep`, `configure`,
`review`, or `conflict`.

The default Safe sync policy is:

- install missing software;
- update release-pinned Mise tools and plugins already owned by Vedup;
- preserve compatible externally installed software without adopting it;
- apply only differing managed configuration;
- retain unselected or removed software and report manual-removal guidance;
- never perform a general Homebrew, APT, DNF/YUM, App Store, or OS upgrade;
- never silently update an installed GUI application.

Running Safe sync twice against the same release should make no resource
changes on the second run. `--dry-run` generates and prints the same inventory
plan used by a real run.

For tools pinned through Mise, “compatible” means the release-pinned version is
already available to Mise. If only a system or third-party copy exists, Vedup
leaves that copy untouched and installs its isolated pinned version alongside
it; the managed shell selects Vedup's version without uninstalling the external
provider.

## macOS Git and Homebrew

Vedup uses Apple Command Line Tools Git. Homebrew Git is not in the required
package set. If Homebrew Git already exists, Vedup leaves it installed and
reports it through `doctor`; it never changes `.gitconfig`, credential helpers,
GitHub credentials, or Keychain permissions.

Homebrew is installed with `NONINTERACTIVE=1` after confirmation. Formulae and
casks are inspected first and installed with auto-update and install-upgrade
suppression. Workstation applications use `brew bundle --no-upgrade`. Missing
required App Store IDs are installed after `mas` is available; unrelated App
Store applications are not updated.

The workstation bundle contains Ghostty, Cursor, Zed, Docker Desktop, Chrome,
Dia, ChatGPT, Raycast, Aerospace and Borders, Shottr, Jump Desktop, Hidden Bar,
Logi Options+, Bitwarden CLI, Amphetamine, Peek, and the JetBrains Mono Nerd
Font. Personal applications remain an explicit optional component.

Installed GUI updates appear in a separate interactive review and start
unchecked. For deliberate non-interactive maintenance, use:

```sh
~/.local/share/vedup/current/bin/setup --upgrade-apps
```

## Profiles and options

The server profile installs terminal development tools and no desktop apps.
The macOS workstation profile adds the curated app bundle and conservative
preferences.

```text
--profile auto|server|workstation
--with-aws | --without-aws
--with-docker | --without-docker
--with-personal-apps | --without-personal-apps
--upgrade-apps
--dry-run
--verbose
--jobs 1..8
--interactive
--non-interactive
--macos-defaults | --no-macos-defaults
--minimal-dock | --no-minimal-dock
--keyboard-shortcuts | --no-keyboard-shortcuts
--experimental-macos-defaults | --no-experimental-macos-defaults
--shell-change | --no-shell-change
--no-verify
```

`--minimal-dock`, `--keyboard-shortcuts`, and
`--experimental-macos-defaults` are high-impact opt-ins. The latter two are
version-gated for tested macOS releases. `--no-verify` skips extended checks,
but a minimal activation health check still runs: an unverified release is
never made current.

Mise supplies pinned Node, Python, Neovim, Starship, zoxide, ripgrep, fd, bat,
fzf, Carapace, jq, yq, delta, lazygit, btop, GitHub CLI, Tree-sitter CLI, tlrc,
and selected AWS/Docker terminal tools where supported. Vedup also pins the Zsh
autosuggestions, syntax-highlighting, history-substring-search, completions,
git-alias, and zsh-you-should-use plugins plus the tracked tmux plugins.

## Releases and state

Every GitHub release contains three assets:

- `bootstrap`, embedding the exact release tag, commit, and archive checksum;
- `vedup-<version>.tar.gz`, an immutable source archive;
- `checksums.txt`.

Verified releases are extracted to:

```text
~/.local/share/vedup/releases/<version>-<commit>/
```

The pending release runs directly from that directory. Only after configuration
and `doctor` succeed does Vedup atomically switch:

```text
~/.local/share/vedup/current
```

Validated, non-executable TSV state and resource ownership live under:

```text
~/.local/state/vedup/
```

Each run journals progress immediately in `transactions/<id>/journal.tsv`.
Failed runs retain their pending release and journal; rerunning the one-liner
re-inventories the observed machine and performs only remaining actions.

An existing `~/.local/state/macautosetup/install.env` is parsed conservatively
as data and migrated after confirmation. The old
`~/.local/share/macautosetup/repo` checkout is never deleted or modified, so it
remains available as a recovery source.

## Friendly progress and recovery

Interactive runs use a fixed dashboard with a progress bar, elapsed-time
spinner, and the latest five log lines. Package output stays in the detailed
log instead of scrolling the dashboard away. `--verbose` streams everything.

```text
~/.local/state/vedup/logs/<timestamp>.log
```

Vedup requests administrator approval only when the generated plan contains a
privileged action. Passwordless sudo is used when available; otherwise one
visible sudo prompt is kept alive for the run. Vedup never reads, stores, or
changes the password or sudo policy.

Dotfiles are preflighted with Stow before anything moves. Every conflict backup
and previous link target is journaled immediately. Linking or health-check
failure restores the old links and conflicts automatically. Recovery copies
are listed under:

```text
~/.local/state/vedup/backups/
```

macOS preference runs export the touched domains and a key manifest recording
whether each key previously existed. Only differing scalar values are written.
Immediate failure restores the snapshot and deletes newly introduced keys.

```text
~/.local/state/vedup/macos-preferences/
```

Useful commands:

```sh
~/.local/share/vedup/current/bin/doctor
~/.local/share/vedup/current/bin/macos-restore
~/.local/share/vedup/current/bin/uninstall
~/.local/share/vedup/current/bin/uninstall --restore-backup
```

Package installation is additive and cannot be reliably rolled back, so
`uninstall` removes managed configuration links while leaving software intact.

## Contributing and releasing

Remote `AUTHOR_MODE` is intentionally unsupported. Work in a separate clone:

```sh
git clone https://github.com/vedprakash2302/MacAutoSetup.git
cd MacAutoSetup
./bin/install
```

Run validation with:

```sh
./tests/test.sh
./bin/setup --dry-run
```

### Disposable validation—no spare Mac required

The **Disposable machine canary** GitHub Actions workflow creates temporary
GitHub-hosted machines and containers; they are destroyed after the run. You do
not need to own, borrow, or wipe another Mac. The workflow performs:

- a real terminal-profile synchronization followed by a required no-op second
  run on macOS 15 and Ubuntu 24.04;
- migration from an actual `f676941` dotfile installation on disposable macOS
  and Ubuntu runners, again followed by a no-op run;
- two-run synchronization inside Amazon Linux 2023, plus a clear rejection
  check for end-of-support Amazon Linux 2.

GitHub's macOS runner already contains Apple Command Line Tools and Homebrew,
so the literal factory-fresh installation of those two prerequisites is tested
with hermetic fixtures rather than by erasing physical hardware. macOS CI still
validates every official Brewfile token and third-party tap without installing
the desktop application bundle.

After the release branch is merged, run the canary from GitHub's **Actions**
tab, or with GitHub CLI:

```sh
gh workflow run canary.yml --ref main -f ref=main
gh run list --workflow canary.yml --limit 1
gh run watch <run-id> --exit-status
```

### Publish `v1.0.0`

Publish only after normal CI and every disposable canary job passes:

```sh
git switch main
git pull --ff-only
git tag -a v1.0.0 -m "Vedup v1.0.0"
git push origin v1.0.0
```

The tag-gated release workflow reruns Ubuntu and macOS validation, builds the
immutable archive, embeds its checksum in `bootstrap`, verifies the assets, and
publishes all three files. Confirm the release and one-liner afterward:

```sh
gh release view v1.0.0
curl -fsSL https://github.com/vedprakash2302/MacAutoSetup/releases/download/v1.0.0/checksums.txt
bash -c "$(curl -fsSL https://github.com/vedprakash2302/MacAutoSetup/releases/latest/download/bootstrap)" -- --dry-run --no-shell-change
```
