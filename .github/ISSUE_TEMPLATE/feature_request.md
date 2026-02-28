---
name: 💡 Feature Request
about: Propose a new data quality check, feature, or improvement
title: "[FEATURE] "
labels: ["enhancement", "needs-triage"]
assignees: ""
---

## Feature Summary

<!-- A concise one-sentence description of the proposed feature. -->

## Problem / Motivation

<!-- Describe the clinical, technical, or operational problem this feature would solve.
Example: "When auditing obstetric data, I frequently encounter cases where..." -->

## Proposed Solution

<!-- Describe your proposed implementation or behavior in as much detail as possible. -->

## Is this a New Data Quality Check?

- [ ] Yes — new quality check
- [ ] No — application feature / UI improvement / integration / performance

**If yes, please complete the following:**

| Field | Value |
|---|---|
| Proposed Check ID | e.g. AGE-014 |
| Category | completeness / age_plausibility / gender_plausibility / temporal_consistency / dx_procedure_consistency / code_integrity |
| Severity | error / warning / info |
| Required Fields | e.g. date_of_birth, admission_date |
| Clinical Reference | e.g. ICD-10-GM 2024, § ... / published guideline |

**Proposed check logic (pseudocode or R):**

```r
# Example:
check_xyz <- function(data, params) {
  affected <- data[condition, ]
  # ...
}
```

## Alternatives Considered

<!-- Describe any alternative approaches or workarounds you have considered. -->

## Clinical Evidence or Standards Reference

<!-- Cite any relevant clinical guidelines, coding standards, or literature supporting this feature.
Example: "According to ICD-10-GM Coding Guidelines 2024, Chapter X..." -->

## Additional Context

<!-- Any other information, screenshots, or mockups. -->

## Checklist

- [ ] I have checked that this feature has not already been requested
- [ ] I have described the clinical/technical motivation clearly
- [ ] If proposing a new check, I have provided a clinical reference or rationale
