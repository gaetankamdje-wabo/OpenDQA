<<<<<<< HEAD
# Open DQA — Open-Source Data Quality Assessment for Clinical Research Data
=======
# Open DQA - Open-Source Data Quality Assessment

>>>>>>> 3f7f6b461c608d0b5eef6abbdc3cbde882860e00


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
- [Assessment Workflow](#assessment-workflow)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Data Format](#data-format)
- [Data Sources](#data-sources)
- [Configuration](#configuration)
<<<<<<< HEAD
- [Statistical Analysis Assistant](#statistical-analysis-assistant)
=======
- [Assisted Features](#assisted-features)
>>>>>>> 3f7f6b461c608d0b5eef6abbdc3cbde882860e00
- [Reporting](#reporting)
- [Multilingual Support](#multilingual-support)
- [Test Data and Validation](#test-data-and-validation)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [Citation](#citation)
- [License](#license)
- [Contact](#contact)

---

## Overview

**Open DQA** is an open-source **R Shiny** application for the systematic assessment and guided cleansing of clinical and administrative healthcare data. It implements **77 rule-based data quality checks** across **six quality dimensions**, providing healthcare data engineers, medical informaticians, and clinical researchers with a reproducible and auditable quality assurance workflow.

The application follows a **fitness-for-purpose** approach to data quality evaluation (Kahn et al., 2016): data quality is assessed relative to the specific requirements of the intended analytical use case. Open DQA supports multi-format data import including **CSV**, **Excel**, **JSON**, **HL7 FHIR R4** bundles, and **SQL databases** (PostgreSQL, Microsoft SQL Server) with pre-built query templates for **i2b2** and **OMOP CDM** schemas.

A complementary **statistical analysis assistant** employs classical descriptive and inferential statistical methods — including IQR-based outlier detection, Z-score analysis, Levenshtein edit distance, Shannon entropy, Chi-squared independence tests, Cramér's V, Spearman rank correlation, and Benford's Law deviation analysis — to generate data-driven custom check suggestions that supplement the rule-based checks.

> **Developed at MIISM (Mannheimer Institut für Intelligente Systeme in der Medizin), Klinikum Mannheim GmbH / Universität Heidelberg.**

> **Disclaimer**: Open DQA is an open-source research tool. It is not a certified medical device under EU MDR, FDA 21 CFR Part 11, or any other regulatory framework. It must not be used as a basis for clinical decisions. The user is solely responsible for validating and interpreting all results.

---

## Key Features

| Feature | Description |
<<<<<<< HEAD
|---|---|
| **77 Built-in Checks** | Rule-based checks across 6 quality dimensions: Completeness (16), Age Plausibility (15), Gender Plausibility (15), Temporal Consistency (6), Diagnosis–Procedure Consistency (15), Code Integrity (10) |
| **Statistical Analysis Assistant** | Classical statistical methods (IQR, Z-score, Levenshtein distance, Shannon entropy, Benford's Law, Chi-squared, Cramér's V, Spearman correlation) for automated custom check suggestion |
| **Trilingual Interface** | Full UI, check descriptions, and reports in English, German, and French |
| **Guided Step-by-Step Workflow** | Wizard from data upload through column mapping, check selection, assessment, to cleansing and documentation |
| **Publication-Ready Reports** | Word (.docx) and CSV export via `officer`/`flextable` with cryptographic session fingerprints |
| **Custom Check Builder** | Define institution-specific rules using `is_not.na`, `not_contains`, `BETWEEN`, `NOT BETWEEN`, `IN()`, `NOT IN()`, `REGEXP` |
| **Multi-Source Import** | CSV, Excel, JSON, FHIR R4 Bundle, SQL (PostgreSQL, MS SQL) with i2b2 and OMOP CDM query templates |
| **Guided Data Cleansing** | Step-by-step cleansing with full audit trail |
| **Audit Trail** | Session logging with cryptographic document fingerprints for regulatory documentation |
| **Built-in Tutorial** | Interactive step-by-step tutorial for new users |
| **Performance Timing** | Runtime profiling for imports, checks, and all computational tasks |
| **Portable Deployment** | Runs locally, on-premise, or via Shiny Server |
=======
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
>>>>>>> 3f7f6b461c608d0b5eef6abbdc3cbde882860e00

---

## Data Quality Check Categories

Open DQA implements **77 checks** across six dimensions, aligned with established data quality frameworks (Kahn et al., 2016; Weiskopf & Weng, 2013):

<<<<<<< HEAD
### 1. Completeness (16 checks: `cat1_1` – `cat1_16`)
Detects missing clinical data by cross-referencing clinical narrative text (anamnese) against coded fields. Identifies discrepancies such as admission present but ICD code missing, surgical procedures mentioned in narrative but OPS code absent, specific disease mentions (diabetes, COPD, hypertension, stroke, depression) without corresponding ICD codes, and records with admission date but both ICD and OPS codes absent.

### 2. Age Plausibility (15 checks: `cat2_1` – `cat2_15`)
Validates that patient age and diagnosis combinations are clinically plausible. Flags biologically implausible combinations including prostate cancer (C61) in patients under 15, Alzheimer's disease (F00/G30) under 30, child developmental disorders (F80–F89) over 70, obstetric diagnoses (O60–O75, O14) in male patients, and age-inappropriate conditions such as acne (L70) in neonates or delayed puberty (E30.0) in patients over 60.

### 3. Gender Plausibility (15 checks: `cat3_1` – `cat3_15`)
Cross-validates gender-coded fields against gender-specific ICD-10 diagnoses. Flags records such as ovarian cyst (N83) in male patients, prostatitis (N41) in female patients, pregnancy O-codes in males, endometriosis (N80) in males, cervical cancer (C53) in males, phimosis (N47) in females, and breast cancer (C50) in male patients (flagged as rare, requiring clinical review).

### 4. Temporal Consistency (6 checks: `cat4_2`, `cat4_4`, `cat4_6`, `cat4_8`, `cat4_12`, `cat4_15`)
Validates logical ordering and plausibility of date fields. Detects discharge date before admission date, duplicate same-day admissions per patient, future-dated admissions, same-day discharge with complex OPS codes, and admission date preceding birth date.

### 5. Diagnosis–Procedure Consistency (15 checks: `cat5_1` – `cat5_15`)
Validates co-occurrence of diagnoses and procedures using evidence-based clinical rules. Flags cases including appendectomy without K35, knee replacement without M17, chemotherapy without cancer ICD, C-section OPS in male patients, cataract surgery without H25/H26, and pacemaker implantation without I44–I49.

### 6. Code Integrity (10 checks: `cat6_1` – `cat6_9`, `cat6_11`)
Validates syntactic and semantic correctness of coded clinical variables using regex-based pattern matching. Identifies invalid ICD-10 syntax, retired OPS codes (heuristic), ICD near-miss typos, ICD-9 codes in ICD-10 environments, placeholder codes (xxx, zzz), invalid OPS structure, foreign code system markers, and unspecific ICD codes (R99, Z00).
=======
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
>>>>>>> 3f7f6b461c608d0b5eef6abbdc3cbde882860e00

---

## Assessment Workflow

Open DQA uses a guided, step-by-step wizard:

| Step | Name | Description |
|---|---|---|
<<<<<<< HEAD
| **0** | Welcome | Landing page with feature overview, disclaimer acceptance, tutorial access |
| **T** | Tutorial | Interactive walkthrough of all features with examples |
| **1** | Load Data | Multi-source import: local files (CSV, Excel, JSON, FHIR), SQL databases, FHIR servers |
| **2** | Map Columns | Map dataset columns to 9 target fields; configure gender value standardization |
| **3** | Select Checks | Browse and select from 77 built-in checks; checks requiring unmapped columns are automatically dimmed |
| **4** | Custom Checks | Build institution-specific rules via visual editor; optionally invoke statistical analysis assistant for data-driven suggestions |
| **5** | Results | Quality score, severity analysis, per-check results, Word/CSV report export |
| **6** | Cleansing | Guided data cleansing with audit trail and final documentation |
=======
| **0** | 🏠 Welcome | Landing page with feature overview, tutorial access, disclaimer acceptance |
| **T** | 🎓 Tutorial | Interactive walkthrough of all features with concrete examples |
| **1** | 📁 Load Data | Multi-source import: local files (CSV, Excel, JSON, FHIR), SQL databases, FHIR servers |
| **2** | 🗺️ Map Columns | Map dataset columns to Open DQA target fields with gender value standardization |
| **3** | ✅ Select Checks | Browse and select from 77 built-in checks, organized by category with availability indicators |
| **4** | ✏️ Custom Checks | Build institution-specific rules using the visual rule editor |
| **5** | 📊 Results | Interactive dashboard with quality score, severity analysis, and category breakdown |
| **6** | 🧹 Cleansing | Guided data cleansing with assistant, full audit trail, and final documentation |
>>>>>>> 3f7f6b461c608d0b5eef6abbdc3cbde882860e00

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
- No LaTeX, Pandoc, or TinyTeX required (reports are generated as Word .docx via `officer`)

### R Package Dependencies

**Core dependencies** (16 packages, required):

| Package | Purpose |
|---|---|
| `shiny` | Web application framework |
| `bs4Dash` | Bootstrap 4 dashboard UI |
| `DT` | Interactive data tables |
| `readxl` | Excel file import |
| `jsonlite` | JSON parsing (including FHIR R4 bundles) |
| `stringr` | String manipulation and regex-based code validation |
| `dplyr` | Data manipulation |
| `lubridate` | Date/time handling |
| `rlang` | Tidy evaluation |
| `data.table` | High-performance data import via `fread()` |
| `shinyjs` | JavaScript operations in Shiny |
| `shinyWidgets` | Enhanced UI widgets |
| `waiter` | Loading spinners and overlays |
| `officer` | Word (.docx) report generation |
| `flextable` | Formatted tables in Word reports |
| `plogr` | Logging |

**Optional dependencies** (5 packages):

| Package | Purpose |
|---|---|
<<<<<<< HEAD
| `cluster` | Listed in the application header; imported at startup if available. Not actively invoked in the current version (V1.0). |
=======
| `cluster` | clustering for anomaly detection |
>>>>>>> 3f7f6b461c608d0b5eef6abbdc3cbde882860e00
| `emayili` | Email report delivery via SMTP |
| `DBI` + `RPostgres` | PostgreSQL database connectivity |
| `DBI` + `odbc` | Microsoft SQL Server connectivity |

---

## Installation

### Option 1: Clone from GitHub

```bash
<<<<<<< HEAD
git clone https://github.com/gkamdje/OpenDQA.git
=======
# 1. Clone the repository
git clone  https://github.com/gaetankamdje-wabo/OpenDQA.git

# 2. Navigate into the project directory
>>>>>>> 3f7f6b461c608d0b5eef6abbdc3cbde882860e00
cd OpenDQA
Rscript install_dependencies.R
Rscript -e "shiny::runApp('app.R', launch.browser = TRUE)"
```

### Option 2: Download ZIP Archive

1. Click **Code → Download ZIP** on the GitHub repository page.
2. Extract the archive.
3. Run `Rscript install_dependencies.R`.
4. Open `app.R` in RStudio and click **Run App**.

---

## Quick Start

<<<<<<< HEAD
1. Launch: `shiny::runApp("app.R", launch.browser = TRUE)`
2. Accept the research tool disclaimer.
3. **Step 1**: Select data source and upload or connect.
4. **Step 2**: Map columns to 9 target fields; configure gender value standardization.
5. **Step 3**: Select built-in checks.
6. **Step 4**: Optionally define custom checks or invoke the statistical analysis assistant.
7. **Step 5**: Review results and export reports (Word, CSV).
8. **Step 6**: Perform guided cleansing with audit trail.
=======
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
>>>>>>> 3f7f6b461c608d0b5eef6abbdc3cbde882860e00

---

## Data Format

Open DQA uses a column mapping wizard (Step 2) to map source columns to the following **9 target fields**:

| Target Field | Type | Required | Description |
|---|---|---|---|
| `patient_id` | character | Yes | Unique patient identifier |
| `icd` | character | Yes | ICD-10 diagnosis code(s); semicolon-separated for multiple codes |
| `ops` | character | No | OPS procedure code(s); semicolon-separated for multiple codes |
| `gender` | character | Yes | Patient gender (normalized via configurable mapping) |
| `admission_date` | date | Yes | Hospital admission date (YYYY-MM-DD) |
| `discharge_date` | date | Yes | Hospital discharge date (YYYY-MM-DD) |
| `age` | numeric | No | Patient age at admission |
| `birth_date` | date | No | Patient date of birth (YYYY-MM-DD) |
| `anamnese` | character | No | Clinical narrative / anamnesis free text |

Gender standardization accepts configurable comma-separated value lists (default: `m, male, M, 1, Mann` → male; `f, female, F, 2, Frau` → female).

See [docs/data_format.md](docs/data_format.md) for the full specification including ICD-10 and OPS validation patterns.

---

## Data Sources

| Source | Formats / Details |
|---|---|
| **Local File** | CSV/TXT (configurable separator, up to 2 GB via `data.table::fread()`), Excel (.xlsx/.xls), JSON (standard, NDJSON, nested with auto-flattening), FHIR Bundle (R4) |
| **SQL Database** | PostgreSQL (`RPostgres`), Microsoft SQL Server (`odbc`). Built-in query templates for i2b2 and OMOP CDM schemas. Connection testing, timeout configuration, retry logic. |
| **FHIR Server** | Direct HTTP connection to FHIR R4 servers via `httr`. Extracts Patient, Encounter, Condition, Procedure resources. |

---

## Configuration

Application configuration is managed via `config/settings.yml`:

```yaml
thresholds:
  completeness_warning: 0.95
  completeness_critical: 0.80
  max_patient_age: 125
  min_patient_age: 0
  max_los: 365

<<<<<<< HEAD
=======


# Reporting
>>>>>>> 3f7f6b461c608d0b5eef6abbdc3cbde882860e00
reporting:
  default_language: "en"           # en | de | fr
  institution_name: "Your Institution"
  logo_path: "assets/logo.png"

email:
  enabled: false
  smtp_host: ""
  smtp_port: 587

logging:
  enabled: true
  log_path: "logs/session_log.csv"
```

---

<<<<<<< HEAD
## Statistical Analysis Assistant

Open DQA includes a **statistical analysis assistant** that complements the 77 rule-based checks by analyzing uploaded data and generating data-driven custom check suggestions. This assistant employs exclusively **classical statistical and heuristic methods**.
=======
## Assisted Features

Open DQA integrates optional assistance:
>>>>>>> 3f7f6b461c608d0b5eef6abbdc3cbde882860e00

### Implemented Methods

The following table enumerates all statistical methods implemented in the assistant, their application context, and their scholarly references:

| Method | Function in `app.R` | Application | Scholarly Reference |
|---|---|---|---|
| **Tukey's IQR-based outlier detection** | `ai_numeric_anomalies()` | Identifies mild (1.5 × IQR) and extreme (3 × IQR) outliers in numeric columns | Tukey, J. W. (1977). *Exploratory Data Analysis*. Addison-Wesley. |
| **Z-score analysis** | `ai_numeric_anomalies()` | Flags values with \|Z\| > 4 in approximately normal distributions (n > 30) | — (standard parametric method) |
| **Domain-specific heuristic rules** | `ai_numeric_anomalies()` | Detects impossible values based on column name pattern matching (e.g., negative age, age > 130) | — (rule-based) |
| **Digit preference analysis** | `ai_numeric_anomalies()` | Identifies rounding bias and terminal digit clustering via Chi-squared goodness-of-fit test (df = 9, α = 0.001) | — (epidemiological method) |
| **Levenshtein edit distance** | `ai_categorical_anomalies()` | Identifies likely typographical errors among categorical values by comparing rare values against frequent values via `utils::adist()` | Levenshtein, V. I. (1966). Binary codes capable of correcting deletions, insertions, and reversals. *Soviet Physics Doklady*, 10(8), 707–710. |
| **Shannon entropy** | `ai_entropy()`, `ai_entropy_anomalies()` | Detects constant columns (entropy = 0) and suspiciously uniform distributions | Shannon, C. E. (1948). A mathematical theory of communication. *Bell System Technical Journal*, 27(3), 379–423. |
| **Frequency analysis** | `ai_categorical_anomalies()` | Identifies rare values (< 1% prevalence), case inconsistencies, and whitespace anomalies | — (descriptive statistics) |
| **Chi-squared test of independence with Cramér's V** | `ai_cross_missing_pattern()` | Detects conditional missing patterns (Missing At Random) across column pairs | Cramér, H. (1946). *Mathematical Methods of Statistics*. Princeton University Press. |
| **Spearman rank correlation** | `ai_cross_correlation()` | Identifies cross-column monotonic correlations that may indicate redundancy or dependency | Spearman, C. (1904). The proof and measurement of association between two things. *American Journal of Psychology*, 15(1), 72–101. |
| **Benford's Law deviation** | `ai_benfords_law()` | Flags potential data fabrication by comparing leading-digit distributions against the expected Benford distribution via Chi-squared goodness-of-fit | Benford, F. (1938). The law of anomalous numbers. *Proceedings of the American Philosophical Society*, 78(4), 551–572. |
| **Date ordering validation** | `ai_cross_date_order()` | Detects chronological violations across all date field pairs | — (logical constraint) |
| **Format consistency analysis** | `ai_cross_format_consistency()` | Identifies formatting inconsistencies across related column groups | — (heuristic) |
| **Rule-based column type classifier** | `ai_type_classifier()` | Determines semantic column types (numeric, date, ICD code, OPS code, free text, etc.) via regex patterns, value-ratio analysis, and cardinality heuristics | — (rule-based heuristic) |

**Note on the `cluster` package**: The R package `cluster` is listed in the application header (line 25 of `app.R`) and is conditionally loaded at startup (line 45–46). However, no functions from this package (e.g., `pam()`, `clara()`, `agnes()`) are invoked anywhere in the current codebase (V1.0). The package dependency is vestigial.

All suggestions generated by the statistical analysis assistant are advisory and require explicit user confirmation before inclusion in the formal quality assessment.

---

## Reporting

Open DQA generates reports in the following formats:

| Format | Method | Description |
|---|---|---|
| **Word (.docx)** | `officer` + `flextable` | Publication-ready proof document. No LaTeX dependency required. |
| **CSV** | Base R | Machine-readable results table for downstream processing. |

### Word Report Contents

The Word report is structured as a quality assessment proof document containing:

- **Cryptographic session fingerprint** (`ODQA-XXXXXXXXXX`) for document integrity verification
- **Data protection statement** confirming exclusion of patient identifiers from the report
- **Tool metadata**: Application name, version (V0.1 as displayed in UI), R version, timestamp, document ID
- **Dataset summary**: Record count, column count, checks executed, custom checks, records with issues, total issues, quality score
- **Quality score**: Computed as `Q = 100% × (1 − affected_records / total_records)` with color-band interpretation (Green ≥ 80%, Yellow ≥ 60%, Orange ≥ 40%, Red < 40%)
- **Methodology section**: Description of the assessment approach (built-in rule-based checks, custom checks, statistical analysis assistant)
- **Severity distribution**: Per-category issue counts and percentages
- **Per-check results**: Individual check status, description, affected count, and severity for every executed check
- **Custom check documentation**: All user-defined rules with creation metadata
- **Fitness-for-purpose interpretation**: Contextual assessment of data suitability for the intended research purpose
- **Cleansing audit trail**: Complete log of all modifications performed during the cleansing step
- **Certification statement** with session fingerprint

---

## Multilingual Support

The complete application UI, check descriptions, disclaimer, tutorial, FAQ, and report content are available in:

- **English** (`en`)
- **German** (`de`)
- **French** (`fr`)

Language is selectable via the in-app dropdown in the top navigation bar. All translation strings are maintained inline in the `I18N` list in `app.R` (Section 2).

---

## Test Data and Validation

### Test Dataset

- **File**: `data/Test_Data.csv`
- **Records**: 1,588 synthetic patient records (no real patient data)
- **Columns**: 9 (`patient_id`, `icd`, `ops`, `gender`, `admission_date`, `discharge_date`, `age`, `birth_date`, `anamnese`)
- **Design**: Contains deliberately seeded quality issues covering all 77 check categories
- **Patient ID convention**: `T_catX_Y` maps to check category and number (e.g., `T_cat1_1` triggers check `cat1_1`)

### Expected Results

- **File**: `data/open_dqa_expected_hits.csv`
- **Structure**: Two columns (`check_id`, `patient_id`)
- **Entries**: 87 expected hits covering all 77 checks

### Validation

```r
source("tests/run_validation.R")
```

---

## Project Structure

```
OpenDQA/
├── app.R                          # Main application (approximately 7,900 lines, 12 sections)
├── install_dependencies.R         # Automated package installer
├── R/                             # Modular source files (reserved for future refactoring)
│   ├── checks/                    # Check implementation functions
│   ├── ui/                        # UI modules
│   ├── server/                    # Server-side modules
<<<<<<< HEAD
│   ├── reporting/                 # Report generation
│   ├── assistance/                # Statistical analysis assistant
=======
│   ├── reporting/                 # Report generation functions
│   ├── assistance/                #  integration
>>>>>>> 3f7f6b461c608d0b5eef6abbdc3cbde882860e00
│   └── utils/                     # Utility functions
├── config/
│   └── settings.yml               # Application configuration
├── data/
│   ├── Test_Data.csv              # Synthetic test dataset (1,588 records)
│   └── open_dqa_expected_hits.csv # Expected check results for validation
├── docs/                          # Extended documentation
│   ├── installation.md
│   ├── user_guide.md
│   ├── checks_reference.md
│   └── data_format.md
├── i18n/                          # Multilingual resources (reserved)
├── reports/templates/             # Report templates (reserved)
├── tests/run_validation.R         # Validation script
├── assets/                        # Images, logos
├── logs/                          # Session logs
├── .github/                       # Issue and PR templates
├── CHANGELOG.md
├── CITATION.cff
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── SECURITY.md
└── LICENSE                        # MIT License
```

---

## Contributing

Contributions from the medical informatics, health data science, and clinical engineering communities are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on reporting bugs, adding new checks, improving translations, and the pull request process.

---

## Citation

```bibtex
@software{opendqa2025,
  author    = {Kamdje Wabo, Gaetan and Sokolowski, P. and Ganslandt, T. and Siegel, F.},
  title     = {{Open DQA}: An Open-Source {R Shiny} Application for Clinical Data Quality Assessment},
  year      = {2025},
  version   = {1.0},
  url       = {https://github.com/gkamdje/OpenDQA},
  note      = {MIISM, Klinikum Mannheim GmbH and Universit{\"a}t Heidelberg}
}
```

A manuscript has been submitted to **JMIR Medical Informatics**. See [CITATION.cff](CITATION.cff) for machine-readable citation metadata.

---

## License

MIT License. See [LICENSE](LICENSE).

© 2025 Open DQA Contributors. MIISM, Klinikum Mannheim GmbH / Universität Heidelberg.

---

## Contact

- **Lead Developer**: Gaetan Kamdje Wabo — [gaetankamdje.wabo@medma.uni-heidelberg.de](mailto:gaetankamdje.wabo@medma.uni-heidelberg.de) | [gaetan.kamdje-wabo@umm.de](mailto:gaetan.kamdje-wabo@umm.de)
<<<<<<< HEAD
- **Institution**: MIISM, Universität Heidelberg
- **Issues**: [GitHub Issues](https://github.com/gkamdje/OpenDQA/issues)
- **Security**: Email directly; do not open public issues.
=======
- **Institution**: MIISM — Medical Informatics in Translational and Integrated Medicine, Universität Heidelberg
- **Issues & Bug Reports**: [GitHub Issues](https://github.com/gkamdje/OpenDQA/issues)
- **Security Disclosures**: Please email directly rather than opening a public issue.

---

>>>>>>> 3f7f6b461c608d0b5eef6abbdc3cbde882860e00
