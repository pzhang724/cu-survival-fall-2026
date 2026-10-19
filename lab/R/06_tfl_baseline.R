# =============================================================================
# 06_tfl_baseline.R  (TFLs: disposition, demographics, concomitant medications)
#
# Tables are built with {rtables} (a layout says which columns, rows and
# analyses; build_table() applies it to the data) and {tern} (ready-made
# analysis functions for clinical tables). Every table has a Total column.
# Table numbering follows ICH E3 (structure of a clinical study report):
#   14.1.x  disposition and baseline   14.2.x efficacy   14.3.x safety
# Populations (SAP section 4):
#   ITT (intention-to-treat) set: all randomized patients, by randomized arm
#   Safety set: all patients who received study drug, by treatment received
# =============================================================================
source(here::here("lab", "R", "00_setup.R"))
need("adsl", "04_adam_adsl.R")

## ---- tfl-populations ----
adsl_itt <- adsl %>%
  filter(ITTFL == "Y") %>%
  mutate(TRT01P = factor(TRT01P, levels = ARM_LEVELS))
adsl_saf <- adsl %>%
  filter(SAFFL == "Y") %>%
  mutate(TRT01A = factor(TRT01A, levels = ARM_LEVELS))

## ---- tfl-disposition ----
# Screening counts have no arm (screen failures are never randomized),
# so they appear in the Total column only.
a_screening <- function(df, .spl_context) {
  total <- function(x) rcell(if (in_col(.spl_context, "Total")) x else NULL, format = "xx")
  in_rows("Patients screened" = total(nrow(adsl)),
          "Screen failures"   = total(sum(adsl$TRT01P == "Screen Failure")))
}

disp <- adsl_itt %>%
  mutate(DCTREAS = factor(str_to_sentence(DCTREAS)),
         DCSREAS = factor(str_to_sentence(DCSREAS)))

lyt_disp <- basic_table(
  title = "Table 14.1.1 Patient disposition (all screened patients)",
  main_footer = "Percentages use the number of randomized patients (N).",
  show_colcounts = TRUE
) %>%
  split_cols_by("TRT01P") %>%
  add_overall_col("Total") %>%
  analyze("USUBJID", afun = a_screening, show_labels = "hidden", table_names = "screening") %>%
  count_values("ITTFL", values = "Y", table_names = "itt", .formats = n_pct,
               .labels = c(count_fraction = "Randomized (ITT set)")) %>%
  count_values("SAFFL", values = "Y", table_names = "saf", .formats = n_pct,
               .labels = c(count_fraction = "Received study drug (safety set)")) %>%
  count_values("EOTSTT", values = "DISCONTINUED", table_names = "eot", .formats = n_pct,
               .labels = c(count_fraction = "Discontinued study treatment")) %>%
  analyze_vars("DCTREAS", .stats = "count_fraction", denom = "N_col", .formats = n_pct,
               show_labels = "hidden", table_names = "eot_reason", .indent_mods = 1L) %>%
  count_values("EOSSTT", values = "DISCONTINUED", table_names = "eos", .formats = n_pct,
               .labels = c(count_fraction = "Discontinued study")) %>%
  analyze_vars("DCSREAS", .stats = "count_fraction", denom = "N_col", .formats = n_pct,
               show_labels = "hidden", table_names = "eos_reason", .indent_mods = 1L)

t_14_1_1 <- build_table(lyt_disp, df = disp)

## ---- tfl-demographics ----
# Display labels for coded values come from the same CT spec used for SDTM mapping
study_ct <- read_raw("study_ct", dir = "spec")
ct_label <- function(x) coalesce(study_ct$collected_value[match(x, study_ct$term_value)], x)

demo <- adsl_itt %>%
  mutate(
    AGEGR1 = factor(AGEGR1, levels = c("18-64", ">64")),
    SEX    = factor(ct_label(SEX), levels = c("Female", "Male")),
    RACE   = factor(ct_label(RACE)),
    ETHNIC = factor(ct_label(ETHNIC))
  )
demo_labels <- c(AGE = "Age (years)", AGEGR1 = "Age group (years)", SEX = "Sex",
                 RACE = "Race", ETHNIC = "Ethnicity", HEIGHTBL = "Height (cm)",
                 WEIGHTBL = "Weight (kg)", BMIBL = "Body mass index (kg/m2)")

lyt_demo <- function(vars) {
  basic_table(title = "Table 14.1.2 Demographic and baseline characteristics (ITT set)",
              show_colcounts = TRUE) %>%
    split_cols_by("TRT01P") %>%
    add_overall_col("Total") %>%
    analyze_vars(vars, var_labels = demo_labels[vars],
                 .stats = c("n", "mean_sd", "median", "range", "count_fraction"))
}
t_14_1_2 <- build_table(lyt_demo(names(demo_labels)), df = demo)

## ---- tfl-conmed ----
# Concomitant medications: taken on or after first dose (ONTRTFL = "Y"),
# by ATC class and preferred name (WHODrug), safety set by treatment received.
# Most pilot medications were never coded (CMDECOD = "UNCODED"): we show the
# verbatim name under "Not yet coded", which is what a dry-run table looks like
# before the coding team finishes. Coding must be complete before database lock.
adcm_con <- pharmaverseadam::adcm %>%
  filter(ONTRTFL == "Y") %>%
  select(-TRT01A) %>%
  inner_join(select(adsl_saf, USUBJID, TRT01A), by = "USUBJID") %>%   # our two arms
  mutate(
    CMCLAS  = if_else(CMCLAS == "UNCODED", "Not yet coded (verbatim name shown)", str_to_sentence(CMCLAS)),
    CMDECOD = if_else(CMDECOD == "UNCODED", str_to_sentence(CMTRT), str_to_sentence(CMDECOD))
  )

lyt_cm <- basic_table(
  title = "Table 14.1.3 Concomitant medications reported by at least 5% of patients (safety set)",
  show_colcounts = TRUE
) %>%
  split_cols_by("TRT01A") %>%
  add_overall_col("Total") %>%
  analyze_num_patients("USUBJID", .stats = "unique",
                       .labels = c(unique = "Patients with at least one concomitant medication")) %>%
  split_rows_by("CMCLAS", split_fun = drop_split_levels, split_label = "ATC class",
                label_pos = "topleft") %>%
  count_occurrences("CMDECOD", .indent_mods = 1L)

t_14_1_3 <- build_table(lyt_cm, df = adcm_con, alt_counts_df = adsl_saf) %>%
  prune_table(keep_rows(has_fraction_in_cols(atleast = 0.05, col_names = "Total"))) %>%
  sort_at_path(c("CMCLAS", "*", "CMDECOD"), scorefun = score_occurrences)

## ---- tfl-baseline-save ----
save_rtf(t_14_1_1, "t_14_1_1_disposition")
save_rtf(t_14_1_2, "t_14_1_2_demographics")
save_rtf(t_14_1_3, "t_14_1_3_conmed")
