# =============================================================================
# 04_adam_adsl.R  (ADaM: subject-level analysis dataset, ADSL)
#
# pharmaverseadam::adsl was produced by the {admiral} ADSL template from the
# CDISC pilot SDTM. Our SAP needs a few more variables, so we extend it the
# same way a study programmer would: one admiral derivation per SAP rule.
#   ITTFL / EFFFL      analysis-set flags, from SUPPDM (supplemental qualifiers)
#   HEIGHTBL, WEIGHTBL, BMIBL   baseline body measurements, from VS
#   EOTSTT / DCTREAS   end of treatment status and reason, from DS
#   EOSSTT / DCSREAS   end of study status and reason, from DS
# Then we keep the two arms of OUR trial: High Dose vs Placebo.
# =============================================================================
source(here::here("lab", "R", "00_setup.R"))

dm     <- pharmaversesdtm::dm
suppdm <- pharmaversesdtm::suppdm
ds     <- pharmaversesdtm::ds
vs     <- pharmaversesdtm::vs

## ---- adsl-derive ----
# SUPPDM holds the analysis-set flags as supplemental qualifiers: join them back
dm_supp <- metatools::combine_supp(dm, suppdm) %>%
  select(STUDYID, USUBJID, ITTFL = ITT, EFFFL = EFFICACY)

adsl <- pharmaverseadam::adsl %>%
  # analysis sets (SAP section 4)
  derive_vars_merged(dataset_add = dm_supp, by_vars = exprs(STUDYID, USUBJID)) %>%
  mutate(ITTFL = coalesce(ITTFL, "N"), EFFFL = coalesce(EFFFL, "N")) %>%
  # baseline height (screening) and weight (baseline flag), then BMI
  derive_vars_merged(
    dataset_add = vs, by_vars = exprs(STUDYID, USUBJID),
    filter_add  = VSTESTCD == "HEIGHT" & !is.na(VSSTRESN),
    order = exprs(VSDTC), mode = "first",
    new_vars    = exprs(HEIGHTBL = VSSTRESN)
  ) %>%
  derive_vars_merged(
    dataset_add = vs, by_vars = exprs(STUDYID, USUBJID),
    filter_add  = VSTESTCD == "WEIGHT" & VSBLFL == "Y",
    new_vars    = exprs(WEIGHTBL = VSSTRESN)
  ) %>%
  mutate(BMIBL = round(compute_bmi(height = HEIGHTBL, weight = WEIGHTBL), 1))

## ---- adsl-disposition ----
# The pilot records one disposition event per patient: the end of study
# treatment (completed, or the reason for stopping). A patient who stopped
# treatment early could still come back for the final "retrieval" visit and
# so stay in the study.
adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ds, by_vars = exprs(STUDYID, USUBJID),
    filter_add  = DSCAT == "DISPOSITION EVENT" & DSDECOD != "SCREEN FAILURE",
    new_vars    = exprs(DSEOT = DSDECOD)
  ) %>%
  derive_var_merged_exist_flag(
    dataset_add = ds, by_vars = exprs(STUDYID, USUBJID),
    new_var = RETFL, condition = DSDECOD == "FINAL RETRIEVAL VISIT"
  ) %>%
  mutate(
    EOTSTT  = case_when(DSEOT == "COMPLETED" ~ "COMPLETED", !is.na(DSEOT) ~ "DISCONTINUED"),
    DCTREAS = if_else(EOTSTT == "DISCONTINUED", DSEOT, NA_character_),
    EOSSTT  = case_when(EOTSTT == "DISCONTINUED" & is.na(RETFL) ~ "DISCONTINUED",
                        !is.na(EOTSTT) ~ "COMPLETED"),
    DCSREAS = if_else(EOSSTT == "DISCONTINUED", DCTREAS, NA_character_)
  ) %>%
  select(-DSEOT)

## ---- adsl-two-arm ----
# Our trial has two arms: High Dose vs Placebo. The pilot study also randomized
# a Low Dose arm; those patients are left out of the analysis datasets.
# 12 High Dose patients stopped during the 54 mg start and never reached 81 mg.
# They started the High Dose regimen, so they stay High Dose for safety (TRT01A).
adsl <- adsl %>%
  filter(TRT01P != "Xanomeline Low Dose") %>%
  mutate(TRT01A = if_else(SAFFL == "Y" & TRT01P == EXPERIMENTAL, EXPERIMENTAL, TRT01A))

## ---- adsl-check ----
# Sanity checks a statistician should always look at
adsl_check <- adsl %>%
  count(TRT01P, ITTFL, SAFFL, EFFFL, name = "Subjects")

## ---- adsl-write ----
write_raw(adsl, "adsl", dir = "adam")
