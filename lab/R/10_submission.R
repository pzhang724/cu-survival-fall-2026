# =============================================================================
# 10_submission.R  (Submission: SAS transport files driven by metadata)
#
# FDA requires SDTM and ADaM datasets as SAS transport files (XPT, version 5),
# described by define.xml. {xportr} applies the specification (types, lengths,
# labels, order, formats) to an R data frame and writes a compliant XPT file,
# reporting every mismatch between the data and the spec.
# =============================================================================
source(here::here("lab", "R", "00_setup.R"))
need("adtte", "05_adam_adrs_adtte.R")
library(xportr)

## ---- sub-spec ----
# Variable-level metadata for ADTTE (in practice: the ADaM specification
# spreadsheet that also generates define.xml)
adtte_spec <- tribble(
  ~variable,  ~label,                                   ~type,       ~length, ~format,
  "STUDYID",  "Study Identifier",                       "character", 12,      NA,
  "USUBJID",  "Unique Subject Identifier",              "character", 11,      NA,
  "TRT01P",   "Planned Treatment for Period 01",        "character", 20,      NA,
  "TRT01A",   "Actual Treatment for Period 01",         "character", 20,      NA,
  "ITTFL",    "Intent-To-Treat Population Flag",        "character", 1,       NA,
  "SAFFL",    "Safety Population Flag",                 "character", 1,       NA,
  "AGE",      "Age",                                    "integer",   8,       NA,
  "SEX",      "Sex",                                    "character", 1,       NA,
  "PARAMCD",  "Parameter Code",                         "character", 8,       NA,
  "PARAM",    "Parameter",                              "character", 40,      NA,
  "AVAL",     "Analysis Value",                         "float",     8,       NA,
  "AVALU",    "Analysis Value Unit",                    "character", 4,       NA,
  "STARTDT",  "Time-to-Event Origin Date for Subject",  "integer",   8,       "DATE9.",
  "ADT",      "Analysis Date",                          "integer",   8,       "DATE9.",
  "CNSR",     "Censor",                                 "integer",   8,       NA,
  "EVNTDESC", "Event or Censoring Description",         "character", 40,      NA,
  "CNSDTDSC", "Censor Date Description",                "character", 40,      NA,
  "SRCDOM",   "Source Data",                            "character", 4,       NA,
  "SRCVAR",   "Source Variable",                        "character", 8,       NA,
  "SRCSEQ",   "Source Sequence Number",                 "integer",   8,       NA,
  "ASEQ",     "Analysis Sequence Number",               "integer",   8,       NA
) %>%
  mutate(dataset = "ADTTE", order = row_number(), .before = 1)

dataset_spec <- tibble(dataset = "ADTTE", label = "Time-to-Event Analysis Dataset")

## ---- sub-xportr ----
adtte_xpt <- adtte %>%
  xportr_metadata(adtte_spec, domain = "ADTTE", verbose = "message") %>%
  xportr_type() %>%      # character vs numeric, as specified
  xportr_length() %>%    # SAS variable lengths
  xportr_label() %>%     # variable labels (max 40 characters in XPT v5)
  xportr_order() %>%     # variable order from the spec
  xportr_format() %>%    # SAS display formats, e.g. DATE9. for dates
  xportr_df_label(dataset_spec) %>%
  xportr_write(lab_path("output", "submission", "adtte.xpt"))

## ---- sub-check ----
# Read the transport file back, as a reviewer at FDA would
adtte_back <- haven::read_xpt(lab_path("output", "submission", "adtte.xpt"))
xpt_check <- tibble(
  Variable = names(adtte_back),
  Label    = map_chr(adtte_back, ~ attr(.x, "label") %||% ""),
  Type     = map_chr(adtte_back, ~ class(.x)[1])
)

## ---- sub-ectd ----
# Where the deliverables live in the eCTD (electronic Common Technical Document), module 5
ectd_tree <- "
m5/datasets/cdiscpilot01/
|-- tabulations/sdtm/
|   |-- dm.xpt  ae.xpt  cm.xpt  ds.xpt  ex.xpt  lb.xpt  rs.xpt ...
|   `-- define.xml  acrf.pdf  csdrg.pdf
`-- analysis/adam/
    |-- datasets/
    |   |-- adsl.xpt  adrs.xpt  adtte.xpt  adae.xpt  adlb.xpt ...
    |   `-- define.xml  adrg.pdf
    `-- programs/
        `-- adtte.r.txt  t_14_2_1_pfs.r.txt ...
"
