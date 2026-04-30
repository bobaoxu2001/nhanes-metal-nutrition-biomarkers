# =============================================================================
# 01_download_data.R
# Project: Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers
# Purpose: Download raw NHANES 2017-2018 data files from the CDC public server.
#          Save as .rds files in data/raw/.
#
# NOTE ON CYCLE SELECTION:
#   We use NHANES 2017-2018 (cycle J) only.
#   The 2019-March 2020 pre-pandemic files (_P suffix) are not hosted at the
#   standard CDC data URL pattern. This is documented in docs/methods_notes.md.
#   A single-cycle analysis with WTMEC2YR weights is standard and valid.
#
# NOTE ON DOWNLOAD METHOD:
#   nhanesA 0.7.2 constructs malformed URLs for cycle-J files (known bug).
#   We bypass it and download directly from the CDC via haven::read_xpt().
#   Correct base: https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/
#
# NOTE ON CRP:
#   The 2017-2018 CRP file is "High-Sensitivity CRP" = HSCRP_J (not CRP_J).
#   CRP_J does not exist for this cycle. Variable: LBXHSCRP (mg/L).
# =============================================================================

source(here::here("R", "00_setup.R"))
library(haven)

message("=== 01_download_data.R: starting data download ===\n")

CDC_BASE <- "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/"

nhanes_files_j <- c(
  DEMO   = "DEMO_J",    # Demographics + survey weights
  PBCD   = "PBCD_J",   # Blood Cd, Pb, Hg, Se, Mn
  HSCRP  = "HSCRP_J",  # High-Sensitivity C-Reactive Protein
  GHB    = "GHB_J",    # Glycohemoglobin (HbA1c)
  TCHOL  = "TCHOL_J",  # Total Cholesterol
  HDL    = "HDL_J",    # HDL Cholesterol
  BPX    = "BPX_J",    # Blood Pressure
  BPQ    = "BPQ_J",    # Blood Pressure Questionnaire
  BMX    = "BMX_J",    # Body Measures
  DR1TOT = "DR1TOT_J", # 24-hr Dietary Recall Day 1
  SMQ    = "SMQ_J"     # Smoking
)

# -----------------------------------------------------------------------------
# Helper: download one NHANES XPT -> save as .rds
# -----------------------------------------------------------------------------
download_nhanes_xpt <- function(file_name, base_url = CDC_BASE,
                                out_dir = dir_raw, force = FALSE) {
  out_path <- file.path(out_dir, paste0(file_name, ".rds"))

  if (file.exists(out_path) && !force) {
    sz <- round(file.size(out_path) / 1024, 1)
    message(glue("  [skip] {file_name}.rds ({sz} KB)"))
    return(invisible(readRDS(out_path)))
  }

  url <- paste0(base_url, file_name, ".XPT")
  message(glue("  [download] {file_name} ..."))

  tf <- tempfile(fileext = ".XPT")

  # curl is more reliable than R's download.file for large files
  ret <- tryCatch(
    system2("curl", args = c("-sS", "-L", "--max-time", "180",
                              "--retry", "3", "--retry-delay", "5",
                              "-o", shQuote(tf), shQuote(url)),
            stdout = FALSE, stderr = FALSE),
    error = function(e) 1L
  )

  # Fallback to R download.file if curl fails or is not available
  if (ret != 0 || !file.exists(tf) || file.size(tf) < 500) {
    tryCatch(
      download.file(url, tf, mode = "wb", quiet = TRUE),
      error = function(e) warning(glue("download.file failed for {file_name}: {e$message}"))
    )
  }

  if (!file.exists(tf) || file.size(tf) < 500) {
    warning(glue("FAILED: {file_name} — file missing or too small"))
    return(NULL)
  }

  # Detect HTML error page
  con   <- file(tf, "rb")
  first <- readBin(con, "raw", 15)
  close(con)
  if (length(first) > 5 && rawToChar(first[1:5]) == "<!DOC") {
    warning(glue("FAILED: {file_name} — CDC returned HTML (404 or redirect)"))
    return(NULL)
  }

  dat <- tryCatch(
    haven::read_xpt(tf),
    error = function(e) {
      warning(glue("read_xpt failed for {file_name}: {e$message}"))
      NULL
    }
  )

  if (!is.null(dat) && nrow(dat) > 0) {
    saveRDS(dat, out_path)
    message(glue("    -> {nrow(dat)} rows x {ncol(dat)} cols"))
  }
  invisible(dat)
}

# -----------------------------------------------------------------------------
# Run downloads
# -----------------------------------------------------------------------------
message(glue("Downloading {length(nhanes_files_j)} NHANES 2017-2018 files...\n"))
downloaded <- imap(nhanes_files_j, ~ download_nhanes_xpt(.x))

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
message("\n--- Download summary ---")
status_df <- tibble(
  domain  = names(nhanes_files_j),
  file    = nhanes_files_j,
  rds     = file.path(dir_raw, paste0(nhanes_files_j, ".rds")),
  exists  = file.exists(rds),
  size_kb = ifelse(exists, round(file.size(rds) / 1024, 1), NA_real_)
)
print(status_df)

n_ok   <- sum(status_df$exists)
n_fail <- sum(!status_df$exists)
message(glue("\n{n_ok}/{length(nhanes_files_j)} tables downloaded."))

if (n_fail > 0) {
  failed_names <- status_df$file[!status_df$exists]
  message("FAILED: ", paste(failed_names, collapse = ", "))
  message("\nMANUAL FALLBACK:")
  message("  https://wwwn.cdc.gov/nchs/nhanes/search/datapage.aspx?Component=Laboratory&Cycle=2017-2018")
  message("  Download XPT, then: saveRDS(haven::read_xpt('X.XPT'), 'data/raw/X.rds')")
  stop("Required NHANES files missing. Cannot proceed.")
}

# -----------------------------------------------------------------------------
# Codebook
# -----------------------------------------------------------------------------
codebook_list <- imap(nhanes_files_j, function(fname, domain) {
  dat <- downloaded[[domain]]
  if (is.null(dat)) return(NULL)
  tibble(
    domain   = domain,
    table    = fname,
    variable = names(dat),
    class    = sapply(dat, function(x) class(x)[1]),
    n_obs    = nrow(dat),
    n_miss   = sapply(dat, function(x) sum(is.na(x))),
    example  = sapply(dat, function(x) as.character(x[min(5, length(x))])[1])
  )
})
codebook_df <- bind_rows(compact(codebook_list))
write_csv(codebook_df, file.path(dir_codebook, "variable_inspection.csv"))
message(glue("\nCodebook saved: {nrow(codebook_df)} variables"))

# -----------------------------------------------------------------------------
# Critical variable check  (haven uses UPPERCASE names, so check as-is)
# -----------------------------------------------------------------------------
message("\n--- Critical variable check ---")
check_var <- function(table_name, var_name) {
  path <- file.path(dir_raw, paste0(table_name, ".rds"))
  if (!file.exists(path)) return(tibble(table=table_name, variable=var_name, found=FALSE))
  nms <- names(readRDS(path))
  found <- var_name %in% nms
  tibble(table=table_name, variable=var_name, found=found)
}

checks <- bind_rows(
  check_var("DEMO_J",   "SEQN"),     check_var("DEMO_J",   "RIDAGEYR"),
  check_var("DEMO_J",   "RIAGENDR"), check_var("DEMO_J",   "RIDRETH3"),
  check_var("DEMO_J",   "DMDEDUC2"), check_var("DEMO_J",   "INDFMPIR"),
  check_var("DEMO_J",   "SDMVPSU"),  check_var("DEMO_J",   "SDMVSTRA"),
  check_var("DEMO_J",   "WTMEC2YR"),
  check_var("PBCD_J",   "LBXBPB"),   check_var("PBCD_J",   "LBXBCD"),
  check_var("PBCD_J",   "LBXTHG"),
  check_var("GHB_J",    "LBXGH"),
  check_var("HSCRP_J",  "LBXHSCRP"),
  check_var("TCHOL_J",  "LBXTC"),    check_var("HDL_J",    "LBDHDD"),
  check_var("BMX_J",    "BMXBMI"),
  check_var("DR1TOT_J", "DR1TFIBE"), check_var("DR1TOT_J", "DR1TVC"),
  check_var("DR1TOT_J", "DR1TKCAL")
)

print(checks)
n_found   <- sum(checks$found)
n_missing <- sum(!checks$found)
message(glue("{n_found} critical variables found, {n_missing} not found."))
if (n_missing > 0) {
  message("Not found:")
  print(checks[!checks$found, ])
}

message("\n=== 01_download_data.R: complete ===\n")
