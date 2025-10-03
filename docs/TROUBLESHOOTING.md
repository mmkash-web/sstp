# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with your SSTP VPN server setup.

## Quick Diagnostic Commands

### Check Service Status
```bash
# Check if accel-ppp is running
sudo systemctl status accel-ppp

# Check if service is enabled
sudo systemctl is-enabled accel-ppp

# Check service logs
sudo journalctl -u accel-ppp -f
```

### Check Network Connectivity
```bash
# Check if port 443 is listening
sudo netstat -tlnp | grep :443

# Test port connectivity from another machine
telnet YOUR_VPS_IP 443

# Check firewall rules
sudo iptables -L -n -v
```

### Check Configuration
```bash
# Verify configuration file syntax
sudo accel-ppp -t /etc/accel-ppp.conf

# Check certificate files
ls -la /etc/ssl/certs/sstp.crt
ls -la /etc/ssl/private/sstp.key

# Test certificate
openssl x509 -in /etc/ssl/certs/sstp.crt -text -noout
```

## Common Issues and Solutions

### 1. Service Won't Start

#### Symptoms
- `systemctl status accel-ppp` shows failed status
- Service fails to start on boot
- Error messages in logs

#### Diagnosis
```bash
# Check service status
sudo systemctl status accel-ppp

# Check detailed logs
sudo journalctl -u accel-ppp --no-pager

# Test configuration
sudo accel-ppp -t /etc/accel-ppp.conf
```

#### Solutions

**Configuration File Issues:**
```bash
# Check for syntax errors
sudo accel-ppp -t /etc/accel-ppp.conf

# Common fixes:
# - Check for missing brackets
# - Verify all required sections are present
# - Ensure proper indentation
```

**Certificate Issues:**
```bash
# Check certificate files exist
ls -la /etc/ssl/certs/sstp.crt /etc/ssl/private/sstp.key

# Fix permissions if needed
sudo chmod 644 /etc/ssl/certs/sstp.crt
sudo chmod 600 /etc/ssl/private/sstp.key

# Regenerate certificate if corrupted
sudo rm /etc/ssl/certs/sstp.crt /etc/ssl/private/sstp.key
sudo openssl req -new -x509 -days 365 -nodes \
  -out /etc/ssl/certs/sstp.crt \
  -keyout /etc/ssl/private/sstp.key \
  -subj "/CN=sstp-vpn"
```

**Port Already in Use:**
```bash
# Check what's using port 443
sudo netstat -tlnp | grep :443

# Kill process if needed (be careful!)
sudo kill -9 PID

# Or change port in configuration
sudo nano /etc/accel-ppp.conf
# Change: bind=0.0.0.0:443 to bind=0.0.0.0:8443
```

### 2. Connection Failed

#### Symptoms
- Clients can't connect to server
- Connection times out
- "Connection refused" errors

#### Diagnosis
```bash
# Check if service is listening
sudo netstat -tlnp | grep :443

# Test from server itself
telnet localhost 443

# Check firewall rules
sudo iptables -L -n -v | grep 443

# Check server logs
sudo tail -f /var/log/accel-ppp.log
```

#### Solutions

**Firewall Issues:**
```bash
# Allow port 443
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Save rules
sudo iptables-save > /etc/iptables/rules.v4

# Check if port is blocked by cloud provider
# (Check VPS provider's firewall settings)
```

**Service Not Listening:**
```bash
# Restart service
sudo systemctl restart accel-ppp

# Check configuration
sudo accel-ppp -t /etc/accel-ppp.conf

# Check logs for errors
sudo journalctl -u accel-ppp --no-pager
```

**Network Issues:**
```bash
# Check if port is open externally
nmap -p 443 YOUR_VPS_IP

# Test from different network
# (Use mobile hotspot or different internet connection)
```

### 3. Authentication Failed

#### Symptoms
- "Invalid username or password" errors
- Connection established but immediately disconnected
- Authentication timeout

#### Diagnosis
```bash
# Check chap-secrets section
grep -A 10 "\[chap-secrets\]" /etc/accel-ppp.conf

# Check server logs during connection attempt
sudo tail -f /var/log/accel-ppp.log

# Test with different credentials
```

#### Solutions

**User Not in Configuration:**
```bash
# Add user to chap-secrets
sudo nano /etc/accel-ppp.conf

# Add line in [chap-secrets] section:
# username  password  ip_address

# Restart service
sudo systemctl restart accel-ppp
```

**Wrong Password:**
```bash
# Update password in configuration
sudo nano /etc/accel-ppp.conf

# Find user line and update password
# username  new_password  ip_address

# Restart service
sudo systemctl restart accel-ppp
```

**IP Address Conflict:**
```bash
# Check if IP is already assigned
grep "10.10.10.2" /etc/accel-ppp.conf

# Assign different IP
# username  password  10.10.10.3

# Restart service
sudo systemctl restart accel-ppp
```

### 4. No Internet Access Through VPN

#### Symptoms
- VPN connects but no internet access
- Can't ping external websites
- DNS resolution fails

#### Diagnosis
```bash
# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward

# Check NAT rules
sudo iptables -t nat -L -n -v

# Check routing table
ip route show

# Test DNS resolution
nslookup google.com
```

#### Solutions

**IP Forwarding Not Enabled:**
```bash
# Enable IP forwarding
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Verify it's enabled
cat /proc/sys/net/ipv4/ip_forward
```

**Missing NAT Rules:**
```bash
# Get main interface
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

# Add NAT rule
sudo iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o $MAIN_INTERFACE -j MASQUERADE

# Save rules
sudo iptables-save > /etc/iptables/rules.v4
```

**DNS Issues:**
```bash
# Check DNS configuration in accel-ppp.conf
grep -A 5 "\[dns\]" /etc/accel-ppp.conf

# Update DNS servers if needed
sudo nano /etc/accel-ppp.conf
# [dns]
# dns1=1.1.1.1
# dns2=8.8.8.8

# Restart service
sudo systemctl restart accel-ppp
```

### 5. MikroTik Connection Issues

#### Symptoms
- MikroTik can't connect to SSTP server
- Connection established but unstable
- "No response from server" errors

#### Diagnosis
```bash
# Check server logs during MikroTik connection attempt
sudo tail -f /var/log/accel-ppp.log

# Check if MikroTik IP is assigned
grep "10.10.10.2" /etc/accel-ppp.conf

# Test from MikroTik
# /ping YOUR_VPS_IP
# /tool traceroute YOUR_VPS_IP
```

#### Solutions

**MikroTik Configuration Issues:**
```bash
# Check MikroTik SSTP client configuration
# /interface sstp-client print

# Verify connection settings
# /interface sstp-client set sstp-to-vps connect-to=YOUR_VPS_IP
# /interface sstp-client set sstp-to-vps user=VPN_USER
# /interface sstp-client set sstp-to-vps password=VPN_PASS

# Enable connection
# /interface sstp-client enable sstp-to-vps
```

**Server-Side Issues:**
```bash
# Check if user exists in configuration
grep "VPN_USER" /etc/accel-ppp.conf

# Check IP assignment
grep "10.10.10.2" /etc/accel-ppp.conf

# Restart service
sudo systemctl restart accel-ppp
```

### 6. Certificate Issues

#### Symptoms
- "Certificate verification failed" errors
- "Invalid certificate" warnings
- Connection refused due to certificate issues

#### Diagnosis
```bash
# Check certificate file
ls -la /etc/ssl/certs/sstp.crt

# Test certificate
openssl x509 -in /etc/ssl/certs/sstp.crt -text -noout

# Check certificate expiration
openssl x509 -in /etc/ssl/certs/sstp.crt -noout -dates
```

#### Solutions

**Certificate Not Found:**
```bash
# Regenerate certificate
sudo openssl req -new -x509 -days 365 -nodes \
  -out /etc/ssl/certs/sstp.crt \
  -keyout /etc/ssl/private/sstp.key \
  -subj "/CN=sstp-vpn" \
  -addext "subjectAltName=IP:YOUR_VPS_IP"

# Set permissions
sudo chmod 644 /etc/ssl/certs/sstp.crt
sudo chmod 600 /etc/ssl/private/sstp.key

# Restart service
sudo systemctl restart accel-ppp
```

**Certificate Expired:**
```bash
# Check expiration date
openssl x509 -in /etc/ssl/certs/sstp.crt -noout -dates

# Regenerate with longer validity
sudo openssl req -new -x509 -days 730 -nodes \
  -out /etc/ssl/certs/sstp.crt \
  -keyout /etc/ssl/private/sstp.key \
  -subj "/CN=sstp-vpn" \
  -addext "subjectAltName=IP:YOUR_VPS_IP"

# Restart service
sudo systemctl restart accel-ppp
```

**Client Certificate Verification:**
- For self-signed certificates, disable verification on client
- For production, use valid certificates from CA

## Advanced Troubleshooting

### Enable Debug Logging

```bash
# Edit configuration to enable debug
sudo nano /etc/accel-ppp.conf

# Add or modify:
[core]
log-error=/var/log/accel-ppp.log
log-debug=/var/log/accel-ppp-debug.log
thread-count=2

# Restart service
sudo systemctl restart accel-ppp

# Monitor debug logs
sudo tail -f /var/log/accel-ppp-debug.log
```

### Network Packet Capture

```bash
# Capture packets on port 443
sudo tcpdump -i any port 443 -w sstp-capture.pcap

# Analyze captured packets
tcpdump -r sstp-capture.pcap -n
```

### Performance Monitoring

```bash
# Monitor active connections
sudo netstat -an | grep :443 | wc -l

# Monitor system resources
top
htop

# Check memory usage
free -h

# Check disk usage
df -h
```

## Log Analysis

### Common Log Messages

**Successful Connection:**
```
[INFO] SSTP connection established
[INFO] User 'username' authenticated
[INFO] PPP session started
```

**Authentication Failed:**
```
[ERROR] Authentication failed for user 'username'
[ERROR] Invalid credentials
[ERROR] User not found
```

**Connection Issues:**
```
[ERROR] Connection timeout
[ERROR] SSL handshake failed
[ERROR] Certificate verification failed
```

### Log Rotation

```bash
# Configure log rotation
sudo nano /etc/logrotate.d/accel-ppp

# Add:
/var/log/accel-ppp*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload accel-ppp
    endscript
}
```

## Recovery Procedures

### Complete Service Reset

```bash
# Stop service
sudo systemctl stop accel-ppp

# Backup current configuration
sudo cp /etc/accel-ppp.conf /etc/accel-ppp.conf.backup

# Restore default configuration
sudo cp /etc/accel-ppp.conf.backup /etc/accel-ppp.conf

# Regenerate certificates
sudo rm /etc/ssl/certs/sstp.crt /etc/ssl/private/sstp.key
sudo openssl req -new -x509 -days 365 -nodes \
  -out /etc/ssl/certs/sstp.crt \
  -keyout /etc/ssl/private/sstp.key \
  -subj "/CN=sstp-vpn"

# Reset firewall rules
sudo iptables -F
sudo iptables -t nat -F
# Reconfigure firewall rules

# Start service
sudo systemctl start accel-ppp
```

### Emergency Access

If you lose access to the server:

1. **Use VPS Console:**
   - Access through VPS provider's web console
   - Check system status and logs

2. **Check Network Configuration:**
   - Verify firewall rules
   - Check if service is running
   - Test network connectivity

3. **Restart Services:**
   - Restart accel-ppp service
   - Restart networking if needed
   - Check system logs for errors

## Getting Help

### Information to Collect

When seeking help, collect this information:

1. **System Information:**
   ```bash
   uname -a
   cat /etc/os-release
   ```

2. **Service Status:**
   ```bash
   sudo systemctl status accel-ppp
   sudo journalctl -u accel-ppp --no-pager
   ```

3. **Configuration:**
   ```bash
   sudo cat /etc/accel-ppp.conf
   ```

4. **Network Status:**
   ```bash
   sudo netstat -tlnp | grep :443
   sudo iptables -L -n -v
   ```

5. **Error Messages:**
   - Copy exact error messages
   - Include timestamps
   - Note what you were doing when error occurred

### Support Resources

- **GitHub Issues:** Create an issue with collected information
- **Community Forums:** Ask questions with detailed information
- **Documentation:** Check this guide and other documentation
- **Logs:** Always check logs first before asking for help

This troubleshooting guide should help you resolve most common issues with your SSTP VPN server. If you encounter issues not covered here, collect the relevant information and seek help from the community or support channels.
