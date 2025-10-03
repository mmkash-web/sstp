#!/bin/bash

# SSTP VPN Server Installation Script
# This script sets up an SSTP VPN server using accel-ppp

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
VPN_USER="net1"
VPN_PASS="net1"
VPS_PUBLIC_IP=""
VPN_SUBNET="10.10.10.0/24"
VPN_GATEWAY="10.10.10.1"
DNS1="1.1.1.1"
DNS2="8.8.8.8"
CERT_DAYS="365"

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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Detect OS and package manager
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        error "Cannot detect OS version"
    fi

    case $OS in
        "Ubuntu"*|"Debian"*)
            PKG_MANAGER="apt"
            ;;
        "CentOS"*|"Red Hat"*|"Rocky"*|"AlmaLinux"*)
            PKG_MANAGER="yum"
            ;;
        "Fedora"*)
            PKG_MANAGER="dnf"
            ;;
        *)
            error "Unsupported OS: $OS"
            ;;
    esac

    log "Detected OS: $OS (Package Manager: $PKG_MANAGER)"
}

# Update system packages
update_system() {
    log "Updating system packages..."
    case $PKG_MANAGER in
        "apt")
            apt update && apt upgrade -y
            ;;
        "yum"|"dnf")
            $PKG_MANAGER update -y
            ;;
    esac
}

# Install required packages
install_packages() {
    log "Installing required packages..."
    case $PKG_MANAGER in
        "apt")
            apt install -y accel-ppp openssl iptables-persistent
            ;;
        "yum"|"dnf")
            $PKG_MANAGER install -y accel-ppp openssl iptables-services
            ;;
    esac
}

# Get user input
get_configuration() {
    echo
    info "SSTP VPN Server Configuration"
    echo "=============================="
    
    while [[ -z "$VPN_USER" ]]; do
        read -p "Enter VPN username: " VPN_USER
        if [[ -z "$VPN_USER" ]]; then
            warning "Username cannot be empty"
        fi
    done
    
    while [[ -z "$VPN_PASS" ]]; do
        read -s -p "Enter VPN password: " VPN_PASS
        echo
        if [[ -z "$VPN_PASS" ]]; then
            warning "Password cannot be empty"
        fi
    done
    
    while [[ -z "$VPS_PUBLIC_IP" ]]; do
        read -p "Enter VPS public IP address: " VPS_PUBLIC_IP
        if [[ -z "$VPS_PUBLIC_IP" ]]; then
            warning "Public IP cannot be empty"
        fi
    done
    
    read -p "Enter VPN subnet (default: $VPN_SUBNET): " input_subnet
    if [[ -n "$input_subnet" ]]; then
        VPN_SUBNET="$input_subnet"
    fi
    
    read -p "Enter primary DNS server (default: $DNS1): " input_dns1
    if [[ -n "$input_dns1" ]]; then
        DNS1="$input_dns1"
    fi
    
    read -p "Enter secondary DNS server (default: $DNS2): " input_dns2
    if [[ -n "$input_dns2" ]]; then
        DNS2="$input_dns2"
    fi
    
    echo
    info "Configuration Summary:"
    echo "  VPN Username: $VPN_USER"
    echo "  VPN Password: [HIDDEN]"
    echo "  VPS Public IP: $VPS_PUBLIC_IP"
    echo "  VPN Subnet: $VPN_SUBNET"
    echo "  Primary DNS: $DNS1"
    echo "  Secondary DNS: $DNS2"
    echo
    
    read -p "Continue with installation? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        error "Installation cancelled"
    fi
}

# Generate SSL certificate
generate_certificate() {
    log "Generating SSL certificate..."
    
    # Create directories
    mkdir -p /etc/ssl/certs /etc/ssl/private
    
    # Generate self-signed certificate
    openssl req -new -x509 -days $CERT_DAYS -nodes \
        -out /etc/ssl/certs/sstp.crt \
        -keyout /etc/ssl/private/sstp.key \
        -subj "/CN=sstp-vpn" \
        -addext "subjectAltName=IP:$VPS_PUBLIC_IP"
    
    # Set proper permissions
    chmod 600 /etc/ssl/private/sstp.key
    chmod 644 /etc/ssl/certs/sstp.crt
    
    log "SSL certificate generated successfully"
}

# Create accel-ppp configuration
create_accel_config() {
    log "Creating accel-ppp configuration..."
    
    # Extract gateway IP from subnet
    VPN_GATEWAY=$(echo $VPN_SUBNET | sed 's/\.0\/.*$/.1/')
    
    cat > /etc/accel-ppp.conf << EOF
[modules]
log file
ppp
sstp

[core]
log-error=/var/log/accel-ppp.log
thread-count=2

[sstp]
bind=0.0.0.0:443
cert=/etc/ssl/certs/sstp.crt
key=/etc/ssl/private/sstp.key

[ppp]
verbose=1
mtu=1400
mru=1400
check-ip=0
lcp-echo-interval=30
lcp-echo-failure=3

[auth]
any-login=0
require-authentication=1

[chap-secrets]
# user   password   ip
$VPN_USER  $VPN_PASS  ${VPN_GATEWAY%.*}.2

[ip-pool]
gw-ip-address=$VPN_GATEWAY
${VPN_GATEWAY%.*}.2-${VPN_GATEWAY%.*}.200

[dns]
dns1=$DNS1
dns2=$DNS2
EOF

    log "accel-ppp configuration created"
}

# Configure IP forwarding
configure_ip_forwarding() {
    log "Configuring IP forwarding..."
    
    # Enable IP forwarding
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
    
    # Get the main network interface
    MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    
    # Configure NAT
    iptables -t nat -A POSTROUTING -s $VPN_SUBNET -o $MAIN_INTERFACE -j MASQUERADE
    
    # Save iptables rules
    case $PKG_MANAGER in
        "apt")
            iptables-save > /etc/iptables/rules.v4
            ;;
        "yum"|"dnf")
            service iptables save
            ;;
    esac
    
    log "IP forwarding configured"
}

# Configure firewall
configure_firewall() {
    log "Configuring firewall..."
    
    # Allow SSH
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # Allow SSTP (port 443)
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    
    # Allow established connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Drop other incoming connections
    iptables -A INPUT -j DROP
    
    # Allow forwarding for VPN subnet
    iptables -A FORWARD -s $VPN_SUBNET -j ACCEPT
    iptables -A FORWARD -d $VPN_SUBNET -j ACCEPT
    
    log "Firewall configured"
}

# Start and enable services
start_services() {
    log "Starting and enabling services..."
    
    # Enable and start accel-ppp
    systemctl enable accel-ppp
    systemctl restart accel-ppp
    
    # Check if service is running
    if systemctl is-active --quiet accel-ppp; then
        log "accel-ppp service started successfully"
    else
        error "Failed to start accel-ppp service"
    fi
}

# Create management scripts
create_management_scripts() {
    log "Creating management scripts..."
    
    # Create add-user script
    cat > /usr/local/bin/sstp-add-user << 'EOF'
#!/bin/bash
if [[ $# -ne 2 ]]; then
    echo "Usage: sstp-add-user <username> <password>"
    exit 1
fi

USERNAME=$1
PASSWORD=$2
VPN_GATEWAY=$(grep "gw-ip-address" /etc/accel-ppp.conf | cut -d'=' -f2 | tr -d ' ')

# Get next available IP
LAST_IP=$(grep -v "^#" /etc/accel-ppp.conf | grep -E "^[a-zA-Z]" | tail -1 | awk '{print $3}')
if [[ -n "$LAST_IP" ]]; then
    NEXT_IP=$(echo $LAST_IP | awk -F. '{print $1"."$2"."$3"."($4+1)}')
else
    NEXT_IP="${VPN_GATEWAY%.*}.2"
fi

# Add user to chap-secrets
echo "$USERNAME  $PASSWORD  $NEXT_IP" >> /etc/accel-ppp.conf

# Restart service
systemctl restart accel-ppp

echo "User $USERNAME added with IP $NEXT_IP"
EOF

    chmod +x /usr/local/bin/sstp-add-user
    
    # Create status script
    cat > /usr/local/bin/sstp-status << 'EOF'
#!/bin/bash
echo "=== SSTP VPN Server Status ==="
echo
echo "Service Status:"
systemctl status accel-ppp --no-pager
echo
echo "Active Connections:"
tail -n 20 /var/log/accel-ppp.log | grep -E "(connected|disconnected)"
echo
echo "Configuration:"
echo "  Listen Port: 443"
echo "  Certificate: /etc/ssl/certs/sstp.crt"
echo "  Log File: /var/log/accel-ppp.log"
EOF

    chmod +x /usr/local/bin/sstp-status
    
    log "Management scripts created"
}

# Display final information
display_final_info() {
    echo
    log "Installation completed successfully!"
    echo
    info "=== Configuration Summary ==="
    echo "  VPN Username: $VPN_USER"
    echo "  VPN Password: [HIDDEN]"
    echo "  VPS Public IP: $VPS_PUBLIC_IP"
    echo "  VPN Subnet: $VPN_SUBNET"
    echo "  VPN Gateway: $VPN_GATEWAY"
    echo "  MikroTik IP: ${VPN_GATEWAY%.*}.2"
    echo "  SSTP Port: 443"
    echo
    info "=== Management Commands ==="
    echo "  Add user: sstp-add-user <username> <password>"
    echo "  Check status: sstp-status"
    echo "  View logs: tail -f /var/log/accel-ppp.log"
    echo "  Restart service: systemctl restart accel-ppp"
    echo
    info "=== MikroTik Configuration ==="
    echo "Use the following command on your MikroTik:"
    echo
    echo "/interface sstp-client add \\"
    echo "    name=sstp-to-vps \\"
    echo "    connect-to=$VPS_PUBLIC_IP \\"
    echo "    user=$VPN_USER \\"
    echo "    password=$VPN_PASS \\"
    echo "    profile=default-encryption \\"
    echo "    certificate=\"\" \\"
    echo "    verify-server-certificate=no \\"
    echo "    disabled=no"
    echo
    info "=== Next Steps ==="
    echo "1. Configure your MikroTik router with the above command"
    echo "2. Test the connection from your MikroTik"
    echo "3. Set up additional users if needed using 'sstp-add-user'"
    echo "4. Check the troubleshooting guide if you encounter issues"
    echo
    warning "Important: Make sure port 443 is open in your VPS firewall!"
    echo
}

# Main installation function
main() {
    log "Starting SSTP VPN Server installation..."
    
    check_root
    detect_os
    update_system
    install_packages
    get_configuration
    generate_certificate
    create_accel_config
    configure_ip_forwarding
    configure_firewall
    start_services
    create_management_scripts
    display_final_info
}

# Run main function
main "$@"


