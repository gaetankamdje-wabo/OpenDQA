# Open DQA - Data Quality Assessment for Clinical Research

**Open DQA** is an open-source, browser-based platform for systematic data quality assessment and cleansing of clinical datasets. Built as an R/Shiny application, it implements a fitness-for-purpose approach: data quality is evaluated against the specific requirements of the user's research question.

Developed at the Mannheim Institute for Intelligent Systems in Medicine (MIISM), Medical Faculty Mannheim, University of Heidelberg.



## Purpose

Clinical research depends on data quality for specific research questions. Open DQA provides a structured, transparent, and reproducible workflow to assess, document, and improve the quality of clinical datasets before analysis. It supports the generation of publication-ready reports with full audit trails that satisfy documentation requirements for Good Clinical Practice (ICH E6(R2)), GDPR, ISO 14155, and FAIR principles.



## Features

| Capability | Description |
|---|---|
| **Multi-format import** | CSV, Excel, JSON, FHIR Bundle, SQL (PostgreSQL, MS SQL Server) |
| **77 built-in plausibility checks** | Organized in 6 categories across clinical data quality dimensions |
| **Custom rule builder** | Define fitness-for-purpose checks with a visual condition builder; import/export as JSON |
| **Guided data cleansing** | Issue-by-issue, patient-by-patient review with keep / modify / remove decisions |
| **Full audit trail** | Every data modification is timestamped and logged with old/new values |
| **Publication-ready reports** | Word (.docx) and CSV exports with severity charts, session fingerprints, and certification footers |
| **Trilingual interface** | English, German, French |
| **Quality Score** | `100 × (1 − affected_records / total_records)` with severity-banded interpretation |



## Built-in Checks (77 total)

All checks are defined in the `CL` list in `app.R` and documented in `docs/OpenDQA_Checks_Metadata.xlsx`.

| # | Category | Checks | Required Columns | Examples |
|---|---|---|---|---|
| 1 | **Completeness** | 16 | `admission_date`, `icd`, `ops`, `anamnese` | Missing ICD on admission; surgery mention without OPS code; diabetes in notes without E10–E14 |
| 2 | **Age Plausibility** | 15 | `age`, `icd` | Prostate cancer (C61) at age < 15; Alzheimer (F00/G30) at age < 30 |
| 3 | **Gender Plausibility** | 15 | `gender`, `icd` | Pregnancy codes (O-chapter) in male patient; prostatitis (N41) in female patient |
| 4 | **Temporal Consistency** | 6 | `admission_date`, `discharge_date`, `birth_date`, `ops`, `patient_id` | Discharge before admission; admission before birth; future admission dates |
| 5 | **Diagnosis–Procedure Consistency** | 15 | `ops`, `icd`, `gender` | Appendectomy OPS without K35 ICD; C-section OPS in male patient |
| 6 | **Code Integrity** | 10 | `icd`, `ops` | Invalid ICD-10 syntax; OPS structural errors; ICD-9 codes in ICD-10 context; placeholder codes |

Checks are designed to work with any ICD-10 variant. Some completeness checks use keyword matching in the `anamnese` (clinical notes) field.

---

## Workflow

The application follows a six-step linear workflow:

```
Step 1       Step 2       Step 3          Step 4          Step 5         Step 6
Load Data → Map Columns → Select Built-in → Build Custom → View Results → Cleanse &
                          Checks           Checks         & Score        Document
```

1. **Load Dataset** - Upload or connect to a data source.
2. **Map Columns** - Assign dataset columns to standard fields (`patient_id`, `icd`, `ops`, `gender`, `admission_date`, `discharge_date`, `age`, `birth_date`, `anamnese`). Auto-detection pre-fills likely matches.
3. **Select Built-in Checks** - Choose from 77 checks. Checks requiring unmapped columns are automatically greyed out.
4. **Build Custom Checks** - Define additional fitness-for-purpose rules using a visual condition builder (column vs. value, column vs. column, with AND/OR logic). Checks are stored with name, severity, and description.
5. **Results & Quality Score** - View the overall quality score, severity distribution, category breakdown, and detailed issue table.
6. **Data Cleansing** - Navigate issues patient-by-patient, apply corrections (keep, modify, remove), perform bulk operations, and export the cleaned dataset with a complete change log.



## Data Elements

Open DQA expects clinical datasets with the following standard fields (all optional; checks adapt to available columns):

| Field | Type | Description |
|---|---|---|
| `patient_id` | String | Unique patient or case identifier |
| `icd` | String | ICD-10 diagnosis code(s), semicolon-separated if multiple |
| `ops` | String | OPS procedure code(s), semicolon-separated if multiple |
| `gender` | String | Patient gender (configurable value mapping) |
| `admission_date` | Date | Hospital admission date |
| `discharge_date` | Date | Hospital discharge date |
| `age` | Numeric | Patient age in years |
| `birth_date` | Date | Patient date of birth |
| `anamnese` | String | Free-text clinical notes |



## Quality Score

```
Quality Score = 100 × (1 − affected_records / total_records)
```

| Score Range | Band | Interpretation |
|---|---|---|
| 100–80 | Green | Excellent — data ready for analysis |
| 79–60 | Yellow | Minor issues — unlikely to significantly affect results |
| 59–40 | Orange | Moderate issues — may introduce bias; targeted cleansing recommended |
| < 40 | Red | Critical — do not use data without resolving issues first |



## Installation and Usage

### Requirements

- **R** ≥ 4.1
- R packages (installed automatically on first run):

```
shiny, bs4Dash, DT, readxl, jsonlite, stringr, dplyr, lubridate,
rlang, data.table, shinyjs, shinyWidgets, waiter, officer, flextable, plogr
```

Optional packages for extended features:

| Package | Feature |
|---|---|
| `cluster` | Cluster-based data analysis in the assistant |
| `emayili` | Email integration for report delivery |
| `DBI` + `RPostgres` | PostgreSQL database connectivity |
| `DBI` + `odbc` | MS SQL Server database connectivity |

### Run

```r
shiny::runApp("app.R")
```

The application opens in the default browser. Maximum upload size is 2 GB.



## Test Data

The `data/` directory contains validation datasets:

| File | Description |
|---|---|
| `open_dqa_testdata.csv` | 1,589 synthetic clinical records designed to trigger all 77 built-in checks. Patient IDs follow the pattern `T_catX_Y` to identify which check each record should trigger. |
| `open_dqa_expected_hits.csv` | Ground truth: maps each `check_id` to the `patient_id`(s) expected to be flagged. Used for verification of check correctness. |
| `Test_Data.csv` | Identical to `open_dqa_testdata.csv`. Provided as a user-facing sample dataset. |

### Test data structure

Each record contains exactly the data elements needed to trigger one specific check:
- **Completeness records** (`T_cat1_*`): Include clinical note keywords (e.g., "surgery", "diabetes") with deliberately missing ICD or OPS codes.
- **Age plausibility records** (`T_cat2_*`): Pair clinically implausible age values with specific ICD codes.
- **Gender plausibility records** (`T_cat3_*`): Pair gender-specific diagnoses with the wrong gender.
- **Temporal records** (`T_cat4_*`): Contain impossible date sequences (e.g., discharge before admission).
- **Diagnosis–procedure records** (`T_cat5_*`): Pair procedure codes with missing or mismatched diagnoses.
- **Code integrity records** (`T_cat6_*`): Contain syntactically invalid, deprecated, or placeholder codes.



## Report Generation

Open DQA generates two types of Word documents via the `officer` and `flextable` packages:

### Data Quality Report
- Tool metadata and version
- Assessment parameters (checks selected, columns mapped)
- Per-check results with descriptions and affected record counts
- Severity distribution chart
- Category breakdown chart
- Data integrity fingerprint (hex-encoded hash of column signature + dimensions)
- Session hash for traceability
- Certification footer

### Cleansing Change Log
- Regulatory context table (ICH E6(R2), GDPR, FAIR, FDA 21 CFR Part 11, ISO 14155, OECD GLP)
- Sequential modification register with timestamp, action, column, row scope, and old/new values
- Document integrity hash

Patient identifiers are automatically redacted in email-delivered reports.



## Repository Structure

```
OpenDQA/
├── app.R                              # Complete application (UI + server + checks)
├── data/
│   ├── open_dqa_testdata.csv          # Synthetic test dataset (1,589 records)
│   ├── open_dqa_expected_hits.csv     # Ground truth for check verification
│   └── Test_Data.csv                  # User-facing sample dataset
├── docs/
│   └── OpenDQA_Checks_Metadata.xlsx   # Full check catalog with metadata
├── README.md
├── LICENSE
├── .gitignore
└── CHANGELOG.md
```



## Disclaimer

Open DQA is an open-source research tool developed at Heidelberg University (MIISM). It is **not** a certified medical product under EU MDR, FDA, or any regulatory framework and must not be used as a basis for clinical decisions. The user is solely responsible for validating and interpreting all results.



## License

MIT License — see [LICENSE](LICENSE).


## Authors

G. Kamdje Wabo, P. Sokolowski, T. Ganslandt, F. Siegel

Mannheim Institute for Intelligent Systems in Medicine (MIISM)  
Medical Faculty Mannheim, Heidelberg University



## Citation

If you use Open DQA in your research, please cite:

```
Kamdje Wabo G, Sokolowski P, Ganslandt T, Siegel F.
Open DQA: An Open-Source Platform for Fitness-for-Purpose Data Quality Assessment in Clinical Research.
Heidelberg University, 2026.
```
