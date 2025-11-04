#!/usr/bin/env bash
set -e

SCRIPT_NAME="serhas"
SCRIPT_URL="https://raw.githubusercontent.com/theserhas/deploy/master/$SCRIPT_NAME.sh"
SCRIPT_PATH="/usr/local/bin/$SCRIPT_NAME"
CONFIG_DIR="/opt/$SCRIPT_NAME"
DATA_DIR="/var/lib/$SCRIPT_NAME"
COMPOSE_FILE="$CONFIG_DIR/docker-compose.yml"

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

check_running_as_root() {
    if [ "$(id -u)" != "0" ]; then
        error "This script must be run as root. Please use sudo."
    fi
}

detect_os() {
    # Detect the operating system
    if [ -f /etc/lsb-release ]; then
        OS=$(lsb_release -si)
        elif [ -f /etc/os-release ]; then
        OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
        elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | awk '{print $1}')
        elif [ -f /etc/arch-release ]; then
        OS="Arch"
    else
        error "Unsupported operating system."
    fi
}


detect_and_update_package_manager() {
    log "Detecting operating system and updating package manager..."
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        PKG_MANAGER="apt-get"
        $PKG_MANAGER update
        elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        PKG_MANAGER="yum"
        $PKG_MANAGER update -y
        $PKG_MANAGER install -y epel-release
        elif [ "$OS" == "Fedora"* ]; then
        PKG_MANAGER="dnf"
        $PKG_MANAGER update
        elif [ "$OS" == "Arch" ]; then
        PKG_MANAGER="pacman"
        $PKG_MANAGER -Sy
    else
        error "Unsupported operating system."
    fi
}


detect_compose() {
    if docker compose >/dev/null 2>&1; then
        COMPOSE='docker compose'
        elif docker-compose >/dev/null 2>&1; then
        COMPOSE='docker-compose'
    else
        error "Docker Compose is not installed. Please install Docker Compose to proceed."
    fi
}


install_package () {
    if [ -z $PKG_MANAGER ]; then
        detect_and_update_package_manager
    fi

    PACKAGE=$1
    log "Installing package: $PACKAGE"
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        $PKG_MANAGER -y install "$PACKAGE"
        elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        $PKG_MANAGER install -y "$PACKAGE"
        elif [ "$OS" == "Fedora"* ]; then
        $PKG_MANAGER install -y "$PACKAGE"
        elif [ "$OS" == "Arch" ]; then
        $PKG_MANAGER -S --noconfirm "$PACKAGE"
    else
        error "Unsupported operating system."
    fi
}

install_docker() {
    log "Installing Docker"
    curl -fsSL https://get.docker.com | sh
    success "Docker installed successfully"
}

install_script() {
    log "Installing script to $SCRIPT_PATH"
    curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin $SCRIPT_PATH
    success "Script installed successfully"
}

update_script() {
    log "Updating script at $SCRIPT_PATH"
    curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin $SCRIPT_PATH
    success "Script updated successfully"
}

uninstall_script() {
    log "Uninstalling script from $SCRIPT_PATH"
    rm -f $SCRIPT_PATH
    success "Script uninstalled successfully"
}



install_sarhas() {
    FILES_URL_PREFIX="https://raw.githubusercontent.com/thesarhas/sarhas/master"
	COMPOSE_FILES_URL="https://raw.githubusercontent.com/thesarhas/deploy/master"

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$DATA_DIR"

    log "Fetching docker-compose file"
    curl -sL "$COMPOSE_FILES_URL/docker-compose.yml" -o $COMPOSE_FILE
    success "File saved in $COMPOSE_FILE"

    log "Fetching example .env file"
    curl -sL "$FILES_URL_PREFIX/.env.example" -o "$CONFIG_DIR/.env"
    success "File saved in $CONFIG_DIR/.env"

    success "Sarhas files downloaded successfully"
}

uninstall_sarhas() {
    log "Removing Sarhas configuration and data directories"
    rm -rf "$CONFIG_DIR"
    rm -rf "$DATA_DIR"
    success "Sarhas configuration and data directories removed successfully"
}

is_sarhas_installed() {
    if [ -d "$CONFIG_DIR" ]; then
        return 0
    else
        return 1
    fi
}

is_sarhas_running() {
    if [ -z "$($COMPOSE -f $COMPOSE_FILE ps -q -a)" ]; then
        return 1
    else
        return 0
    fi
}

start_sarhas() {
    log "Starting Sarhas service"
    $COMPOSE -f $COMPOSE_FILE -p "$SCRIPT_NAME" up -d --remove-orphans
    success "Sarhas service started successfully"
}

stop_sarhas() {
    log "Stopping Sarhas service"
    $COMPOSE -f $COMPOSE_FILE -p "$SCRIPT_NAME" down
    success "Sarhas service stopped successfully"
}

logs_sarhas() {
    log "Displaying Sarhas service logs"
    $COMPOSE -f $COMPOSE_FILE -p "$SCRIPT_NAME" logs -f
}

sarhas_cli() {
    $COMPOSE -f $COMPOSE_FILE -p "$SCRIPT_NAME" exec -e CLI_PROG_NAME="sarhas cli" sarhas /app/sarhas-cli.py "$@"
}

update_sarhas() {
    $COMPOSE -f $COMPOSE_FILE -p "$SCRIPT_NAME" pull
}

uninstall_images() {
        images=$(docker images | grep sarhas | awk '{print $3}')

    if [ -n "$images" ]; then
        colorized_echo yellow "Removing Docker images of Sarhas"
        for image in $images; do
            if docker rmi "$image" >/dev/null 2>&1; then
                warn "Removed image: $image"
            fi
        done
    fi
}

help() {
    echo "Usage: $SCRIPT_NAME [command]"
    echo
    echo "Commands:"
    echo "  install             Install or update Serhas"
    echo "  update              Update Serhas to the latest version"
    echo "  uninstall           Uninstall Serhas"
    echo "  status              Show the status of Serhas"
    echo "  start               Start Serhas service"
    echo "  stop                Stop Serhas service"
    echo "  restart             Restart Serhas service"
    echo "  logs                Show Serhas service logs"
    echo "  env                 Display environment variables for Serhas"
    echo
    echo "Example:"
    echo "  $SCRIPT_NAME install"
    echo "  $SCRIPT_NAME status"
}

case "$1" in
    install)
        check_running_as_root
        if is_sarhas_installed; then
            error "Sarhas is already installed. Use 'update' to update."
        fi
        detect_os
        if ! command -v jq >/dev/null 2>&1; then
            install_package jq
        fi
        if ! command -v curl >/dev/null 2>&1; then
            install_package curl
        fi
        if ! command -v docker >/dev/null 2>&1; then
            install_docker
        fi
        detect_compose
        install_script
        install_sarhas
        start_sarhas
        logs_sarhas
        ;;
    update)
        check_running_as_root
        if ! is_sarhas_installed; then
            error "Sarhas is not installed. Use 'install' to install."
        fi
        detect_compose
        update_script
        log "Updating Sarhas to the latest version"
        update_sarhas
        log "Restarting Sarhas service"
        stop_sarhas
        start_sarhas
        success "Sarhas updated successfully"
        logs_sarhas
        ;;
    uninstall)
        check_running_as_root
        if ! is_sarhas_installed; then
            error "Sarhas is not installed."
        fi
        read -p "Are you sure you want to uninstall Sarhas? This will remove all configuration and data. (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            error "Uninstallation cancelled."
        fi
        detect_compose
        if is_sarhas_running; then
            stop_sarhas
        fi
        uninstall_sarhas
        uninstall_images
        uninstall_script
        success "Sarhas uninstalled successfully"
        ;;
    status)
        if ! is_sarhas_installed; then
            error "Sarhas is not installed. Use 'install' to install."
        fi
        detect_compose
        if is_sarhas_running; then
            success "Sarhas is running."
        else
            warn "Sarhas is not running."
        fi
        ;;
    start)
        if ! is_sarhas_installed; then
            error "Sarhas is not installed. Use 'install' to install."
        fi
        detect_compose
        if is_sarhas_running; then
            warn "Sarhas is already running."
        else
            start_sarhas
        fi
        ;;
    stop)
        if ! is_sarhas_installed; then
            error "Sarhas is not installed. Use 'install' to install."
        fi
        detect_compose
        if is_sarhas_running; then
            stop_sarhas
        else
            warn "Sarhas is not running."
        fi
        ;;
    restart)
        if ! is_sarhas_installed; then
            error "Sarhas is not installed. Use 'install' to install."
        fi
        detect_compose
        if is_sarhas_running; then
            stop_sarhas
            start_sarhas
        else
            warn "Sarhas is not running. Starting Sarhas."
            start_sarhas
        fi
        ;;
    logs)
        if ! is_sarhas_installed; then
            error "Sarhas is not installed. Use 'install' to install."
        fi
        detect_compose
        if ! is_sarhas_running; then
            error "Sarhas is not running. Use 'start' to start."
        fi
        logs_sarhas
        ;;
    env)
        if ! is_sarhas_installed; then
            error "Sarhas is not installed. Use 'install' to install."
        fi
        nano "$CONFIG_DIR/.env"
        ;;
    cli)
        if ! is_sarhas_installed; then
            error "Sarhas is not installed. Use 'install' to install."
        fi
        detect_compose
        if ! is_sarhas_running; then
            error "Sarhas is not running. Use 'start' to start."
        fi
        shift
        sarhas_cli "$@"
        ;;
    *)
        usage
        ;;
esac