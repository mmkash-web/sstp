# SSTP VPN Server for MikroTik Access

A complete SSTP VPN solution that allows secure access to MikroTik routers through a VPS. This project provides easy deployment scripts and configuration files for setting up an SSTP server using accel-ppp.

## 🔹 Topology

- **VPS (Linux, public IP)**: Runs SSTP server
- **MikroTik Router**: Runs SSTP client, establishes outbound connection to VPS
- **VPN Network**: Once tunnel is up, MikroTik gets private VPN IP (e.g., 10.10.10.2)
- **Access Methods**:
  - Connect from laptop/PC via SSTP to VPS → access MikroTik at 10.10.10.2 (Recommended)
  - OR port-forward API traffic from VPS → MikroTik's VPN IP (Optional)

## 🚀 Quick Start

### Option 1: Automated Installation (Recommended)

```bash
# Clone the repository
git clone https://github.com/yourusername/sstp-vpn-server.git
cd sstp-vpn-server

# Make installation script executable
chmod +x install.sh

# Run installation (will prompt for configuration)
sudo ./install.sh
```

### Option 2: Docker Deployment

```bash
# Build and run with Docker
docker-compose up -d
```

### Option 3: Manual Installation

Follow the step-by-step guide in [MANUAL_INSTALL.md](docs/MANUAL_INSTALL.md)

## 📁 Project Structure

```
sstp-vpn-server/
├── install.sh                 # Main installation script
├── config/
│   ├── accel-ppp.conf        # accel-ppp configuration
│   └── sstp.conf             # SSTP-specific settings
├── scripts/
│   ├── generate-cert.sh      # SSL certificate generation
│   ├── setup-firewall.sh     # Firewall configuration
│   └── add-user.sh           # User management script
├── mikrotik/
│   ├── sstp-client.rsc       # MikroTik SSTP client config
│   └── api-port-forward.rsc  # API port forwarding config
├── clients/
│   ├── windows/              # Windows SSTP client examples
│   ├── linux/                # Linux SSTP client examples
│   └── mobile/               # Mobile client examples
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
├── docs/
│   ├── MANUAL_INSTALL.md
│   ├── TROUBLESHOOTING.md
│   └── API_ACCESS.md
└── README.md
```

## ⚙️ Configuration

### VPS Configuration

The installation script will prompt you for:
- VPN username and password
- VPS public IP address
- VPN subnet (default: 10.10.10.0/24)
- DNS servers

### MikroTik Configuration

1. Import the provided configuration:
   ```bash
   /import file=sstp-client.rsc
   ```

2. Update the connection details:
   - Replace `VPS_PUBLIC_IP` with your VPS IP
   - Replace `VPN_USER` and `VPN_PASS` with your credentials

## 🔐 Security Features

- TLS encryption for all connections
- Self-signed or Let's Encrypt certificates
- IP forwarding and NAT configuration
- Firewall rules for API access
- User authentication via CHAP

## 📖 Documentation

- [Manual Installation Guide](docs/MANUAL_INSTALL.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- [API Access Methods](docs/API_ACCESS.md)

## 🛠️ Management Scripts

- `scripts/add-user.sh`: Add new VPN users
- `scripts/setup-firewall.sh`: Configure firewall rules
- `scripts/generate-cert.sh`: Generate SSL certificates

## 🔧 Troubleshooting

Common issues and solutions are documented in [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting pull requests.

## 📞 Support

For support and questions:
- Create an issue on GitHub
- Check the troubleshooting guide
- Review the documentation

---

**Note**: This project is designed for educational and legitimate network management purposes. Ensure you have proper authorization before accessing any network infrastructure.


