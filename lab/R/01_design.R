# =============================================================================
# 01_design.R  (Planning: sample size, power and group sequential design)
#
# Primary endpoint: progression-free survival (PFS), High Dose vs Placebo.
# Hypothesis: H0: HR = 1 vs H1: HR < 1, one-sided alpha 2.5%, power 80%,
# design HR 0.60 (placebo median PFS 1.7 months -> High Dose 2.8 months).
#
# Step 1  events for a fixed design (Schoenfeld's formula)
# Step 2  events -> patients (accrual, follow-up, dropout)
# Step 3  group sequential design: analyses at 50%, 75% and 100% of the TOTAL
#         number of events (both arms pooled), Lan-DeMets O'Brien-Fleming-type
#         alpha spending. Futility is non-binding and based on conditional
#         power (09_interim.R), so the design has efficacy bounds only.
# Step 4  power analysis: power for other true HRs and event numbers
# Tool: {gsDesign}, with Schoenfeld's method so the numbers match the formula.
# =============================================================================
source(here::here("lab", "R", "00_setup.R"))

## ---- design-hypothesis ----
# Exponential model: median = log(2) / hazard, so HR = median_control / median_experimental
median_exp <- DESIGN$median_control / DESIGN$hr

hyp_curves <- expand_grid(month = seq(0, 8, by = 0.05),
                          arm = c("Placebo", "High Dose (design)")) %>%
  mutate(median = if_else(arm == "Placebo", DESIGN$median_control, median_exp),
         surv = exp(-log(2) / median * month))
p_hypothesis <- ggplot(hyp_curves, aes(month, surv, colour = arm)) +
  geom_line(linewidth = 1.1) +
  geom_segment(data = distinct(hyp_curves, arm, median),
               aes(x = median, xend = median, y = 0, yend = 0.5), linetype = "dashed") +
  geom_hline(yintercept = 0.5, linetype = "dotted", colour = "grey50") +
  annotate("text", x = c(DESIGN$median_control - 0.1, median_exp + 0.1), y = 0.05,
           hjust = c(1, 0), size = 4.6,
           label = sprintf("median %.1f", c(DESIGN$median_control, median_exp))) +
  scale_colour_manual(NULL, values = c("Placebo" = "#7F7F7F", "High Dose (design)" = "#1D4F91")) +
  scale_y_continuous("Progression-free survival", labels = scales::percent) +
  scale_x_continuous("Months since randomization", breaks = 0:8) +
  theme_minimal(base_size = 16) +
  theme(legend.position = "bottom")

## ---- design-schoenfeld ----
# Step 1. Events for a fixed design (1:1 randomization, log-rank test):
# d = 4 (z_{1-alpha} + z_{1-beta})^2 / log(HR)^2
z_a <- qnorm(1 - DESIGN$alpha)
z_b <- qnorm(1 - DESIGN$beta)
events_fixed <- 4 * (z_a + z_b)^2 / log(DESIGN$hr)^2

# {gsDesign} gives the same number
nEvents(hr = DESIGN$hr, alpha = DESIGN$alpha, beta = DESIGN$beta)

## ---- design-fixed-n ----
# Step 2. Events -> patients:
#   patients = events / P(a patient has an event)
# P(event) depends on the hazards, accrual,
# follow-up and dropout.
fixed <- nSurv(
  lambdaC = log(2) / DESIGN$median_control, # hazard
  hr      = DESIGN$hr,
  eta     = -log(1 - DESIGN$dropout_rate) /
              DESIGN$dropout_time,          # dropout
  R       = DESIGN$accrual_months,          # accrual
  minfup  = DESIGN$followup_months,
  T       = DESIGN$accrual_months + DESIGN$followup_months,
  alpha   = DESIGN$alpha, beta = DESIGN$beta,
  sided   = 1, method = "Schoenfeld"
)
p_event <- fixed$d / fixed$n          # P(event)
n_fixed <- 2 * ceiling(fixed$n / 2)   # even (1:1)

## ---- design-gsd ----
# Step 3. Same assumptions, three analyses
gs <- gsSurv(
  k = 3,                            # 2 interims + final
  timing = DESIGN$info_rates[1:2],  # 50%, 75% of events
  test.type = 1,                    # efficacy only
  sfu = sfLDOF,                     # Lan-DeMets OF
  alpha = DESIGN$alpha, beta = DESIGN$beta,
  lambdaC = log(2) / DESIGN$median_control,
  hr = DESIGN$hr,
  eta = -log(1 - DESIGN$dropout_rate) / DESIGN$dropout_time,
  R = DESIGN$accrual_months,
  minfup = DESIGN$followup_months,
  T = DESIGN$accrual_months + DESIGN$followup_months,
  method = "Schoenfeld"
)

target_events <- ceiling(max(gs$n.I))   # final
ia_events     <- ceiling(gs$n.I[1:2])   # interims
inflation     <- max(gs$n.I) / events_fixed
n_per_arm     <- ceiling(max(rowSums(gs$eNC + gs$eNE)) / 2)

## ---- design-boundary-table ----
look_events <- c(ia_events, target_events)
boundary_tbl <- tibble(
  Analysis                 = c("Interim 1 (50%)", "Interim 2 (75%)", "Final"),
  `Events (planned)`       = look_events,
  `Expected month`         = round(gs$T, 1),
  `Efficacy boundary (Z)`  = round(gs$upper$bound, 3),
  `Nominal one-sided p`    = signif(pnorm(-gs$upper$bound), 2),
  `HR at boundary`         = round(exp(-2 * gs$upper$bound / sqrt(look_events)), 2),
  `Cumulative alpha spent` = signif(cumsum(gs$upper$spend), 2)
)

## ---- design-event-forecast ----
# Analyses are triggered by events, not by dates: expected total events by month
event_curve <- tibble(month = seq(0, 30, by = 0.25)) %>%
  mutate(events = map_dbl(month, ~ if (.x == 0) 0 else nEventsIA(tIA = .x, x = gs)))
p_events <- ggplot(event_curve, aes(month, events)) +
  geom_line(colour = "#1D4F91", linewidth = 1) +
  geom_hline(yintercept = look_events, linetype = "dashed", colour = "grey50") +
  annotate("point", x = gs$T, y = gs$n.I, colour = "#E07B00", size = 3.5) +
  annotate("text", x = 0.5, y = look_events + 5, hjust = 0, size = 4.6, colour = "grey30",
           label = sprintf("%s: %d events (month %.0f)", boundary_tbl$Analysis, look_events, gs$T)) +
  annotate("text", x = DESIGN$accrual_months, y = 8, hjust = 1, size = 4.2, colour = "grey40",
           label = "end of enrollment") +
  geom_vline(xintercept = DESIGN$accrual_months, linetype = "dotted", colour = "grey40") +
  scale_x_continuous("Months from first randomization", breaks = seq(0, 30, 6)) +
  scale_y_continuous("Expected total PFS events (both arms)") +
  theme_minimal(base_size = 16)

## ---- design-boundary-plot ----
bnd <- tibble(info = DESIGN$info_rates, efficacy = gs$upper$bound)
p_boundary <- ggplot(bnd, aes(x = info, y = efficacy)) +
  geom_line(colour = "#1D4F91", linewidth = 1, linetype = "dashed") +
  geom_point(colour = "#1D4F91", size = 3.5) +
  geom_hline(yintercept = qnorm(1 - DESIGN$alpha), linetype = "dotted", colour = "grey40") +
  geom_hline(yintercept = 0, colour = "grey80") +
  annotate("text", x = bnd$info, y = bnd$efficacy + 0.3, colour = "#1D4F91", size = 4.6,
           label = sprintf("Z >= %.2f", bnd$efficacy)) +
  annotate("text", x = 0.52, y = 1.2, hjust = 0, colour = "grey30", size = 4.6,
           label = "continue (unless conditional power is very low)") +
  annotate("text", x = 0.75, y = qnorm(1 - DESIGN$alpha) - 0.18, hjust = 0.5, colour = "grey40",
           size = 4, label = "fixed design: 1.960") +
  scale_x_continuous("Information fraction (events observed / events planned)",
                     limits = c(0.45, 1.05), breaks = DESIGN$info_rates) +
  scale_y_continuous("Log-rank Z (positive favours High Dose)", limits = c(-0.5, 3.6)) +
  theme_minimal(base_size = 16)

## ---- design-power ----
# Step 4. Power analysis: power of this design (same boundaries) for a given
# number of events and true HR. Information for the log-rank test ~ events / 4.
gs_power <- function(events, hr) {
  x <- gsProbability(k = 3, theta = -log(hr) / 2, n.I = events * DESIGN$info_rates,
                     a = rep(-20, 3), b = gs$upper$bound)
  sum(x$upper$prob)                           # P(cross an efficacy boundary)
}
power_curve <- expand_grid(hr = c(0.5, 0.6, 0.7, 0.8), events = seq(10, 700, by = 5)) %>%
  mutate(power = map2_dbl(events, hr, gs_power))

power_tbl <- tibble(`True HR` = c(0.5, 0.6, 0.7, 0.8)) %>%
  mutate(`Median PFS, High Dose (months)` = round(DESIGN$median_control / `True HR`, 1),
         `Power with planned events` = sprintf("%.0f%%", 100 * map_dbl(`True HR`, ~ gs_power(target_events, .x))),
         `Events for 80% power` = map_dbl(`True HR`, ~ ceiling(nEvents(hr = .x, alpha = DESIGN$alpha,
                                                                       beta = DESIGN$beta) * inflation)))

p_power <- ggplot(power_curve, aes(events, power, colour = factor(hr))) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 1 - DESIGN$beta, linetype = "dotted", colour = "grey40") +
  geom_vline(xintercept = target_events, linetype = "dashed", colour = "grey40") +
  annotate("text", x = target_events + 8, y = 0.08, hjust = 0, size = 4.4, colour = "grey30",
           label = sprintf("planned: %d events", target_events)) +
  scale_colour_manual("True HR", values = c("0.5" = "#0B2C5C", "0.6" = "#1D4F91",
                                            "0.7" = "#75AADB", "0.8" = "#B03A2E")) +
  scale_y_continuous("Power", labels = scales::percent, breaks = seq(0, 1, 0.2)) +
  scale_x_continuous("Total PFS events at the final analysis") +
  theme_minimal(base_size = 16) +
  theme(legend.position = "bottom")

## ---- design-save ----
ggsave(lab_path("output", "figures", "f_design_boundaries.png"), p_boundary,
       width = 8, height = 4.5, dpi = 150, bg = "white")
ggsave(lab_path("output", "figures", "f_design_power.png"), p_power,
       width = 8, height = 4.5, dpi = 150, bg = "white")
save_rtf(gt(boundary_tbl), "t_design_boundaries")
