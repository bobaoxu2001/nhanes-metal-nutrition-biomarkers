# =============================================================================
# 05_regression_models.R
# Project: Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers
# Purpose: Run linear and logistic regression models (survey-weighted)
#
# Model structure (primary exposure: log blood lead; outcome: HbA1c):
#   Model 1 (Unadjusted):    hba1c ~ log_lead
#   Model 2 (Demo-adjusted): hba1c ~ log_lead + age + sex + race_eth
#   Model 3 (Fully adjusted): + educ + pir + bmi + smoke_status + fiber_z
#   Model 4 (Interaction):   + log_lead * fiber_z
#   Binary outcome: logistic regression with hba1c_elevated
#   Sensitivity:   Repeat for blood cadmium and mercury
# =============================================================================

source(here::here("R", "00_setup.R"))
library(broom)
library(survey)

message("=== 05_regression_models.R: regression models ===\n")

# --- Load data ---------------------------------------------------------------
dat_path <- file.path(dir_processed, "analysis_dataset_v2.rds")
if (!file.exists(dat_path)) stop("Run 03_define_variables.R first.")
dat <- readRDS(dat_path)

# --- Survey design -----------------------------------------------------------
svy <- svydesign(
  ids     = ~psu,
  strata  = ~strata,
  weights = ~wt_mec,
  data    = dat,
  nest    = TRUE
)

# --- Complete-case subsets for each primary model ----------------------------
# Require: log_lead, hba1c, age, sex, race_eth, educ, pir, bmi, smoke_status, fiber_z
base_covs  <- c("log_lead", "hba1c", "age", "sex", "race_eth")
full_covs  <- c(base_covs, "educ", "pir", "bmi", "smoke_status", "fiber_z")
binary_covs <- c(full_covs[full_covs != "hba1c"], "hba1c_elevated")

complete_full  <- dat |> select(all_of(full_covs),  SEQN) |> drop_na()
complete_bin   <- dat |> select(all_of(binary_covs), SEQN) |> drop_na()

svy_full <- subset(svy, SEQN %in% complete_full$SEQN)
svy_bin  <- subset(svy, SEQN %in% complete_bin$SEQN)

message(glue("  Analytic N for continuous models: {nrow(complete_full)}"))
message(glue("  Analytic N for binary models:    {nrow(complete_bin)}"))

# =============================================================================
# Helper: tidy survey model with 95% CI
#
# NOTE ON DEGREES OF FREEDOM:
#   NHANES 2017-2018 has 15 strata × 2 PSUs → 15 design df.
#   Fully adjusted models have ~18 parameters → df.residual < 0.
#   When df.residual < 0, we use a normal approximation (df = Inf, z = 1.96),
#   which is standard for large NHANES samples (n > 3,000) and recommended
#   by NCHS when the model saturates the design df.
#   p-values from summary() use the survey package's internal Wald test.
# =============================================================================
tidy_svy <- function(svy_model, exponentiate = FALSE) {
  sm    <- summary(svy_model)$coefficients   # Est, SE, t-value, p-value
  coefs <- sm[, 1]
  ses   <- sm[, 2]
  pvals <- sm[, 4]

  # Determine effective df: use model df if positive, else design df, else Inf
  df_model  <- svy_model$df.residual
  df_design <- tryCatch(degf(svy_model$survey.design), error = function(e) Inf)
  df_use    <- if (!is.null(df_model) && is.finite(df_model) && df_model > 0) {
    df_model
  } else if (is.finite(df_design) && df_design > 0) {
    df_design
  } else {
    Inf   # normal approximation: appropriate for large n (>3000)
  }

  z_crit  <- qt(0.975, df = df_use)   # 1.96 when df = Inf
  tstats  <- coefs / ses
  # Recompute p-values with the effective df (avoids NaN from negative df.residual)
  pvals_adj <- 2 * pt(abs(tstats), df = df_use, lower.tail = FALSE)

  res <- tibble(
    term      = rownames(sm),
    estimate  = coefs,
    std.error = ses,
    statistic = tstats,
    p.value   = pvals_adj,
    conf.low  = coefs - z_crit * ses,
    conf.high = coefs + z_crit * ses,
    df_used   = df_use
  )

  if (exponentiate) {
    res <- res |> mutate(across(c(estimate, conf.low, conf.high), exp))
  }
  res
}

# =============================================================================
# PRIMARY: Linear models — log blood lead → HbA1c (survey-weighted)
# =============================================================================
message("\n--- Linear models: log_lead → HbA1c ---")

# Model 1: Unadjusted
m1_svy <- svyglm(hba1c ~ log_lead,
                 design = svy_full,
                 family = gaussian())

# Model 2: Demographically adjusted
m2_svy <- svyglm(hba1c ~ log_lead + age + sex + race_eth,
                 design = svy_full,
                 family = gaussian())

# Model 3: Fully adjusted
m3_svy <- svyglm(hba1c ~ log_lead + age + sex + race_eth +
                   educ + pir + bmi + smoke_status + fiber_z,
                 design = svy_full,
                 family = gaussian())

# Model 4: Interaction — log_lead × fiber_z
m4_svy <- svyglm(hba1c ~ log_lead * fiber_z + age + sex + race_eth +
                   educ + pir + bmi + smoke_status,
                 design = svy_full,
                 family = gaussian())

# Tidy outputs
linear_results <- bind_rows(
  tidy_svy(m1_svy) |> mutate(model = "Model 1: Unadjusted"),
  tidy_svy(m2_svy) |> mutate(model = "Model 2: Demo-adjusted"),
  tidy_svy(m3_svy) |> mutate(model = "Model 3: Fully adjusted"),
  tidy_svy(m4_svy) |> mutate(model = "Model 4: + Lead×Fiber interaction")
)

# Extract log_lead rows for summary table
lead_linear <- linear_results |>
  filter(term == "log_lead") |>
  select(model, estimate, std.error, conf.low, conf.high, p.value) |>
  mutate(across(where(is.numeric), ~ round(., 4)))

message("  Lead-HbA1c association (β per 1-unit log_lead):")
print(lead_linear)

write_csv(linear_results, file.path(dir_tables, "linear_models_lead_hba1c.csv"))
write_csv(lead_linear,    file.path(dir_tables, "lead_hba1c_summary.csv"))

# =============================================================================
# BINARY: Logistic models — log blood lead → Elevated HbA1c (≥5.7%)
# =============================================================================
message("\n--- Logistic models: log_lead → Elevated HbA1c ---")

lg1_svy <- svyglm(hba1c_elevated ~ log_lead,
                  design = svy_bin,
                  family = quasibinomial())

lg2_svy <- svyglm(hba1c_elevated ~ log_lead + age + sex + race_eth,
                  design = svy_bin,
                  family = quasibinomial())

lg3_svy <- svyglm(hba1c_elevated ~ log_lead + age + sex + race_eth +
                    educ + pir + bmi + smoke_status + fiber_z,
                  design = svy_bin,
                  family = quasibinomial())

logit_results <- bind_rows(
  tidy_svy(lg1_svy, exponentiate = TRUE) |> mutate(model = "Model 1: Unadjusted"),
  tidy_svy(lg2_svy, exponentiate = TRUE) |> mutate(model = "Model 2: Demo-adjusted"),
  tidy_svy(lg3_svy, exponentiate = TRUE) |> mutate(model = "Model 3: Fully adjusted")
)

lead_logit <- logit_results |>
  filter(term == "log_lead") |>
  select(model, estimate, conf.low, conf.high, p.value) |>
  rename(OR = estimate) |>
  mutate(across(where(is.numeric), ~ round(., 4)))

message("  Lead-Elevated HbA1c association (OR per 1-unit log_lead):")
print(lead_logit)

write_csv(logit_results, file.path(dir_tables, "logistic_models_lead_hba1c_elevated.csv"))
write_csv(lead_logit,    file.path(dir_tables, "lead_hba1c_elevated_summary.csv"))

# =============================================================================
# SENSITIVITY: Cadmium and Mercury → HbA1c (fully adjusted)
# =============================================================================
message("\n--- Sensitivity: cadmium and mercury fully-adjusted models ---")

# Cadmium complete-case subset
cad_covs <- c("log_cad", "hba1c", "age", "sex", "race_eth",
              "educ", "pir", "bmi", "smoke_status", "fiber_z")
dat_cad   <- dat |> select(all_of(cad_covs), SEQN) |> drop_na()
svy_cad   <- subset(svy, SEQN %in% dat_cad$SEQN)

m_cad_svy <- svyglm(hba1c ~ log_cad + age + sex + race_eth +
                      educ + pir + bmi + smoke_status + fiber_z,
                    design = svy_cad,
                    family = gaussian())

# Mercury complete-case subset
hg_covs  <- c("log_hg",  "hba1c", "age", "sex", "race_eth",
              "educ", "pir", "bmi", "smoke_status", "fiber_z")
dat_hg   <- dat |> select(all_of(hg_covs), SEQN) |> drop_na()
svy_hg   <- subset(svy, SEQN %in% dat_hg$SEQN)

m_hg_svy <- svyglm(hba1c ~ log_hg + age + sex + race_eth +
                     educ + pir + bmi + smoke_status + fiber_z,
                   design = svy_hg,
                   family = gaussian())

sensitivity_results <- bind_rows(
  tidy_svy(m_cad_svy) |>
    filter(term == "log_cad") |>
    mutate(exposure = "Blood cadmium", model = "Fully adjusted"),
  tidy_svy(m_hg_svy) |>
    filter(term == "log_hg") |>
    mutate(exposure = "Blood mercury", model = "Fully adjusted"),
  tidy_svy(m3_svy) |>
    filter(term == "log_lead") |>
    mutate(exposure = "Blood lead",   model = "Fully adjusted")
) |>
  select(exposure, model, estimate, std.error, conf.low, conf.high, p.value) |>
  mutate(across(where(is.numeric), ~ round(., 4)))

message("  Sensitivity: all metals → HbA1c (fully adjusted):")
print(sensitivity_results)
write_csv(sensitivity_results, file.path(dir_tables, "sensitivity_all_metals_hba1c.csv"))

# =============================================================================
# STRATIFIED: Lead → HbA1c by fiber tertile
# =============================================================================
message("\n--- Stratified models: lead × fiber ---")

dat_strat <- dat |>
  filter(!is.na(log_lead) & !is.na(hba1c) & !is.na(fiber_g) &
           !is.na(age) & !is.na(sex) & !is.na(race_eth) &
           !is.na(educ) & !is.na(pir) & !is.na(bmi) & !is.na(smoke_status)) |>
  mutate(fiber_tertile = ntile(fiber_g, 3) |> factor(labels = c("Low", "Medium", "High")))

strat_results <- dat_strat |>
  group_by(fiber_tertile) |>
  summarise(
    n         = n(),
    beta_lead = lm(hba1c ~ log_lead + age + sex + race_eth + educ + pir + bmi + smoke_status)$coefficients["log_lead"],
    .groups = "drop"
  )

message("  Stratified β (lead→HbA1c) by fiber tertile:")
print(strat_results)
write_csv(strat_results, file.path(dir_tables, "stratified_lead_hba1c_by_fiber.csv"))

# =============================================================================
# Save all model objects for use in visualizations
# =============================================================================
model_list <- list(
  m1_linear    = m1_svy,
  m2_linear    = m2_svy,
  m3_linear    = m3_svy,
  m4_interact  = m4_svy,
  m1_logistic  = lg1_svy,
  m2_logistic  = lg2_svy,
  m3_logistic  = lg3_svy,
  m_cadmium    = m_cad_svy,
  m_mercury    = m_hg_svy
)
saveRDS(model_list, file.path(dir_processed, "model_list.rds"))
message("\n  Model objects saved to data/processed/model_list.rds")

message("\n=== 05_regression_models.R: complete ===\n")
