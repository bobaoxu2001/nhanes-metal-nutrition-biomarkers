# =============================================================================
# 02_clean_merge_data.R
# Project: Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers
# Purpose: Load raw NHANES files, harmonize across cycles, merge by SEQN,
#          apply exclusions, and save analysis-ready dataset
# =============================================================================

source(here::here("R", "00_setup.R"))

message("=== 02_clean_merge_data.R: starting data merge ===\n")

# -----------------------------------------------------------------------------
# Helper: load raw table; stop with informative error if missing
# -----------------------------------------------------------------------------
load_raw <- function(table_name) {
  path <- file.path(dir_raw, paste0(table_name, ".rds"))
  if (!file.exists(path)) {
    stop(glue(
      "Raw file not found: {path}\n",
      "Run 01_download_data.R first, or manually download and save as RDS."
    ))
  }
  readRDS(path) |>
    janitor::clean_names() |>
    as_tibble()
}

# =============================================================================
# 1. Load and harmonize 2017-2018 (_J) files
# =============================================================================
message("--- Loading 2017-2018 (cycle J) ---")

demo_j   <- load_raw("DEMO_J")
metals_j <- load_raw("PBCD_J")
ghb_j    <- load_raw("GHB_J")
crp_j    <- load_raw("CRP_J")
tchol_j  <- load_raw("TCHOL_J")
hdl_j    <- load_raw("HDL_J")
bpx_j    <- load_raw("BPX_J")
bpq_j    <- load_raw("BPQ_J")
bmx_j    <- load_raw("BMX_J")
diet_j   <- load_raw("DR1TOT_J")
smq_j    <- load_raw("SMQ_J")

# Blood pressure: average available readings
# BPX_J uses BPXSY1/2/3 and BPXDI1/2/3
bpx_j <- bpx_j |>
  mutate(
    sbp_mean = rowmean_na(bpxsy1, bpxsy2, bpxsy3),
    dbp_mean = rowmean_na(bpxdi1, bpxdi2, bpxdi3)
  ) |>
  select(seqn, sbp_mean, dbp_mean)

# BP medication (antihypertensive): BPQ050A = 1 means currently taking
bpq_j <- bpq_j |>
  mutate(bp_med = if_else(bpq050a == 1, 1L, 0L, missing = 0L)) |>
  select(seqn, bp_med)

# Smoking: recode to Never / Former / Current
smq_j <- smq_j |>
  mutate(
    smq020 = nhanes_na(smq020),
    smq040 = nhanes_na(smq040),
    smoke_status = case_when(
      smq020 == 2              ~ "Never",
      smq020 == 1 & smq040 == 3 ~ "Former",
      smq020 == 1 & smq040 %in% c(1, 2) ~ "Current",
      TRUE ~ NA_character_
    )
  ) |>
  select(seqn, smoke_status)

# Assemble cycle J wide
cycle_j <- demo_j |>
  select(seqn, ridageyr, riagendr, ridreth3, dmdeduc2, indfmpir,
         sdmvpsu, sdmvstra, wtmec2yr) |>
  left_join(select(metals_j, seqn, lbxbpb, lbxbcd, lbxthg), by = "seqn") |>
  left_join(select(ghb_j,    seqn, lbxgh),   by = "seqn") |>
  left_join(select(crp_j,    seqn, lbxcrp),  by = "seqn") |>
  left_join(select(tchol_j,  seqn, lbxtc),   by = "seqn") |>
  left_join(select(hdl_j,    seqn, lbdhdd),  by = "seqn") |>
  left_join(bpx_j,                           by = "seqn") |>
  left_join(bpq_j,                           by = "seqn") |>
  left_join(select(bmx_j, seqn, bmxbmi),     by = "seqn") |>
  left_join(select(diet_j, seqn, dr1tfibe, dr1tvc, dr1tkcal, dr1tcalc, dr1tiron),
            by = "seqn") |>
  left_join(smq_j, by = "seqn") |>
  mutate(
    cycle      = "2017-2018",
    wt_combined = wtmec2yr / 2   # 4-year combined weight (divided by num cycles)
  )

message(glue("  Cycle J: {nrow(cycle_j)} participants"))

# =============================================================================
# 2. Load and harmonize 2019-March 2020 (_P) files
# =============================================================================
message("--- Loading 2019-March 2020 (cycle P) ---")

demo_p   <- load_raw("DEMO_P")
metals_p <- load_raw("PBCD_P")
ghb_p    <- load_raw("GHB_P")
crp_p    <- load_raw("CRP_P")
tchol_p  <- load_raw("TCHOL_P")
hdl_p    <- load_raw("HDL_P")
bpxo_p   <- load_raw("BPXO_P")   # Oscillometric BP in _P cycle
bpq_p    <- load_raw("BPQ_P")
bmx_p    <- load_raw("BMX_P")
diet_p   <- load_raw("DR1TOT_P")
smq_p    <- load_raw("SMQ_P")

# 2019-March 2020 uses oscillometric readings: BPXOSY1/2/3 and BPXODI1/2/3
bpxo_p <- bpxo_p |>
  mutate(
    sbp_mean = rowmean_na(bpxosy1, bpxosy2, bpxosy3),
    dbp_mean = rowmean_na(bpxodi1, bpxodi2, bpxodi3)
  ) |>
  select(seqn, sbp_mean, dbp_mean)

bpq_p <- bpq_p |>
  mutate(bp_med = if_else(bpq050a == 1, 1L, 0L, missing = 0L)) |>
  select(seqn, bp_med)

smq_p <- smq_p |>
  mutate(
    smq020 = nhanes_na(smq020),
    smq040 = nhanes_na(smq040),
    smoke_status = case_when(
      smq020 == 2              ~ "Never",
      smq020 == 1 & smq040 == 3 ~ "Former",
      smq020 == 1 & smq040 %in% c(1, 2) ~ "Current",
      TRUE ~ NA_character_
    )
  ) |>
  select(seqn, smoke_status)

# 2019-March 2020 uses WTMECPRP (pre-pandemic weight)
cycle_p <- demo_p |>
  select(seqn, ridageyr, riagendr, ridreth3, dmdeduc2, indfmpir,
         sdmvpsu, sdmvstra, wtmecprp) |>
  rename(wtmec2yr = wtmecprp) |>    # harmonize name for binding
  left_join(select(metals_p, seqn, lbxbpb, lbxbcd, lbxthg), by = "seqn") |>
  left_join(select(ghb_p,    seqn, lbxgh),   by = "seqn") |>
  left_join(select(crp_p,    seqn, lbxcrp),  by = "seqn") |>
  left_join(select(tchol_p,  seqn, lbxtc),   by = "seqn") |>
  left_join(select(hdl_p,    seqn, lbdhdd),  by = "seqn") |>
  left_join(bpxo_p,                          by = "seqn") |>
  left_join(bpq_p,                           by = "seqn") |>
  left_join(select(bmx_p, seqn, bmxbmi),     by = "seqn") |>
  left_join(select(diet_p, seqn, dr1tfibe, dr1tvc, dr1tkcal, dr1tcalc, dr1tiron),
            by = "seqn") |>
  left_join(smq_p, by = "seqn") |>
  mutate(
    cycle      = "2019-March 2020",
    wt_combined = wtmec2yr / 2
  )

message(glue("  Cycle P: {nrow(cycle_p)} participants"))

# =============================================================================
# 3. Stack cycles
# =============================================================================
message("--- Stacking cycles ---")

raw_merged <- bind_rows(cycle_j, cycle_p)
message(glue("  Combined dataset: {nrow(raw_merged)} rows x {ncol(raw_merged)} cols"))

# =============================================================================
# 4. Standardize and clean variable coding
# =============================================================================
message("--- Cleaning and recoding variables ---")

clean_data <- raw_merged |>
  mutate(
    # --- Demographics ---
    age     = ridageyr,
    sex     = factor(riagendr, levels = c(1, 2), labels = c("Male", "Female")),

    # Race/ethnicity: RIDRETH3 categories
    race_eth = factor(ridreth3,
                      levels = c(1, 2, 3, 4, 6, 7),
                      labels = c("Mexican American",
                                 "Other Hispanic",
                                 "Non-Hispanic White",
                                 "Non-Hispanic Black",
                                 "Non-Hispanic Asian",
                                 "Other/Multiracial")),

    # Education (adults)
    educ = factor(nhanes_na(dmdeduc2),
                  levels = c(1, 2, 3, 4, 5),
                  labels = c("Less than 9th grade",
                             "9-11th grade",
                             "High school / GED",
                             "Some college / AA",
                             "College graduate or above")),

    # Poverty-income ratio: values > 5 are top-coded at 5
    pir = if_else(indfmpir > 5, 5, indfmpir),

    # --- Metal exposures (keep as numeric, NAs already NA from nhanesA) ---
    blood_lead  = lbxbpb,
    blood_cad   = lbxbcd,
    blood_hg    = lbxthg,

    # --- Outcomes ---
    hba1c       = lbxgh,
    crp         = lbxcrp,
    total_chol  = lbxtc,
    hdl_chol    = lbdhdd,
    sbp         = sbp_mean,
    dbp         = dbp_mean,

    # --- Body measures ---
    bmi         = bmxbmi,

    # --- Nutrition ---
    fiber_g     = dr1tfibe,
    vitc_mg     = dr1tvc,
    energy_kcal = dr1tkcal,
    calcium_mg  = dr1tcalc,
    iron_mg     = dr1tiron,

    # --- Smoking ---
    smoke_status = factor(smoke_status,
                          levels = c("Never", "Former", "Current")),

    # --- Survey weights ---
    psu    = sdmvpsu,
    strata = sdmvstra,
    wt_mec = wt_combined
  ) |>
  select(seqn, cycle, psu, strata, wt_mec,
         age, sex, race_eth, educ, pir,
         blood_lead, blood_cad, blood_hg,
         hba1c, crp, total_chol, hdl_chol, sbp, dbp,
         bmi, fiber_g, vitc_mg, energy_kcal, calcium_mg, iron_mg,
         smoke_status, bp_med)

# =============================================================================
# 5. Apply exclusion criteria
# =============================================================================
message("--- Applying exclusion criteria ---")

n_start <- nrow(clean_data)
exclusion_log <- tibble(step = character(), n_remaining = integer(), n_excluded = integer())

log_step <- function(df, step_label) {
  n_rem <- nrow(df)
  n_exc <- n_start - n_rem
  exclusion_log <<- bind_rows(exclusion_log,
                              tibble(step = step_label, n_remaining = n_rem, n_excluded = n_exc))
  n_start <<- n_rem
  df
}

analysis_data <- clean_data |>
  log_step("Starting N (all NHANES participants)") |>

  # Restrict to adults aged 20+
  filter(age >= 20) |>
  log_step("Exclude age < 20") |>

  # Require MEC exam weight > 0 (i.e., actually examined)
  filter(!is.na(wt_mec) & wt_mec > 0) |>
  log_step("Exclude missing/zero MEC exam weight") |>

  # Require at least one metal exposure measured
  filter(!is.na(blood_lead) | !is.na(blood_cad) | !is.na(blood_hg)) |>
  log_step("Exclude missing all three metal exposures") |>

  # Require HbA1c (primary continuous outcome)
  filter(!is.na(hba1c)) |>
  log_step("Exclude missing HbA1c (primary outcome)") |>

  # Require key demographic covariates
  filter(!is.na(age) & !is.na(sex) & !is.na(race_eth)) |>
  log_step("Exclude missing age, sex, or race/ethnicity")

message("\nExclusion flow:")
print(exclusion_log)

n_final <- nrow(analysis_data)
message(glue("\n  Final analytic sample: {n_final} participants"))

# =============================================================================
# 6. Save outputs
# =============================================================================
saveRDS(analysis_data,  file.path(dir_processed, "analysis_dataset.rds"))
saveRDS(exclusion_log,  file.path(dir_processed, "exclusion_log.rds"))
write_csv(analysis_data, file.path(dir_processed, "analysis_dataset.csv"))
write_csv(exclusion_log, file.path(dir_processed, "exclusion_log.csv"))

message(glue("\n  Saved: data/processed/analysis_dataset.rds  ({n_final} rows)"))
message(glue("  Saved: data/processed/exclusion_log.rds"))

# Missingness report
miss_rpt <- miss_summary(analysis_data)
write_csv(miss_rpt, file.path(dir_codebook, "missingness_report.csv"))
message(glue("  Saved: data/codebook/missingness_report.csv"))

message("\n=== 02_clean_merge_data.R: complete ===\n")
