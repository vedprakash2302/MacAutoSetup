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

### 🐧 One-liner for remote Linux (curl only)

Run this single command on a fresh remote Linux server. It will detect your distro, install required CLI tools, install Starship and Zap, clone this repo, and stow terminal dotfiles.

```sh
INSTALL_LAZYDOCKER=0 MAC_AUTOSETUP_REPO_URL='https://github.com/NLaundry/MacAutoSetup.git' bash -c "$(curl -fsSL https://raw.githubusercontent.com/NLaundry/MacAutoSetup/main/bootstrap-linux.sh)"
```

Notes:

- You may be prompted for your password for package installs (uses sudo).
- Toggle optional pieces via env vars, e.g. `INSTALL_LAZYDOCKER=0` to skip lazydocker.
