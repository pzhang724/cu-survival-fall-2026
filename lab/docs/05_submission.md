# Submission package (statistician's checklist)

*Acronyms in this document:* FDA: US Food and Drug Administration; SDTM: Study
Data Tabulation Model; ADaM: Analysis Data Model; XPT: SAS Transport File; SAP:
Statistical Analysis Plan; aCRF / CRF: Annotated Case Report Form / Case Report
Form; cSDRG: Clinical Study Data Reviewer's Guide; ADRG: Analysis Data
Reviewer's Guide; CSR: Clinical Study Report; TFL: Tables, Figures and Listings;
ICH: International Council for Harmonisation; CSV: Comma-Separated Values;
ADTTE: Time-to-Event Analysis Dataset. Full list:
[`00_glossary.md`](00_glossary.md).

What the FDA receives, where it lives in the eCTD (electronic Common Technical
Document) module 5, and who usually prepares it.

```
m5/datasets/cdiscpilot01/
|-- tabulations/sdtm/      dm.xpt  ae.xpt  cm.xpt  ds.xpt  ex.xpt  lb.xpt  rs.xpt ...
|                          define.xml   acrf.pdf   csdrg.pdf
`-- analysis/adam/
    |-- datasets/          adsl.xpt  adrs.xpt  adtte.xpt  adae.xpt  adlb.xpt ...
    |                      define.xml   adrg.pdf
    `-- programs/          adtte.r.txt  t_14_2_1_pfs.r.txt ...
```

| Deliverable | What it is | Statistician's role |
|---|---|---|
| SDTM datasets (XPT v5) | Tabulated collected data | Review; check that SAP-relevant data are present |
| ADaM datasets (XPT v5) | Analysis datasets | Own the specifications; review traceability |
| define.xml (v2.x) | Machine-readable metadata for every dataset and variable | Review derivation descriptions |
| aCRF | Annotated blank CRF | - |
| cSDRG | SDTM reviewer's guide | - |
| ADRG | ADaM reviewer's guide: analysis sets, key derivations, data cut, software | Co-author |
| Analysis programs | Programs for primary and key secondary results, as text files | Make them runnable by a reviewer |
| Conformance report | Pinnacle 21 validation; every remaining issue explained in the reviewer's guides | Review explanations |
| CSR with TFLs | ICH E3 study report; TFLs in section 14, listings in 16 | Author statistical sections |

## Data formats: CSV for checking, XPT for submission

The lab keeps its data as CSV files (`lab/data/source/`, `lab/data/raw/`,
`lab/data/sdtm/`, `lab/data/adam/`). CSV is easy to open, check and compare in
any software and in git, but it keeps no types and no labels. A submission uses
SAS transport files (XPT version 5), described by define.xml; CSV is not a
submission format.

## Checks before you hand over

* XPT version 5 limits: dataset and variable names up to 8 characters, labels
  up to 40 characters, character values up to 200 bytes.
* Every ADaM variable in define.xml has a derivation, and the derivation text
  matches the code.
* Traceability: ADTTE records point back to their source (`SRCDOM`, `SRCVAR`,
  `SRCSEQ`).
* Re-running the submitted programs on the submitted datasets reproduces the
  CSR numbers.
* For R: record package versions (`renv.lock`, `sessionInfo()`), and describe
  them in the ADRG. The R Consortium R Submissions Working Group has run public
  pilot submissions to FDA with R-based TFLs, a Shiny app, and ADaM datasets
  built in R (see https://github.com/RConsortium/submissions-wg).

## In this lab

`lab/R/10_submission.R` applies a variable-level specification to ADTTE with
{xportr} (types, lengths, labels, order, formats) and writes
`lab/output/submission/adtte.xpt`, then reads it back with `haven::read_xpt()`.
