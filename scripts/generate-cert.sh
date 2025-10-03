#!/bin/bash

# SSL Certificate Generation Script for SSTP VPN
# This script generates self-signed certificates for SSTP VPN server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CERT_DAYS=365
CERT_DIR="/etc/ssl"
CERT_FILE="sstp.crt"
KEY_FILE="sstp.key"
CN="sstp-vpn"
VPS_IP=""

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
    echo "  -i, --ip IP_ADDRESS     VPS public IP address (required)"
    echo "  -d, --days DAYS         Certificate validity in days (default: 365)"
    echo "  -c, --cn COMMON_NAME    Common name for certificate (default: sstp-vpn)"
    echo "  -o, --output DIR        Output directory (default: /etc/ssl)"
    echo "  -h, --help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --ip 203.0.113.1"
    echo "  $0 --ip 203.0.113.1 --days 730 --cn my-vpn-server"
    echo "  $0 --ip 203.0.113.1 --output /opt/ssl"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--ip)
                VPS_IP="$2"
                shift 2
                ;;
            -d|--days)
                CERT_DAYS="$2"
                shift 2
                ;;
            -c|--cn)
                CN="$2"
                shift 2
                ;;
            -o|--output)
                CERT_DIR="$2"
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
    if [[ -z "$VPS_IP" ]]; then
        error "VPS IP address is required. Use -i or --ip option."
    fi

    # Validate IP address format
    if ! [[ $VPS_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        error "Invalid IP address format: $VPS_IP"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Create certificate directories
create_directories() {
    log "Creating certificate directories..."
    mkdir -p "$CERT_DIR/certs" "$CERT_DIR/private"
}

# Generate private key
generate_private_key() {
    log "Generating private key..."
    openssl genrsa -out "$CERT_DIR/private/$KEY_FILE" 2048
    chmod 600 "$CERT_DIR/private/$KEY_FILE"
}

# Generate certificate signing request
generate_csr() {
    log "Generating certificate signing request..."
    openssl req -new -key "$CERT_DIR/private/$KEY_FILE" -out "$CERT_DIR/certs/sstp.csr" -subj "/CN=$CN"
}

# Generate self-signed certificate
generate_certificate() {
    log "Generating self-signed certificate..."
    openssl req -new -x509 -days $CERT_DAYS -key "$CERT_DIR/private/$KEY_FILE" \
        -out "$CERT_DIR/certs/$CERT_FILE" \
        -subj "/CN=$CN" \
        -addext "subjectAltName=IP:$VPS_IP,DNS:$CN"
    
    chmod 644 "$CERT_DIR/certs/$CERT_FILE"
}

# Generate Let's Encrypt certificate (optional)
generate_letsencrypt_cert() {
    local domain="$1"
    
    if command -v certbot &> /dev/null; then
        log "Generating Let's Encrypt certificate for domain: $domain"
        
        # Stop accel-ppp if running
        systemctl stop accel-ppp 2>/dev/null || true
        
        # Generate certificate
        certbot certonly --standalone -d "$domain" --non-interactive --agree-tos --email admin@$domain
        
        # Copy certificates
        cp "/etc/letsencrypt/live/$domain/fullchain.pem" "$CERT_DIR/certs/$CERT_FILE"
        cp "/etc/letsencrypt/live/$domain/privkey.pem" "$CERT_DIR/private/$KEY_FILE"
        
        # Set permissions
        chmod 644 "$CERT_DIR/certs/$CERT_FILE"
        chmod 600 "$CERT_DIR/private/$KEY_FILE"
        
        # Start accel-ppp
        systemctl start accel-ppp
        
        log "Let's Encrypt certificate generated successfully"
    else
        warning "certbot not found. Install it to use Let's Encrypt certificates."
        warning "Run: apt install certbot (Ubuntu/Debian) or yum install certbot (CentOS/RHEL)"
    fi
}

# Create certificate renewal script
create_renewal_script() {
    log "Creating certificate renewal script..."
    
    cat > /usr/local/bin/sstp-renew-cert << EOF
#!/bin/bash
# SSTP Certificate Renewal Script

CERT_DIR="$CERT_DIR"
CERT_FILE="$CERT_FILE"
KEY_FILE="$KEY_FILE"

# Check if certificate expires within 30 days
if openssl x509 -in "\$CERT_DIR/certs/\$CERT_FILE" -checkend 2592000 -noout; then
    echo "Certificate is still valid for more than 30 days"
    exit 0
fi

echo "Certificate expires within 30 days, renewing..."

# Stop accel-ppp
systemctl stop accel-ppp

# Generate new certificate
openssl req -new -x509 -days $CERT_DAYS -key "\$CERT_DIR/private/\$KEY_FILE" \\
    -out "\$CERT_DIR/certs/\$CERT_FILE" \\
    -subj "/CN=$CN" \\
    -addext "subjectAltName=IP:$VPS_IP,DNS:$CN"

# Set permissions
chmod 644 "\$CERT_DIR/certs/\$CERT_FILE"
chmod 600 "\$CERT_DIR/private/\$KEY_FILE"

# Start accel-ppp
systemctl start accel-ppp

echo "Certificate renewed successfully"
EOF

    chmod +x /usr/local/bin/sstp-renew-cert
    
    # Add to crontab for automatic renewal
    (crontab -l 2>/dev/null; echo "0 2 * * 0 /usr/local/bin/sstp-renew-cert") | crontab -
}

# Display certificate information
display_cert_info() {
    log "Certificate generated successfully!"
    echo
    info "=== Certificate Information ==="
    echo "  Certificate file: $CERT_DIR/certs/$CERT_FILE"
    echo "  Private key file: $CERT_DIR/private/$KEY_FILE"
    echo "  Common Name: $CN"
    echo "  IP Address: $VPS_IP"
    echo "  Validity: $CERT_DAYS days"
    echo
    info "=== Certificate Details ==="
    openssl x509 -in "$CERT_DIR/certs/$CERT_FILE" -text -noout | grep -E "(Subject:|Not Before|Not After|Subject Alternative Name)"
    echo
    info "=== Management Commands ==="
    echo "  Renew certificate: sstp-renew-cert"
    echo "  View certificate: openssl x509 -in $CERT_DIR/certs/$CERT_FILE -text -noout"
    echo "  Check expiration: openssl x509 -in $CERT_DIR/certs/$CERT_FILE -noout -dates"
    echo
}

# Main function
main() {
    log "Starting SSL certificate generation..."
    
    parse_args "$@"
    check_root
    create_directories
    generate_private_key
    generate_certificate
    create_renewal_script
    display_cert_info
}

# Run main function
main "$@"


