# From CRF to raw data to SDTM

## 1. Collect what the SAP needs (and nothing else)

Work backwards from the SAP: every analysis variable must trace to a CRF field,
a vendor file, or a derivation.

| SAP need | Source | Raw file (`lab/data/raw/`) | SDTM |
|---|---|---|---|
| Randomized arm, randomization date | IRT vendor transfer | `irt.csv` | DM.ARM, DS (RANDOMIZED) |
| Age, sex, race, ethnicity | Demographics CRF | `dm.csv` | DM |
| First / last dose, dose received | Exposure log CRF | `ex.csv` | EX, DM.RFXSTDTC, DM.ACTARM |
| Progression (RECIST 1.1) | Tumour response CRF | `rs.csv` | RS |
| Death, end of study | End of Study CRF | `ds.csv` | DS, DM.DTHDTC |
| Adverse events | AE log CRF + MedDRA coding | `ae.csv` | AE |
| Concomitant medications | CM log CRF + WHODrug coding | `cm.csv` | CM |
| Laboratory values | Central laboratory transfer | `lb.csv.gz` | LB |
| Height, weight, blood pressure | Vital signs CRF | `vs.csv` | VS |

Specs (metadata, not data): `lab/data/spec/study_ct.csv` (CRF text <-> CDISC
controlled terminology) and `lab/data/spec/visit_schedule.csv` (visit names and
numbers, like the SDTM trial design dataset TV).

## 2. Annotated CRF: Adverse Event page

An annotated CRF (aCRF) labels each field with its SDTM target. Field names
follow CDASH, which makes most mappings one-to-one.

| CRF question | CRF field (CDASH) | Example raw value | SDTM variable | Rule |
|---|---|---|---|---|
| Adverse event term | AETERM | APPLICATION SITE ERYTHEMA | AE.AETERM | as collected |
| Start date | AESTDAT | 03 JAN 2014 / UN JAN 2014 | AE.AESTDTC | to ISO 8601; partial stays partial ("2014-01") |
| End date | AEENDAT | 11 JAN 2014 | AE.AEENDTC | to ISO 8601 |
| Ongoing? | AEONGO | Yes / No | (not submitted) | edit check: end date missing if ongoing |
| Severity | AESEV | Mild / Moderate / Severe | AE.AESEV | CT: MILD / MODERATE / SEVERE |
| Serious? | AESER | Yes / No | AE.AESER | CT: Y / N |
| Relationship to study drug | AEREL | None / Remote / Possible / Probable | AE.AEREL | CT (sponsor-defined list) |
| Outcome | AEOUT | Recovered/Resolved ... Fatal | AE.AEOUT | CT |
| (coding team) | AETERM_PT, AETERM_SOC ... | APPLICATION SITE ERYTHEMA | AE.AEDECOD, AE.AEBODSYS ... | MedDRA preferred term / system organ class |
| (derived) | - | - | AE.AESEQ, AE.AESTDY, AE.AEENDY | sequence within patient; study day vs RFSTDTC |

The other pages follow the same pattern. Points worth noticing:

* **Demographics**: the CRF collects the **birth date**; `AGE` is derived
  (age at the demographics visit).
* **Exposure**: the drug name is blinded on the CRF; `EXTRT` and `ARM` come from IRT.
  `ACTARM` is derived from the doses actually received.
* **Vital signs**: the CRF page is wide (one column per test); SDTM findings
  domains are long (one row per test) -> `pivot_longer()`.
* **Laboratory**: vendor file with its own codes, date format (YYYYMMDD) and both
  conventional and SI units.

## 3. How the raw data in this lab were made

pharmaverse provides SDTM only, so `lab/R/02_reverse_raw.R` **reverse-engineers**
raw data by undoing what the SDTMIG asks a sponsor to derive:

1. drop derived variables (`--SEQ`, `--DY`, `USUBJID`, `AGE`, reference dates);
2. ISO 8601 -> CRF text dates (`"2014-01"` -> `"UN JAN 2014"`);
3. controlled terminology -> CRF display values (`"F"` -> `"Female"`);
4. keep dictionary codes as separate coding columns;
5. reshape findings to the way forms and vendors deliver them.

`lab/R/03_raw_to_sdtm.R` then maps DM, AE and CM forward again and compares the
result with `pharmaversesdtm` using `diffdf` (the R analogue of SAS PROC COMPARE):

| Domain | Records | Values that differ | Root cause |
|---|---|---|---|
| DM | 306 | 1 | `RFENDTC` for 01-710-1083: reference used the page completion date (DSDTC), we used the event date (DSSTDTC). Spec ambiguity |
| AE | 1191 | 1 | `AESTDY` for 01-716-1063: AE starts on the first-dose date (day 1) but the reference says 366. Error in the reference data |
| CM | 7510 | 0 | - |

This is what real QC looks like: the differences are rarely bugs in one
program only; they expose unclear specifications and data issues.

## 4. Exercises

1. Map `raw/vs.csv` to SDTM VS (hint: `pivot_longer()`, units from the CRF,
   `VSSTRESN` in metric units) and compare with `pharmaversesdtm::vs`.
2. Map `raw/lb.csv.gz` to SDTM LB (vendor date format, `LBNRIND` from `FLAG`,
   baseline flag `LBBLFL`) and compare with `pharmaversesdtm::lb`.
3. Map `raw/rs.csv` to SDTM RS (investigator records only) and rebuild ADRS
   from your own RS.
4. Change the RFENDTC rule so that DM matches the reference. Should you?
