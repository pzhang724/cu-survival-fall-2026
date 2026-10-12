# =============================================================================
# 09_interim.R  (Interim analysis for the Data Monitoring Committee)
#
# Trigger: 61 PFS events (50% of 122) in High Dose + Placebo.
# The ADaM program in 05 was re-run with the data cut-off date (DCO), giving
# adtte_ia. Here we compute what goes into the DMC closed report:
#   observed log-rank Z and one-sided p-value vs the efficacy boundary,
#   the non-binding futility guideline, and conditional power (CP).
# In a real trial this is run by an independent statistician behind a
# firewall; the sponsor study team stays blinded.
# =============================================================================
source(here::here("lab", "R", "00_setup.R"))
need("compare_arms", "07_tfl_efficacy.R")

## ---- ia-data ----
pfs_ia <- adtte_ia %>%
  filter(PARAMCD == "PFS") %>%
  mutate(TRT01P = factor(TRT01P, levels = ARM_LEVELS), AVAL_M = AVAL / DAYS_PER_MONTH)

ia <- compare_arms(pfs_ia, EXPERIMENTAL)        # same function as the final analysis
info_frac <- ia$events / target_events

## ---- ia-boundaries ----
# Lan-DeMets spending: the boundary follows the ACTUAL information fraction
design_ia <- getDesignGroupSequential(
  kMax = 2, alpha = DESIGN$alpha, beta = DESIGN$beta, sided = 1,
  typeOfDesign = "asOF", informationRates = c(info_frac, 1),
  futilityBounds = 0, bindingFutility = FALSE
)
z_eff_ia <- design_ia$criticalValues[1]   # efficacy boundary at this interim
p_eff_ia <- design_ia$stageLevels[1]      # same boundary on the one-sided p-value scale
z_fin    <- design_ia$criticalValues[2]   # planned final boundary

## ---- ia-conditional-power ----
# CP = P(reject H0 at the final | data so far, true effect theta)
# Information for the log-rank test ~ events / 4 (1:1 randomization);
# theta = -log(HR), so theta > 0 favours the drug.
cond_power <- function(z_k, d_k, d_max, theta, z_final) {
  i_k <- d_k / 4
  i_max <- d_max / 4
  1 - pnorm((z_final * sqrt(i_max) - z_k * sqrt(i_k) - theta * (i_max - i_k)) /
              sqrt(i_max - i_k))
}

theta_trend <- ia$z / sqrt(ia$events / 4)          # effect estimated from the interim Z
cp_tbl <- tibble(
  Assumption = c(sprintf("Design: HR = %.2f", DESIGN$hr),
                 sprintf("Current trend: HR = %.2f", exp(-theta_trend)),
                 "No effect: HR = 1"),
  theta = c(-log(DESIGN$hr), theta_trend, 0)
) %>%
  mutate(`Conditional power` = cond_power(ia$z, ia$events, target_events, theta, z_fin))

## ---- ia-rpact ----
# Cross-check with rpact. rpact's log-rank statistic carries the sign of
# log(HR): for "HR < 1 is better" pass -Z and set directionUpper = FALSE.
ia_results <- getAnalysisResults(
  design_ia,
  dataInput = getDataset(cumulativeEvents = ia$events, cumulativeLogRanks = -ia$z),
  directionUpper = FALSE, nPlanned = target_events - ia$events, thetaH1 = DESIGN$hr
)
cp_rpact_design <- ia_results$conditionalPower[2]

## ---- ia-report ----
n_rand_ia <- pfs_ia %>% count(TRT01P)
ev_ia     <- pfs_ia %>% filter(CNSR == 0) %>% count(TRT01P)
decision  <- case_when(
  ia$z >= z_eff_ia ~ "Efficacy boundary crossed",
  ia$z < 0         ~ "Futility guideline met (Z < 0); non-binding",
  TRUE             ~ "Continue the trial as planned"
)

ia_report <- tibble(
  Item = c("Data cut-off date (DCO)",
           "Patients randomized by DCO (Placebo / Low / High)",
           "PFS events (Placebo / High Dose)",
           "Information fraction (events / 122 planned)",
           "Hazard ratio High Dose vs Placebo (95% CI)",
           "Log-rank Z (positive favours High Dose)",
           "One-sided p-value",
           "Efficacy boundary at this interim",
           "Futility guideline (non-binding)",
           "Conditional power: design HR 0.60",
           sprintf("Conditional power: current trend (HR %.2f)", exp(-theta_trend)),
           "Outcome"),
  Value = c(format(ia_dco),
            paste(n_rand_ia$n, collapse = " / "),
            sprintf("%d / %d (total %d)", ev_ia$n[ev_ia$TRT01P == CONTROL],
                    ev_ia$n[ev_ia$TRT01P == EXPERIMENTAL], ia$events),
            sprintf("%d / %d = %.1f%%", ia$events, target_events, 100 * info_frac),
            sprintf("%.2f (%.2f, %.2f)", ia$hr, ia$hr_lower, ia$hr_upper),
            sprintf("%.3f", ia$z),
            sprintf("%.3f", ia$p_one_sided),
            sprintf("Z >= %.3f (one-sided p <= %.4f): %s", z_eff_ia, p_eff_ia,
                    if (ia$z >= z_eff_ia) "crossed" else "not crossed"),
            sprintf("Z < 0: %s", if (ia$z < 0) "met" else "not met"),
            sprintf("%.1f%%", 100 * cp_tbl$`Conditional power`[1]),
            sprintf("%.1f%%", 100 * cp_tbl$`Conditional power`[2]),
            decision)
)

t_ia_1 <- ia_report %>%
  gt() %>%
  tab_header(title = md("**Table IA.1** Interim analysis of PFS: High Dose vs Placebo (DMC closed report)")) %>%
  tab_footnote(paste("Lan-DeMets O'Brien-Fleming-type alpha spending, one-sided alpha 2.5%;",
                     "conditional power uses the final boundary and 122 planned events."))

## ---- ia-boundary-plot ----
# Where did the interim land relative to the boundaries?
p_ia_boundary <- p_boundary +
  annotate("point", x = info_frac, y = ia$z, shape = 18, size = 6, colour = "#E07B00") +
  annotate("text", x = info_frac + 0.02, y = ia$z + 0.3, hjust = 0, colour = "#E07B00", size = 4.6,
           label = sprintf("Observed at the interim: Z = %.2f (HR %.2f)", ia$z, ia$hr))

## ---- ia-km ----
p_km_ia <- survfit2(Surv(AVAL_M, 1 - CNSR) ~ TRT01P, data = pfs_ia) %>%
  ggsurvfit(linewidth = 0.9) +
  add_censor_mark(size = 2, alpha = 0.6) +
  add_risktable(risktable_stats = "n.risk", size = 4.5,
                theme = theme_risktable_default(axis.text.y.size = 13, plot.title.size = 14)) +
  scale_color_manual(values = arm_colours) +
  scale_x_continuous(breaks = 0:6, limits = c(0, 6.1)) +
  scale_y_continuous(labels = scales::percent) +
  labs(x = "Months since randomization", y = "Progression-free survival",
       title = sprintf("Figure IA.1 PFS at the interim analysis (DCO %s)", format(ia_dco))) +
  theme(legend.position = "bottom", plot.title = element_text(size = 15),
        axis.text = element_text(size = 13), axis.title = element_text(size = 15),
        legend.text = element_text(size = 14))

## ---- ia-save ----
save_rtf(t_ia_1, "t_ia_1_interim_pfs")
ggsave(lab_path("output", "figures", "f_ia_1_km_pfs.png"), p_km_ia,
       width = 9, height = 6, dpi = 150, bg = "white")
