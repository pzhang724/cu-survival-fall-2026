# =============================================================================
# 01_design.R  (Planning: group sequential design and sample size)
#
# Primary endpoint: progression-free survival (PFS), High Dose vs Placebo.
# Design: one interim analysis (IA) at 50% of events, Lan-DeMets
# O'Brien-Fleming-type alpha spending, non-binding futility at Z = 0.
# Tool: {rpact}. Cross-check: Schoenfeld's formula by hand.
# =============================================================================
source(here::here("lab", "R", "00_setup.R"))

## ---- design-gsd ----
design <- getDesignGroupSequential(
  kMax             = 2,                  # 1 interim + 1 final analysis
  informationRates = DESIGN$info_rates,  # IA at 50% of the target events
  alpha            = DESIGN$alpha,       # one-sided 2.5%
  beta             = DESIGN$beta,        # 80% power
  sided            = 1,
  typeOfDesign     = "asOF",             # Lan-DeMets O'Brien-Fleming-type spending
  futilityBounds   = 0,                  # stop for futility if Z < 0 (HR > 1) at IA
  bindingFutility  = FALSE               # non-binding: alpha is NOT recycled
)

## ---- design-schoenfeld ----
# Fixed-design events (Schoenfeld): d = 4 (z_{1-alpha} + z_{1-beta})^2 / log(HR)^2
z_a <- qnorm(1 - DESIGN$alpha)
z_b <- qnorm(1 - DESIGN$beta)
events_fixed <- 4 * (z_a + z_b)^2 / log(DESIGN$hr)^2

# The group sequential design needs a few more events (the "inflation factor")
inflation <- getDesignCharacteristics(design)$inflationFactor
events_gsd <- events_fixed * inflation
c(fixed = events_fixed, inflation = inflation, group_sequential = events_gsd)

## ---- design-samplesize ----
ss <- getSampleSizeSurvival(
  design,
  hazardRatio  = DESIGN$hr,
  median2      = DESIGN$median_control,       # control (placebo) median, months
  accrualTime  = c(0, DESIGN$accrual_months), # uniform accrual over 24 months
  followUpTime = DESIGN$followup_months,
  dropoutRate1 = DESIGN$dropout_rate,
  dropoutRate2 = DESIGN$dropout_rate,
  dropoutTime  = DESIGN$dropout_time
)

target_events <- ceiling(ss$maxNumberOfEvents)        # final analysis events
ia_events     <- ceiling(target_events * DESIGN$info_rates[1])
n_per_arm     <- ceiling(ss$maxNumberOfSubjects / 2)

## ---- design-boundary-table ----
boundary_tbl <- tibble(
  Analysis               = c("Interim (50%)", "Final"),
  `Information fraction` = design$informationRates,
  `Events (planned)`     = c(ia_events, target_events),
  `Months from first randomization` = round(ss$analysisTime[, 1], 1),
  `Efficacy boundary (Z)` = round(design$criticalValues, 3),
  `Nominal one-sided p`   = signif(design$stageLevels, 2),
  `HR at efficacy boundary` = round(ss$criticalValuesEffectScale[, 1], 3),
  `Futility boundary (Z)` = c(design$futilityBounds, NA),
  `Cumulative alpha spent` = signif(design$alphaSpent, 2)
)

## ---- design-boundary-plot ----
bnd <- tibble(info = design$informationRates, efficacy = design$criticalValues)
p_boundary <- ggplot(bnd, aes(x = info, y = efficacy)) +
  # continuation region at the interim: between the futility and efficacy bounds
  annotate("segment", x = 0.5, xend = 0.5, y = design$futilityBounds, yend = design$criticalValues[1],
           colour = "#B9D9EB", linewidth = 6) +
  geom_line(colour = "#1D4F91", linewidth = 1, linetype = "dashed") +
  geom_point(colour = "#1D4F91", size = 3.5) +
  annotate("point", x = 0.5, y = design$futilityBounds, colour = "#B03A2E", size = 3.5) +
  geom_hline(yintercept = qnorm(1 - DESIGN$alpha), linetype = "dotted", colour = "grey40") +
  annotate("text", x = 0.5, y = design$criticalValues[1] + 0.3, hjust = 0, colour = "#1D4F91",
           label = sprintf("IA: stop for efficacy if Z >= %.3f (one-sided p <= %.4f)",
                           design$criticalValues[1], design$stageLevels[1])) +
  annotate("text", x = 0.52, y = 1.4, hjust = 0, colour = "grey30", label = "IA: continue") +
  annotate("text", x = 0.52, y = design$futilityBounds, hjust = 0, colour = "#B03A2E",
           label = "IA: consider stopping for futility if Z < 0 (non-binding)") +
  annotate("text", x = 1, y = design$criticalValues[2] - 0.35, hjust = 1, colour = "#1D4F91",
           label = sprintf("Final: reject H0 if Z >= %.3f", design$criticalValues[2])) +
  annotate("text", x = 0.62, y = qnorm(1 - DESIGN$alpha) + 0.1, hjust = 0, colour = "grey40",
           size = 3.2, label = "fixed design: 1.960") +
  scale_x_continuous("Information fraction (events observed / events planned)",
                     limits = c(0.45, 1.02), breaks = c(0.5, 1)) +
  scale_y_continuous("Log-rank Z (positive favours High Dose)", limits = c(-0.5, 3.5)) +
  theme_minimal(base_size = 13)

## ---- design-sensitivity ----
# How fragile is the plan? Events and patients needed as the assumed HR changes.
sens_tbl <- map_dfr(c(0.50, 0.55, 0.60, 0.65, 0.70, 0.75), function(hr) {
  x <- getSampleSizeSurvival(design, hazardRatio = hr, median2 = DESIGN$median_control,
    accrualTime = c(0, DESIGN$accrual_months), followUpTime = DESIGN$followup_months,
    dropoutRate1 = DESIGN$dropout_rate, dropoutRate2 = DESIGN$dropout_rate,
    dropoutTime = DESIGN$dropout_time)
  tibble(`Assumed HR` = hr, `Events needed` = ceiling(x$maxNumberOfEvents),
         `Patients (2 arms)` = 2 * ceiling(x$maxNumberOfSubjects / 2))
})

## ---- design-save ----
ggsave(lab_path("output", "figures", "f_design_boundaries.png"), p_boundary,
       width = 8, height = 4.5, dpi = 150, bg = "white")
save_rtf(gt(boundary_tbl), "t_design_boundaries")
