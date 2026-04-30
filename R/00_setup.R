# =============================================================================
# 00_setup.R
# Project: Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers
# Purpose: Load libraries, set global options, define helper functions and
#          constants used across all analysis scripts
# Author:  Ao Xu
# Date:    2025
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
  library(janitor)
  library(haven)
  library(nhanesA)
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

# --- NHANES cycles -----------------------------------------------------------
# 2017-2018: suffix _J
# 2019-March 2020 (pre-pandemic): suffix _P
nhanes_cycles <- list(
  "2017-2018"       = "J",
  "2019-March 2020" = "P"
)

# NHANES file names by domain
nhanes_files <- list(
  demo   = c("DEMO_J",   "DEMO_P"),
  metals = c("PBCD_J",   "PBCD_P"),   # Blood Cd, Pb, Hg, Se, Mn
  crp    = c("CRP_J",    "CRP_P"),    # C-Reactive Protein
  ghb    = c("GHB_J",    "GHB_P"),    # Glycohemoglobin (HbA1c)
  tchol  = c("TCHOL_J",  "TCHOL_P"), # Total Cholesterol
  hdl    = c("HDL_J",    "HDL_P"),   # HDL Cholesterol
  bp     = c("BPX_J",    "BPXO_P"),  # Blood Pressure (format changed in _P)
  bpq    = c("BPQ_J",    "BPQ_P"),   # Blood Pressure Questionnaire (BP meds)
  bmx    = c("BMX_J",    "BMX_P"),   # Body Measures
  diet   = c("DR1TOT_J", "DR1TOT_P"),# 24-hr Dietary Recall Day 1
  smq    = c("SMQ_J",    "SMQ_P")    # Smoking Questionnaire
)

# --- Key variable names ------------------------------------------------------
# These map NHANES variable names to their roles. Verified against NHANES codebooks.
var_map <- list(
  # Identifiers / design
  seqn    = "SEQN",
  psu     = "SDMVPSU",
  strata  = "SDMVSTRA",
  wt_mec  = "WTMEC2YR",    # 2017-2018 MEC weight
  wt_pre  = "WTMECPRP",    # 2019-March 2020 pre-pandemic MEC weight

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
  hba1c   = "LBXGH",       # HbA1c %  (GHB files)
  crp     = "LBXCRP",      # C-Reactive Protein mg/dL (CRP files)
  tchol   = "LBXTC",       # Total Cholesterol mg/dL (TCHOL files)
  hdl     = "LBDHDD",      # HDL Cholesterol mg/dL (HDL files)

  # Body measures
  bmi     = "BMXBMI",

  # Blood pressure (BPX files)
  sbp1    = "BPXSY1",  sbp2 = "BPXSY2",  sbp3 = "BPXSY3",
  dbp1    = "BPXDI1",  dbp2 = "BPXDI2",  dbp3 = "BPXDI3",
  # 2019-March 2020 oscillometric BP (BPXO files)
  sbp1p   = "BPXOSY1", sbp2p = "BPXOSY2", sbp3p = "BPXOSY3",
  dbp1p   = "BPXODI1", dbp2p = "BPXODI2", dbp3p = "BPXODI3",

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
  df |>
    summarise(across(everything(),
                     list(n_miss = ~ sum(is.na(.)),
                          pct_miss = ~ round(mean(is.na(.)) * 100, 1)))) |>
    pivot_longer(everything(),
                 names_to = c("variable", ".value"),
                 names_sep = "_(?=[^_]+$)") |>
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
