#!/bin/bash

# New Machine Setup Script
# This script sets up a fresh machine with all dotfiles and packages

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if we're on macOS
is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# Function to install Homebrew if not present
install_homebrew() {
    if ! command_exists brew; then
        print_status "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for this session
        if is_macos; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
        print_success "Homebrew installed"
    else
        print_status "Homebrew already installed"
    fi
}

setup_mac_configs() {
  defaults write -g ApplePressAndHoldEnabled -bool false
  print_success "Custom macOS configs applied"
}

# Function to install GitHub CLI if not present
install_gh() {
    if ! command_exists gh; then
        print_status "Installing GitHub CLI..."
        if is_macos; then
            brew install gh
        else
            # For Linux, you might need to add the repository first
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            sudo apt update
            sudo apt install gh
        fi
        print_success "GitHub CLI installed"
    else
        print_status "GitHub CLI already installed"
    fi
}

# Function to setup GitHub authentication
setup_github_auth() {
    print_status "Setting up GitHub authentication..."
    if ! gh auth status >/dev/null 2>&1; then
        gh auth login
    else
        print_status "GitHub already authenticated"
    fi
}

# Function to clone dotfiles
clone_dotfiles() {
    print_status "Cloning dotfiles..."
    
    if [[ -d ~/dotfiles ]]; then
        print_warning "dotfiles directory already exists"
        read -p "Do you want to remove it and re-clone? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf ~/dotfiles
        else
            print_error "Aborting setup"
            exit 1
        fi
    fi
    
    git clone https://github.com/ferntheplant/dotfiles.git ~/dotfiles
    cd ~/dotfiles
    print_success "Dotfiles cloned"
}

# Function to clear existing configs
clear_existing_configs() {
    print_status "Clearing existing configs..."
    rm -f ~/.zshrc ~/.zshenv ~/.gitconfig
    rm -rf ~/.config
    rm -rf ~/.local/bin
    print_success "Configs cleared"
}

# Function to install Homebrew packages
install_brew_packages() {
    print_status "Installing Homebrew packages..."
    
    if [[ ! -f brew-packages.txt ]]; then
        print_error ".Brewfile not found"
        return 1
    fi
    
    brew update
    brew bundle install --file=.Brewfile --cleanup --force --upgrade

    print_success "Homebrew packages installed"
}

# Function to run the dotfiles install script
run_dotfiles_install() {
    print_status "Running dotfiles install script..."
    ./scripts/install.sh
    print_success "Dotfiles installed"
}

# Function to setup mise
setup_mise() {
    print_status "Setting up mise..."
    if ! command_exists mise; then
        curl https://mise.run | sh
        # Add mise to PATH for this session
        export PATH="$HOME/.local/bin:$PATH"
    fi
    ~/.local/bin/mise install
    print_success "mise setup complete"
}

# Function to setup Zsh themes
setup_zsh_themes() {
    print_status "Setting up Zsh themes..."
    
    # Create zsh directory if it doesn't exist
    mkdir -p ~/.zsh

    # Clone fzf-tab
    if [[ ! -d ~/.zsh/fzf-tab ]]; then
        git clone https://github.com/Aloxaf/fzf-tab ~/.zsh/fzf-tab
    fi
    
    # Clone and setup catppuccin theme
    if [[ ! -d ~/zsh-catppuccin-highlighting-theme ]]; then
        git clone https://github.com/catppuccin/zsh-syntax-highlighting.git ~/zsh-catppuccin-highlighting-theme
        cd ~/zsh-catppuccin-highlighting-theme
        cp -v themes/catppuccin_macchiato-zsh-syntax-highlighting.zsh ~/.zsh/
        cp -v themes/catppuccin_latte-zsh-syntax-highlighting.zsh ~/.zsh/
        cd - > /dev/null
    fi
    
    print_success "Zsh themes setup complete"
}

# Function to setup LTeX
setup_ltex() {
    print_status "Setting up LTeX..."
    
    # Create bin directory if it doesn't exist
    mkdir -p ~/bin
    
    # Download and install ltex-ls
    if [[ ! -d ~/bin/ltex-ls-16.0.0 ]]; then
        curl -L -o "$HOME/bin/ltex-ls.tar.gz" https://github.com/valentjn/ltex-ls/releases/download/16.0.0/ltex-ls-16.0.0-linux-x64.tar.gz
        cd ~/bin
        tar -xvzf ltex-ls.tar.gz
        rm ltex-ls.tar.gz
        sudo ln -s ~/bin/ltex-ls-16.0.0/bin/ltex-ls ~/.local/bin/ltex-ls
        cd - > /dev/null
    fi
    
    print_success "LTeX setup complete"
}

# Function to setup Java (macOS only)
# Must happen after mise is setup
setup_java_macos() {
    print_status "Setting up Java (macOS)..."
    
    if is_macos; then
        sudo mkdir -p /Library/Java/JavaVirtualMachines/17.0.2.jdk
        sudo ln -s /Users/fjorn/.local/share/mise/installs/java/17.0.2/Contents /Library/Java/JavaVirtualMachines/17.0.2.jdk/Contents
        print_success "Java setup complete (macOS)"
    else
        print_status "Skipping Java setup (not macOS)"
    fi
}

install_buildx() {
  print_status "Installing buildx..."
  ARCH=arm64 # change to 'arm64' for m1
  VERSION=v0.28.0
  curl -LO https://github.com/docker/buildx/releases/download/${VERSION}/buildx-${VERSION}.darwin-${ARCH}
  mkdir -p ~/.docker/cli-plugins
  mv buildx-${VERSION}.darwin-${ARCH} ~/.docker/cli-plugins/docker-buildx
  chmod +x ~/.docker/cli-plugins/docker-buildx
  print_success "buildx installed"
}

setup_cursor() {
    print_status "Setting up Cursor..."
    cat cursor-extensions.txt | xargs -L 1 cursor --install-extension
    print_success "Cursor setup complete"
}

# Function to make zsh default shell
make_zsh_default() {
    print_status "Making Zsh default shell..."
    chsh -s $(which zsh)
    print_success "Zsh set as default shell"
}

# Function to parse command line arguments
parse_args() {
    SKIP_PREREQUISITES=false
    SKIP_CLONE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-prerequisites)
                SKIP_PREREQUISITES=true
                shift
                ;;
            --skip-clone)
                SKIP_CLONE=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --skip-prerequisites    Skip installing Homebrew and GitHub CLI"
                echo "  --skip-clone            Skip cloning dotfiles (assumes already in dotfiles dir)"
                echo "  --help, -h              Show this help message"
                echo
                echo "Examples:"
                echo "  $0                      # Full setup from scratch"
                echo "  $0 --skip-prerequisites # Skip Homebrew/GH CLI install"
                echo "  $0 --skip-clone         # Setup in existing dotfiles directory"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

install_kanata() {
    print_status "Installing Kanata..."
    ./scripts/kanata.sh
    print_success "Kanata installed"
}

# Main setup function
main() {
    echo "🚀 Starting new machine setup..."
    echo "This script will set up a fresh machine with all your dotfiles and packages."
    echo
    
    # Check if we're on a supported OS
    if ! is_macos; then
        print_warning "This script is primarily designed for macOS. Some features may not work on other systems."
    fi
    
    # Install prerequisites (unless skipped)
    if [[ "$SKIP_PREREQUISITES" == "false" ]]; then
        install_homebrew
        install_gh
    fi
    
    # Setup authentication and clone dotfiles (unless skipped)
    if [[ "$SKIP_CLONE" == "false" ]]; then
        setup_github_auth
        clone_dotfiles
    fi
    
    # Ensure we're in dotfiles directory
    if [[ ! -f "scripts/install.sh" ]]; then
        print_error "Not in dotfiles directory. Please run this script from the dotfiles directory."
        exit 1
    fi
    
    # Clear existing configs
    clear_existing_configs
    setup_mac_configs
    
    # Setup dotfiles
    install_brew_packages
    run_dotfiles_install
    
    # Setup base tools
    setup_mise
    setup_cursor
    
    # Setup tools
    setup_zsh_themes
    setup_ltex
    setup_java_macos

    # Setup Kanata - highly interactive setup, only on macOS
    if is_macos; then
        install_kanata
    fi
    
    # Make zsh default
    make_zsh_default
    
    echo
    print_success "🎉 New machine setup complete!"
    echo
    echo "Next steps:"
    echo "1. Restart your terminal or run 'source ~/.zshrc'"
    echo "2. Test that all your tools are working"
    echo "3. Customize any additional settings as needed"
    echo
    echo "If you encounter any issues, check the logs above for error messages."
}

# Parse arguments first
parse_args "$@"

# Run main function
main 
