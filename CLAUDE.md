# CLAUDE.md

Guidance for Claude (and for people) working in this repository. Read it before
changing anything, and update it when a decision changes.

## What this repository is

* A **90-minute guest lecture** for the Survival Analysis course at Columbia
  University, Fall 2026. Lecture date: **Friday, November 13, 2026**.
* Theme: a role-play of the trial statistician on a two-arm randomized trial
  with a survival endpoint, in this order: protocol -> SAP (Statistical Analysis
  Plan) -> sample size, power and group sequential design -> CRF (Case Report
  Form) -> raw data -> SDTM -> ADaM -> TFL (Tables, Figures, Listings) shells
  and outputs -> interim analyses (p-value, conditional power, DMC report) ->
  deliverables and submission.
* Audience: graduate biostatistics students who know survival theory but have
  not worked on an industry trial.
* Deliverables: the slide deck (`slides/index.qmd`, Quarto revealjs) and a
  shareable lab (`lab/`) that students run on Posit Cloud, locally, or with Claude.

## Layout

```
slides/index.qmd        the deck; runs lab/run_all.R and pulls code chunks from lab/R/
slides/columbia.scss    theme (36px base font; logo, footer and slide-number placement)
slides/logos.html       Columbia (bottom-left) and CIMS (bottom-right) logos on every slide
slides/images/          logo files, embedded into index.html at render time
slides/index.html       rendered, self-contained deck (committed as an offline copy)
.github/workflows/publish-slides.yml   CI: render slides, deploy to GitHub Pages
lab/run_all.R           runs the whole pipeline (about 30 seconds)
lab/source_data.R       maintainer script: pharmaverse -> two-arm source data (not in run_all)
lab/R/00_setup.R        packages, paths, DESIGN constants, helpers (need(), read_raw() ...)
lab/R/01..10_*.R        design, raw data, SDTM, ADSL, ADRS/ADTTE, TFLs, interim, submission
lab/data/source/        source SDTM + ADaM of our two-arm trial (CSV, large files gzipped) + metadata.csv
lab/data/raw/           reverse-engineered raw data (EDC-style CSV; lab file gzipped)
lab/data/spec/          study controlled-terminology map, visit schedule
lab/data/sdtm/, adam/   derived datasets written by the pipeline (CSV; adtte_ia1/2 = interim cuts)
lab/output/             RTF tables, PNG figures, XPT file
lab/docs/               glossary, protocol synopsis, SAP excerpt, CRF/raw/SDTM notes, TFL shells, submission
renv.lock               package versions (Posit Package Manager snapshot 2026-10-12)
```

Main packages: {admiral}/{admiralonco} (ADaM), {gsDesign} (sample size, power,
group sequential design, conditional power), {rtables} + {tern} (all TFLs),
{survival}/{ggsurvfit}, {diffdf} (QC), {xportr} (XPT). gt is used only for
small summary tables on the slides, not for TFLs.

## Rules that keep the project from drifting

1. **Single source of truth.** Code on a slide comes from `lab/R/*.R` through
   `## ---- label ----` markers and `knitr::read_chunk()`; numbers on a slide come
   from inline R. Never paste code or type results into the slides by hand.
   If you rename or split a chunk label, update `slides/index.qmd`.
2. **Data.** Only `pharmaversesdtm` / `pharmaverseadam` (CDISC pilot study,
   plus pharmaverse's synthetic RECIST data `rs_onco`), and only through the
   source data: `lab/source_data.R` cuts them to our two arms and exports CSV
   files plus `metadata.csv` (labels, types) to `lab/data/source/`, and checks
   that every file reads back unchanged. Lab programs and slides read the
   source data with `read_source()` and never call `pharmaversesdtm::` or
   `pharmaverseadam::` directly. Raw data are reverse-engineered from the source
   SDTM (`02_reverse_raw.R`). Do not simulate or tweak efficacy data to get a
   nicer story; report what the data show. After changing `source_data.R`, run
   it (`Rscript lab/source_data.R`) before `run_all.R`.
3. **Acronyms.** Spell out every acronym the first time it appears on a slide
   or in a document; never invent new abbreviations. Keep
   `lab/docs/00_glossary.md` and the glossary slides in sync (same acronyms).
   The deck has one glossary, in the Appendix; the "Today" slide spells out its
   own acronyms in a footnote. Each file in `lab/docs/` (and `lab/README.md`)
   starts with an "Acronyms in this document" line.
4. **Content first, not timing.** Do not plan slides around a time budget,
   and do not put minutes or timing targets on slides or in speaker notes.
   Judge a slide by its content: is it correct, clear, and useful to the
   audience?
5. **Design numbers live in `DESIGN` (00_setup.R).** The protocol synopsis and
   SAP (`lab/docs/01`, `02`) restate them: change all three together, then
   re-render.
6. **English** in slides, docs and code comments. Slides use simple English
   for readers with English as a second language: short sentences, common
   words, no idioms, and nouns instead of a vague "it". Keep R sources ASCII
   (write non-ASCII characters as `\uXXXX` escapes).
7. **Reproducibility.** After adding a package: `renv::snapshot()` with
   `options(repos = c(CRAN = "https://packagemanager.posit.co/cran/2026-10-12"))`
   (or a newer dated snapshot), then check that every record in `renv.lock` has
   `"Repository": "CRAN"`, not a `__linux__/.../latest` URL. After any
   change to `lab/` or `slides/`: `Rscript lab/run_all.R`, then
   `quarto render slides/index.qmd`, and commit the regenerated outputs.
8. Upstream objects are loaded with `need(object, script)`, which checks the
   **global environment only**: {ggsurvfit} ships an example dataset called
   `adtte` that would fool a plain `exists()`.

## Key decisions and why

* **Primary endpoint: PFS by investigator (RECIST 1.1), derived with
  admiral/admiralonco from `pharmaversesdtm::rs_onco`** (205 patients with
  assessments). `pharmaverseadam::adtte_onco` has only 6 PFS events (it is built
  from `rs_onco_recist`, 8 patients), too few for a log-rank test.
* **Two arms**: our trial is High Dose vs Placebo, 1:1. The pilot's Low Dose
  arm is removed from every SDTM and ADaM dataset in the source data, so raw
  data, SDTM and ADaM all describe the same two-arm trial. 222 screened
  (52 screen failures), 170 randomized (86 Placebo, 84 High Dose).
* **CSV**: the lab's data are CSV (easy to check and diff); the slides say that
  a submission uses XPT with define.xml, not CSV.
* **Endpoints**: primary PFS; key secondary OS; secondary ORR and DCR; safety.
  Sensitivity analysis: PFS by BICR (the adjudicated read, `RSACPTFL = "Y"`),
  same programs and table layout.
* **Hypothesis and design** ({gsDesign}, Schoenfeld method): H0: HR = 1 vs
  H1: HR < 1, one-sided alpha 2.5%, power 80%, design HR 0.60 (placebo median
  1.7 months -> High Dose 2.8). Slide order: events for a fixed design (120.3)
  -> patients (P(event) 0.74, 164) -> group sequential design with analyses at
  50%, 75%, 100% of the **total** events, Lan-DeMets O'Brien-Fleming spending,
  efficacy bounds only -> **123 events**, interims at **62** and **93**,
  **166 patients** -> power analysis (HR 0.5-0.8). The user chose HR 0.6 so
  that the design fits the 123 events in the data (HR 0.8 would need ~640).
* **Futility**: non-binding, conditional power under the current trend < 10%
  (not a Z boundary). SSR (sample size re-estimation) is only mentioned.
* **Multiplicity**: fixed-sequence gatekeeping PFS -> OS -> ORR -> DCR, order
  fixed before unblinding.
* **Interim data cuts**: cut-off = date of the event that reaches 62 / 93 total
  PFS events = 2013-08-15 / 2014-01-30. The same ADaM functions (`cut_adsl()`,
  `derive_adrs()`, `derive_adtte()`) build every cut.
* **Final analysis** uses all data: 123 events; the final boundary is recomputed
  from the actual information (Z >= 2.016).
* **Results are what they are**: interim 1 Z = 0.26 (HR 0.93), CP 27.4% under
  the design HR and 1.0% under the current trend, so the futility rule is met;
  final HR 1.02, one-sided p = 0.596, so PFS is not rejected and the chain stops.
  OS has 2 deaths (both Placebo): the median and the HR are shown as "NC"
  (not calculated); the OS table and Kaplan-Meier figure are still produced.
* **TFLs**: {rtables} + {tern} (the user's preference), every table has a
  Total column; comparison rows (HR, log-rank, rate difference) appear in the
  High Dose column only. One layout (`lyt_tte()`) serves Tables 14.2.1, 14.2.3,
  14.2.4 and IA.1. Disposition: screened and screen failures (Total column
  only), ITT, safety, discontinued treatment + reasons, discontinued study +
  reasons. AE overview shows TEAEs by maximum severity (mild/moderate/severe).
* **Clean logs**: `lab/run_all.R` must run with no warnings or errors (an
  industry QC standard the lecture teaches).
* **QC example**: forward-mapped DM / AE / CM are compared with the source
  SDTM using {diffdf}; one difference is kept on purpose (a spec ambiguity in
  `RFENDTC`, patient 01-710-1083). AE and CM match fully. (The pilot's
  `AESTDY` reference error was in a Low Dose patient and left with that arm.)
* **Actual arm**: 12 High Dose patients never received 81 mg. In the two-arm
  trial they started the High Dose regimen, so `ACTARM`, `TRT01A` and `TRTA`
  are High Dose in the source data, and the SDTM mapping in `03` uses
  actual arm = planned arm.
* **Concomitant medications**: most pilot records are "UNCODED"; the table shows
  them by verbatim name under "Not yet coded".
* **Data cut-off** is always written out; do not use the abbreviation "DCO".
* **Synthetic data**: the slides say that all data are synthetic test data
  from pharmaverse and that no real patient data are used.
* **Links to the repository** on slides (code, data, docs) always point to the
  `main` branch: use `gh("path")` in `slides/index.qmd`, which builds
  `https://github.com/pzhang724/cu-survival-fall-2026/blob/main/<path>` (`tree/`
  for a folder ending in `/`). Never link to a feature branch.
* No mermaid diagrams: their labels were clipped in revealjs. Flow diagrams are
  HTML boxes styled in `columbia.scss` (`.flow`, `.box`).
* **Logos and font size**: Columbia logo bottom-left, CIMS logo bottom-right on
  every slide (white badge so they also read on the navy section slides). The
  slide-menu button that used that corner is hidden; press `M` for the menu.
  Base font is 36px on a 1600 x 900 canvas, tables are scaled by 1.15 in
  `slide_gt()` (gt) and `slide_rt()` (rtables, styled by `.rt-slide`). Keep content out of the bottom ~75px band (footer and logos);
  check every slide after edits.

## Commands

```bash
Rscript -e 'renv::restore()'          # install the locked package versions
Rscript lab/run_all.R                 # whole pipeline, about 30 s
quarto render slides/index.qmd        # about 45 s; re-runs the pipeline
```

GitHub Pages (https://pzhang724.github.io/cu-survival-fall-2026/) is built by
`.github/workflows/publish-slides.yml`: on pull requests it only renders (a
check that the pipeline still runs); on pushes to `main` it renders and deploys.
It restores packages from `renv.lock` and pins Quarto 1.10.19, so keep the
lockfile current. Pages must be set to "Source: GitHub Actions" in the
repository settings (one-time).

Environment used to build: R 4.6.1, Quarto 1.10.19. If the shell locale is
`C`, prefix commands with `LANG=C.UTF-8`. To check layout, screenshot every
slide (for example with Playwright) and look for clipped text or tables that
run into the footer.

## Before the lecture

- [x] Check the speaker line in the YAML header of `slides/index.qmd` (now "Peng Zhang, PhD · CIMS Global")
- [ ] Rehearse with the speaker notes (press `S` in the browser)
- [ ] Share the repository (Posit Cloud: New Project from Git Repository)
- [ ] Re-render after the last change and commit `slides/index.html` (offline backup)
- [ ] Check that the GitHub Pages site shows the latest version

## When a student asks Claude for help

Students may open this repository with Claude to work through the lab.
Explain what each script does in plain language, spell out acronyms, point to
the relevant document in `lab/docs/`, and help with the exercises listed in
`lab/README.md`, `lab/docs/03_crf_raw_sdtm.md` and on the "Try it yourself" slide. Keep the
original pipeline working: put exercise code in new files rather than editing
`lab/R/01..10`.
