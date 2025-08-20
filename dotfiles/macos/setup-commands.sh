#################### Keyboard related settings ####################
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
# Fn key usage
defaults write com.apple.HIToolbox AppleFnUsageType -int "1"
# F1, F2, etc. as function keys
# defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true
# Keyboard navigation
defaults write NSGlobalDomain AppleKeyboardUIMode -int 2

# Import keyboard shortcuts
defaults import com.apple.symbolichotkeys ./dotfiles/macos/keyboard-shortcuts.xml
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

#################### Trackpad related settings ####################
defaults write -globalDomain "com.apple.mouse.scaling" -int 2
defaults write -globalDomain "com.apple.trackpad.scaling" -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad "Clicking" -bool true
defaults write com.apple.AppleMultitouchTrackpad "Clicking" -bool true
defaults -currentHost write -globalDomain "com.apple.mouse.tapBehavior" -int 1
defaults write "com.apple.driver.AppleBluetoothMultitouch.mouse" MouseButtonMode TwoButton
defaults write "com.apple.AppleMultitouchMouse.plist" MouseButtonMode TwoButton
defaults write -g AppleShowScrollBars -string "WhenScrolling"
# three finger drag
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
# Mouse speed
defaults write -g com.apple.mouse.scaling 3
defaults write -g com.apple.trackpad.scaling 3

#################### Finder related settings ####################
defaults write com.apple.Finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.Finder "FXPreferredViewStyle" clmv
chflags nohidden ~/Library
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"
# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true
# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true
# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true
# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.desktopservices DSDontWriteNetworkStores true



#################### Dock related settings ####################
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock "show-recents" -bool false
# Change minimize/maximize window effect
defaults write com.apple.dock mineffect -string "scale"
# Minimize windows into their application’s icon
defaults write com.apple.dock minimize-to-application -bool true
# Show indicator lights for open applications in the Dock
defaults write com.apple.dock show-process-indicators -bool true
# Wipe all (default) app icons from the Dock
defaults write com.apple.dock persistent-apps -array
# Show only open applications in the Dock
defaults write com.apple.dock static-only -bool true
# Speed up Mission Control animations
defaults write com.apple.dock expose-animation-duration -float 0.1
# Automatically hide and show the Dock
defaults write com.apple.dock autohide -bool true
# Remove the auto-hiding Dock delay
defaults write com.apple.dock autohide-delay -float 0
# Remove the animation when hiding/showing the Dock
defaults write com.apple.dock autohide-time-modifier -float 1
# Make Dock icons of hidden applications translucent
defaults write com.apple.dock showhidden -bool true
# Don’t show recent applications in Dock
defaults write com.apple.dock show-recents -bool false
# Dock size
defaults write com.apple.dock tilesize -int 48
# Spring loading
defaults write com.apple.dock "enable-spring-load-actions-on-all-items" -bool "true"



#################### Desktop related settings ####################
defaults write com.apple.finder "_FXSortFoldersFirstOnDesktop" -bool "true" 
defaults write com.apple.finder "ShowExternalHardDrivesOnDesktop" -bool "false" 
defaults write com.apple.finder "ShowRemovableMediaOnDesktop" -bool "false" 



#################### Other settings ####################
defaults write com.apple.dock "expose-group-apps" -bool "true"




#################### Application related settings ####################

# # Set up my preferred keyboard shortcuts
# cp -r init/spectacle.json ~/Library/Application\ Support/Spectacle/Shortcuts.json 2> /dev/null


# Restart all affected applications
killall Dock
killall Finder
killall SystemUIServer
