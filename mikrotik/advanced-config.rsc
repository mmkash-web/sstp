# Advanced MikroTik SSTP Configuration
# This file contains advanced configuration options for SSTP client

# Create SSTP client with advanced options
/interface sstp-client add \
    name=sstp-to-vps \
    connect-to=VPS_PUBLIC_IP \
    user=VPN_USER \
    password=VPN_PASS \
    profile=default-encryption \
    certificate="" \
    verify-server-certificate=no \
    disabled=no \
    add-default-route=yes \
    use-peer-dns=yes \
    keepalive-timeout=30 \
    max-mru=1400 \
    max-mtu=1400

# Create custom PPP profile for better performance
/ppp profile add \
    name=sstp-profile \
    use-encryption=yes \
    use-compression=no \
    use-vj-compression=no \
    use-mpls=no \
    only-one=no \
    change-tcp-mss=yes \
    use-upnp=no \
    address-list="" \
    on-up="" \
    on-down=""

# Update SSTP client to use custom profile
/interface sstp-client set sstp-to-vps profile=sstp-profile

# Configure routing for VPN traffic
# Add route for VPN subnet
/ip route add \
    dst-address=10.10.10.0/24 \
    gateway=sstp-to-vps \
    distance=1 \
    comment="VPN subnet route"

# Optional: Add route for specific networks through VPN
# /ip route add \
#     dst-address=192.168.100.0/24 \
#     gateway=sstp-to-vps \
#     distance=1 \
#     comment="Route specific network through VPN"

# Configure firewall rules for VPN traffic
# Allow established connections
/ip firewall filter add \
    chain=forward \
    connection-state=established,related \
    action=accept \
    comment="Allow established connections"

# Allow VPN traffic
/ip firewall filter add \
    chain=forward \
    in-interface=sstp-to-vps \
    action=accept \
    comment="Allow incoming VPN traffic"

/ip firewall filter add \
    chain=forward \
    out-interface=sstp-to-vps \
    action=accept \
    comment="Allow outgoing VPN traffic"

# Configure NAT for VPN clients (if needed)
# /ip firewall nat add \
#     chain=srcnat \
#     out-interface=sstp-to-vps \
#     action=masquerade \
#     comment="NAT for VPN clients"

# Configure connection monitoring
# Create a script to monitor SSTP connection
/system script add \
    name=sstp-monitor \
    source={
        :if ([/interface sstp-client get sstp-to-vps running] = false) do={
            :log info "SSTP connection lost, attempting to reconnect"
            /interface sstp-client connect sstp-to-vps
        }
    }

# Schedule the monitoring script to run every minute
/system scheduler add \
    name=sstp-monitor-schedule \
    interval=1m \
    on-event=sstp-monitor \
    comment="Monitor SSTP connection"

# Configure logging for SSTP
/system logging add \
    topics=ppp,info \
    action=memory \
    comment="SSTP connection logging"

# Enable interface and check status
/interface sstp-client enable sstp-to-vps

# Display connection information
:log info "SSTP client configured and enabled"
/interface sstp-client print
/ppp active print


