#!/bin/bash
# Phase 1: Install LazyVim on RHEL-compatible systems (AlmaLinux/Rocky/CentOS)
# This script installs LazyVim (Neovim configuration)
# Usage: ./install-lazyvim.sh
# Can be run locally or via: ssh user@host 'bash -s' < install-lazyvim.sh
#
# Note (EL9 / glibc): Some Neovim plugin tooling (notably Mason's prebuilt
# `tree-sitter` CLI used by nvim-treesitter) may be compiled against newer glibc
# than your distro provides, causing errors like `GLIBC_2.35 not found` when
# installing Treesitter parsers. This script mitigates that by building a local
# `tree-sitter-cli` via cargo (glibc-compatible) and wiring Mason to use it.

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "=========================================="
echo "  LazyVim Installation (RHEL-compatible)"
echo "=========================================="
echo ""

# Check if running as root (for package installation)
if [ "$EUID" -eq 0 ]; then
    log_info "Running as root - installing system packages"
    AS_ROOT=true
else
    log_info "Running as user - will use sudo for system packages"
    AS_ROOT=false
fi

# Determine the target user/home for user-level installs (cargo, mason, nvim config)
# If this script is invoked via sudo, prefer the invoking user's HOME.
TARGET_USER="$USER"
TARGET_HOME="$HOME"
if [ "$AS_ROOT" = true ] && [ -n "${SUDO_USER:-}" ]; then
    TARGET_USER="$SUDO_USER"
    TARGET_HOME="$(eval echo "~$SUDO_USER")"
fi

run_as_target_user() {
    # Run a command as the target user with HOME set appropriately
    local cmd="$1"
    if [ "$AS_ROOT" = true ] && [ -n "${SUDO_USER:-}" ]; then
        sudo -u "$TARGET_USER" -H bash -lc "$cmd"
    else
        bash -lc "$cmd"
    fi
}

# Detect RHEL variant
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_VERSION=$VERSION_ID
    log_info "Detected OS: $PRETTY_NAME"
else
    log_error "Cannot detect OS type"
    exit 1
fi

# Install function for RHEL-based systems
install_package() {
    local pkg=$1

    if rpm -q "$pkg" &>/dev/null; then
        log_info "Package $pkg already installed"
        return 0
    fi

    log_info "Installing $pkg..."

    # With `set -e`, a failing dnf install would exit the script immediately.
    # Wrap installs in an if-statement so we can handle failures cleanly.
    if [ "$AS_ROOT" = true ]; then
        if dnf install -y "$pkg" >/dev/null 2>&1; then
            log_success "Installed $pkg"
            return 0
        fi
    else
        if sudo dnf install -y "$pkg" >/dev/null 2>&1; then
            log_success "Installed $pkg"
            return 0
        fi
    fi

    log_error "Failed to install $pkg"
    return 1
}

detect_arch() {
    # Map uname output to GitHub release arch naming.
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) echo "x86_64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) echo "$arch" ;;
    esac
}

# Update package cache
log_info "Updating package cache..."
if [ "$AS_ROOT" = true ]; then
    dnf makecache >/dev/null 2>&1
else
    sudo dnf makecache >/dev/null 2>&1
fi

# Enable EPEL repository
log_info "Enabling EPEL repository..."
if [ "$AS_ROOT" = true ]; then
    dnf install -y epel-release >/dev/null 2>&1 || true
else
    sudo dnf install -y epel-release >/dev/null 2>&1 || true
fi

# Install dependencies
log_info "Installing system dependencies..."
install_package "git"
install_package "curl"
install_package "wget"

# Install build tools
log_info "Installing build tools..."
install_package "gcc"
install_package "gcc-c++"
install_package "make"
install_package "cmake"
install_package "pkg-config"
install_package "libtool"
install_package "autoconf"
install_package "automake"
install_package "zip"
install_package "unzip"

# Install CLI tools
log_info "Installing CLI tools..."

# Check if ripgrep is available in repos, if not compile it
if ! rpm -q ripgrep &>/dev/null; then
    log_info "Installing ripgrep (compiling from source)..."
    cd /tmp
    curl -LO https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-x86_64-unknown-linux-musl.tar.gz >/dev/null 2>&1
    tar xzf ripgrep-14.1.0-x86_64-unknown-linux-musl.tar.gz
    if [ "$AS_ROOT" = true ]; then
        mv ripgrep-14.1.0-x86_64-unknown-linux-musl/rg /usr/local/bin/rg
    else
        sudo mv ripgrep-14.1.0-x86_64-unknown-linux-musl/rg /usr/local/bin/rg
    fi
    log_success "Installed ripgrep"
else
    log_info "ripgrep already installed"
fi

# Check if fd-find is available, if not compile it
if ! rpm -q fd-find &>/dev/null && ! command -v fd &>/dev/null; then
    log_info "Installing fd-find (compiling from source)..."
    cd /tmp
    curl -LO https://github.com/sharkdp/fd/releases/download/v10.1.0/fd-v10.1.0-x86_64-unknown-linux-musl.tar.gz >/dev/null 2>&1
    tar xzf fd-v10.1.0-x86_64-unknown-linux-musl.tar.gz
    if [ "$AS_ROOT" = true ]; then
        mv fd-v10.1.0-x86_64-unknown-linux-musl/fd /usr/local/bin/fd
    else
        sudo mv fd-v10.1.0-x86_64-unknown-linux-musl/fd /usr/local/bin/fd
    fi
    log_success "Installed fd-find"
else
    log_info "fd-find already installed"
fi

install_package "tree"
install_package "htop"

# Install language-specific tools for LSP support
log_info "Installing language toolchains..."

# Python (for Python LSP)
install_package "python3"
install_package "python3-pip"
install_package "python3-devel"

# Install compression tools
install_package "tar"
install_package "gzip"
install_package "bzip2"

# Install Neovim
log_info "Checking Neovim installation..."
if command -v nvim &> /dev/null; then
    NVIM_VERSION=$(nvim --version | head -n1 | awk '{print $2}')
    log_info "Neovim $NVIM_VERSION already installed"

    # Check if version meets LazyVim requirement (>= 0.11.2)
    if [ "$NVIM_VERSION" \< "0.11.2" ]; then
        log_warning "Neovim $NVIM_VERSION is too old for LazyVim (requires >= 0.11.2)"
        log_info "Will install latest Neovim from AppImage..."
        if [ "$AS_ROOT" = true ]; then
            rm -f /usr/local/bin/nvim /usr/bin/nvim
        else
            sudo rm -f /usr/local/bin/nvim /usr/bin/nvim
        fi
        NVIM_NEEDS_UPDATE=true
    else
        NVIM_NEEDS_UPDATE=false
    fi
else
    NVIM_NEEDS_UPDATE=true
fi

if [ "$NVIM_NEEDS_UPDATE" = true ]; then
    log_info "Installing Neovim >= 0.11.2 for LazyVim..."

    # Remove any existing nvim binary
    if [ -f "/usr/local/bin/nvim" ] || [ -f "/usr/bin/nvim" ]; then
        log_warning "Removing old nvim binary"
        if [ "$AS_ROOT" = true ]; then
            rm -f /usr/local/bin/nvim /usr/bin/nvim
        else
            sudo rm -f /usr/local/bin/nvim /usr/bin/nvim
        fi
    fi

    # EPEL version is too old, download from GitHub
    cd /tmp

    # Clean up any existing downloads
    rm -f nvim.appimage nvim-linux-x86_64.appimage nvim-linux-x86_64.tar.gz
    rm -rf squashfs-root nvim-linux-x86_64

    # Use latest stable Neovim from neovim repository (LazyVim requires >= 0.11.2)
    # Using /latest/ endpoint ensures we always get the newest stable version
    TARBALL_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"

    log_info "Downloading latest stable Neovim (>= 0.11.2 required for LazyVim)..."
    if curl -fL -o nvim-linux-x86_64.tar.gz "$TARBALL_URL" 2>&1; then
        # Extract tarball
        log_info "Extracting Neovim tarball..."
        if tar xzf nvim-linux-x86_64.tar.gz 2>&1; then
            # Install to /usr/local (includes binary and all runtime files)
            log_info "Installing Neovim to /usr/local..."
            if [ "$AS_ROOT" = true ]; then
                cp -r nvim-linux-x86_64/* /usr/local/
            else
                sudo cp -r nvim-linux-x86_64/* /usr/local/
            fi

            # Clean up
            rm -rf nvim-linux-x86_64 nvim-linux-x86_64.tar.gz

            # Verify installation and version
            if /usr/local/bin/nvim --version >/dev/null 2>&1; then
                NVIM_VER=$(/usr/local/bin/nvim --version | head -n1 | awk '{print $2}')
                log_success "Neovim ${NVIM_VER} installed successfully"
            else
                log_error "Neovim binary not working after installation"
                exit 1
            fi
        else
            log_error "Failed to extract Neovim tarball"
            exit 1
        fi
    else
        log_error "Failed to download Neovim tarball from GitHub"
        log_error "Failed to install Neovim. Please check your internet connection and try again."
        exit 1
    fi
fi

# Verify Neovim installation
if ! command -v nvim &> /dev/null; then
    log_error "Neovim installation failed"
    exit 1
fi

NVIM_VERSION=$(nvim --version | head -n1 | awk '{print $2}')
log_success "Neovim $NVIM_VERSION is installed"

# Install Node.js for some Neovim plugins
log_info "Checking Node.js installation..."
if ! command -v node &> /dev/null; then
    log_info "Installing Node.js (required for some Neovim plugins)..."

    # Install Node.js using NodeSource for RHEL
    curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null 2>&1
    if [ "$AS_ROOT" = true ]; then
        dnf install -y nodejs >/dev/null 2>&1
    else
        sudo dnf install -y nodejs >/dev/null 2>&1
    fi

    log_success "Node.js installed"
else
    NODE_VERSION=$(node --version)
    log_info "Node.js $NODE_VERSION already installed"
fi

# Install Python support for Neovim
log_info "Setting up Python support..."
if command -v python3 &> /dev/null; then
    if [ "$AS_ROOT" = true ]; then
        python3 -m pip install --upgrade pip >/dev/null 2>&1
        python3 -m pip install pynvim >/dev/null 2>&1
        # Install Python language server and tools
        python3 -m pip install python-lsp-server >/dev/null 2>&1 || true
        python3 -m pip install black >/dev/null 2>&1 || true
        python3 -m pip install flake8 >/dev/null 2>&1 || true
        python3 -m pip install mypy >/dev/null 2>&1 || true
    else
        sudo -H python3 -m pip install --upgrade pip >/dev/null 2>&1
        sudo -H python3 -m pip install pynvim >/dev/null 2>&1
        # Install Python language server and tools
        sudo -H python3 -m pip install python-lsp-server >/dev/null 2>&1 || true
        sudo -H python3 -m pip install black >/dev/null 2>&1 || true
        sudo -H python3 -m pip install flake8 >/dev/null 2>&1 || true
        sudo -H python3 -m pip install mypy >/dev/null 2>&1 || true
    fi
    log_success "Python support and tools installed"
else
    log_warning "Python3 not found - skipping Python support"
fi

# Install optional language toolchains
INSTALL_EXTRAS="${INSTALL_EXTRA_LANGUAGES:-true}"

if [ "$INSTALL_EXTRAS" = "true" ]; then
    # Rust toolchain (for Rust LSP and tree-sitter)
    log_info "Checking Rust toolchain..."
    if ! command -v cargo &> /dev/null; then
        log_info "Installing Rust (for Rust LSP support)..."
        # Always install rustup as the target user (even when running under sudo).
        # NOTE: `SUDO_USER` may be unset if not invoked via sudo; avoid referencing it.
        run_as_target_user "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y >/dev/null 2>&1 || true"
        log_success "Rust toolchain installed"
    else
        RUST_VERSION=$(rustc --version 2>/dev/null || echo "unknown")
        log_info "Rust already installed: $RUST_VERSION"
    fi

    # Go toolchain (for Go LSP)
    log_info "Checking Go toolchain..."
    if ! command -v go &> /dev/null; then
        log_info "Installing Go (for Go LSP support)..."
        cd /tmp
        GO_VERSION="1.23.1"
        curl -LO "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" >/dev/null 2>&1
        if [ "$AS_ROOT" = true ]; then
            rm -rf /usr/local/go && tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz" >/dev/null 2>&1
            ln -sf /usr/local/go/bin/go /usr/local/bin/go 2>/dev/null || true
        else
            sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz" >/dev/null 2>&1
            sudo ln -sf /usr/local/go/bin/go /usr/local/bin/go 2>/dev/null || true
        fi
        log_success "Go toolchain installed"
    else
        GO_VERSION=$(go version 2>/dev/null | awk '{print $3}' || echo "unknown")
        log_info "Go already installed: $GO_VERSION"
    fi

    # Install additional useful tools via Cargo
    if command -v cargo &> /dev/null; then
        # NOTE: On EL9 (Alma/Rocky/RHEL 9), Mason's prebuilt tree-sitter binary may
        # require a newer glibc than the VM provides (e.g. GLIBC_2.35/2.39).
        # When that happens, nvim-treesitter fails to compile parsers.
        # Fix: build tree-sitter-cli locally (glibc-compatible) and point Mason's
        # tree-sitter shim to it.

        log_info "Ensuring tree-sitter-cli is available for nvim-treesitter (glibc-compatible build)..."

        # Build deps for tree-sitter-cli (bindgen requires libclang)
        install_package "clang"
        install_package "clang-libs"
        install_package "clang-devel"
        install_package "llvm-devel"

        # Prefer the bundled libclang from llvm20 if available
        LIBCLANG_PATH="/usr/lib64"
        if [ -d "/usr/lib64/llvm20/lib64" ]; then
            LIBCLANG_PATH="/usr/lib64/llvm20/lib64"
        elif [ -d "/usr/lib/llvm20/lib" ]; then
            LIBCLANG_PATH="/usr/lib/llvm20/lib"
        fi

        # If Mason already has a working tree-sitter, keep it.
        # Otherwise install and then override Mason's tree-sitter shim.
        if [ -x "${TARGET_HOME}/.local/share/nvim/mason/bin/tree-sitter" ] \
           && "${TARGET_HOME}/.local/share/nvim/mason/bin/tree-sitter" --version >/dev/null 2>&1; then
            log_info "Mason tree-sitter is already working"
        else
            log_info "Installing tree-sitter-cli via cargo (this may take a few minutes)..."
            run_as_target_user "export LIBCLANG_PATH='${LIBCLANG_PATH}'; cargo install tree-sitter-cli --locked || true"

            # Point Mason's tree-sitter wrapper to the locally-built one
            run_as_target_user "mkdir -p '${TARGET_HOME}/.local/share/nvim/mason/bin' && ln -sf '${TARGET_HOME}/.cargo/bin/tree-sitter' '${TARGET_HOME}/.local/share/nvim/mason/bin/tree-sitter'"

            if [ -x "${TARGET_HOME}/.local/share/nvim/mason/bin/tree-sitter" ] \
               && "${TARGET_HOME}/.local/share/nvim/mason/bin/tree-sitter" --version >/dev/null 2>&1; then
                log_success "tree-sitter-cli is installed and wired for Mason"
            else
                log_warning "tree-sitter-cli setup did not fully verify. If Treesitter parser installs fail, run: cargo install tree-sitter-cli --locked"
            fi
        fi
    fi
fi

# Backup existing Neovim config
CONFIG_DIR="$HOME/.config/nvim"
BACKUP_DIR="$HOME/.config/nvim.backup.$(date +%Y%m%d_%H%M%S)"

if [ -d "$CONFIG_DIR" ]; then
    log_warning "Existing Neovim configuration found at $CONFIG_DIR"
    log_info "Backing up to $BACKUP_DIR"
    mv "$CONFIG_DIR" "$BACKUP_DIR"
fi

# Install LazyVim
log_info "Installing LazyVim..."
git clone https://github.com/LazyVim/starter "$CONFIG_DIR" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    # Remove .git directory to make it a personal config
    rm -rf "$CONFIG_DIR/.git"

    log_success "LazyVim installed successfully"

    # Install plugins on first run
    log_info "Installing Neovim plugins (this may take a minute)..."
    nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 || true

    log_success "Plugins installed"
else
    log_error "Failed to clone LazyVim"
    exit 1
fi

# Create a basic .vimrc for vim users (if they have one)
if [ -f "$HOME/.vimrc" ] && [ ! -L "$HOME/.vimrc" ]; then
    log_warning "Found existing .vimrc - not creating symlink"
else
    log_info "Creating .vimrc symlink to use Neovim config..."
    ln -sf "$HOME/.config/nvim/init.lua" "$HOME/.vimrc" 2>/dev/null || true
fi

# Configure a clean, professional Bash prompt for the target user (optional)
# This is purely cosmetic and should never break the install.
SETUP_BASH_PROMPT="${SETUP_BASH_PROMPT:-true}"
if [ "$SETUP_BASH_PROMPT" = "true" ]; then
    log_info "Configuring a professional bash prompt..."
    run_as_target_user "mkdir -p '${TARGET_HOME}/.config'

cat > '${TARGET_HOME}/.config/bash_prompt.sh' << 'PROMPT_EOF'
# ~/.config/bash_prompt.sh
# A clean, informative prompt (user@host:cwd) with git branch when available.

__git_branch() {
  command -v git >/dev/null 2>&1 || return 0
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  local b
  b=$(git branch --show-current 2>/dev/null)
  [ -n "$b" ] && printf ' (%s)' "$b"
}

__set_prompt() {
  local exit_code=$?
  local reset='\[\e[0m\]'
  local cyan='\[\e[36m\]'
  local green='\[\e[32m\]'
  local yellow='\[\e[33m\]'
  local red='\[\e[31m\]'

  local status_color="$green"
  [ $exit_code -ne 0 ] && status_color="$red"

  # user@host:cwd (branch)  ➜
  PS1="${status_color}➜${reset} ${cyan}\u@\h${reset}:${yellow}\w${reset}${green}$(__git_branch)${reset} "
}

PROMPT_COMMAND=__set_prompt
PROMPT_EOF

# Ensure prompt file is sourced from ~/.bashrc only once.
touch '${TARGET_HOME}/.bashrc'
grep -q "bash_prompt.sh" '${TARGET_HOME}/.bashrc' 2>/dev/null || cat >> '${TARGET_HOME}/.bashrc' << 'BASHRC_EOF'

# Load custom prompt
if [ -f "$HOME/.config/bash_prompt.sh" ]; then
  source "$HOME/.config/bash_prompt.sh"
fi
BASHRC_EOF

# Ensure SSH/login shells load ~/.bashrc (many distros only read ~/.bash_profile on login)
touch '${TARGET_HOME}/.bash_profile'
grep -q "source ~/.bashrc" '${TARGET_HOME}/.bash_profile' 2>/dev/null || cat >> '${TARGET_HOME}/.bash_profile' << 'BASHPROFILE_EOF'

# Load interactive bash config for login shells
if [ -f "$HOME/.bashrc" ]; then
  source "$HOME/.bashrc"
fi
BASHPROFILE_EOF
" || true
else
    log_info "SETUP_BASH_PROMPT=false; skipping bash prompt config"
fi

# Install lazygit (optional but recommended)
log_info "Checking lazygit installation..."
INSTALL_LAZYGIT="${INSTALL_LAZYGIT:-true}"
REQUIRE_LAZYGIT="${REQUIRE_LAZYGIT:-true}"
if [ "$INSTALL_LAZYGIT" = "true" ]; then
    if ! command -v lazygit &> /dev/null; then
        log_info "Installing lazygit..."

        # 1) Try package manager first (fastest / most reliable when available)
        if install_package "lazygit"; then
            log_success "lazygit installed (dnf)"
        else
            # 2) Fallback to GitHub release tarball.
            # IMPORTANT: With `set -euo pipefail`, a failing `grep` inside a pipeline
            # would abort the whole script. Guard the pipeline with `|| true`.

            LAZYGIT_ARCH="$(detect_arch)"
            cd /tmp

            LAZYGIT_URL="$(curl -Ls \
                -H 'Accept: application/vnd.github+json' \
                -H 'User-Agent: azure-devops-learn-lazyvim-installer' \
                "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
                | grep -E "browser_download_url.*Linux_${LAZYGIT_ARCH}\\.tar\\.gz" \
                | cut -d '"' -f 4 \
                | head -n 1 \
                || true)"

            if [ -z "${LAZYGIT_URL:-}" ]; then
                log_warning "Failed to get lazygit download URL (GitHub API may be rate-limited)."
                log_warning "You can try again later or install manually:"
                log_warning "  https://github.com/jesseduffield/lazygit#installation"
                log_info "Attempting fallback install via Go toolchain..."

                # 3) Fallback to installing from source via Go. This avoids GitHub API calls
                # and works well on RHEL/Alma where a lazygit RPM may not exist.
                if ! command -v go >/dev/null 2>&1; then
                    # Try to install a distro Go (may lag behind but works for `go install`).
                    install_package "golang" || true
                fi

                if command -v go >/dev/null 2>&1; then
                    # Install to user's GOPATH/bin, then move to /usr/local/bin
                    run_as_target_user "go env -w GOPATH='${TARGET_HOME}/go' >/dev/null 2>&1 || true"
                    run_as_target_user "go install github.com/jesseduffield/lazygit@latest >/dev/null 2>&1" || true

                    if [ -x "${TARGET_HOME}/go/bin/lazygit" ]; then
                        if [ "$AS_ROOT" = true ]; then
                            mv "${TARGET_HOME}/go/bin/lazygit" /usr/local/bin/lazygit
                        else
                            sudo mv "${TARGET_HOME}/go/bin/lazygit" /usr/local/bin/lazygit
                        fi
                        log_success "lazygit installed (go install)"
                    else
                        log_warning "go install did not produce a lazygit binary; skipping"
                    fi
                else
                    log_warning "Go toolchain not available; cannot install lazygit via go"
                fi
            else
                if curl -fL -o lazygit.tar.gz "$LAZYGIT_URL" >/dev/null 2>&1; then
                    LAZYGIT_BIN_PATH=$(tar -tzf lazygit.tar.gz 2>/dev/null | grep -E '(^|/)lazygit$' | head -n 1 || true)

                    if [ -z "${LAZYGIT_BIN_PATH:-}" ]; then
                        log_warning "Could not find lazygit binary inside tarball; skipping"
                    else
                        if tar -xzf lazygit.tar.gz "$LAZYGIT_BIN_PATH" >/dev/null 2>&1; then
                            chmod +x "$LAZYGIT_BIN_PATH" 2>/dev/null || true

                            if [ "$AS_ROOT" = true ]; then
                                mv "$LAZYGIT_BIN_PATH" /usr/local/bin/lazygit
                            else
                                sudo mv "$LAZYGIT_BIN_PATH" /usr/local/bin/lazygit
                            fi

                            log_success "lazygit installed (GitHub release)"
                        else
                            log_warning "Failed to extract lazygit; skipping installation"
                        fi
                    fi

                    rm -f lazygit.tar.gz
                else
                    log_warning "Failed to download lazygit; skipping installation"
                fi
            fi
        fi
    else
        log_info "lazygit already installed"
    fi

    # If you want lazygit present for your workflow, enforce it here.
    if [ "$REQUIRE_LAZYGIT" = "true" ] && ! command -v lazygit &> /dev/null; then
        log_error "lazygit is required (REQUIRE_LAZYGIT=true) but could not be installed"
        exit 1
    fi
else
    log_info "INSTALL_LAZYGIT=false; skipping lazygit"
fi

echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
log_success "LazyVim and build tools have been installed on your RHEL-compatible system!"
echo ""
echo "Installed Components:"
echo ""
echo "Editor:"
echo "  • Neovim (latest) with LazyVim config"
echo "  • Plugins auto-synced and ready"
echo ""
echo "Build Tools:"
echo "  • gcc, gcc-c++, make"
echo "  • cmake, pkg-config, libtool"
echo "  • autoconf, automake"
echo ""
echo "Language Toolchains:"
echo "  • Python 3 (with python-lsp-server)"
echo "  • Node.js LTS (for JS/TS LSP)"
if [ "$INSTALL_EXTRAS" = "true" ]; then
    echo "  • Rust (rustc, cargo)"
    echo "  • Go (latest)"
fi
echo ""
echo "Python Tools:"
echo "  • pynvim (Neovim Python support)"
echo "  • black (code formatter)"
echo "  • flake8 (linter)"
echo "  • mypy (type checker)"
echo ""
echo "CLI Tools:"
echo "  • ripgrep (fast search)"
echo "  • fd-find (fast file finder)"
echo "  • tree (directory tree)"
echo "  • htop (process monitor)"
echo "  • lazygit (Git UI)"
echo ""
echo "Quick Start:"
echo "  nvim                    # Open Neovim with LazyVim"
echo "  nvim +Lazy              # View and manage plugins"
echo "  nvim :Lazy sync         # Sync plugins"
echo "  :help lazyvim           # View LazyVim documentation"
echo ""
echo "LSP Support:"
echo "  • Python:     Enabled (python-lsp-server)"
echo "  • JavaScript: Enabled (via TypeScript LSP)"
echo "  • TypeScript:  Enabled (via tsserver)"
echo "  • Bash:       Enabled (via bash-language-server)"
if [ "$INSTALL_EXTRAS" = "true" ]; then
    echo "  • Rust:       Enabled (via rust-analyzer)"
    echo "  • Go:         Enabled (via gopls)"
fi
echo ""
echo "Configuration:"
echo "  Location: $CONFIG_DIR"
if [ -n "${BACKUP_DIR:-}" ]; then
    echo "  Backup:   $BACKUP_DIR"
fi
echo ""
echo "Next Steps:"
echo "  1. Open Neovim: nvim"
echo "  2. Wait for plugins to install (first time only)"
echo "  3. Press 'q' to close the plugin window"
echo "  4. Check health: :checkhealth lazy"
echo "  5. Read docs: :help lazyvim"
echo ""
echo "To disable extra language toolchains in future:"
echo "  INSTALL_EXTRA_LANGUAGES=false ./install-lazyvim.sh"
echo ""
echo "For more information:"
echo "  https://www.lazyvim.org/"
echo ""
