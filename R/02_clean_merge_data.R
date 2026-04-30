# =============================================================================
# 02_clean_merge_data.R
# Project: Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers
# Purpose: Load NHANES 2017-2018 raw files, merge by SEQN, apply exclusions,
#          and save analysis-ready dataset.
#
# NOTE: Single-cycle (2017-2018 only). WTMEC2YR used directly as survey weight
#       (no division needed for single cycle).
# NOTE: CRP variable is LBXHSCRP (mg/L) from HSCRP_J, not LBXCRP.
#       LBXHSCRP is the high-sensitivity CRP assay; results are mg/L.
#       We convert to mg/dL (* 0.1) for consistency with prior NHANES analyses.
# =============================================================================

source(here::here("R", "00_setup.R"))

message("=== 02_clean_merge_data.R: merging NHANES 2017-2018 ===\n")

# -----------------------------------------------------------------------------
# Helper: load raw .rds with informative error
# Haven imports data with labelled class; we strip labels for clean numerics
# -----------------------------------------------------------------------------
load_raw <- function(table_name) {
  path <- file.path(dir_raw, paste0(table_name, ".rds"))
  if (!file.exists(path)) {
    stop(glue("Raw file not found: {path}\nRun 01_download_data.R first."))
  }
  dat <- readRDS(path) |>
    as_tibble() |>
    # Strip haven_labelled class so numeric operations work correctly
    mutate(across(where(haven::is.labelled), haven::zap_labels))
  message(glue("  Loaded {table_name}: {nrow(dat)} rows x {ncol(dat)} cols"))
  dat
}

# =============================================================================
# 1. Load all files
# =============================================================================
message("--- Loading NHANES 2017-2018 files ---")

demo  <- load_raw("DEMO_J")
pbcd  <- load_raw("PBCD_J")
hscrp <- load_raw("HSCRP_J")
ghb   <- load_raw("GHB_J")
tchol <- load_raw("TCHOL_J")
hdl   <- load_raw("HDL_J")
bpx   <- load_raw("BPX_J")
bpq   <- load_raw("BPQ_J")
bmx   <- load_raw("BMX_J")
diet  <- load_raw("DR1TOT_J")
smq   <- load_raw("SMQ_J")

# =============================================================================
# 2. Pre-process individual files
# =============================================================================
message("\n--- Pre-processing files ---")

# Blood pressure: row-mean of readings (ignore 0s which encode missing in BPX)
bpx_clean <- bpx |>
  mutate(
    across(c(BPXSY1, BPXSY2, BPXSY3), ~ na_if(., 0)),
    across(c(BPXDI1, BPXDI2, BPXDI3), ~ na_if(., 0)),
    sbp_mean = rowMeans(cbind(BPXSY1, BPXSY2, BPXSY3), na.rm = TRUE),
    dbp_mean = rowMeans(cbind(BPXDI1, BPXDI2, BPXDI3), na.rm = TRUE),
    # If all 3 readings are NA, rowMeans returns NaN -> set to NA
    sbp_mean = ifelse(is.nan(sbp_mean), NA_real_, sbp_mean),
    dbp_mean = ifelse(is.nan(dbp_mean), NA_real_, dbp_mean)
  ) |>
  select(SEQN, sbp_mean, dbp_mean)

# BP medication (antihypertensive: BPQ050A = 1 = Yes)
bpq_clean <- bpq |>
  mutate(bp_med = case_when(
    BPQ050A == 1 ~ 1L,
    BPQ050A == 2 ~ 0L,
    TRUE         ~ 0L   # missing -> assume not on medication (conservative)
  )) |>
  select(SEQN, bp_med)

# Smoking status (recode missing codes to NA first)
smq_clean <- smq |>
  mutate(
    smq020 = nhanes_na(SMQ020),  # smoked >=100 cigarettes
    smq040 = nhanes_na(SMQ040),  # currently smoke
    smoke_status = case_when(
      smq020 == 2                       ~ "Never",
      smq020 == 1 & smq040 == 3        ~ "Former",
      smq020 == 1 & smq040 %in% c(1,2) ~ "Current",
      TRUE                              ~ NA_character_
    )
  ) |>
  select(SEQN, smoke_status)

# HSCRP: convert mg/L to mg/dL for comparability (mg/dL = mg/L * 0.1)
hscrp_clean <- hscrp |>
  mutate(crp_mgdl = LBXHSCRP * 0.1) |>
  select(SEQN, crp_mgdl, LBXHSCRP)

# =============================================================================
# 3. Merge all files by SEQN (left join from demo as base)
# =============================================================================
message("\n--- Merging all files by SEQN ---")

merged <- demo |>
  select(SEQN, RIDAGEYR, RIAGENDR, RIDRETH3, DMDEDUC2, INDFMPIR,
         SDMVPSU, SDMVSTRA, WTMEC2YR) |>
  left_join(select(pbcd,  SEQN, LBXBPB, LBXBCD, LBXTHG),   by = "SEQN") |>
  left_join(hscrp_clean,                                      by = "SEQN") |>
  left_join(select(ghb,   SEQN, LBXGH),                      by = "SEQN") |>
  left_join(select(tchol, SEQN, LBXTC),                      by = "SEQN") |>
  left_join(select(hdl,   SEQN, LBDHDD),                     by = "SEQN") |>
  left_join(bpx_clean,                                        by = "SEQN") |>
  left_join(bpq_clean,                                        by = "SEQN") |>
  left_join(select(bmx,   SEQN, BMXBMI),                     by = "SEQN") |>
  left_join(select(diet,  SEQN, DR1TFIBE, DR1TVC, DR1TKCAL, DR1TCALC, DR1TIRON),
            by = "SEQN") |>
  left_join(smq_clean,                                        by = "SEQN") |>
  mutate(cycle = "2017-2018")

message(glue("  Merged dataset: {nrow(merged)} rows x {ncol(merged)} cols"))

# =============================================================================
# 4. Clean and recode variables
# =============================================================================
message("\n--- Recoding variables ---")

clean_data <- merged |>
  mutate(
    # Survey design
    psu    = SDMVPSU,
    strata = SDMVSTRA,
    wt_mec = WTMEC2YR,  # single-cycle: use weight directly (no halving)

    # Demographics
    age = RIDAGEYR,
    sex = factor(RIAGENDR, levels = c(1, 2), labels = c("Male", "Female")),

    race_eth = factor(RIDRETH3,
                      levels = c(1, 2, 3, 4, 6, 7),
                      labels = c("Mexican American", "Other Hispanic",
                                 "Non-Hispanic White", "Non-Hispanic Black",
                                 "Non-Hispanic Asian", "Other/Multiracial")),

    educ = factor(nhanes_na(DMDEDUC2),
                  levels = 1:5,
                  labels = c("Less than 9th grade", "9-11th grade",
                             "High school/GED", "Some college/AA",
                             "College graduate+")),

    pir = if_else(INDFMPIR > 5, 5, INDFMPIR),  # top-code at 5

    # Metals (keep raw; log-transform in 03)
    blood_lead = LBXBPB,
    blood_cad  = LBXBCD,
    blood_hg   = LBXTHG,

    # Outcomes
    hba1c      = LBXGH,
    crp        = crp_mgdl,       # mg/dL (converted from HSCRP mg/L)
    crp_mgl    = LBXHSCRP,      # mg/L (original units, saved for reference)
    total_chol = LBXTC,
    hdl_chol   = LBDHDD,
    sbp        = sbp_mean,
    dbp        = dbp_mean,

    # Body measures
    bmi = BMXBMI,

    # Nutrition
    fiber_g     = DR1TFIBE,
    vitc_mg     = DR1TVC,
    energy_kcal = DR1TKCAL,
    calcium_mg  = DR1TCALC,
    iron_mg     = DR1TIRON,

    # Behavioral
    smoke_status = factor(smoke_status, levels = c("Never", "Former", "Current"))
  ) |>
  select(
    SEQN, cycle, psu, strata, wt_mec,
    age, sex, race_eth, educ, pir,
    blood_lead, blood_cad, blood_hg,
    hba1c, crp, crp_mgl, total_chol, hdl_chol, sbp, dbp,
    bmi, fiber_g, vitc_mg, energy_kcal, calcium_mg, iron_mg,
    smoke_status, bp_med
  )

# =============================================================================
# 5. Exclusion criteria
# =============================================================================
message("\n--- Applying exclusion criteria ---")

n_start <- nrow(clean_data)
exclusion_log <- tibble(step = character(), n_remaining = integer(), n_excluded = integer())

log_step <- function(df, label) {
  n_rem <- nrow(df)
  exclusion_log <<- bind_rows(
    exclusion_log,
    tibble(step = label, n_remaining = n_rem, n_excluded = n_start - n_rem)
  )
  n_start <<- n_rem
  df
}

analysis_data <- clean_data |>
  log_step("Full NHANES 2017-2018 sample") |>
  filter(age >= 20) |>
  log_step("Restrict to adults aged ≥20") |>
  filter(!is.na(wt_mec) & wt_mec > 0) |>
  log_step("Exclude zero/missing MEC exam weight") |>
  filter(!is.na(blood_lead) | !is.na(blood_cad) | !is.na(blood_hg)) |>
  log_step("Exclude missing all three metal exposures") |>
  filter(!is.na(hba1c)) |>
  log_step("Exclude missing HbA1c (primary outcome)") |>
  filter(!is.na(age) & !is.na(sex) & !is.na(race_eth)) |>
  log_step("Exclude missing age, sex, or race/ethnicity")

message("\nExclusion flow:")
print(exclusion_log)
message(glue("\nFinal analytic sample: {nrow(analysis_data)} participants"))

# Check wt_mec is positive for all (required for survey design)
stopifnot("Negative weights found" = all(analysis_data$wt_mec > 0, na.rm = TRUE))

# =============================================================================
# 6. Save outputs
# =============================================================================
saveRDS(analysis_data, file.path(dir_processed, "analysis_dataset.rds"))
saveRDS(analysis_data, file.path(dir_processed, "analysis_dataset_v2.rds")) # alias for later scripts
saveRDS(exclusion_log, file.path(dir_processed, "exclusion_log.rds"))
write_csv(analysis_data, file.path(dir_processed, "analysis_dataset.csv"))
write_csv(exclusion_log, file.path(dir_processed, "exclusion_log.csv"))

# Missingness report
miss_rpt <- miss_summary(analysis_data)
write_csv(miss_rpt, file.path(dir_codebook, "missingness_report.csv"))

message(glue("\nSaved analysis_dataset.rds ({nrow(analysis_data)} rows)"))
message(glue("Saved exclusion_log.rds"))
message(glue("Saved missingness_report.csv"))
message("\n=== 02_clean_merge_data.R: complete ===\n")
