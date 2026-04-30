# =============================================================================
# package_setup.R
# Project: Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers
# Purpose: Install and verify all required packages
# Run this once before any other scripts
# =============================================================================

# --- CRAN packages -----------------------------------------------------------
cran_pkgs <- c(
  # Data acquisition
  "nhanesA",      # NHANES data download
  "haven",        # Read SAS/SPSS/Stata files

  # Data wrangling
  "tidyverse",    # dplyr, tidyr, readr, ggplot2, purrr, stringr
  "janitor",      # clean_names, tabyl
  "here",         # project-relative paths
  "lubridate",    # date handling

  # Survey analysis
  "survey",       # Complex survey design
  "srvyr",        # tidyverse-style survey functions

  # Modeling
  "broom",        # tidy model output
  "broom.helpers",# additional broom helpers

  # Tables
  "gtsummary",    # publication-quality summary tables
  "gt",           # underlying table engine
  "flextable",    # Word-compatible tables
  "knitr",        # kable tables
  "kableExtra",   # kable formatting

  # Visualization
  "ggplot2",      # core plotting (included in tidyverse)
  "ggpubr",       # publication-ready plots
  "patchwork",    # combine multiple ggplots
  "scales",       # axis scale formatting
  "ggdist",       # distribution visualizations
  "ggrepel",      # non-overlapping labels
  "viridis",      # colorblind-friendly palettes
  "RColorBrewer", # color palettes

  # Reporting
  "quarto",       # Quarto document rendering (may need system Quarto)
  "rmarkdown",    # R Markdown support

  # Utilities
  "glue",         # string interpolation
  "fs",           # file system operations
  "sessioninfo"   # session information
)

# Install missing packages
missing_pkgs <- cran_pkgs[!cran_pkgs %in% installed.packages()[, "Package"]]

if (length(missing_pkgs) > 0) {
  message("Installing missing packages: ", paste(missing_pkgs, collapse = ", "))
  install.packages(missing_pkgs, repos = "https://cloud.r-project.org")
} else {
  message("All required packages are already installed.")
}

# Verify all packages load successfully
failed <- character(0)
for (pkg in cran_pkgs) {
  result <- tryCatch(
    { suppressPackageStartupMessages(library(pkg, character.only = TRUE)); TRUE },
    error = function(e) FALSE
  )
  if (!result) failed <- c(failed, pkg)
}

if (length(failed) > 0) {
  warning("The following packages failed to load: ", paste(failed, collapse = ", "))
} else {
  message("\n✓ All packages loaded successfully.")
}

# Print session info for reproducibility
sessioninfo::session_info()
