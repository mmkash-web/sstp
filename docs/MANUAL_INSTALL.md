# Manual Installation Guide

This guide provides step-by-step instructions for manually installing and configuring the SSTP VPN server without using the automated installation script.

## Prerequisites

- Ubuntu/Debian or CentOS/RHEL server
- Root or sudo access
- Public IP address
- Basic knowledge of Linux command line

## Step 1: System Preparation

### Update System Packages

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt upgrade -y
```

**CentOS/RHEL:**
```bash
sudo yum update -y
```

**Fedora:**
```bash
sudo dnf update -y
```

### Install Required Packages

**Ubuntu/Debian:**
```bash
sudo apt install -y accel-ppp openssl iptables-persistent
```

**CentOS/RHEL:**
```bash
sudo yum install -y accel-ppp openssl iptables-services
```

**Fedora:**
```bash
sudo dnf install -y accel-ppp openssl iptables-services
```

## Step 2: Generate SSL Certificate

### Create Certificate Directory
```bash
sudo mkdir -p /etc/ssl/certs /etc/ssl/private
```

### Generate Self-Signed Certificate
```bash
sudo openssl req -new -x509 -days 365 -nodes \
  -out /etc/ssl/certs/sstp.crt \
  -keyout /etc/ssl/private/sstp.key \
  -subj "/CN=sstp-vpn" \
  -addext "subjectAltName=IP:YOUR_VPS_IP"
```

Replace `YOUR_VPS_IP` with your actual VPS public IP address.

### Set Proper Permissions
```bash
sudo chmod 600 /etc/ssl/private/sstp.key
sudo chmod 644 /etc/ssl/certs/sstp.crt
```

## Step 3: Configure accel-ppp

### Create Configuration File
```bash
sudo nano /etc/accel-ppp.conf
```

### Add Configuration Content
```ini
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
VPN_USER  VPN_PASS  10.10.10.2

[ip-pool]
gw-ip-address=10.10.10.1
10.10.10.2-10.10.10.200

[dns]
dns1=1.1.1.1
dns2=8.8.8.8
```

### Replace Placeholders
- `VPN_USER`: Your desired VPN username
- `VPN_PASS`: Your desired VPN password
- `YOUR_VPS_IP`: Your VPS public IP address

## Step 4: Configure IP Forwarding

### Enable IP Forwarding
```bash
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Get Main Network Interface
```bash
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
echo "Main interface: $MAIN_INTERFACE"
```

### Configure NAT
```bash
sudo iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o $MAIN_INTERFACE -j MASQUERADE
```

## Step 5: Configure Firewall

### Basic Firewall Rules
```bash
# Allow SSH
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow SSTP (port 443)
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow established connections
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow VPN traffic forwarding
sudo iptables -A FORWARD -s 10.10.10.0/24 -j ACCEPT
sudo iptables -A FORWARD -d 10.10.10.0/24 -j ACCEPT

# Drop other incoming connections
sudo iptables -A INPUT -j DROP
```

### Save Firewall Rules

**Ubuntu/Debian:**
```bash
sudo iptables-save > /etc/iptables/rules.v4
```

**CentOS/RHEL:**
```bash
sudo service iptables save
```

## Step 6: Start and Enable Service

### Enable and Start accel-ppp
```bash
sudo systemctl enable accel-ppp
sudo systemctl start accel-ppp
```

### Check Service Status
```bash
sudo systemctl status accel-ppp
```

### Check Logs
```bash
sudo tail -f /var/log/accel-ppp.log
```

## Step 7: Test Configuration

### Check if Service is Listening
```bash
sudo netstat -tlnp | grep :443
```

### Test from Another Machine
```bash
# Test port connectivity
telnet YOUR_VPS_IP 443

# Test with SSTP client
# Use Windows built-in SSTP client or Linux sstp-client
```

## Step 8: Configure MikroTik Router

### Connect to MikroTik
Use Winbox or SSH to connect to your MikroTik router.

### Add SSTP Client
```bash
/interface sstp-client add \
    name=sstp-to-vps \
    connect-to=YOUR_VPS_IP \
    user=VPN_USER \
    password=VPN_PASS \
    profile=default-encryption \
    certificate="" \
    verify-server-certificate=no \
    disabled=no
```

### Enable Connection
```bash
/interface sstp-client enable sstp-to-vps
```

### Check Connection Status
```bash
/interface sstp-client print
/ppp active print
```

## Step 9: Add Additional Users

### Add User to Configuration
Edit `/etc/accel-ppp.conf` and add new user to `[chap-secrets]` section:
```ini
[chap-secrets]
# user   password   ip
VPN_USER  VPN_PASS  10.10.10.2
NEW_USER  NEW_PASS  10.10.10.3
```

### Restart Service
```bash
sudo systemctl restart accel-ppp
```

## Step 10: Optional API Port Forwarding

### Forward API Port to MikroTik
```bash
# Forward port 8728 to MikroTik's VPN IP
sudo iptables -t nat -A PREROUTING -p tcp --dport 8728 -j DNAT --to-destination 10.10.10.2:8728
sudo iptables -A FORWARD -p tcp -d 10.10.10.2 --dport 8728 -j ACCEPT
```

### Restrict to Admin IP (Recommended)
```bash
# Replace ADMIN_IP with your actual IP
sudo iptables -t nat -A PREROUTING -p tcp -s ADMIN_IP/32 --dport 8728 -j DNAT --to-destination 10.10.10.2:8728
```

## Troubleshooting

### Common Issues

1. **Service Won't Start**
   - Check configuration file syntax
   - Verify certificate files exist and have correct permissions
   - Check logs: `sudo journalctl -u accel-ppp`

2. **Connection Failed**
   - Verify port 443 is open
   - Check firewall rules
   - Test with telnet: `telnet YOUR_VPS_IP 443`

3. **Authentication Failed**
   - Check username/password in configuration
   - Verify user exists in chap-secrets section
   - Check server logs

4. **No Internet Access**
   - Verify IP forwarding is enabled
   - Check NAT rules
   - Verify DNS settings

### Useful Commands

```bash
# Check service status
sudo systemctl status accel-ppp

# View logs
sudo tail -f /var/log/accel-ppp.log

# Check listening ports
sudo netstat -tlnp | grep :443

# Test connectivity
telnet YOUR_VPS_IP 443

# Check firewall rules
sudo iptables -L -n -v

# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward
```

## Security Considerations

1. **Use Strong Passwords**
   - Choose complex passwords for VPN users
   - Change default passwords

2. **Certificate Security**
   - Use valid certificates for production
   - Consider Let's Encrypt for free certificates
   - Keep private keys secure

3. **Firewall Rules**
   - Restrict API access to admin IPs
   - Use rate limiting for connections
   - Monitor connection logs

4. **Regular Updates**
   - Keep system packages updated
   - Monitor security advisories
   - Update certificates before expiration

## Maintenance

### Regular Tasks

1. **Monitor Logs**
   - Check connection logs regularly
   - Monitor for failed authentication attempts
   - Review system logs

2. **Update Certificates**
   - Renew certificates before expiration
   - Update configuration if needed
   - Restart service after updates

3. **User Management**
   - Add/remove users as needed
   - Change passwords regularly
   - Monitor active connections

### Backup Configuration

```bash
# Backup configuration
sudo cp /etc/accel-ppp.conf /etc/accel-ppp.conf.backup

# Backup certificates
sudo cp -r /etc/ssl /etc/ssl.backup

# Backup firewall rules
sudo iptables-save > /etc/iptables/rules.v4.backup
```

This manual installation guide provides a complete setup process for your SSTP VPN server. Follow each step carefully and test the configuration before relying on it for production use.


