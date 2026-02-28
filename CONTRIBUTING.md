# Contributing to Open DQA

Contributions from the medical informatics, health data science, and clinical engineering communities are welcome. This document describes how to report bugs, suggest features, add new quality checks, and submit code changes.

---

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to maintain a respectful and professional environment.

---

## Reporting Bugs

1. Search [existing issues](https://github.com/gkamdje/OpenDQA/issues) to check if the bug has already been reported.
2. Open a new issue using the **Bug Report** template.
3. Include: R version, OS, browser, steps to reproduce, expected behavior, actual behavior, and (if applicable) a minimal dataset that triggers the issue.

---

## Requesting Features

1. Open a new issue using the **Feature Request** template.
2. Describe the use case, expected behavior, and any relevant clinical or technical context.

---

## Development Setup

### Prerequisites
- R ≥ 4.2.0
- RStudio (recommended)
- Git

### Setup
```bash
git clone https://github.com/gkamdje/OpenDQA.git
cd OpenDQA
git checkout -b feature/your-feature-name
Rscript install_dependencies.R
```

### Architecture Overview

Open DQA V1.0 uses a single-file architecture (`app.R`, approximately 7,900 lines). The file is organized into 12 clearly delimited sections:

| Section | Content |
|---|---|
| 1 | Package loading and initialization |
| 2 | `I18N` — Internationalization strings (EN, DE, FR) |
| 3 | Helper functions and utilities |
| 4 | Statistical analysis assistant functions |
| 5 | Master check suggestion function |
| 6 | `CL` — Check library (77 built-in checks) |
| 7 | Report generation (`officer` + `flextable`) |
| 8 | UI definition (`bs4Dash`) |
| 9 | Server logic |
| 10 | Data import handlers |
| 11 | Check execution engine |
| 12 | Cleansing and export |

The `R/` directory contains empty subdirectories reserved for future modularization.

---

## Adding New Quality Checks

### Step 1: Define the Check

Add a new entry to the `CL` list in `app.R` (Section 6). Follow the existing naming convention:

```r
cat<CATEGORY>_<NUMBER> = list(
  name = list(
    en = "English check name",
    de = "German check name",
    fr = "French check name"
  ),
  description = list(
    en = "English description",
    de = "German description",
    fr = "French description"
  ),
  severity = "High",           # Critical | High | Medium | Low
  required_cols = c("icd", "age"),  # Required target fields
  expression = "grepl(...)"    # R logical expression (TRUE = violation)
)
```

### Step 2: Provide Trilingual Text

All check names and descriptions must be provided in English, German, and French.

### Step 3: Add Test Data

1. Add corresponding test records to `data/Test_Data.csv` using the patient ID convention `T_catX_Y`.
2. Add expected hits to `data/open_dqa_expected_hits.csv`.

### Step 4: Run Validation

```r
source("tests/run_validation.R")
```

Verify that your new check is executed and produces the expected results.

---

## Improving Translations

All translation strings are in the `I18N` list (Section 2 of `app.R`). Each entry follows the structure:

```r
key_name = list(en = "English", de = "Deutsch", fr = "Français")
```

When modifying translations, ensure all three languages are updated simultaneously.

---

## Extending the Statistical Analysis Assistant

The statistical analysis assistant (Section 4 of `app.R`) uses classical statistical and heuristic methods.

When adding new statistical methods:

1. Implement the function using base R or CRAN packages already in the dependency list.
2. Document the statistical method and its scholarly reference.
3. Register the function in the master dispatcher `ai_detect_anomalies()` or `ai_suggest_checks()`.
4. Ensure all output strings are trilingual (EN, DE, FR).

---

## Pull Request Process

1. Fork the repository and create a feature branch.
2. Make your changes with clear, descriptive commit messages.
3. Ensure the validation script passes: `source("tests/run_validation.R")`.
4. Open a pull request using the PR template.
5. Address reviewer feedback.

### PR Requirements

- All new checks must include trilingual text (EN, DE, FR).
- All new checks must include test data and expected results.
- No new R package dependencies without prior discussion.
- Code style: Follow the existing conventions in `app.R`.

---

## Versioning

This project uses [Semantic Versioning](https://semver.org/). Version numbers follow `MAJOR.MINOR.PATCH`:

- **MAJOR**: Breaking changes to check semantics, data format, or report structure.
- **MINOR**: New checks, new features, new data source support.
- **PATCH**: Bug fixes, translation corrections, documentation updates.

---

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
