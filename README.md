# Open DQA — Open-Source Data Quality Assessment



<p align="center">
  <a href="https://github.com/gkamdje/OpenDQA/releases"><img src="https://img.shields.io/badge/version-1.0-blue.svg" alt="Version"/></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"/></a>
  <a href="https://www.r-project.org/"><img src="https://img.shields.io/badge/R-%E2%89%A54.2.0-blue.svg" alt="R Version"/></a>
  <a href="https://rstudio.github.io/bs4Dash/"><img src="https://img.shields.io/badge/bs4Dash-2.0%2B-orange.svg" alt="bs4Dash"/></a>
  <img src="https://img.shields.io/badge/languages-EN%20%7C%20DE%20%7C%20FR-lightgrey.svg" alt="Languages"/>
  <img src="https://img.shields.io/badge/checks-77-brightgreen.svg" alt="77 Checks"/>
  <a href="CONTRIBUTING.md"><img src="https://img.shields.io/badge/contributions-welcome-brightgreen.svg" alt="Contributions Welcome"/></a>
</p>

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Data Quality Check Categories](#data-quality-check-categories)
- [Screenshots](#screenshots)
- [Assessment Workflow](#assessment-workflow)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Data Format](#data-format)
- [Data Sources](#data-sources)
- [Configuration](#configuration)
- [Assisted Features](#assisted-features)
- [Reporting](#reporting)
- [Multilingual Support](#multilingual-support)
- [Test Data & Validation](#test-data--validation)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [Citation](#citation)
- [License](#license)
- [Contact](#contact)

---

## Overview

**Open DQA** is a comprehensive, open-source **R Shiny** application designed for systematic data quality assessment and guided cleansing of clinical and administrative healthcare datasets. It operationalizes **77 validated, rule-based data quality checks** grouped into **six clinically meaningful categories**, providing healthcare data engineers, medical informaticians, and clinical researchers with an automated, reproducible, and auditable quality assurance workflow.

Open DQA follows a **fitness-for-purpose** approach: data quality is evaluated against the specific requirements of your research question. It supports common healthcare interoperability standards including **HL7 FHIR**, **i2b2**, and **OMOP CDM**, making it adaptable to a wide range of real-world clinical data warehousing environments.


> ⚠️ **Important**: Open DQA is an open-source **research tool** — NOT a certified medical product under EU MDR, FDA, or any regulatory framework. It must not be used as a basis for clinical decisions. The user is solely responsible for validating and interpreting all results.

---

## Key Features

| Feature | Description |
|---|
|  **77 Built-in Checks** | Covering 6 quality dimensions: Completeness (16), Age Plausibility (15), Gender Plausibility (15), Temporal Consistency (6), Diagnosis–Procedure Consistency (15), Code Integrity (10) |
|  **Assisted Anomaly Detection** | Cluster-based anomaly detection with automated cleansing proposals |
|  **Trilingual Interface** | Full UI, check descriptions, and reports in English, German, and French |
|  **Step-by-Step Workflow** | Guided wizard from data upload through assessment to cleansing and documentation |
|  **Publication-Ready Reports** | One-click Word (.docx) and CSV export with cryptographic session fingerprints |
|  **Custom Check Builder** | Define institution-specific rules using `is_not.na`, `not_contains`, `BETWEEN`, `NOT BETWEEN`, `IN()`, `NOT IN()`, `REGEXP` |
|  **Multi-Source Import** | CSV, Excel, JSON, FHIR Bundle (R4), SQL (PostgreSQL, MS SQL) with i2b2 and OMOP CDM templates |
|  **Guided Data Cleansing** | Step-by-step cleansing with full audit trail and GCP-compliant documentation |
|  **Audit Trail** | Full session logging with cryptographic document fingerprints for regulatory compliance |
|  **Built-in Tutorial** | Interactive step-by-step tutorial with concrete examples for new users |
|  **Performance Timing** | Runtime profiling for imports, checks, and all tasks |
|  **Portable Deployment** | Runs locally, on-premise servers, or via Shiny Server |

---

## Data Quality Check Categories

Open DQA implements **77 checks** across six dimensions, aligned with established DQ frameworks (Kahn et al., 2016; Weiskopf & Weng, 2013):

### 1.  Completeness (16 checks: `cat1_1` – `cat1_16`)
Detects missing clinical data by cross-referencing clinical narratives (anamnese) against coded fields. Identifies discrepancies such as: admission present but ICD missing, surgery mentioned but no OPS code, specific disease mentions (diabetes, COPD, hypertension, stroke, etc.) without corresponding ICD codes, and complete absence of both ICD and OPS on admitted cases.

### 2.  Age Plausibility (15 checks: `cat2_1` – `cat2_15`)
Validates that patient age and diagnosis combinations are clinically plausible. Flags biologically impossible combinations such as prostate cancer (C61) in patients under 15, Alzheimer's (F00/G30) under 30, child developmental disorders (F80–F89) over 70, obstetric diagnoses in males, and age-inappropriate conditions like neonatal acne or delayed puberty in geriatric patients.

### 3.  Gender Plausibility (15 checks: `cat3_1` – `cat3_15`)
Cross-validates gender-coded fields against gender-specific diagnoses (ICD-10) and procedures. Flags records such as ovarian cyst (N83) in male patients, prostatitis (N41) in female patients, pregnancy codes in males, endometriosis in males, cervical cancer (C53) in males, and phimosis (N47) in females.

### 4.  Temporal Consistency (6 checks: `cat4_2`, `cat4_4`, `cat4_6`, `cat4_8`, `cat4_12`, `cat4_15`)
Ensures the logical ordering and validity of date fields. Detects discharge before admission, duplicate same-day admissions, future-dated admissions, same-day discharge with complex OPS codes, and admission before birth date.

### 5.  Diagnosis–Procedure Consistency (15 checks: `cat5_1` – `cat5_15`)
Validates co-occurrence of diagnoses and procedures using evidence-based clinical rules. Flags cases such as appendectomy without K35, knee replacement without M17, chemotherapy without cancer ICD, C-section in male patients, and hysterectomy without gynecological diagnosis.

### 6.  Code Integrity (10 checks: `cat6_1` – `cat6_9`, `cat6_11`)
Validates syntactic and semantic correctness of coded clinical variables. Identifies invalid ICD syntax patterns, retired OPS codes, ICD-10 near-miss typos, ICD-9 codes in ICD-10 environments, placeholder/fake codes, invalid code structure, foreign code system markers, and unspecific ICD codes.

---

## Screenshots

> *(Screenshots folder: `assets/`)*

| Welcome Page | Data Import |
|---|---|
| ![Welcome](assets/screenshot_welcome.png) | ![Import](assets/screenshot_import.png) |

| Check Results | Word Report |
|---|---|
| ![Results](assets/screenshot_results.png) | ![Report](assets/screenshot_report.png) |

---

## Assessment Workflow

Open DQA uses a guided, step-by-step wizard:

| Step | Name | Description |
|---|---|---|
| **0** | 🏠 Welcome | Landing page with feature overview, tutorial access, disclaimer acceptance |
| **T** | 🎓 Tutorial | Interactive walkthrough of all features with concrete examples |
| **1** | 📁 Load Data | Multi-source import: local files (CSV, Excel, JSON, FHIR), SQL databases, FHIR servers |
| **2** | 🗺️ Map Columns | Map dataset columns to Open DQA target fields with gender value standardization |
| **3** | ✅ Select Checks | Browse and select from 77 built-in checks, organized by category with availability indicators |
| **4** | ✏️ Custom Checks | Build institution-specific rules using the visual rule editor |
| **5** | 📊 Results | Interactive dashboard with quality score, severity analysis, and category breakdown |
| **6** | 🧹 Cleansing | Guided data cleansing with assistant, full audit trail, and final documentation |

---

## Requirements

### System Requirements

| Component | Minimum | Recommended |
|---|---|---|
| OS | Windows 10 / Ubuntu 20.04 / macOS 12 | Ubuntu 22.04 LTS |
| RAM | 4 GB | 16 GB+ |
| CPU | 2 cores | 4+ cores |
| Disk | 500 MB | 2 GB+ |

### Software Requirements

- **R** ≥ 4.2.0
- **RStudio** ≥ 2022.07 *(recommended)* or any R-compatible IDE

### R Package Dependencies

Core dependencies (automatically installed on first run):

| Package | Purpose |
|---|---|
| `shiny` | Web application framework |
| `bs4Dash` | Bootstrap 4 dashboard UI |
| `DT` | Interactive data tables |
| `readxl` | Excel file import |
| `jsonlite` | JSON parsing (standard + FHIR) |
| `stringr` | String manipulation |
| `dplyr` | Data manipulation |
| `lubridate` | Date/time handling |
| `rlang` | Tidy evaluation |
| `data.table` | Fast data import (`fread`) and manipulation |
| `shinyjs` | JavaScript operations in Shiny |
| `shinyWidgets` | Enhanced UI widgets |
| `waiter` | Loading spinners and overlays |
| `officer` | Word (.docx) report generation |
| `flextable` | Formatted tables in Word reports |
| `plogr` | Logging |

Optional dependencies:

| Package | Purpose |
|---|---|
| `cluster` | clustering for anomaly detection |
| `emayili` | Email report delivery via SMTP |
| `DBI` + `RPostgres` | PostgreSQL database connectivity |
| `DBI` + `odbc` | Microsoft SQL Server connectivity |

---

## Installation

### Option 1: Clone from GitHub *(Recommended)*

```bash
# 1. Clone the repository
git clone  https://github.com/gaetankamdje-wabo/OpenDQA.git

# 2. Navigate into the project directory
cd OpenDQA

# 3. Open R or RStudio and install dependencies
Rscript install_dependencies.R

# 4. Launch the application
Rscript -e "shiny::runApp('app.R', launch.browser = TRUE)"
```

### Option 2: Download ZIP Archive

1. Click **Code → Download ZIP** on the GitHub repository page.
2. Extract the archive to your desired location.
3. Open `app.R` in RStudio.
4. Run `Rscript install_dependencies.R` in the terminal.
5. Click **Run App** in RStudio.

### Installing Dependencies Manually

If the automatic installer fails, install packages manually in R:

```r
pkgs <- c(
  "shiny", "bs4Dash", "DT", "readxl", "jsonlite", "stringr", "dplyr",
  "lubridate", "rlang", "data.table", "shinyjs", "shinyWidgets", "waiter",
  "officer", "flextable", "plogr", "cluster", "emayili", "DBI", "RPostgres"
)
install.packages(pkgs, dependencies = TRUE)
```

---

## Quick Start

### 1. Launch the Application

```r
shiny::runApp("app.R", launch.browser = TRUE)
```

### 2. Accept the Disclaimer

Read and accept the research tool disclaimer on the landing page.

### 3. Upload & Assess

1. Click **"Proceed to Assessment"** (or take the Tutorial first).
2. In **Step 1**, select your data source (local file, SQL database, or FHIR server) and upload/connect.
3. In **Step 2**, map your columns to the 9 target fields and configure gender value standardization.
4. In **Step 3**, select which of the 77 built-in checks to run (checks requiring unavailable columns are dimmed).
5. In **Step 4**, optionally define custom checks using the visual rule builder.
6. Click **"Run All Checks"** and review results in **Step 5** with the interactive dashboard.
7. In **Step 6**, use guided cleansing with the assistant and export your final Word report and CSV.

---

## Data Format

Open DQA expects a flat tabular structure. The column mapping wizard (Step 2) allows you to map any column names to the required target fields.

### Target Fields

| Target Field | Type | Description | Required |
|---|---|---|---|
| `patient_id` | character | Unique patient identifier | ✅ |
| `icd` | character | ICD-10 diagnosis code(s); semicolon-separated for multiple | ✅ |
| `ops` | character | OPS procedure code(s); semicolon-separated for multiple | ⬜ Optional |
| `gender` | character | Patient gender (mapped via gender standardization) | ✅ |
| `admission_date` | date | Hospital admission date | ✅ |
| `discharge_date` | date | Hospital discharge date | ✅ |
| `age` | numeric | Patient age at admission | ⬜ Optional |
| `birth_date` | date | Patient date of birth | ⬜ Optional |
| `anamnese` | character | Clinical narrative / anamnesis text | ⬜ Optional |

> **Gender Standardization**: In Step 2, you provide comma-separated lists of values that represent "male" and "female" in your dataset (e.g., `m, male, M, 1, Mann` for male). Open DQA automatically normalizes these for gender plausibility checks.

> **Date Formats**: ISO 8601 (`YYYY-MM-DD`) is preferred. Dates are automatically parsed using `as.Date()`.

> See [docs/data_format.md](docs/data_format.md) for the full schema specification.

---

## Data Sources

### Local File Upload

| Format | Extension | Notes |
|---|---|---|
| CSV/TXT | `.csv`, `.txt`, `.tsv` | Configurable separator (`,`, `;`, tab) and header row. Up to **2 GB** |
| Excel | `.xlsx`, `.xls` | Selectable sheet number |
| JSON | `.json` | Standard JSON, JSON Lines (NDJSON), and nested JSON with auto-flattening |
| FHIR Bundle | `.json` | HL7 FHIR R4 bundles — extracts Patient, Encounter, Condition, Procedure resources |

### SQL Database

Supports **PostgreSQL** and **Microsoft SQL Server** with built-in query templates:

| Template | Description |
|---|---|
| Basic SELECT | Simple `SELECT * FROM table LIMIT 100` |
| i2b2 | Pre-built query joining i2b2 `patient_dimension`, `visit_dimension`, and `observation_fact` |
| OMOP CDM | Pre-built query joining OMOP `person`, `visit_occurrence`, `condition_occurrence`, `procedure_occurrence` |

Connection features include test connectivity, configurable timeouts, retry logic, and SSL support.

### FHIR Server

Direct connection to FHIR R4 servers for live data retrieval (panel available in Step 1).

---

## Configuration

Application behavior is configurable via `config/settings.yml`:

```yaml
# Threshold settings
thresholds:
  completeness_warning: 0.95       # Warn if completeness < 95%
  completeness_critical: 0.80      # Critical if completeness < 80%
  max_patient_age: 125             # Maximum plausible patient age (years)
  min_patient_age: 0               # Minimum plausible patient age (years)
  max_los: 365                     # Maximum plausible length of stay (days)



# Reporting
reporting:
  default_language: "en"           # en | de | fr
  logo_path: "assets/logo.png"
  institution_name: "Your Institution"

# Email
email:
  enabled: false
  smtp_host: ""
  smtp_port: 587
  from_address: ""
```

---

## Assisted Features

Open DQA integrates optional assistance:

- **Cluster-Based Anomaly Detection**: Uses the `cluster` package to identify data patterns and anomalies, proposing targeted cleansing actions.
- **Near-Duplicate Detection**: Identifies potential typos and near-duplicates among categorical values using edit distance computation.
- **Entropy Analysis**: Evaluates information entropy of categorical distributions to flag suspicious uniformity or diversity.
- **AI Narrative Generation** *(optional, requires API key)*: When enabled, summarizes detected quality issues in plain clinical language with root cause suggestions.

To enable API-based AI features, set your API key as an environment variable:

```bash
export ANTHROPIC_API_KEY="your_api_key_here"
```

> All data submitted to external AI providers is anonymized — patient identifiers and direct clinical data are stripped prior to API calls.

---

## Reporting

Open DQA generates comprehensive quality reports:

| Format | Description |
|---|---|
| **Word (.docx)** | Publication-ready, IT-security-grade proof document generated via `officer` + `flextable`. Includes executive summary, tool metadata, assessment parameters, per-check results with descriptions, severity analysis, and cryptographic session fingerprint. |
| **CSV** | Machine-readable results table for downstream processing |

### Report Contents

Reports include:
- **Cryptographic Session Fingerprint** (`ODQA-XXXXXXXXXX`) for document integrity verification
- **Data Protection Statement** confirming exclusion of patient identifiers
- **Tool Metadata**: Version, R version, timestamp, document ID
- **Dataset Summary**: Record/column counts, checks executed, quality score
- **Quality Score**: `100% × (1 − affected_records / total_records)` with color-band interpretation (Green ≥80%, Yellow 60–79%, Orange 40–59%, Red <40%)
- **Per-Category Severity Analysis** with issue counts and distributions
- **Individual Check Results**: Status, description, affected count, severity for every executed check
- **Custom Check Documentation**: All user-defined rules with creation metadata
- **Cleansing Audit Trail**: Complete log of all modifications for GCP compliance
- **Fitness-for-Purpose Interpretation**: Contextual assessment of data suitability

---

## Multilingual Support

The full application UI, all check descriptions, disclaimer, tutorial, FAQ, and report content are available in:

- 🇬🇧 **English** (`en`)
- 🇩🇪 **German** (`de`) — Deutsch
- 🇫🇷 **French** (`fr`) — Français

Language is selectable via the in-app dropdown in the top navigation bar. All translation strings are maintained inline in the i18n section of `app.R`.

---

## Test Data & Validation

The repository includes a synthetic test dataset (`data/Test_Data.csv`) and a corresponding expected results file (`data/open_dqa_expected_hits.csv`) for validation purposes.

### Test Dataset

- **File**: `data/Test_Data.csv`
- **Records**: 1,588 synthetic patient records
- **Columns**: 9 (`patient_id`, `icd`, `ops`, `gender`, `admission_date`, `discharge_date`, `age`, `birth_date`, `anamnese`)
- **Design**: Contains deliberately seeded quality issues covering all 77 check categories

### Expected Results

- **File**: `data/open_dqa_expected_hits.csv`
- **Structure**: Two columns (`check_id`, `patient_id`) mapping each check to the test records that should trigger it
- **Coverage**: All 77 checks have at least one expected hit

### Running Validation

```r
source("tests/run_validation.R")
# Compares application output against open_dqa_expected_hits.csv
```

The test dataset is fully synthetic — it contains no real patient data.

---

## Project Structure

```
OpenDQA/
│
├── app.R                          # Main Shiny application (single-file, ~7,900 lines)
├── install_dependencies.R         # Automated package installer
│
├── R/                             # Modular R source files (for future refactoring)
│   ├── checks/                    # Check implementation functions
│   ├── ui/                        # UI modules
│   ├── server/                    # Server-side modules
│   ├── reporting/                 # Report generation functions
│   ├── assistance/                #  integration
│   └── utils/                     # Utility functions
│
├── config/
│   └── settings.yml               # Application configuration
│
├── data/
│   ├── Test_Data.csv              # Synthetic test dataset (1,588 records)
│   └── open_dqa_expected_hits.csv # Expected check results for validation
│
├── i18n/                          # Multilingual resources (translations inline in app.R)
│
├── reports/
│   └── templates/                 # Report templates
│
├── tests/
│   └── run_validation.R           # Automated validation script
│
├── docs/                          # Extended documentation
│   ├── installation.md
│   ├── user_guide.md
│   ├── checks_reference.md
│   └── data_format.md
│
├── assets/                        # Images, logos
├── logs/                          # Session logs (gitignored except .gitkeep)
├── .github/                       # GitHub templates
├── CHANGELOG.md
├── CITATION.cff
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── SECURITY.md
└── LICENSE
```

---

## Contributing

We welcome contributions from the medical informatics, health data science, and clinical engineering communities. Please read [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on:

- Reporting bugs and requesting features
- Development workflow (fork → branch → PR)
- Coding standards and test requirements
- Adding new quality checks
- Adding or improving translations

---

## Citation

If you use Open DQA in research or clinical work, please cite:

```bibtex
@software{opendqa2025,
  author    = {Kamdje Wabo, Gaetan and Sokolowski, P. and Ganslandt, T. and Siegel, F.},
  title     = {{Open DQA}: An Open-Source {R Shiny} Application for Medical Data Quality Assessment},
  year      = {2025},
  version   = {1.0},
  url       = {https://github.com/gkamdje/OpenDQA},
  note      = {Developed at MIISM, Klinikum Mannheim GmbH and Universit{\"a}t Heidelberg}
}
```

A manuscript describing the methodology and validation of Open DQA has been submitted to **JMIR Medical Informatics**. See [CITATION.cff](CITATION.cff) for machine-readable citation metadata.

---

## License

Open DQA is released under the **MIT License**. See [LICENSE](LICENSE) for the full license text.

© 2026 Open DQA Contributors. Developed at MIISM, Klinikum Mannheim GmbH and Universität Heidelberg.

---

## Contact

- **Lead Developer**: Gaetan Kamdje Wabo — [gaetankamdje.wabo@medma.uni-heidelberg.de](mailto:gaetankamdje.wabo@medma.uni-heidelberg.de) | [gaetan.kamdje-wabo@umm.de](mailto:gaetan.kamdje-wabo@umm.de)
- **Institution**: MIISM — Medical Informatics in Translational and Integrated Medicine, Universität Heidelberg
- **Issues & Bug Reports**: [GitHub Issues](https://github.com/gkamdje/OpenDQA/issues)
- **Security Disclosures**: Please email directly rather than opening a public issue.

---

<p align="center">
  <sub>Built with ❤️ for clinical data quality • Mannheim 🇩🇪</sub>
</p>
