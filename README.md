# Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers
### A Reproducible NHANES Analysis

[![R](https://img.shields.io/badge/R-≥4.3-blue.svg)](https://cran.r-project.org/)
[![NHANES](https://img.shields.io/badge/Data-NHANES%202017--March%202020-green.svg)](https://wwwn.cdc.gov/nchs/nhanes/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Project Overview

This project investigates associations between **blood heavy metal concentrations** (lead, cadmium, mercury) and **glycemic biomarkers** (HbA1c) among U.S. adults, using publicly available data from the National Health and Nutrition Examination Survey (NHANES) 2017–March 2020. A secondary objective is to evaluate whether **dietary fiber intake** modifies or attenuates these associations.

The project is designed as a **portfolio-quality epidemiological analysis** demonstrating reproducible research practices, complex survey data handling, and rigorous statistical modeling suitable for academic or public health research settings.

---

## Why This Project Matters

Environmental metal exposures persist in the U.S. population despite decades of regulatory progress. Lead, cadmium, and mercury—even at low, subclinical levels—may disrupt insulin signaling, promote oxidative stress, and contribute to cardiometabolic disease. HbA1c is a stable, clinically important biomarker of average glycemia and a diagnostic criterion for prediabetes and diabetes.

Understanding whether dietary quality (specifically fiber intake) modifies these associations has direct public health relevance: it suggests that improving diet may partially buffer the cardiometabolic effects of environmental metal burdens—an actionable, modifiable factor.

---

## Research Question

> Are blood concentrations of lead, cadmium, and mercury associated with HbA1c among U.S. adults aged ≥20 years, and does dietary fiber intake modify or attenuate these associations?

**Primary exposure:** Blood lead (µg/dL)  
**Primary outcome:** HbA1c (%)  
**Effect modifier / confounder:** Dietary fiber (g/day)  
**Study design:** Cross-sectional analysis of NHANES 2017–March 2020

---

## Data Source

**National Health and Nutrition Examination Survey (NHANES)**  
Centers for Disease Control and Prevention (CDC), National Center for Health Statistics (NCHS)

- **Cycles:** 2017–2018 (`_J`) and 2019–March 2020 pre-pandemic (`_P`)
- **Public access:** [https://wwwn.cdc.gov/nchs/nhanes/](https://wwwn.cdc.gov/nchs/nhanes/)
- **Download method:** `nhanesA` R package (programmatic download from CDC API)
- **License:** Public domain (U.S. government data)

**NHANES files used:**

| Domain | Files | Variables |
|--------|-------|-----------|
| Demographics | DEMO_J, DEMO_P | Age, sex, race/ethnicity, education, PIR, survey design |
| Blood metals | PBCD_J, PBCD_P | Blood lead, cadmium, total mercury |
| HbA1c | GHB_J, GHB_P | Glycated hemoglobin |
| CRP | CRP_J, CRP_P | C-reactive protein |
| Cholesterol | TCHOL_J, TCHOL_P; HDL_J, HDL_P | Total and HDL cholesterol |
| Blood pressure | BPX_J, BPXO_P; BPQ_J, BPQ_P | BP readings and medication |
| Body measures | BMX_J, BMX_P | BMI |
| Dietary recall | DR1TOT_J, DR1TOT_P | Fiber, vitamin C, energy, calcium, iron |
| Smoking | SMQ_J, SMQ_P | Smoking status |

---

## Methods Summary

| Step | Approach |
|------|---------|
| Data download | `nhanesA` package; raw files cached as `.rds` |
| Merging | Left-join on `SEQN` across 11 NHANES files per cycle; row-bind two cycles |
| Exclusions | Age <20, missing MEC weight, missing all metals, missing HbA1c |
| Exposure transformation | Natural log (right-skewed metals); quartile categorization |
| Outcome | HbA1c (continuous); elevated HbA1c ≥5.7% (binary) |
| Survey weights | 4-year combined weights (original weight ÷ 2); `svydesign()` with strata + PSU |
| Linear regression | `svyglm(gaussian())`: 3 models + interaction |
| Logistic regression | `svyglm(quasibinomial())`: 3 models for binary outcome |
| Sensitivity | Cadmium and mercury substituted for lead in fully adjusted model |
| Visualization | `ggplot2` + `patchwork`; 7 publication-quality figures |
| Tables | `gtsummary` → HTML + Word-compatible `.docx` |
| Report | Quarto (`.qmd`) → self-contained HTML |

---

## Project Structure

```
nhanes-metal-nutrition-biomarkers/
├── README.md                                  ← This file
├── nhanes-metal-nutrition-biomarkers.Rproj    ← RStudio project
├── package_setup.R                            ← Install all packages
│
├── R/
│   ├── 00_setup.R                  ← Libraries, paths, helper functions
│   ├── 01_download_data.R          ← Download NHANES files via nhanesA
│   ├── 02_clean_merge_data.R       ← Merge, harmonize, apply exclusions
│   ├── 03_define_variables.R       ← Transformations, binary outcomes, labels
│   ├── 04_descriptive_analysis.R   ← Table 1, missingness, correlations
│   ├── 05_regression_models.R      ← Linear + logistic survey-weighted models
│   ├── 06_visualizations.R         ← 7 ggplot2 figures
│   └── 07_export_tables_figures.R  ← Export tables to HTML/DOCX
│
├── data/
│   ├── raw/          ← Downloaded NHANES .rds files (not committed to git)
│   ├── processed/    ← analysis_dataset_v2.rds, exclusion_log.rds, model_list.rds
│   └── codebook/     ← variable_inspection.csv, missingness_report.csv
│
├── outputs/
│   ├── tables/       ← Table 1–4 (.html, .docx), regression CSVs
│   ├── figures/      ← fig01–fig07 (.png, 300 dpi)
│   └── report/       ← output_inventory.csv
│
├── report/
│   └── nhanes_metal_nutrition_biomarkers.qmd  ← Main Quarto report
│
└── docs/
    ├── analytic_plan.md        ← Pre-analysis plan with hypotheses
    ├── variable_dictionary.md  ← All variables with NHANES names and coding
    └── methods_notes.md        ← Methodological decisions and rationale
```

---

## How to Reproduce This Analysis

### Prerequisites

- **R** (≥ 4.3): [https://cran.r-project.org/](https://cran.r-project.org/)
- **Quarto** (≥ 1.4): [https://quarto.org/docs/get-started/](https://quarto.org/docs/get-started/)
- **RStudio** (recommended): [https://posit.co/download/rstudio-desktop/](https://posit.co/download/rstudio-desktop/)
- Active internet connection (for NHANES data download)

### Step-by-Step

**1. Clone or download the repository**
```bash
git clone https://github.com/YOUR-USERNAME/nhanes-metal-nutrition-biomarkers.git
cd nhanes-metal-nutrition-biomarkers
```

**2. Open the R project**
Double-click `nhanes-metal-nutrition-biomarkers.Rproj` in RStudio, or:
```r
rstudioapi::openProject("nhanes-metal-nutrition-biomarkers.Rproj")
```

**3. Install required packages**
```r
source("package_setup.R")
```

**4. Run analysis scripts in order**
```r
source("R/00_setup.R")
source("R/01_download_data.R")      # ~10-30 min on first run; internet required
source("R/02_clean_merge_data.R")
source("R/03_define_variables.R")
source("R/04_descriptive_analysis.R")
source("R/05_regression_models.R")
source("R/06_visualizations.R")
source("R/07_export_tables_figures.R")
```

Or from the terminal:
```bash
Rscript R/00_setup.R
Rscript R/01_download_data.R
Rscript R/02_clean_merge_data.R
Rscript R/03_define_variables.R
Rscript R/04_descriptive_analysis.R
Rscript R/05_regression_models.R
Rscript R/06_visualizations.R
Rscript R/07_export_tables_figures.R
```

**5. Render the report**
```r
quarto::quarto_render("report/nhanes_metal_nutrition_biomarkers.qmd")
```
Or from the terminal:
```bash
quarto render report/nhanes_metal_nutrition_biomarkers.qmd
```

The rendered HTML report will appear at `report/nhanes_metal_nutrition_biomarkers.html`.

### If Downloads Fail

If `nhanesA` cannot download files, you can download them manually:
1. Visit [https://wwwn.cdc.gov/nchs/nhanes/](https://wwwn.cdc.gov/nchs/nhanes/)
2. Select the cycle → Lab/Examination/Questionnaire/Dietary data
3. Download the `.XPT` file
4. Convert and save in R:
```r
dat <- haven::read_xpt("PBCD_J.XPT")
saveRDS(dat, "data/raw/PBCD_J.rds")
```

---

## Main Outputs

| Output | Location | Description |
|--------|----------|-------------|
| Table 1: Overall characteristics | `outputs/tables/table1_overall.html/.docx` | Demographics, exposures, outcomes |
| Table 1b: By lead quartile | `outputs/tables/table1_by_lead_quartile.html/.docx` | Stratified characteristics |
| Table 2: Linear regression | `outputs/tables/table2_linear_regression.html/.docx` | β (95% CI) for lead→HbA1c |
| Table 3: Logistic regression | `outputs/tables/table3_logistic_regression.html/.docx` | OR (95% CI) for lead→elevated HbA1c |
| Table 4: Multi-metal sensitivity | `outputs/tables/table4_sensitivity_metals.html/.docx` | All metals → HbA1c |
| Figure 1: Exposure distributions | `outputs/figures/fig01_exposure_distributions.png` | Metal histograms |
| Figure 2: Outcome distributions | `outputs/figures/fig02_outcome_distributions.png` | HbA1c histogram |
| Figure 3: Scatter plot | `outputs/figures/fig03_exposure_outcome_scatter.png` | Lead vs. HbA1c |
| Figure 4: Forest plot | `outputs/figures/fig04_forest_plot.png` | Model comparison |
| Figure 5: By quartile | `outputs/figures/fig05_hba1c_by_lead_quartile.png` | Mean HbA1c by lead Q |
| Figure 6: Interaction plot | `outputs/figures/fig06_interaction_plot.png` | Lead × fiber |
| Figure 7: Multi-metal forest | `outputs/figures/fig07_metals_forest.png` | Sensitivity |
| Full report | `report/nhanes_metal_nutrition_biomarkers.html` | Self-contained HTML |

---

## Skills Demonstrated

| Skill | Where |
|-------|-------|
| Real public health data acquisition | `R/01_download_data.R` |
| Complex survey data handling | `R/05_regression_models.R`, `svydesign()` |
| Multi-file data merging and harmonization | `R/02_clean_merge_data.R` |
| Variable engineering and transformation | `R/03_define_variables.R` |
| Publication-quality Table 1 | `R/04_descriptive_analysis.R`, `gtsummary` |
| Linear and logistic regression | `R/05_regression_models.R` |
| Effect modification / interaction analysis | Models 4, `R/05_regression_models.R` |
| ggplot2 visualization (7 figures) | `R/06_visualizations.R` |
| Reproducible Quarto report | `report/nhanes_metal_nutrition_biomarkers.qmd` |
| Pre-analysis plan | `docs/analytic_plan.md` |
| Professional documentation | `docs/variable_dictionary.md`, `docs/methods_notes.md` |
| Portable project structure (`here`) | All scripts |
| Epidemiological interpretation | Report sections: Background, Results, Limitations |

---

## Future Extensions

1. **Mixture analysis** using Weighted Quantile Sum (WQS) regression or Bayesian Kernel Machine Regression (BKMR) to model joint metal mixture effects
2. **Mediation analysis** examining whether BMI mediates the metal-HbA1c pathway
3. **Race/ethnicity stratification** to address health disparities in metal bioaccumulation
4. **Additional outcomes** including CRP (inflammation), eGFR (kidney function), and blood pressure
5. **Multiple imputation** to handle missing dietary data more rigorously
6. **Dietary pattern analysis** using Healthy Eating Index (HEI-2015) as a comprehensive nutrition confounder

---

## Author

**Ao Xu**  
MPH / Data Analyst  
Email: ax2183@nyu.edu

---

## License

This project is released under the MIT License. NHANES data are in the public domain (U.S. government work, no copyright).

---

## Citation

If you use or adapt this analysis:

> Xu A. (2025). *Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers: A Reproducible NHANES Analysis*. GitHub. https://github.com/YOUR-USERNAME/nhanes-metal-nutrition-biomarkers

**Data citation:**
> National Center for Health Statistics. National Health and Nutrition Examination Survey Data, 2017–2018 and 2019–March 2020 Pre-Pandemic. Hyattsville, MD: U.S. Department of Health and Human Services, Centers for Disease Control and Prevention. https://wwwn.cdc.gov/nchs/nhanes/.
