# =============================================================================
# source_data.R - build the source data of OUR trial (maintainer script)
#
# The lab programs never read the pharmaverse packages directly. They read the
# study data in lab/data/source/, which this script builds once from the CDISC
# pilot study in {pharmaversesdtm} and {pharmaverseadam}:
#
#   1. Two arms. Keep Placebo, High Dose and the screen failures; drop the
#      pilot's Low Dose arm from every SDTM and ADaM dataset.
#   2. Actual treatment. 12 High Dose patients stopped during the 54 mg start
#      and never reached 81 mg. They started the High Dose regimen, so their
#      actual arm (ACTARM, ACTARMCD, TRT01A, TRTA) is High Dose.
#   3. Export every dataset as CSV (large files gzipped), plus one metadata
#      file with the label and type of every variable.
#
# CSV is easy to open, check and compare (any software, git diff), but it
# keeps no types and no labels. read_source() in R/00_setup.R restores both
# from the metadata file. Submissions use SAS transport files (XPT) described
# by define.xml, not CSV.
#
# Run from the repository root:   Rscript lab/source_data.R
# Students do not need to run it: the output is in the repository.
# =============================================================================
source(here::here("lab", "R", "00_setup.R"))

sdtm <- list(
  dm = pharmaversesdtm::dm, suppdm = pharmaversesdtm::suppdm, ex = pharmaversesdtm::ex,
  ae = pharmaversesdtm::ae, cm = pharmaversesdtm::cm, ds = pharmaversesdtm::ds,
  lb = pharmaversesdtm::lb, vs = pharmaversesdtm::vs, sv = pharmaversesdtm::sv,
  rs = pharmaversesdtm::rs_onco      # synthetic RECIST 1.1 tumour response
)
adam <- list(
  adsl = pharmaverseadam::adsl, adae = pharmaverseadam::adae,
  adcm = pharmaverseadam::adcm, adlb = pharmaverseadam::adlb
)

## ---- source-two-arm ----
low_dose <- pharmaversesdtm::dm$USUBJID[pharmaversesdtm::dm$ARM == "Xanomeline Low Dose"]

two_arm <- function(df) {
  df <- df[!df$USUBJID %in% low_dose, , drop = FALSE]
  # actual treatment of the 12 High Dose patients who never reached 81 mg
  for (v in intersect(c("ACTARM", "TRT01A", "TRTA"), names(df))) {
    df[[v]][df[[v]] %in% "Xanomeline Low Dose"] <- "Xanomeline High Dose"
  }
  if ("ACTARMCD" %in% names(df)) df$ACTARMCD[df$ACTARMCD %in% "Xan_Lo"] <- "Xan_Hi"
  df
}
source_data <- c(lapply(sdtm, two_arm), lapply(adam, two_arm))
standard <- c(rep("sdtm", length(sdtm)), rep("adam", length(adam)))

## ---- source-write ----
metadata <- purrr::imap_dfr(source_data, function(df, name) {
  tibble(
    dataset  = name,
    standard = standard[match(name, names(source_data))],
    variable = names(df),
    label    = purrr::map_chr(df, ~ attr(.x, "label") %||% NA_character_),
    type     = purrr::map_chr(df, ~ class(.x)[1])
  )
})

for (name in names(source_data)) {
  df <- source_data[[name]]
  dir <- lab_path("data", "source", standard[match(name, names(source_data))])
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  gzip <- nrow(df) * ncol(df) > 200000              # large files are gzipped
  readr::write_csv(df, file.path(dir, paste0(name, if (gzip) ".csv.gz" else ".csv")), na = "")
}
readr::write_csv(metadata, lab_path("data", "source", "metadata.csv"), na = "")

## ---- source-check ----
# QC of the export itself: every dataset read back must equal the original
for (name in names(source_data)) {
  back <- read_source(name)
  orig <- as.data.frame(source_data[[name]])
  stopifnot(identical(names(back), names(orig)), nrow(back) == nrow(orig))
  for (v in names(orig)) {
    same <- isTRUE(all.equal(as.vector(back[[v]]), as.vector(orig[[v]]), check.attributes = FALSE)) &&
      identical(attr(back[[v]], "label"), attr(orig[[v]], "label")) &&
      identical(class(back[[v]])[1], class(orig[[v]])[1])
    if (!same) stop("Round trip failed: ", name, ".", v)
  }
}
message("Source data written to lab/data/source/ and checked: ",
        paste(names(source_data), collapse = ", "))
