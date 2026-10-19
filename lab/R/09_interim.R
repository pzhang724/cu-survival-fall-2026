# =============================================================================
# 09_interim.R  (Interim analyses for the Data Monitoring Committee)
#
# Triggers: 50% and 75% of the planned PFS events, counted over both arms.
# The ADaM programs in 05 were re-run with each data cut-off date, giving
# adtte_ia[[1]] and adtte_ia[[2]]. Here we compute what goes into the DMC
# closed report: log-rank Z and p-value vs the efficacy boundary at the
# ACTUAL information, conditional power (CP), and the non-binding futility
# rule (consider stopping if CP under the current trend < 10%).
# In a real trial this is done by an independent statistician behind a
# firewall; the sponsor study team stays blinded.
# =============================================================================
source(here::here("lab", "R", "00_setup.R"))
need("compare_arms", "07_tfl_efficacy.R")

## ---- ia-data ----
pfs_ia <- map(adtte_ia, function(d) {
  d %>%
    filter(PARAMCD == "PFS") %>%
    mutate(TRT01P   = factor(TRT01P, levels = ARM_LEVELS),
           AVAL_M   = AVAL / DAYS_PER_MONTH,
           is_event = CNSR == 0,
           EVENT    = if_else(is_event, "Y", "N"),
           EVENT_TYPE = factor(if_else(is_event, EVNTDESC, NA_character_),
                               levels = c("Disease progression", "Death")))
})
looks <- map_dfr(pfs_ia, compare_arms, experimental = EXPERIMENTAL)   # same function as the final

## ---- ia-boundaries ----
# Lan-DeMets spending: each boundary uses the ACTUAL events at that look;
# later looks are still at their planned events.
bounds_at <- function(events) {
  gsDesign(k = 3, test.type = 1, alpha = DESIGN$alpha, sfu = sfLDOF,
           n.I = events, maxn.IPlan = target_events)
}
gs_ia1 <- bounds_at(c(looks$events[1], ia_events[2], target_events))
gs_ia2 <- bounds_at(c(looks$events, target_events))
z_eff  <- c(gs_ia1$upper$bound[1], gs_ia2$upper$bound[2])   # efficacy boundary at IA1, IA2

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

ia <- looks[1, ]                                     # interim analysis 1
theta_trend <- ia$z / sqrt(ia$events / 4)            # effect estimated from the interim Z
cp_tbl <- tibble(
  Assumption = c(sprintf("Design: HR = %.2f", DESIGN$hr),
                 sprintf("Current trend: HR = %.2f", exp(-theta_trend)),
                 "No effect: HR = 1"),
  theta = c(-log(DESIGN$hr), theta_trend, 0)
) %>%
  mutate(`Conditional power` = cond_power(ia$z, ia$events, target_events, theta,
                                          gs_ia1$upper$bound[3]))
cp_trend <- cp_tbl$`Conditional power`[2]

## ---- ia-gscp ----
# Cross-check with {gsDesign}: gsCP() also counts the chance to stop at IA2
cp_gs_design <- sum(gsCP(gs_ia1, i = 1, zi = ia$z, theta = -log(DESIGN$hr) / 2)$upper$prob)

## ---- ia-decisions ----
# Same rules at every look: efficacy if Z >= boundary; futility (non-binding)
# if CP under the current trend < 10%; otherwise continue.
look_cp <- map2_dbl(looks$z, looks$events, function(z, d) {
  cond_power(z, d, target_events, z / sqrt(d / 4), gs_ia2$upper$bound[3])
})
decide <- function(z, bound, cp) {
  case_when(z >= bound ~ "Efficacy boundary crossed: stop",
            cp < DESIGN$futility_cp ~ "Futility rule met (CP < 10%): consider stopping",
            TRUE ~ "Continue")
}
looks_tbl <- tibble(
  Analysis = c("Interim 1", "Interim 2", "Final"),
  `Cut-off date` = c(format(ia_dco), "all data"),
  Events = c(looks$events, pfs_hi$events),
  `Information fraction` = sprintf("%.0f%%", 100 * Events / target_events),
  `Efficacy boundary (Z)` = sprintf("%.3f", c(z_eff, z_final)),
  `Observed Z (HR)` = sprintf("%.2f (%.2f)", c(looks$z, pfs_hi$z), c(looks$hr, pfs_hi$hr)),
  `CP, current trend` = c(sprintf("%.1f%%", 100 * look_cp), ""),
  Decision = c(decide(looks$z, z_eff, look_cp),
               if (pfs_hi$z >= z_final) "Reject H0" else "Do not reject H0")
)

## ---- ia-report ----
# Table IA.1: the SAME layout as Table 14.2.1, run on the interim data cut
ia_footer <- c(
  sprintf("Data cut-off %s: %d of %d planned events (%.0f%%).", format(ia_dco[1]), ia$events,
          target_events, 100 * ia$events / target_events),
  sprintf("Efficacy boundary at this look: Z >= %.3f (one-sided p <= %.4f): %s.", z_eff[1],
          pnorm(-z_eff[1]), if (ia$z >= z_eff[1]) "crossed" else "not crossed"),
  sprintf("Conditional power: %.1f%% under the design HR %.2f, %.1f%% under the current trend (HR %.2f).",
          100 * cp_tbl$`Conditional power`[1], DESIGN$hr, 100 * cp_trend, exp(-theta_trend)),
  sprintf("Futility rule (non-binding, CP under the current trend < 10%%): %s.",
          if (cp_trend < DESIGN$futility_cp) "met" else "not met")
)
t_ia_1 <- build_table(
  lyt_tte("Table IA.1 Interim analysis 1 of progression-free survival (DMC closed report)", ia_footer),
  df = pfs_ia[[1]]
)

## ---- ia-boundary-plot ----
# Where did each look land relative to the boundaries?
obs <- tibble(info = c(looks$events, pfs_hi$events) / target_events, z = c(looks$z, pfs_hi$z),
              label = c("IA1", "IA2", "Final"))
p_ia_boundary <- p_boundary +
  geom_point(data = obs, aes(x = info, y = z), shape = 18, size = 6, colour = "#E07B00") +
  geom_text(data = obs, aes(x = info, y = z, label = sprintf("%s: Z = %.2f", label, z)),
            nudge_y = -0.35, colour = "#E07B00", size = 4.6)

## ---- ia-km ----
p_km_ia <- km_plot(pfs_ia[[1]], ia,
                   sprintf("Figure IA.1 PFS at interim 1 (cut-off %s)", format(ia_dco[1])),
                   "Progression-free survival")

## ---- ia-save ----
save_rtf(t_ia_1, "t_ia_1_interim_pfs")
ggsave(lab_path("output", "figures", "f_ia_1_km_pfs.png"), p_km_ia,
       width = 9, height = 6, dpi = 150, bg = "white")
