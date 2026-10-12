# =============================================================================
# 03_raw_to_sdtm.R  (Data standards: raw -> SDTM, then QC)
#
# Map the raw EDC/vendor data from 02_reverse_raw.R to SDTM following the
# SDTMIG, then check our result against pharmaversesdtm with {diffdf}
# (the R analogue of SAS PROC COMPARE). Domains mapped here: DM, AE, CM.
# VS, LB and RS are left as exercises (see lab/README.md).
#
# Production teams often use {sdtm.oak} (pharmaverse) for this step; plain
# dplyr is used here so every rule is visible.
# =============================================================================
source(here::here("lab", "R", "00_setup.R"))
if (!file.exists(lab_path("data", "raw", "ae.csv"))) source(lab_path("R", "02_reverse_raw.R"))

raw_dm    <- read_raw("dm")
raw_sites <- read_raw("sites")
raw_irt   <- read_raw("irt")
raw_ex    <- read_raw("ex")
raw_ds    <- read_raw("ds")
raw_ae    <- read_raw("ae")
raw_cm    <- read_raw("cm")
study_ct  <- read_raw("study_ct", dir = "spec")

## ---- sdtm-helpers ----
# CRF date text -> ISO 8601: "02 JAN 2014" -> "2014-01-02", "UN JAN 2014" -> "2014-01",
# "UN UNK 2014" -> "2014". Never impute in SDTM: partial dates stay partial.
crf_to_iso <- function(x, time = NULL) {
  p  <- str_split_fixed(x, " ", 3)
  mm <- sprintf("%02d", match(p[, 2], toupper(month.abb)))
  iso <- case_when(
    is.na(x)        ~ NA_character_,
    p[, 2] == "UNK" ~ p[, 3],
    p[, 1] == "UN"  ~ paste(p[, 3], mm, sep = "-"),
    TRUE            ~ paste(p[, 3], mm, p[, 1], sep = "-")
  )
  if (!is.null(time)) iso <- if_else(!is.na(time) & nchar(iso) == 10, paste0(iso, "T", time), iso)
  iso
}

## ---- sdtm-helpers-ct ----
# CRF display value -> CDISC submission value, using the study CT map
ct_encode <- function(x, codelist) {
  map <- filter(study_ct, .data$codelist == !!codelist)
  out <- map$term_value[match(x, map$collected_value)]
  if (any(!is.na(x) & is.na(out))) {
    warning("Unmapped values in codelist ", codelist, ": ",
            paste(unique(x[!is.na(x) & is.na(out)]), collapse = ", "))
  }
  out
}

## ---- sdtm-helpers-dy ----
# SDTMIG study day: no day 0. Day 1 = reference start date (RFSTDTC).
# Partial dates give NA (study day is only derived from complete dates).
study_day <- function(dtc, rfstdtc) {
  d <- suppressWarnings(ymd(substr(dtc, 1, 10)))
  r <- suppressWarnings(ymd(substr(rfstdtc, 1, 10)))
  ifelse(nchar(dtc) >= 10, as.numeric(d - r) + (d >= r), NA_real_)
}

## ---- sdtm-dm ----
# Reference dates come from exposure (first/last dose) and disposition (end of study).
ex_dates <- raw_ex %>%
  mutate(st = crf_to_iso(EXSTDAT), en = crf_to_iso(EXENDAT), dose = as.numeric(EXDOSE)) %>%
  group_by(SUBJECT) %>%
  summarise(RFXSTDTC = min(st),
            RFXENDTC = if (all(is.na(en))) NA_character_ else max(en, na.rm = TRUE),
            max_dose = max(dose), .groups = "drop")

eos <- raw_ds %>%
  filter(FORM == "End of Study") %>%
  transmute(SUBJECT, RFENDTC = crf_to_iso(DSSTDAT),
            DTHDTC = if_else(DSDECOD == "Death", crf_to_iso(DSSTDAT), NA_character_))

dm_sdtm <- raw_dm %>%
  left_join(raw_sites, by = "SITE") %>%
  left_join(raw_irt %>% select(SUBJECT, TREATMENT_CODE, TREATMENT_ARM), by = "SUBJECT") %>%
  left_join(ex_dates, by = "SUBJECT") %>%
  left_join(eos, by = "SUBJECT") %>%
  mutate(
    STUDYID  = STUDY,
    DOMAIN   = "DM",
    USUBJID  = paste0("01-", SUBJECT),
    SUBJID   = str_remove(SUBJECT, "^\\d+-"),
    SITEID   = SITE,
    RFSTDTC  = RFXSTDTC,                 # reference start = first dose
    BRTHDTC  = crf_to_iso(BRTHDAT),
    DMDTC    = crf_to_iso(DMDAT),
    AGE      = floor(time_length(interval(ymd(BRTHDTC), ymd(DMDTC)), "years")),
    AGEU     = "YEARS",
    SEX      = ct_encode(SEX, "SEX"),
    RACE     = ct_encode(RACE, "RACE"),
    ETHNIC   = ct_encode(ETHNIC, "ETHNIC"),
    DTHFL    = if_else(!is.na(DTHDTC), "Y", NA_character_),
    # planned arm = randomized arm from IRT; no randomization = screen failure
    ARMCD    = coalesce(TREATMENT_CODE, "Scrnfail"),
    ARM      = coalesce(TREATMENT_ARM, "Screen Failure"),
    ARMNRS   = if_else(is.na(TREATMENT_CODE), "SCREEN FAILURE", NA_character_),
    # actual arm = what was received: High Dose patients who never got 81 mg
    # (stopped during the titration period) actually received the Low Dose
    ACTARMCD = if_else(ARMCD == "Xan_Hi" & max_dose < 81, "Xan_Lo", ARMCD),
    ACTARM   = if_else(ARMCD == "Xan_Hi" & max_dose < 81, "Xanomeline Low Dose", ARM),
    DMDY     = study_day(DMDTC, RFSTDTC)
  )

## ---- sdtm-ae ----
ae_sdtm <- raw_ae %>%
  mutate(USUBJID = paste0("01-", SUBJECT)) %>%
  left_join(select(dm_sdtm, USUBJID, RFSTDTC), by = "USUBJID") %>%
  transmute(
    STUDYID = STUDY, DOMAIN = "AE", USUBJID,
    RECORDPOS = as.numeric(RECORDPOS),
    AESPID, AETERM,
    # MedDRA coding: the dictionary hierarchy, lowest level term up to system organ class
    AELLT = AETERM_LLT, AELLTCD = as.numeric(AETERM_LLT_CODE),
    AEDECOD = AETERM_PT, AEPTCD = as.numeric(AETERM_PT_CODE),
    AEHLT = AETERM_HLT, AEHLTCD = as.numeric(AETERM_HLT_CODE),
    AEHLGT = AETERM_HLGT, AEHLGTCD = as.numeric(AETERM_HLGT_CODE),
    AEBODSYS = AETERM_SOC, AEBDSYCD = as.numeric(AETERM_SOC_CODE),
    AESOC = AETERM_SOC, AESOCCD = as.numeric(AETERM_SOC_CODE),
    AESEV = ct_encode(AESEV, "AESEV"),
    AESER = ct_encode(AESER, "NY"),
    AEACN = NA_character_,                 # action taken was not collected in this study
    AEREL = ct_encode(AEREL, "AEREL"),
    AEOUT = ct_encode(AEOUT, "OUT"),
    across(c(AESCAN, AESCONG, AESDISAB, AESDTH, AESHOSP, AESLIFE, AESOD), ~ ct_encode(.x, "NY")),
    AEDTC   = crf_to_iso(RECORDDATE),
    AESTDTC = crf_to_iso(AESTDAT),
    AEENDTC = crf_to_iso(AEENDAT),
    AESTDY  = study_day(AESTDTC, RFSTDTC),
    AEENDY  = study_day(AEENDTC, RFSTDTC)
  ) %>%
  arrange(USUBJID, RECORDPOS) %>%
  group_by(USUBJID) %>%
  mutate(AESEQ = as.numeric(row_number())) %>%  # --SEQ: unique within subject
  ungroup() %>%
  select(STUDYID, DOMAIN, USUBJID, AESEQ, everything(), -RECORDPOS)

## ---- sdtm-cm ----
visit_schedule <- read_raw("visit_schedule", dir = "spec") %>%
  mutate(VISITNUM = as.numeric(VISITNUM), VISITDY = as.numeric(VISITDY))

cm_sdtm <- raw_cm %>%
  mutate(USUBJID = paste0("01-", SUBJECT)) %>%
  left_join(select(dm_sdtm, USUBJID, RFSTDTC), by = "USUBJID") %>%
  left_join(visit_schedule, by = c("FOLDER" = "VISIT")) %>%
  transmute(
    STUDYID = STUDY, DOMAIN = "CM", USUBJID,
    RECORDPOS = as.numeric(RECORDPOS),
    CMSPID, CMTRT,
    CMDECOD = CMTRT_PREFERRED_NAME,   # WHODrug preferred name
    CMINDC,
    CMCLAS = CMTRT_ATC_CLASS,         # WHODrug ATC class
    CMDOSE = as.numeric(CMDOSE), CMDOSU, CMDOSFRQ, CMROUTE,
    VISITNUM, VISIT = FOLDER, VISITDY,
    CMDTC   = crf_to_iso(RECORDDATE),
    CMSTDTC = crf_to_iso(CMSTDAT),
    CMENDTC = crf_to_iso(CMENDAT),
    CMSTDY  = study_day(CMSTDTC, RFSTDTC),
    CMENDY  = study_day(CMENDTC, RFSTDTC),
    CMENRTPT = if_else(CMONGO == "Yes", "ONGOING", NA_character_)
  ) %>%
  arrange(USUBJID, RECORDPOS) %>%
  group_by(USUBJID) %>%
  mutate(CMSEQ = as.numeric(row_number())) %>%
  ungroup() %>%
  select(STUDYID, DOMAIN, USUBJID, CMSEQ, everything(), -RECORDPOS)

## ---- sdtm-qc ----
# Independent QC: compare our SDTM with the reference SDTM (pharmaversesdtm).
# Variables we deliberately do not derive here are listed and excluded.
qc_compare <- function(ours, ref, keys, not_derived = character()) {
  vars <- setdiff(names(ref), not_derived)
  ref  <- ref[, vars]
  ours <- ours[, vars]
  ref[]  <- lapply(ref, function(x) { attributes(x) <- NULL; x })   # drop labels
  ours[] <- lapply(ours, function(x) { attributes(x) <- NULL; x })
  diffdf::diffdf(base = ref, compare = ours, keys = keys, suppress_warnings = TRUE)
}

qc_dm <- qc_compare(dm_sdtm, pharmaversesdtm::dm, keys = "USUBJID",
                    not_derived = c("RFICDTC", "RFPENDTC", "ACTARMUD"))
qc_ae <- qc_compare(ae_sdtm, pharmaversesdtm::ae, keys = c("USUBJID", "AESEQ"))
qc_cm <- qc_compare(cm_sdtm, pharmaversesdtm::cm, keys = c("USUBJID", "CMSEQ"))

# Number of differing values (diffdf stores one "VarDiff_<variable>" table per variable)
n_diff <- function(d) sum(map_int(d[grepl("^VarDiff_", names(d))], nrow))

qc_summary <- tibble(
  Domain = c("DM", "AE", "CM"),
  Records = c(nrow(dm_sdtm), nrow(ae_sdtm), nrow(cm_sdtm)),
  `Variables compared` = c(ncol(pharmaversesdtm::dm) - 3, ncol(pharmaversesdtm::ae), ncol(pharmaversesdtm::cm)),
  `Values that differ` = map_int(list(qc_dm, qc_ae, qc_cm), n_diff)
)
# Root cause of the 2 differences (keep them: this is what real QC looks like)
#  * DM.RFENDTC, 01-710-1083: the reference used the date the end-of-study page
#    was completed (DSDTC = 2013-08-03); we used the disposition event date
#    (DSSTDTC = 2013-08-02, the death date). A spec ambiguity -> clarify the spec.
#  * AE.AESTDY, 01-716-1063 AESEQ 1: AE starts on the first dose date, so study
#    day is 1; the reference says 366. An error in the reference data.

## ---- sdtm-write ----
dm_sdtm <- dm_sdtm %>% select(all_of(intersect(names(pharmaversesdtm::dm), names(dm_sdtm))))
write_raw(dm_sdtm, "dm", dir = "sdtm")
write_raw(ae_sdtm, "ae", dir = "sdtm")
write_raw(cm_sdtm, "cm", dir = "sdtm")
