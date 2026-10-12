# =============================================================================
# 07_tfl_efficacy.R  (TFLs: primary and secondary efficacy, final analysis)
#
# Primary:   PFS, High Dose vs Placebo, log-rank test (one-sided alpha 2.5%,
#            group sequential boundary), Cox hazard ratio, Kaplan-Meier medians
# Secondary: PFS Low Dose vs Placebo, objective response rate (ORR), OS
# Multiplicity: fixed-sequence (hierarchical) testing, SAP section 9
# =============================================================================
source(here::here("lab", "R", "00_setup.R"))
need("adtte_ia", "05_adam_adrs_adtte.R")

## ---- eff-data ----
tte <- adtte %>%
  mutate(TRT01P = factor(TRT01P, levels = ARM_LEVELS),
         AVAL_M = AVAL / DAYS_PER_MONTH)                 # days -> months
pfs <- filter(tte, PARAMCD == "PFS")
os  <- filter(tte, PARAMCD == "OS")

## ---- eff-km ----
# Kaplan-Meier with log-log confidence intervals for the median
# (Brookmeyer-Crowley). R's default is conf.type = "log"; SAS PROC LIFETEST
# uses log-log: state the method in the SAP or the two will not match.
km_pfs <- survfit(Surv(AVAL_M, 1 - CNSR) ~ TRT01P, data = pfs, conf.type = "log-log")

## ---- eff-compare ----
# Two-arm comparison: log-rank Z (positive = fewer events than expected on the
# experimental arm, i.e. favours it) and Cox proportional-hazards HR.
compare_arms <- function(data, experimental, control = CONTROL) {
  d <- data %>%
    filter(TRT01P %in% c(control, experimental)) %>%
    mutate(ARM = factor(TRT01P, levels = c(control, experimental)))
  lr  <- survdiff(Surv(AVAL_M, 1 - CNSR) ~ ARM, data = d)
  z   <- (lr$exp[2] - lr$obs[2]) / sqrt(lr$var[2, 2])
  cox <- coxph(Surv(AVAL_M, 1 - CNSR) ~ ARM, data = d)
  tibble(
    experimental, control,
    events = sum(d$CNSR == 0),
    hr = exp(coef(cox)), hr_lower = exp(confint(cox))[1], hr_upper = exp(confint(cox))[2],
    z = z,
    p_one_sided = pnorm(z, lower.tail = FALSE),   # H1: HR < 1
    p_two_sided = 2 * pnorm(-abs(z))
  )
}

pfs_hi <- compare_arms(pfs, "Xanomeline High Dose")   # primary hypothesis
pfs_lo <- compare_arms(pfs, "Xanomeline Low Dose")    # next in the hierarchy

## ---- eff-logrank-by-hand ----
# The log-rank statistic is observed minus expected events on one arm,
# summed over event times, divided by the square root of its variance.
lr <- survdiff(Surv(AVAL_M, 1 - CNSR) ~ TRT01P,
               data = droplevels(filter(pfs, TRT01P %in% c(CONTROL, EXPERIMENTAL))))
logrank_parts <- tibble(
  Arm = str_remove(names(lr$n), "TRT01P="),
  Patients = as.integer(lr$n),
  `Observed events (O)` = lr$obs,
  `Expected events (E)` = round(lr$exp, 1),
  `O - E` = round(lr$obs - lr$exp, 1)
)
logrank_var <- lr$var[2, 2]   # variance of O - E (same for both arms)

## ---- eff-software-defaults ----
# Same data, different defaults: tied event times (many patients progress at
# the same scheduled scan) and the CI for the median.
d_hi <- filter(pfs, TRT01P %in% c(CONTROL, EXPERIMENTAL)) %>%
  mutate(ARM = factor(TRT01P, levels = c(CONTROL, EXPERIMENTAL)))
hr_ties <- function(ties) exp(coef(coxph(Surv(AVAL_M, 1 - CNSR) ~ ARM, data = d_hi, ties = ties)))
rate_3m_ci <- function(type) {
  s <- summary(survfit(Surv(AVAL_M, 1 - CNSR) ~ 1, data = filter(d_hi, ARM == CONTROL),
                       conf.type = type), times = 3)
  sprintf("%.1f%% (%.1f, %.1f)", 100 * s$surv, 100 * s$lower, 100 * s$upper)
}
defaults_tbl <- tibble(
  Quantity = c("Cox HR, ties = Efron", "Cox HR, ties = Breslow",
               "Placebo 3-month PFS rate, CI conf.type = \"log\"",
               "Placebo 3-month PFS rate, CI conf.type = \"log-log\""),
  `R default?` = c("yes (coxph)", "no", "yes (survfit)", "no"),
  `SAS default?` = c("no", "yes (PROC PHREG)", "no", "yes (PROC LIFETEST)"),
  Value = c(sprintf("%.4f", hr_ties("efron")), sprintf("%.4f", hr_ties("breslow")),
            rate_3m_ci("log"), rate_3m_ci("log-log"))
)

## ---- eff-final-boundary ----
# The final boundary uses the ACTUAL information: alpha already spent at the
# interim (61 events) and the actual final number of events.
ia_events_obs <- adtte_ia %>%
  filter(PARAMCD == "PFS", CNSR == 0, TRT01P %in% c(CONTROL, EXPERIMENTAL)) %>% nrow()
alpha_spent_ia <- getDesignGroupSequential(
  kMax = 2, alpha = DESIGN$alpha, typeOfDesign = "asOF",
  informationRates = c(ia_events_obs / target_events, 1))$alphaSpent[1]
design_final <- getDesignGroupSequential(
  kMax = 2, alpha = DESIGN$alpha, typeOfDesign = "asUser",
  userAlphaSpending = c(alpha_spent_ia, DESIGN$alpha),
  informationRates  = c(ia_events_obs / pfs_hi$events, 1))
z_final <- design_final$criticalValues[2]

## ---- eff-pfs-table ----
fmt_ci <- function(est, lo, hi, d = 1) {
  f <- function(x) ifelse(is.na(x), "NE", formatC(x, format = "f", digits = d))
  paste0(f(est), " (", f(lo), ", ", f(hi), ")")
}
n_pct <- function(n, N) sprintf("%d (%.1f%%)", n, 100 * n / N)

km_tbl  <- summary(km_pfs)$table
km_3m   <- summary(km_pfs, times = 3, extend = TRUE)
pfs_by_arm <- pfs %>%
  group_by(TRT01P) %>%
  summarise(N = n(), events = sum(CNSR == 0),
            pd = sum(CNSR == 0 & EVNTDESC == "Disease progression"),
            death = sum(CNSR == 0 & EVNTDESC == "Death"),
            cens = sum(CNSR == 1), .groups = "drop")

t_14_2_1 <- tibble(
  Statistic = c("Patients", "Events, n (%)", "  Disease progression", "  Death",
                "Censored, n (%)", "Median PFS, months (95% CI)", "PFS rate at 3 months, % (95% CI)",
                "Hazard ratio vs Placebo (95% CI)", "Log-rank Z (positive favours drug)",
                "One-sided p-value (log-rank)")
) %>%
  bind_cols(map_dfc(seq_along(ARM_LEVELS), function(i) {
    a  <- pfs_by_arm[i, ]
    cmp <- switch(ARM_LEVELS[i], "Xanomeline High Dose" = pfs_hi, "Xanomeline Low Dose" = pfs_lo, NULL)
    col <- c(
      a$N, n_pct(a$events, a$N), n_pct(a$pd, a$N), n_pct(a$death, a$N), n_pct(a$cens, a$N),
      fmt_ci(km_tbl[i, "median"], km_tbl[i, "0.95LCL"], km_tbl[i, "0.95UCL"]),
      fmt_ci(100 * km_3m$surv[i], 100 * km_3m$lower[i], 100 * km_3m$upper[i]),
      if (is.null(cmp)) "Reference" else fmt_ci(cmp$hr, cmp$hr_lower, cmp$hr_upper, 2),
      if (is.null(cmp)) "" else sprintf("%.2f", cmp$z),
      if (is.null(cmp)) "" else sprintf("%.3f", cmp$p_one_sided)
    )
    setNames(tibble(as.character(col)), ARM_LEVELS[i])
  })) %>%
  gt() %>%
  tab_header(title = md("**Table 14.2.1** Progression-free survival by investigator (ITT set)")) %>%
  tab_footnote(sprintf(paste(
    "Kaplan-Meier estimates; 95%% CI by Brookmeyer-Crowley (log-log). HR from an unstratified Cox model.",
    "Primary hypothesis: High Dose vs Placebo, tested at the final analysis against Z >= %.3f",
    "(Lan-DeMets O'Brien-Fleming spending, %d events at the interim, %d at the final)."),
    z_final, ia_events_obs, pfs_hi$events))

## ---- eff-km-plot ----
arm_colours <- c("Placebo" = "#7F7F7F", "Xanomeline Low Dose" = "#75AADB", "Xanomeline High Dose" = "#1D4F91")
p_km_pfs <- survfit2(Surv(AVAL_M, 1 - CNSR) ~ TRT01P, data = pfs) %>%
  ggsurvfit(linewidth = 0.9) +
  add_censor_mark(size = 2, alpha = 0.6) +
  add_risktable(risktable_stats = "n.risk", size = 3.5,
                theme = theme_risktable_default(axis.text.y.size = 10, plot.title.size = 11)) +
  scale_color_manual(values = arm_colours) +
  scale_x_continuous(breaks = 0:6, limits = c(0, 6.1)) +
  scale_y_continuous(labels = scales::percent) +
  annotate("text", x = 6, y = 0.72, hjust = 1, size = 3.8,
           label = sprintf("High Dose vs Placebo: HR %.2f (95%% CI %.2f, %.2f); one-sided log-rank p = %.3f",
                           pfs_hi$hr, pfs_hi$hr_lower, pfs_hi$hr_upper, pfs_hi$p_one_sided)) +
  labs(x = "Months since randomization", y = "Progression-free survival",
       title = "Figure 14.2.1 Kaplan-Meier plot of progression-free survival (ITT set)") +
  theme(legend.position = "bottom", plot.title = element_text(size = 12))

## ---- eff-orr ----
# Objective response rate (ORR): best overall response of CR or PR (RECIST 1.1,
# confirmation not required in a randomized trial). Exact (Clopper-Pearson) CI.
bor <- adrs %>%
  filter(PARAMCD == "BOR", ITTFL == "Y") %>%
  mutate(TRT01P = factor(TRT01P, levels = ARM_LEVELS),
         RESP = AVALC %in% c("CR", "PR"))

orr <- bor %>%
  group_by(TRT01P) %>%
  summarise(N = n(), x = sum(RESP), .groups = "drop") %>%
  mutate(rate = x / N,
         lower = map2_dbl(x, N, ~ binom.test(.x, .y)$conf.int[1]),
         upper = map2_dbl(x, N, ~ binom.test(.x, .y)$conf.int[2]))

orr_diff <- function(experimental, control = CONTROL) {
  a <- filter(orr, TRT01P == experimental); b <- filter(orr, TRT01P == control)
  pt <- prop.test(c(a$x, b$x), c(a$N, b$N), correct = FALSE)   # Wald CI, chi-square p
  tibble(experimental, diff = a$rate - b$rate, lower = pt$conf.int[1], upper = pt$conf.int[2],
         p_two_sided = pt$p.value)
}
orr_cmp <- bind_rows(orr_diff("Xanomeline Low Dose"), orr_diff("Xanomeline High Dose"))

bor_levels <- c(CR = "Complete response (CR)", PR = "Partial response (PR)",
                SD = "Stable disease (SD)", `NON-CR/NON-PD` = "Non-CR/non-PD",
                PD = "Progressive disease (PD)", NE = "Not evaluable (NE)",
                MISSING = "No post-baseline assessment")

t_14_2_2 <- bor %>%
  mutate(BOR = factor(bor_levels[AVALC], levels = bor_levels)) %>%
  count(TRT01P, BOR, .drop = FALSE) %>%
  left_join(select(orr, TRT01P, N), by = "TRT01P") %>%
  mutate(value = n_pct(n, N)) %>%
  select(TRT01P, Statistic = BOR, value) %>%
  bind_rows(
    orr %>% transmute(TRT01P, Statistic = "ORR (CR + PR), n (%)", value = n_pct(x, N)),
    orr %>% transmute(TRT01P, Statistic = "  95% exact CI (Clopper-Pearson)",
                      value = sprintf("%.1f, %.1f", 100 * lower, 100 * upper)),
    orr_cmp %>% transmute(TRT01P = experimental, Statistic = "Difference vs Placebo, % (95% CI)",
                          value = fmt_ci(100 * diff, 100 * lower, 100 * upper)),
    orr_cmp %>% transmute(TRT01P = experimental, Statistic = "Two-sided p-value (chi-square, nominal)",
                          value = sprintf("%.3f", p_two_sided))
  ) %>%
  mutate(TRT01P = as.character(TRT01P)) %>%
  tidyr::pivot_wider(names_from = TRT01P, values_from = value, values_fill = "") %>%
  select(Statistic, all_of(ARM_LEVELS)) %>%
  gt() %>%
  tab_header(title = md("**Table 14.2.2** Best overall response and objective response rate (ITT set)")) %>%
  tab_footnote("RECIST 1.1, investigator assessment. Difference CI: Wald (normal approximation).")

## ---- eff-os ----
os_by_arm <- os %>%
  group_by(TRT01P) %>%
  summarise(Patients = n(), Deaths = sum(CNSR == 0), Censored = sum(CNSR == 1), .groups = "drop")

## ---- eff-hierarchy ----
# Fixed-sequence testing: each hypothesis is tested only if all previous ones
# were rejected; the full one-sided 2.5% alpha passes down the chain.
hier_tbl <- tibble(
  Step = 1:3,
  Hypothesis = c("PFS: High Dose vs Placebo", "PFS: Low Dose vs Placebo", "ORR: High Dose vs Placebo"),
  `Test statistic` = c(sprintf("Z = %.2f", pfs_hi$z), sprintf("Z = %.2f", pfs_lo$z),
                       sprintf("diff = %.1f%%", 100 * orr_cmp$diff[2])),
  Boundary = c(sprintf("Z >= %.3f", z_final), "same", "same"),
  Decision = c(if (pfs_hi$z >= z_final) "Reject H0" else "Do not reject H0",
               "Not tested (descriptive only)", "Not tested (descriptive only)")
)

## ---- eff-save ----
save_rtf(t_14_2_1, "t_14_2_1_pfs")
save_rtf(t_14_2_2, "t_14_2_2_orr")
ggsave(lab_path("output", "figures", "f_14_2_1_km_pfs.png"), p_km_pfs,
       width = 9, height = 6, dpi = 150, bg = "white")
