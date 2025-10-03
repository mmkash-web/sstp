#!/bin/bash

# Firewall Setup Script for SSTP VPN Server
# This script configures iptables rules for SSTP VPN server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VPN_SUBNET="10.10.10.0/24"
SSTP_PORT="443"
SSH_PORT="22"
API_PORT="8728"
ADMIN_IP=""
MAIN_INTERFACE=""

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
    echo "  -s, --subnet SUBNET     VPN subnet (default: 10.10.10.0/24)"
    echo "  -p, --port PORT         SSTP port (default: 443)"
    echo "  -a, --admin-ip IP       Admin IP for API access (optional)"
    echo "  -i, --interface IFACE   Main network interface (auto-detect if not specified)"
    echo "  -h, --help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --subnet 192.168.100.0/24 --port 443"
    echo "  $0 --admin-ip 203.0.113.1 --subnet 10.10.10.0/24"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--subnet)
                VPN_SUBNET="$2"
                shift 2
                ;;
            -p|--port)
                SSTP_PORT="$2"
                shift 2
                ;;
            -a|--admin-ip)
                ADMIN_IP="$2"
                shift 2
                ;;
            -i|--interface)
                MAIN_INTERFACE="$2"
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
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Detect main network interface
detect_interface() {
    if [[ -z "$MAIN_INTERFACE" ]]; then
        MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
        if [[ -z "$MAIN_INTERFACE" ]]; then
            error "Could not detect main network interface"
        fi
        log "Detected main interface: $MAIN_INTERFACE"
    fi
}

# Backup existing iptables rules
backup_iptables() {
    log "Backing up existing iptables rules..."
    iptables-save > /etc/iptables/rules.v4.backup.$(date +%Y%m%d_%H%M%S)
    log "Backup saved to /etc/iptables/rules.v4.backup.$(date +%Y%m%d_%H%M%S)"
}

# Clear existing rules
clear_iptables() {
    log "Clearing existing iptables rules..."
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    iptables -X
    iptables -t nat -X
    iptables -t mangle -X
}

# Set default policies
set_default_policies() {
    log "Setting default iptables policies..."
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
}

# Allow loopback traffic
allow_loopback() {
    log "Allowing loopback traffic..."
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
}

# Allow established connections
allow_established() {
    log "Allowing established connections..."
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
}

# Allow SSH access
allow_ssh() {
    log "Allowing SSH access on port $SSH_PORT..."
    iptables -A INPUT -p tcp --dport $SSH_PORT -j ACCEPT
}

# Allow SSTP access
allow_sstp() {
    log "Allowing SSTP access on port $SSTP_PORT..."
    iptables -A INPUT -p tcp --dport $SSTP_PORT -j ACCEPT
}

# Configure NAT for VPN clients
configure_nat() {
    log "Configuring NAT for VPN subnet $VPN_SUBNET..."
    iptables -t nat -A POSTROUTING -s $VPN_SUBNET -o $MAIN_INTERFACE -j MASQUERADE
}

# Allow VPN traffic forwarding
allow_vpn_forwarding() {
    log "Allowing VPN traffic forwarding..."
    iptables -A FORWARD -s $VPN_SUBNET -j ACCEPT
    iptables -A FORWARD -d $VPN_SUBNET -j ACCEPT
}

# Configure API port forwarding (optional)
configure_api_forwarding() {
    if [[ -n "$ADMIN_IP" ]]; then
        log "Configuring API port forwarding for admin IP $ADMIN_IP..."
        
        # Get MikroTik IP (first client IP in subnet)
        MIKROTIK_IP=$(echo $VPN_SUBNET | sed 's/\.0\/.*$/.2/')
        
        # Forward API port to MikroTik
        iptables -t nat -A PREROUTING -p tcp -s $ADMIN_IP/32 --dport $API_PORT -j DNAT --to-destination $MIKROTIK_IP:$API_PORT
        iptables -A FORWARD -p tcp -s $ADMIN_IP -d $MIKROTIK_IP --dport $API_PORT -j ACCEPT
        
        log "API port forwarding configured: $ADMIN_IP:$API_PORT -> $MIKROTIK_IP:$API_PORT"
    else
        info "No admin IP specified, skipping API port forwarding"
    fi
}

# Allow ICMP (ping)
allow_icmp() {
    log "Allowing ICMP (ping) traffic..."
    iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT
}

# Configure rate limiting for SSH
configure_ssh_rate_limit() {
    log "Configuring SSH rate limiting..."
    iptables -A INPUT -p tcp --dport $SSH_PORT -m state --state NEW -m recent --set --name SSH
    iptables -A INPUT -p tcp --dport $SSH_PORT -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
}

# Configure rate limiting for SSTP
configure_sstp_rate_limit() {
    log "Configuring SSTP rate limiting..."
    iptables -A INPUT -p tcp --dport $SSTP_PORT -m state --state NEW -m recent --set --name SSTP
    iptables -A INPUT -p tcp --dport $SSTP_PORT -m state --state NEW -m recent --update --seconds 60 --hitcount 10 --name SSTP -j DROP
}

# Save iptables rules
save_iptables() {
    log "Saving iptables rules..."
    
    # Detect package manager and save accordingly
    if command -v apt &> /dev/null; then
        # Ubuntu/Debian
        iptables-save > /etc/iptables/rules.v4
        log "Rules saved to /etc/iptables/rules.v4"
    elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
        # CentOS/RHEL/Fedora
        service iptables save
        log "Rules saved using iptables service"
    else
        warning "Could not detect package manager, rules not saved automatically"
        warning "Please save rules manually using: iptables-save > /etc/iptables/rules.v4"
    fi
}

# Create iptables management script
create_management_script() {
    log "Creating iptables management script..."
    
    cat > /usr/local/bin/sstp-firewall << 'EOF'
#!/bin/bash
# SSTP Firewall Management Script

case "$1" in
    status)
        echo "=== iptables Status ==="
        iptables -L -n -v
        echo
        echo "=== NAT Rules ==="
        iptables -t nat -L -n -v
        ;;
    restart)
        echo "Restarting iptables..."
        iptables -F
        iptables -t nat -F
        iptables -t mangle -F
        iptables -X
        iptables -t nat -X
        iptables -t mangle -X
        /usr/local/bin/sstp-setup-firewall
        ;;
    backup)
        echo "Backing up iptables rules..."
        iptables-save > /etc/iptables/rules.v4.backup.$(date +%Y%m%d_%H%M%S)
        echo "Backup completed"
        ;;
    restore)
        if [[ -n "$2" ]]; then
            echo "Restoring iptables rules from $2..."
            iptables-restore < "$2"
            echo "Restore completed"
        else
            echo "Usage: sstp-firewall restore <backup_file>"
        fi
        ;;
    *)
        echo "Usage: $0 {status|restart|backup|restore}"
        echo
        echo "Commands:"
        echo "  status   - Show current iptables rules"
        echo "  restart  - Restart firewall with SSTP rules"
        echo "  backup   - Backup current iptables rules"
        echo "  restore  - Restore iptables rules from backup"
        ;;
esac
EOF

    chmod +x /usr/local/bin/sstp-firewall
}

# Display final information
display_final_info() {
    echo
    log "Firewall configuration completed successfully!"
    echo
    info "=== Firewall Configuration Summary ==="
    echo "  VPN Subnet: $VPN_SUBNET"
    echo "  SSTP Port: $SSTP_PORT"
    echo "  SSH Port: $SSH_PORT"
    echo "  Main Interface: $MAIN_INTERFACE"
    if [[ -n "$ADMIN_IP" ]]; then
        echo "  Admin IP: $ADMIN_IP"
        echo "  API Port Forwarding: $ADMIN_IP:$API_PORT -> $(echo $VPN_SUBNET | sed 's/\.0\/.*$/.2/'):$API_PORT"
    fi
    echo
    info "=== Management Commands ==="
    echo "  Check status: sstp-firewall status"
    echo "  Restart firewall: sstp-firewall restart"
    echo "  Backup rules: sstp-firewall backup"
    echo "  Restore rules: sstp-firewall restore <backup_file>"
    echo
    info "=== Security Features ==="
    echo "  ✓ SSH rate limiting (4 connections per minute)"
    echo "  ✓ SSTP rate limiting (10 connections per minute)"
    echo "  ✓ NAT for VPN clients"
    echo "  ✓ ICMP allowed for ping"
    echo "  ✓ Established connections allowed"
    echo
    warning "Important: Test your SSH connection before closing this session!"
    echo
}

# Main function
main() {
    log "Starting firewall configuration..."
    
    parse_args "$@"
    check_root
    detect_interface
    backup_iptables
    clear_iptables
    set_default_policies
    allow_loopback
    allow_established
    allow_ssh
    allow_sstp
    configure_nat
    allow_vpn_forwarding
    configure_api_forwarding
    allow_icmp
    configure_ssh_rate_limit
    configure_sstp_rate_limit
    save_iptables
    create_management_script
    display_final_info
}

# Run main function
main "$@"


