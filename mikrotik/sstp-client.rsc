# MikroTik SSTP Client Configuration
# Replace the placeholders with your actual values:
# - VPS_PUBLIC_IP: Your VPS public IP address
# - VPN_USER: VPN username
# - VPN_PASS: VPN password

# Create SSTP client interface
/interface sstp-client add \
    name=sstp-to-vps \
    connect-to=VPS_PUBLIC_IP \
    user=VPN_USER \
    password=VPN_PASS \
    profile=default-encryption \
    certificate="" \
    verify-server-certificate=no \
    disabled=no

# Optional: Set static IP for MikroTik (if not using DHCP from server)
# /ip address add address=10.10.10.2/24 interface=sstp-to-vps

# Optional: Add route for VPN traffic
# /ip route add dst-address=10.10.10.0/24 gateway=sstp-to-vps

# Optional: Enable interface
/interface sstp-client enable sstp-to-vps

# Check connection status
/interface sstp-client print
/ppp active print


