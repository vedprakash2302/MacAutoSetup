# 🛠️ Dotfiles

## ⚙️ Prepare First (From the old Mac)

### 🔄 Backup you current configured default keyboard shortcuts

```sh
defaults export com.apple.symbolichotkeys - > ./dotfiles/macos/keyboard-shortcuts.xml
```

### 🔗 Sync Cursor/VS Code extensiosns:

You will first need to extract the list of extensions you have using the following command:

```sh
cursor --list-extensions > ./dotfiles/cursor/sync-extensions.txt
```

Then `git commit` and `git push` the changes

## 🔧 Installation

### 🌀 If you only have curl (fresh macOS install)

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/vedprakash2302/MacAutoSetup/main/bootstrap-nogit.sh)
```

### ✅ If you have Git

```sh
git clone https://github.com/NLaundry/MacAutoSetup.git ~/Projects/MacAutoSetup
cd ~/Projects/MacAutoSetup
./bootstrap.sh
```

### 🐧 Linux Server Setup

#### 🏢 Company Server (Minimal Installation)

For company servers where you want only essential terminal tools:

```sh
COMPANY=1 bash <(curl -fsSL https://raw.githubusercontent.com/vedprakash2302/MacAutoSetup/main/bootstrap-linux-nogit.sh)
```

**Company Mode Installs:**

- 🔧 Build essentials (gcc, make, etc.)
- 🐚 Zsh shell + Zap plugin manager
- 🔍 Essential CLI tools: `fzf`, `fd`, `ripgrep`, `bat`, `jq`, `wget`, `tmux`, `stow`, `neovim`
- 🚀 Modern tools: `starship` prompt, `zoxide`, `btop`
- 📁 Terminal dotfiles (zsh, vim, nvim, tmux, starship)
- ✅ **Skips:** Python/Node installation, GitHub CLI, lazygit, lazydocker, delta

#### 🌍 Personal Server (Full Installation)

For personal servers where you want all development tools:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/vedprakash2302/MacAutoSetup/main/bootstrap-linux-nogit.sh)
```

**Full Mode Includes Everything Above Plus:**

- 🐍 Python 3 + pip + pipx
- 🟢 Node.js + npm + nvm
- 🛠️ Development tools: `gh` (GitHub CLI), `delta`, `lazygit`, `lazydocker`

---

**Supported Distributions:**

- Ubuntu/Debian (apt)
- Fedora (dnf)
- RHEL/CentOS (dnf/yum + EPEL)
- Amazon Linux (yum/dnf + extras)
- Arch Linux/Manjaro (pacman)

**Common Features (Both Modes):**

- 🔍 Auto-detects your Linux distribution and package manager
- 🐚 Sets zsh as your default shell
- 📁 Uses GNU Stow to manage dotfiles
- 🔐 Prompts for password for package installations (uses sudo)
- ⚡ Fast, reliable installation with error handling
