# Data Quality Checks Reference

This document provides a comprehensive reference for all **77 data quality checks** implemented in Open DQA, organized by category. All check definitions are sourced directly from the `CL` list in `app.R` (Section 6).

---

## Check Result Interpretation

| Code | Meaning |
|---|---|
| `PASS` | No violations detected |
| `WARN` | Violations detected but within acceptable range |
| `FAIL` | Violations exceed critical threshold; review recommended |
| `SKIP` | Check could not be run due to missing required fields |

---

## Severity Levels

| Level | Description |
|---|---|
| `Critical` | Data integrity failure likely to invalidate downstream analysis |
| `High` | Serious data quality issue requiring immediate review |
| `Medium` | Potential issue that may indicate data entry errors |
| `Low` | Informational observation; does not indicate a definitive error |

---

## Category 1: Completeness (16 checks)

Cross-references clinical narratives (anamnese field) and admission data against coded fields (ICD, OPS).

| Check ID | Description | Required Columns | Severity |
|---|---|---|---|
| `cat1_1` | Admission present but ICD missing/empty | admission_date, icd | High |
| `cat1_2` | Surgery mention in notes; OPS missing (>10%) | anamnese, ops | Medium |
| `cat1_3` | Diabetes mention; no E10–E14 ICD | anamnese, icd | High |
| `cat1_4` | Heart disease mention; no I-chapter ICD | anamnese, icd | Medium |
| `cat1_5` | Chemotherapy mention; OPS missing | anamnese, ops | High |
| `cat1_6` | COPD mention; no J44 ICD | anamnese, icd | High |
| `cat1_7` | Radiology mention; OPS missing | anamnese, ops | Medium |
| `cat1_8` | Allergy mention; no T78 ICD | anamnese, icd | Medium |
| `cat1_9` | Dialysis mention; OPS missing | anamnese, ops | Medium |
| `cat1_10` | Hypertension mention; no I10 ICD | anamnese, icd | Medium |
| `cat1_11` | Endoscopy mention; OPS missing | anamnese, ops | Medium |
| `cat1_12` | Stroke mention; no I63/I64 ICD | anamnese, icd | High |
| `cat1_13` | Infection mention; no B-chapter ICD | anamnese, icd | Medium |
| `cat1_14` | Prosthesis mention; OPS missing | anamnese, ops | Medium |
| `cat1_15` | Depression mention; no F32–F33 ICD | anamnese, icd | Medium |
| `cat1_16` | Admission present but both ICD and OPS missing | admission_date, icd, ops | High |

---

## Category 2: Age Plausibility (15 checks)

Validates that age–diagnosis combinations are clinically plausible.

| Check ID | Description | Required Columns | Severity |
|---|---|---|---|
| `cat2_1` | Prostate cancer (C61) in age < 15 | age, icd | High |
| `cat2_2` | Alzheimer (F00/G30) in age < 30 | age, icd | High |
| `cat2_3` | Child dev. disorder (F80–F89) in age > 70 | age, icd | Medium |
| `cat2_4` | Osteoporosis (M80/M81) in age < 18 | age, icd | Medium |
| `cat2_5` | Measles (B05) in age > 60 | age, icd | Medium |
| `cat2_6` | Birth ICD (O60–O75) in male patient | gender, icd | High |
| `cat2_7` | Menopause (N95) in male patient | gender, icd | High |
| `cat2_8` | Teen acne (L70) in neonate (age < 1) | age, icd | Medium |
| `cat2_9` | Macular degeneration (H35.3) in age < 30 | age, icd | Medium |
| `cat2_10` | Infantile CP (G80) in adult (age > 21) | age, icd | Medium |
| `cat2_11` | Preeclampsia (O14) in male patient | gender, icd | High |
| `cat2_12` | Juvenile arthritis (M08) in age > 70 | age, icd | Medium |
| `cat2_13` | Testosterone deficiency (E29) in female patient | gender, icd | Medium |
| `cat2_14` | Testicular tumor (C62) in female patient | gender, icd | High |
| `cat2_15` | Delayed puberty (E30.0) in age > 60 | age, icd | Medium |

---

## Category 3: Gender Plausibility (15 checks)

Cross-validates gender-coded fields against gender-specific ICD-10 diagnoses.

| Check ID | Description | Required Columns | Severity |
|---|---|---|---|
| `cat3_1` | Ovarian cyst (N83) in male patient | gender, icd | High |
| `cat3_2` | Prostatitis (N41) in female patient | gender, icd | High |
| `cat3_3` | Pregnancy (O-codes) in male patient | gender, icd | High |
| `cat3_4` | Testicular cancer (C62) in female patient | gender, icd | High |
| `cat3_5` | Endometriosis (N80) in male patient | gender, icd | High |
| `cat3_6` | Erectile dysfunction (N52) in female patient | gender, icd | High |
| `cat3_7` | Cervical cancer (C53) in male patient | gender, icd | High |
| `cat3_8` | Testosterone excess (E28.1) in female patient | gender, icd | Medium |
| `cat3_9` | Menstrual disorder (N92/N93) in male patient | gender, icd | High |
| `cat3_10` | Breast cancer (C50) in male patient (rare; review) | gender, icd | Medium |
| `cat3_11` | Phimosis (N47) in female patient | gender, icd | High |
| `cat3_12` | Vulvitis (N76) in male patient | gender, icd | High |
| `cat3_13` | Perinatal codes (P-chapter) in male baby | gender, icd | Medium |
| `cat3_14` | Cryptorchidism (Q53) in female patient | gender, icd | High |
| `cat3_15` | Hyperemesis gravidarum (O21) in male patient | gender, icd | High |

---

## Category 4: Temporal Consistency (6 checks)

Validates logical ordering and plausibility of date fields.

| Check ID | Description | Required Columns | Severity |
|---|---|---|---|
| `cat4_2` | Discharge date before admission date | admission_date, discharge_date | Critical |
| `cat4_4` | Duplicate same-day admission per patient | patient_id, admission_date | Medium |
| `cat4_6` | Admission date lies in the future | admission_date | Medium |
| `cat4_8` | Same-day discharge with complex OPS | admission_date, discharge_date, ops | Low |
| `cat4_12` | Admission date before birth date | admission_date, birth_date | Critical |
| `cat4_15` | Discharge before admission (dup check) | admission_date, discharge_date | Critical |

---

## Category 5: Diagnosis–Procedure Consistency (15 checks)

Validates co-occurrence of diagnoses and procedures using evidence-based clinical rules.

| Check ID | Description | Required Columns | Severity |
|---|---|---|---|
| `cat5_1` | Appendectomy OPS without K35 ICD | ops, icd | Medium |
| `cat5_2` | Knee replacement OPS without M17 ICD | ops, icd | Medium |
| `cat5_3` | Chemotherapy OPS without cancer ICD | ops, icd | High |
| `cat5_4` | Heart catheter OPS without I-chapter ICD | ops, icd | Medium |
| `cat5_5` | Dialysis OPS without N18 ICD | ops, icd | Medium |
| `cat5_6` | C-section OPS in male patient | ops, gender | High |
| `cat5_7` | Cataract OPS without H25/H26 ICD | ops, icd | Medium |
| `cat5_8` | Gastric bypass OPS without E66 ICD | ops, icd | Medium |
| `cat5_9` | Hysterectomy OPS without GYN ICD | ops, icd | Medium |
| `cat5_10` | Transfusion OPS without anemia ICD | ops, icd | Medium |
| `cat5_11` | Knee arthroscopy OPS without knee ICD | ops, icd | Medium |
| `cat5_12` | Radiology OPS without ICD reason | ops, icd | Medium |
| `cat5_13` | Skin graft OPS without wound/burn ICD | ops, icd | Medium |
| `cat5_14` | Upper GI endoscopy OPS without K-chapter ICD | ops, icd | Medium |
| `cat5_15` | Pacemaker OPS without I44–I49 ICD | ops, icd | Medium |

---

## Category 6: Code Integrity (10 checks)

Validates syntactic and semantic correctness of coded clinical variables.

| Check ID | Description | Required Columns | Severity |
|---|---|---|---|
| `cat6_1` | ICD code does not match valid syntax pattern | icd | Medium |
| `cat6_2` | OPS appears retired (heuristic) | ops | Medium |
| `cat6_3` | ICD potential typo (near-miss) | icd | Medium |
| `cat6_4` | Likely ICD-9 code in ICD-10 environment | icd | Medium |
| `cat6_5` | Placeholder/fake ICD (xxx, zzz) | icd | High |
| `cat6_6` | Numeric ICD-9 style code in ICD-10 env | icd | Medium |
| `cat6_7` | ICD length/shape out of range | icd | Medium |
| `cat6_8` | OPS invalid structure | ops | Medium |
| `cat6_9` | Foreign code system marker (z9) | icd, ops | Low |
| `cat6_11` | Unspecific ICD (R99, Z00) | icd | Low |

> **Note**: Check `cat6_10` is not implemented in the current version.

---

## Adding Custom Checks

In addition to the 77 built-in checks, Open DQA supports institution-specific custom checks via the Custom Check Builder (Step 4). Custom checks support the following constraint types:

- `is_not.na` — Field must not be missing/empty
- `not_contains` — Field must not contain specified text
- `BETWEEN` / `NOT BETWEEN` — Numeric range validation
- `IN()` / `NOT IN()` — Set membership validation
- `REGEXP` — Regular expression pattern matching

Custom checks can be exported as JSON and shared between institutions.

See [CONTRIBUTING.md](../CONTRIBUTING.md#adding-new-quality-checks) for instructions on contributing new built-in checks.
