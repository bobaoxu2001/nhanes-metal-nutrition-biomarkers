# =============================================================================
# 04_descriptive_analysis.R
# Project: Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers
# Purpose: Descriptive statistics and Table 1
#          - Overall sample characteristics
#          - By blood lead quartile
#          - Missingness table
#          - Exposure and outcome distributions
# =============================================================================

source(here::here("R", "00_setup.R"))
library(gtsummary)
library(gt)

# Helper: save gtsummary as Word doc (avoids xfun version conflict with gtsave)
save_gtsummary_docx <- function(tbl, path) {
  tbl |>
    as_flex_table() |>
    set_table_properties(layout = "autofit") |>
    fontsize(size = 9, part = "all") |>
    save_as_docx(path = path)
}

message("=== 04_descriptive_analysis.R: descriptive analysis ===\n")

# --- Load data ---------------------------------------------------------------
dat_path <- file.path(dir_processed, "analysis_dataset_v2.rds")
if (!file.exists(dat_path)) stop("Run 03_define_variables.R first.")
dat <- readRDS(dat_path)
message(glue("  Loaded: {nrow(dat)} participants"))

# =============================================================================
# 1. Define survey design object
# =============================================================================
# Single-cycle 2017-2018 design: WTMEC2YR used directly (no pooling adjustment).
svy_design <- svydesign(
  ids     = ~psu,
  strata  = ~strata,
  weights = ~wt_mec,
  data    = dat,
  nest    = TRUE
)

message(glue("  Survey design: {length(unique(dat$strata))} strata, ",
             "{length(unique(dat$psu))} PSUs (before nesting)"))

# =============================================================================
# 2. Table 1: Sample characteristics overall
# =============================================================================
message("--- Creating Table 1 ---")

table1_vars <- c(
  "age", "sex", "race_eth", "educ", "pir_cat", "smoke_status",
  "bmi", "bmi_cat",
  "blood_lead", "blood_cad", "blood_hg",
  "hba1c", "hba1c_elevated",
  "crp", "total_chol", "hdl_chol",
  "sbp", "dbp", "hypertension",
  "fiber_g", "vitc_mg", "energy_kcal"
)

# Check which vars are in data
table1_vars <- intersect(table1_vars, names(dat))

# gtsummary Table 1 (unweighted for display; survey-weighted follows)
tbl1_unweighted <- dat |>
  select(all_of(table1_vars)) |>
  tbl_summary(
    statistic = list(
      all_continuous()  ~ "{mean} ({sd})",
      all_categorical() ~ "{n} ({p}%)"
    ),
    digits    = all_continuous() ~ 1,
    missing   = "ifany",
    missing_text = "Missing"
  ) |>
  add_n() |>
  modify_header(label ~ "**Characteristic**") |>
  modify_caption("**Table 1. Sample Characteristics (N = {N})**") |>
  bold_labels()

saveRDS(tbl1_unweighted, file.path(dir_tables, "table1_overall.rds"))
save_gtsummary_docx(tbl1_unweighted, file.path(dir_tables, "table1_overall.docx"))
message("  Table 1 (unweighted) saved.")

# =============================================================================
# 3. Table 1 by blood lead quartile
# =============================================================================
message("--- Creating Table 1 by lead quartile ---")

# Only participants with valid lead measurement
dat_lead <- dat |> filter(!is.na(q_lead))

tbl1_bylead <- dat_lead |>
  select(all_of(table1_vars), q_lead) |>
  tbl_summary(
    by       = q_lead,
    statistic = list(
      all_continuous()  ~ "{mean} ({sd})",
      all_categorical() ~ "{n} ({p}%)"
    ),
    digits    = all_continuous() ~ 1,
    missing   = "no"
  ) |>
  add_overall() |>
  add_p(test = list(
    all_continuous()  ~ "aov",
    all_categorical() ~ "chisq.test"
  )) |>
  modify_header(label ~ "**Characteristic**") |>
  modify_caption("**Table 1 by Blood Lead Quartile**") |>
  bold_labels() |>
  modify_spanning_header(starts_with("stat_") ~ "**Blood Lead Quartile**")

saveRDS(tbl1_bylead, file.path(dir_tables, "table1_by_lead_quartile.rds"))
save_gtsummary_docx(tbl1_bylead, file.path(dir_tables, "table1_by_lead_quartile.docx"))
message("  Table 1 by lead quartile saved.")

# =============================================================================
# 4. Missingness summary table
# =============================================================================
message("--- Creating missingness table ---")

miss_tbl <- dat |>
  summarise(across(all_of(table1_vars),
                   ~ sum(is.na(.)))) |>
  pivot_longer(everything(), names_to = "variable", values_to = "n_missing") |>
  mutate(
    n_total   = nrow(dat),
    pct_miss  = round(n_missing / n_total * 100, 1),
    n_complete = n_total - n_missing
  ) |>
  arrange(desc(pct_miss)) |>
  select(variable, n_total, n_complete, n_missing, pct_miss)

write_csv(miss_tbl, file.path(dir_tables, "missingness_table.csv"))
message("  Missingness table saved.")

# =============================================================================
# 5. Exposure distribution summary
# =============================================================================
message("--- Exposure summary statistics ---")

expo_summary <- dat |>
  summarise(across(c(blood_lead, blood_cad, blood_hg,
                     log_lead, log_cad, log_hg),
                   list(
                     N    = ~ sum(!is.na(.)),
                     Mean = ~ round(mean(., na.rm = TRUE), 3),
                     SD   = ~ round(sd(., na.rm = TRUE), 3),
                     Min  = ~ round(min(., na.rm = TRUE), 3),
                     P25  = ~ round(quantile(., .25, na.rm = TRUE), 3),
                     Med  = ~ round(median(., na.rm = TRUE), 3),
                     P75  = ~ round(quantile(., .75, na.rm = TRUE), 3),
                     Max  = ~ round(max(., na.rm = TRUE), 3)
                   ),
                   .names = "{.col}__{.fn}")) |>
  pivot_longer(everything(),
               names_to  = c("variable", "statistic"),
               names_sep = "__") |>
  pivot_wider(names_from = statistic, values_from = value)

write_csv(expo_summary, file.path(dir_tables, "exposure_summary.csv"))
message("  Exposure summary saved.")

# =============================================================================
# 6. Outcome summary
# =============================================================================
outcome_summary <- dat |>
  summarise(across(c(hba1c, crp, total_chol, hdl_chol, sbp, dbp),
                   list(
                     N    = ~ sum(!is.na(.)),
                     Mean = ~ round(mean(., na.rm = TRUE), 2),
                     SD   = ~ round(sd(., na.rm = TRUE), 2),
                     Med  = ~ round(median(., na.rm = TRUE), 2),
                     IQR  = ~ round(IQR(., na.rm = TRUE), 2)
                   ),
                   .names = "{.col}__{.fn}")) |>
  pivot_longer(everything(),
               names_to  = c("variable", "statistic"),
               names_sep = "__") |>
  pivot_wider(names_from = statistic, values_from = value)

write_csv(outcome_summary, file.path(dir_tables, "outcome_summary.csv"))
message("  Outcome summary saved.")

# =============================================================================
# 7. Correlation matrix: metals and outcomes
# =============================================================================
message("--- Computing correlation matrix ---")

cor_vars <- dat |>
  select(log_lead, log_cad, log_hg, hba1c, crp, total_chol, hdl_chol) |>
  drop_na()

cor_mat <- cor(cor_vars, method = "spearman", use = "complete.obs")
cor_df  <- as.data.frame(cor_mat)
cor_df$variable <- rownames(cor_df)
write_csv(cor_df, file.path(dir_tables, "spearman_correlation_matrix.csv"))
message("  Spearman correlation matrix saved.")

message("\n=== 04_descriptive_analysis.R: complete ===\n")
