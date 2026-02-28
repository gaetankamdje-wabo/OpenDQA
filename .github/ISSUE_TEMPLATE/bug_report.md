---
name: 🐛 Bug Report
about: Report a reproducible bug or unexpected behavior in Open DQA
title: "[BUG] "
labels: ["bug", "needs-triage"]
assignees: ""
---

## Bug Description

<!-- A clear and concise description of the bug. -->

## Steps to Reproduce

1. Go to '...'
2. Upload file '...'
3. Click on '...'
4. Observe error

## Expected Behavior

<!-- What did you expect to happen? -->

## Actual Behavior

<!-- What actually happened? Include any error messages verbatim. -->

## Error Output

```
# Paste full error message or stack trace here
```

## Minimal Reproducible Example

<!-- If possible, provide the smallest possible input file or code snippet that reproduces the issue. -->

```r
# Minimal R code that reproduces the issue (if applicable)
```

## Environment

| Field | Value |
|---|---|
| Open DQA Version | e.g. 2.1.0 |
| R Version | e.g. 4.3.1 |
| RStudio Version | e.g. 2023.06.0 |
| Operating System | e.g. Windows 11, Ubuntu 22.04 |
| Browser (if UI bug) | e.g. Chrome 118 |
| Shiny Server Version | e.g. 1.5.21 (if server deployment) |

## Input Data Characteristics

| Field | Value |
|---|---|
| Number of records | e.g. 50,000 |
| File format | CSV / XLSX |
| Character encoding | UTF-8 / ISO-8859-1 / other |

> ⚠️ Please do **not** attach real patient data. Use synthetic or anonymized data only.

## Additional Context

<!-- Add any other context, screenshots, or relevant information. -->

## Checklist

- [ ] I have checked that this issue has not already been reported
- [ ] I have updated Open DQA to the latest version and the bug persists
- [ ] I have run `Rscript tests/run_validation.R` and included the output if relevant
- [ ] I have not included any real patient data in this report
