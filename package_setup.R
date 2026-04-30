# =============================================================================
# package_setup.R
# Project: Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers
# Purpose: Install and verify all required packages
# Run this once before any other scripts
# =============================================================================

# Always pin a CRAN mirror so this works in non-interactive / CI environments
options(repos = c(CRAN = "https://cloud.r-project.org"))

# --- CRAN packages -----------------------------------------------------------
cran_pkgs <- c(
  # Data acquisition
  "haven",         # Read SAS XPT files (NHANES native format); see R/01_download_data.R
  "curl",          # Robust HTTP downloads with timeout/retry (preferred over base download.file)

  # Data wrangling — tidyverse + explicit components used in the pipeline
  "tidyverse",     # dplyr, tidyr, readr, ggplot2, purrr, stringr, forcats
  "dplyr",
  "tidyr",
  "readr",
  "purrr",
  "stringr",
  "forcats",
  "tibble",
  "janitor",       # clean_names, tabyl
  "here",          # project-relative paths
  "lubridate",     # date handling

  # Survey analysis
  "survey",        # Complex survey design
  "srvyr",         # tidyverse-style survey functions

  # Modeling
  "broom",         # tidy model output
  "broom.helpers", # additional broom helpers

  # Tables
  "gtsummary",     # publication-quality summary tables
  "gt",            # underlying table engine
  "flextable",     # Word-compatible tables
  "knitr",         # kable tables
  "kableExtra",    # kable formatting

  # Visualization
  "ggplot2",       # core plotting (included in tidyverse)
  "ggpubr",        # publication-ready plots
  "patchwork",     # combine multiple ggplots
  "scales",        # axis scale formatting
  "ggdist",        # distribution visualizations
  "ggrepel",       # non-overlapping labels
  "viridis",       # colorblind-friendly palettes
  "RColorBrewer",  # color palettes

  # Reporting
  "quarto",        # Quarto document rendering (may need system Quarto)
  "rmarkdown",     # R Markdown support

  # Utilities
  "glue",          # string interpolation
  "fs",            # file system operations
  "sessioninfo"    # session information
)

# Install missing packages -----------------------------------------------------
installed <- rownames(installed.packages())
missing_pkgs <- setdiff(cran_pkgs, installed)

if (length(missing_pkgs) > 0) {
  message("Installing missing packages: ", paste(missing_pkgs, collapse = ", "))
  install.packages(missing_pkgs, repos = "https://cloud.r-project.org")
} else {
  message("All required packages are already installed.")
}

# Verify each required package can be loaded via requireNamespace() ------------
required_for_pipeline <- c(
  "tidyverse", "here", "janitor", "haven", "survey", "srvyr", "broom",
  "gtsummary", "gt", "flextable", "ggplot2", "patchwork", "scales",
  "viridis", "glue", "fs", "knitr", "kableExtra", "sessioninfo",
  "readr", "dplyr", "stringr", "forcats", "rmarkdown"
)

still_missing <- required_for_pipeline[
  !vapply(required_for_pipeline, requireNamespace, logical(1), quietly = TRUE)
]

if (length(still_missing) > 0) {
  stop(
    "package_setup.R: required packages still missing after install: ",
    paste(still_missing, collapse = ", "),
    call. = FALSE
  )
}

message("\n[OK] All required packages available.")

# Print session info for reproducibility (best-effort) -------------------------
try(sessioninfo::session_info(), silent = TRUE)
