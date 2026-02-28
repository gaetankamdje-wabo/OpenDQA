#!/usr/bin/env Rscript
# =============================================================================
# Open DQA V1.0 — Automated Dependency Installer
# =============================================================================
# This script checks for and installs all R packages required by Open DQA.
# Run from the OpenDQA project directory:
#   Rscript install_dependencies.R
# =============================================================================

cat("\n")
cat("╔══════════════════════════════════════════════════════════════╗\n")
cat("║           Open DQA V1.0 — Dependency Installer              ║\n")
cat("╚══════════════════════════════════════════════════════════════╝\n\n")

# ── Minimum R version check ──────────────────────────────────────────────────
min_r_version <- "4.2.0"
current_r <- paste(R.version$major, R.version$minor, sep = ".")
if (compareVersion(current_r, min_r_version) < 0) {
  stop(
    sprintf(
      "Open DQA requires R >= %s. You have R %s.\n",
      min_r_version, current_r
    ),
    call. = FALSE
  )
}
cat(sprintf("✔  R version: %s\n", current_r))

# ── Core CRAN packages (required) ────────────────────────────────────────────
core_packages <- c(
  "shiny",          # Web application framework
  "bs4Dash",        # Bootstrap 4 dashboard UI
  "DT",             # Interactive data tables
  "readxl",         # Excel file import
  "jsonlite",       # JSON parsing (standard + FHIR)
  "stringr",        # String manipulation
  "dplyr",          # Data manipulation
  "lubridate",      # Date/time handling
  "rlang",          # Tidy evaluation
  "data.table",     # Fast data import (fread) and manipulation
  "shinyjs",        # JavaScript operations in Shiny
  "shinyWidgets",   # Enhanced UI widgets
  "waiter",         # Loading spinners and overlays
  "officer",        # Word (.docx) report generation
  "flextable",      # Formatted tables in Word reports
  "plogr"           # Logging
)

# ── Optional CRAN packages ───────────────────────────────────────────────────
optional_packages <- c(
  "cluster",        # Listed in app.R header; not actively invoked in V1.0
  "emayili",        # Email report delivery via SMTP
  "DBI",            # Database interface
  "RPostgres",      # PostgreSQL connectivity
  "odbc"            # Microsoft SQL Server connectivity
)

cat("\nChecking core packages...\n\n")

installed_pkgs <- rownames(installed.packages())
core_missing <- core_packages[!core_packages %in% installed_pkgs]

if (length(core_missing) == 0) {
  cat("✔  All required core packages are already installed.\n")
} else {
  cat(sprintf("Installing %d missing core packages:\n", length(core_missing)))
  cat(paste0("   • ", core_missing, collapse = "\n"), "\n\n")
  install.packages(
    core_missing,
    dependencies = TRUE,
    repos = "https://cloud.r-project.org"
  )
}

cat("\nChecking optional packages...\n\n")

opt_missing <- optional_packages[!optional_packages %in% installed_pkgs]
if (length(opt_missing) == 0) {
  cat("✔  All optional packages are already installed.\n")
} else {
  cat(sprintf("Installing %d optional packages (failures are non-critical):\n", length(opt_missing)))
  cat(paste0("   • ", opt_missing, collapse = "\n"), "\n\n")
  for (pkg in opt_missing) {
    tryCatch(
      install.packages(pkg, dependencies = TRUE, repos = "https://cloud.r-project.org", quiet = TRUE),
      error = function(e) cat(sprintf("   ⚠  Optional: %s not installed (%s)\n", pkg, e$message))
    )
  }
}

# ── Version checks for key packages ──────────────────────────────────────────
cat("\nVerifying minimum package versions...\n\n")

version_requirements <- list(
  shiny     = "1.7.0",
  bs4Dash   = "2.0.0",
  dplyr     = "1.1.0",
  lubridate = "1.9.0",
  officer   = "0.6.0",
  flextable = "0.9.0"
)

for (pkg in names(version_requirements)) {
  required <- version_requirements[[pkg]]
  tryCatch({
    installed <- as.character(packageVersion(pkg))
    if (compareVersion(installed, required) < 0) {
      cat(sprintf("⚠  %s: installed %s < required %s — updating...\n",
                  pkg, installed, required))
      install.packages(pkg, repos = "https://cloud.r-project.org")
    } else {
      cat(sprintf("✔  %s %s\n", pkg, installed))
    }
  }, error = function(e) {
    cat(sprintf("⚠  %s: not found\n", pkg))
  })
}

# ── Final summary ────────────────────────────────────────────────────────────
cat("\n")
cat("══════════════════════════════════════════════════════════════\n")
cat("  Installation complete.\n\n")
cat("  Launch Open DQA:\n")
cat("    shiny::runApp('app.R', launch.browser = TRUE)\n\n")
cat("  Run validation:\n")
cat("    source('tests/run_validation.R')\n")
cat("══════════════════════════════════════════════════════════════\n\n")
