# Methods Notes

**Project:** Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers  
**Author:** Ao Xu  
**Purpose:** Document methodological decisions, rationale, and limitations

---

## 1. Why NHANES Is Appropriate for This Research Question

**National Health and Nutrition Examination Survey (NHANES)** is uniquely suited to this analysis for several reasons:

1. **Representative sample:** NHANES uses a stratified, multistage probability cluster sampling design that is nationally representative of the U.S. civilian non-institutionalized population. This enables population-level inference, unlike convenience or clinic samples.

2. **Co-measurement of exposures, outcomes, and covariates:** NHANES simultaneously collects blood metal concentrations, HbA1c, dietary recall data, and a comprehensive set of demographic and behavioral covariates in the same survey wave — eliminating the recall and selection biases that arise when linking separate data sources.

3. **Standardized laboratory protocols:** All NHANES laboratories follow rigorous quality control procedures, with periodic blind duplicate samples and certified reference standards. ICP-MS blood metal assays are validated and comparable across cycles.

4. **Public availability:** All NHANES data are freely available at https://wwwn.cdc.gov/nchs/nhanes/ without data use restrictions, enabling transparent and reproducible science.

5. **Pre-pandemic 2017–2018 cycle:** This analysis uses the 2017–2018 cycle (`_J` files), the most recent fully-released NHANES cycle that pre-dates COVID-19. Restricting to 2017–2018 avoids the confounding effects of pandemic-era disruptions in health behavior, exposure patterns, and healthcare access.

**Limitations of NHANES for this question:**
- Cross-sectional: cannot establish temporality
- No longitudinal follow-up: outcome events cannot be observed
- Not designed for rare exposures or disease-specific subpopulations

---

## 2. Why Metal Exposures Are Log-Transformed

Blood metal concentrations (lead, cadmium, mercury) are characteristically **right-skewed** in population-based studies, with a long right tail driven by highly exposed individuals (e.g., occupational exposures, dietary patterns).

**Problems with analyzing untransformed values:**
- Regression residuals are non-normally distributed, violating OLS assumptions
- The association between metals and outcomes is often non-linear on the original scale
- A few extreme values may dominate regression estimates

**Benefits of log (natural log) transformation:**
1. **Normalization:** The log-transformed distribution approximates normality, satisfying regression assumptions.
2. **Interpretability:** A 1-unit increase on the log scale corresponds to a multiplicative effect (e.g., doubling of exposure). A coefficient β can be interpreted as: "a 2.7-fold increase in blood lead concentration is associated with a β-unit change in HbA1c."
3. **Comparability:** Log-transformed metals are the analytic standard in environmental epidemiology, enabling comparison of results across studies.
4. **Handling of non-detects:** NHANES pre-applies the LOD/√2 substitution for values below detection limits, which are positive and can be log-transformed directly.

**Sensitivity check:** The number of values ≤0 (which cannot be log-transformed) is tabulated in `01_download_data.R` and is typically <0.01% of observations.

---

## 3. How Missing Data Are Handled

**Approach: Complete-case analysis**

For each regression model, only participants with complete data on all variables in that model are included. The N for each model is reported.

**Rationale:**
- Complete-case analysis is valid under the missing completely at random (MCAR) or missing at random (MAR) assumptions.
- NHANES missing data typically arise from MEC non-participation (not examined), lab processing issues (random), or dietary recall refusals — mechanisms more consistent with MAR than missing not at random (MNAR).

**What is reported:**
- Table of missingness proportion for each variable (see `04_descriptive_analysis.R`)
- Model-specific N in each regression table
- Participants excluded at each step in the exclusion log

**Future extension:** Multiple imputation using `mice` or `Amelia`, which can be incorporated into the survey design framework with `mitools::imputationList()`.

**Known high-missingness variables:**
- Dietary recall data (DR1TOT): participants who were not interviewed, were pregnant at interview, or had unreliable recall excluded by NHANES; typically ~10–20% missing.
- Education (`DMDEDUC2`): some missingness in older adults.
- Smoking status: some item non-response.

---

## 4. How Survey Weights Are Handled

NHANES sampling is designed so that no individual represents only themselves — each respondent has a sampling weight reflecting the probability of selection and post-stratification adjustments for nonresponse.

**Ignoring weights** would produce estimates biased toward oversampled subgroups (e.g., low-income, racial/ethnic minorities, elderly) and would not be nationally representative.

**Our approach:**

### 2-year weights (single cycle)
This analysis uses a single NHANES cycle (2017–2018), so the 2-year MEC examination weight `WTMEC2YR` is used directly without pooling adjustment, per NCHS analytic guidelines.

### Survey design object (R)
```r
svydesign(
  ids     = ~psu,        # primary sampling unit (SDMVPSU)
  strata  = ~strata,     # masked stratum (SDMVSTRA)
  weights = ~wt_mec,     # WTMEC2YR
  data    = dat,
  nest    = TRUE          # PSUs nested within strata
)
```

`nest = TRUE` is required when the same PSU numbers are reused across strata.

### Variance estimation
The `survey` package uses Taylor Series Linearization (TSL) by default, which correctly propagates the complex design variance through regression. This accounts for the clustering and stratification in NHANES.

### Lonely PSUs
Setting `options(survey.lonely.psu = "adjust")` handles the rare case where a stratum contains only one sampled PSU by using the stratum mean for variance estimation (a conservative approach).

---

## 5. Limitations of Cross-Sectional Analysis

A cross-sectional survey measures exposure and outcome at the same point in time. This creates fundamental limitations for causal inference:

| Limitation | Consequence |
|-----------|-------------|
| **No temporal ordering** | Cannot determine whether metal exposure preceded the HbA1c elevation or vice versa |
| **Reverse causation** | Individuals with uncontrolled diabetes may have altered metabolism that affects metal biokinetics |
| **Prevalent outcome bias** | Only living, community-dwelling participants are sampled; those who died from metal-related disease are excluded |
| **Survivor bias** | Long-term metal-exposed individuals who survived to study participation may be inherently healthier (healthy worker effect) |
| **Single time point** | Metal measurements on a single day may not reflect long-term exposure, especially for blood lead (which reflects weeks, not years) |

**For lead specifically:** Blood lead has a half-life of ~35 days; it reflects recent exposure, while cumulative bone lead better represents lifetime exposure. NHANES does not measure bone lead.

---

## 6. Why Results Should Be Interpreted as Associations, Not Causal Effects

1. **Confounding:** Despite extensive covariate adjustment, residual confounding from unmeasured variables (occupation, residential proximity to pollution sources, dietary supplement use, physical activity) cannot be eliminated in observational data.

2. **Measurement error in exposures:** Blood metal concentrations are measured with laboratory imprecision and reflect only a snapshot of exposure, potentially attenuating true associations toward the null.

3. **Effect heterogeneity:** Population-average associations may mask substantial heterogeneity by age, sex, race/ethnicity, or nutritional status. Stratified analyses are exploratory.

4. **Multiple comparisons:** Testing associations for three metals across multiple outcomes and models increases the chance of false-positive findings. Results should be interpreted in the context of a priori hypotheses and the totality of evidence.

5. **Ecological fallacy does not apply** (this is individual-level data), but individual-level associations in observational data still require replication and triangulation with experimental or quasi-experimental evidence before causal claims are warranted.

**Appropriate language:**
- ✓ "Blood lead was positively associated with HbA1c..."
- ✓ "Higher blood lead concentrations were observed in participants with elevated HbA1c..."
- ✗ "Blood lead causes HbA1c elevation..."
- ✗ "Reducing blood lead would lower HbA1c by..."

---

## 7. Computational Notes

- All file paths use `here::here()` to ensure portability across machines.
- No absolute paths are hard-coded.
- Random seed set to 2025 in `00_setup.R` for any stochastic operations.
- Scripts must be run in order (00 → 07) as each depends on outputs of prior scripts.
- Survey `svyglm` results are exported as CSV to allow the Quarto report to render without re-fitting models.
- `options(survey.lonely.psu = "adjust")` set globally to prevent errors in subgroup analyses.

---

## 8. NHANES File Structure Reference (cycle 2017–2018)

| NHANES Component | File |
|-----------------|------|
| Demographics | `DEMO_J` |
| Blood metals | `PBCD_J` |
| Glycohemoglobin | `GHB_J` |
| High-sensitivity C-reactive protein | `HSCRP_J` |
| Total cholesterol | `TCHOL_J` |
| HDL cholesterol | `HDL_J` |
| Blood pressure (auscultatory) | `BPX_J` |
| BP questionnaire | `BPQ_J` |
| Body measures | `BMX_J` |
| Dietary recall, Day 1 | `DR1TOT_J` |
| Smoking | `SMQ_J` |

**Note on CRP:** For 2017–2018 the standard CRP file is `HSCRP_J` (high-sensitivity CRP, variable `LBXHSCRP` in mg/L). The earlier `CRP_J` file does not exist for this cycle. We convert mg/L → mg/dL by multiplying by 0.1 to maintain comparability with earlier-cycle CRP units.

## 9. Data Acquisition

For maximum reliability and reproducibility, this project downloads `.XPT` files directly from the CDC NHANES public data repository at `https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/`. Each file is fetched with `curl` (180 s timeout, 3 retries) with `download.file()` as a fallback, then read via `haven::read_xpt()` and cached as `.rds` in `data/raw/`. This avoids any third-party API dependency and remains stable as long as CDC continues to host the public XPT files. See `R/01_download_data.R`.
