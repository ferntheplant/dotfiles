autoload -U compinit
compinit

export EDITOR="/usr/bin/hx"
export HELIX_RUNTIME="/var/lib/helix/runtime"
export RUSTC_WRAPPER="$HOME/.cargo/bin/sccache"

path+=("/opt/homebrew/bin")
path+=("$HOME/.bun/bin")
path+=("$HOME/.local/bin")
path+=("$HOME/.spicetify")
export PATH

alias l="eza -a --long --header --tree --level=2 --icons --no-user --git --ignore-glob='.git|*node_modules*' --time-style='relative' --no-permissions --modified"
alias l1="l --level=1 --time-style='+%y-%m-%d %H:%M'"
alias g="git"
alias zell="zellij"
alias zspot="zellij action new-tab --layout ~/.config/zellij/layouts/spotify.kdl --name spotify"
alias ztab="zellij action new-tab --layout ~/.config/zellij/layouts/base.kdl --name "
alias dab="databricks"
alias dbx="databricks"

alias blog-toc="markdown-toc --append=$'\n<br></br>' -i"
alias spot="spotify_player"

alias leave-apt="apt-mark showmanual > apt-packages.txt"
alias leave-brew="brew leaves > brew-packages.txt"
alias leave-brew-casks="brew list --cask > brew-casks.txt"
alias leave-cargo="cargo install --list | parse-cargo"
alias leave-bun="cat ~/.bun/install/global/package.json | jq -r '.dependencies | keys[]' | tr -s '\n' ' ' > bun-packages.txt"
alias leave-pip="pip freeze > pip-packages.txt"
# TODO: move this to script to check for current location (~/dotfiles)
alias leave-mac="leave-brew && leave-brew-casks && leave-cargo && leave-bun && leave-pip"

sanitize_command_name() {
	local cmd="$1"
	cmd="${cmd// /_}"              # Replace spaces with underscores
	cmd="${cmd//\//-}"             # Replace slashes with dashes
	cmd="${cmd//[^a-zA-Z0-9._-]/}" # Remove any characters that aren't alphanumeric, `.` `_` or `-`
	echo "$cmd"
}

logrun() {
	local timestamp
	timestamp=$(date +"%Y-%m-%d_%H-%M-%S") # Assign separately

	local cmd_name
	cmd_name=$(sanitize_command_name "$1") # Use helper function
	local args=("${@:2}")                  # Captures all arguments as an array
	local safe_args="${args[*]// /_}"      # Replace spaces with underscores
	safe_args="${safe_args//\//-}"         # Replace slashes with dashes

	# Truncate if args are too long
	if [[ ${#safe_args} -gt 50 ]]; then
		safe_args="${safe_args:0:50}_..."
	fi

	local logdir="./logs"
	mkdir -p "$logdir" # Ensure logs directory exists

	local logfile="${logdir}/${cmd_name}_${safe_args}_${timestamp}.log"

	# Log the executed command for reference
	echo "Running: ${cmd_name} ${args[*]}" | tee "$logfile"
	echo "------------------------" >>"$logfile"
	# Run the command and redirect both stdout and stderr to the log file
	"${cmd_name}" "${args[@]}" &>>"$logfile"

	echo "Log saved to $logfile"
}

logclear() {
	local logdir="./logs"
	[[ -d "$logdir" ]] || {
		echo "Log directory does not exist: $logdir"
		return 1
	}

	local pattern=""
	local older_than=""
	local today_hour=""
	local matching_logs=()

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-d | --day)
			if [[ "$2" == "today" ]]; then
				pattern="$(date +"%Y-%m-%d")"
			else
				pattern="$2"
			fi
			shift 2
			;;
		-h | --hour)
			if [[ "$2" == "now" ]]; then
				pattern="$(date +"%Y-%m-%d_%H")"
			else
				pattern="$(date +"%Y-%m-%d")_$2"
			fi
			shift 2
			;;
		-c | --command)
			pattern="$(sanitize_command_name "$2")" # Use helper function
			shift 2
			;;
		-o | --older-than)
			if [[ "$2" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
				older_than="$2"
			else
				echo "Invalid date format. Use YYYY-MM-DD."
				return 1
			fi
			shift 2
			;;
		-t | --today-hour)
			if [[ "$2" =~ ^[0-9]{1,2}$ && "$2" -ge 0 && "$2" -le 23 ]]; then
				today_hour="$2"
			else
				echo "Invalid hour format. Use 0-23."
				return 1
			fi
			shift 2
			;;
		*)
			echo "Usage: clearlogs [-d YYYY-MM-DD | -d today] [-h HH | -h now] [-c command] [-o YYYY-MM-DD] [-t HH]"
			return 1
			;;
		esac
	done

	# Loop through files safely
	for file in "$logdir"/*; do
		[[ -f "$file" ]] || continue # Skip non-files (e.g., if no matching logs)

		if [[ -n "$older_than" ]]; then
			log_date=$(echo "$file" | grep -oE '\d{4}-\d{2}-\d{2}')
			if [[ -n "$log_date" && "$log_date" < "$older_than" ]]; then
				matching_logs+=("$file")
			fi
		elif [[ -n "$today_hour" ]]; then
			today_date="$(date +"%Y-%m-%d")"
			if [[ "$file" =~ ${today_date}_[0-9]{2} ]]; then
				log_hr="${file:${#today_date}+1:2}" # Extract HH part from filename
				if [[ "$log_hr" -le "$today_hour" ]]; then
					matching_logs+=("$file")
				fi
			fi
		elif [[ -n "$pattern" && "$file" == *"$pattern"* ]]; then
			matching_logs+=("$file")
		fi
	done

	if [[ ${#matching_logs[@]} -eq 0 ]]; then
		echo "No matching logs found."
		return 0
	fi

	echo "Deleting ${#matching_logs[@]} logs matching: $pattern $older_than $today_hour"
	rm -v -- "${matching_logs[@]}"
}

theme() {
	update-catppuccin "$HOME/.config/alacritty/alacritty.toml" --"$1"
	update-catppuccin "$HOME/.config/starship.toml" --"$1" --quotes
	update-catppuccin "$HOME/.config/zellij/config.kdl" --"$1" --quotes
	update-catppuccin "$HOME/.config/bat/config.conf" --"$1" --quotes
	update-catppuccin "$HOME/.config/helix/config.toml" --"$1" --quotes --underscore
	update-catppuccin "$HOME/.config/spotify-player/app.toml" --"$1" --quotes
	update-catppuccin "$HOME/.config/btop/btop.conf" --"$1" --quotes --underscore
	update-catppuccin "$HOME/.gitconfig" --"$1"

	# TODO: Yazi
	if [[ "$1" == "light" ]]; then
		# shellcheck disable=SC1091
		source "$HOME/.zsh/catppuccin-latte-zsh-syntax-highlighting.zsh"
		export FZF_DEFAULT_OPTS=" \
--color=bg+:#ccd0da,bg:#eff1f5,spinner:#dc8a78,hl:#d20f39 \
--color=fg:#4c4f69,header:#d20f39,info:#8839ef,pointer:#dc8a78 \
--color=marker:#7287fd,fg+:#4c4f69,prompt:#8839ef,hl+:#d20f39 \
--color=selected-bg:#bcc0cc \
--multi"
	else
		# shellcheck disable=SC1091
		source "$HOME/.zsh/catppuccin-macchiato-zsh-syntax-highlighting.zsh"
		export FZF_DEFAULT_OPTS=" \
--color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 \
--color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 \
--color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796"
	fi
}

if [ "$ALACRITTY" = "true" ] && [ "$ZELLIJ" != 0 ]; then
	ALACRITTY_THEME=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo "Light")
	if [ "$ALACRITTY_THEME" = "Dark" ]; then
		theme "dark"
	else
		theme "light"
	fi
fi

if [[ -x "$(command -v brew)" ]]; then
	# shellcheck disable=SC1091
	source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
else
	# shellcheck disable=SC1091
	source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# shellcheck disable=SC1091
source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"

eval "$(mise activate zsh)"
eval "$(mise hook-env)"
eval "$(fzf --zsh)"
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
eval "$(atuin init zsh --disable-up-arrow)"

# heroku autocomplete setup
HEROKU_AC_ZSH_SETUP_PATH=/Users/fjorn/Library/Caches/heroku/autocomplete/zsh_setup && test -f $HEROKU_AC_ZSH_SETUP_PATH && source $HEROKU_AC_ZSH_SETUP_PATH
