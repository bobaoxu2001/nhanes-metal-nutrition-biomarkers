# Executive Summary

**Project:** Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers — A Reproducible Cross-Sectional Analysis of NHANES 2017–2018  
**Author:** Allen Xu · ax2183@nyu.edu  
**Repository:** https://github.com/bobaoxu2001/nhanes-metal-nutrition-biomarkers

---

## Research Question

Are blood concentrations of lead, cadmium, and mercury associated with HbA1c among U.S. adults aged ≥20, and does dietary fiber intake modify these associations?

## Data Source

The **National Health and Nutrition Examination Survey (NHANES) 2017–2018** cycle, a nationally representative complex-survey dataset administered by the U.S. Centers for Disease Control and Prevention (CDC). Public domain. Eleven NHANES files (demographics, blood metals, glycohemoglobin, high-sensitivity CRP, cholesterol, blood pressure, body measures, dietary recall, smoking) are downloaded directly from the CDC public data repository, harmonized on `SEQN`, and merged into a single analytic dataset.

## Analytic Sample

**N = 5,014 U.S. adults aged ≥20 years** with valid blood metal and HbA1c measurements after exclusions for age <20, missing MEC weight, missing all metal exposures, and missing HbA1c.

## Methods

- **Design.** Survey-weighted analysis using `survey::svydesign()` with `SDMVPSU`, `SDMVSTRA`, and `WTMEC2YR` (single-cycle 2-year MEC weight, used directly without pooling adjustment).
- **Exposures.** Blood lead, cadmium, mercury — natural-log-transformed; quartile cuts for stratification.
- **Outcome.** HbA1c (continuous); elevated HbA1c ≥5.7% (binary; ADA prediabetes threshold).
- **Models.** Four sequential survey-weighted linear models (`svyglm`, Gaussian) — unadjusted → demographic → fully adjusted → fully adjusted with a lead × dietary-fiber interaction. Three logistic models (`svyglm`, quasibinomial) for the binary outcome. Sensitivity analyses substitute cadmium and mercury for lead in the fully adjusted model. A stratified analysis fits the fully adjusted lead → HbA1c model within each fiber tertile of the survey design.
- **Reporting.** Tables produced with `gtsummary` and exported to DOCX via `flextable`. Seven publication-quality figures produced with `ggplot2` and `patchwork`. The full report is rendered as a self-contained Quarto HTML and PDF.

## Key Result

After adjusting for age, sex, race/ethnicity, education, poverty-income ratio, BMI, smoking, and dietary fiber, log blood lead was inversely associated with HbA1c (β = **−0.21**, 95% CI: **−0.28, −0.15**; p < 0.001). The unadjusted association was small and not statistically significant (β = +0.04, 95% CI: −0.01, 0.09; p = 0.094). Adjusted associations for cadmium and mercury were near-null and small, respectively.

## Interpretation

This is a **cross-sectional adjusted statistical association, not evidence that lead exposure protects against dysglycemia**. The direction reversal between the unadjusted and fully adjusted estimates is most plausibly explained by negative confounding from demographic and socioeconomic factors that are themselves correlated with both blood-lead burden and glycemic control, possibly compounded by selection processes, the timing window captured by blood-lead measurement (recent rather than cumulative exposure), and model specification under residual confounding. Findings should not be over-interpreted causally and would require longitudinal data, mixture modeling, and replication to support any directional inference.

## Limitations

1. **Cross-sectional design** — temporality cannot be established and reverse causation cannot be excluded.
2. **Residual confounding** — occupational and dietary-supplement exposures, residential proximity to pollution, physical activity, and most non-antihypertensive medications are unmeasured.
3. **Dietary recall measurement error** — Day-1 24-hour recall does not necessarily reflect habitual intake.
4. **Blood metals reflect recent exposure** — blood lead has a half-life of ~35 days; bone lead (cumulative burden) is not measured in NHANES.
5. **Single cycle** — pooling additional cycles in future work could improve precision and temporal scope.
6. **Complete-case analysis** — assumes missing-at-random; multiple imputation is a natural future extension.

## Why This Demonstrates Readiness for an Epidemiology Data Analyst Role

This project shows that I can independently take a research question through a complete reproducible analysis pipeline that mirrors how an academic epidemiology team works:

- **Real public-health data acquisition** from the CDC, with retry/fallback logic so the pipeline reproduces years from now.
- **Correct handling of NHANES complex survey design** — strata, PSUs, MEC weights, lonely-PSU adjustment, and a survey-weighted stratified analysis (not naive `lm()`).
- **Multi-file harmonization on `SEQN`** across 11 NHANES files, with transparent exclusion logging.
- **Variable engineering** — log transforms for skewed metals, quartiles, z-scores, ADA-criterion binary thresholds.
- **Sequential adjustment + interaction + sensitivity** modeling that matches the rhythm of an epidemiology research paper.
- **Publication-quality output** — `gtsummary` Table 1, DOCX-exported regression tables, seven `ggplot2` figures, and a Quarto research report (HTML and PDF).
- **Documentation** — pre-analysis plan, variable dictionary, methods notes, executive summary, all consistent with the code.
- **Honest interpretation** — the headline result is framed as an adjusted association rather than a causal effect; the limitations are explicit about what this design can and cannot support.
- **One-command reproducibility** — `Rscript run_all.R` runs scripts 00→07 in order with timing banners and renders the report.

A faculty member, biostatistician, or future analyst should be able to clone this repository, run a single command, and reproduce every table and figure in the report — and audit every analytic decision against the matching documentation file.
