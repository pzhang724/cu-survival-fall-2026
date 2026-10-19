# Lab: one survival trial from design to submission

Everything the slides show, as runnable R code. Run it all with

```r
source("lab/run_all.R")   # from the repository root, about 30 seconds
```

or open the scripts one by one; each script loads what it needs from the
scripts before it.

## Source data

All programs start from the study's **source data** in `data/source/`: the SDTM
and ADaM datasets of our two-arm trial (High Dose vs Placebo), stored as CSV
(large files gzipped) with `data/source/metadata.csv` for the label and type of
every variable. Read a dataset with `read_source("adsl")` (defined in
`R/00_setup.R`). The course maintainer builds these files once from the CDISC
pilot study in {pharmaversesdtm} / {pharmaverseadam} with `source_data.R`
(drops the pilot's Low Dose arm; checks that every file reads back unchanged).
You do not need to run it.

CSV is easy to open, check and compare, but it keeps no types or labels; a
submission uses SAS transport files (XPT) with define.xml instead.

## Pipeline

| Step | Script | What it does | Main outputs |
|---|---|---|---|
| Planning | `R/01_design.R` | Hypothesis, events (Schoenfeld), patients, group sequential design with analyses at 50/75/100% of events, power analysis, all with {gsDesign} | `output/figures/f_design_boundaries.png`, `f_design_power.png`, `output/tables/t_design_boundaries.rtf` |
| Collection | `R/02_reverse_raw.R` | Builds EDC-style raw data from the source SDTM (dates as CRF text, CRF pick-list values, coding columns, wide CRF pages, lab vendor file) | `data/raw/*.csv`, `data/spec/*.csv` |
| Standards | `R/03_raw_to_sdtm.R` | Maps raw DM, AE, CM to SDTM and compares with the source SDTM using {diffdf} | `data/sdtm/*.csv` |
| Standards | `R/04_adam_adsl.R` | Extends the source ADSL: analysis-set flags (from SUPPDM), baseline BMI, end of treatment and end of study with reasons | `data/adam/adsl.csv` |
| Standards | `R/05_adam_adrs_adtte.R` | ADRS (RECIST response) and ADTTE (PFS, OS) with {admiral}/{admiralonco}, for the final data, for PFS by BICR (sensitivity) and for the two interim data cuts | `data/adam/adrs.csv`, `adtte.csv`, `adtte_ia1.csv`, `adtte_ia2.csv` |
| Reporting | `R/06_tfl_baseline.R` | Tables 14.1.1-14.1.3: disposition, demographics, concomitant medications ({rtables} + {tern}) | `output/tables/t_14_1_*.rtf` |
| Reporting | `R/07_tfl_efficacy.R` | Tables 14.2.1-14.2.4: PFS (Kaplan-Meier, log-rank, Cox), response rates, OS, PFS by BICR; Figures 14.2.1-14.2.2; multiplicity; investigator vs BICR reads | `output/tables/t_14_2_*.rtf`, `output/figures/f_14_2_*.png` |
| Reporting | `R/08_tfl_safety.R` | Tables 14.3.1-14.3.3: adverse events overview (with maximum severity), adverse events by SOC/PT, lab CTCAE shift | `output/tables/t_14_3_*.rtf` |
| Monitoring | `R/09_interim.R` | Two interim analyses: boundaries at the actual information, log-rank Z and p-value, conditional power (formula and {gsDesign}), futility rule, DMC table | `output/tables/t_ia_1_interim_pfs.rtf`, `output/figures/f_ia_1_km_pfs.png` |
| Submission | `R/10_submission.R` | Applies a variable specification with {xportr} and writes a SAS transport file | `output/submission/adtte.xpt` |

`R/00_setup.R` holds the packages, the design assumptions (`DESIGN`) and small
helpers. Lines such as `## ---- design-gsd ----` label code blocks that the
slides display.

## Documents (`docs/`)

| File | Content |
|---|---|
| `00_glossary.md` | Every acronym, spelled out and explained |
| `01_protocol_synopsis.md` | Objectives, endpoints, estimand, design and sample size |
| `02_sap.md` | Analysis sets, definitions, PFS censoring rules, methods, sensitivity analysis, computation conventions, multiplicity, interim analyses |
| `03_crf_raw_sdtm.md` | From the SAP to CRF fields, the annotated AE page, how the raw data were built, QC results, exercises |
| `04_tfl_shells.md` | TFL index and mock shells |
| `05_submission.md` | What goes into the submission package |

## Exercises

1. Map `data/raw/vs.csv` and `data/raw/lb.csv.gz` to SDTM and compare with
   `read_source("vs")` / `read_source("lb")` using `diffdf::diffdf()`.
2. Add a PFS sensitivity analysis that censors patients whose progression or
   death follows two or more missed scans.
3. Add a stratified log-rank test (strata: age group `AGEGR1`) as a second
   PFS sensitivity analysis. Does the HR change?
4. In your own file, move the interim analyses to 40% and 70% of the events
   (`timing` in `gsSurv()`). How do the boundaries and the expected months change?
5. In your own file, rerun `gsSurv()` from `R/01_design.R` with `hr = 0.70`.
   What happens to the events, the patients, and the timing of the interims?
   (Leave `DESIGN` in `R/00_setup.R` unchanged: the interim data cuts are
   triggered by the events in `DESIGN`'s design.)

Tip: write your exercise code in a new file (for example `lab/R/exercise_1.R`)
that starts with `source(here::here("lab", "R", "00_setup.R"))`, so the main
pipeline keeps working.
