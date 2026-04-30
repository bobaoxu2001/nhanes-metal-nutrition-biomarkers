# Variable Dictionary

**Project:** Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers  
**Data Source:** NHANES 2017–2018 (cycle J) and 2019–March 2020 (cycle P)  
**Last Updated:** 2025

---

## Survey Design Variables

| Clean Name | NHANES Variable | File | Description | Role |
|-----------|----------------|------|-------------|------|
| `seqn` | `SEQN` | All | Respondent sequence number (unique ID) | Key / merge |
| `psu` | `SDMVPSU` | DEMO | Masked variance pseudo-PSU | Survey design |
| `strata` | `SDMVSTRA` | DEMO | Masked variance pseudo-stratum | Survey design |
| `wt_mec` | `WTMEC2YR` / `WTMECPRP` | DEMO | Combined 4-year MEC exam weight | Survey weight |
| `cycle` | Derived | — | NHANES cycle (2017–2018 or 2019–March 2020) | Stratum |

**Weight construction:**  
- 2017–2018: `wt_combined = WTMEC2YR / 2`  
- 2019–March 2020: `wt_combined = WTMECPRP / 2`  
(Division by 2 = number of cycles combined, per NCHS guidelines)

---

## Demographic Variables

| Clean Name | NHANES Variable | File | Description | Coding | Role |
|-----------|----------------|------|-------------|--------|------|
| `age` | `RIDAGEYR` | DEMO | Age at screening (years) | Continuous | Covariate |
| `age_cat` | Derived | — | Age category | 20–39 / 40–59 / 60+ | Covariate |
| `sex` | `RIAGENDR` | DEMO | Biological sex | 1=Male, 2=Female → factor | Covariate |
| `race_eth` | `RIDRETH3` | DEMO | Race/Hispanic origin (6-level) | 1=Mexican American, 2=Other Hispanic, 3=NH White, 4=NH Black, 6=NH Asian, 7=Other/Multiracial | Covariate |
| `educ` | `DMDEDUC2` | DEMO | Education level (adults ≥20) | 1=<9th grade, 2=9–11th, 3=HS/GED, 4=Some college/AA, 5=College+ | Covariate |
| `pir` | `INDFMPIR` | DEMO | Poverty-income ratio | Continuous 0–5 (top-coded at 5); higher = higher income | Covariate |
| `pir_cat` | Derived | — | PIR category | <1 / 1–<2 / 2–<3 / ≥3 | Covariate |

---

## Exposure Variables (Blood Metals)

| Clean Name | NHANES Variable | File | Description | Unit | Transformation | Role |
|-----------|----------------|------|-------------|------|---------------|------|
| `blood_lead` | `LBXBPB` | PBCD | Blood lead | µg/dL | None (raw) | Primary exposure |
| `blood_cad` | `LBXBCD` | PBCD | Blood cadmium | µg/dL | None (raw) | Secondary exposure |
| `blood_hg` | `LBXTHG` | PBCD | Blood total mercury | µg/L | None (raw) | Secondary exposure |
| `log_lead` | Derived | — | ln(blood lead) | ln(µg/dL) | log_safe(blood_lead) | Primary exposure (analysis) |
| `log_cad` | Derived | — | ln(blood cadmium) | ln(µg/dL) | log_safe(blood_cad) | Secondary exposure (analysis) |
| `log_hg` | Derived | — | ln(blood mercury) | ln(µg/L) | log_safe(blood_hg) | Secondary exposure (analysis) |
| `q_lead` | Derived | — | Blood lead quartile | Q1–Q4 | `quartile_factor(blood_lead)` | Descriptive / stratification |
| `q_cad` | Derived | — | Blood cadmium quartile | Q1–Q4 | `quartile_factor(blood_cad)` | Descriptive |
| `q_hg` | Derived | — | Blood mercury quartile | Q1–Q4 | `quartile_factor(blood_hg)` | Descriptive |

**NHANES PBCD File Notes:**
- PBCD_J (2017–2018): Blood Cadmium, Lead, Total Mercury, Selenium, and Manganese
- PBCD_P (2019–March 2020): Same variables, same NHANES file structure
- Detection: ICP-MS; LOD varies by cycle; values below LOD = LOD/√2 (pre-applied by NHANES)

---

## Outcome Variables

| Clean Name | NHANES Variable | File | Description | Unit | Transformation | Role |
|-----------|----------------|------|-------------|------|---------------|------|
| `hba1c` | `LBXGH` | GHB | Glycated hemoglobin (HbA1c) | % | None | Primary continuous outcome |
| `hba1c_elevated` | Derived | — | Elevated HbA1c (≥5.7%) | 0/1 | `hba1c >= 5.7` | Primary binary outcome |
| `hba1c_diabetes` | Derived | — | Diabetes-range HbA1c (≥6.5%) | 0/1 | `hba1c >= 6.5` | Secondary binary outcome |
| `crp` | `LBXCRP` | CRP | C-reactive protein | mg/dL | None | Secondary outcome |
| `total_chol` | `LBXTC` | TCHOL | Total cholesterol | mg/dL | None | Secondary outcome |
| `hdl_chol` | `LBDHDD` | HDL | HDL cholesterol | mg/dL | None | Secondary outcome |
| `sbp` | Derived | BPX/BPXO | Mean systolic blood pressure | mmHg | Row mean of 3 readings | Secondary outcome |
| `dbp` | Derived | BPX/BPXO | Mean diastolic blood pressure | mmHg | Row mean of 3 readings | Secondary outcome |
| `hypertension` | Derived | — | Hypertension (SBP≥130 OR DBP≥80 OR BP med) | 0/1 | See 03_define_variables.R | Secondary binary outcome |

**HbA1c thresholds:**
- Normal: <5.7%
- Prediabetes: 5.7–6.4%
- Diabetes: ≥6.5% (ADA 2023 criteria)

---

## Body Measures

| Clean Name | NHANES Variable | File | Description | Unit | Role |
|-----------|----------------|------|-------------|------|------|
| `bmi` | `BMXBMI` | BMX | Body mass index | kg/m² | Covariate / secondary outcome |
| `bmi_cat` | Derived | — | BMI category (WHO) | Underweight/<18.5, Normal/18.5–24.9, Overweight/25–29.9, Obese/≥30 | Descriptive |
| `bp_med` | `BPQ050A` | BPQ | Currently taking antihypertensive medication | 0=No, 1=Yes | Covariate (hypertension definition) |
| `sbp1/2/3` | `BPXSY1/2/3` | BPX | Systolic BP readings 1/2/3 (2017–2018) | mmHg | Used for mean SBP |
| `sbp1p/2p/3p` | `BPXOSY1/2/3` | BPXO | Systolic BP readings 1/2/3 (2019–March 2020) | mmHg | Used for mean SBP |

---

## Nutrition Variables (24-hr Dietary Recall, Day 1)

| Clean Name | NHANES Variable | File | Description | Unit | Role |
|-----------|----------------|------|-------------|------|------|
| `fiber_g` | `DR1TFIBE` | DR1TOT | Dietary fiber | g/day | Primary effect modifier / confounder |
| `fiber_z` | Derived | — | Standardized dietary fiber | z-score | Continuous interaction term |
| `fiber_q` | Derived | — | Dietary fiber quartile | FQ1–FQ4 | Stratification |
| `vitc_mg` | `DR1TVC` | DR1TOT | Vitamin C | mg/day | Descriptive |
| `energy_kcal` | `DR1TKCAL` | DR1TOT | Total energy intake | kcal/day | Descriptive / potential covariate |
| `calcium_mg` | `DR1TCALC` | DR1TOT | Calcium | mg/day | Descriptive |
| `iron_mg` | `DR1TIRON` | DR1TOT | Iron | mg/day | Descriptive |

---

## Behavioral Variables

| Clean Name | NHANES Variable | File | Description | Coding | Role |
|-----------|----------------|------|-------------|--------|------|
| `smoke_status` | Derived | SMQ | Smoking status | Never / Former / Current | Covariate |

**Derivation of smoke_status:**  
- **Never:** `SMQ020 == 2` (smoked <100 cigarettes in lifetime)  
- **Former:** `SMQ020 == 1 AND SMQ040 == 3` (ever smoked ≥100, now not at all)  
- **Current:** `SMQ020 == 1 AND SMQ040 %in% c(1, 2)` (smokes every day or some days)  
- Missing codes (7=Refused, 9=Don't know) set to NA before derivation

---

## NHANES Missing Value Codes

The following NHANES values are recoded to `NA` using `nhanes_na()`:

| Code | Meaning |
|------|---------|
| 7, 77, 777 | Refused |
| 9, 99, 999, 9999 | Don't know |

Note: nhanesA package automatically converts many labeled values; numeric recoding applied as a safety check.
