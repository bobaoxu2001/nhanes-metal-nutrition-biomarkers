# =============================================================================
# 07_export_tables_figures.R
# Project: Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers
# Purpose: Export polished tables and figures in report-ready formats
#          - gtsummary tables → HTML + Word-ready flextable
#          - Regression tables with publication formatting
#          - Figures compiled with consistent resolution
# =============================================================================

source(here::here("R", "00_setup.R"))
library(gtsummary)
library(gt)
library(flextable)
library(broom)

message("=== 07_export_tables_figures.R: exporting outputs ===\n")

# --- Load data ---------------------------------------------------------------
dat_path <- file.path(dir_processed, "analysis_dataset_v2.rds")
if (!file.exists(dat_path)) stop("Run 03_define_variables.R first.")
dat <- readRDS(dat_path)

# =============================================================================
# TABLE 1 — Load saved gtsummary objects and export
# =============================================================================
message("--- Exporting Table 1 ---")

save_tbl_docx <- function(tbl, path) {
  tbl |> as_flex_table() |>
    set_table_properties(layout = "autofit") |>
    fontsize(size = 9, part = "all") |>
    save_as_docx(path = path)
}

tbl1_path <- file.path(dir_tables, "table1_overall.rds")
if (file.exists(tbl1_path)) {
  tbl1 <- readRDS(tbl1_path)
  save_tbl_docx(tbl1, file.path(dir_tables, "table1_overall.docx"))
  message("  Table 1 → DOCX")
}

tbl1_lead_path <- file.path(dir_tables, "table1_by_lead_quartile.rds")
if (file.exists(tbl1_lead_path)) {
  tbl1_lead <- readRDS(tbl1_lead_path)
  save_tbl_docx(tbl1_lead, file.path(dir_tables, "table1_by_lead_quartile.docx"))
  message("  Table 1 by quartile → DOCX")
}

# =============================================================================
# TABLE 2 — Regression summary: linear models (β, 95% CI, p-value)
# =============================================================================
message("--- Creating Table 2 (regression results) ---")

linear_results <- read_csv(file.path(dir_tables, "linear_models_lead_hba1c.csv"),
                           show_col_types = FALSE)

# Format for publication: only log_lead row, all models
tbl2_data <- linear_results |>
  filter(term == "log_lead") |>
  mutate(
    `β (95% CI)` = glue("{round(estimate,3)} ({round(conf.low,3)}, {round(conf.high,3)})"),
    `p-value`    = case_when(
      p.value < 0.001 ~ "<0.001",
      p.value < 0.01  ~ "<0.01",
      TRUE            ~ as.character(round(p.value, 3))
    )
  ) |>
  select(Model = model, `β (95% CI)`, `p-value`)

# Add footnote row for model definitions
tbl2_ft <- flextable(tbl2_data) |>
  set_header_labels(Model = "Model") |>
  add_footer_lines(
    paste0("β = change in HbA1c (%) per 1-unit increase in ln(blood lead µg/dL). ",
           "95% CI = 95% confidence interval. All models survey-weighted.\n",
           "Model 1: Unadjusted. ",
           "Model 2: Adjusted for age, sex, race/ethnicity. ",
           "Model 3: + education, poverty-income ratio, BMI, smoking status, dietary fiber. ",
           "Model 4: Model 3 + blood lead × dietary fiber interaction.")
  ) |>
  fontsize(size = 10, part = "body") |>
  fontsize(size = 8, part = "footer") |>
  bold(part = "header") |>
  set_table_properties(layout = "autofit") |>
  autofit()

save_as_docx(tbl2_ft, path = file.path(dir_tables, "table2_linear_regression.docx"))
message("  Table 2 → DOCX")

# =============================================================================
# TABLE 3 — Logistic regression: OR (95% CI) for elevated HbA1c
# =============================================================================
message("--- Creating Table 3 (logistic regression results) ---")

logit_results <- read_csv(file.path(dir_tables, "logistic_models_lead_hba1c_elevated.csv"),
                          show_col_types = FALSE)

tbl3_data <- logit_results |>
  filter(term == "log_lead") |>
  mutate(
    `OR (95% CI)` = glue("{round(estimate,3)} ({round(conf.low,3)}, {round(conf.high,3)})"),
    `p-value`    = case_when(
      p.value < 0.001 ~ "<0.001",
      p.value < 0.01  ~ "<0.01",
      TRUE            ~ as.character(round(p.value, 3))
    )
  ) |>
  select(Model = model, `OR (95% CI)`, `p-value`)

tbl3_ft <- flextable(tbl3_data) |>
  add_footer_lines(
    paste0("OR = odds ratio per 1-unit increase in ln(blood lead µg/dL). ",
           "95% CI = 95% confidence interval. Survey-weighted quasi-binomial model.\n",
           "Outcome: elevated HbA1c (≥5.7%). ",
           "Models adjusted as in Table 2.")
  ) |>
  fontsize(size = 10, part = "body") |>
  fontsize(size = 8, part = "footer") |>
  bold(part = "header") |>
  set_table_properties(layout = "autofit") |>
  autofit()

save_as_docx(tbl3_ft, path = file.path(dir_tables, "table3_logistic_regression.docx"))
message("  Table 3 → DOCX")

# =============================================================================
# TABLE 4 — Sensitivity: all metals → HbA1c (fully adjusted)
# =============================================================================
message("--- Creating Table 4 (sensitivity analysis) ---")

sens_results <- read_csv(file.path(dir_tables, "sensitivity_all_metals_hba1c.csv"),
                         show_col_types = FALSE)

tbl4_data <- sens_results |>
  mutate(
    `β (95% CI)` = glue("{round(estimate,3)} ({round(conf.low,3)}, {round(conf.high,3)})"),
    `p-value`    = case_when(
      p.value < 0.001 ~ "<0.001",
      p.value < 0.01  ~ "<0.01",
      TRUE            ~ as.character(round(p.value, 3))
    )
  ) |>
  select(Exposure = exposure, `β (95% CI)`, `p-value`)

tbl4_ft <- flextable(tbl4_data) |>
  add_footer_lines(
    paste0("β = change in HbA1c (%) per 1-unit increase in ln(metal concentration). ",
           "All models adjusted for age, sex, race/ethnicity, education, PIR, BMI, ",
           "smoking status, and dietary fiber. Survey-weighted.")
  ) |>
  fontsize(size = 10, part = "body") |>
  fontsize(size = 8, part = "footer") |>
  bold(part = "header") |>
  set_table_properties(layout = "autofit") |>
  autofit()

save_as_docx(tbl4_ft, path = file.path(dir_tables, "table4_sensitivity_metals.docx"))
message("  Table 4 → DOCX")

# =============================================================================
# Summary of all outputs
# =============================================================================
message("\n--- Output inventory ---")
all_outputs <- tibble(
  file      = c(
    list.files(dir_tables,  full.names = TRUE),
    list.files(dir_figures, full.names = TRUE)
  )
) |>
  mutate(
    filename = basename(file),
    size_kb  = round(file.size(file) / 1024, 1),
    type     = if_else(str_detect(filename, "\\.png$"), "Figure", "Table")
  ) |>
  filter(size_kb > 0) |>
  arrange(type, filename) |>
  select(type, filename, size_kb)

print(all_outputs)
write_csv(all_outputs, file.path(dir_report, "output_inventory.csv"))

message(glue("\n  Total outputs: {nrow(all_outputs)} files"))
message("\n=== 07_export_tables_figures.R: complete ===\n")
message("=== All analysis scripts complete. Run report/nhanes_metal_nutrition_biomarkers.qmd to render the report. ===\n")
