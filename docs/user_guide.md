# User Guide

This guide walks through a complete Open DQA assessment workflow, from data upload to report export and data cleansing.

---

## Launching the Application

```r
shiny::runApp("app.R", launch.browser = TRUE)
```

The application opens in the default web browser. For optimal display, use **Google Chrome** or **Mozilla Firefox**.

---

## Navigation Overview

Open DQA uses a guided wizard with top navigation pills (numbered 0–6):

| Step | Name | Purpose |
|---|---|---|
| **0** | Home / Welcome | Feature overview, tutorial access, disclaimer |
| **T** | Tutorial | Interactive walkthrough of all features |
| **1** | Load Data | Multi-source data import |
| **2** | Map Columns | Column mapping and gender standardization |
| **3** | Select Checks | Choose built-in checks to run |
| **4** | Custom Checks | Build institution-specific rules; invoke statistical analysis assistant |
| **5** | Results | Interactive dashboard with quality score |
| **6** | Cleansing | Guided data cleansing and final documentation |

Navigation pills unlock progressively as each step is completed.

---

## Step 0: Welcome and Disclaimer

On first launch:

1. **Disclaimer**: A research tool notice must be accepted before proceeding. Open DQA is not a certified medical device — this acknowledgment is required before data processing begins.
2. **Welcome Page**: Overview of features with two options:
   - **Take the Tutorial**: Step-by-step guide for new users.
   - **Proceed to Assessment**: Proceed directly into the workflow.

The welcome page also displays a workflow diagram, a "Who Is This For?" section, feature cards, and an FAQ.

---

## Step T: Tutorial

The interactive tutorial walks through every feature with concrete examples. It is accessible from the welcome page or the navigation bar.

---

## Step 1: Load Data

Three data source options are available via tabs:

### Local File Upload
1. Select **Format**: CSV/TXT, Excel, JSON, or FHIR Bundle.
2. For CSV: Configure separator (`,`, `;`, tab) and header row option.
3. For Excel: Select sheet number.
4. Click **Upload** and select the file (up to 2 GB).
5. Click the **Load** button.

### SQL Database
1. Select **Type**: PostgreSQL or Microsoft SQL Server.
2. Enter connection details: Host, Port, Database, User, Password.
3. Click **Test** to verify the connection.
4. Use a template query (Basic SELECT, i2b2, or OMOP CDM) or write custom SQL.
5. Click **Run Query**.

### FHIR Server
Direct connection to FHIR R4 servers for live data retrieval.

After loading, a data preview is displayed showing the first rows and column names.

---

## Step 2: Map Columns

The column mapping interface presents all 9 target fields with dropdown selectors populated from the dataset's column names:

| Target | Status |
|---|---|
| `patient_id` | Required |
| `icd` | Required |
| `ops` | Optional |
| `gender` | Required |
| `admission_date` | Required |
| `discharge_date` | Required |
| `age` | Optional |
| `birth_date` | Optional |
| `anamnese` | Optional |

### Gender Value Standardization

Below the column mapping, configure how the dataset encodes gender:

- **Male values**: Comma-separated list (default: `m, male, M, 1, Mann`)
- **Female values**: Comma-separated list (default: `f, female, F, 2, Frau`)

Click **Save and Continue** to proceed. Dates are automatically parsed and the gender column is standardized.

---

## Step 3: Select Built-in Checks

The 77 built-in checks are displayed in 6 color-coded categories:

- **Completeness** (16 checks)
- **Age Plausibility** (15 checks)
- **Gender Plausibility** (15 checks)
- **Temporal Consistency** (6 checks)
- **Diagnosis–Procedure Consistency** (15 checks)
- **Code Integrity** (10 checks)

Each check displays its ID (e.g., `cat1_1`), name, description, and availability status. Checks requiring unmapped columns are dimmed and marked with "(needs: column_name)".

Use **Select All** / **Deselect All** buttons for convenience.

---

## Step 4: Custom Check Builder

Define institution-specific rules without writing R code:

1. Select a **column** to validate.
2. Choose a **constraint type**: `is_not.na`, `not_contains`, `BETWEEN`, `NOT BETWEEN`, `IN()`, `NOT IN()`, `REGEXP`.
3. Provide **values/parameters**.
4. Set **severity** and **name**.
5. Click **Add Check**.

Custom checks are displayed in a table below the builder, included in the assessment alongside built-in checks, and exportable/importable as JSON for cross-institutional sharing.

### Statistical Analysis Assistant

Optionally, the statistical analysis assistant can be invoked to analyze the uploaded data and suggest additional custom checks. This assistant uses classical statistical and heuristic methods (IQR outlier detection, Z-score analysis, Levenshtein distance for typo detection, Shannon entropy, Benford's Law, Chi-squared, Spearman correlation) to identify potential data quality issues not covered by the built-in checks. All suggestions require explicit user confirmation before inclusion.

---

## Step 5: Results and Data Fitness

After clicking **Run All Checks**, the results dashboard displays:

### Quality Score
`Quality Score = 100% × (1 − affected_records / total_records)`

Color bands:
- Green: 100–80% (High quality)
- Yellow: 79–60% (Moderate issues)
- Orange: 59–40% (Significant issues)
- Red: < 40% (Critical issues)

### Results Overview
- Total checks executed
- Total issues found
- Category-wise severity breakdown
- Per-check results table with status, description, affected count, and severity

### Report Export
Generate reports directly from the results view:
- **Word (.docx)**: Publication-ready proof document with cryptographic session fingerprint.
- **CSV**: Machine-readable results for downstream processing.

---

## Step 6: Cleansing and Documentation

Guided data cleansing with full audit trail:

### Cleansing Workflow
- Step-by-step data modification guided by detected issues
- Each modification is logged (what was changed, when, by which action)
- Full audit trail for regulatory compliance documentation

### Final Export
- **Cleaned Data**: Download the cleansed dataset as CSV.
- **Cleansing Log**: Word document with complete audit trail.
- **Final Assessment Report**: Word document certifying the assessment with session fingerprint.

---

## Frequently Asked Questions

The built-in FAQ (accessible from the Welcome page) covers common questions in all three supported languages, including:

- How to share custom checks between colleagues
- Data privacy and security considerations
- Interpretation of quality scores
- Support for different data standards (i2b2, OMOP, FHIR)

---

## Performance Considerations

| Records | Estimated Time |
|---|---|
| 1,000 | < 5 seconds |
| 50,000 | 15–30 seconds |
| 500,000 | 2–5 minutes |

For datasets exceeding 500,000 records, ensure at least 16 GB of RAM is available.

---

## Session Logging

Assessment sessions are logged for audit purposes. Logs include timestamps, dataset characteristics, quality scores, and session metadata.
