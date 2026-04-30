# =============================================================================
# run_all.R
# Project: Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers
# Purpose: One-command end-to-end reproduction of the full pipeline.
#
# Usage (from project root):
#     Rscript run_all.R
#
# Steps:
#   1. Source R/00_setup.R through R/07_export_tables_figures.R in order
#   2. Render the Quarto report (HTML + PDF) if Quarto is installed
#
# Behavior:
#   - Each step prints a banner with elapsed time.
#   - If any script fails, execution stops with an informative error.
# =============================================================================

scripts <- c(
  "R/00_setup.R",
  "R/01_download_data.R",
  "R/02_clean_merge_data.R",
  "R/03_define_variables.R",
  "R/04_descriptive_analysis.R",
  "R/05_regression_models.R",
  "R/06_visualizations.R",
  "R/07_export_tables_figures.R"
)

run_step <- function(path) {
  if (!file.exists(path)) {
    stop("Missing script: ", path, call. = FALSE)
  }
  banner <- paste0("\n", strrep("=", 70), "\n",
                   ">>> ", path, "\n",
                   strrep("=", 70), "\n")
  cat(banner)
  t0 <- Sys.time()
  tryCatch(
    source(path, echo = FALSE),
    error = function(e) {
      stop(sprintf("Pipeline failed at %s: %s", path, conditionMessage(e)),
           call. = FALSE)
    }
  )
  elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)
  cat(sprintf("    [done in %s sec]\n", elapsed))
}

start_time <- Sys.time()
cat("\n>>> Starting end-to-end pipeline\n")
cat(">>> Working directory:", getwd(), "\n")

invisible(lapply(scripts, run_step))

# --- Render Quarto report ----------------------------------------------------
qmd <- "report/nhanes_metal_nutrition_biomarkers.qmd"
if (file.exists(qmd) && nzchar(Sys.which("quarto"))) {
  cat("\n", strrep("=", 70), "\n", sep = "")
  cat(">>> Rendering Quarto report\n")
  cat(strrep("=", 70), "\n", sep = "")
  status <- system2("quarto", args = c("render", qmd))
  if (!identical(as.integer(status), 0L)) {
    stop("Quarto render failed (exit code ", status, ").", call. = FALSE)
  }
  cat("    [report rendered]\n")
} else {
  cat("\n[skip] Quarto not found on PATH or report file missing; skipping render.\n")
  cat("       Install Quarto from https://quarto.org/, then run:\n")
  cat("           quarto render", qmd, "\n")
}

total <- round(as.numeric(difftime(Sys.time(), start_time, units = "mins")), 1)
cat("\n", strrep("=", 70), "\n", sep = "")
cat(sprintf(">>> Pipeline complete in %s min\n", total))
cat(strrep("=", 70), "\n", sep = "")
