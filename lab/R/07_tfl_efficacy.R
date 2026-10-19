# =============================================================================
# 07_tfl_efficacy.R  (TFLs: primary and secondary efficacy, final analysis)
#
# Primary:        PFS, High Dose vs Placebo, log-rank test (one-sided alpha
#                 2.5%, group sequential boundary), Cox hazard ratio,
#                 Kaplan-Meier medians
# Key secondary:  overall survival (OS)
# Secondary:      objective response rate (ORR), disease control rate (DCR)
# Multiplicity:   fixed-sequence (gatekeeping) testing PFS -> OS -> ORR -> DCR,
#                 SAP section 9
# Tables: {rtables} + {tern}, with a Total column.
# =============================================================================
source(here::here("lab", "R", "00_setup.R"))
need("adtte_ia", "05_adam_adrs_adtte.R")

## ---- eff-data ----
tte <- adtte %>%
  mutate(TRT01P   = factor(TRT01P, levels = ARM_LEVELS),
         AVAL_M   = AVAL / DAYS_PER_MONTH,                 # days -> months
         is_event = CNSR == 0,
         EVENT    = if_else(is_event, "Y", "N"),
         EVENT_TYPE = factor(if_else(is_event, EVNTDESC, NA_character_),
                             levels = c("Disease progression", "Death")))
pfs <- filter(tte, PARAMCD == "PFS")
os  <- filter(tte, PARAMCD == "OS") %>% mutate(EVENT_TYPE = droplevels(EVENT_TYPE))

## ---- eff-compare ----
# Two-arm comparison: log-rank test and Cox proportional-hazards HR.
# The log-rank chi-square has 1 degree of freedom; Z = +sqrt(chi-square) when
# the experimental arm has fewer events than expected (favours the drug),
# which gives the one-sided p-value for H1: HR < 1.
compare_arms <- function(data, experimental, control = CONTROL) {
  d <- data %>%
    filter(TRT01P %in% c(control, experimental)) %>%
    mutate(ARM = factor(TRT01P, levels = c(control, experimental)))
  lr  <- survdiff(Surv(AVAL_M, 1 - CNSR) ~ ARM, data = d)
  z   <- (lr$exp[2] - lr$obs[2]) / sqrt(lr$var[2, 2])
  # The HR is not estimable (NE) when an arm has no events
  hr_ci <- c(NA_real_, NA_real_, NA_real_)
  if (all(lr$obs > 0)) {
    cox   <- coxph(Surv(AVAL_M, 1 - CNSR) ~ ARM, data = d, ties = "efron")
    hr_ci <- exp(c(coef(cox), confint(cox)))
  }
  tibble(
    experimental, control,
    events = sum(d$CNSR == 0),
    hr = hr_ci[1], hr_lower = hr_ci[2], hr_upper = hr_ci[3],
    chisq = lr$chisq,
    p_chisq = pchisq(lr$chisq, df = 1, lower.tail = FALSE),   # two-sided
    z = z,
    p_one_sided = pnorm(z, lower.tail = FALSE)                # H1: HR < 1
  )
}

pfs_hi <- compare_arms(pfs, EXPERIMENTAL)   # primary hypothesis
os_hi  <- compare_arms(os, EXPERIMENTAL)    # key secondary

## ---- eff-logrank-by-hand ----
# The log-rank statistic: observed minus expected events on one arm, summed
# over event times. Chi-square = (O - E)^2 / V, with 1 degree of freedom.
lr <- survdiff(Surv(AVAL_M, 1 - CNSR) ~ TRT01P, data = pfs)
logrank_parts <- tibble(
  Arm = str_remove(names(lr$n), "TRT01P="),
  Patients = as.integer(lr$n),
  `Observed events (O)` = lr$obs,
  `Expected events (E)` = round(lr$exp, 1),
  `O - E` = round(lr$obs - lr$exp, 1)
)
logrank_var <- lr$var[2, 2]   # variance V of O - E (same for both arms)

## ---- eff-final-boundary ----
# The final boundary uses the ACTUAL information: alpha spent at the two
# interim analyses (at their actual event counts) and the actual final events.
ia_events_obs <- map_int(adtte_ia, ~ sum(.x$PARAMCD == "PFS" & .x$CNSR == 0))
bounds_actual <- gsDesign(k = 3, test.type = 1, alpha = DESIGN$alpha, sfu = sfLDOF,
                          n.I = c(ia_events_obs, pfs_hi$events), maxn.IPlan = target_events)
z_final <- bounds_actual$upper$bound[3]

## ---- eff-tte-layout ----
# One layout for every time-to-event table: PFS (14.2.1), OS (14.2.3) and the
# interim PFS table for the DMC (IA.1). Comparison rows appear in the
# High Dose column only (not in the Placebo or Total columns).
a_compare <- function(df, .spl_context, .ref_group = NULL, .in_ref_col = FALSE) {
  show <- !.in_ref_col && !in_col(.spl_context, "Total")
  cmp  <- if (show) compare_arms(bind_rows(.ref_group, df), EXPERIMENTAL)
  cell <- function(x, format) rcell(if (show) x else NULL, format = format, format_na_str = "NE")
  in_rows(
    "Hazard ratio vs Placebo (95% CI)" = cell(c(cmp$hr, cmp$hr_lower, cmp$hr_upper), "xx.xx (xx.xx - xx.xx)"),
    "Log-rank chi-square (1 df)"       = cell(cmp$chisq, "xx.xxx"),
    "One-sided p-value (log-rank)"     = cell(cmp$p_one_sided, "xx.xxxx")
  )
}

lyt_tte <- function(title, footer = character()) {
  basic_table(title = title, main_footer = footer, show_colcounts = TRUE) %>%
    split_cols_by("TRT01P", ref_group = CONTROL) %>%
    add_overall_col("Total") %>%
    count_values("EVENT", values = "Y", table_names = "events", .formats = n_pct,
                 .labels = c(count_fraction = "Patients with event")) %>%
    analyze_vars("EVENT_TYPE", .stats = "count_fraction", denom = "N_col", .formats = n_pct,
                 show_labels = "hidden", .indent_mods = 1L) %>%
    count_values("EVENT", values = "N", table_names = "censored", .formats = n_pct,
                 .labels = c(count_fraction = "Censored")) %>%
    surv_time("AVAL_M", is_event = "is_event", .stats = "median_ci_3d",
              control = control_surv_time(conf_type = "log-log"),       # Brookmeyer-Crowley
              .labels = c(median_ci_3d = "Median, months (95% CI)"), show_labels = "hidden") %>%
    surv_timepoint("AVAL_M", is_event = "is_event", time_point = 3, method = "surv",
                   var_labels = "Months", .stats = "event_free_rate_3d",
                   control = control_surv_timepoint(conf_type = "log-log"),
                   .formats = c(event_free_rate_3d = "xx.x (xx.x - xx.x)"),
                   .labels = c(event_free_rate_3d = "Event-free rate, % (95% CI)")) %>%
    analyze("AVAL_M", afun = a_compare, show_labels = "hidden", table_names = "compare")
}

## ---- eff-pfs-table ----
t_14_2_1 <- build_table(
  lyt_tte("Table 14.2.1 Progression-free survival by investigator (ITT set)",
          c("Median and rate: Kaplan-Meier, 95% CI with log-log transformation. HR: unstratified Cox model (Efron ties).",
            sprintf("Primary hypothesis H0: HR = 1 vs H1: HR < 1, rejected if Z >= %.3f (Lan-DeMets O'Brien-Fleming spending; %s events at the interims, %d at the final).",
                    z_final, paste(ia_events_obs, collapse = " and "), pfs_hi$events))),
  df = pfs
)

## ---- eff-km-plot ----
arm_colours <- c("Placebo" = "#7F7F7F", "Xanomeline High Dose" = "#1D4F91")
km_plot <- function(data, cmp, title, ylab) {
  survfit2(Surv(AVAL_M, 1 - CNSR) ~ TRT01P, data = data) %>%
    ggsurvfit(linewidth = 0.9) +
    add_censor_mark(size = 2, alpha = 0.6) +
    add_risktable(risktable_stats = "n.risk", size = 4.5,
                  theme = theme_risktable_default(axis.text.y.size = 13, plot.title.size = 14)) +
    scale_color_manual(values = arm_colours) +
    scale_x_continuous(breaks = 0:8) +
    scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
    annotate("text", x = Inf, y = 0.7, hjust = 1.05, size = 4.8,
             label = paste("High Dose vs Placebo",
                           if (is.na(cmp$hr)) "HR not estimable" else
                             sprintf("HR %.2f (95%% CI %.2f, %.2f)", cmp$hr, cmp$hr_lower, cmp$hr_upper),
                           sprintf("one-sided log-rank p = %.3f", cmp$p_one_sided), sep = "\n")) +
    labs(x = "Months since randomization", y = ylab, title = title) +
    theme(legend.position = "bottom", plot.title = element_text(size = 15),
          axis.text = element_text(size = 13), axis.title = element_text(size = 15),
          legend.text = element_text(size = 14))
}
p_km_pfs <- km_plot(pfs, pfs_hi, "Figure 14.2.1 Kaplan-Meier plot of progression-free survival (ITT set)",
                    "Progression-free survival")

## ---- eff-sensitivity ----
# Sensitivity analysis (SAP section 6.3): PFS by blinded independent central
# review (BICR). Same ADaM programs, same table layout, different reads.
pfs_bicr <- adtte_bicr %>%
  mutate(TRT01P   = factor(TRT01P, levels = ARM_LEVELS),
         AVAL_M   = AVAL / DAYS_PER_MONTH,
         is_event = CNSR == 0,
         EVENT    = if_else(is_event, "Y", "N"),
         EVENT_TYPE = factor(if_else(is_event, EVNTDESC, NA_character_),
                             levels = c("Disease progression", "Death")))
pfs_bicr_hi <- compare_arms(pfs_bicr, EXPERIMENTAL)
t_14_2_4 <- build_table(
  lyt_tte("Table 14.2.4 Sensitivity analysis: progression-free survival by BICR (ITT set)",
          "BICR: blinded independent central review, the adjudicated read of two independent radiologists."),
  df = pfs_bicr
)

## ---- eff-os ----
# Key secondary endpoint: overall survival. Few deaths in a 6-month study.
t_14_2_3 <- build_table(
  lyt_tte("Table 14.2.3 Overall survival (ITT set)",
          "Median and rate: Kaplan-Meier, 95% CI with log-log transformation. HR: unstratified Cox model (Efron ties)."),
  df = os
)
p_km_os <- km_plot(os, os_hi, "Figure 14.2.2 Kaplan-Meier plot of overall survival (ITT set)",
                   "Overall survival")
os_deaths <- sum(os$is_event)

## ---- eff-orr ----
# Best overall response (RECIST 1.1, investigator; confirmation not required
# in a randomized trial). ORR = CR or PR; DCR = CR, PR, SD or non-CR/non-PD.
bor_levels <- c(CR = "Complete response (CR)", PR = "Partial response (PR)",
                SD = "Stable disease (SD)", `NON-CR/NON-PD` = "Non-CR/non-PD",
                PD = "Progressive disease (PD)", NE = "Not evaluable (NE)",
                MISSING = "No post-baseline assessment")
bor <- adrs %>%
  filter(PARAMCD == "BOR", ITTFL == "Y") %>%
  mutate(TRT01P = factor(TRT01P, levels = ARM_LEVELS),
         BOR = factor(bor_levels[AVALC], levels = bor_levels),
         ORR = AVALC %in% c("CR", "PR"),
         DCR = AVALC %in% c("CR", "PR", "SD", "NON-CR/NON-PD"))

# Difference in rates vs Placebo: High Dose column only
a_rate_diff <- function(df, .var, .spl_context, .ref_group = NULL, .in_ref_col = FALSE) {
  show <- !.in_ref_col && !in_col(.spl_context, "Total")
  d <- if (show) s_proportion_diff(df, .var, .ref_group, .in_ref_col, method = "wald")
  p <- if (show) s_test_proportion_diff(df, .var, .ref_group, .in_ref_col, method = "chisq")
  in_rows(
    "Difference vs Placebo, % (95% CI)" = rcell(if (show) c(d$diff, d$diff_ci), format = "xx.x (xx.x - xx.x)"),
    "Two-sided p-value (chi-square)"   = rcell(if (show) p$pval, format = "xx.xxxx"),
    .indent_mods = c(1L, 1L)
  )
}

lyt_rsp <- basic_table(
  title = "Table 14.2.2 Best overall response, ORR and DCR (ITT set)",
  main_footer = "RECIST 1.1, investigator assessment. Rate CI: Clopper-Pearson. Difference CI: Wald.",
  show_colcounts = TRUE
) %>%
  split_cols_by("TRT01P", ref_group = CONTROL) %>%
  add_overall_col("Total") %>%
  analyze_vars("BOR", .stats = "count_fraction", .formats = n_pct, show_labels = "hidden") %>%
  estimate_proportion("ORR", method = "clopper-pearson", table_names = "orr",
                      .labels = c(n_prop = "ORR (CR + PR)", prop_ci = "95% CI")) %>%
  analyze("ORR", afun = a_rate_diff, show_labels = "hidden", table_names = "orr_diff") %>%
  estimate_proportion("DCR", method = "clopper-pearson", table_names = "dcr",
                      .labels = c(n_prop = "DCR (CR + PR + SD + non-CR/non-PD)", prop_ci = "95% CI")) %>%
  analyze("DCR", afun = a_rate_diff, show_labels = "hidden", table_names = "dcr_diff")

t_14_2_2 <- build_table(lyt_rsp, df = bor)

## ---- eff-hierarchy ----
# Fixed-sequence (gatekeeping) testing. The order is fixed in the SAP before
# unblinding. Each hypothesis is tested at the full one-sided 2.5% only if all
# earlier ones were rejected; the first failure stops the chain.
rate_test <- function(var) {
  s_test_proportion_diff(filter(bor, TRT01P == EXPERIMENTAL), var,
                         filter(bor, TRT01P == CONTROL), FALSE, method = "chisq")$pval
}
fmt_hr <- function(hr) if (is.na(hr)) "NE" else sprintf("%.2f", hr)
rate_diff <- function(var) 100 * (mean(bor[[var]][bor$TRT01P == EXPERIMENTAL]) -
                                  mean(bor[[var]][bor$TRT01P == CONTROL]))
hier_tbl <- tibble(
  Step = 1:4,
  Hypothesis = c("PFS (primary)", "OS (key secondary)", "ORR", "DCR"),
  Result = c(sprintf("HR %s, Z = %.2f", fmt_hr(pfs_hi$hr), pfs_hi$z),
             sprintf("HR %s, Z = %.2f", fmt_hr(os_hi$hr), os_hi$z),
             sprintf("difference %.1f%%, two-sided p = %.3f", rate_diff("ORR"), rate_test("ORR")),
             sprintf("difference %.1f%%, two-sided p = %.3f", rate_diff("DCR"), rate_test("DCR"))),
  passed = c(pfs_hi$z >= z_final, os_hi$p_one_sided <= DESIGN$alpha,
             rate_diff("ORR") > 0 & rate_test("ORR") <= 2 * DESIGN$alpha,
             rate_diff("DCR") > 0 & rate_test("DCR") <= 2 * DESIGN$alpha)
) %>%
  mutate(
    tested   = c(TRUE, head(cumprod(passed), -1) == 1),   # tested only if all earlier passed
    Decision = case_when(!tested ~ "Not tested (descriptive only)",
                         passed  ~ "Reject H0: go to the next step",
                         TRUE    ~ "Not rejected: STOP")
  ) %>%
  select(Step, Hypothesis, Result, Decision)

## ---- eff-review ----
# Progression is a judgement. rs_onco has three reads of every scan: the
# investigator and two independent radiologists. When the radiologists
# disagree, an adjudicator accepts one read (RSACPTFL = "Y"): the blinded
# independent central review (BICR) result.
reads <- pharmaversesdtm::rs_onco %>%
  filter(RSTESTCD == "OVRLRESP") %>%
  semi_join(adsl, by = c("STUDYID", "USUBJID")) %>%
  mutate(Reader = case_when(RSEVAL == "INVESTIGATOR" ~ "Investigator",
                            RSACPTFL == "Y" ~ "BICR (accepted read)",
                            TRUE ~ "BICR (other reader)"))

# First progression per patient and reader
first_pd <- reads %>%
  filter(Reader != "BICR (other reader)") %>%
  group_by(USUBJID, Reader) %>%
  summarise(pd_visit = if (any(RSSTRESC == "PD")) min(VISITNUM[RSSTRESC == "PD"]) else NA_real_,
            .groups = "drop") %>%
  tidyr::pivot_wider(names_from = Reader, values_from = pd_visit)

review_tbl <- first_pd %>%
  mutate(Agreement = case_when(
    is.na(Investigator) & is.na(`BICR (accepted read)`) ~ "No progression by either",
    Investigator == `BICR (accepted read)`              ~ "Progression at the same visit",
    is.na(Investigator) | is.na(`BICR (accepted read)`) ~ "Progression by one review only",
    TRUE                                                ~ "Progression at different visits")) %>%
  count(`Investigator vs BICR` = factor(Agreement, levels = c(
    "Progression at the same visit", "No progression by either",
    "Progression at different visits", "Progression by one review only")),
    name = "Patients")

# Two radiologists, one scan schedule: how often do the two independent reads differ?
reader_disagree <- reads %>%
  filter(RSEVAL == "INDEPENDENT ASSESSOR") %>%
  group_by(USUBJID, VISITNUM) %>%
  summarise(differ = n_distinct(RSSTRESC) > 1, .groups = "drop") %>%
  summarise(visits = n(), differ = sum(differ))

## ---- eff-save ----
save_rtf(t_14_2_1, "t_14_2_1_pfs")
save_rtf(t_14_2_2, "t_14_2_2_orr")
save_rtf(t_14_2_3, "t_14_2_3_os")
save_rtf(t_14_2_4, "t_14_2_4_pfs_bicr")
ggsave(lab_path("output", "figures", "f_14_2_1_km_pfs.png"), p_km_pfs,
       width = 9, height = 6, dpi = 150, bg = "white")
ggsave(lab_path("output", "figures", "f_14_2_2_km_os.png"), p_km_os,
       width = 9, height = 6, dpi = 150, bg = "white")
