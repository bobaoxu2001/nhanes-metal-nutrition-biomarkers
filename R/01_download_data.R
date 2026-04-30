# =============================================================================
# 01_download_data.R
# Project: Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers
# Purpose: Download raw NHANES data files for 2017-2018 and 2019-March 2020
#          Save as .rds files in data/raw/
# =============================================================================
# NOTE: This script uses the nhanesA package to query and download data from
#       the CDC NHANES public API. An active internet connection is required.
#       Files already downloaded are skipped to avoid redundant downloads.
# =============================================================================

source(here::here("R", "00_setup.R"))

message("=== 01_download_data.R: starting data download ===\n")

# -----------------------------------------------------------------------------
# Helper: download one NHANES table, cache as .rds
# -----------------------------------------------------------------------------
download_nhanes_table <- function(table_name, out_dir = dir_raw, force = FALSE) {
  out_path <- file.path(out_dir, paste0(table_name, ".rds"))

  if (file.exists(out_path) && !force) {
    message(glue("  [skip] {table_name} already exists at {out_path}"))
    return(invisible(readRDS(out_path)))
  }

  message(glue("  [download] {table_name} ..."))

  dat <- tryCatch({
    nhanesA::nhanes(table_name)
  }, error = function(e) {
    warning(glue("Failed to download {table_name}: {conditionMessage(e)}"))
    return(NULL)
  })

  if (!is.null(dat)) {
    saveRDS(dat, out_path)
    message(glue("    -> saved {nrow(dat)} rows x {ncol(dat)} cols"))
  }

  invisible(dat)
}

# -----------------------------------------------------------------------------
# Download all files
# -----------------------------------------------------------------------------
all_tables <- unlist(nhanes_files, use.names = FALSE)

message("Downloading ", length(all_tables), " NHANES tables...\n")

downloaded <- map(all_tables, download_nhanes_table)
names(downloaded) <- all_tables

# -----------------------------------------------------------------------------
# Verify downloads and report
# -----------------------------------------------------------------------------
message("\n--- Download summary ---")
status <- tibble(
  table     = all_tables,
  file      = file.path(dir_raw, paste0(all_tables, ".rds")),
  exists    = file.exists(file),
  size_kb   = ifelse(exists, round(file.size(file) / 1024, 1), NA_real_)
)

print(status)

n_ok   <- sum(status$exists)
n_fail <- sum(!status$exists)

message(glue("\n✓ {n_ok} tables downloaded successfully."))
if (n_fail > 0) {
  message(glue("✗ {n_fail} tables FAILED. Check warnings above."))
  message("  Failed tables: ",
          paste(status$table[!status$exists], collapse = ", "))
  message("\n  MANUAL DOWNLOAD FALLBACK:")
  message("  Visit https://wwwn.cdc.gov/nchs/nhanes/")
  message("  Navigate to each cycle and download the .XPT files.")
  message("  Place them in data/raw/ and use haven::read_xpt() to convert.")
}

# -----------------------------------------------------------------------------
# Create a codebook / variable inspection for key tables
# -----------------------------------------------------------------------------
message("\n--- Inspecting variable names for key tables ---")

inspect_tables <- c("PBCD_J", "GHB_J", "CRP_J", "DEMO_J",
                    "BPX_J", "BMX_J", "DR1TOT_J", "SMQ_J",
                    "BPXO_P", "PBCD_P")

codebook_list <- list()
for (tbl in inspect_tables) {
  path <- file.path(dir_raw, paste0(tbl, ".rds"))
  if (file.exists(path)) {
    dat <- readRDS(path)
    codebook_list[[tbl]] <- tibble(
      table    = tbl,
      variable = names(dat),
      class    = sapply(dat, class),
      n_obs    = nrow(dat),
      n_miss   = sapply(dat, function(x) sum(is.na(x))),
      example  = sapply(dat, function(x) as.character(x[min(5, length(x))]))
    )
  }
}

if (length(codebook_list) > 0) {
  codebook_df <- bind_rows(codebook_list)
  write_csv(codebook_df, file.path(dir_codebook, "variable_inspection.csv"))
  message(glue("  Codebook saved to data/codebook/variable_inspection.csv"))
}

# -----------------------------------------------------------------------------
# Verify critical variables exist
# -----------------------------------------------------------------------------
message("\n--- Verifying critical variables ---")

check_var <- function(table_name, var_name) {
  path <- file.path(dir_raw, paste0(table_name, ".rds"))
  if (!file.exists(path)) return(tibble(table = table_name, variable = var_name, found = FALSE))
  dat <- readRDS(path)
  tibble(table = table_name, variable = var_name, found = var_name %in% names(dat))
}

critical_checks <- bind_rows(
  check_var("DEMO_J",   "SEQN"),
  check_var("DEMO_J",   "RIDAGEYR"),
  check_var("DEMO_J",   "RIAGENDR"),
  check_var("DEMO_J",   "RIDRETH3"),
  check_var("DEMO_J",   "DMDEDUC2"),
  check_var("DEMO_J",   "INDFMPIR"),
  check_var("DEMO_J",   "SDMVPSU"),
  check_var("DEMO_J",   "SDMVSTRA"),
  check_var("DEMO_J",   "WTMEC2YR"),
  check_var("DEMO_P",   "WTMECPRP"),  # pre-pandemic weight
  check_var("PBCD_J",   "LBXBPB"),    # Blood lead
  check_var("PBCD_J",   "LBXBCD"),    # Blood cadmium
  check_var("PBCD_J",   "LBXTHG"),    # Blood total mercury
  check_var("GHB_J",    "LBXGH"),     # HbA1c
  check_var("CRP_J",    "LBXCRP"),    # CRP
  check_var("TCHOL_J",  "LBXTC"),     # Total cholesterol
  check_var("HDL_J",    "LBDHDD"),    # HDL
  check_var("BMX_J",    "BMXBMI"),    # BMI
  check_var("DR1TOT_J", "DR1TFIBE"),  # Dietary fiber
  check_var("DR1TOT_J", "DR1TVC"),    # Vitamin C
  check_var("DR1TOT_J", "DR1TKCAL")  # Energy
)

print(critical_checks)

n_found   <- sum(critical_checks$found)
n_missing <- sum(!critical_checks$found)
message(glue("\n✓ {n_found} critical variables found."))
if (n_missing > 0) {
  message(glue("✗ {n_missing} critical variables NOT found. Review and adapt 02_clean_merge_data.R."))
}

message("\n=== 01_download_data.R: complete ===\n")
