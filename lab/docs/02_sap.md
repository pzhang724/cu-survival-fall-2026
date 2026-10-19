# Statistical analysis plan (excerpt)

The sections a statistician writes first, and the ADaM variables that implement
them. Section numbers are illustrative.

## 4. Analysis sets

| Analysis set | Definition | ADSL flag | Used for |
|---|---|---|---|
| Screened | Signed informed consent | all ADSL records | Disposition |
| Intention-to-treat (ITT) | All randomized patients, analysed as randomized | `ITTFL = "Y"` | Disposition, demographics, efficacy |
| Safety | All patients who received at least one dose, analysed as treated | `SAFFL = "Y"`, `TRT01A` | Safety, concomitant medications |

Twelve patients randomized to High Dose stopped during the 54 mg start and never
received 81 mg; they are analysed as High Dose for efficacy (`TRT01P`) and as
Low Dose for safety (`TRT01A`).

## 5. General definitions

* **Study day**: date - first dose date + 1 for dates on/after first dose;
  date - first dose date before it (there is no day 0).
* **Baseline**: last non-missing value on or before the first dose date
  (`ABLFL = "Y"` in ADLB). Tumour baseline: screening scan.
* **Treatment-emergent AE (TEAE)**: AE that starts on or after the first dose
  and no later than 30 days after the last dose (`TRTEMFL = "Y"`).
* **Partial AE start dates**: missing day/month imputed to the first day/month,
  but not earlier than the first dose if in the same month (`ASTDTF` records
  the imputation). SDTM keeps the partial date; imputation happens only in ADaM.

## 6. Efficacy endpoints

### 6.1 Progression-free survival (primary)

`AVAL = ADT - STARTDT + 1` days, `STARTDT = RANDDT`. Event or censoring per the
rules below (adapted from the FDA guidance *Clinical Trial Endpoints for the
Approval of Cancer Drugs and Biologics*, 2018).

| Situation | Date of event / censoring | Outcome | ADaM implementation (admiral) |
|---|---|---|---|
| Progression documented (RECIST 1.1) | Date of first scan showing PD | Event | `event_source()` on ADRS `PARAMCD = "PD"` |
| Death before progression | Date of death | Event | `event_source()` on ADSL `DTHDT` |
| No progression, no death | Date of last adequate tumour assessment | Censored | `censor_source()` on ADRS `PARAMCD = "LSTA"` |
| No post-baseline assessment and no death | Date of randomization | Censored | `censor_source()` on ADSL `RANDDT` |
| New anticancer therapy before progression | Last adequate assessment before the new therapy | Censored | (not collected in this study) |
| Progression or death after two or more missed assessments | Last adequate assessment before the missed visits | Censored | Sensitivity analysis |

### 6.2 Objective response rate

Best overall response (BOR) by the investigator from randomization until
progression; ORR = proportion with BOR = CR or PR. Confirmation of response is
not required in a randomized trial (RECIST 1.1). Patients with no post-baseline
assessment count as non-responders.

### 6.3 Overall survival

Death from any cause; patients alive are censored at the last date known alive
(`LSTALVDT`).

## 7. Statistical methods

| Endpoint | Method |
|---|---|
| PFS | Unstratified log-rank test (one-sided); HR and 95% CI from an unstratified Cox model; Kaplan-Meier medians with 95% CI by Brookmeyer-Crowley (log-log transformation); KM rate at 3 months |
| ORR | Rate with exact Clopper-Pearson 95% CI; difference vs placebo with 95% CI (normal approximation); chi-square test (nominal) |
| OS | Descriptive (few deaths expected); formal test at a later data cut |
| Safety | Counts and percentages of patients; shift tables of CTCAE grade (baseline vs worst on treatment) |

All randomization was unstratified; in a trial with stratified randomization the
log-rank test and Cox model are stratified by the IRT strata.

## 9. Multiplicity

Fixed-sequence (hierarchical) testing at the full one-sided 2.5%:
PFS High Dose vs placebo -> PFS Low Dose vs placebo -> ORR High Dose vs placebo.
A hypothesis is tested only if every hypothesis before it was rejected.

## 10. Interim analysis

* **Timing**: when 61 PFS events (50% of 122) have occurred in High Dose + placebo.
  The data cut-off date is the date of the 61st event; all data up to the cut-off date
  are cleaned before the analysis.
* **Boundaries**: Lan-DeMets O'Brien-Fleming-type spending evaluated at the
  *actual* information fraction (observed events / 122).
* **Futility**: non-binding guideline Z < 0 (observed HR > 1); the DMC may also
  consider conditional power under the current trend.
* **Conditional power**: reported under the design HR (0.60), the current trend
  and H0, using the final boundary and 122 planned events.
* **Confidentiality**: interim results are seen only by the DMC and the
  independent statistician; the sponsor study team stays blinded.
