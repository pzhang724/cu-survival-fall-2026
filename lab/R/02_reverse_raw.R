# =============================================================================
# 02_reverse_raw.R  (Data collection: build "raw" data from SDTM)
#
# Our source data (lab/data/source/, built from pharmaverse by
# lab/source_data.R) contain SDTM, not the raw data a statistician receives from
# the EDC (electronic data capture) system and from vendors. To practise the real
# workflow (CRF -> raw -> SDTM), we reverse-engineer raw data from SDTM by
# undoing what the SDTMIG (SDTM Implementation Guide) asks a sponsor to derive:
#
#   * drop derived variables: --SEQ, --DY, EPOCH, USUBJID, AGE, RF dates ...
#   * turn ISO 8601 dates ("2014-01-02") back into CRF text ("02 JAN 2014",
#     with "UN"/"UNK" for unknown day/month)
#   * turn controlled terminology ("F") back into what the CRF shows ("Female")
#   * keep dictionary coding (MedDRA for AEs, WHODrug for medications) as the
#     separate "coding" columns a coding team would deliver
#   * reshape findings back to how forms and vendors deliver them (wide CRF
#     pages, one lab-vendor transfer file)
#
# Output: lab/data/raw/*.csv  (+ lab/data/spec/study_ct.csv, the codelist map)
# =============================================================================
source(here::here("lab", "R", "00_setup.R"))

dm   <- read_source("dm")
ex   <- read_source("ex")
ae   <- read_source("ae")
cm   <- read_source("cm")
ds   <- read_source("ds")
lb   <- read_source("lb")
vs   <- read_source("vs")
rs   <- read_source("rs")

## ---- raw-date-helpers ----
# ISO 8601 date (SDTM --DTC)  ->  CRF date text, e.g. "2014-01" -> "UN JAN 2014"
iso_to_crf_date <- function(dtc) {
  d    <- substr(dtc, 1, 10)
  yyyy <- substr(d, 1, 4)
  mon  <- toupper(month.abb[suppressWarnings(as.integer(substr(d, 6, 7)))])
  dd   <- substr(d, 9, 10)
  case_when(
    is.na(dtc) | dtc == "" ~ NA_character_,
    nchar(d) == 10 ~ paste(dd, mon, yyyy),
    nchar(d) == 7  ~ paste("UN", mon, yyyy),
    nchar(d) == 4  ~ paste("UN UNK", yyyy)
  )
}
# ISO 8601 date-time -> CRF time text "HH:MM" (missing when no time collected)
iso_to_crf_time <- function(dtc) if_else(nchar(dtc) >= 16, substr(dtc, 12, 16), NA_character_)

# Subject identifier as the site sees it in EDC ("701-1015"); USUBJID adds the study prefix
subject_id <- function(usubjid) str_remove(usubjid, "^01-")

## ---- raw-ct ----
# Study controlled-terminology (CT) map: CRF display value <-> SDTM submission value.
# One table drives both directions (reverse here, forward in 03_raw_to_sdtm.R).
study_ct <- tribble(
  ~codelist, ~collected_value,                       ~term_value,
  "SEX",     "Female",                               "F",
  "SEX",     "Male",                                 "M",
  "RACE",    "White",                                "WHITE",
  "RACE",    "Black or African American",            "BLACK OR AFRICAN AMERICAN",
  "RACE",    "Asian",                                "ASIAN",
  "RACE",    "American Indian or Alaska Native",     "AMERICAN INDIAN OR ALASKA NATIVE",
  "ETHNIC",  "Hispanic or Latino",                   "HISPANIC OR LATINO",
  "ETHNIC",  "Not Hispanic or Latino",               "NOT HISPANIC OR LATINO",
  "NY",      "Yes",                                  "Y",
  "NY",      "No",                                   "N",
  "AESEV",   "Mild",                                 "MILD",
  "AESEV",   "Moderate",                             "MODERATE",
  "AESEV",   "Severe",                               "SEVERE",
  "AEREL",   "None",                                 "NONE",
  "AEREL",   "Remote",                               "REMOTE",
  "AEREL",   "Possible",                             "POSSIBLE",
  "AEREL",   "Probable",                             "PROBABLE",
  "OUT",     "Recovered/Resolved",                   "RECOVERED/RESOLVED",
  "OUT",     "Not Recovered/Not Resolved",           "NOT RECOVERED/NOT RESOLVED",
  "OUT",     "Fatal",                                "FATAL"
)

# term_value -> collected_value for one codelist (unmapped values stay as they are)
ct_decode <- function(x, codelist) {
  map <- filter(study_ct, .data$codelist == !!codelist)
  out <- map$collected_value[match(x, map$term_value)]
  if_else(is.na(out), x, out)
}

## ---- raw-dm ----
# Demographics CRF page: birth date is collected; AGE is derived later in SDTM.
raw_dm <- dm %>%
  transmute(
    STUDY   = STUDYID,
    SITE    = SITEID,
    SUBJECT = subject_id(USUBJID),
    FOLDER  = "SCREENING 1",
    DMDAT   = iso_to_crf_date(DMDTC),
    BRTHDAT = iso_to_crf_date(BRTHDTC),
    SEX     = ct_decode(SEX, "SEX"),
    RACE    = ct_decode(RACE, "RACE"),
    ETHNIC  = ct_decode(ETHNIC, "ETHNIC")
  )

# Site master list (from the clinical operations system, not the CRF)
raw_sites <- dm %>% distinct(SITE = SITEID, COUNTRY)

## ---- raw-irt ----
# IRT (interactive response technology) randomization transfer from the vendor.
# Vendors use their own date format: "02-Jan-2014".
raw_irt <- dm %>%
  filter(ARMCD != "Scrnfail") %>%
  left_join(filter(ds, DSDECOD == "RANDOMIZED") %>% select(USUBJID, DSSTDTC), by = "USUBJID") %>%
  transmute(
    STUDY          = STUDYID,
    SUBJECT        = subject_id(USUBJID),
    RANDOMIZATION_DATE = format(ymd(DSSTDTC), "%d-%b-%Y"),
    TREATMENT_CODE = ARMCD,
    TREATMENT_ARM  = ARM
  )

## ---- raw-ex ----
# Study drug administration log. The treatment name is blinded on the CRF;
# it is filled in from IRT during SDTM mapping.
raw_ex <- ex %>%
  transmute(
    STUDY = STUDYID, SUBJECT = subject_id(USUBJID), FOLDER = VISIT,
    EXSTDAT = iso_to_crf_date(EXSTDTC),
    EXENDAT = iso_to_crf_date(EXENDTC),
    EXDOSE, EXDOSU, EXDOSFRM, EXDOSFRQ, EXROUTE
  )

## ---- raw-ae ----
# Adverse event log form + MedDRA coding columns delivered by the coding team.
# RECORDPOS is the EDC record position on the log form (used to sort --SEQ).
raw_ae <- ae %>%
  transmute(
    STUDY = STUDYID, SUBJECT = subject_id(USUBJID),
    RECORDPOS = AESEQ, RECORDDATE = iso_to_crf_date(AEDTC),
    AESPID,
    AETERM,
    AESTDAT = iso_to_crf_date(AESTDTC),
    AEENDAT = iso_to_crf_date(AEENDTC),
    AEONGO  = if_else(is.na(AEENDTC), "Yes", "No"),
    AESEV   = ct_decode(AESEV, "AESEV"),
    AESER   = ct_decode(AESER, "NY"),
    AEREL   = ct_decode(AEREL, "AEREL"),
    AEOUT   = ct_decode(AEOUT, "OUT"),
    across(c(AESCAN, AESCONG, AESDISAB, AESDTH, AESHOSP, AESLIFE, AESOD), ~ ct_decode(.x, "NY")),
    # MedDRA coding (lowest level term ... system organ class)
    AETERM_LLT = AELLT, AETERM_LLT_CODE = AELLTCD,
    AETERM_PT  = AEDECOD, AETERM_PT_CODE = AEPTCD,
    AETERM_HLT = AEHLT, AETERM_HLT_CODE = AEHLTCD,
    AETERM_HLGT = AEHLGT, AETERM_HLGT_CODE = AEHLGTCD,
    AETERM_SOC = AEBODSYS, AETERM_SOC_CODE = AEBDSYCD
  )

## ---- raw-cm ----
# Prior / concomitant medication log form + WHODrug coding columns.
raw_cm <- cm %>%
  transmute(
    STUDY = STUDYID, SUBJECT = subject_id(USUBJID), FOLDER = VISIT,
    RECORDPOS = CMSEQ, RECORDDATE = iso_to_crf_date(CMDTC),
    CMSPID, CMTRT, CMINDC, CMDOSE, CMDOSU, CMDOSFRQ, CMROUTE,
    CMSTDAT = iso_to_crf_date(CMSTDTC),
    CMENDAT = iso_to_crf_date(CMENDTC),
    CMONGO  = if_else(CMENRTPT %in% "ONGOING", "Yes", "No"),
    CMTRT_PREFERRED_NAME = CMDECOD,   # WHODrug preferred name
    CMTRT_ATC_CLASS      = CMCLAS     # WHODrug ATC class
  )

## ---- raw-ds ----
# Disposition pages: screening outcome, end of study, other study events.
raw_ds <- ds %>%
  filter(DSDECOD != "RANDOMIZED") %>%  # randomization comes from IRT, not the CRF
  transmute(
    STUDY = STUDYID, SUBJECT = subject_id(USUBJID), FOLDER = VISIT,
    FORM = case_when(
      DSDECOD == "SCREEN FAILURE"     ~ "Screening Outcome",
      DSCAT == "DISPOSITION EVENT"    ~ "End of Study",
      TRUE                            ~ "Study Events"
    ),
    DSDECOD = str_to_sentence(DSDECOD),   # pick-list text shown on the CRF
    DSTERM,                               # "specify" free text
    DSSTDAT = iso_to_crf_date(DSSTDTC),
    DSSTTIM = iso_to_crf_time(DSDTC)
  )

## ---- raw-vs ----
# Vital signs CRF: one row per visit and time point, one column per test,
# units printed on the page except where the site can choose (height, weight, temp).
raw_vs <- vs %>%
  filter(is.na(VSSTAT)) %>%
  transmute(
    STUDY = STUDYID, SUBJECT = subject_id(USUBJID), FOLDER = VISIT,
    VSDAT = iso_to_crf_date(VSDTC), VSTPT, VSPOS, VSTESTCD, VSORRES, VSORRESU
  ) %>%
  pivot_wider(
    names_from = VSTESTCD, values_from = c(VSORRES, VSORRESU),
    names_glue = "{VSTESTCD}_{.value}"
  ) %>%
  rename_with(~ str_remove(.x, "_VSORRES$")) %>%
  rename_with(~ str_replace(.x, "_VSORRESU$", "_UNIT")) %>%
  select(-any_of(c("SYSBP_UNIT", "DIABP_UNIT", "PULSE_UNIT")))

## ---- raw-lb ----
# Central laboratory transfer file (vendor data, not a CRF). Vendor conventions:
# dates as YYYYMMDD, times as HHMM, both conventional and SI results supplied.
raw_lb <- lb %>%
  transmute(
    STUDY = STUDYID, SUBJECT = subject_id(USUBJID),
    VISIT_NAME = VISIT,
    COLL_DATE  = format(ymd(substr(LBDTC, 1, 10)), "%Y%m%d"),
    COLL_TIME  = str_remove(iso_to_crf_time(LBDTC), ":"),
    PANEL = LBCAT, TEST_CODE = LBTESTCD, TEST_NAME = LBTEST,
    RESULT = LBORRES, UNIT = LBORRESU, REF_LOW = LBORNRLO, REF_HIGH = LBORNRHI,
    RESULT_SI = LBSTRESC, UNIT_SI = LBSTRESU, REF_LOW_SI = LBSTNRLO, REF_HIGH_SI = LBSTNRHI,
    FLAG = recode(LBNRIND, HIGH = "H", LOW = "L", ABNORMAL = "A", NORMAL = NA_character_)
  )

## ---- raw-rs ----
# Tumour response CRF (investigator, RECIST 1.1): one row per assessment visit.
# Independent central review results would arrive as a separate vendor file.
raw_rs <- rs %>%
  filter(RSEVAL == "INVESTIGATOR") %>%
  transmute(STUDY = STUDYID, SUBJECT = subject_id(USUBJID), FOLDER = VISIT,
            RSDAT = iso_to_crf_date(RSDTC), RSTESTCD, RSORRES) %>%
  pivot_wider(names_from = RSTESTCD, values_from = RSORRES) %>%
  select(STUDY, SUBJECT, FOLDER, RSDAT, TRGRESP, NTRGRESP, NEWLPROG, OVRLRESP)

## ---- raw-write ----
# Specs (metadata, not data): codelist map and the planned visit schedule
# (the visit schedule mirrors the SDTM trial design dataset TV).
write_raw(study_ct, "study_ct", dir = "spec")
write_raw(distinct(read_source("sv"), VISIT, VISITNUM, VISITDY) %>% arrange(VISITNUM),
          "visit_schedule", dir = "spec")
walk2(
  list(raw_dm, raw_sites, raw_irt, raw_ex, raw_ae, raw_cm, raw_ds, raw_vs, raw_rs),
  c("dm", "sites", "irt", "ex", "ae", "cm", "ds", "vs", "rs"),
  write_raw
)
write_raw(raw_lb, "lb", gzip = TRUE)  # ~60,000 rows: keep the repository small
