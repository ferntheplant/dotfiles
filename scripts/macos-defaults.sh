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

# Vorssaint (com.vorssaint.utils): Cmd-Shift-4 opens Vorssaint's screenshot tool (area, with the
# capture menu) and Cmd-Shift-3 its full-screen capture, in place of the macOS screenshot keys.
# systemShortcutTakeOverKeys tells Vorssaint to turn off the matching macOS hotkeys while it runs
# and to give them back when it quits. A shortcut is "<modifiers>:<key code>", with the modifiers in
# the order control, option, shift, command (20 is the 3 key, 21 is the 4 key). Vorssaint reads
# these keys only at launch, so the script restarts it when a value changes.
vorssaint=com.vorssaint.utils
# Print the current values of the keys below, one line each
vorssaint_values() {
	local key
	for key in screenshotShortcutEnabled screenshotShortcut screenshotFullScreenShortcutEnabled \
		screenshotFullScreenShortcut systemShortcutTakeOverKeys; do
		defaults read "$vorssaint" "$key" 2>/dev/null | tr -d ' \n(),"' || true
		echo
	done
}
vorssaint_wanted=$'1\nshift+command:21\n1\nshift+command:20\nscreenshotFullScreenShortcutscreenshotShortcut'
if [[ "$(vorssaint_values)" != "$vorssaint_wanted" ]]; then
	vorssaint_running=false
	if pgrep -xq Vorssaint; then
		vorssaint_running=true
		# Quit first, so that Vorssaint does not save its old values over the new ones
		osascript -e "quit app id \"$vorssaint\""
		for _ in {1..20}; do pgrep -xq Vorssaint || break; sleep 0.25; done
	fi
	defaults write "$vorssaint" screenshotShortcutEnabled -bool true
	defaults write "$vorssaint" screenshotShortcut -string "shift+command:21"
	defaults write "$vorssaint" screenshotFullScreenShortcutEnabled -bool true
	defaults write "$vorssaint" screenshotFullScreenShortcut -string "shift+command:20"
	# Vorssaint keeps this list sorted
	defaults write "$vorssaint" systemShortcutTakeOverKeys -array screenshotFullScreenShortcut screenshotShortcut
	if [[ "$vorssaint_running" = true ]]; then
		open -b "$vorssaint"
		echo "🔁 Restarted Vorssaint to apply its screenshot shortcuts"
	fi
fi

echo "✅ Wrote macOS defaults. Log out and back in to apply the menu bar spacing and Spaces setting."
