# From Protocol to Submission: a practical survival-trial workflow

Guest lecture for the **Survival Analysis** course, Columbia University, Fall 2026
(Friday, November 13, 2026; 90 minutes).

One randomized trial with a survival endpoint, followed the way a trial
statistician works it:

| Part | Topic |
|---|---|
| 1 | The map of a trial |
| 2 | Planning: protocol, estimand, SAP (Statistical Analysis Plan), sample size, power, group sequential design |
| 3 | Data standards: CRF (Case Report Form) -> raw data -> SDTM (Study Data Tabulation Model) -> ADaM (Analysis Data Model), QC (quality control) |
| 4 | Tables, figures and listings (TFLs) with {rtables} and {tern}: disposition, demographics, medications, progression-free survival (PFS) with log-rank test and Cox model, sensitivity analysis, multiplicity, response rates, overall survival (OS), adverse events, labs |
| 5 | Interim analyses: boundaries, p-values, conditional power and futility, the Data Monitoring Committee report |
| 6 | Deliverables during the trial, submission and wrap-up |

The trial is a two-arm role-play (High Dose vs Placebo) built on synthetic
pharmaverse test data; no real patient data are used.

## What is in the repository

* **`slides/`**: the deck (`index.qmd`, Quarto revealjs).
  **Online: https://pzhang724.github.io/cu-survival-fall-2026/** (rebuilt by
  GitHub Actions on every push to `main`). `index.html` is the same deck as a
  single self-contained file for offline use (press `S` for speaker notes,
  `F` for full screen).
* **`lab/`**: all code and data behind the slides, meant to be shared with
  students. Every number on the slides is computed by these scripts. See
  [`lab/README.md`](lab/README.md).
* **`CLAUDE.md`**: how the project is organised and the rules that keep it
  consistent (read by Claude when you open the repository with it).

## Data

All data come from [pharmaverse](https://pharmaverse.org): the CDISC (Clinical
Data Interchange Standards Consortium) SDTM/ADaM pilot study (`pharmaversesdtm`,
`pharmaverseadam`; xanomeline patch vs placebo) plus synthetic RECIST 1.1
(Response Evaluation Criteria in Solid Tumors) tumour assessments that
pharmaverse provides for the same patients. For teaching, the study is treated
as a two-arm oncology trial (High Dose vs Placebo) with progression-free
survival as the primary endpoint. `lab/source_data.R` cuts the pilot to the two
arms and exports the SDTM and ADaM datasets as CSV (comma-separated values)
files to `lab/data/source/`; every lab program starts from these files. The raw
data in `lab/data/raw/` look like an EDC (Electronic Data Capture) export;
`lab/R/02_reverse_raw.R` reverse-engineered them from the source SDTM.
Design assumptions were chosen for teaching and are not from the original study.

## Quick start

**Posit Cloud** (or RStudio): *New Project* -> *New Project from Git
Repository* -> paste this repository's URL, then in the R console:

```r
renv::restore()            # installs the locked package versions
source("lab/run_all.R")    # runs the whole pipeline (about 30 seconds)
```

**Command line**:

```bash
Rscript -e 'renv::restore()'
Rscript lab/run_all.R
quarto render slides/index.qmd   # needs Quarto >= 1.5; re-runs the pipeline
```

**Claude**: open the repository with Claude Code, or add the GitHub repository
to a claude.ai project. `CLAUDE.md` tells Claude how everything fits together;
ask it to walk you through a script or to help with an exercise.

Built with R 4.6.1 and Quarto 1.10. Package versions are locked in `renv.lock`
(Posit Package Manager snapshot of 2026-10-12).
