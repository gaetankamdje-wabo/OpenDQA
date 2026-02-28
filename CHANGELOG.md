# Changelog

All notable changes to Open DQA are documented in this file. This project adheres to [Semantic Versioning](https://semver.org/).

---

## [1.0] — 2025

### Initial Public Release

#### Core Assessment Engine
- 77 rule-based data quality checks across 6 quality dimensions
  - Category 1: Completeness (16 checks, `cat1_1`–`cat1_16`)
  - Category 2: Age Plausibility (15 checks, `cat2_1`–`cat2_15`)
  - Category 3: Gender Plausibility (15 checks, `cat3_1`–`cat3_15`)
  - Category 4: Temporal Consistency (6 checks, `cat4_2`, `cat4_4`, `cat4_6`, `cat4_8`, `cat4_12`, `cat4_15`)
  - Category 5: Diagnosis–Procedure Consistency (15 checks, `cat5_1`–`cat5_15`)
  - Category 6: Code Integrity (10 checks, `cat6_1`–`cat6_9`, `cat6_11`)
- Quality score computation: `Q = 100% × (1 − affected_records / total_records)`
- Per-check impact metrics with severity classification

#### Statistical Analysis Assistant
- Per-column analysis: IQR-based outlier detection (Tukey, 1977), Z-score analysis, domain-specific heuristic rules, digit preference analysis
- Categorical analysis: Levenshtein edit distance for typo detection, frequency analysis, case inconsistency detection, whitespace anomaly detection
- Cross-column analysis: Spearman rank correlation, Chi-squared with Cramér's V for conditional missing patterns, multi-column duplicate fingerprinting
- Distribution analysis: Shannon entropy for constant/uniform column detection, Benford's Law deviation for data fabrication indicators
- Date analysis: Chronological violation detection across all date field pairs, future date detection, weekend/holiday clustering
- Heuristic column type classifier (numeric, integer, date, datetime, categorical, binary, ICD code, OPS code, free text, mixed)

#### Data Import
- Local file upload: CSV/TXT (via `data.table::fread()`, up to 2 GB), Excel (.xlsx/.xls), JSON (standard, NDJSON, nested), FHIR R4 Bundle
- SQL database connectivity: PostgreSQL (`RPostgres`), Microsoft SQL Server (`odbc`)
- Built-in SQL query templates for i2b2 and OMOP CDM schemas
- FHIR R4 server connectivity via `httr`

#### Column Mapping and Standardization
- Interactive column mapping wizard for 9 target fields
- Configurable gender value standardization with comma-separated value lists
- Automatic date parsing

#### Custom Check Builder
- Visual editor for institution-specific rules
- Supported constraint types: `is_not.na`, `not_contains`, `BETWEEN`, `NOT BETWEEN`, `IN()`, `NOT IN()`, `REGEXP`
- JSON export/import for cross-institutional sharing

#### Reporting
- Word (.docx) report generation via `officer` + `flextable`
- CSV export for machine-readable results
- Cryptographic session fingerprints for document integrity verification
- Data protection statement in reports (patient identifiers excluded)
- Methodology, severity distribution, per-check results, fitness-for-purpose interpretation

#### User Interface
- bs4Dash (Bootstrap 4) dashboard UI
- Guided step-by-step wizard (Steps 0 → T → 1 → 2 → 3 → 4 → 5 → 6)
- Trilingual interface: English, German, French
- Interactive tutorial
- FAQ section
- Research tool disclaimer
- Performance timing for all computational tasks

#### Data Cleansing
- Guided cleansing workflow with audit trail
- Action logging for regulatory documentation
- Cleaned data export (CSV)

#### Infrastructure
- Single-file architecture (`app.R`, approximately 7,900 lines)
- Automated dependency installer (`install_dependencies.R`)
- Synthetic test dataset (1,588 records, 9 columns)
- Expected check results file (87 expected hits)
- Validation script (`tests/run_validation.R`)
- MIT License
