# MikroTik API Port Forwarding Configuration
# This configuration allows API access through the SSTP tunnel

# Enable API service (if not already enabled)
/ip service set api disabled=no

# Set API port (default is 8728)
/ip service set api port=8728

# Allow API access from VPN subnet
/ip firewall filter add \
    chain=input \
    protocol=tcp \
    dst-port=8728 \
    src-address=10.10.10.0/24 \
    action=accept \
    comment="Allow API access from VPN"

# Optional: Allow API access from specific admin IP
# /ip firewall filter add \
#     chain=input \
#     protocol=tcp \
#     dst-port=8728 \
#     src-address=ADMIN_IP/32 \
#     action=accept \
#     comment="Allow API access from admin IP"

# Optional: Disable API access from other sources
# /ip firewall filter add \
#     chain=input \
#     protocol=tcp \
#     dst-port=8728 \
#     action=drop \
#     comment="Drop other API access"

# Check API service status
/ip service print
/ip firewall filter print where comment~"API"


