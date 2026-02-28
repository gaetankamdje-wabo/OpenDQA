## Summary

<!-- Provide a concise description of the changes in this PR. -->

## Motivation

<!-- Explain WHY these changes are needed. Link to relevant issues. -->

Closes: #<!-- issue number -->

## Type of Change

- [ ] 🐛 Bug fix (non-breaking change that fixes an issue)
- [ ] ✨ New feature (non-breaking change that adds functionality)
- [ ] 🔍 New data quality check
- [ ] 🌍 Translation / i18n improvement
- [ ] 📝 Documentation update
- [ ] ♻️ Refactoring (no functional changes)
- [ ] ⚡ Performance improvement
- [ ] 🔧 Configuration change
- [ ] 💥 Breaking change (fix or feature that would break existing behavior)

## Changes Made

<!-- List the key changes. Be specific. -->

- 
- 
- 

## Testing

<!-- Describe how you tested these changes. -->

- [ ] All 77 existing checks pass: `Rscript tests/run_validation.R` — output shows `77/77 ✔`
- [ ] New/modified checks have test records in `generate_testdata.R`
- [ ] `open_dqa_expected_hits.csv` updated to reflect new expected results (if applicable)
- [ ] Manual testing performed in the Shiny UI
- [ ] Tested on:
  - [ ] Windows
  - [ ] macOS
  - [ ] Linux

## Screenshots (UI Changes)

<!-- If this PR changes the UI, add before/after screenshots. -->

| Before | After |
|---|---|
| | |

## Documentation

- [ ] `docs/checks_reference.md` updated (if new check added)
- [ ] `docs/data_format.md` updated (if new fields required)
- [ ] `CHANGELOG.md` updated with a summary of changes
- [ ] `README.md` updated if applicable
- [ ] `data/OpenDQA_Checks_Metadata.xlsx` updated (if new check added)
- [ ] `i18n/translations.yml` updated (EN, DE, FR) for any new UI strings

## Breaking Changes

<!-- If this is a breaking change, describe what users need to do to adapt. -->

## Checklist

- [ ] My code follows the [Open DQA coding standards](CONTRIBUTING.md#coding-standards)
- [ ] All functions have `roxygen2` documentation headers
- [ ] I have not introduced any new `library()` calls inside function bodies
- [ ] No hardcoded patient data or real clinical records are included in test files
- [ ] I have reviewed my own diff and removed debug code, `print()` statements, and commented-out code
- [ ] I have rebased my branch on the latest `main`
