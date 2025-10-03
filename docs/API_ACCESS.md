# API Access Guide

This guide explains how to access your MikroTik router's API through the SSTP VPN tunnel.

## Overview

Once your MikroTik router is connected to the SSTP VPN server, you can access its API in several ways:

1. **Direct VPN Access** (Recommended): Connect your computer to the VPN and access MikroTik directly
2. **Port Forwarding**: Forward API traffic from VPS to MikroTik through the tunnel
3. **Hybrid Approach**: Use both methods for different use cases

## Method 1: Direct VPN Access (Recommended)

### Step 1: Connect Your Computer to VPN

**Windows:**
1. Open Settings > Network & Internet > VPN
2. Add VPN connection
3. Select SSTP as VPN type
4. Enter server details and credentials
5. Connect to VPN

**Linux:**
```bash
# Install sstp-client
sudo apt install sstp-client

# Connect to VPN
sudo sstpc YOUR_VPS_IP:443 --user YOUR_USERNAME --password YOUR_PASSWORD
```

**macOS:**
1. System Preferences > Network
2. Add VPN connection
3. Select SSTP as interface
4. Enter server details and credentials

### Step 2: Access MikroTik API

Once connected to VPN, your computer will have a VPN IP (e.g., 10.10.10.3), and you can access MikroTik at its VPN IP (10.10.10.2).

**Using Winbox:**
- Connect to: 10.10.10.2
- Username: admin (or your MikroTik username)
- Password: your MikroTik password

**Using SSH:**
```bash
ssh admin@10.10.10.2
```

**Using API Scripts:**
```python
# Python example
import socket

def mikrotik_api_call(host, port, username, password, command):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((host, port))
    
    # Send login command
    s.send(f"/login\n=name={username}\n=password={password}\n".encode())
    
    # Send API command
    s.send(f"{command}\n".encode())
    
    # Receive response
    response = s.recv(4096).decode()
    s.close()
    return response

# Usage
result = mikrotik_api_call("10.10.10.2", 8728, "admin", "password", "/ip/address/print")
print(result)
```

## Method 2: Port Forwarding

### Step 1: Configure Port Forwarding on VPS

```bash
# Forward port 8728 to MikroTik's VPN IP
sudo iptables -t nat -A PREROUTING -p tcp --dport 8728 -j DNAT --to-destination 10.10.10.2:8728
sudo iptables -A FORWARD -p tcp -d 10.10.10.2 --dport 8728 -j ACCEPT

# Save rules
sudo iptables-save > /etc/iptables/rules.v4
```

### Step 2: Restrict Access to Admin IP (Recommended)

```bash
# Replace ADMIN_IP with your actual IP
sudo iptables -t nat -A PREROUTING -p tcp -s ADMIN_IP/32 --dport 8728 -j DNAT --to-destination 10.10.10.2:8728
sudo iptables -A FORWARD -p tcp -s ADMIN_IP -d 10.10.10.2 --dport 8728 -j ACCEPT

# Save rules
sudo iptables-save > /etc/iptables/rules.v4
```

### Step 3: Access MikroTik API

Now you can access MikroTik API through your VPS:

**Using Winbox:**
- Connect to: YOUR_VPS_IP:8728
- Username: admin (or your MikroTik username)
- Password: your MikroTik password

**Using SSH:**
```bash
ssh admin@YOUR_VPS_IP -p 8728
```

## Method 3: Hybrid Approach

### Use Both Methods

1. **Direct VPN Access**: For regular management and monitoring
2. **Port Forwarding**: For automated scripts and external access

### Configuration Example

```bash
# Allow direct VPN access (no port forwarding needed)
# Allow port forwarding for specific admin IP
sudo iptables -t nat -A PREROUTING -p tcp -s ADMIN_IP/32 --dport 8728 -j DNAT --to-destination 10.10.10.2:8728
sudo iptables -A FORWARD -p tcp -s ADMIN_IP -d 10.10.10.2 --dport 8728 -j ACCEPT
```

## Security Considerations

### 1. Authentication

**Strong Passwords:**
- Use complex passwords for MikroTik admin account
- Change default passwords
- Consider using certificate-based authentication

**API Access Control:**
```bash
# Limit API access to specific IPs
/ip firewall filter add \
    chain=input \
    protocol=tcp \
    dst-port=8728 \
    src-address=10.10.10.0/24 \
    action=accept \
    comment="Allow API access from VPN"

/ip firewall filter add \
    chain=input \
    protocol=tcp \
    dst-port=8728 \
    action=drop \
    comment="Drop other API access"
```

### 2. Encryption

**Use Encrypted Connections:**
- Always use HTTPS for web-based management
- Use SSH for command-line access
- Consider using VPN for all management traffic

### 3. Monitoring

**Log API Access:**
```bash
# Enable API logging on MikroTik
/system logging add \
    topics=info \
    action=memory \
    comment="API access logging"
```

**Monitor Connections:**
```bash
# Check active API connections
/ip service print
/ip firewall filter print where comment~"API"
```

## API Usage Examples

### Python Scripts

```python
import socket
import ssl

class MikroTikAPI:
    def __init__(self, host, port, username, password):
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.socket = None
    
    def connect(self):
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.connect((self.host, self.port))
        
        # Login
        self.send_command("/login")
        self.send_command(f"=name={self.username}")
        self.send_command(f"=password={self.password}")
    
    def send_command(self, command):
        self.socket.send(f"{command}\n".encode())
        return self.socket.recv(4096).decode()
    
    def get_ip_addresses(self):
        return self.send_command("/ip/address/print")
    
    def get_interfaces(self):
        return self.send_command("/interface/print")
    
    def disconnect(self):
        if self.socket:
            self.socket.close()

# Usage
api = MikroTikAPI("10.10.10.2", 8728, "admin", "password")
api.connect()
print(api.get_ip_addresses())
api.disconnect()
```

### Bash Scripts

```bash
#!/bin/bash
# MikroTik API script

MIKROTIK_IP="10.10.10.2"
MIKROTIK_PORT="8728"
USERNAME="admin"
PASSWORD="password"

# Function to send API command
send_api_command() {
    local command="$1"
    echo -e "$command\n" | nc $MIKROTIK_IP $MIKROTIK_PORT
}

# Get system information
get_system_info() {
    send_api_command "/system/identity/print"
    send_api_command "/system/resource/print"
}

# Get interface status
get_interface_status() {
    send_api_command "/interface/print"
}

# Usage
get_system_info
get_interface_status
```

### PowerShell Scripts

```powershell
# MikroTik API PowerShell script

$MikroTikIP = "10.10.10.2"
$MikroTikPort = 8728
$Username = "admin"
$Password = "password"

function Send-MikroTikCommand {
    param([string]$Command)
    
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect($MikroTikIP, $MikroTikPort)
    
    $stream = $tcpClient.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $reader = New-Object System.IO.StreamReader($stream)
    
    # Login
    $writer.WriteLine("/login")
    $writer.WriteLine("=name=$Username")
    $writer.WriteLine("=password=$Password")
    $writer.Flush()
    
    # Send command
    $writer.WriteLine($Command)
    $writer.Flush()
    
    # Read response
    $response = $reader.ReadToEnd()
    
    $writer.Close()
    $reader.Close()
    $tcpClient.Close()
    
    return $response
}

# Usage
$result = Send-MikroTikCommand "/ip/address/print"
Write-Output $result
```

## Troubleshooting API Access

### Common Issues

1. **Connection Refused**
   - Check if MikroTik is connected to VPN
   - Verify API service is enabled
   - Check firewall rules

2. **Authentication Failed**
   - Verify username and password
   - Check if user has API access
   - Ensure user is not locked out

3. **Timeout Issues**
   - Check network connectivity
   - Verify port forwarding rules
   - Check if MikroTik is responding

### Debug Steps

```bash
# Test connectivity
ping 10.10.10.2

# Test port connectivity
telnet 10.10.10.2 8728

# Check MikroTik API service
# /ip service print
# /ip service set api disabled=no

# Check firewall rules
# /ip firewall filter print where comment~"API"
```

## Best Practices

### 1. Security

- Use strong authentication
- Limit API access to specific IPs
- Monitor API access logs
- Use encrypted connections when possible

### 2. Performance

- Limit concurrent API connections
- Use connection pooling
- Implement proper error handling
- Monitor resource usage

### 3. Reliability

- Implement retry logic
- Use health checks
- Monitor connection status
- Have fallback access methods

### 4. Maintenance

- Regular security updates
- Monitor logs for issues
- Test API access regularly
- Keep documentation updated

This guide provides comprehensive information for accessing your MikroTik router's API through the SSTP VPN tunnel. Choose the method that best fits your needs and security requirements.
