#!/usr/bin/env bash

set -euo pipefail

# Detect package manager
detect_pkg_manager() {
	if command -v apt-get &>/dev/null; then
		echo apt
	elif command -v dnf &>/dev/null; then
		echo dnf
	elif command -v yum &>/dev/null; then
		echo yum
	elif command -v pacman &>/dev/null; then
		echo pacman
	elif command -v zypper &>/dev/null; then
		echo zypper
	else
		echo "unsupported"
	fi
}

PKG_MGR=$(detect_pkg_manager)
if [[ "$PKG_MGR" == "unsupported" ]]; then
	echo "Unsupported Linux distribution. Install dependencies manually: zsh, git, stow, tmux, neovim/vim, curl, starship"
	exit 1
fi

echo "Using package manager: $PKG_MGR"

# Update package lists
case "$PKG_MGR" in
	apt)
		sudo apt-get update -y
		;;
	dnf)
		sudo dnf makecache -y || true
		;;
	yum)
		sudo yum makecache -y || true
		;;
	pacman)
		sudo pacman -Sy --noconfirm
		;;
	zypper)
		sudo zypper refresh
		;;
esac

# Install base packages
install_packages() {
	local packages=(git curl zsh tmux)

	case "$PKG_MGR" in
		apt)
			sudo apt-get install -y "${packages[@]}"
			;;
		dnf)
			sudo dnf install -y "${packages[@]}"
			;;
		yum)
			sudo yum install -y "${packages[@]}"
			;;
		pacman)
			sudo pacman -S --needed --noconfirm "${packages[@]}"
			;;
		zypper)
			sudo zypper install -y "${packages[@]}"
			;;
		*)
			echo "Unsupported package manager during install"
			exit 1
			;;
	esac
}

install_packages

# Ensure GNU Stow is available (handles Amazon Linux 2023/EPEL case)
ensure_stow() {
	if command -v stow &>/dev/null; then
		return
	fi

	echo "Ensuring GNU Stow is installed..."
	case "$PKG_MGR" in
		apt)
			sudo apt-get install -y stow
			;;
		dnf)
			# Try native repo first
			sudo dnf install -y stow || {
				# Enable EPEL for EL9-compatible systems (Amazon Linux 2023)
				sudo dnf install -y epel-release || sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm || true
				sudo dnf makecache -y || true
				sudo dnf install -y stow || {
					# Fallback: build from source (Perl-based)
					echo "Installing stow from source..."
					tmpdir=$(mktemp -d)
					curl -fsSL https://ftp.gnu.org/gnu/stow/stow-latest.tar.gz -o "$tmpdir/stow.tar.gz"
					tar -xzf "$tmpdir/stow.tar.gz" -C "$tmpdir"
					cd "$tmpdir"/stow-* || exit 1
					sudo dnf install -y make perl || true
					perl Makefile.PL PREFIX=/usr/local
					make
					sudo make install
				}
			}
			;;
		yum)
			# RHEL/CentOS older flavors
			sudo yum install -y stow || {
				sudo yum install -y epel-release || true
				sudo yum makecache -y || true
				sudo yum install -y stow || {
					echo "Installing stow from source..."
					tmpdir=$(mktemp -d)
					curl -fsSL https://ftp.gnu.org/gnu/stow/stow-latest.tar.gz -o "$tmpdir/stow.tar.gz"
					tar -xzf "$tmpdir/stow.tar.gz" -C "$tmpdir"
					cd "$tmpdir"/stow-* || exit 1
					sudo yum install -y make perl || true
					perl Makefile.PL PREFIX=/usr/local
					make
					sudo make install
				}
			}
			;;
		pacman)
			sudo pacman -S --needed --noconfirm stow
			;;
		zypper)
			sudo zypper install -y stow
			;;
		*)
			echo "[warn] Unknown package manager; please install stow manually."
			;;
	esac

	if ! command -v stow &>/dev/null; then
		echo "[error] Failed to install GNU Stow. Exiting."
		exit 1
	fi
}

ensure_stow

# Install editor with fallback: prefer neovim, fallback to vim when unavailable
install_editor() {
	echo "Installing editor (neovim preferred, vim fallback)..."
	case "$PKG_MGR" in
		apt)
			sudo apt-get install -y neovim || sudo apt-get install -y vim
			;;
		dnf)
			sudo dnf install -y neovim || sudo dnf install -y vim-enhanced
			;;
		yum)
			sudo yum install -y neovim || sudo yum install -y vim-enhanced
			;;
		pacman)
			sudo pacman -S --needed --noconfirm neovim || sudo pacman -S --needed --noconfirm vim
			;;
		zypper)
			sudo zypper install -y neovim || sudo zypper install -y vim
			;;
		*)
			echo "Unknown package manager for editor install"
			;;
	esac
}

install_editor

# Install common terminal CLI tools from Brewfile (best-effort, per-distro names)
install_cli_tools() {
	echo "Installing terminal CLI tools..."

	install_pkg() {
		local name="$1"
		case "$PKG_MGR" in
			apt)
				sudo apt-get install -y "$name" || echo "[warn] apt couldn't install $name"
				;;
			dnf)
				sudo dnf install -y "$name" || echo "[warn] dnf couldn't install $name"
				;;
			yum)
				sudo yum install -y "$name" || echo "[warn] yum couldn't install $name"
				;;
			pacman)
				sudo pacman -S --needed --noconfirm "$name" || echo "[warn] pacman couldn't install $name"
				;;
			zypper)
				sudo zypper install -y "$name" || echo "[warn] zypper couldn't install $name"
				;;
			*)
				echo "[warn] Unsupported package manager for $name"
				;;
		esac
	}

	case "$PKG_MGR" in
		apt)
			# Map Brewfile -> apt names
			for pkg in \
				fzf \
				fd-find \
				tealdeer \
				wget \
				ripgrep \
				bat \
				btop \
				lazygit \
				jq \
				yq \
				gh \
				git-delta \
				zoxide; do
				install_pkg "$pkg"
			done
			;;
		dnf)
			for pkg in \
				fzf \
				fd-find \
				tealdeer \
				wget \
				ripgrep \
				bat \
				btop \
				lazygit \
				jq \
				yq \
				gh \
				git-delta \
				zoxide; do
				install_pkg "$pkg"
			done
			;;
		yum)
			for pkg in \
				fzf \
				fd-find \
				tealdeer \
				wget \
				ripgrep \
				bat \
				btop \
				lazygit \
				jq \
				yq \
				gh \
				git-delta \
				zoxide; do
				install_pkg "$pkg"
			done
			;;
		pacman)
			for pkg in \
				fzf \
				fd \
				tealdeer \
				wget \
				ripgrep \
				bat \
				btop \
				lazygit \
				jq \
				yq \
				gh \
				git-delta \
				zoxide; do
				install_pkg "$pkg"
			done
			;;
		zypper)
			for pkg in \
				fzf \
				fd \
				tealdeer \
				wget \
				ripgrep \
				bat \
				btop \
				lazygit \
				jq \
				yq \
				gh \
				git-delta \
				zoxide; do
				install_pkg "$pkg"
			done
			;;
		*)
			echo "[warn] Unknown package manager for CLI tools"
			;;
	esac

	# Fallback installs where package may not exist
	if ! command -v zoxide &>/dev/null; then
		echo "Installing zoxide via official script..."
		curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash -s -- -y || true
	fi

	# Optionally install lazydocker (not always in repos)
	if [[ "${INSTALL_LAZYDOCKER:-1}" == "1" ]] && ! command -v lazydocker &>/dev/null; then
		echo "Installing lazydocker via install script..."
		curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash || true
	fi

	# Post-install symlinks for Debian-based naming quirks
	if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
		mkdir -p "$HOME/.local/bin"
		ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
		echo "Symlinked fdfind -> $HOME/.local/bin/fd"
	fi
	if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
		mkdir -p "$HOME/.local/bin"
		ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
		echo "Symlinked batcat -> $HOME/.local/bin/bat"
	fi
}

install_cli_tools

# Install Starship prompt
if ! command -v starship &>/dev/null; then
	echo "Installing Starship..."
	curl -fsSL https://starship.rs/install.sh | sh -s -- -y
fi

# Install Zap ZSH plugin manager
if [[ ! -d "${XDG_DATA_HOME:-$HOME/.local/share}/zap" ]]; then
	echo "Installing Zap ZSH plugin manager..."
	zsh <(curl -s https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh) --branch release-v1
	echo "Removing .zshrc so stow can manage it..."
	rm -f ~/.zshrc
fi

# Use GNU Stow to symlink terminal-related dotfiles
echo "Setting up dotfiles with GNU Stow (terminal-only)..."
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# If not running from the repo root (no dotfiles), optionally auto-clone when MAC_AUTOSETUP_REPO_URL is provided
if [[ ! -d "$SCRIPT_DIR/dotfiles" ]]; then
	if [[ -n "${MAC_AUTOSETUP_REPO_URL:-}" ]]; then
		tmpdir=$(mktemp -d)
		echo "Cloning repo from $MAC_AUTOSETUP_REPO_URL to $tmpdir..."
		git clone "$MAC_AUTOSETUP_REPO_URL" "$tmpdir"
		SCRIPT_DIR="$tmpdir"
	else
		echo "dotfiles directory not found. Clone the repo and run from its root, or set MAC_AUTOSETUP_REPO_URL to your repo URL for auto-clone."
		exit 1
	fi
fi

pushd "$SCRIPT_DIR" >/dev/null

# Only stow terminal-related configs
stow --target="$HOME" --dir=./dotfiles zsh vim nvim starship tmux

popd >/dev/null

# Default shell to zsh (if not already)
if [[ "$SHELL" != *"zsh"* ]]; then
	if command -v chsh &>/dev/null; then
		echo "Changing default shell to zsh (you may be prompted for password)..."
		chsh -s "$(command -v zsh)" || true
	fi
fi

echo "Done. Start a new terminal session or run: exec zsh -l"
exec zsh -l


