# Security Policy

## Supported Versions

| Version | Supported |
|---|---|
| 2.1.x | ✅ Active support |
| 2.0.x | ⚠️ Security fixes only |
| 1.x.x | ❌ End of life |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub Issues.**

Security vulnerabilities should be reported by email to the project maintainers at:

📧 **[maintainer.email@institution.de]**

Please include:

- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if known)

We will acknowledge receipt within **5 business days** and provide a status update within **14 business days**.

## Security Considerations for Healthcare Deployment

Open DQA processes potentially sensitive healthcare data. Deploying institutions are responsible for:

- Ensuring data processing complies with applicable regulations (e.g., GDPR, HIPAA, BDSG)
- Using pseudonymized or de-identified data where possible
- Restricting access to the Shiny application to authorized personnel
- Securing the server environment (HTTPS, authentication, network isolation)
- Not committing patient data or API keys to version control (see `.gitignore`)
- Rotating API keys if they are inadvertently exposed

## Data Handling

Open DQA does not transmit patient data externally under any standard configuration. When AI features are enabled, only anonymized aggregate statistics are sent to the configured API endpoint. See `docs/ai_privacy.md` for details.
