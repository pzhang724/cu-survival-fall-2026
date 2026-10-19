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
  library(rtables)     # table layouts: columns, rows, analyses -> a table
  library(tern)        # analysis functions for clinical tables (built on rtables)
  library(gt)          # simple tables for the slides
  library(gsDesign)    # sample size, power, group sequential design, conditional power
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

# Treatment arms (planned = randomized): a two-arm trial, High Dose vs Placebo.
# (The CDISC pilot study also had a Low Dose arm; 04_adam_adsl.R leaves it out.)
ARM_LEVELS   <- c("Placebo", "Xanomeline High Dose")
CONTROL      <- "Placebo"
EXPERIMENTAL <- "Xanomeline High Dose"

# Design assumptions, copied from the protocol synopsis (lab/docs/01_protocol_synopsis.md)
DESIGN <- list(
  alpha          = 0.025, # one-sided type I error
  beta           = 0.20,  # type II error (power = 80%)
  info_rates     = c(0.5, 0.75, 1), # analyses at 50%, 75% and 100% of the total events
  hr             = 0.60,  # design hazard ratio, High Dose vs Placebo (H0: HR = 1)
  median_control = 1.7,   # months, placebo median progression-free survival
  accrual_months = 24,
  followup_months = 3,    # minimum follow-up after the last patient is randomized
  dropout_rate   = 0.25,  # cumulative dropout probability by `dropout_time`
  dropout_time   = 3,     # months
  futility_cp    = 0.10   # non-binding futility: consider stopping if CP (current trend) < 10%
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

# Save a table as RTF, the usual hand-off format for a clinical study report
# (CSR): {rtables} tables with export_as_rtf(), gt tables with gtsave().
# Returns the table invisibly so it can be piped.
save_rtf <- function(tbl, name) {
  path <- lab_path("output", "tables", paste0(name, ".rtf"))
  if (inherits(tbl, "VTableTree")) {
    stopifnot(requireNamespace("r2rtf", quietly = TRUE))   # used by export_as_rtf()
    formatters::export_as_rtf(tbl, file = path, landscape = TRUE, font_size = 8)
  } else {
    gt::gtsave(tbl, path)
  }
  invisible(tbl)
}

# "n (xx.x%)" with one decimal everywhere ({tern} formats)
n_pct <- c(count_fraction = format_count_fraction_fixed_dp)

# Is the current {rtables} column the Total column? Used by analysis functions
# for rows that only make sense there (screening counts) or never do
# (comparisons with Placebo).
in_col <- function(.spl_context, col) {
  .spl_context$cur_col_id[[nrow(.spl_context)]] == col
}

# Write a data frame as CSV with blanks (not "NA") for missing values,
# the way most EDC (electronic data capture) and vendor exports look.
# Large files are gzipped (readr reads .csv.gz transparently).
write_raw <- function(df, name, dir = "raw", gzip = FALSE) {
  ext <- if (gzip) ".csv.gz" else ".csv"
  readr::write_csv(df, lab_path("data", dir, paste0(name, ext)), na = "")
  invisible(df)
}

# Read one dataset of the study's source data (lab/data/source/, built by
# lab/source_data.R): SDTM and ADaM of our two-arm trial, stored as CSV.
# CSV keeps no types or labels, so both come back from metadata.csv.
read_source <- function(name) {
  meta <- readr::read_csv(lab_path("data", "source", "metadata.csv"),
                          col_types = readr::cols(.default = "c"), na = "")
  meta <- meta[meta$dataset == name, ]
  path <- lab_path("data", "source", meta$standard[1], paste0(name, ".csv"))
  if (!file.exists(path)) path <- paste0(path, ".gz")
  df <- readr::read_csv(path, col_types = readr::cols(.default = "c"), na = "", trim_ws = FALSE)
  for (i in seq_len(nrow(meta))) {
    x <- df[[meta$variable[i]]]
    x <- switch(meta$type[i],
                numeric = as.numeric(x),
                integer = as.integer(x),
                logical = as.logical(x),
                Date    = as.Date(x),
                POSIXct = as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                x)
    if (!is.na(meta$label[i])) attr(x, "label") <- meta$label[i]
    df[[meta$variable[i]]] <- x
  }
  as.data.frame(df)
}

# Read a raw CSV with every column as character, as you would on day one of
# a study: never let the reader guess types for you.
read_raw <- function(name, dir = "raw") {
  path <- lab_path("data", dir, paste0(name, ".csv"))
  if (!file.exists(path)) path <- paste0(path, ".gz")
  readr::read_csv(path, col_types = readr::cols(.default = "c"), na = "")
}
