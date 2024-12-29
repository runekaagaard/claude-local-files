#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

DOMAIN="cdn.jsdelivr.net"
HOSTS_MARKER="# claude-local-files"

# Check dependencies
check_deps() {
    local missing_deps=()
    
    if ! command -v mkcert >/dev/null 2>&1; then
        missing_deps+=("mkcert")
    fi
    
    if ! command -v caddy >/dev/null 2>&1; then
        missing_deps+=("caddy")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}" >&2
        echo "Please install them and try again" >&2
        exit 1
    fi
}

# Manage /etc/hosts entry
setup_hosts() {
    if ! grep -q "${HOSTS_MARKER}$" /etc/hosts; then
        echo "Adding ${DOMAIN} to /etc/hosts..."
        echo "127.0.0.1 ${DOMAIN} ${HOSTS_MARKER}" | sudo tee -a /etc/hosts >/dev/null
    fi
}

cleanup_hosts() {
    echo "Removing ${DOMAIN} from /etc/hosts..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sudo sed -i '' "/${HOSTS_MARKER}$/d" /etc/hosts
    else
        sudo sed -i "/${HOSTS_MARKER}$/d" /etc/hosts
    fi
}

# Setup certificates if needed
setup_certs() {
    if [ ! -f "${DOMAIN}.pem" ] || [ ! -f "${DOMAIN}-key.pem" ]; then
        echo "Setting up certificates..."
        mkcert -install
        mkcert "$DOMAIN"
    fi
}

# Main
main() {
    check_deps
    setup_hosts
    setup_certs
    
    echo "Starting Caddy server..."
    trap cleanup_hosts EXIT
    sudo caddy run
}

main "$@"
