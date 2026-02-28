# Security Policy

## Supported Versions

| Version | Supported |
|---|---|
| 1.0 | Active support |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub Issues.**

Security vulnerabilities should be reported by email to the project maintainers at:

gaetankamdje.wabo@medma.uni-heidelberg.de

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
- Not committing patient data to version control (see `.gitignore`)

## Data Handling

Open DQA processes all data locally within the R session. No patient data is transmitted externally during standard operation. The only network connections initiated by the application are:

- **FHIR server connections** (Step 1, if configured by the user)
- **SQL database connections** (Step 1, if configured by the user)
- **SMTP connections** (optional email reporting, if configured in `config/settings.yml`)

All three connection types are user-initiated and require explicit configuration.
