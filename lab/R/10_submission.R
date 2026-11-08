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
# Variable-level metadata for ADTTE: sheet "ADTTE" of the ADaM specification
# workbook (lab/data/spec/adam_spec.xlsx), the same workbook that would also
# generate define.xml. Renamed to the columns that {xportr} reads; a SAS format
# (for example DATE9.) sits in the column "Controlled Terms or Format".
adtte_spec <- read_spec("adam_spec.xlsx", sheet = "ADTTE") %>%
  transmute(
    dataset  = "ADTTE",
    variable = `Variable Name`,
    label    = `Variable Label`,
    type     = if_else(Type == "Num", "numeric", "character"),
    length   = Length,
    format   = if_else(str_detect(`Controlled Terms or Format`, "\\.$"),
                       `Controlled Terms or Format`, NA_character_),
    order    = `Variable Order`
  )

dataset_spec <- read_spec("adam_spec.xlsx", sheet = "Datasets") %>%
  transmute(dataset = Dataset, label = Label)

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
