#!/bin/bash

# Linux SSTP Client Setup Script
# This script helps configure SSTP client on Linux systems

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SERVER_IP=""
USERNAME=""
PASSWORD=""
CONNECTION_NAME="sstp-vpn"
PORT="443"
CONFIG_DIR="/etc/ppp"
LOG_FILE="/var/log/sstp-client.log"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -s, --server IP         SSTP server IP address (required)"
    echo "  -u, --username USER     VPN username (required)"
    echo "  -p, --password PASS     VPN password (required)"
    echo "  -n, --name NAME         Connection name (default: sstp-vpn)"
    echo "  -P, --port PORT         Server port (default: 443)"
    echo "  -c, --config-dir DIR    Configuration directory (default: /etc/ppp)"
    echo "  -h, --help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --server 203.0.113.1 --username vpnuser --password vpnpass"
    echo "  $0 -s 203.0.113.1 -u vpnuser -p vpnpass -n my-vpn"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--server)
                SERVER_IP="$2"
                shift 2
                ;;
            -u|--username)
                USERNAME="$2"
                shift 2
                ;;
            -p|--password)
                PASSWORD="$2"
                shift 2
                ;;
            -n|--name)
                CONNECTION_NAME="$2"
                shift 2
                ;;
            -P|--port)
                PORT="$2"
                shift 2
                ;;
            -c|--config-dir)
                CONFIG_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "$SERVER_IP" || -z "$USERNAME" || -z "$PASSWORD" ]]; then
        error "Server IP, username, and password are required"
    fi
}

# Detect OS and install required packages
install_packages() {
    log "Installing required packages..."
    
    if command -v apt &> /dev/null; then
        # Ubuntu/Debian
        apt update
        apt install -y sstp-client ppp
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        yum install -y sstp-client ppp
    elif command -v dnf &> /dev/null; then
        # Fedora
        dnf install -y sstp-client ppp
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        pacman -S --noconfirm sstp-client ppp
    else
        error "Unsupported package manager. Please install sstp-client and ppp manually."
    fi
}

# Create configuration directory
create_config_dir() {
    log "Creating configuration directory..."
    mkdir -p "$CONFIG_DIR"
}

# Create SSTP client configuration
create_sstp_config() {
    log "Creating SSTP client configuration..."
    
    cat > "$CONFIG_DIR/sstp-$CONNECTION_NAME.conf" << EOF
# SSTP Client Configuration for $CONNECTION_NAME
# Generated on $(date)

[global]
debug = 1
logfile = $LOG_FILE

[connection]
name = $CONNECTION_NAME
server = $SERVER_IP
port = $PORT
username = $USERNAME
password = $PASSWORD
certificate = 
verify_cert = no
EOF

    chmod 600 "$CONFIG_DIR/sstp-$CONNECTION_NAME.conf"
}

# Create PPP options
create_ppp_options() {
    log "Creating PPP options..."
    
    cat > "$CONFIG_DIR/options.sstp" << EOF
# PPP options for SSTP
noauth
defaultroute
replacedefaultroute
usepeerdns
noipdefault
noccp
novj
nobsdcomp
nodeflate
lock
local
EOF
}

# Create connection script
create_connection_script() {
    log "Creating connection script..."
    
    cat > "/usr/local/bin/sstp-connect-$CONNECTION_NAME" << EOF
#!/bin/bash
# SSTP Connection Script for $CONNECTION_NAME

CONFIG_FILE="$CONFIG_DIR/sstp-$CONNECTION_NAME.conf"
LOG_FILE="$LOG_FILE"

log() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') \$1" | tee -a "\$LOG_FILE"
}

log "Starting SSTP connection to $SERVER_IP"

# Check if already connected
if pgrep -f "sstpc.*$SERVER_IP" > /dev/null; then
    log "SSTP connection already active"
    exit 0
fi

# Start SSTP connection
sstpc \$SERVER_IP:$PORT --log-level 2 --log-stderr --cert-warn --user \$USERNAME --password \$PASSWORD --pppd-opts file $CONFIG_DIR/options.sstp &

# Wait for connection
sleep 5

# Check if connection is established
if pgrep -f "sstpc.*$SERVER_IP" > /dev/null; then
    log "SSTP connection established successfully"
    exit 0
else
    log "Failed to establish SSTP connection"
    exit 1
fi
EOF

    chmod +x "/usr/local/bin/sstp-connect-$CONNECTION_NAME"
}

# Create disconnection script
create_disconnection_script() {
    log "Creating disconnection script..."
    
    cat > "/usr/local/bin/sstp-disconnect-$CONNECTION_NAME" << EOF
#!/bin/bash
# SSTP Disconnection Script for $CONNECTION_NAME

LOG_FILE="$LOG_FILE"

log() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') \$1" | tee -a "\$LOG_FILE"
}

log "Disconnecting SSTP connection to $SERVER_IP"

# Kill SSTP client process
pkill -f "sstpc.*$SERVER_IP"

# Kill PPP process
pkill -f "pppd.*$CONNECTION_NAME"

log "SSTP connection disconnected"
EOF

    chmod +x "/usr/local/bin/sstp-disconnect-$CONNECTION_NAME"
}

# Create status script
create_status_script() {
    log "Creating status script..."
    
    cat > "/usr/local/bin/sstp-status-$CONNECTION_NAME" << EOF
#!/bin/bash
# SSTP Status Script for $CONNECTION_NAME

echo "=== SSTP Connection Status ==="
echo "Connection Name: $CONNECTION_NAME"
echo "Server: $SERVER_IP:$PORT"
echo "Username: $USERNAME"
echo

# Check if SSTP client is running
if pgrep -f "sstpc.*$SERVER_IP" > /dev/null; then
    echo "Status: Connected"
    echo "Process: \$(pgrep -f 'sstpc.*$SERVER_IP')"
else
    echo "Status: Disconnected"
fi

echo

# Check if PPP interface exists
if ip link show | grep -q "ppp"; then
    echo "PPP Interfaces:"
    ip link show | grep "ppp"
    echo
    echo "PPP Routes:"
    ip route | grep "ppp"
else
    echo "No PPP interfaces found"
fi

echo

# Show recent logs
if [[ -f "$LOG_FILE" ]]; then
    echo "Recent logs:"
    tail -n 10 "$LOG_FILE"
fi
EOF

    chmod +x "/usr/local/bin/sstp-status-$CONNECTION_NAME"
}

# Create systemd service
create_systemd_service() {
    log "Creating systemd service..."
    
    cat > "/etc/systemd/system/sstp-$CONNECTION_NAME.service" << EOF
[Unit]
Description=SSTP VPN Connection ($CONNECTION_NAME)
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/sstp-connect-$CONNECTION_NAME
ExecStop=/usr/local/bin/sstp-disconnect-$CONNECTION_NAME
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "sstp-$CONNECTION_NAME"
}

# Display final information
display_final_info() {
    echo
    log "SSTP client setup completed successfully!"
    echo
    info "=== Configuration Summary ==="
    echo "  Connection Name: $CONNECTION_NAME"
    echo "  Server: $SERVER_IP:$PORT"
    echo "  Username: $USERNAME"
    echo "  Config File: $CONFIG_DIR/sstp-$CONNECTION_NAME.conf"
    echo "  Log File: $LOG_FILE"
    echo
    info "=== Management Commands ==="
    echo "  Connect:    sstp-connect-$CONNECTION_NAME"
    echo "  Disconnect: sstp-disconnect-$CONNECTION_NAME"
    echo "  Status:     sstp-status-$CONNECTION_NAME"
    echo "  Service:    systemctl start sstp-$CONNECTION_NAME"
    echo "  Auto-start: systemctl enable sstp-$CONNECTION_NAME"
    echo
    info "=== Testing Connection ==="
    echo "To test the connection, run:"
    echo "  sstp-connect-$CONNECTION_NAME"
    echo
    echo "To check status:"
    echo "  sstp-status-$CONNECTION_NAME"
    echo
}

# Main function
main() {
    log "Starting SSTP client setup..."
    
    parse_args "$@"
    install_packages
    create_config_dir
    create_sstp_config
    create_ppp_options
    create_connection_script
    create_disconnection_script
    create_status_script
    create_systemd_service
    display_final_info
}

# Run main function
main "$@"


