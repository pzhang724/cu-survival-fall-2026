# =============================================================================
# 00_setup.R
# Packages, paths and study-level constants shared by every lab script.
#
# Every script starts with `source(here::here("lab", "R", "00_setup.R"))`, so
# any script can be run on its own. lab/run_all.R runs the whole pipeline.
#
# Lines such as `## ---- design-gsd ----` are chunk labels. The slides pull
# these exact code blocks with knitr::read_chunk(), so the code students see
# on a slide is the code that produced the numbers on that slide.
# =============================================================================

## ---- setup-packages ----
suppressPackageStartupMessages({
  library(dplyr)       # data manipulation
  library(tidyr)
  library(stringr)
  library(purrr)
  library(lubridate)
  library(admiral)     # ADaM derivations (pharmaverse)
  library(admiralonco) # oncology add-ons: RECIST response, PFS/OS sources
  library(survival)    # Kaplan-Meier, log-rank test, Cox model
  library(ggsurvfit)   # Kaplan-Meier figures with numbers at risk
  library(gtsummary)   # summary tables
  library(gt)          # table rendering and RTF export
  library(rpact)       # group sequential design, sample size, conditional power
})

## ---- setup-paths ----
# All paths are relative to the repository root (found by {here}),
# so scripts work from RStudio, Posit Cloud, Quarto, or Rscript.
lab_path <- function(...) here::here("lab", ...)

for (d in c("data/raw", "data/spec", "data/sdtm", "data/adam",
            "output/tables", "output/figures", "output/submission")) {
  dir.create(lab_path(d), recursive = TRUE, showWarnings = FALSE)
}

## ---- setup-constants ----
STUDYID <- "CDISCPILOT01"

# Treatment arms (planned = randomized). Primary comparison: High Dose vs Placebo.
ARM_LEVELS   <- c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")
CONTROL      <- "Placebo"
EXPERIMENTAL <- "Xanomeline High Dose"

# Design assumptions, copied from the protocol synopsis (lab/docs/01_protocol_synopsis.md)
DESIGN <- list(
  alpha          = 0.025, # one-sided type I error
  beta           = 0.20,  # type II error (power = 80%)
  info_rates     = c(0.5, 1), # one interim analysis at 50% of events
  hr             = 0.60,  # target hazard ratio, High Dose vs Placebo
  median_control = 1.7,   # months, placebo median progression-free survival
  accrual_months = 24,
  followup_months = 3,    # minimum follow-up after the last patient is randomized
  dropout_rate   = 0.25,  # cumulative dropout probability by `dropout_time`
  dropout_time   = 3      # months
)

DAYS_PER_MONTH <- 365.25 / 12

## ---- setup-helpers ----
# Run an upstream script only if the object it creates is not in the workspace.
# (inherits = FALSE matters: {ggsurvfit} ships an example data set called `adtte`.)
need <- function(object, script) {
  if (!exists(object, envir = globalenv(), inherits = FALSE)) {
    source(lab_path("R", script), echo = FALSE)
  }
}

invisible(suppressMessages(theme_gtsummary_compact(set_theme = TRUE, font_size = 12)))

# Save a gtsummary / gt table as RTF, the usual hand-off format for a
# clinical study report (CSR). Returns the table invisibly so it can be piped.
save_rtf <- function(tbl, name) {
  gt_tbl <- if (inherits(tbl, "gtsummary")) as_gt(tbl) else tbl
  gt::gtsave(gt_tbl, lab_path("output", "tables", paste0(name, ".rtf")))
  invisible(tbl)
}

# Write a data frame as CSV with blanks (not "NA") for missing values,
# the way most EDC (electronic data capture) and vendor exports look.
# Large files are gzipped (readr reads .csv.gz transparently).
write_raw <- function(df, name, dir = "raw", gzip = FALSE) {
  ext <- if (gzip) ".csv.gz" else ".csv"
  readr::write_csv(df, lab_path("data", dir, paste0(name, ext)), na = "")
  invisible(df)
}

# Read a raw CSV with every column as character, as you would on day one of
# a study: never let the reader guess types for you.
read_raw <- function(name, dir = "raw") {
  path <- lab_path("data", dir, paste0(name, ".csv"))
  if (!file.exists(path)) path <- paste0(path, ".gz")
  readr::read_csv(path, col_types = readr::cols(.default = "c"), na = "")
}
