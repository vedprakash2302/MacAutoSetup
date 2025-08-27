#!/usr/bin/env bash

set -e

REPO_URL="https://github.com/vedprakash2302/MacAutoSetup.git"
CLONE_DIR="$HOME/projects/MacAutoSetup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if [ -n "${COMPANY:-}" ]; then
    log "⏳ Bootstrapping Linux Terminal Setup (Company Mode)..."
    log "🏢 Minimal installation mode detected"
else
    log "⏳ Bootstrapping Linux Terminal Setup (Full Mode)..."
fi

# Detect if we're on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    error "This script is designed for Linux systems only."
    error "Detected OS type: $OSTYPE"
    exit 1
fi

# Function to detect and install git based on distro
install_git() {
    if command -v git &> /dev/null; then
        log "Git is already installed"
        return 0
    fi

    log "Installing Git..."
    
    # Detect distro and install git
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            ubuntu|debian)
                sudo apt update
                sudo apt install -y git
                ;;
            fedora)
                sudo dnf install -y git
                ;;
            rhel|centos)
                if command -v dnf &> /dev/null; then
                    sudo dnf install -y git
                else
                    sudo yum install -y git
                fi
                ;;
            arch|manjaro)
                sudo pacman -S --noconfirm git
                ;;
            *)
                error "Unsupported distribution: $ID"
                error "Please install Git manually and run this script again."
                exit 1
                ;;
        esac
    else
        error "Cannot detect Linux distribution"
        error "Please install Git manually and run this script again."
        exit 1
    fi

    # Verify git installation
    if ! command -v git &> /dev/null; then
        error "Failed to install Git"
        exit 1
    fi
    
    log "✅ Git installed successfully"
}

# Install curl if not present (needed for cloning and other operations)
install_curl() {
    if command -v curl &> /dev/null; then
        return 0
    fi

    log "Installing curl..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            ubuntu|debian)
                sudo apt update
                sudo apt install -y curl
                ;;
            fedora)
                sudo dnf install -y curl
                ;;
            rhel|centos)
                if command -v dnf &> /dev/null; then
                    sudo dnf install -y curl
                else
                    sudo yum install -y curl
                fi
                ;;
            arch|manjaro)
                sudo pacman -S --noconfirm curl
                ;;
        esac
    fi
}

# Install essential tools
install_curl
install_git

# Clone the repo if it hasn't been cloned yet
if [ ! -d "$CLONE_DIR" ]; then
    log "📥 Cloning MacAutoSetup into $CLONE_DIR..."
    mkdir -p "$(dirname "$CLONE_DIR")"
    git clone "$REPO_URL" "$CLONE_DIR"
else
    log "📁 Directory $CLONE_DIR already exists."
    log "🔄 Pulling latest changes..."
    cd "$CLONE_DIR"
    git pull origin main || log "⚠️  Could not pull latest changes, continuing with existing version..."
fi

# Make sure we're in the cloned directory
cd "$CLONE_DIR"

# Check if the Linux bootstrap script exists
if [ ! -f "./bootstrap-linux.sh" ]; then
    error "bootstrap-linux.sh not found in $CLONE_DIR"
    error "This might be an older version of the repository."
    exit 1
fi

# Make the script executable
chmod +x ./bootstrap-linux.sh

# Run main Linux bootstrap script
if [ -n "${COMPANY:-}" ]; then
    log "🚀 Running minimal Linux terminal setup..."
    export COMPANY="$COMPANY"
else
    log "🚀 Running full Linux terminal setup..."
fi
exec ./bootstrap-linux.sh
