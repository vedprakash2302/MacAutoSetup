#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect Linux distribution and package manager
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        DISTRO="rhel"
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
    elif [ -f /etc/arch-release ]; then
        DISTRO="arch"
    else
        error "Unable to detect Linux distribution"
        exit 1
    fi

    log "Detected distribution: $DISTRO"
}

# Set package manager based on distro
set_package_manager() {
    case $DISTRO in
        ubuntu|debian)
            PKG_MANAGER="apt"
            PKG_UPDATE="apt update"
            PKG_INSTALL="apt install -y"
            EPEL_NEEDED=false
            ;;
        fedora)
            PKG_MANAGER="dnf"
            PKG_UPDATE="dnf check-update || true"
            PKG_INSTALL="dnf install -y"
            EPEL_NEEDED=false
            ;;
        rhel|centos|amzn)
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
                PKG_UPDATE="dnf check-update || true"
                PKG_INSTALL="dnf install -y"
            else
                PKG_MANAGER="yum"
                PKG_UPDATE="yum check-update || true"
                PKG_INSTALL="yum install -y"
            fi
            # Amazon Linux has EPEL, RHEL/CentOS need it
            if [ "$DISTRO" = "amzn" ]; then
                EPEL_NEEDED=false  # Amazon Linux has extras repo instead
            else
                EPEL_NEEDED=true   # RHEL/CentOS need EPEL
            fi
            ;;
        arch|manjaro)
            PKG_MANAGER="pacman"
            PKG_UPDATE="pacman -Sy"
            PKG_INSTALL="pacman -S --noconfirm"
            EPEL_NEEDED=false
            ;;
        *)
            error "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac

    log "Using package manager: $PKG_MANAGER"
}

# Install EPEL repository for RHEL/CentOS, enable extras for Amazon Linux
install_epel() {
    if [ "$EPEL_NEEDED" = true ]; then
        log "Installing EPEL repository..."
        if [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ]; then
            if [ "$PKG_MANAGER" = "dnf" ]; then
                sudo dnf install -y epel-release
            else
                sudo yum install -y epel-release
            fi
        fi
    elif [ "$DISTRO" = "amzn" ]; then
        log "Enabling Amazon Linux Extras and EPEL..."
        # Amazon Linux 2 has amazon-linux-extras
        if command -v amazon-linux-extras &> /dev/null; then
            # Enable common extras that might be needed
            sudo amazon-linux-extras install -y epel || log "EPEL already available or not needed"
        else
            # Amazon Linux 2023 - install EPEL manually
            log "Installing EPEL for Amazon Linux 2023..."
            sudo dnf install -y epel-release || {
                log "Installing EPEL from fedora project..."
                sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm || {
                    warn "Could not install EPEL, some packages may not be available"
                }
            }
        fi
    fi
}

# Update package manager
update_packages() {
    log "Updating package manager..."
    sudo $PKG_UPDATE
}

# Install Git if not present
install_git() {
    if ! command -v git &> /dev/null; then
        log "Installing Git..."
        sudo $PKG_INSTALL git
    else
        log "Git is already installed"
    fi
}

# Install essential build tools
install_build_essentials() {
    log "Installing build essentials..."
    case $PKG_MANAGER in
        apt)
            sudo $PKG_INSTALL build-essential curl wget ca-certificates gnupg lsb-release
            ;;
        dnf)
            if [ "$DISTRO" = "amzn" ]; then
                # Amazon Linux 2023 with dnf - install individual packages
                log "Installing individual development packages for Amazon Linux..."
                sudo $PKG_INSTALL gcc gcc-c++ make automake autoconf libtool curl wget ca-certificates gnupg2 util-linux shadow-utils || {
                    warn "Some build tools may not be available, continuing..."
                }
            else
                # Standard Fedora/RHEL with dnf
                sudo $PKG_INSTALL @development-tools curl wget ca-certificates gnupg2
            fi
            ;;
        yum)
            if [ "$DISTRO" = "amzn" ]; then
                # Amazon Linux 2 with yum
                log "Installing individual development packages for Amazon Linux..."
                sudo $PKG_INSTALL gcc gcc-c++ make automake autoconf libtool curl wget ca-certificates util-linux shadow-utils || {
                    warn "Some build tools may not be available, continuing..."
                }
            else
                # Standard RHEL/CentOS with yum
                sudo yum groupinstall -y "Development Tools" || {
                    warn "Development Tools group not available, installing individual packages..."
                    sudo $PKG_INSTALL gcc gcc-c++ make automake autoconf libtool
                }
                sudo $PKG_INSTALL curl wget ca-certificates
            fi
            ;;
        pacman)
            sudo $PKG_INSTALL base-devel curl wget ca-certificates gnupg
            ;;
    esac
}

# Install Zsh
install_zsh() {
    if ! command -v zsh &> /dev/null; then
        log "Installing Zsh..."
        sudo $PKG_INSTALL zsh
    else
        log "Zsh is already installed"
    fi
}

# Install core CLI tools
install_cli_tools() {
    log "Installing CLI tools..."
    
    # Common tools available in most repos
    COMMON_TOOLS=""
    case $PKG_MANAGER in
        apt)
            COMMON_TOOLS="fzf fd-find ripgrep bat jq wget tmux stow neovim python3 python3-pip nodejs npm"
            ;;
        dnf|yum)
            # Amazon Linux might have different package names
            if [ "$DISTRO" = "amzn" ]; then
                # Only install tools that are actually available in Amazon Linux repos
                COMMON_TOOLS="jq wget tmux python3 python3-pip nodejs npm"
                log "Note: Modern CLI tools (fzf, ripgrep, bat, stow, neovim) will be installed via alternative methods"
            else
                COMMON_TOOLS="fzf fd-find ripgrep bat jq wget tmux stow neovim python3 python3-pip nodejs npm"
            fi
            ;;
        pacman)
            COMMON_TOOLS="fzf fd ripgrep bat jq wget tmux stow neovim python python-pip nodejs npm"
            ;;
    esac
    
    if [ -n "$COMMON_TOOLS" ]; then
        log "Installing common CLI tools: $COMMON_TOOLS"
        sudo $PKG_INSTALL $COMMON_TOOLS || {
            warn "Some CLI tools may not be available in repositories, continuing..."
            # Try installing tools individually
            for tool in $COMMON_TOOLS; do
                sudo $PKG_INSTALL "$tool" || warn "Failed to install $tool, skipping..."
            done
        }
    fi
    
    # Install tools that might have different names or need special handling
    install_special_tools
}

# Install tools that need special handling per distro
install_special_tools() {
    # Install GitHub CLI
    install_github_cli
    
    # Install delta (git diff tool)
    install_delta
    
    # Install starship
    install_starship
    
    # Install zoxide
    install_zoxide
    
    # Install btop (may not be available in all repos)
    install_btop
    
    # Install modern tools via alternative methods if not in repos
    install_modern_tools
    
    # Install missing tools for Amazon Linux  
    install_amazon_linux_fallbacks
}

# Install GitHub CLI
install_github_cli() {
    if ! command -v gh &> /dev/null; then
        log "Installing GitHub CLI..."
        case $PKG_MANAGER in
            apt)
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                sudo apt update
                sudo apt install -y gh
                ;;
            dnf)
                sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
                sudo dnf install -y gh
                ;;
            yum)
                # Handle Amazon Linux differently
                if [ "$DISTRO" = "amzn" ]; then
                    # Amazon Linux 2 might not have yum-config-manager
                    if command -v yum-config-manager &> /dev/null; then
                        sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
                        sudo yum install -y gh
                    else
                        warn "GitHub CLI repository setup not available on this Amazon Linux version"
                        install_from_github_releases "cli/cli" "gh"
                    fi
                else
                    sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
                    sudo yum install -y gh
                fi
                ;;
            pacman)
                sudo pacman -S --noconfirm github-cli
                ;;
        esac
    fi
}

# Install delta
install_delta() {
    if ! command -v delta &> /dev/null; then
        log "Installing delta..."
        case $PKG_MANAGER in
            apt)
                # Check if available in repo, otherwise install from releases
                if apt-cache search git-delta | grep -q git-delta; then
                    sudo apt install -y git-delta
                else
                    install_from_github_releases "dandavison/delta" "git-delta"
                fi
                ;;
            dnf|yum)
                sudo $PKG_INSTALL git-delta || install_from_github_releases "dandavison/delta" "git-delta"
                ;;
            pacman)
                sudo pacman -S --noconfirm git-delta
                ;;
        esac
    fi
}

# Install starship prompt
install_starship() {
    if ! command -v starship &> /dev/null; then
        log "Installing Starship prompt..."
        # Use sudo sh to avoid password prompt
        curl -sS https://starship.rs/install.sh | sudo sh -s -- -y || {
            warn "Failed to install Starship prompt, skipping..."
        }
    else
        log "Starship is already installed"
    fi
}

# Install zoxide
install_zoxide() {
    if ! command -v zoxide &> /dev/null; then
        log "Installing zoxide..."
        case $PKG_MANAGER in
            apt)
                if apt-cache search zoxide | grep -q zoxide; then
                    sudo apt install -y zoxide
                else
                    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash || {
                        warn "Failed to install zoxide, skipping..."
                    }
                fi
                ;;
            dnf|yum)
                sudo $PKG_INSTALL zoxide || {
                    log "zoxide not in repository, installing from script..."
                    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash || {
                        warn "Failed to install zoxide, skipping..."
                    }
                }
                ;;
            pacman)
                sudo pacman -S --noconfirm zoxide
                ;;
        esac
    else
        log "zoxide is already installed"
    fi
}

# Install btop
install_btop() {
    if ! command -v btop &> /dev/null; then
        log "Installing btop..."
        case $PKG_MANAGER in
            apt)
                if apt-cache search btop | grep -q btop; then
                    sudo apt install -y btop
                else
                    warn "btop not available in repository, skipping..."
                fi
                ;;
            dnf|yum)
                if [ "$DISTRO" = "amzn" ]; then
                    warn "btop may not be available in Amazon Linux repositories, skipping..."
                else
                    sudo $PKG_INSTALL btop || warn "btop not available in repository, skipping..."
                fi
                ;;
            pacman)
                sudo pacman -S --noconfirm btop
                ;;
        esac
    else
        log "btop is already installed"
    fi
}

# Install modern tools via alternative methods
install_modern_tools() {
    # Install lazygit
    if ! command -v lazygit &> /dev/null; then
        log "Installing lazygit..."
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar xf lazygit.tar.gz lazygit
        sudo install lazygit /usr/local/bin
        rm lazygit lazygit.tar.gz
    fi
    
    # Install lazydocker if Docker is available
    if command -v docker &> /dev/null && ! command -v lazydocker &> /dev/null; then
        log "Installing lazydocker..."
        curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
    fi
}

# Install missing tools for Amazon Linux using alternative methods
install_amazon_linux_fallbacks() {
    if [ "$DISTRO" != "amzn" ]; then
        return 0  # Only run for Amazon Linux
    fi
    
    log "Installing missing tools for Amazon Linux using alternative methods..."
    
    # Install fzf
    if ! command -v fzf &> /dev/null; then
        log "Installing fzf from GitHub..."
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --all --no-update-rc || {
            warn "Failed to install fzf, skipping..."
        }
    fi
    
    # Install ripgrep  
    if ! command -v rg &> /dev/null; then
        log "Installing ripgrep from GitHub releases..."
        RIPGREP_VERSION=$(curl -s "https://api.github.com/repos/BurntSushi/ripgrep/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
        curl -Lo ripgrep.tar.gz "https://github.com/BurntSushi/ripgrep/releases/latest/download/ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl.tar.gz"
        tar xf ripgrep.tar.gz --strip-components=1 "ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl/rg"
        sudo install rg /usr/local/bin/
        rm -f rg ripgrep.tar.gz || warn "Failed to install ripgrep, skipping..."
    fi
    
    # Install bat
    if ! command -v bat &> /dev/null; then
        log "Installing bat from GitHub releases..."
        BAT_VERSION=$(curl -s "https://api.github.com/repos/sharkdp/bat/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -Lo bat.tar.gz "https://github.com/sharkdp/bat/releases/latest/download/bat-v${BAT_VERSION}-x86_64-unknown-linux-musl.tar.gz"
        tar xf bat.tar.gz --strip-components=1 "bat-v${BAT_VERSION}-x86_64-unknown-linux-musl/bat"
        sudo install bat /usr/local/bin/
        rm -f bat bat.tar.gz || warn "Failed to install bat, skipping..."
    fi
    
    # Install fd (find alternative)
    if ! command -v fd &> /dev/null; then
        log "Installing fd from GitHub releases..."
        FD_VERSION=$(curl -s "https://api.github.com/repos/sharkdp/fd/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -Lo fd.tar.gz "https://github.com/sharkdp/fd/releases/latest/download/fd-v${FD_VERSION}-x86_64-unknown-linux-musl.tar.gz"
        tar xf fd.tar.gz --strip-components=1 "fd-v${FD_VERSION}-x86_64-unknown-linux-musl/fd"
        sudo install fd /usr/local/bin/
        rm -f fd fd.tar.gz || warn "Failed to install fd, skipping..."
    fi
    
    # Install stow (try EPEL first, then from source)
    if ! command -v stow &> /dev/null; then
        log "Installing stow..."
        sudo $PKG_INSTALL stow || {
            log "stow not in repositories, installing from source..."
            # Install perl which is required for stow
            sudo $PKG_INSTALL perl || warn "Could not install perl, stow installation may fail"
            
            cd /tmp
            wget https://ftp.gnu.org/gnu/stow/stow-2.3.1.tar.gz || {
                warn "Failed to download stow source, skipping..."
                return
            }
            tar xf stow-2.3.1.tar.gz
            cd stow-2.3.1
            chmod +x configure
            ./configure --prefix=/usr/local && make && sudo make install && {
                log "Successfully installed stow from source"
            }
            cd /tmp && rm -rf stow-2.3.1*
        } || warn "Failed to install stow, skipping..."
    fi
    
    # Install neovim 
    if ! command -v nvim &> /dev/null; then
        log "Installing neovim AppImage..."
        curl -Lo /tmp/nvim.appimage "https://github.com/neovim/neovim/releases/latest/download/nvim.appimage"
        chmod +x /tmp/nvim.appimage
        sudo mv /tmp/nvim.appimage /usr/local/bin/nvim || warn "Failed to install neovim, skipping..."
    fi
}

# Generic function to install tools from GitHub releases
install_from_github_releases() {
    local repo=$1
    local binary_name=$2
    
    log "Installing $binary_name from GitHub releases..."
    local latest_url=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep "browser_download_url.*linux.*x86_64" | cut -d '"' -f 4 | head -n 1)
    
    if [ -n "$latest_url" ]; then
        wget -O /tmp/${binary_name}.tar.gz "$latest_url"
        cd /tmp
        tar -xzf ${binary_name}.tar.gz
        sudo mv ${binary_name}* /usr/local/bin/${binary_name} 2>/dev/null || sudo cp ${binary_name} /usr/local/bin/
        sudo chmod +x /usr/local/bin/${binary_name}
        rm -rf /tmp/${binary_name}*
    else
        warn "Could not find download URL for $binary_name"
    fi
}

# Install Python tools
install_python_tools() {
    log "Installing Python tools..."
    
    # Install pipx
    if ! command -v pipx &> /dev/null; then
        python3 -m pip install --user pipx
        python3 -m pipx ensurepath
        export PATH="$PATH:$HOME/.local/bin"
    fi
}

# Install Node.js tools
install_node_tools() {
    log "Installing Node.js tools..."
    
    # Install nvm
    if [ ! -d "$HOME/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    fi
}

# Install Zap ZSH plugin manager
install_zap_zsh() {
    if [[ ! -d "${XDG_DATA_HOME:-$HOME/.local/share}/zap" ]]; then
        log "Installing Zap ZSH plugin manager..."
        zsh <(curl -s https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh) --branch release-v1
        log "Removing .zshrc so stow can manage it..."
        rm -f ~/.zshrc
    else
        log "Zap ZSH plugin manager is already installed"
    fi
}

# Use GNU Stow to symlink dotfiles (Linux-appropriate ones only)
setup_dotfiles() {
    log "Setting up dotfiles with GNU Stow..."
    
    # Check if we have stow installed
    if ! command -v stow &> /dev/null; then
        warn "GNU Stow is not installed, cannot set up dotfiles"
        log "Install stow manually and run: stow --target=\$HOME --dir=./dotfiles zsh vim nvim starship tmux"
        return 1
    fi
    
    # Debug: show current directory and dotfiles structure
    log "Current directory: $(pwd)"
    log "Available dotfiles directories:"
    ls -la ./dotfiles/ 2>/dev/null || {
        warn "dotfiles directory not found in current location"
        return 1
    }
    
    # Only stow Linux-compatible dotfiles
    local dotfiles="zsh vim nvim starship tmux"
    
    for dotfile in $dotfiles; do
        if [ -d "./dotfiles/$dotfile" ]; then
            log "Stowing $dotfile..."
            log "Contents of ./dotfiles/$dotfile:"
            find "./dotfiles/$dotfile" -type f -name ".*" -o -type f -name "*" 2>/dev/null || log "No files found"
            stow --target="$HOME" --dir=./dotfiles "$dotfile" || {
                warn "Failed to stow $dotfile"
            }
        else
            warn "Dotfile directory ./dotfiles/$dotfile not found, skipping..."
            log "Checking if directory exists with different case or location..."
            find ./dotfiles -type d -iname "$dotfile" 2>/dev/null || log "No matching directory found"
        fi
    done
}

# Change default shell to zsh
change_shell_to_zsh() {
    if [ "$SHELL" != "$(which zsh)" ]; then
        log "Changing default shell to zsh..."
        if command -v chsh &> /dev/null; then
            chsh -s "$(which zsh)"
            log "Shell changed to zsh. You may need to log out and log back in for this to take effect."
        else
            # Fallback for systems without chsh (like some Amazon Linux instances)
            log "chsh not available, adding shell change instructions..."
            cat << 'EOF' > ~/.change_shell_to_zsh.sh
#!/bin/bash
# Run this script to change your shell to zsh
sudo usermod -s $(which zsh) $USER
echo "Shell changed to zsh. Please log out and log back in for this to take effect."
EOF
            chmod +x ~/.change_shell_to_zsh.sh
            log "Created ~/.change_shell_to_zsh.sh - run it to change your shell to zsh"
            log "Or run: sudo usermod -s \$(which zsh) \$USER"
        fi
    else
        log "Default shell is already zsh"
    fi
}

# Check if we're in company mode (minimal installation)
is_company_mode() {
    [ -n "${COMPANY:-}" ]
}

# Install minimal CLI tools for company servers
install_minimal_cli_tools() {
    log "Installing minimal CLI tools for company server..."
    
    # Essential tools only
    MINIMAL_TOOLS=""
    case $PKG_MANAGER in
        apt)
            MINIMAL_TOOLS="fzf fd-find ripgrep bat jq wget tmux stow neovim"
            ;;
        dnf|yum)
            # Amazon Linux might have different package names  
            if [ "$DISTRO" = "amzn" ]; then
                # Only install tools that are actually available in Amazon Linux repos
                MINIMAL_TOOLS="jq wget tmux"
                log "Note: Modern CLI tools (fzf, ripgrep, bat, stow, neovim) will be installed via alternative methods"
            else
                MINIMAL_TOOLS="fzf fd-find ripgrep bat jq wget tmux stow neovim"
            fi
            ;;
        pacman)
            MINIMAL_TOOLS="fzf fd ripgrep bat jq wget tmux stow neovim"
            ;;
    esac
    
    if [ -n "$MINIMAL_TOOLS" ]; then
        log "Installing minimal CLI tools: $MINIMAL_TOOLS"
        sudo $PKG_INSTALL $MINIMAL_TOOLS || {
            warn "Some minimal tools may not be available in repositories, continuing..."
            # Try installing tools individually
            for tool in $MINIMAL_TOOLS; do
                sudo $PKG_INSTALL "$tool" || warn "Failed to install $tool, skipping..."
            done
        }
    fi
    
    # Install essential tools that need special handling
    install_starship
    install_zoxide  
    install_btop
    
    # Install missing tools for Amazon Linux
    install_amazon_linux_fallbacks
}

# Main installation function
main() {
    if is_company_mode; then
        log "🏢 Starting minimal Linux terminal setup for company server..."
        log "📦 Installing essential tools only (COMPANY mode detected)"
    else
        log "🚀 Starting full Linux terminal setup..."
    fi
    
    # Detect system
    detect_distro
    set_package_manager
    
    # Install EPEL if needed
    install_epel
    
    # Update packages
    update_packages
    
    # Install core tools
    install_git
    install_build_essentials
    install_zsh
    
    # Install CLI tools based on mode
    if is_company_mode; then
        # Company mode: minimal tools only
        install_minimal_cli_tools
    else
        # Full mode: everything
        install_cli_tools
        install_python_tools
        install_node_tools
    fi
    
    # Install Zap ZSH plugin manager (both modes)
    install_zap_zsh
    
    # Setup dotfiles (both modes)
    setup_dotfiles
    
    # Change shell to zsh (both modes)
    change_shell_to_zsh
    
    if is_company_mode; then
        log "✅ Minimal Linux terminal setup complete!"
        log "🏢 Company mode: Skipped Python/Node/development tools"
        log "🔧 Using existing Python/Node versions on this server"
    else
        log "✅ Full Linux terminal setup complete!"
    fi
    
    log "🔄 Restart your shell or log out and log back in to complete the setup."
    log "🚀 Run 'exec zsh -l' to start using your new shell configuration."
}

# Run main function
main "$@"
