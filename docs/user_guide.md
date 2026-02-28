# User Guide

This guide walks through a complete Open DQA assessment workflow, from data upload to report export and data cleansing.

---

## Launching the Application

```r
shiny::runApp("app.R", launch.browser = TRUE)
```

The application opens in your default web browser. For best experience, use **Google Chrome** or **Mozilla Firefox**.

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
| **4** | Custom Checks | Build institution-specific rules |
| **5** | Results | Interactive dashboard with quality score |
| **6** | Cleansing | Guided data cleansing and final documentation |

Navigation pills unlock progressively as you complete each step.

---

## Step 0: Welcome & Disclaimer

On first launch, you will see:

1. **Disclaimer**: A research tool notice that must be accepted before proceeding. Open DQA is NOT a medical device — this is acknowledged before data processing begins.
2. **Welcome Page**: Overview of features with two options:
   - **Take the Tutorial**: Step-by-step guide for new users
   - **Proceed to Assessment**: Jump directly into the workflow

The welcome page also displays a "How It Works" workflow diagram, "Who Is This For?" section, feature cards, and FAQ.

---

## Step T: Tutorial

The interactive tutorial walks through every feature with concrete examples. Accessible from the welcome page or the navigation bar. Covers:

- Data import options
- Column mapping
- Check selection and execution
- Custom check building
- Result interpretation
- Report generation
- Data cleansing

---

## Step 1: Load Data

Three data source options are available via tabs:

### Local File Upload
1. Select **Format**: CSV/TXT, Excel, JSON, or FHIR Bundle
2. For CSV: Configure separator (`,`, `;`, tab) and header row option
3. For Excel: Select sheet number
4. Click **Upload** and select your file (up to 2 GB)
5. Click the **Load** button

### SQL Database
1. Select **Type**: PostgreSQL or Microsoft SQL Server
2. Enter connection details: Host, Port, Database, User, Password
3. Click **Test** to verify the connection
4. Use a template query (Basic SELECT, i2b2, or OMOP CDM) or write your own SQL
5. Click **Run Query**

### FHIR Server
Direct connection to FHIR R4 servers for live data retrieval.

After loading, a data preview is displayed showing the first rows and column names.

---

## Step 2: Map Columns

The column mapping interface shows all 9 target fields with dropdown selectors populated from your dataset's column names:

| Target | Your Column | Status |
|---|---|---|
| `patient_id` | *(auto-detected or select)* | Required |
| `icd` | *(auto-detected or select)* | Required |
| `ops` | *(auto-detected or select)* | Optional |
| `gender` | *(auto-detected or select)* | Required |
| `admission_date` | *(auto-detected or select)* | Required |
| `discharge_date` | *(auto-detected or select)* | Required |
| `age` | *(auto-detected or select)* | Optional |
| `birth_date` | *(auto-detected or select)* | Optional |
| `anamnese` | *(auto-detected or select)* | Optional |

### Gender Value Standardization

Below the column mapping, configure how your dataset encodes gender:

- **Male values**: Comma-separated list (default: `m, male, M, 1, Mann`)
- **Female values**: Comma-separated list (default: `f, female, F, 2, Frau`)

Click **Save & Continue** to proceed. Dates are automatically parsed and the gender column is standardized.

---

## Step 3: Select Built-in Checks

The 77 built-in checks are displayed in 6 color-coded categories:

- 📋 **Completeness** (16 checks, blue)
- 👶 **Age Plausibility** (15 checks, purple)
- ⚧ **Gender Plausibility** (15 checks, pink)
- 🕒 **Temporal Consistency** (6 checks, amber)
- 🏥 **Diagnosis–Procedure** (15 checks, green)
- 🔍 **Code Integrity** (10 checks, red)

Each check displays:
- Check ID (e.g., `cat1_1`)
- Check name and description
- Availability status: Checks requiring unmapped columns are dimmed and marked with "(needs: column_name)"

Use **Select All** / **Deselect All** buttons for convenience.

---

## Step 4: Custom Check Builder

Define institution-specific rules without writing R code:

1. Select a **column** to validate
2. Choose a **constraint type**: `is_not.na`, `not_contains`, `BETWEEN`, `NOT BETWEEN`, `IN()`, `NOT IN()`, `REGEXP`
3. Provide **values/parameters**
4. Set **severity** and **name**
5. Click **Add Check**

Custom checks are:
- Displayed in a table below the builder
- Included in the assessment alongside built-in checks
- Exportable as JSON for sharing with colleagues
- Importable from JSON files

---

## Step 5: Results & Data Fitness

After clicking **Run All Checks**, the results dashboard displays:

### Quality Score
`Quality Score = 100% × (1 − affected_records / total_records)`

Color bands:
- 🟢 Green: 100–80% (High quality)
- 🟡 Yellow: 79–60% (Moderate issues)
- 🟠 Orange: 59–40% (Significant issues)
- 🔴 Red: <40% (Critical issues)

### Results Overview
- Total checks executed
- Total issues found
- Category-wise severity breakdown
- Per-check results table with status, description, affected count, and severity

### Report Export
Generate reports directly from the results view:
- **Word (.docx)**: Publication-ready proof document with cryptographic session fingerprint
- **CSV**: Machine-readable results for downstream processing

---

## Step 6: Cleansing & Documentation

Guided data cleansing with full audit trail:

### ML-Assisted Cleansing
When the `cluster` package is available, the ML-based Cleansing Assistant provides:
- Cluster-based anomaly detection
- Automated correction proposals
- User-controlled accept/reject decisions

### Manual Cleansing
Step-by-step data modification with:
- Action logging (what was changed, by whom, when)
- Full audit trail for GCP compliance

### Final Export
- **Cleaned Data**: Download the cleansed dataset as CSV
- **Cleansing Log**: Word document with complete audit trail
- **Final Assessment Report**: Word document certifying the assessment with session fingerprint

---

## Frequently Asked Questions

The built-in FAQ (accessible from the Welcome page) covers common questions in all three languages, including:

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

For very large datasets (>500,000 records), ensure at least 16 GB of RAM is available.

---

## Session Logging

Assessment sessions are logged for audit purposes. Logs include timestamps, dataset characteristics, quality scores, and session metadata.
