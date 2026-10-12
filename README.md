# From Protocol to Submission: a practical survival-trial workflow

Guest lecture for the **Survival Analysis** course, Columbia University, Fall 2026
(Friday, November 13, 2026; 90 minutes).

One randomized trial with a survival endpoint, followed the way a trial
statistician works it:

| Part | Topic | Minutes |
|---|---|---|
| 1 | The map of a trial | 5 |
| 2 | Planning: protocol, estimand, SAP (Statistical Analysis Plan), group sequential design, sample size | 25 |
| 3 | Data standards: CRF (Case Report Form) -> raw data -> SDTM (Study Data Tabulation Model) -> ADaM (Analysis Data Model) | 20 |
| 4 | Tables, figures and listings (TFLs): disposition, demographics, medications, PFS / log-rank / Cox, response rate, adverse events, labs | 20 |
| 5 | Interim analysis: boundaries, p-values, conditional power, the Data Monitoring Committee report | 12 |
| 6 | Submission and wrap-up | 8 |

## What is in the repository

* **`slides/`**: the deck (`index.qmd`, Quarto revealjs). `index.html` is the
  rendered, self-contained version: download it and open it in a browser
  (press `S` for speaker notes, `F` for full screen).
* **`lab/`**: all code and data behind the slides, meant to be shared with
  students. Every number on the slides is computed by these scripts. See
  [`lab/README.md`](lab/README.md).
* **`CLAUDE.md`**: how the project is organised and the rules that keep it
  consistent (read by Claude when you open the repository with it).

## Data

All data come from [pharmaverse](https://pharmaverse.org): the CDISC SDTM/ADaM
pilot study (`pharmaversesdtm`, `pharmaverseadam`; xanomeline patch vs placebo)
plus synthetic RECIST 1.1 tumour assessments that pharmaverse provides for the
same patients. For teaching, the study is treated as an oncology trial with
progression-free survival as the primary endpoint. The raw (EDC-style) data in
`lab/data/raw/` were reverse-engineered from SDTM by `lab/R/02_reverse_raw.R`.
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
