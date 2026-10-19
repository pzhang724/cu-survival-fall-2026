# =============================================================================
# 08_tfl_safety.R  (TFLs: adverse events and laboratory data, safety set)
#
# Safety analyses use the safety set by treatment ACTUALLY received (TRT01A).
# TEAE = treatment-emergent adverse event: starts on/after the first dose
# (admiral flag TRTEMFL in ADAE). Lab toxicity grades follow the US National Cancer Institute's CTCAE
# (Common Terminology Criteria for Adverse Events), derived in ADLB by admiral.
# Tables: {rtables} + {tern}, with a Total column.
# =============================================================================
source(here::here("lab", "R", "00_setup.R"))
need("adsl", "04_adam_adsl.R")

adsl_saf <- adsl %>%
  filter(SAFFL == "Y") %>%
  mutate(TRT01A = factor(TRT01A, levels = ARM_LEVELS))

## ---- saf-teae ----
adae_te <- read_source("adae") %>%
  filter(SAFFL == "Y", TRTEMFL == "Y") %>%
  mutate(TRT01A = factor(TRT01A, levels = ARM_LEVELS))

## ---- saf-overview ----
# One row per patient with yes/no flags; percentages over the safety set
severity <- c("MILD", "MODERATE", "SEVERE")
ae_patients <- adae_te %>%
  group_by(USUBJID) %>%
  summarise(
    ANY    = TRUE,
    MAXSEV = severity[max(match(ASEV, severity), na.rm = TRUE)],   # worst severity
    REL    = any(AREL %in% c("POSSIBLE", "PROBABLE")),
    SER    = any(AESER == "Y"),
    DTH    = any(AESDTH == "Y"),
    .groups = "drop"
  )
ae_overview <- adsl_saf %>%
  select(USUBJID, TRT01A, DCTREAS) %>%
  left_join(ae_patients, by = "USUBJID") %>%
  mutate(across(c(ANY, REL, SER, DTH), ~ coalesce(.x, FALSE)),
         DISC   = DCTREAS %in% "ADVERSE EVENT",
         MAXSEV = factor(str_to_sentence(MAXSEV), levels = str_to_sentence(severity)))

lyt_ae_overview <- basic_table(
  title = "Table 14.3.1 Overview of treatment-emergent adverse events (safety set)",
  main_footer = "TEAE: starts on or after the first dose and up to 30 days after the last dose.",
  show_colcounts = TRUE
) %>%
  split_cols_by("TRT01A") %>%
  add_overall_col("Total") %>%
  count_patients_with_flags("USUBJID", flag_variables = c(ANY = "Patients with any TEAE"),
                            denom = "N_col", table_names = "any", .formats = n_pct) %>%
  analyze_vars("MAXSEV", .stats = "count_fraction", denom = "N_col", .formats = n_pct,
               var_labels = "By maximum severity", .indent_mods = 1L) %>%
  count_patients_with_flags("USUBJID", denom = "N_col", table_names = "other", .formats = n_pct,
                            flag_variables = c(REL  = "TEAE related to study drug (possible/probable)",
                                               SER  = "Serious TEAE",
                                               DTH  = "TEAE leading to death",
                                               DISC = "Discontinued treatment because of an AE"))

t_14_3_1 <- build_table(lyt_ae_overview, df = ae_overview)

## ---- saf-soc-pt ----
# Patients counted once per system organ class (SOC) and preferred term (PT);
# sorted by descending frequency; PTs reported by at least 10% of all patients.
lyt_soc_pt <- basic_table(
  title = "Table 14.3.2 TEAEs reported by at least 10% of patients, by SOC and PT (safety set)",
  show_colcounts = TRUE
) %>%
  split_cols_by("TRT01A") %>%
  add_overall_col("Total") %>%
  analyze_num_patients("USUBJID", .stats = "unique",
                       .labels = c(unique = "Patients with at least one TEAE")) %>%
  split_rows_by("AEBODSYS", split_fun = drop_split_levels, split_label = "System organ class",
                label_pos = "topleft", child_labels = "visible") %>%
  summarize_num_patients("USUBJID", .stats = "unique", .labels = c(unique = "Patients with a TEAE in this SOC")) %>%
  count_occurrences("AEDECOD", .indent_mods = -1L)

t_14_3_2 <- adae_te %>%
  mutate(AEBODSYS = str_to_sentence(AEBODSYS), AEDECOD = str_to_sentence(AEDECOD)) %>%
  build_table(lyt_soc_pt, df = ., alt_counts_df = adsl_saf) %>%
  prune_table(keep_rows(has_fraction_in_cols(atleast = 0.10, col_names = "Total"))) %>%
  sort_at_path("AEBODSYS", scorefun = cont_n_allcols) %>%
  sort_at_path(c("AEBODSYS", "*", "AEDECOD"), scorefun = score_occurrences)

## ---- saf-lab-shift ----
# Shift from baseline CTCAE grade to the worst grade on treatment
lab_params <- c("ALT", "AST", "BILI", "ALKPH", "CREAT")
lb_worst <- read_source("adlb") %>%
  filter(SAFFL == "Y", PARAMCD %in% lab_params, ONTRTFL == "Y", ANL01FL == "Y",
         is.na(DTYPE), !is.na(ATOXGR)) %>%
  group_by(USUBJID, TRT01A, PARAMCD, PARAM, BTOXGR) %>%
  summarise(WORST = max(as.integer(ATOXGR)), .groups = "drop") %>%
  mutate(
    TRT01A   = factor(TRT01A, levels = ARM_LEVELS),
    PARAM    = factor(PARAM, levels = unique(PARAM[order(match(PARAMCD, lab_params))])),
    Baseline = factor(paste("Baseline grade", coalesce(BTOXGR, "missing"))),
    WORST    = droplevels(factor(paste("Grade", WORST), levels = paste("Grade", 0:4)))
  )

lyt_shift <- basic_table(
  title = "Table 14.3.3 Shift from baseline to worst post-baseline CTCAE grade, liver and kidney tests (safety set)",
  main_footer = "Number of patients. CTCAE: Common Terminology Criteria for Adverse Events (v4) of the US National Cancer Institute, derived by admiral in ADLB."
) %>%
  split_cols_by("TRT01A", split_fun = add_overall_level("Total", first = FALSE)) %>%
  split_cols_by("WORST") %>%
  split_rows_by("PARAM", split_fun = drop_split_levels, label_pos = "hidden") %>%
  count_occurrences("Baseline", .stats = "count", show_labels = "hidden")

t_14_3_3 <- build_table(lyt_shift, df = lb_worst)

## ---- saf-save ----
save_rtf(t_14_3_1, "t_14_3_1_ae_overview")
save_rtf(t_14_3_2, "t_14_3_2_ae_soc_pt")
save_rtf(t_14_3_3, "t_14_3_3_lab_shift")
