# =============================================================================
# 00_setup.R
# Project: Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers
# Purpose: Load libraries, set global options, define helper functions and
#          constants used across all analysis scripts
# Author:  Allen Xu
# Date:    2025
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
  library(janitor)
  library(haven)
  library(survey)
  library(srvyr)
  library(broom)
  library(gtsummary)
  library(gt)
  library(flextable)
  library(ggplot2)
  library(patchwork)
  library(scales)
  library(viridis)
  library(glue)
  library(fs)
  library(knitr)
  library(kableExtra)
  library(sessioninfo)
})

message("=== 00_setup.R: libraries loaded ===")

# --- Global R options --------------------------------------------------------
options(
  scipen    = 999,          # suppress scientific notation
  digits    = 4,            # default print precision
  dplyr.summarise.inform = FALSE,
  survey.lonely.psu = "adjust"  # handle strata with single PSU
)

set.seed(2025)  # reproducibility

# --- Directory paths ---------------------------------------------------------
# All paths are relative to the project root via here::here()
dir_raw       <- here("data", "raw")
dir_processed <- here("data", "processed")
dir_codebook  <- here("data", "codebook")
dir_tables    <- here("outputs", "tables")
dir_figures   <- here("outputs", "figures")
dir_report    <- here("outputs", "report")

# Create directories if they do not exist
walk(c(dir_raw, dir_processed, dir_codebook, dir_tables, dir_figures, dir_report),
     dir_create)

# --- NHANES cycle ------------------------------------------------------------
# This analysis uses NHANES 2017-2018 (cycle J) only. See docs/methods_notes.md
# for the rationale (single-cycle pre-pandemic data; avoids COVID-era effects).

# NHANES file names by domain (single cycle)
nhanes_files <- list(
  demo   = "DEMO_J",
  metals = "PBCD_J",    # Blood Cd, Pb, Hg, Se, Mn
  hscrp  = "HSCRP_J",  # High-Sensitivity C-Reactive Protein (NOT CRP_J)
  ghb    = "GHB_J",    # Glycohemoglobin (HbA1c)
  tchol  = "TCHOL_J",  # Total Cholesterol
  hdl    = "HDL_J",    # HDL Cholesterol
  bp     = "BPX_J",    # Blood Pressure
  bpq    = "BPQ_J",    # Blood Pressure Questionnaire
  bmx    = "BMX_J",    # Body Measures
  diet   = "DR1TOT_J", # 24-hr Dietary Recall Day 1
  smq    = "SMQ_J"     # Smoking Questionnaire
)

# --- Key variable names ------------------------------------------------------
# These map NHANES variable names to their roles. Verified against NHANES codebooks.
var_map <- list(
  # Identifiers / design
  seqn    = "SEQN",
  psu     = "SDMVPSU",
  strata  = "SDMVSTRA",
  wt_mec  = "WTMEC2YR",    # 2017-2018 MEC examination weight (used directly; single cycle)

  # Demographics
  age     = "RIDAGEYR",
  sex     = "RIAGENDR",
  race    = "RIDRETH3",
  educ    = "DMDEDUC2",
  pir     = "INDFMPIR",    # poverty-income ratio

  # Exposures: blood metals (PBCD files)
  pb      = "LBXBPB",      # Blood Lead  (µg/dL)
  cd      = "LBXBCD",      # Blood Cadmium (µg/dL)
  hg      = "LBXTHG",      # Blood Total Mercury (µg/L)

  # Outcomes
  hba1c   = "LBXGH",       # HbA1c %  (GHB_J)
  hscrp   = "LBXHSCRP",    # High-Sensitivity CRP mg/L (HSCRP_J); converted to mg/dL in 02_
  tchol   = "LBXTC",       # Total Cholesterol mg/dL (TCHOL_J)
  hdl     = "LBDHDD",      # HDL Cholesterol mg/dL (HDL_J)

  # Body measures
  bmi     = "BMXBMI",

  # Blood pressure (BPX_J — auscultatory readings, 2017-2018)
  sbp1    = "BPXSY1",  sbp2 = "BPXSY2",  sbp3 = "BPXSY3",
  dbp1    = "BPXDI1",  dbp2 = "BPXDI2",  dbp3 = "BPXDI3",

  # BP medication (BPQ files)
  bp_med  = "BPQ050A",

  # Dietary (DR1TOT files)
  fiber   = "DR1TFIBE",   # Dietary fiber (g)
  vitc    = "DR1TVC",     # Vitamin C (mg)
  kcal    = "DR1TKCAL",   # Energy (kcal)
  calcium = "DR1TCALC",   # Calcium (mg)
  iron    = "DR1TIRON",   # Iron (mg)

  # Smoking (SMQ files)
  smk100  = "SMQ020",     # Smoked ≥100 cigarettes in life
  smknow  = "SMQ040"      # Currently smoke
)

# --- Helper functions --------------------------------------------------------

#' Safe natural-log transform: returns NA for non-positive values
log_safe <- function(x) {
  ifelse(x > 0, log(x), NA_real_)
}

#' Quartile factor with clean labels
quartile_factor <- function(x, label_prefix = "Q") {
  q <- quantile(x, probs = c(0, .25, .5, .75, 1), na.rm = TRUE)
  cut(x, breaks = q, include.lowest = TRUE,
      labels = paste0(label_prefix, 1:4))
}

#' Recode NHANES missing codes to NA
nhanes_na <- function(x) {
  # Common NHANES refused/don't know codes
  x[x %in% c(7, 77, 777, 9, 99, 999, 9999)] <- NA
  x
}

#' Compute row-wise mean ignoring NA (for blood pressure averages)
rowmean_na <- function(...) {
  vals <- cbind(...)
  rowMeans(vals, na.rm = TRUE)
}

#' Quick missingness summary for a data frame
miss_summary <- function(df) {
  vars <- names(df)
  tibble(
    variable = vars,
    n_miss   = sapply(df, function(x) sum(is.na(x))),
    pct_miss = round(sapply(df, function(x) mean(is.na(x)) * 100), 1)
  ) |>
    arrange(desc(pct_miss))
}

#' Theme for publication-quality ggplots
theme_pub <- function(base_size = 12) {
  theme_bw(base_size = base_size) +
    theme(
      panel.grid.minor  = element_blank(),
      panel.grid.major  = element_line(color = "grey92"),
      strip.background  = element_rect(fill = "grey95", color = NA),
      legend.position   = "bottom",
      plot.title        = element_text(face = "bold", size = base_size + 1),
      plot.subtitle     = element_text(color = "grey40"),
      axis.title        = element_text(face = "bold"),
      plot.caption      = element_text(color = "grey50", size = 8)
    )
}

# Register theme globally
theme_set(theme_pub())

message("=== 00_setup.R: setup complete ===\n")
