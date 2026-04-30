# =============================================================================
# 06_visualizations.R
# Project: Environmental Metal Exposure, Nutrition, and Cardiometabolic Biomarkers
# Purpose: Create all analysis figures using ggplot2
#
# Figures produced:
#   fig01_exposure_distributions.png   - Density/histogram of metal exposures
#   fig02_outcome_distributions.png    - HbA1c and binary outcome distribution
#   fig03_exposure_outcome_scatter.png - Scatter: log_lead vs HbA1c with LOESS
#   fig04_forest_plot.png              - Coefficient plot across models
#   fig05_hba1c_by_lead_quartile.png   - Predicted HbA1c by lead quartile
#   fig06_interaction_plot.png         - Lead × fiber interaction
#   fig07_metals_forest.png            - Multi-metal comparison
# =============================================================================

source(here::here("R", "00_setup.R"))
library(patchwork)
library(ggdist)
library(ggrepel)
library(viridis)

message("=== 06_visualizations.R: creating figures ===\n")

# --- Load data and models ----------------------------------------------------
dat_path <- file.path(dir_processed, "analysis_dataset_v2.rds")
if (!file.exists(dat_path)) stop("Run 03_define_variables.R first.")
dat <- readRDS(dat_path)

# Load regression results from CSVs (avoid needing survey objects)
linear_results  <- read_csv(file.path(dir_tables, "linear_models_lead_hba1c.csv"),
                             show_col_types = FALSE)
logit_results   <- read_csv(file.path(dir_tables, "logistic_models_lead_hba1c_elevated.csv"),
                             show_col_types = FALSE)
sensitivity_res <- read_csv(file.path(dir_tables, "sensitivity_all_metals_hba1c.csv"),
                             show_col_types = FALSE)

# Consistent color palette
metal_colors <- c("Blood lead" = "#E63946", "Blood cadmium" = "#457B9D",
                  "Blood mercury" = "#2A9D8F")
model_colors <- c("Model 1: Unadjusted"         = "#ADB5BD",
                  "Model 2: Demo-adjusted"        = "#6C757D",
                  "Model 3: Fully adjusted"       = "#212529",
                  "Model 4: + Lead×Fiber interaction" = "#E76F51")

# ============================================================================
# Figure 1: Metal exposure distributions (raw and log-transformed)
# ============================================================================
message("  [fig01] Exposure distributions")

# Pivot to long format for faceting
metals_long <- dat |>
  select(blood_lead, blood_cad, blood_hg, log_lead, log_cad, log_hg) |>
  pivot_longer(everything(), names_to = "variable", values_to = "value") |>
  filter(!is.na(value)) |>
  mutate(
    scale  = if_else(str_starts(variable, "log"), "Log-transformed", "Original scale"),
    metal  = case_when(
      str_detect(variable, "lead") ~ "Blood Lead (µg/dL)",
      str_detect(variable, "cad")  ~ "Blood Cadmium (µg/dL)",
      str_detect(variable, "hg")   ~ "Blood Mercury (µg/L)"
    ),
    scale = factor(scale, levels = c("Original scale", "Log-transformed"))
  )

fig01 <- ggplot(metals_long, aes(x = value, fill = metal)) +
  geom_histogram(bins = 45, color = "white", alpha = 0.85) +
  facet_grid(scale ~ metal, scales = "free") +
  scale_fill_manual(values = c("Blood Lead (µg/dL)"    = "#E63946",
                               "Blood Cadmium (µg/dL)" = "#457B9D",
                               "Blood Mercury (µg/L)"  = "#2A9D8F")) +
  labs(
    title    = "Figure 1. Distribution of Blood Metal Concentrations",
    subtitle = "NHANES 2017–March 2020, U.S. Adults ≥20 Years",
    x        = "Concentration",
    y        = "Count",
    caption  = "Log-transformation applied as ln(x); values ≤0 excluded (<0.01% of observations)."
  ) +
  theme_pub() +
  theme(legend.position = "none",
        strip.text = element_text(size = 9))

ggsave(file.path(dir_figures, "fig01_exposure_distributions.png"),
       fig01, width = 10, height = 6, dpi = 300)
message("    Saved fig01_exposure_distributions.png")

# ============================================================================
# Figure 2: HbA1c distribution with threshold lines
# ============================================================================
message("  [fig02] Outcome distributions")

fig02a <- dat |>
  filter(!is.na(hba1c)) |>
  ggplot(aes(x = hba1c)) +
  geom_histogram(bins = 40, fill = "#457B9D", color = "white", alpha = 0.85) +
  geom_vline(xintercept = 5.7, linetype = "dashed", color = "#E63946", linewidth = 0.8) +
  geom_vline(xintercept = 6.5, linetype = "dotted", color = "#E63946", linewidth = 0.8) +
  annotate("text", x = 5.9, y = Inf, label = "Prediabetes\n≥5.7%",
           vjust = 1.5, hjust = 0, color = "#E63946", size = 3) +
  annotate("text", x = 6.7, y = Inf, label = "Diabetes\n≥6.5%",
           vjust = 1.5, hjust = 0, color = "#E63946", size = 3) +
  labs(title    = "HbA1c Distribution",
       x = "HbA1c (%)",
       y = "Count") +
  theme_pub()

fig02b <- dat |>
  filter(!is.na(hba1c_elevated)) |>
  mutate(group = factor(hba1c_elevated, labels = c("Normal HbA1c\n(<5.7%)", "Elevated HbA1c\n(≥5.7%)"))) |>
  count(group) |>
  mutate(pct = n / sum(n) * 100) |>
  ggplot(aes(x = group, y = pct, fill = group)) +
  geom_col(color = "white", width = 0.6) +
  geom_text(aes(label = glue("{round(pct,1)}%\n(n={scales::comma(n)})")),
            vjust = -0.3, size = 3.5) +
  scale_fill_manual(values = c("#78C1D1", "#E63946")) +
  scale_y_continuous(limits = c(0, 75)) +
  labs(title    = "Elevated HbA1c (Binary)",
       x = NULL, y = "Percentage (%)") +
  theme_pub() +
  theme(legend.position = "none")

fig02 <- fig02a + fig02b +
  plot_annotation(
    title    = "Figure 2. Distribution of Primary Outcome: HbA1c",
    subtitle = "NHANES 2017–March 2020, U.S. Adults ≥20 Years",
    caption  = "Dashed line: prediabetes threshold (5.7%). Dotted line: diabetes threshold (6.5%)."
  )

ggsave(file.path(dir_figures, "fig02_outcome_distributions.png"),
       fig02, width = 10, height = 5, dpi = 300)
message("    Saved fig02_outcome_distributions.png")

# ============================================================================
# Figure 3: Scatter plot — log lead vs. HbA1c with LOESS smoother
# ============================================================================
message("  [fig03] Scatter: log lead vs HbA1c")

fig03_dat <- dat |>
  filter(!is.na(log_lead) & !is.na(hba1c)) |>
  sample_n(min(n(), 3000))   # subsample for readability

fig03 <- ggplot(fig03_dat, aes(x = log_lead, y = hba1c)) +
  geom_point(alpha = 0.15, size = 0.8, color = "#457B9D") +
  geom_smooth(method = "loess", color = "#E63946", se = TRUE,
              linewidth = 1.2, fill = "#E6394620") +
  geom_smooth(method = "lm", color = "#212529", se = FALSE,
              linewidth = 0.8, linetype = "dashed") +
  labs(
    title    = "Figure 3. Association Between Blood Lead and HbA1c",
    subtitle = "NHANES 2017–March 2020 (random subsample n≤3,000 shown for clarity)",
    x        = "Log-Transformed Blood Lead (ln µg/dL)",
    y        = "HbA1c (%)",
    caption  = "Red curve: LOESS smoother (95% CI). Dashed line: linear regression. Unadjusted."
  ) +
  theme_pub()

ggsave(file.path(dir_figures, "fig03_exposure_outcome_scatter.png"),
       fig03, width = 8, height = 6, dpi = 300)
message("    Saved fig03_exposure_outcome_scatter.png")

# ============================================================================
# Figure 4: Forest plot — β coefficients for log_lead across models
# ============================================================================
message("  [fig04] Forest plot: model comparison")

forest_dat <- linear_results |>
  filter(term == "log_lead") |>
  mutate(
    model    = factor(model, levels = rev(unique(model))),
    sig      = p.value < 0.05
  )

fig04 <- ggplot(forest_dat, aes(x = estimate, y = model, color = model)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(aes(shape = sig), size = 4) +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.2, linewidth = 0.8) +
  scale_color_manual(values = model_colors) +
  scale_shape_manual(values = c(`TRUE` = 16, `FALSE` = 1),
                     labels = c(`TRUE` = "p<0.05", `FALSE` = "p≥0.05")) +
  labs(
    title    = "Figure 4. Association of Blood Lead with HbA1c — Model Comparison",
    subtitle = "Survey-weighted regression; NHANES 2017–March 2020, U.S. Adults ≥20 Years",
    x        = "β Coefficient (per 1-unit increase in ln Blood Lead)\n95% Confidence Interval",
    y        = NULL,
    shape    = "Significance",
    caption  = paste0("Model 1: Unadjusted. Model 2: + age, sex, race/ethnicity.\n",
                      "Model 3: + education, PIR, BMI, smoking, fiber. ",
                      "Model 4: + lead×fiber interaction term.")
  ) +
  theme_pub() +
  theme(legend.position = "right")

ggsave(file.path(dir_figures, "fig04_forest_plot.png"),
       fig04, width = 9, height = 5, dpi = 300)
message("    Saved fig04_forest_plot.png")

# ============================================================================
# Figure 5: Mean HbA1c by blood lead quartile (adjusted predictions)
# ============================================================================
message("  [fig05] Predicted HbA1c by lead quartile")

# Compute crude mean HbA1c by quartile with 95% CI
quartile_dat <- dat |>
  filter(!is.na(q_lead) & !is.na(hba1c)) |>
  group_by(q_lead) |>
  summarise(
    n       = n(),
    mean    = mean(hba1c, na.rm = TRUE),
    se      = sd(hba1c, na.rm = TRUE) / sqrt(n()),
    ci_low  = mean - 1.96 * se,
    ci_high = mean + 1.96 * se,
    .groups = "drop"
  )

# Quartile median blood lead values for x-axis annotation
q_medians <- dat |>
  filter(!is.na(q_lead) & !is.na(blood_lead)) |>
  group_by(q_lead) |>
  summarise(med_lead = round(median(blood_lead, na.rm = TRUE), 2), .groups = "drop")

quartile_dat <- left_join(quartile_dat, q_medians, by = "q_lead") |>
  mutate(label = glue("{q_lead}\n(median={med_lead} µg/dL)\nn={scales::comma(n)}"))

fig05 <- ggplot(quartile_dat, aes(x = q_lead, y = mean, group = 1)) +
  geom_line(color = "#457B9D", linewidth = 1) +
  geom_point(size = 4, color = "#E63946") +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.15, color = "#E63946") +
  scale_x_discrete(labels = quartile_dat$label) +
  labs(
    title    = "Figure 5. Mean HbA1c by Blood Lead Quartile",
    subtitle = "NHANES 2017–March 2020, U.S. Adults ≥20 Years; unadjusted means ± 95% CI",
    x        = "Blood Lead Quartile",
    y        = "Mean HbA1c (%)",
    caption  = "Error bars: 95% CI based on standard error. Adjusted estimates in Table 2."
  ) +
  theme_pub()

ggsave(file.path(dir_figures, "fig05_hba1c_by_lead_quartile.png"),
       fig05, width = 8, height = 5, dpi = 300)
message("    Saved fig05_hba1c_by_lead_quartile.png")

# ============================================================================
# Figure 6: Interaction — predicted HbA1c by log_lead × fiber tertile
# ============================================================================
message("  [fig06] Interaction plot: lead × fiber")

int_dat <- dat |>
  filter(!is.na(log_lead) & !is.na(hba1c) & !is.na(fiber_g)) |>
  mutate(fiber_tert = ntile(fiber_g, 3),
         fiber_label = factor(fiber_tert, labels = c(
           glue("Low fiber\n(≤{round(quantile(dat$fiber_g, 1/3, na.rm=TRUE),1)} g)"),
           glue("Medium fiber"),
           glue("High fiber\n(>{round(quantile(dat$fiber_g, 2/3, na.rm=TRUE),1)} g)")
         )))

fig06 <- ggplot(int_dat, aes(x = log_lead, y = hba1c, color = fiber_label)) +
  geom_smooth(method = "lm", se = TRUE, alpha = 0.15, linewidth = 1.2) +
  scale_color_manual(values = c("#E07A5F", "#81B29A", "#3D405B")) +
  labs(
    title    = "Figure 6. Interaction: Blood Lead × Dietary Fiber on HbA1c",
    subtitle = "NHANES 2017–March 2020, stratified by dietary fiber tertile",
    x        = "Log-Transformed Blood Lead (ln µg/dL)",
    y        = "HbA1c (%)",
    color    = "Dietary Fiber Tertile",
    caption  = "Linear regression lines per fiber tertile. Unadjusted for clarity; see Model 4 for formal test."
  ) +
  theme_pub()

ggsave(file.path(dir_figures, "fig06_interaction_plot.png"),
       fig06, width = 8, height = 5, dpi = 300)
message("    Saved fig06_interaction_plot.png")

# ============================================================================
# Figure 7: Multi-metal comparison forest plot
# ============================================================================
message("  [fig07] Multi-metal sensitivity forest plot")

fig07_dat <- sensitivity_res |>
  mutate(
    exposure = factor(exposure, levels = c("Blood lead", "Blood cadmium", "Blood mercury")),
    sig      = p.value < 0.05
  )

fig07 <- ggplot(fig07_dat, aes(x = estimate, y = exposure, color = exposure)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(aes(shape = sig), size = 4) +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.2, linewidth = 0.8) +
  scale_color_manual(values = metal_colors) +
  scale_shape_manual(values = c(`TRUE` = 16, `FALSE` = 1),
                     labels = c(`TRUE` = "p<0.05", `FALSE` = "p≥0.05")) +
  labs(
    title    = "Figure 7. Association of Blood Metals with HbA1c — Fully Adjusted Models",
    subtitle = "Survey-weighted linear regression; NHANES 2017–March 2020, U.S. Adults ≥20 Years",
    x        = "β Coefficient (per 1-unit increase in ln Metal)\n95% Confidence Interval",
    y        = NULL,
    color    = NULL, shape = "Significance",
    caption  = "Adjusted for age, sex, race/ethnicity, education, PIR, BMI, smoking, dietary fiber."
  ) +
  theme_pub() +
  theme(legend.position = "right")

ggsave(file.path(dir_figures, "fig07_metals_forest.png"),
       fig07, width = 9, height = 4, dpi = 300)
message("    Saved fig07_metals_forest.png")

message("\n  All figures saved to outputs/figures/")
message("\n=== 06_visualizations.R: complete ===\n")
