# =============================================================================
# 04_adam_adsl.R  (ADaM: subject-level analysis dataset, ADSL)
#
# pharmaverseadam::adsl was produced by the {admiral} ADSL template from the
# CDISC pilot SDTM. Our SAP needs a few more variables, so we extend it the
# same way a study programmer would: one admiral derivation per SAP rule.
#   ITTFL / EFFFL      analysis-set flags, from SUPPDM (supplemental qualifiers)
#   DCSREAS            reason for discontinuation from study, from DS
#   HEIGHTBL, WEIGHTBL, BMIBL   baseline body measurements, from VS
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
  # reason for discontinuation from study
  derive_vars_merged(
    dataset_add = ds,
    by_vars     = exprs(STUDYID, USUBJID),
    filter_add  = DSCAT == "DISPOSITION EVENT" & !DSDECOD %in% c("COMPLETED", "SCREEN FAILURE"),
    new_vars    = exprs(DCSREAS = DSDECOD)
  ) %>%
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

## ---- adsl-check ----
# Sanity checks a statistician should always look at
adsl_check <- adsl %>%
  count(TRT01P, ITTFL, SAFFL, EFFFL, name = "Subjects")

## ---- adsl-write ----
write_raw(adsl, "adsl", dir = "adam")
