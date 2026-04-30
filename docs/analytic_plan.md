# Analytic Plan

**Project:** Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers: A Reproducible NHANES Analysis  
**Author:** Ao Xu  
**Date:** 2025  
**Status:** Pre-registered analytic plan (pre-analysis)

---

## 1. Objective

To examine whether blood concentrations of lead, cadmium, and mercury are associated with glycemic biomarkers (HbA1c) among U.S. adults, and to evaluate whether dietary fiber intake modifies or attenuates these associations. Secondary objectives include evaluating binary dysglycemia outcomes and multi-metal sensitivity analyses.

---

## 2. Hypotheses

**Primary hypothesis:**  
Higher blood lead concentration (log-transformed) is positively associated with HbA1c (%) after adjustment for demographic, socioeconomic, and behavioral covariates.

**Secondary hypotheses:**
- Blood cadmium and mercury are independently associated with HbA1c.
- Higher dietary fiber intake attenuates the metal-HbA1c association (negative interaction on the additive or multiplicative scale).
- Blood lead is positively associated with elevated HbA1c (≥5.7%) in logistic regression models.

**Null hypothesis:**  
There is no association between log-transformed blood lead and HbA1c after full covariate adjustment.

---

## 3. Study Population

| Criterion | Specification |
|-----------|---------------|
| Data source | NHANES 2017–2018 (cycle J) |
| Age | ≥20 years |
| Eligibility | Participated in Mobile Examination Center (MEC) |
| Exposure | Available blood lead measurement (PBCD files) |
| Outcome | Available HbA1c measurement (GHB files) |
| Exclusions | Missing MEC weight, age <20, missing all metal exposures, missing HbA1c |

Expected final N: ~5,000 adults (achieved analytic sample: 5,014).

---

## 4. Exposures

| Exposure | NHANES Variable | Unit | Transformation |
|----------|----------------|------|---------------|
| Blood lead | `LBXBPB` | µg/dL | ln(x); quartiles |
| Blood cadmium | `LBXBCD` | µg/dL | ln(x); quartiles |
| Blood total mercury | `LBXTHG` | µg/L | ln(x); quartiles |

**Primary exposure:** Blood lead (most strongly associated with cardiometabolic outcomes in the literature; highest detection rate in the general population).

**Rationale for log-transformation:** Metal concentrations are right-skewed. Log-transformation normalizes the distribution and allows interpretation of associations on the log-concentration scale (a clinically meaningful exposure metric). Values ≤0 (<0.01% of observations) are set to NA.

---

## 5. Outcomes

| Outcome | NHANES Variable | Type | Definition |
|---------|----------------|------|-----------|
| HbA1c | `LBXGH` | Continuous | % glycated hemoglobin |
| Elevated HbA1c | Derived from `LBXGH` | Binary | HbA1c ≥5.7% (prediabetes/diabetes threshold) |

**Primary outcome:** HbA1c (continuous) — primary pre-specified outcome.  
**Secondary outcome:** Elevated HbA1c ≥5.7% (binary) — secondary pre-specified outcome.

---

## 6. Effect Modifier / Confounder: Nutrition

**Primary nutrition variable:** Dietary fiber (g/day) from Day 1 24-hour dietary recall (`DR1TFIBE`).

**Rationale:** Fiber may reduce gastrointestinal absorption of lead and cadmium, and is independently associated with glycemic control. It serves both as a potential effect modifier and as a confounder to be adjusted.

**Operationalization:**
- Continuous (standardized z-score) for interaction terms
- Tertile (low/medium/high) for stratified analyses

---

## 7. Covariates

| Covariate | Variable | Coding |
|-----------|----------|--------|
| Age | `RIDAGEYR` | Continuous; categories (20–39, 40–59, ≥60) |
| Sex | `RIAGENDR` | Male / Female |
| Race/ethnicity | `RIDRETH3` | Mexican American, Other Hispanic, NH White, NH Black, NH Asian, Other |
| Education | `DMDEDUC2` | <9th grade, 9–11th, HS/GED, Some college, College+ |
| Poverty-income ratio | `INDFMPIR` | Continuous, top-coded at 5 |
| BMI | `BMXBMI` | Continuous (kg/m²); categorical (WHO) |
| Smoking status | `SMQ020`, `SMQ040` | Never / Former / Current |

---

## 8. Statistical Models

### Model Sequence (Primary: log_lead → HbA1c)

| Model | Formula | Covariates |
|-------|---------|-----------|
| Model 1 | `HbA1c ~ log_lead` | None |
| Model 2 | `HbA1c ~ log_lead + ...` | Age, sex, race/ethnicity |
| Model 3 | `HbA1c ~ log_lead + ...` | + education, PIR, BMI, smoking, dietary fiber |
| Model 4 | `HbA1c ~ log_lead * fiber_z + ...` | Model 3 + interaction term |

All models: survey-weighted (`svyglm`, `family = gaussian()`), NHANES strata and PSUs.

### Binary Outcome (log_lead → Elevated HbA1c)

Same model sequence using `family = quasibinomial()` to obtain odds ratios.

### Sensitivity Analyses

- Replace `log_lead` with `log_cad` (cadmium) and `log_hg` (mercury) in Model 3.
- Stratify Model 3 by dietary fiber tertile to examine effect measure modification.

---

## 9. Handling Survey Design

- Use the NHANES 2-year MEC weight `WTMEC2YR` directly (single-cycle analysis; no pooling adjustment).
- Design object: `svydesign(ids = ~psu, strata = ~strata, weights = ~wt_mec, nest = TRUE)`
- Option: `survey.lonely.psu = "adjust"` for strata with single PSU

---

## 10. Missing Data

- **Approach:** Complete-case analysis (primary)
- **Reporting:** Proportion missing by variable; comparison of included vs. excluded participants
- **Assumption:** Missing at random (MAR)
- **Future work:** Multiple imputation as sensitivity analysis (not included in primary analysis)

---

## 11. Sensitivity Analyses

| Analysis | Description |
|----------|-------------|
| All metals | Repeat Model 3 for cadmium and mercury |
| Fiber stratification | Stratify Model 3 by fiber tertile |
| Exclude diabetes Rx | Sensitivity excluding participants on diabetes medication (if available) |
| Cycle-specific | Run models within each NHANES cycle separately |

---

## 12. Limitations Acknowledged a Priori

1. Cross-sectional design; cannot establish temporality or causality.
2. Single 24-hour dietary recall; single day may not reflect habitual intake.
3. Blood metals reflect recent, not cumulative, exposure (especially for lead and mercury).
4. Complete-case analysis may introduce selection bias if missingness is informative.
5. Multiple testing across metals and outcomes; results should be interpreted with this in mind.
6. Potential residual confounding from unmeasured variables (occupation, physical activity, other pollutants).
