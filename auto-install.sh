#!/bin/bash

# SSTP VPN Server - One-Click VPS Installation
# This script automatically installs and configures SSTP VPN server on VPS
# Usage: curl -sSL https://raw.githubusercontent.com/mmkash-web/sstp/main/auto-install.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ASCII Art Banner
print_banner() {
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║                    SSTP VPN Server                          ║"
    echo "  ║                One-Click VPS Installation                   ║"
    echo "  ║                                                              ║"
    echo "  ║  🚀 Automatic deployment for MikroTik remote access        ║"
    echo "  ║  🔒 Secure SSL/TLS encrypted connections                    ║"
    echo "  ║  🛡️  Built-in firewall and security                        ║"
    echo "  ║  📱 Multi-platform client support                          ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Logging functions
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

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Please run: sudo bash <(curl -sSL https://raw.githubusercontent.com/mmkash-web/sstp/main/auto-install.sh)"
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
            error "Unsupported OS: $OS. Supported: Ubuntu, Debian, CentOS, RHEL, Rocky, AlmaLinux, Fedora"
            ;;
    esac

    log "Detected OS: $OS (Package Manager: $PKG_MANAGER)"
}

# Get VPS public IP automatically
get_public_ip() {
    log "Detecting VPS public IP address..."
    
    # Try multiple methods to get public IP
    PUBLIC_IP=""
    
    # Method 1: curl ifconfig.me
    if command -v curl &> /dev/null; then
        PUBLIC_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || true)
    fi
    
    # Method 2: curl ipinfo.io
    if [[ -z "$PUBLIC_IP" ]] && command -v curl &> /dev/null; then
        PUBLIC_IP=$(curl -s --max-time 10 ipinfo.io/ip 2>/dev/null || true)
    fi
    
    # Method 3: wget ifconfig.me
    if [[ -z "$PUBLIC_IP" ]] && command -v wget &> /dev/null; then
        PUBLIC_IP=$(wget -qO- --timeout=10 ifconfig.me 2>/dev/null || true)
    fi
    
    # Method 4: dig +short
    if [[ -z "$PUBLIC_IP" ]] && command -v dig &> /dev/null; then
        PUBLIC_IP=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || true)
    fi
    
    if [[ -z "$PUBLIC_IP" ]]; then
        error "Could not automatically detect public IP. Please run with: PUBLIC_IP=your.ip.address bash <(curl -sSL https://raw.githubusercontent.com/mmkash-web/sstp/main/auto-install.sh)"
    fi
    
    log "Detected public IP: $PUBLIC_IP"
    echo "$PUBLIC_IP"
}

# Generate random credentials
generate_credentials() {
    VPN_USER="vpnuser$(shuf -i 1000-9999 -n 1)"
    VPN_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
    
    log "Generated credentials:"
    log "  Username: $VPN_USER"
    log "  Password: $VPN_PASS"
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
    success "System updated successfully"
}

# Install required packages
install_packages() {
    log "Installing required packages..."
    case $PKG_MANAGER in
        "apt")
            apt install -y accel-ppp openssl iptables-persistent curl wget
            ;;
        "yum"|"dnf")
            $PKG_MANAGER install -y accel-ppp openssl iptables-services curl wget
            ;;
    esac
    success "Packages installed successfully"
}

# Generate SSL certificate
generate_certificate() {
    log "Generating SSL certificate..."
    
    # Create directories
    mkdir -p /etc/ssl/certs /etc/ssl/private
    
    # Generate self-signed certificate
    openssl req -new -x509 -days 365 -nodes \
        -out /etc/ssl/certs/sstp.crt \
        -keyout /etc/ssl/private/sstp.key \
        -subj "/CN=sstp-vpn" \
        -addext "subjectAltName=IP:$VPS_PUBLIC_IP"
    
    # Set proper permissions
    chmod 600 /etc/ssl/private/sstp.key
    chmod 644 /etc/ssl/certs/sstp.crt
    
    success "SSL certificate generated successfully"
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
dns1=1.1.1.1
dns2=8.8.8.8
EOF

    success "Configuration created successfully"
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
    
    success "IP forwarding configured"
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
    
    # Allow VPN traffic forwarding
    iptables -A FORWARD -s $VPN_SUBNET -j ACCEPT
    iptables -A FORWARD -d $VPN_SUBNET -j ACCEPT
    
    # Allow ICMP
    iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    
    # Drop other incoming connections
    iptables -A INPUT -j DROP
    
    success "Firewall configured"
}

# Start and enable services
start_services() {
    log "Starting and enabling services..."
    
    # Enable and start accel-ppp
    systemctl enable accel-ppp
    systemctl restart accel-ppp
    
    # Check if service is running
    if systemctl is-active --quiet accel-ppp; then
        success "accel-ppp service started successfully"
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
tail -n 20 /var/log/accel-ppp.log | grep -E "(connected|disconnected)" || echo "No recent connections"
echo
echo "Configuration:"
echo "  Listen Port: 443"
echo "  Certificate: /etc/ssl/certs/sstp.crt"
echo "  Log File: /var/log/accel-ppp.log"
EOF

    chmod +x /usr/local/bin/sstp-status
    
    success "Management scripts created"
}

# Display final information
display_final_info() {
    echo
    success "🎉 SSTP VPN Server installed successfully!"
    echo
    info "=== Connection Information ==="
    echo -e "  ${CYAN}Server IP:${NC} $VPS_PUBLIC_IP"
    echo -e "  ${CYAN}Port:${NC} 443"
    echo -e "  ${CYAN}Username:${NC} $VPN_USER"
    echo -e "  ${CYAN}Password:${NC} $VPN_PASS"
    echo -e "  ${CYAN}VPN Subnet:${NC} $VPN_SUBNET"
    echo -e "  ${CYAN}MikroTik IP:${NC} ${VPN_GATEWAY%.*}.2"
    echo
    info "=== Management Commands ==="
    echo -e "  ${GREEN}Add user:${NC} sstp-add-user <username> <password>"
    echo -e "  ${GREEN}Check status:${NC} sstp-status"
    echo -e "  ${GREEN}View logs:${NC} tail -f /var/log/accel-ppp.log"
    echo -e "  ${GREEN}Restart service:${NC} systemctl restart accel-ppp"
    echo
    info "=== MikroTik Configuration ==="
    echo "Use this command on your MikroTik router:"
    echo
    echo -e "${YELLOW}/interface sstp-client add \\${NC}"
    echo -e "${YELLOW}    name=sstp-to-vps \\${NC}"
    echo -e "${YELLOW}    connect-to=$VPS_PUBLIC_IP \\${NC}"
    echo -e "${YELLOW}    user=$VPN_USER \\${NC}"
    echo -e "${YELLOW}    password=$VPN_PASS \\${NC}"
    echo -e "${YELLOW}    profile=default-encryption \\${NC}"
    echo -e "${YELLOW}    certificate=\"\" \\${NC}"
    echo -e "${YELLOW}    verify-server-certificate=no \\${NC}"
    echo -e "${YELLOW}    disabled=no${NC}"
    echo
    info "=== Next Steps ==="
    echo "1. Configure your MikroTik router with the above command"
    echo "2. Test the connection from your MikroTik"
    echo "3. Add additional users if needed using 'sstp-add-user'"
    echo "4. Check the troubleshooting guide if you encounter issues"
    echo
    warning "⚠️  Important: Save these credentials securely!"
    echo
    success "🚀 Your SSTP VPN server is ready to use!"
}

# Main installation function
main() {
    print_banner
    
    # Check if running as root
    check_root
    
    # Detect OS
    detect_os
    
    # Get VPS public IP
    VPS_PUBLIC_IP=${PUBLIC_IP:-$(get_public_ip)}
    
    # Set default values
    VPN_SUBNET="10.10.10.0/24"
    DNS1="1.1.1.1"
    DNS2="8.8.8.8"
    
    # Generate credentials
    generate_credentials
    
    # Installation steps
    update_system
    install_packages
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
