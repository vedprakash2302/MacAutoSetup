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
bash <(curl -fsSL https://raw.githubusercontent.com/NLaundry/MacAutoSetup/main/bootstrap-nogit.sh)
```

### ✅ If you have Git

```sh
git clone https://github.com/NLaundry/MacAutoSetup.git ~/Projects/MacAutoSetup
cd ~/Projects/MacAutoSetup
./bootstrap.sh
```
