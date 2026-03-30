<!--
SPDX-FileCopyrightText: 2026 Euro-Office contributors
SPDX-License-Identifier: CC0-1.0
-->

# Security Policy

## Supported Versions

Euro-Office is under active development. Security fixes are applied to the `main` branch and included in the latest nightly builds.

## Reporting a Vulnerability

We take security seriously. If you discover a vulnerability, please report it responsibly.

**Do not open a public issue for security vulnerabilities.**

Instead, please report vulnerabilities by:

1. **Email**: Contact the Euro-Office security team via the [GitHub organization](https://github.com/Euro-Office) or through one of the contributing partner organizations.
2. **Private vulnerability reporting**: Use GitHub's [private vulnerability reporting](https://github.com/Euro-Office/DocumentServer/security/advisories/new) feature if available.

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Any suggested fixes (if available)

### What to Expect

- We will acknowledge receipt within 7 days
- We will aim to provide an initial assessment within 14 days
- We will keep you informed of progress toward a fix
- We will credit you in the fix disclosure (unless you prefer anonymity)

## Security Best Practices

- **Keep deployments updated**: Subscribe to the repository releases and update promptly.
- **Review access controls**: Ensure DocumentServer is not publicly accessible without authentication.
- **Use HTTPS**: Always serve Euro-Office over HTTPS in production.
- **Docker security**: Keep Docker and the host system updated. Review container permissions.

## Dependency Security

Euro-Office uses automated security scanning:
- **CodeQL**: Enabled on core, server, web-apps, sdkjs, desktop-apps
- **Upstream sync**: Automated daily mirroring from ONLYOFFICE upstream

Report suspicious dependencies via the vulnerability reporting channels above.
