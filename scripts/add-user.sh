#!/bin/bash

# Add User Script for SSTP VPN Server
# This script adds new users to the SSTP VPN server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONFIG_FILE="/etc/accel-ppp.conf"
SERVICE_NAME="accel-ppp"

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
    echo "Usage: $0 [OPTIONS] <username> <password>"
    echo
    echo "Options:"
    echo "  -i, --ip IP_ADDRESS     Assign specific IP address to user"
    echo "  -c, --config FILE       Configuration file path (default: /etc/accel-ppp.conf)"
    echo "  -h, --help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0 john mypassword"
    echo "  $0 --ip 10.10.10.10 jane secretpass"
    echo "  $0 --config /custom/accel-ppp.conf alice password123"
}

# Parse command line arguments
parse_args() {
    USER_IP=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--ip)
                USER_IP="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                if [[ -z "$USERNAME" ]]; then
                    USERNAME="$1"
                elif [[ -z "$PASSWORD" ]]; then
                    PASSWORD="$1"
                else
                    error "Too many arguments"
                fi
                shift
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
        error "Username and password are required"
    fi

    # Validate username (alphanumeric and underscore only)
    if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
        error "Username can only contain letters, numbers, and underscores"
    fi

    # Validate password length
    if [[ ${#PASSWORD} -lt 6 ]]; then
        error "Password must be at least 6 characters long"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Check if configuration file exists
check_config_file() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Configuration file not found: $CONFIG_FILE"
    fi
}

# Check if user already exists
check_user_exists() {
    if grep -q "^$USERNAME " "$CONFIG_FILE"; then
        error "User '$USERNAME' already exists"
    fi
}

# Get next available IP address
get_next_ip() {
    if [[ -n "$USER_IP" ]]; then
        # Check if specified IP is already in use
        if grep -q " $USER_IP$" "$CONFIG_FILE"; then
            error "IP address $USER_IP is already in use"
        fi
        echo "$USER_IP"
        return
    fi

    # Get VPN gateway from config
    VPN_GATEWAY=$(grep "gw-ip-address" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
    if [[ -z "$VPN_GATEWAY" ]]; then
        error "Could not find VPN gateway in configuration"
    fi

    # Get the last assigned IP
    LAST_IP=$(grep -v "^#" "$CONFIG_FILE" | grep -E "^[a-zA-Z]" | tail -1 | awk '{print $3}')
    
    if [[ -n "$LAST_IP" ]]; then
        # Calculate next IP
        NEXT_IP=$(echo $LAST_IP | awk -F. '{print $1"."$2"."$3"."($4+1)}')
    else
        # First user gets .2
        NEXT_IP="${VPN_GATEWAY%.*}.2"
    fi

    # Check if next IP is within range
    IP_POOL=$(grep -A 1 "\[ip-pool\]" "$CONFIG_FILE" | tail -1)
    if [[ "$IP_POOL" =~ ^([0-9.]+)-([0-9.]+)$ ]]; then
        POOL_START="${BASH_REMATCH[1]}"
        POOL_END="${BASH_REMATCH[2]}"
        
        # Simple IP comparison (works for /24 subnets)
        POOL_START_NUM=$(echo $POOL_START | awk -F. '{print $4}')
        POOL_END_NUM=$(echo $POOL_END | awk -F. '{print $4}')
        NEXT_IP_NUM=$(echo $NEXT_IP | awk -F. '{print $4}')
        
        if [[ $NEXT_IP_NUM -gt $POOL_END_NUM ]]; then
            error "No more IP addresses available in the pool"
        fi
    fi

    echo "$NEXT_IP"
}

# Add user to configuration
add_user_to_config() {
    local assigned_ip="$1"
    
    log "Adding user '$USERNAME' with IP $assigned_ip..."
    
    # Find the [chap-secrets] section and add user
    if grep -q "\[chap-secrets\]" "$CONFIG_FILE"; then
        # Add user after the [chap-secrets] line
        sed -i "/\[chap-secrets\]/a $USERNAME  $PASSWORD  $assigned_ip" "$CONFIG_FILE"
    else
        # Add [chap-secrets] section and user
        echo "" >> "$CONFIG_FILE"
        echo "[chap-secrets]" >> "$CONFIG_FILE"
        echo "# user   password   ip" >> "$CONFIG_FILE"
        echo "$USERNAME  $PASSWORD  $assigned_ip" >> "$CONFIG_FILE"
    fi
    
    log "User added to configuration file"
}

# Restart service
restart_service() {
    log "Restarting $SERVICE_NAME service..."
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl restart "$SERVICE_NAME"
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            log "Service restarted successfully"
        else
            error "Failed to restart service"
        fi
    else
        warning "Service is not running, starting it..."
        systemctl start "$SERVICE_NAME"
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            log "Service started successfully"
        else
            error "Failed to start service"
        fi
    fi
}

# Create user management script
create_user_management_script() {
    log "Creating user management script..."
    
    cat > /usr/local/bin/sstp-user-mgmt << 'EOF'
#!/bin/bash
# SSTP User Management Script

CONFIG_FILE="/etc/accel-ppp.conf"
SERVICE_NAME="accel-ppp"

case "$1" in
    list)
        echo "=== SSTP VPN Users ==="
        grep -v "^#" "$CONFIG_FILE" | grep -E "^[a-zA-Z]" | while read line; do
            if [[ -n "$line" ]]; then
                echo "$line"
            fi
        done
        ;;
    remove)
        if [[ -n "$2" ]]; then
            USERNAME="$2"
            if grep -q "^$USERNAME " "$CONFIG_FILE"; then
                sed -i "/^$USERNAME /d" "$CONFIG_FILE"
                systemctl restart "$SERVICE_NAME"
                echo "User '$USERNAME' removed successfully"
            else
                echo "User '$USERNAME' not found"
            fi
        else
            echo "Usage: sstp-user-mgmt remove <username>"
        fi
        ;;
    change-password)
        if [[ -n "$2" && -n "$3" ]]; then
            USERNAME="$2"
            NEW_PASSWORD="$3"
            if grep -q "^$USERNAME " "$CONFIG_FILE"; then
                sed -i "s/^$USERNAME .*/$USERNAME  $NEW_PASSWORD  $(grep "^$USERNAME " "$CONFIG_FILE" | awk '{print $3}')/" "$CONFIG_FILE"
                systemctl restart "$SERVICE_NAME"
                echo "Password for user '$USERNAME' changed successfully"
            else
                echo "User '$USERNAME' not found"
            fi
        else
            echo "Usage: sstp-user-mgmt change-password <username> <new_password>"
        fi
        ;;
    *)
        echo "Usage: $0 {list|remove|change-password}"
        echo
        echo "Commands:"
        echo "  list                    - List all users"
        echo "  remove <username>       - Remove a user"
        echo "  change-password <user> <pass> - Change user password"
        ;;
esac
EOF

    chmod +x /usr/local/bin/sstp-user-mgmt
}

# Display final information
display_final_info() {
    echo
    log "User added successfully!"
    echo
    info "=== User Information ==="
    echo "  Username: $USERNAME"
    echo "  Password: [HIDDEN]"
    echo "  IP Address: $ASSIGNED_IP"
    echo
    info "=== Management Commands ==="
    echo "  List users: sstp-user-mgmt list"
    echo "  Remove user: sstp-user-mgmt remove $USERNAME"
    echo "  Change password: sstp-user-mgmt change-password $USERNAME <new_password>"
    echo
    info "=== MikroTik Configuration ==="
    echo "To connect this user to MikroTik, use:"
    echo
    echo "/interface sstp-client add \\"
    echo "    name=sstp-$USERNAME \\"
    echo "    connect-to=VPS_PUBLIC_IP \\"
    echo "    user=$USERNAME \\"
    echo "    password=$PASSWORD \\"
    echo "    profile=default-encryption \\"
    echo "    certificate=\"\" \\"
    echo "    verify-server-certificate=no \\"
    echo "    disabled=no"
    echo
}

# Main function
main() {
    log "Starting user addition process..."
    
    parse_args "$@"
    check_root
    check_config_file
    check_user_exists
    
    ASSIGNED_IP=$(get_next_ip)
    add_user_to_config "$ASSIGNED_IP"
    restart_service
    create_user_management_script
    display_final_info
}

# Run main function
main "$@"


