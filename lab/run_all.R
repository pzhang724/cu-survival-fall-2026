# =============================================================================
# run_all.R - run the whole lab pipeline in order (about 1 minute).
#
#   planning      01 design and sample size
#   collection    02 raw data (reverse-engineered from SDTM)
#   standards     03 raw -> SDTM + QC, 04 ADSL, 05 ADRS / ADTTE (+ interim data cut)
#   reporting     06 baseline, 07 efficacy, 08 safety TFLs
#   monitoring    09 interim analysis (DMC report)
#   submission    10 XPT transport file with xportr
#
# From the repository root:   Rscript lab/run_all.R
# or in RStudio / Posit Cloud: source("lab/run_all.R")
# =============================================================================
scripts <- c(
  "01_design.R", "02_reverse_raw.R", "03_raw_to_sdtm.R", "04_adam_adsl.R",
  "05_adam_adrs_adtte.R", "06_tfl_baseline.R", "07_tfl_efficacy.R",
  "08_tfl_safety.R", "09_interim.R", "10_submission.R"
)
for (s in scripts) {
  message("== ", s)
  source(here::here("lab", "R", s))
}
message("Done. Outputs in lab/output/, derived data in lab/data/.")
