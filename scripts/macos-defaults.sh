#!/bin/bash
set -euo pipefail

# Write the macOS and app preferences that `defaults` can set. Safe to run again.
# install.sh runs this on the desktop profile.

# Menu bar: tighter spacing between status items (replaces the Menu Bar Spacing app).
# macOS reads these at login, so log out and back in to see a change.
defaults write -globalDomain NSStatusItemSpacing -int 4
defaults write -globalDomain NSStatusItemSelectionPadding -int 2

# Mission Control: "Displays have separate Spaces" on. Paneru does not start without it.
# macOS reads this at login.
defaults write com.apple.spaces spans-displays -bool false

# Hidden Bar (com.dwarvesv.minimalbar)
hiddenbar=com.dwarvesv.minimalbar
defaults write "$hiddenbar" alwaysHiddenSectionEnabled -bool false
defaults write "$hiddenbar" areSeparatorsHidden -bool true
defaults write "$hiddenbar" isAutoHide -bool false
defaults write "$hiddenbar" isAutoStart -bool true
defaults write "$hiddenbar" numberOfSecondForAutoHide -int 5
defaults write "$hiddenbar" useFullStatusBarOnExpandEnabled -bool true

# Sill (me.saffer.sill.mac). Sill reads these at launch, so quit and open Sill to apply a change.
# Only the settings that differ from Sill's defaults are here. Sill keeps Launch at Login in
# SMAppService, and the paired devices and Require pairing in the keychain, not in defaults.
# The keys are in Sources/SillMenuBar/HostSettings.swift in the Sill repo.
sill=me.saffer.sill.mac
# Remote Access: paired devices connect through Tailscale on TCP port 7455
defaults write "$sill" remoteAccess -bool true

echo "✅ Wrote macOS defaults. Log out and back in to apply the menu bar spacing and Spaces setting."
