# =============================================================================
# 05_adam_adrs_adtte.R  (ADaM: tumour response ADRS and time-to-event ADTTE)
#
# Source: pharmaversesdtm::rs_onco (RECIST 1.1 overall response by visit,
# investigator and independent review) + our ADSL.
#
# Why not pharmaverseadam::adtte_onco? It is built from a small RECIST example
# (8 patients with tumour assessments, 6 PFS events) - too few for a log-rank
# test. rs_onco has investigator assessments for 205 patients.
#
# Both derivations are FUNCTIONS of a data cut-off date. The interim
# analysis (09_interim.R) calls the very same code with an earlier cut-off date:
# one program, many data cuts.
# =============================================================================
source(here::here("lab", "R", "00_setup.R"))
need("target_events", "01_design.R")
need("adsl", "04_adam_adsl.R")

rs <- pharmaversesdtm::rs_onco

## ---- adam-datacut ----
# Apply a data cut-off date to ADSL: only patients randomized by the cut-off,
# and nothing that happened after it.
cut_adsl <- function(adsl, dco = NULL) {
  if (is.null(dco)) return(adsl)
  adsl %>%
    filter(!is.na(RANDDT), RANDDT <= dco) %>%
    mutate(
      DTHDT    = if_else(!is.na(DTHDT) & DTHDT <= dco, DTHDT, as.Date(NA)),
      DTHFL    = if_else(!is.na(DTHDT), "Y", NA_character_),
      LSTALVDT = pmin(LSTALVDT, dco, na.rm = TRUE)   # alive at cut-off if seen later
    )
}

## ---- adrs-derive ----
derive_adrs <- function(adsl, rs, dco = NULL) {
  rs <- convert_blanks_to_na(rs)
  if (!is.null(dco)) rs <- filter(rs, ymd(substr(RSDTC, 1, 10)) <= dco)

  # Overall response by visit, investigator assessment (SAP: primary analysis)
  ovr <- rs %>%
    filter(RSEVAL == "INVESTIGATOR", RSTESTCD == "OVRLRESP") %>%
    derive_vars_merged(dataset_add = adsl, new_vars = exprs(RANDDT), by_vars = exprs(STUDYID, USUBJID)) %>%
    derive_vars_dt(dtc = RSDTC, new_vars_prefix = "A") %>%
    mutate(PARAMCD = "OVR", PARAM = "Overall Response by Investigator",
           AVISIT = VISIT, AVALC = RSSTRESC, AVAL = aval_resp(AVALC)) %>%
    # analysis records: valid response on/after randomization, up to first PD
    restrict_derivation(
      derivation = derive_var_extreme_flag,
      args = params(by_vars = exprs(STUDYID, USUBJID, ADT), order = exprs(AVAL, RSSEQ),
                    new_var = ANL01FL, mode = "first"),
      filter = !is.na(AVAL) & ADT >= RANDDT
    ) %>%
    derive_var_relative_flag(
      by_vars = exprs(STUDYID, USUBJID), order = exprs(ADT, RSSEQ), new_var = ANL02FL,
      condition = AVALC == "PD", mode = "first", selection = "before", inclusive = TRUE
    )

  ovr_anl <- filter(ovr, ANL01FL == "Y", ANL02FL == "Y")
  bor_missing <- event(description = "No post-baseline assessment", dataset_name = "adsl",
                       condition = TRUE, set_values_to = exprs(AVALC = "MISSING"),
                       keep_source_vars = exprs(RANDDT))

  ovr %>%
    # PD: first progression (Y/N for every randomized patient)
    derive_extreme_records(
      dataset_ref = adsl, dataset_add = ovr_anl, by_vars = exprs(STUDYID, USUBJID),
      filter_add = AVALC == "PD", order = exprs(ADT, RSSEQ), mode = "first",
      exist_flag = AVALC, false_value = "N",
      set_values_to = exprs(PARAMCD = "PD", PARAM = "Disease Progression by Investigator",
                            AVAL = yn_to_numeric(AVALC), ANL01FL = "Y")
    ) %>%
    # BOR: best overall response (RECIST 1.1, confirmation not required)
    derive_extreme_event(
      by_vars = exprs(STUDYID, USUBJID), order = exprs(event_nr, ADT),
      tmp_event_nr_var = event_nr, mode = "first",
      source_datasets = list(ovr = ovr_anl, adsl = adsl),
      events = list(bor_cr, bor_pr, bor_sd, bor_non_crpd, bor_pd, bor_ne, bor_missing),
      set_values_to = exprs(PARAMCD = "BOR", PARAM = "Best Overall Response by Investigator",
                            AVAL = aval_resp(AVALC), ANL01FL = "Y")
    ) %>%
    # LSTA: last adequate tumour assessment (used for PFS censoring)
    derive_extreme_records(
      dataset_ref = adsl, dataset_add = ovr_anl, by_vars = exprs(STUDYID, USUBJID),
      filter_add = AVALC != "NE", order = exprs(ADT, RSSEQ), mode = "last",
      set_values_to = exprs(PARAMCD = "LSTA", PARAM = "Last Adequate Tumor Assessment by Investigator",
                            ANL01FL = "Y")
    ) %>%
    derive_var_obs_number(by_vars = exprs(STUDYID, USUBJID),
                          order = exprs(PARAMCD, ADT, VISITNUM, RSSEQ), check_type = "none") %>%
    derive_vars_merged(dataset_add = select(adsl, STUDYID, USUBJID, TRT01P, TRT01A, ITTFL, SAFFL),
                       by_vars = exprs(STUDYID, USUBJID))
}

## ---- adtte-sources ----
# Each SAP censoring rule becomes one admiral source object.
# PFS event: first documented progression (RECIST 1.1) ...
pfs_progression <- event_source(
  dataset_name = "adrs",
  filter = PARAMCD == "PD" & AVALC == "Y" & ANL01FL == "Y",
  date = ADT,
  set_values_to = exprs(EVNTDESC = "Disease progression",
                        SRCDOM = "ADRS", SRCVAR = "ADT", SRCSEQ = ASEQ)
)
# ... or death from any cause, whichever comes first
any_death <- event_source(
  dataset_name = "adsl", filter = !is.na(DTHDT), date = DTHDT,
  set_values_to = exprs(EVNTDESC = "Death", SRCDOM = "ADSL", SRCVAR = "DTHDT")
)
## ---- adtte-censor ----
# No event: censor at the last adequate tumour assessment ...
cens_last_assessment <- censor_source(
  dataset_name = "adrs", filter = PARAMCD == "LSTA" & ANL01FL == "Y", date = ADT,
  set_values_to = exprs(EVNTDESC = "Last adequate tumor assessment", CNSDTDSC = "Last adequate tumor assessment",
                        SRCDOM = "ADRS", SRCVAR = "ADT", SRCSEQ = ASEQ)
)
# ... or at randomization if there is no post-baseline assessment
# (admiral takes the LATEST of the censoring dates available for a patient)
cens_randomization <- censor_source(
  dataset_name = "adsl", date = RANDDT,
  set_values_to = exprs(EVNTDESC = "No post-baseline tumor assessment", CNSDTDSC = "Randomization",
                        SRCDOM = "ADSL", SRCVAR = "RANDDT")
)
# OS: death; otherwise censor at the last date known alive (or randomization)
cens_last_alive <- censor_source(
  dataset_name = "adsl", date = LSTALVDT,
  set_values_to = exprs(EVNTDESC = "Last known alive", CNSDTDSC = "Last known alive date",
                        SRCDOM = "ADSL", SRCVAR = "LSTALVDT")
)
cens_randomization_os <- censor_source(
  dataset_name = "adsl", date = RANDDT,
  set_values_to = exprs(EVNTDESC = "No contact after randomization", CNSDTDSC = "Randomization",
                        SRCDOM = "ADSL", SRCVAR = "RANDDT")
)

## ---- adtte-derive ----
derive_adtte <- function(adsl, adrs) {
  adsl_itt <- filter(adsl, ITTFL == "Y")
  sources  <- list(adsl = adsl_itt, adrs = adrs)

  derive_param_tte(
    dataset_adsl = adsl_itt, start_date = RANDDT, source_datasets = sources,
    event_conditions  = list(pfs_progression, any_death),
    censor_conditions = list(cens_last_assessment, cens_randomization),
    set_values_to = exprs(PARAMCD = "PFS", PARAM = "Progression-Free Survival (days)")
  ) %>%
    derive_param_tte(
      dataset_adsl = adsl_itt, start_date = RANDDT, source_datasets = sources,
      event_conditions  = list(any_death),
      censor_conditions = list(cens_last_alive, cens_randomization_os),
      set_values_to = exprs(PARAMCD = "OS", PARAM = "Overall Survival (days)")
    ) %>%
    derive_vars_duration(new_var = AVAL, start_date = STARTDT, end_date = ADT) %>%  # days, day 1 = randomization
    mutate(AVALU = "DAYS") %>%
    derive_var_obs_number(by_vars = exprs(STUDYID, USUBJID), order = exprs(PARAMCD), check_type = "error") %>%
    derive_vars_merged(dataset_add = select(adsl, STUDYID, USUBJID, TRT01P, TRT01A, ITTFL, SAFFL, AGE, SEX),
                       by_vars = exprs(STUDYID, USUBJID))
}

## ---- adtte-final ----
# Final analysis: all data (database lock)
adrs  <- derive_adrs(adsl, rs)
adtte <- derive_adtte(adsl, adrs)

adtte_check <- adtte %>%
  count(PARAMCD, TRT01P, CNSR, EVNTDESC, name = "Patients")

## ---- adtte-interim ----
# Interim analysis trigger (protocol): 50% of the 122 target PFS events in the
# primary comparison (High Dose vs Placebo). Cut-off = date the 61st event occurred.
# In a live trial this date is forecast from blinded event counts.
ia_dco <- adtte %>%
  filter(PARAMCD == "PFS", CNSR == 0, TRT01P %in% c(CONTROL, EXPERIMENTAL)) %>%
  arrange(ADT) %>%
  slice(ia_events) %>%
  pull(ADT)

adsl_ia  <- cut_adsl(adsl, dco = ia_dco)
adrs_ia  <- derive_adrs(adsl_ia, rs, dco = ia_dco)
adtte_ia <- derive_adtte(adsl_ia, adrs_ia)

## ---- adam-write ----
write_raw(adrs, "adrs", dir = "adam")
write_raw(adtte, "adtte", dir = "adam")
write_raw(adtte_ia, "adtte_ia", dir = "adam")
