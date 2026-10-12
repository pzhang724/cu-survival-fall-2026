# =============================================================================
# 06_tfl_baseline.R  (TFLs: disposition, demographics, concomitant medications)
#
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
disp <- adsl_itt %>%
  mutate(
    TREATED      = SAFFL == "Y",
    COMPLETED    = EOSSTT == "COMPLETED",
    DISCONTINUED = EOSSTT == "DISCONTINUED",
    DCSREAS      = str_to_sentence(DCSREAS)
  )

t_disp_status <- disp %>%
  tbl_summary(
    by = TRT01P, include = c(TREATED, COMPLETED, DISCONTINUED),
    label = list(TREATED ~ "Received study drug", COMPLETED ~ "Completed study",
                 DISCONTINUED ~ "Discontinued study"),
    statistic = all_dichotomous() ~ "{n} ({p}%)"
  )
# reasons: percentages use ALL randomized patients as denominator
t_disp_reason <- disp %>%
  filter(DISCONTINUED) %>%
  tbl_hierarchical(
    variables = DCSREAS, by = TRT01P, id = USUBJID, denominator = disp,
    label = list(DCSREAS = "Reason for discontinuation")
  )

t_14_1_1 <- tbl_stack(list(t_disp_status, t_disp_reason), quiet = TRUE) %>%
  modify_header(label ~ "**Randomized patients (ITT set)**") %>%
  modify_caption("**Table 14.1.1** Patient disposition (ITT set)")

## ---- tfl-demographics ----
# Display labels for coded values come from the same CT spec used for SDTM mapping
study_ct <- read_raw("study_ct", dir = "spec")
ct_label <- function(x) coalesce(study_ct$collected_value[match(x, study_ct$term_value)], x)

t_14_1_2 <- adsl_itt %>%
  mutate(
    AGEGR1 = factor(AGEGR1, levels = c("18-64", ">64")),
    SEX    = factor(ct_label(SEX), levels = c("Female", "Male")),
    RACE   = ct_label(RACE),
    ETHNIC = ct_label(ETHNIC)
  ) %>%
  tbl_summary(
    by = TRT01P,
    include = c(AGE, AGEGR1, SEX, RACE, ETHNIC, HEIGHTBL, WEIGHTBL, BMIBL),
    type = all_continuous() ~ "continuous2",
    statistic = all_continuous() ~ c("{N_nonmiss}", "{mean} ({sd})", "{median}", "{min}, {max}"),
    digits = all_continuous() ~ list(N_nonmiss = 0, mean = 1, sd = 2, median = 1, min = 1, max = 1),
    label = list(AGE ~ "Age (years)", AGEGR1 ~ "Age group (years)", SEX ~ "Sex",
                 RACE ~ "Race", ETHNIC ~ "Ethnicity", HEIGHTBL ~ "Height (cm)",
                 WEIGHTBL ~ "Weight (kg)", BMIBL ~ "Body mass index (kg/m^2)"),
    missing = "no"
  ) %>%
  add_overall(last = TRUE) %>%
  modify_caption("**Table 14.1.2** Demographic and baseline characteristics (ITT set)")

## ---- tfl-conmed ----
# Concomitant medications: taken on or after first dose (ONTRTFL = "Y"),
# summarised by ATC class and preferred name (WHODrug), safety set.
# Most pilot medications were never coded (CMDECOD = "UNCODED"): we show the
# verbatim name under "Not yet coded", which is what a dry-run table looks like
# before the coding team finishes. Coding must be complete before database lock.
adcm_con <- pharmaverseadam::adcm %>%
  filter(SAFFL == "Y", ONTRTFL == "Y") %>%
  mutate(
    TRT01A  = factor(TRT01A, levels = ARM_LEVELS),
    CMCLAS  = if_else(CMCLAS == "UNCODED", "Not yet coded (verbatim name shown)", str_to_sentence(CMCLAS)),
    CMDECOD = if_else(CMDECOD == "UNCODED", str_to_sentence(CMTRT), str_to_sentence(CMDECOD))
  )

t_14_1_3 <- adcm_con %>%
  tbl_hierarchical(
    variables = c(CMCLAS, CMDECOD), by = TRT01A, id = USUBJID,
    denominator = adsl_saf, overall_row = TRUE,
    label = list(..ard_hierarchical_overall.. = "Patients with at least one concomitant medication",
                 CMCLAS = "ATC class", CMDECOD = "Preferred name")
  ) %>%
  sort_hierarchical() %>%
  filter_hierarchical(sum(n) / sum(N) >= 0.05) %>%   # preferred names in >= 5% overall
  modify_caption("**Table 14.1.3** Concomitant medications reported by at least 5% of patients (safety set)")

## ---- tfl-baseline-save ----
save_rtf(t_14_1_1, "t_14_1_1_disposition")
save_rtf(t_14_1_2, "t_14_1_2_demographics")
save_rtf(t_14_1_3, "t_14_1_3_conmed")
