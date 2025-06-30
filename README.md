# 🛠️ MacAutoSetup

A lean, modern development environment for macOS that brings the Linux tiling window manager experience to Mac — with minimal fuss.

## ✨ Core Features

- 🧠 Raycast — fast launcher & automation
- 🪟 Aerospace — tiling window management (like i3, for Mac)
- 🖋️ GNU Stow — simple, modular dotfile management
- 🧑‍💻 Astronvim — full-featured, sane Neovim IDE config
- 🧘 Minimal Vim config — if you want to keep it light
- 🧰 Essential GNU utilities — sed, coreutils, gawk, etc.
- 🚀 Zsh with Zap — plugin manager for a clean, fast shell


## 🎯 Philosophy

- Terminal-first, keyboard-driven workflow
- Get up and running fast
- Modular, understandable configuration — no hidden magic
- LOW configuration (I use tmux a lot but 0 config for it) for improved portability
- Dotfile hygiene - I yoinked the .zsh.d idea from a youtube video that I have 
forgotten but would LOVE to credit. If someone knows the video on "the dot problem" 
or something like that, please point that out to me and let me know!


### You may be asking, why astronvim? Aren't you a vim nerd who handles his own config

Okay ... so, here's my thinking about astronvim.

I have run my own vim configs for almost 10 years now. I love it. It's fun. It breaks a lot!

I've come to some conclusions about **CONFIGURATION**:
1. The less you configure things, the more portable your knowledge of the thing is.
2. The less you configure things, the more you learn THE TOOL ITSELF, instead of YOUR CONFIGURATION of that tool
3. Leverage Defaults and Leverage Community

So I prefer to use defaults as much as possible OR leverage things maintained by a community.

Astronvim is the latter. I keep 0 plugin, minimal configuration Vim too for lightweight editing.
- together, these require next to no configuration on my part and give me 99% of the workflow I was used to with a home-grown config

It feels, to me, as if the neovim community has converged on a mostly consistent set of tools and hotkeys 
for the general flow of neovim as pseudo-IDE. I ran the Primeagen's Neovim setup tutorial + my own tweaks 
for a few years, and it was great but eventually things broke. I just got tired of fixing my editor instead of 
editing.

Given, that I feel neovim as a pseudo-IDE has mostly converged ... most "neovim distributions" feel pretty close 
to what I'd expect and what I was already using with my home-grown config.

So Astronvim gives me what I expect and mostly already had, while off-loading maintenance to a community.

I would, however, HIGHLY RECOMMEND, if you don't know Vim or, have never managed your own config, to run vanilla vim 
as well as try managing your own config for a bit. You will learn things. Also read practical vim.


## 🔧 Installation

### ✅ If you have Git

```sh
git clone https://github.com/NLaundry/MacAutoSetup.git ~/Projects/MacAutoSetup
cd ~/Projects/MacAutoSetup
./bootstrap.sh
```

### 🌀 If you only have curl (fresh macOS install)

```bash <(curl -fsSL https://raw.githubusercontent.com/NLaundry/MacAutoSetup/main/bootstrap-nogit.sh)```

This will:
1. Install Xcode CLI tools (for Git)
2. Install Homebrew
3. Clone this repo
4. Run the full setup


## 📦 What Gets Installed

The Brewfile covers all the essentials:

### 🧰 CLI Tools

git, fzf, ripgrep, bat, htop, lazygit, lazysql, awscli, jq, gh, tmux, stow, neovim, kubectl, tailscale, coreutils, gnu-sed, findutils, gawk

### 💻 GUI Apps

raycast, aerospace, ghostty, iterm2, visual-studio-code, docker, caffeine

### 🖥️ Fonts

JetBrains Mono Nerd Font (for beautiful glyphs and coding ligatures)

### 🧪 Dev Environment

python, pipx, node, nvm


## 📁 Dotfiles & Config

Dotfiles are managed using GNU Stow.

Directory structure:

```
dotfiles/
├── zsh/
├── nvim/        # Minimal Neovim config
├── vim/         # Classic Vim config (optional)
├── aerospace/   # Tiling window manager config
├── iterm2/
├── ghostty/
└── …
```

Each folder maps to $HOME. For example:

```
stow –target=$HOME zsh nvim ghostty
```

creates symlinks for config files in your home directory.

## ✅ Result

- Feels like Arch or Debian with i3, but polished for Mac
- Astronvim or minimal Vim: pick your workflow
- Tiling window control and keybindings
- Clean terminal with Nerd Font and modern CLI tools
- Shell and dev tools ready for Python, Node, AWS, and Kubernetes
