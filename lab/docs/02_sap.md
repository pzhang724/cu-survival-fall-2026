# Statistical analysis plan (excerpt)

The sections a statistician writes first, and the ADaM variables that implement
them. Section numbers are illustrative.

## 4. Analysis sets

| Analysis set | Definition | ADSL flag | Used for |
|---|---|---|---|
| Screened | Signed informed consent | all ADSL records | Disposition |
| Intention-to-treat (ITT) | All randomized patients, analysed as randomized | `ITTFL = "Y"` | Disposition, demographics, efficacy |
| Safety | All patients who received at least one dose, analysed as treated | `SAFFL = "Y"`, `TRT01A` | Safety, concomitant medications |

The trial has two arms (High Dose, placebo); the pilot's Low Dose arm is left
out of the analysis datasets. Twelve patients randomized to High Dose stopped
during the 54 mg start and never received 81 mg. They started the High Dose
regimen, so they are High Dose for both efficacy (`TRT01P`) and safety (`TRT01A`).

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

### 6.2 Overall survival (key secondary)

Death from any cause; patients alive are censored at the last date known alive
(`LSTALVDT`).

### 6.3 Response rates

Best overall response (BOR) by the investigator from randomization until
progression; ORR = proportion with BOR = CR or PR; DCR (disease control rate) =
proportion with BOR = CR, PR, SD or non-CR/non-PD. Confirmation of response is
not required in a randomized trial (RECIST 1.1). Patients with no post-baseline
assessment count as non-responders.

### 6.4 Sensitivity analysis

PFS by blinded independent central review (BICR): the same derivation and
methods, with the adjudicated read of the two independent radiologists
(`RSACPTFL = "Y"`) instead of the investigator's read.

## 7. Statistical methods

| Endpoint | Method |
|---|---|
| PFS | Unstratified log-rank test (chi-square with 1 df; one-sided Z for the group sequential test); HR and 95% CI from an unstratified Cox model (Efron ties); Kaplan-Meier medians with 95% CI by Brookmeyer-Crowley (log-log transformation); KM rate at 3 months |
| OS | Same methods as PFS; few deaths expected, so a formal test at a later data cut |
| ORR, DCR | Rate with exact Clopper-Pearson 95% CI; difference vs placebo with 95% CI (Wald); chi-square test |
| Safety | Counts and percentages of patients; shift tables of CTCAE grade (baseline vs worst on treatment) |

All randomization was unstratified; in a trial with stratified randomization the
log-rank test and Cox model are stratified by the IRT strata.

## 8. Computation conventions

Percentages with one decimal; HR with two decimals; p-values with four
decimals. CI methods and the handling of ties are named above, because R and
SAS defaults differ (for example Efron vs Breslow ties). Software: R with the
package versions locked in `renv.lock`.

## 9. Multiplicity

Fixed-sequence (gatekeeping) testing at the full one-sided 2.5%, in an order
fixed before unblinding: PFS -> OS -> ORR -> DCR. A hypothesis is tested only
if every hypothesis before it was rejected; the first failure stops the chain.

## 10. Interim analyses

* **Timing**: when the total number of PFS events (both arms, counted blinded)
  reaches 62 (50% of 123) and 93 (75%). The data cut-off date is the date of the
  event that reaches the target; all data up to the cut-off date are cleaned
  before the analysis.
* **Boundaries**: Lan-DeMets O'Brien-Fleming-type spending evaluated at the
  *actual* information fraction (observed events / 123).
* **Futility**: non-binding; the DMC may recommend stopping if conditional power
  under the current trend is below 10%.
* **Conditional power**: reported under the design HR (0.60), the current trend
  and H0, using the final boundary and 123 planned events.
* **DMC safety reviews**: between the efficacy interims, the DMC reviews safety
  data only, at regular meetings.
* **Confidentiality**: interim results are seen only by the DMC and the
  independent statistician; the sponsor study team stays blinded.
