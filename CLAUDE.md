# CLAUDE.md

Guidance for Claude (and for people) working in this repository. Read it before
changing anything, and update it when a decision changes.

## What this repository is

* A **90-minute guest lecture** for the Survival Analysis course at Columbia
  University, Fall 2026. Lecture date: **Friday, November 13, 2026**.
* Theme: the practical work of a trial statistician on a randomized trial with a
  survival endpoint, in this order: protocol -> SAP (Statistical Analysis Plan)
  -> group sequential design and sample size -> CRF (Case Report Form) -> raw data
  -> SDTM -> ADaM -> TFL (Tables, Figures, Listings) shells and outputs ->
  interim analysis (p-value, conditional power, DMC report) -> submission.
* Audience: graduate biostatistics students who know survival theory but have
  not worked on an industry trial.
* Deliverables: the slide deck (`slides/index.qmd`, Quarto revealjs) and a
  shareable lab (`lab/`) that students run on Posit Cloud, locally, or with Claude.

## Layout

```
slides/index.qmd        the deck; runs lab/run_all.R and pulls code chunks from lab/R/
slides/columbia.scss    theme
slides/index.html       rendered, self-contained deck (committed for convenience)
lab/run_all.R           runs the whole pipeline (about 30 seconds)
lab/R/00_setup.R        packages, paths, DESIGN constants, helpers (need(), read_raw() ...)
lab/R/01..10_*.R        design, raw data, SDTM, ADSL, ADRS/ADTTE, TFLs, interim, submission
lab/data/raw/           reverse-engineered raw data (EDC-style CSV; lab file gzipped)
lab/data/spec/          study controlled-terminology map, visit schedule
lab/data/sdtm/, adam/   derived datasets written by the pipeline (CSV)
lab/output/             RTF tables, PNG figures, XPT file
lab/docs/               glossary, protocol synopsis, SAP excerpt, CRF/raw/SDTM notes, TFL shells, submission
renv.lock               package versions (Posit Package Manager snapshot 2026-10-12)
```

## Rules that keep the project from drifting

1. **Single source of truth.** Code on a slide comes from `lab/R/*.R` through
   `## ---- label ----` markers and `knitr::read_chunk()`; numbers on a slide come
   from inline R. Never paste code or type results into the slides by hand.
   If you rename or split a chunk label, update `slides/index.qmd`.
2. **Data.** Only `pharmaversesdtm` / `pharmaverseadam` (CDISC pilot study,
   plus pharmaverse's synthetic RECIST data `rs_onco`). Raw data are
   reverse-engineered from SDTM (`02_reverse_raw.R`). Do not simulate or tweak
   efficacy data to get a nicer story; report what the data show.
3. **Acronyms.** Spell out every acronym the first time it appears on a slide
   or in a document; never invent new abbreviations. Keep
   `lab/docs/00_glossary.md` and the glossary slides in sync.
4. **Time budget: 90 minutes.** Part 1 map 5 · Part 2 planning 25 · Part 3 data
   standards 20 · Part 4 TFLs 20 · Part 5 interim 12 · Part 6 submission and
   wrap-up 8. Adding a slide means removing or shortening another.
5. **Design numbers live in `DESIGN` (00_setup.R).** The protocol synopsis and
   SAP (`lab/docs/01`, `02`) restate them: change all three together, then
   re-render.
6. **English** in slides, docs and code comments. Keep R sources ASCII
   (write non-ASCII characters as `\uXXXX` escapes).
7. **Reproducibility.** After adding a package: `renv::snapshot()`. After any
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
* **Design**: High Dose vs Placebo, HR 0.60, placebo median 1.7 months,
  one-sided alpha 2.5%, power 80%, one interim at 50% of events, Lan-DeMets
  O'Brien-Fleming spending, non-binding futility Z < 0 -> **122 events**
  (interim at **61**), 166 patients for two arms, 249 for three (254 randomized).
* **Multiplicity**: fixed sequence PFS High -> PFS Low -> ORR High.
* **Interim data cut**: DCO = date of the 61st PFS event = 2013-08-08. The same
  ADaM functions (`cut_adsl()`, `derive_adrs()`, `derive_adtte()`) build both cuts.
* **Final analysis** uses all data: 123 events in High + Placebo; the final
  boundary is recomputed from the actual information (Z >= 1.969).
* **Results are what they are**: interim Z = 0.335 (HR 0.91), CP 32.5% under
  the design HR and 1.7% under the current trend; final HR 1.02, one-sided
  p = 0.596, so the primary hypothesis is not rejected and the hierarchy stops.
  The lecture uses this as a lesson about futility rules and conditional power.
* **QC example**: forward-mapped DM / AE / CM are compared with pharmaversesdtm
  using {diffdf}; two differences are kept on purpose (a spec ambiguity in
  `RFENDTC`, an error in the reference `AESTDY`).
* **Actual arm**: High Dose patients who never received 81 mg are Low Dose for
  safety (`ACTARM`, `TRT01A`); 12 patients.
* **Concomitant medications**: most pilot records are "UNCODED"; the table shows
  them by verbatim name under "Not yet coded".
* No mermaid diagrams: their labels were clipped in revealjs. Flow diagrams are
  HTML boxes styled in `columbia.scss` (`.flow`, `.box`).

## Commands

```bash
Rscript -e 'renv::restore()'          # install the locked package versions
Rscript lab/run_all.R                 # whole pipeline, about 30 s
quarto render slides/index.qmd        # about 45 s; re-runs the pipeline
```

Environment used to build: R 4.6.1, Quarto 1.10.19. If the shell locale is
`C`, prefix commands with `LANG=C.UTF-8`. To check layout, screenshot every
slide (for example with Playwright) and look for clipped text or tables that
run into the footer.

## Before the lecture

- [ ] Check the speaker line in the YAML header of `slides/index.qmd` (name taken from the repository's first commit; add title or affiliation if wanted)
- [ ] Rehearse with the speaker notes (press `S` in the browser); trim if over 90 minutes
- [ ] Share the repository (Posit Cloud: New Project from Git Repository)
- [ ] Re-render after the last change and commit `slides/index.html`

## When a student asks Claude for help

Students may open this repository with Claude to work through the lab.
Explain what each script does in plain language, spell out acronyms, point to
the relevant document in `lab/docs/`, and help with the exercises listed in
`lab/docs/03_crf_raw_sdtm.md` and on the "Try it yourself" slide. Keep the
original pipeline working: put exercise code in new files rather than editing
`lab/R/01..10`.
