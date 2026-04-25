# Open DQA

**Fitness-for-Purpose Data Quality Assessment for Clinical Research**

Open DQA is an open-source R Shiny platform that assesses clinical dataset quality against the specific requirements of a research question, rather than applying a fixed set of generic checks. It combines automated statistical profiling, a structured manual check builder, guided data cleansing with a full audit trail, and produces two Word-format certificates (a Data Quality Assessment Certificate and a Cleansing Certificate) designed to support ICH E6 (R2), GDPR Art. 5(1)(d), ISO 14155, and FDA 21 CFR Part 11 audit-trail requirements.

- **Repository:** <https://github.com/gaetankamdje-wabo/OpenDQA>
- **Live demo:** <https://gaet.shinyapps.io/OpenDQA/>
- **License:** MIT
- **Status:** Research prototype. Not a medical device. Not certified under EU MDR, FDA, or any other regulatory framework.

---

## Table of Contents

1. [Key Features](#key-features)
2. [Screenshots](#screenshots)
3. [Installation](#installation)
4. [Quick Start](#quick-start)
5. [How to Use](#how-to-use)
6. [Input Data](#input-data)
7. [Outputs](#outputs)
8. [Examples](#examples)
9. [Project Structure](#project-structure)
10. [Requirements and Dependencies](#requirements-and-dependencies)
11. [Configuration](#configuration)
12. [Testing](#testing)
13. [Limitations](#limitations)
14. [Security and Privacy](#security-and-privacy)
15. [Disclaimer](#disclaimer)
16. [License](#license)
17. [Citation](#citation)
18. [Contributing](#contributing)
19. [Changelog](#changelog)
20. [Roadmap](#roadmap)
21. [Contact](#contact)

---

## Key Features

**Fitness-for-purpose paradigm.** Quality checks are defined relative to the intended secondary use of the data (Wang and Strong, 1996; Weiskopf and Weng, 2013), not against a one-size-fits-all threshold. The same dataset can legitimately pass the assessment for one research question and fail it for another.

**Four-stage workflow.**
- **D1 — Statistical profiling.** Column-name-independent pattern recognition proposes checks based on observed distributions. Covers completeness, robust outliers (MAD z-score > 8), impossible values, whitespace, ICD-10-GM and OPS code format validity, future dates, cross-column temporal order, duplicate identifiers, case inconsistency, inter-column correlation (Pearson *r* > 0.95), and gender-vs-ICD plausibility. Each suggestion carries a quantitative statistical basis, a severity rating, and a pre-validated R expression that the analyst explicitly accepts, modifies, or rejects.
- **D2 Base — Operator-driven check builder.** Step-by-step construction of column-to-value and column-to-column rules over 18 operators (six comparisons, four string-matching, two presence, two range, two set-membership, one regex, two uniqueness). Conditions combine with AND or OR connectives. Value lists for IN / NOT IN operators can be imported from CSV, JSON, Excel, or TXT (useful for sets of several hundred valid ICD codes).
- **D2 Advanced — Grouped, conditional, and free R queries.** Three independent sub-builders: GROUP BY aggregation with eight aggregation functions over a configurable numeric threshold; IF-THEN conditional rules that flag a row only when a precondition holds and a required condition fails; and a free-form R expression field for rules that cannot be expressed through the other two. All three share the same security blacklist as D2 Base.
- **D3 — Check manager and execution.** All checks from D1, D2 Base, and D2 Advanced converge into a single register with stable identifiers (`STAT-`, `STAT-M-`, `MAN-`, `GB-`, `IF-`, `RQ-`). The register exports to JSON for reuse across projects and re-imports on a new dataset. Execution runs every saved expression in a single pass; a malformed check records zero flags instead of aborting the run.

**Guided cleansing with tamper-evident audit trail.** Eight sub-steps: (4.1) issue-guided record-by-record review, (4.2) find-and-replace with regex and case-sensitivity options, (4.3) direct cell editing, (4.4) audit trail review, (4.5) original-vs-cleaned diff view with per-cell highlights, (4.6) column rename, (4.7) type coercion with NA logging for incompatible cells, (4.8) column deletion. Every modification is logged with ISO 8601 timestamp, column, row, old value, and new value.

**Security model.** Every check expression (user-written, imported from JSON, or generated from the D1 suggester) is validated against a blacklist before evaluation. The blacklist rejects `system`, `exec`, `eval`, `parse`, `do.call`, file I/O, environment manipulation, `Sys.*`, `install.*`, and related patterns. Validation runs at definition, at JSON import, and again at execution.

**Certificates.** Two Word documents are generated via `officer` and `flextable`:
- *DQ Certificate* — methodology, complete check register, per-check impact charts, severity and source distributions, session fingerprint, dataset fingerprint, regulatory alignment table.
- *Cleansing Certificate* — every modification in chronological order, chunked at 200 entries per table for Word pagination, summary statistics, integrity hash.

**Trilingual UI (English, German, French).** All labels, hints, tutorial steps, and certificate section headers switch at runtime. The language selector sits in the top bar. Disclaimer content is fixed to English by design (it must appear before language choice is possible).

**Four data sources.** Local file upload (CSV, TXT, Excel, JSON, FHIR Bundle), PostgreSQL, Microsoft SQL Server, HL7 FHIR R4 REST endpoint, plus a built-in demo dataset of 50 synthetic German inpatient encounters that deliberately contains realistic errors (negative length of stay, future admission date, duplicate patient ID, missing OPS codes, male patient with an O-code) so every feature can be exercised without loading real data.

---

## Screenshots

*Screenshots are not committed to the repository. Launch the [live demo](https://gaet.shinyapps.io/OpenDQA/) or run the app locally with the demo dataset to see every screen.*

Screens available in the workflow:

1. Welcome page with disclaimer overlay.
2. Step 1 — Data import (four source tabs plus preview).
3. Step 2 — Checks Studio with D1, D2 Base, D2 Advanced, and D3 tabs.
4. Step 3 — Results dashboard with fitness score, severity distribution, source distribution, per-check impact plots.
5. Step 4 — Cleansing workspace with eight sub-steps.
6. Summary page with certificate downloads.

---

## Installation

### Prerequisites

- R >= 4.1.0 (tested on 4.2 and 4.3)
- RStudio (recommended) or any R console
- On Linux: `libcurl4-openssl-dev`, `libssl-dev`, `libxml2-dev`, and `libfontconfig1-dev` for the Shiny and `officer` toolchains

### Install from source

```bash
git clone https://github.com/gaetankamdje-wabo/OpenDQA.git
cd OpenDQA
```

Open the app script in R or RStudio. On first launch the app installs any missing packages from CRAN automatically. To pre-install manually:

```r
pkgs <- c(
  "shiny", "bs4Dash", "DT", "readxl", "jsonlite", "stringr", "dplyr",
  "lubridate", "rlang", "data.table", "shinyjs", "shinyWidgets", "waiter",
  "cluster", "officer", "flextable"
)
install.packages(setdiff(pkgs, rownames(installed.packages())))
```

Optional database drivers (only required if you use SQL sources):

```r
install.packages(c("DBI", "RPostgres"))   # PostgreSQL
install.packages(c("DBI", "odbc"))        # Microsoft SQL Server (needs ODBC driver)
```

For Microsoft SQL Server, install the *Microsoft ODBC Driver 17 or 18 for SQL Server* at the operating-system level before loading the R `odbc` package.

---

## Quick Start

```r
# From an R session in the project root
shiny::runApp("app.R")
```

The app opens in your default browser at `http://127.0.0.1:<port>`. The first screen is a disclaimer overlay; the *Enter Open DQA* button remains disabled until the acceptance checkbox is ticked.

After acceptance, an optional analyst-information dialog collects a name and role for inclusion in generated certificates. Leave the fields blank and click *Skip* if attribution is not required.

### Fastest path to a working assessment

1. Step 1 → select *Demo Dataset* → *Load Demo Dataset* → *Confirm dataset and proceed*.
2. Step 2 → D1 → *Run Statistical Profiling* → accept all suggestions.
3. Step 2 → D3 → *Execute All Checks* → confirm.
4. Step 3 → review the fitness score and per-check impact.
5. Step 3 → *DQ Certificate (Word)* to download the proof document.

The full round trip on the 50-row demo dataset takes under ten seconds.

---

## How to Use

### Step 1 — Data Import

Four tabs: *Local File*, *SQL Database*, *FHIR Server*, *Demo Dataset*. For local files, pick a format (CSV / Excel / JSON / FHIR Bundle), upload, and preview the first 100 rows. For SQL, choose PostgreSQL or Microsoft SQL, enter host, port, database, user, password; *Test* verifies the connection without running a query, *Run Query* executes the statement and loads the result. For FHIR, enter a base URL (for example `https://hapi.fhir.org/baseR4`) and a resource query (for example `Patient?_count=50`); the client follows up to three retries against flaky public test servers.

Click *Confirm dataset and proceed to Checks Studio* to lock the dataset. Confirmation clears all previous checks, results, and cleansing history so a fresh dataset starts with a clean studio.

### Step 2 — Checks Studio

**D1 — Statistical Profiling.** One click runs the profiler over the active dataset. Each suggestion appears as a card with severity badge, statistical basis, and pre-validated R expression. *Accept* promotes it to the check register; *Modify* opens the expression in an editable dialog before saving; *Reject* discards it.

**D2 Base.** Pick a check type (column-to-value or column-to-column). For each condition: select a column, an operator, a value (or min/max for range operators), and a logic connector (AND / OR / END). Click *Add* to append. Select END to finalize the expression. Click *Test Query* to see the flag count and elapsed time before saving. Naming is mandatory — an unnamed check fails to save.

**D2 Advanced.** Three sub-tabs. GROUP BY takes a grouping column, an aggregation function (count / n_distinct / sum / mean / min / max), an optional target column, and a numeric threshold. IF-THEN takes a precondition (column, operator, value) and a required condition on a second column; a row is flagged when the precondition is true and the required condition is false. Free R-Query accepts any R logical expression that evaluates per row, subject to the same security blacklist (no system calls, no `eval`, no file access).

**D3.** Lists every saved check with identifier, source, description, severity, and truncated expression. Select rows and *Delete Selected* to remove. *Export JSON* saves the register. *Browse* imports a previously exported register. *Execute All Checks* runs everything and jumps to Step 3.

### Step 3 — Results

Four headline metrics: checks executed, issue flags, records affected, fitness score. The fitness score is `Q = 100 × (1 − affected_records / total_records)`, bounded to [0, 100] and binned into four orientation bands (Green ≥ 80, Yellow ≥ 60, Orange ≥ 40, Red < 40). A record flagged by three separate checks counts once in *records affected* but three times in *issue flags*; both are shown so the two views reconcile.

Below the metrics: severity distribution, source distribution, and a per-check impact list with inline bar charts. All charts render eagerly so toggling Show / Hide is a pure CSS operation without a server round trip.

### Step 4 — Cleansing

Eight sub-steps. Sub-step 4.1 is the recommended starting point: select an issue, review each affected record one at a time in an editable form, then *Validate*, *Keep as is*, or *Delete record*. Sub-step 4.7 is the most technical: target-type coercion for a whole column, with a preview that reports how many cells would become NA before the change is applied. Every cell that flips to NA because of the coercion is logged with its original value.

The audit trail is append-only at the UI level. Undo pops the most recent snapshot off a five-step stack but does not erase the log entry — both the change and its reversal remain traceable.

### Summary

Final screen. Four download buttons: DQ Certificate, Issues CSV, Cleansing Certificate, Cleaned Data CSV. *Start New Analysis* confirms with a modal and resets all state.

---

## Input Data

Open DQA is schema-agnostic. It makes no assumption about column names. The statistical profiler auto-detects column types from values, not from headers, which means a column named `foobar` containing ICD-10 codes is profiled as an ICD column.

**Supported formats:**

| Format       | Extension       | Notes |
|--------------|-----------------|-------|
| CSV / TXT    | `.csv`, `.txt`  | Header row and separator configurable. Reads via `data.table::fread`. |
| Excel        | `.xlsx`, `.xls` | Sheet number selectable. Reads via `readxl`. |
| JSON         | `.json`         | Attempts structured parse first, falls back to newline-delimited JSON. |
| FHIR Bundle  | `.json`         | Flattens Patient / Encounter / Condition / Procedure resources into one row per encounter. |
| PostgreSQL   | connection      | Requires `DBI` and `RPostgres`. |
| MS SQL       | connection      | Requires `DBI`, `odbc`, and an ODBC driver. |
| FHIR REST    | URL             | HL7 FHIR R4. Libcurl-based download with retry. |

Maximum file upload is 2 GB (`shiny.maxRequestSize`). Larger datasets should be loaded via SQL.

---

## Outputs

Every download is a plain file, never a database handle or a ZIP archive. Files are named with an ISO-style timestamp suffix (`YYYYMMDD_HHMMSS`) so multiple runs never overwrite.

| Artefact                 | Format | Purpose |
|--------------------------|--------|---------|
| DQ Certificate           | `.docx` | Formal assessment proof: tool metadata, dataset summary, methodology, check register, per-check impact with charts, session fingerprint, regulatory alignment. |
| Cleansing Certificate    | `.docx` | Complete chronological modification log with timestamps and before/after values, chunked for Word pagination, integrity hash. |
| Issues CSV               | `.csv`  | Row-level flag list: `check_id`, `issue`, `severity`, `row`. |
| Cleaned Data CSV         | `.csv`  | Post-cleansing dataset. |
| Audit Trail CSV          | `.csv`  | Raw modification log (same content as the Cleansing Certificate, machine-readable). |
| Check Register JSON      | `.json` | Full check definitions for export and reuse. |

---

## Examples

### Example 1 — End-to-end assessment on the demo dataset

```text
Step 1  → Demo Dataset → Load → Confirm
Step 2  → D1 → Run Statistical Profiling
         Suggestions include:
           Completeness: ops_code        (High, 72 % missing)
           Duplicate IDs: patient_id     (1 duplicate)
           Future dates: admission_date  (1 record in the future)
           Temporal order violations     (1 record: admission > discharge)
         Accept all.
Step 2  → D3 → Execute All Checks
Step 3  → Fitness Score ≈ 86 % (Yellow band)
         Records affected: 7 of 50
Step 4  → 4.1 Select "Future dates: admission_date" → review → correct → validate
Step F  → Download DQ Certificate and Cleansing Certificate
```

### Example 2 — Custom implausible-age check in D2 Base

```text
Step 0: Check Type = Column to Value
Step 1: Column = age, Operator = >, Value = 120, Logic = END, Add
Step 2: Name = "Age over 120", Severity = High, Save
```

### Example 3 — Cross-column plausibility in D2 Advanced

```text
Sub-tab: IF-THEN
IF   column = gender,   operator = ==,          value = M
THEN column = icd_code, operator = starts_with, value = O
Name = "Male patient with female-specific O-code", Severity = High, Save
```

The saved expression flags any male patient carrying an ICD code from Chapter O (pregnancy, childbirth, puerperium).

### Example 4 — Group-level uniqueness in D2 Advanced

```text
Sub-tab: GROUP BY
Group by column = patient_id
Aggregation = count > threshold
Threshold = 1
Name = "Duplicate patient IDs", Severity = High, Save
```

---

## Project Structure

The application is distributed as a single self-contained R file. This is intentional for a research prototype: everything needed to reproduce a run — UI, server logic, internationalization dictionary, demo data generator, certificate templates, security blacklist — lives in one place, versioned together.

```text
OpenDQA/
├── app.R              # Shiny UI, server, helpers, renderers, certificate generators
├── README.md          # This file
├── LICENSE            # MIT
└── .gitignore
```

**Inside `app.R`, the code is organized top-to-bottom as follows:**

| Section                   | Purpose |
|---------------------------|---------|
| Package management        | Detects and installs missing CRAN packages on first run. |
| `i18n_db` dictionary      | Trilingual (EN / DE / FR) lookup for every UI string, hint, tutorial step, and certificate heading. |
| Utility helpers           | Null coalescing, safe notifications, numeric parsing, sample indexing, fitness-score bands. |
| Security layer            | `validate_expression` (regex blacklist) and `safe_eval_expr` (wrapped `eval` with length coercion). |
| Undo stack                | Five-step snapshot stack for cleansing operations. |
| Demo data generator       | 50 synthetic German inpatient encounters with deliberate errors. |
| Data readers              | CSV, Excel, JSON, FHIR bundle, PostgreSQL, MS SQL, FHIR REST. |
| Statistical profiler      | Type classifier plus ten check families (completeness, outliers, impossible values, whitespace, ICD and OPS format, future dates, temporal order, duplicates, correlation, gender-ICD plausibility). |
| Check-execution engine    | Vectorised evaluation over the active data.frame with `data.table::rbindlist`. |
| Visualisation helpers     | Per-check bar+donut plot, severity and source PNG renderers. |
| `gen_word`, `gen_cl_word` | Officer-based Word document generators. |
| `APP_CSS`                 | Single-stylesheet design system: colour tokens, typography, layout, skeleton loaders, topbar, timer strip. |
| `ui`                      | bs4Dash page definition with all four workflow steps, tutorial, and summary. |
| `server`                  | Reactive wiring, observers, download handlers, eager-render configuration. |

---

## Requirements and Dependencies

### R packages (hard dependencies)

`shiny`, `bs4Dash`, `DT`, `readxl`, `jsonlite`, `stringr`, `dplyr`, `lubridate`, `rlang`, `data.table`, `shinyjs`, `shinyWidgets`, `waiter`, `cluster`, `officer`, `flextable`.

### R packages (optional)

`DBI` + `RPostgres` for PostgreSQL. `DBI` + `odbc` for Microsoft SQL Server. Both are detected at startup; if missing, the corresponding SQL tab reports an informative message instead of crashing.

### System dependencies (Linux)

```bash
sudo apt-get install -y \
  libcurl4-openssl-dev libssl-dev libxml2-dev \
  libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
  libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev
```

For MS SQL, additionally install the Microsoft ODBC driver:

```bash
# Ubuntu 22.04 example — see Microsoft docs for other distributions
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list \
  | sudo tee /etc/apt/sources.list.d/mssql-release.list
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql18
```

---

## Configuration

There is no configuration file. Behavior is controlled in the app script through a small set of named constants:

| Constant                 | Default       | Effect |
|--------------------------|---------------|--------|
| `shiny.maxRequestSize`   | 2 GB          | Maximum upload size. |
| `SEC_BLACKLIST`          | regex         | Forbidden function patterns in any user-supplied expression. |
| `MANUAL_EDIT_MAX`        | 1000 rows     | Maximum rows rendered in sub-step 4.3 (direct cell editing) per page. |
| D1 `max_checks`          | 30            | Maximum number of automated suggestions per profiling run. |
| D1 `sample_n`            | 50 000        | Rows sampled from the active dataset for profiling on very large inputs. |
| Undo stack depth         | 5             | Cleansing snapshots retained. |
| FHIR retry count         | 3             | Retries on HTTP 5xx against FHIR endpoints. |

Adjustments require editing the top of the script and restarting the session.

---

## Testing

This is a research prototype and does not ship a formal `testthat` suite. The validated way to verify a clean install is the demo-dataset smoke test:

1. Launch the app.
2. Step 1 → Demo Dataset → Load → Confirm.
3. Step 2 → D1 → Run Statistical Profiling.
4. Confirm that the suggestion list contains, at minimum: *Completeness: ops_code*, *Duplicate IDs: patient_id*, *Future dates: admission_date*, *Temporal order: admission_date after discharge_date*.
5. Accept all. Execute all checks in D3.
6. Confirm that Step 3 reports a non-trivial fitness score between 60 and 95 %.
7. Download the DQ Certificate and confirm that it opens in Word or LibreOffice without errors.

If any of those steps fails the install is incomplete — the most common cause is a missing `officer` or `flextable` system library on Linux.

---

## Limitations

- Single-user. Shiny state is scoped to one session; there is no multi-analyst collaboration, no concurrency lock, and no server-side persistence beyond the current session.
- Not a medical device. The fitness score is an orientation metric. Domain-specific thresholds, agreement with downstream analyses, and fit to the regulatory framework of a specific study must be established separately.
- In-memory processing. The check-execution engine loads the full data.frame into RAM. Datasets larger than roughly one million rows on commodity hardware should be pre-filtered upstream.
- The D1 statistical profiler samples up to 50 000 rows for pattern detection. Suggestions on very large datasets may miss rare patterns. Executed checks, in contrast, always run on the full dataset.
- FHIR ingestion supports R4 and flattens only Patient, Encounter, Condition, and Procedure resources. Other resource types are read through as raw JSON.
- The demo dataset is synthetic and intentionally small. It is not representative of real-world coding completeness or distribution.

---

## Security and Privacy

**Local-only processing.** All data handling happens in the R session hosting the app. No data is transmitted to third parties. The only network traffic initiated by Open DQA is: (a) CRAN on first-launch package installation, (b) Google Fonts for the Inter typeface in the stylesheet, (c) user-configured SQL or FHIR endpoints.

**Expression validation.** Every R expression — whether typed in D2 Base, D2 Advanced, proposed by D1, or imported from a JSON check register — is validated against the same blacklist that rejects `system`, `exec`, `pipe`, `eval`, `parse`, `do.call`, `assign`, `source`, file I/O, `Sys.*`, `options(`, `setwd`, `getwd`, `readRDS`, `saveRDS`, `load(`, `save(`, `sink(`, `scan(`, `install.*`, `library`, `require`, and URL / browser operations. Rejection happens before the expression reaches `eval`.

**Patient identifier redaction in certificates.** Generated Word documents contain per-check statistics, not row-level patient listings. The cleansing certificate records modifications by row index, not by patient identifier. If identifiable fields are present in the dataset they appear only in the Issues CSV and the Cleaned Data CSV, both of which the analyst exports intentionally.

**Session fingerprints.** Every DQ Certificate embeds a session hash (`ODQA-...`) and a dataset fingerprint (`DF-...`) derived from the column signature, dataset dimensions, and a first-row sample. The fingerprint is deterministic for a given input and serves as an integrity reference across archival, re-analysis, and cross-site verification.

**Consent overlay.** The first screen is a disclaimer that blocks access to every other screen. Confirmation requires an explicit checkbox tick. The *Enter Open DQA* button is client-side disabled until the checkbox is ticked, so accidental clicks cannot proceed.

---

## Disclaimer

Open DQA is an open-source research tool developed at the Mannheim Institute for Intelligent Systems in Medicine (MIISM), Medical Faculty Mannheim, Heidelberg University.

**It is not a certified medical product** under EU MDR, FDA, or any other regulatory framework, and must not be used as a basis for clinical decisions. It is designed to support clinical research by providing transparent, reproducible, and auditable data quality assessment. The user is solely responsible for validating and interpreting all results.

---

## License

Released under the **MIT License**. See [`LICENSE`](./LICENSE) for the full text.

Copyright (c) Heidelberg University, Gaetan Kamdje Wabo and contributors.

---

## Citation

If Open DQA supports work leading to publication, please cite:

```bibtex
@software{OpenDQA,
  author  = {Kamdje Wabo, Gaetan and Ganslandt, Thomas and Siegel, Fabian and Sokolowski, Piotr},
  title   = {{Open DQA}: Fitness-for-Purpose Data Quality Assessment for Clinical Research},
  url     = {https://github.com/gaetankamdje-wabo/OpenDQA},
  note    = {Mannheim Institute for Intelligent Systems in Medicine (MIISM), Heidelberg University}
}
```

A methodological description is under peer review at JMIR Medical Informatics. This entry will be updated once the DOI is assigned.

**Theoretical basis:**

- Wang, R. Y. and Strong, D. M. (1996). *Beyond accuracy: What data quality means to data consumers.* Journal of Management Information Systems, 12(4), 5–33.
- Weiskopf, N. G. and Weng, C. (2013). *Methods and dimensions of electronic health record data quality assessment: enabling reuse for clinical research.* JAMIA, 20(1), 144–151.

---

## Contributing

Contributions are welcome through GitHub issues and pull requests.

**Before opening a pull request:**

1. Open an issue first to discuss the proposed change, especially for new check families or changes to the security blacklist.
2. Keep the single-file architecture intact — refactors that split `app.R` into multiple files need explicit discussion.
3. Preserve trilingual coverage: every new user-facing string must be added to all three languages in `i18n_db` (EN / DE / FR).
4. Expressions added to the D1 suggester must pass `validate_expression` and must not rely on column names. Match on detected types and content patterns instead.
5. Run the demo-dataset smoke test (see [Testing](#testing)) before pushing.

**Bug reports** should include the R version, the operating system, the exact input (or the demo dataset if reproducible there), the Shiny notification text, and the content of the R console. Minimal reproducible examples are strongly preferred.

---

## Changelog

Changes are tracked per commit in the Git history. A dedicated `CHANGELOG.md` will be introduced once the first stable release is tagged.

---

## Roadmap

Planned, not committed:

- `testthat` suite covering the security blacklist, the D1 profiler on canonical inputs, and the check-execution engine.
- Server-side persistence of check registers across sessions.
- OMOP CDM and i2b2-star-schema-aware importers in addition to the generic tabular path.
- Pluggable severity-weighting schemes for the fitness score.
- Batch-mode command-line runner for CI pipelines (same check register, no UI).
- Extended FHIR resource coverage (Observation, MedicationStatement, DiagnosticReport).

---

## Contact

**Gaetan Kamdje Wabo, M.Sc.**
Department of Biomedical Informatics
Mannheim Institute for Intelligent Systems in Medicine (MIISM)
Medical Faculty Mannheim, Heidelberg University
Universitätsmedizin Mannheim (UMM)
Mannheim, Germany

- GitHub: [@gaetankamdje-wabo](https://github.com/gaetankamdje-wabo)
- Repository issues: <https://github.com/gaetankamdje-wabo/OpenDQA/issues>
