# Contributing to Open DQA

Thank you for your interest in contributing to Open DQA! We welcome contributions from the medical informatics, health data science, clinical data engineering, and software development communities.

This document provides guidelines to help ensure that contributions are high-quality, consistent, and efficiently reviewed.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Branch Naming Convention](#branch-naming-convention)
- [Coding Standards](#coding-standards)
- [Adding New Quality Checks](#adding-new-quality-checks)
- [Adding or Improving Translations](#adding-or-improving-translations)
- [Testing Requirements](#testing-requirements)
- [Pull Request Process](#pull-request-process)
- [Reporting Bugs](#reporting-bugs)
- [Requesting Features](#requesting-features)
- [Recognition](#recognition)

---

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). We are committed to providing a welcoming and inclusive environment for everyone.

---

## How to Contribute

There are many ways to contribute to Open DQA, even without writing code:

- **Report bugs** via [GitHub Issues](https://github.com/gkamdje/OpenDQA/issues)
- **Suggest new quality checks** — especially domain-specific clinical rules
- **Improve documentation** — fix typos, add examples, clarify instructions
- **Add or improve translations** — currently EN, DE, FR; new languages welcome
- **Submit code** — bug fixes, new features, performance improvements
- **Review pull requests** — help evaluate and provide feedback on others' contributions
- **Share clinical domain knowledge** — expert input on check logic and thresholds

---

## Development Setup

### Prerequisites

- R ≥ 4.2.0
- RStudio (recommended) or VS Code with R extension
- Git ≥ 2.30

### Fork and Clone

```bash
# 1. Fork the repository on GitHub (click "Fork" button)

# 2. Clone your fork
git clone https://github.com/YOUR-USERNAME/OpenDQA.git
cd OpenDQA

# 3. Add the upstream remote
git remote add upstream https://github.com/gkamdje/OpenDQA.git

# 4. Install dependencies
Rscript install_dependencies.R
```

### Keeping Your Fork Updated

```bash
git fetch upstream
git checkout main
git merge upstream/main
```

---

## Branch Naming Convention

Use descriptive, lowercase, hyphen-separated branch names following this pattern:

| Type | Pattern | Example |
|---|---|---|
| New feature | `feature/short-description` | `feature/omop-import` |
| Bug fix | `fix/short-description` | `fix/date-parsing-timezone` |
| Documentation | `docs/short-description` | `docs/improve-installation-guide` |
| New check | `check/category-name` | `check/temporal-los-negative` |
| Translation | `i18n/language-code` | `i18n/spanish-es` |
| Refactor | `refactor/short-description` | `refactor/completeness-module` |

---

## Coding Standards

### R Style Guide

Open DQA follows the [tidyverse style guide](https://style.tidyverse.org/) with the following additions:

- Use `snake_case` for all variable and function names.
- Maximum line length: **100 characters**.
- Use `<-` for assignment (not `=`).
- Handle all possible `NA`/`NULL` inputs gracefully — use `tryCatch` for robustness.
- The current application is a single-file `app.R`. New utility functions should be placed in the appropriate `R/` subdirectory for eventual modularization.

### Current Architecture

Open DQA V1.0 is structured as a single `app.R` file (~7,900 lines) organized into 12 sections:

1. **Libraries**: Package loading with graceful fallbacks
2. **Internationalisation (i18n)**: Key-value store for EN/DE/FR strings
3. **Data Readers**: CSV, Excel, JSON, FHIR, SQL importers
4. **ICD-10 & OPS Validators**: Regex-based code validation
5. **Utilities**: Helper functions, ML tools, performance utilities
6. **Check Metadata**: 77 check definitions in the `CL` list
7. **Word Report Generation**: `officer`/`flextable`-based .docx export
8. **FAQ Data**: Trilingual FAQ entries
9. **CSS Design System**: Complete CSS for the application
10. **UI Definition**: `bs4DashPage` layout with step-based navigation
11. **Server Logic**: Reactive logic, check execution, cleansing
12. **Launch**: `shinyApp(ui, server)`

### Key Packages

| Package | Used For |
|---|---|
| `bs4Dash` | UI framework (not `shinydashboard`) |
| `officer` + `flextable` | Word report generation (not `rmarkdown`) |
| `data.table::fread()` | CSV import (not `readr`) |
| `emayili` | Email delivery (not `mailR`) |
| `waiter` | Loading spinners |

---

## Adding New Quality Checks

Adding a new check is the most impactful way to contribute.

### 1. Determine the Category

Assign your check to one of the six existing categories (`cat1_` through `cat6_`), or propose a new category in the issue tracker first.

### 2. Add the Check to the `CL` List

In `app.R`, Section 6, add your check to the `CL` list following the existing pattern:

```r
CL <- list(
  # ... existing checks ...
  cat1_17 = list(w = "Your check description.", n = c("required_col1", "required_col2"), sev = "Medium"),
)
```

Fields:
- `w`: Short description of what the check flags
- `n`: Character vector of required mapped column names
- `sev`: Severity level (`"Critical"`, `"High"`, `"Medium"`, `"Low"`)

### 3. Implement the Check Logic

Add the corresponding check logic in the server section's check execution block, following the pattern of existing checks.

### 4. Add Translations

Add UI-facing strings to the `I18N` list in Section 2 for all three languages (EN, DE, FR).

### 5. Add Test Cases

Add test records to `data/Test_Data.csv` with patient IDs following the pattern `T_catX_Y` (e.g., `T_cat1_17`). Update `data/open_dqa_expected_hits.csv` with the expected hits.

### 6. Document

Add an entry for your check in `docs/checks_reference.md`.

---

## Adding or Improving Translations

Translation strings are maintained inline in the `I18N` list in `app.R` (Section 2). The structure is:

```r
I18N <- list(
  my_key = list(
    en = "English text",
    de = "German text",
    fr = "French text"
  ),
  # ...
)
```

To add a new language, add a new key to each entry and update the language selector in the UI definition (Section 10).

---

## Testing Requirements

All code contributions must include or update tests:

- All 77 existing checks must continue to produce expected results against `data/Test_Data.csv` matching `data/open_dqa_expected_hits.csv`.
- New checks must have associated test records in `data/Test_Data.csv` and expected hits in `data/open_dqa_expected_hits.csv`.

```bash
Rscript tests/run_validation.R
```

---

## Pull Request Process

1. **Ensure your branch is up to date** with `upstream/main` before opening a PR.
2. **Fill out the PR template** completely — incomplete PRs may be closed without review.
3. **Link any related issues** using `Closes #issue_number` in the PR description.
4. **Ensure all checks pass**: Run the validation script locally before submitting.
5. **Limit PRs to a single concern** — separate bug fixes from features.
6. **Request a review** from at least one maintainer.

PRs will be reviewed within **14 business days**.

---

## Reporting Bugs

Please use the [Bug Report issue template](.github/ISSUE_TEMPLATE/bug_report.md). Include:

- Open DQA version number
- R version and operating system
- Steps to reproduce the issue
- Expected vs. actual behavior
- Relevant error messages or log output

**Security vulnerabilities** should be reported by email to the project lead rather than as public issues.

---

## Requesting Features

Please use the [Feature Request issue template](.github/ISSUE_TEMPLATE/feature_request.md). Describe:

- The clinical or technical problem you are trying to solve
- Your proposed solution
- Alternative approaches you have considered
- Any relevant literature or standards references

---

## Recognition

All contributors are listed in [CHANGELOG.md](CHANGELOG.md) and the project's GitHub contributor graph. Significant contributors may be invited to co-author future academic publications describing Open DQA.

---

Thank you for helping improve data quality in healthcare! 🏥
