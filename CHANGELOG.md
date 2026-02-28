# Changelog

## V1.0 (2026-02-28)

Initial public release.

### Core
- 77 built-in plausibility checks across 6 categories (Completeness, Age Plausibility, Gender Plausibility, Temporal Consistency, Diagnosis–Procedure Consistency, Code Integrity)
- Custom rule builder with visual condition editor (column vs. value, column vs. column, AND/OR logic)
- JSON import/export for custom check reuse across projects
- Quality Score computation with severity-banded interpretation

### Data Import
- Local file upload: CSV, Excel, JSON, FHIR Bundle
- SQL database connectivity: PostgreSQL, MS SQL Server
- FHIR Bundle parsing (Patient, Encounter, Condition, Procedure resources)
- Auto-detection of column mappings
- Maximum upload size: 2 GB

### Data Cleansing
- Issue-guided cleansing (navigate by issue, then by patient)
- Bulk operations (find & replace with regex support, column rename, date format correction)
- Manual cell editing
- Undo/redo with disk-backed snapshots for large datasets
- Original vs. cleaned data comparison view

### Reporting
- Word (.docx) data quality report with charts, check details, and certification footer
- Word (.docx) cleansing change log with regulatory context (ICH E6(R2), GDPR, FAIR, FDA 21 CFR Part 11, ISO 14155, OECD GLP)
- CSV export for issues and cleaned data
- Session fingerprint and data integrity hash

### Interface
- Trilingual UI (English, German, French)
- Interactive tutorial
- Landing page with optional user identification
- Performance timing for imports and checks
- Responsive design with modern CSS
