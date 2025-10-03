# Docker Deployment for SSTP VPN Server

This directory contains Docker configuration files for deploying the SSTP VPN server using Docker and Docker Compose.

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- VPS with public IP address
- Basic knowledge of Docker

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/sstp-vpn-server.git
cd sstp-vpn-server
```

### 2. Configure Environment Variables

```bash
# Copy the example environment file
cp docker/env.example docker/.env

# Edit the environment file
nano docker/.env
```

Update the following variables:
- `VPN_USER`: Your desired VPN username
- `VPN_PASS`: Your desired VPN password
- `VPS_PUBLIC_IP`: Your VPS public IP address

### 3. Deploy with Docker Compose

```bash
# Navigate to docker directory
cd docker

# Start the services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f sstp-vpn
```

### 4. Verify Deployment

```bash
# Check if port 443 is listening
netstat -tlnp | grep :443

# Test connectivity
telnet YOUR_VPS_IP 443

# Check container logs
docker-compose logs sstp-vpn
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `VPN_USER` | Yes | - | VPN username |
| `VPN_PASS` | Yes | - | VPN password |
| `VPS_PUBLIC_IP` | Yes | - | VPS public IP address |
| `VPN_SUBNET` | No | `10.10.10.0/24` | VPN subnet |
| `DNS1` | No | `1.1.1.1` | Primary DNS server |
| `DNS2` | No | `8.8.8.8` | Secondary DNS server |
| `ADDITIONAL_USERS` | No | - | Additional users (comma-separated) |
| `API_PORT_FORWARDING` | No | `false` | Enable API port forwarding |
| `API_PORT` | No | `8728` | API port for forwarding |
| `ADMIN_IP` | No | - | Admin IP for API access |

### Additional Users

To add multiple users, use the `ADDITIONAL_USERS` environment variable:

```bash
ADDITIONAL_USERS=user1:pass1:10.10.10.3,user2:pass2:10.10.10.4
```

Format: `username:password:ip_address`

## Management Commands

### Basic Operations

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart services
docker-compose restart

# View logs
docker-compose logs -f sstp-vpn

# Check status
docker-compose ps
```

### Container Management

```bash
# Access container shell
docker-compose exec sstp-vpn bash

# View configuration
docker-compose exec sstp-vpn cat /etc/accel-ppp.conf

# Check certificates
docker-compose exec sstp-vpn openssl x509 -in /etc/ssl/certs/sstp.crt -text -noout

# View logs
docker-compose exec sstp-vpn tail -f /var/log/accel-ppp.log
```

### Adding Users

```bash
# Add user via container
docker-compose exec sstp-vpn /usr/local/bin/add-user.sh username password

# Or edit configuration directly
docker-compose exec sstp-vpn nano /etc/accel-ppp.conf
docker-compose restart sstp-vpn
```

## Security Considerations

### 1. Environment Variables

- Never commit `.env` files to version control
- Use strong passwords
- Rotate credentials regularly

### 2. Network Security

- Ensure port 443 is properly configured
- Use firewall rules to restrict access
- Monitor connection logs

### 3. Container Security

- Run containers as non-root user when possible
- Keep base images updated
- Use specific image tags instead of `latest`

## Troubleshooting

### Common Issues

1. **Container Won't Start**
   ```bash
   # Check logs
   docker-compose logs sstp-vpn
   
   # Check environment variables
   docker-compose config
   ```

2. **Port Already in Use**
   ```bash
   # Check what's using port 443
   sudo netstat -tlnp | grep :443
   
   # Kill process if needed
   sudo kill -9 PID
   ```

3. **Certificate Issues**
   ```bash
   # Check certificate
   docker-compose exec sstp-vpn openssl x509 -in /etc/ssl/certs/sstp.crt -text -noout
   
   # Regenerate certificate
   docker-compose exec sstp-vpn /usr/local/bin/generate-cert.sh --ip YOUR_VPS_IP
   ```

### Debug Mode

```bash
# Run in debug mode
docker-compose up --build

# Access container for debugging
docker-compose exec sstp-vpn bash
```

## Production Deployment

### 1. Use Production Environment

```bash
# Create production environment file
cp docker/env.example docker/.env.prod

# Deploy with production environment
docker-compose --env-file .env.prod up -d
```

### 2. Enable Logging

```bash
# Configure log rotation
docker-compose exec sstp-vpn sh -c "
  echo '/var/log/accel-ppp*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
  }' > /etc/logrotate.d/accel-ppp
"
```

### 3. Monitor Resources

```bash
# Check resource usage
docker stats sstp-vpn-server

# Monitor logs
docker-compose logs -f sstp-vpn | grep -E "(ERROR|WARN|connected|disconnected)"
```

## Backup and Recovery

### Backup Configuration

```bash
# Backup configuration
docker-compose exec sstp-vpn tar -czf /tmp/sstp-backup.tar.gz /etc/accel-ppp.conf /etc/ssl

# Copy backup to host
docker cp sstp-vpn-server:/tmp/sstp-backup.tar.gz ./sstp-backup.tar.gz
```

### Restore Configuration

```bash
# Copy backup to container
docker cp sstp-backup.tar.gz sstp-vpn-server:/tmp/

# Extract backup
docker-compose exec sstp-vpn tar -xzf /tmp/sstp-backup.tar.gz -C /

# Restart service
docker-compose restart sstp-vpn
```

## Advanced Configuration

### Custom Configuration

To use a custom configuration file:

1. Create your custom configuration
2. Mount it as a volume in `docker-compose.yml`
3. Update the startup script to use your configuration

### Multiple Instances

To run multiple SSTP servers:

1. Create separate environment files
2. Use different port mappings
3. Use different container names

### Integration with Other Services

The SSTP server can be integrated with:
- Load balancers
- Monitoring systems
- Log aggregation services
- Backup systems

## Support

For issues and questions:
- Check the troubleshooting guide
- Review Docker logs
- Check the main project documentation
- Create an issue on GitHub

## License

This Docker configuration is part of the SSTP VPN Server project and follows the same license terms.
