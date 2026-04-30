# =============================================================================
# 03_define_variables.R
# Project: Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers
# Purpose: Create transformed and derived variables for analysis
#          - Log-transformed metal exposures
#          - Exposure quartiles
#          - Binary outcomes (prediabetes/diabetes, hypertension)
#          - Categorized covariates
#          - Standardized nutrition variable
# =============================================================================

source(here::here("R", "00_setup.R"))

message("=== 03_define_variables.R: variable engineering ===\n")

# --- Load analysis dataset ---------------------------------------------------
dat_path <- file.path(dir_processed, "analysis_dataset.rds")
if (!file.exists(dat_path)) stop("Run 02_clean_merge_data.R first.")
dat <- readRDS(dat_path)
message(glue("  Loaded: {nrow(dat)} participants"))

# =============================================================================
# 1. Metal exposure transformations
# =============================================================================
message("--- Transforming metal exposures ---")

# Distribution checks before transformation
metal_summary <- dat |>
  summarise(across(c(blood_lead, blood_cad, blood_hg),
                   list(n    = ~ sum(!is.na(.)),
                        mean = ~ mean(., na.rm = TRUE),
                        sd   = ~ sd(., na.rm = TRUE),
                        min  = ~ min(., na.rm = TRUE),
                        p25  = ~ quantile(., .25, na.rm = TRUE),
                        med  = ~ median(., na.rm = TRUE),
                        p75  = ~ quantile(., .75, na.rm = TRUE),
                        max  = ~ max(., na.rm = TRUE),
                        n_le0 = ~ sum(. <= 0, na.rm = TRUE)),
                   .names = "{.col}__{.fn}"))

message("  Metal exposure distributions (raw):")
print(pivot_longer(metal_summary, everything(),
                   names_to = c("variable", "stat"),
                   names_sep = "__") |>
        pivot_wider(names_from = stat, values_from = value))

dat <- dat |>
  mutate(
    # Log-transform (natural log): values <= 0 become NA (rare)
    log_lead = log_safe(blood_lead),
    log_cad  = log_safe(blood_cad),
    log_hg   = log_safe(blood_hg),

    # Quartiles: defined on analytic sample (excludes NA)
    q_lead = quartile_factor(blood_lead),
    q_cad  = quartile_factor(blood_cad),
    q_hg   = quartile_factor(blood_hg)
  )

# Report how many participants have valid log-transformed values
message(glue("  Valid log_lead: {sum(!is.na(dat$log_lead))}"))
message(glue("  Valid log_cad:  {sum(!is.na(dat$log_cad))}"))
message(glue("  Valid log_hg:   {sum(!is.na(dat$log_hg))}"))

# =============================================================================
# 2. Primary continuous outcome: HbA1c (already defined)
# =============================================================================
# HbA1c distribution check
message(glue("\n  HbA1c distribution: mean={round(mean(dat$hba1c, na.rm=TRUE),2)}, ",
             "SD={round(sd(dat$hba1c, na.rm=TRUE),2)}, ",
             "range=[{round(min(dat$hba1c, na.rm=TRUE),1)}, {round(max(dat$hba1c, na.rm=TRUE),1)}]"))

# =============================================================================
# 3. Binary outcome: Elevated HbA1c (prediabetes/diabetes threshold ≥ 5.7%)
# =============================================================================
# ADA definition: prediabetes 5.7-6.4%, diabetes ≥6.5%
# We define elevated as HbA1c ≥ 5.7% (any dysglycemia)
dat <- dat |>
  mutate(
    hba1c_elevated = case_when(
      is.na(hba1c) ~ NA_integer_,
      hba1c >= 5.7 ~ 1L,
      TRUE         ~ 0L
    ),
    hba1c_diabetes = case_when(
      is.na(hba1c) ~ NA_integer_,
      hba1c >= 6.5 ~ 1L,
      TRUE         ~ 0L
    )
  )

message(glue("  Elevated HbA1c (≥5.7%): {sum(dat$hba1c_elevated, na.rm=TRUE)} ",
             "({round(mean(dat$hba1c_elevated, na.rm=TRUE)*100,1)}%)"))
message(glue("  Diabetes-range HbA1c (≥6.5%): {sum(dat$hba1c_diabetes, na.rm=TRUE)} ",
             "({round(mean(dat$hba1c_diabetes, na.rm=TRUE)*100,1)}%)"))

# =============================================================================
# 4. Secondary outcome: Hypertension
# =============================================================================
# Definition: mean SBP ≥ 130 OR mean DBP ≥ 80 OR on antihypertensive medication
# (2017 ACC/AHA guideline, Stage 1+ hypertension)
dat <- dat |>
  mutate(
    hypertension = case_when(
      is.na(sbp) & is.na(dbp) & (is.na(bp_med) | bp_med == 0) ~ NA_integer_,
      sbp >= 130 | dbp >= 80 | bp_med == 1 ~ 1L,
      TRUE ~ 0L
    )
  )

message(glue("  Hypertension: {sum(dat$hypertension, na.rm=TRUE)} ",
             "({round(mean(dat$hypertension, na.rm=TRUE)*100,1)}%)"))

# =============================================================================
# 5. Nutrition variable: dietary fiber
# =============================================================================
message("\n--- Defining nutrition variable (dietary fiber) ---")

# Standardize fiber to z-score for continuous interaction terms
dat <- dat |>
  mutate(
    fiber_z = scale(fiber_g)[, 1],   # standardized (mean 0, SD 1)
    fiber_q = quartile_factor(fiber_g, "FQ")
  )

message(glue("  Fiber: n={sum(!is.na(dat$fiber_g))}, ",
             "mean={round(mean(dat$fiber_g, na.rm=TRUE),1)}g, ",
             "SD={round(sd(dat$fiber_g, na.rm=TRUE),1)}g"))

# =============================================================================
# 6. Covariate categorization
# =============================================================================
message("--- Categorizing covariates ---")

dat <- dat |>
  mutate(
    # Age groups
    age_cat = cut(age,
                  breaks = c(20, 40, 60, Inf),
                  labels = c("20-39", "40-59", "60+"),
                  right  = FALSE),

    # BMI category (WHO/NHLBI)
    bmi_cat = cut(bmi,
                  breaks = c(0, 18.5, 25, 30, Inf),
                  labels = c("Underweight (<18.5)",
                             "Normal (18.5-24.9)",
                             "Overweight (25-29.9)",
                             "Obese (≥30)"),
                  right  = FALSE),

    # PIR category
    pir_cat = cut(pir,
                  breaks = c(0, 1, 2, 3, Inf),
                  labels = c("<1 (Below poverty)",
                             "1-<2",
                             "2-<3",
                             "≥3"),
                  right  = FALSE,
                  include.lowest = TRUE),

    # Education binary: < vs. ≥ college
    educ_bin = case_when(
      educ %in% c("College graduate or above") ~ "College graduate+",
      !is.na(educ) ~ "Less than college",
      TRUE ~ NA_character_
    ) |> factor(levels = c("Less than college", "College graduate+"))
  )

# =============================================================================
# 7. Clean variable labels for tables
# =============================================================================
# Using attr() labels compatible with gtsummary
var_labels <- list(
  blood_lead    = "Blood lead (µg/dL)",
  blood_cad     = "Blood cadmium (µg/dL)",
  blood_hg      = "Blood total mercury (µg/L)",
  log_lead      = "Log blood lead (µg/dL)",
  log_cad       = "Log blood cadmium (µg/dL)",
  log_hg        = "Log blood mercury (µg/L)",
  q_lead        = "Blood lead quartile",
  hba1c         = "HbA1c (%)",
  hba1c_elevated = "Elevated HbA1c (≥5.7%)",
  crp           = "C-reactive protein (mg/dL)",
  total_chol    = "Total cholesterol (mg/dL)",
  hdl_chol      = "HDL cholesterol (mg/dL)",
  sbp           = "Systolic blood pressure (mmHg)",
  dbp           = "Diastolic blood pressure (mmHg)",
  hypertension  = "Hypertension",
  bmi           = "BMI (kg/m²)",
  bmi_cat       = "BMI category",
  age           = "Age (years)",
  age_cat       = "Age category",
  sex           = "Sex",
  race_eth      = "Race/ethnicity",
  educ          = "Education",
  pir           = "Poverty-income ratio",
  pir_cat       = "Poverty-income ratio category",
  smoke_status  = "Smoking status",
  fiber_g       = "Dietary fiber (g/day)",
  vitc_mg       = "Vitamin C (mg/day)",
  energy_kcal   = "Energy intake (kcal/day)",
  calcium_mg    = "Calcium (mg/day)",
  iron_mg       = "Iron (mg/day)",
  cycle         = "NHANES cycle"
)

# Apply labels
for (v in names(var_labels)) {
  if (v %in% names(dat)) attr(dat[[v]], "label") <- var_labels[[v]]
}

# =============================================================================
# 8. Save engineered dataset
# =============================================================================
saveRDS(dat, file.path(dir_processed, "analysis_dataset_v2.rds"))
write_csv(dat, file.path(dir_processed, "analysis_dataset_v2.csv"))

message(glue("\n  Saved: data/processed/analysis_dataset_v2.rds ({nrow(dat)} rows, {ncol(dat)} cols)"))
message("\n=== 03_define_variables.R: complete ===\n")
