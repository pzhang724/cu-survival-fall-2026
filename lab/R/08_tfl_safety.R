# =============================================================================
# 08_tfl_safety.R  (TFLs: adverse events and laboratory data, safety set)
#
# Safety analyses use the safety set by treatment ACTUALLY received (TRT01A).
# TEAE = treatment-emergent adverse event: starts on/after the first dose
# (admiral flag TRTEMFL in ADAE). Lab toxicity grades follow NCI CTCAE
# (Common Terminology Criteria for Adverse Events), derived in ADLB by admiral.
# =============================================================================
source(here::here("lab", "R", "00_setup.R"))
need("adsl", "04_adam_adsl.R")

adsl_saf <- adsl %>%
  filter(SAFFL == "Y") %>%
  mutate(TRT01A = factor(TRT01A, levels = ARM_LEVELS))

## ---- saf-teae ----
adae_te <- pharmaverseadam::adae %>%
  filter(SAFFL == "Y", TRTEMFL == "Y") %>%
  mutate(TRT01A = factor(TRT01A, levels = ARM_LEVELS))

## ---- saf-overview ----
# One row per patient with yes/no flags; percentages over the safety set
ae_flags <- adae_te %>%
  group_by(USUBJID) %>%
  summarise(
    ANY = TRUE,
    REL = any(AREL %in% c("POSSIBLE", "PROBABLE")),
    SEV = any(ASEV == "SEVERE"),
    SER = any(AESER == "Y"),
    DTH = any(AESDTH == "Y"),
    .groups = "drop"
  )

t_14_3_1 <- adsl_saf %>%
  select(USUBJID, TRT01A, DCSREAS) %>%
  left_join(ae_flags, by = "USUBJID") %>%
  mutate(across(c(ANY, REL, SEV, SER, DTH), ~ coalesce(.x, FALSE)),
         DISC = DCSREAS %in% "ADVERSE EVENT") %>%
  tbl_summary(
    by = TRT01A, include = c(ANY, REL, SEV, SER, DTH, DISC),
    label = list(ANY ~ "Any TEAE", REL ~ "TEAE related to study drug (possible/probable)",
                 SEV ~ "Severe TEAE", SER ~ "Serious TEAE", DTH ~ "TEAE leading to death",
                 DISC ~ "Discontinued study because of an AE"),
    statistic = all_dichotomous() ~ "{n} ({p}%)"
  ) %>%
  modify_header(label ~ "**Patients with**") %>%
  modify_caption("**Table 14.3.1** Overview of treatment-emergent adverse events (safety set)")

## ---- saf-soc-pt ----
# Patients counted once per system organ class (SOC) and preferred term (PT);
# sorted by descending frequency; PTs reported by at least 10% of all patients.
t_14_3_2 <- adae_te %>%
  mutate(AEBODSYS = str_to_sentence(AEBODSYS), AEDECOD = str_to_sentence(AEDECOD)) %>%
  tbl_hierarchical(
    variables = c(AEBODSYS, AEDECOD), by = TRT01A, id = USUBJID,
    denominator = adsl_saf, overall_row = TRUE,
    label = list(..ard_hierarchical_overall.. = "Patients with at least one TEAE",
                 AEBODSYS = "System organ class", AEDECOD = "Preferred term")
  ) %>%
  sort_hierarchical() %>%
  filter_hierarchical(sum(n) / sum(N) >= 0.10) %>%
  modify_caption("**Table 14.3.2** TEAEs reported by at least 10% of patients, by SOC and PT (safety set)")

## ---- saf-lab-shift ----
# Shift from baseline CTCAE grade to the worst grade on treatment
lab_params <- c("ALT", "AST", "BILI", "ALKPH", "CREAT")
lb_worst <- pharmaverseadam::adlb %>%
  filter(SAFFL == "Y", PARAMCD %in% lab_params, ONTRTFL == "Y", ANL01FL == "Y",
         is.na(DTYPE), !is.na(ATOXGR)) %>%
  group_by(USUBJID, TRT01A, PARAMCD, PARAM, BTOXGR) %>%
  summarise(WORST = max(as.integer(ATOXGR)), .groups = "drop") %>%
  mutate(
    TRT01A = factor(TRT01A, levels = ARM_LEVELS),
    PARAM  = factor(PARAM, levels = unique(PARAM[order(match(PARAMCD, lab_params))])),
    Baseline = paste("Baseline grade", coalesce(BTOXGR, "missing")),
    WORST = factor(paste("Grade", WORST), levels = paste("Grade", 0:4))
  )

shift_tbl <- lb_worst %>%
  count(PARAM, Baseline, TRT01A, WORST, .drop = FALSE) %>%
  filter(!(n == 0 & !grepl("Grade [0-2]", WORST))) %>%        # keep grades 0-2 plus any observed 3-4
  group_by(PARAM, Baseline) %>% filter(sum(n) > 0) %>% ungroup() %>%
  arrange(TRT01A, WORST) %>%                                   # column order: arm, then grade
  mutate(col = paste(TRT01A, WORST, sep = "|")) %>%
  select(PARAM, Baseline, col, n) %>%
  tidyr::pivot_wider(names_from = col, values_from = n, values_fill = 0) %>%
  arrange(PARAM, Baseline)

make_shift_gt <- function(data) {
  data %>%
    gt(groupname_col = "PARAM", rowname_col = "Baseline") %>%
    tab_spanner_delim(delim = "|") %>%
    tab_header(title = md("**Table 14.3.3** Shift from baseline to worst post-baseline CTCAE grade, liver and kidney tests (safety set)")) %>%
    tab_footnote("Number of patients. CTCAE = NCI Common Terminology Criteria for Adverse Events (v4), as derived by admiral in ADLB.")
}
t_14_3_3 <- make_shift_gt(shift_tbl)

## ---- saf-save ----
save_rtf(t_14_3_1, "t_14_3_1_ae_overview")
save_rtf(t_14_3_2, "t_14_3_2_ae_soc_pt")
save_rtf(t_14_3_3, "t_14_3_3_lab_shift")
