# Data Format Specification

This document defines the input data format accepted by Open DQA and provides guidance on data preparation, field mapping, and encoding considerations.

---

## Supported File Formats

| Format | Extension | Notes |
|---|---|---|
| CSV/TXT | `.csv`, `.txt`, `.tsv` | Configurable separator (`,`, `;`, tab). Header row optional. UTF-8 recommended. |
| Excel | `.xlsx`, `.xls` | First sheet by default; sheet number selectable in UI. |
| JSON | `.json` | Standard JSON, JSON Lines (NDJSON), and nested JSON with auto-flattening. |
| FHIR Bundle | `.json` | HL7 FHIR R4 bundles — extracts Patient, Encounter, Condition, Procedure resources. |

Maximum upload size: **2 GB** (configurable via `shiny.maxRequestSize` in `app.R`).

---

## Target Fields

Open DQA uses a column mapping wizard (Step 2) to map source columns to the following 9 target fields. Any column names can be mapped — the application does not require specific column naming.

| Target Field | Data Type | Format / Value Set | Required | Used By |
|---|---|---|---|---|
| `patient_id` | character | Any unique string | Yes | All categories |
| `icd` | character | ICD-10 code(s), semicolon-separated | Yes | Completeness, Age, Gender, Dx-Procedure, Code Integrity |
| `ops` | character | OPS procedure code(s), semicolon-separated | No | Completeness, Dx-Procedure, Code Integrity, Temporal |
| `gender` | character | Mapped via gender standardization | Yes | Gender Plausibility, Dx-Procedure |
| `admission_date` | date | `YYYY-MM-DD` (parsed via `as.Date()`) | Yes | Temporal Consistency, Age Plausibility |
| `discharge_date` | date | `YYYY-MM-DD` or blank | Yes | Temporal Consistency |
| `age` | numeric | Patient age at admission | No | Age Plausibility |
| `birth_date` | date | `YYYY-MM-DD` | No | Age Plausibility, Temporal |
| `anamnese` | character | Clinical narrative / free text | No | Completeness (text-based cross-checks) |

---

## Gender Value Standardization

In Step 2, users provide comma-separated lists of values representing "male" and "female" in their dataset:

| Gender | Default Accepted Values |
|---|---|
| Male | `m, male, M, 1, Mann` |
| Female | `f, female, F, 2, Frau` |

Open DQA normalizes all gender values to lowercase `"male"` or `"female"` for internal processing. This ensures gender plausibility checks function correctly regardless of the source encoding convention.

---

## ICD-10 Code Formats

Both dot notation and compact notation are accepted. Validation uses the regex pattern `^[A-Z][0-9]{2}(\.[0-9A-Z]{1,4})?$` (case-insensitive):

```
Valid:
  I10          I10.0        E11.9
  Z87.39       C50.119      F32.1

Invalid (triggers Code Integrity checks):
  I 10         (contains space)
  I-10         (hyphen instead of dot)
  XXX.0        (placeholder)
  123.4        (numeric-only — likely ICD-9)
```

Internal normalization: whitespace is removed, characters are uppercased, and common OCR confusions are corrected (O→0, I→1).

### Unspecific Code Detection

Codes matching `R99`, `Z00*`, or ending in `.9`, `.90`, `.99` are flagged as unspecific (Code Integrity check `cat6_11`).

---

## OPS Procedure Code Formats

Validation uses the regex pattern `^[1-9]-[0-9]{2,3}(\.[0-9A-Z]{1,3}){0,2}$`:

```
Valid:
  5-470.0      1-632.0      8-980.0
  5-511.0      3-200.0
```

---

## Multiple Codes in One Field

When multiple codes are stored in a single field (ICD or OPS), semicolons serve as separators. For user-uploaded CSV/Excel data, the application handles both semicolons and pipes internally.

---

## Date Formats

Open DQA parses dates using R's `as.Date()` function. ISO 8601 (`YYYY-MM-DD`) is strongly preferred for unambiguous parsing.

| Format | Example | Recommendation |
|---|---|---|
| `YYYY-MM-DD` | `1975-03-22` | Preferred |
| Other formats | Various | May require pre-processing before upload |

---

## Encoding Requirements

- **Character encoding**: UTF-8 is recommended for correct handling of special characters (German umlauts ä, ö, ü; French accents).
- **Line endings**: Both Windows (CRLF) and Unix (LF) line endings are supported via `data.table::fread()`.
- **Large files**: `data.table::fread()` provides high-performance reading; files up to 2 GB are supported.

---

## Test Dataset

A fully synthetic test dataset is provided at `data/Test_Data.csv`:

- **Records**: 1,588
- **Columns**: 9 (`patient_id`, `icd`, `ops`, `gender`, `admission_date`, `discharge_date`, `age`, `birth_date`, `anamnese`)
- **Design**: Contains deliberately seeded quality issues covering all 77 checks.
- **Patient IDs**: Follow the pattern `T_catX_Y` (e.g., `T_cat1_1`, `T_cat2_3`) mapping to specific check categories.

The file `data/open_dqa_expected_hits.csv` contains the expected check results and is used by the validation script.

---

## Data Privacy Considerations

Open DQA processes data entirely within the local or institutional environment in which the application is deployed. No patient data is transmitted externally during operation.

Pseudonymized or de-identified data should be used for all quality assessments in accordance with applicable data protection regulations.
