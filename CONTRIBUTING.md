# Contributing to SSTP VPN Server

Thank you for your interest in contributing to the SSTP VPN Server project! This document provides guidelines and information for contributors.

## How to Contribute

### Reporting Issues

Before creating an issue, please:

1. Check if the issue already exists
2. Search the documentation for solutions
3. Try the troubleshooting guide
4. Check if it's a configuration issue

When creating an issue, please include:

- **OS and version** (Ubuntu 22.04, CentOS 8, etc.)
- **Installation method** (script, manual, Docker)
- **Error messages** (exact text)
- **Steps to reproduce**
- **Expected vs actual behavior**
- **Logs** (relevant log entries)

### Suggesting Enhancements

We welcome suggestions for:

- New features
- Performance improvements
- Security enhancements
- Documentation improvements
- User experience improvements

Please use the issue tracker with the "enhancement" label.

### Code Contributions

#### Getting Started

1. **Fork the repository**
2. **Clone your fork**
   ```bash
   git clone https://github.com/yourusername/sstp-vpn-server.git
   cd sstp-vpn-server
   ```

3. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

4. **Make your changes**
5. **Test your changes**
6. **Commit your changes**
   ```bash
   git commit -m "Add: brief description of changes"
   ```

7. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

8. **Create a Pull Request**

#### Code Style Guidelines

- **Shell scripts**: Use consistent indentation (2 spaces)
- **Comments**: Add comments for complex logic
- **Error handling**: Include proper error handling
- **Logging**: Use the provided logging functions
- **Documentation**: Update relevant documentation

#### Testing

Before submitting a pull request:

1. **Test on multiple OS versions**
2. **Test installation methods**
3. **Test edge cases**
4. **Verify documentation**
5. **Check for security issues**

### Documentation Contributions

We welcome contributions to:

- **README files**
- **Installation guides**
- **Troubleshooting guides**
- **API documentation**
- **Code comments**

#### Documentation Guidelines

- Use clear, concise language
- Include examples where helpful
- Keep formatting consistent
- Update related sections
- Test all code examples

## Development Setup

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/sstp-vpn-server.git
   cd sstp-vpn-server
   ```

2. **Set up test environment**
   - Use a VM or container
   - Test on different OS versions
   - Use different installation methods

3. **Make changes**
4. **Test thoroughly**
5. **Submit pull request**

### Docker Development

```bash
# Build development image
docker build -t sstp-vpn-dev -f docker/Dockerfile .

# Run development container
docker run -it --rm \
  -e VPN_USER=testuser \
  -e VPN_PASS=testpass \
  -e VPS_PUBLIC_IP=127.0.0.1 \
  sstp-vpn-dev
```

## Pull Request Process

### Before Submitting

1. **Ensure your changes work**
2. **Test on multiple platforms**
3. **Update documentation**
4. **Follow code style guidelines**
5. **Add tests if applicable**

### Pull Request Template

When creating a pull request, please include:

- **Description** of changes
- **Testing** performed
- **Documentation** updates
- **Breaking changes** (if any)
- **Related issues** (if any)

### Review Process

1. **Automated checks** (if configured)
2. **Code review** by maintainers
3. **Testing** by maintainers
4. **Documentation review**
5. **Approval and merge**

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors.

### Expected Behavior

- Be respectful and inclusive
- Focus on what's best for the community
- Show empathy towards others
- Accept constructive criticism
- Help others learn and grow

### Unacceptable Behavior

- Harassment or discrimination
- Trolling or inflammatory comments
- Personal attacks
- Spam or off-topic discussions
- Any other unprofessional conduct

## Security

### Reporting Security Issues

If you discover a security vulnerability, please:

1. **Do not** create a public issue
2. **Email** the maintainers directly
3. **Include** detailed information
4. **Wait** for response before disclosure

### Security Guidelines

- Follow security best practices
- Test for security vulnerabilities
- Use secure coding practices
- Report security issues responsibly

## License

By contributing to this project, you agree that your contributions will be licensed under the same license as the project (MIT License).

## Recognition

Contributors will be recognized in:

- **CONTRIBUTORS.md** file
- **Release notes**
- **Project documentation**
- **GitHub contributors page**

## Getting Help

If you need help contributing:

1. **Check the documentation**
2. **Search existing issues**
3. **Ask in discussions**
4. **Contact maintainers**

## Release Process

### Version Numbering

We use semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

1. **Update version numbers**
2. **Update changelog**
3. **Test release candidate**
4. **Create release notes**
5. **Tag release**
6. **Publish release**

## Maintenance

### Long-term Support

- **LTS versions** for stability
- **Regular updates** for security
- **Deprecation notices** for old features
- **Migration guides** for breaking changes

### End of Life

- **Notice period** before EOL
- **Migration assistance**
- **Documentation updates**
- **Final security updates**

## Contact

- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Email**: [Contact information if available]
- **Documentation**: Project README

Thank you for contributing to the SSTP VPN Server project!
