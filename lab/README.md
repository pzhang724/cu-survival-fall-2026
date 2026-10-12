# Lab: one survival trial from design to submission

Everything the slides show, as runnable R code. Run it all with

```r
source("lab/run_all.R")   # from the repository root, about 30 seconds
```

or open the scripts one by one; each script loads what it needs from the
scripts before it.

## Pipeline

| Step | Script | What it does | Main outputs |
|---|---|---|---|
| Planning | `R/01_design.R` | Group sequential design and sample size with {rpact}; Schoenfeld check; sensitivity to the assumed HR | `output/figures/f_design_boundaries.png`, `output/tables/t_design_boundaries.rtf` |
| Collection | `R/02_reverse_raw.R` | Builds EDC-style raw data from pharmaverse SDTM (dates as CRF text, CRF pick-list values, coding columns, wide CRF pages, lab vendor file) | `data/raw/*.csv`, `data/spec/*.csv` |
| Standards | `R/03_raw_to_sdtm.R` | Maps raw DM, AE, CM to SDTM and compares with pharmaversesdtm using {diffdf} | `data/sdtm/*.csv` |
| Standards | `R/04_adam_adsl.R` | Extends ADSL: analysis-set flags (from SUPPDM), reason for discontinuation, baseline BMI | `data/adam/adsl.csv` |
| Standards | `R/05_adam_adrs_adtte.R` | ADRS (RECIST response) and ADTTE (PFS, OS) with {admiral}/{admiralonco}, for the final data and for the interim data cut | `data/adam/adrs.csv`, `adtte.csv`, `adtte_ia.csv` |
| Reporting | `R/06_tfl_baseline.R` | Tables 14.1.1-14.1.3: disposition, demographics, concomitant medications ({gtsummary}) | `output/tables/t_14_1_*.rtf` |
| Reporting | `R/07_tfl_efficacy.R` | Table 14.2.1 PFS (Kaplan-Meier, log-rank, Cox), Figure 14.2.1, Table 14.2.2 ORR, OS summary, multiplicity, R vs SAS defaults | `output/tables/t_14_2_*.rtf`, `output/figures/f_14_2_1_km_pfs.png` |
| Reporting | `R/08_tfl_safety.R` | Tables 14.3.1-14.3.3: adverse events overview, adverse events by SOC/PT, lab CTCAE shift | `output/tables/t_14_3_*.rtf` |
| Monitoring | `R/09_interim.R` | Interim analysis: boundary at the actual information fraction, log-rank Z and p-value, conditional power (formula and {rpact}), DMC table | `output/tables/t_ia_1_interim_pfs.rtf`, `output/figures/f_ia_1_km_pfs.png` |
| Submission | `R/10_submission.R` | Applies a variable specification with {xportr} and writes a SAS transport file | `output/submission/adtte.xpt` |

`R/00_setup.R` holds the packages, the design assumptions (`DESIGN`) and small
helpers. Lines such as `## ---- design-gsd ----` label code blocks that the
slides display.

## Documents (`docs/`)

| File | Content |
|---|---|
| `00_glossary.md` | Every acronym, spelled out and explained |
| `01_protocol_synopsis.md` | Objectives, endpoints, estimand, design and sample size |
| `02_sap.md` | Analysis sets, definitions, PFS censoring rules, methods, multiplicity, interim analysis |
| `03_crf_raw_sdtm.md` | From the SAP to CRF fields, the annotated AE page, how the raw data were built, QC results, exercises |
| `04_tfl_shells.md` | TFL index and mock shells |
| `05_submission.md` | What goes into the submission package |

## Exercises

1. Map `data/raw/vs.csv` and `data/raw/lb.csv.gz` to SDTM and compare with
   `pharmaversesdtm::vs` / `pharmaversesdtm::lb` using `diffdf::diffdf()`.
2. Add a PFS sensitivity analysis that censors patients whose progression or
   death follows two or more missed scans.
3. Re-derive PFS from the independent central review records
   (`RSEVAL == "INDEPENDENT ASSESSOR"` in `rs_onco`) and compare with the
   investigator result.
4. Replace the Z < 0 futility rule with "conditional power under the current
   trend below 10%". Would the trial have stopped at the interim?
5. In your own file, rerun `getSampleSizeSurvival()` from `R/01_design.R` with
   `hazardRatio = 0.70`. What happens to the events, the patients, and the
   timing of the interim? (Leave `DESIGN` in `R/00_setup.R` unchanged: the
   interim data cut is triggered by `DESIGN`'s 61 events.)

Tip: write your exercise code in a new file (for example `lab/R/exercise_1.R`)
that starts with `source(here::here("lab", "R", "00_setup.R"))`, so the main
pipeline keeps working.
