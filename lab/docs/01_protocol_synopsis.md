# Protocol synopsis (teaching version of CDISCPILOT01)

> **About the data.** The patients, treatments, dates, adverse events, labs and
> medications are the CDISC SDTM/ADaM Pilot study as distributed by
> [pharmaverse](https://pharmaverse.org) (`pharmaversesdtm`, `pharmaverseadam`):
> xanomeline transdermal patch vs placebo. The tumour-response data (`rs_onco`)
> are synthetic RECIST 1.1 assessments that pharmaverse attached to the same
> patients. For this course we treat the study as an oncology trial with a
> survival endpoint. The design numbers below were chosen for teaching; they are
> not from the original study.

| Item | Content |
|---|---|
| Title | A randomized, double-blind, placebo-controlled, three-arm study of xanomeline transdermal patch in patients with refractory solid tumours |
| Study ID | CDISCPILOT01 |
| Phase / design | Phase 3, randomized 1:1:1, double-blind, parallel group, event-driven, one interim analysis |
| Treatments | Placebo patch; Xanomeline Low Dose (54 mg/day); Xanomeline High Dose (81 mg/day, after a 54 mg start) |
| Population | Adults with a measurable solid tumour that progressed on standard therapy |
| Tumour assessments | RECIST 1.1 by the investigator at weeks 6, 12, 18 and 24 (independent central review as supportive) |

## Objectives and endpoints

| | Objective | Endpoint |
|---|---|---|
| Primary | Show that High Dose prolongs PFS compared with placebo | PFS: time from randomization to first documented progression (RECIST 1.1, investigator) or death from any cause |
| Key secondary | Low Dose vs placebo on PFS | PFS (as above) |
| Secondary | Tumour response | ORR: best overall response of CR or PR (confirmation not required) |
| Secondary | Survival | OS: time from randomization to death from any cause |
| Safety | Safety and tolerability | TEAEs (MedDRA), laboratory values (CTCAE grades) |

## Primary estimand (ICH E9(R1))

| Attribute | Definition |
|---|---|
| Population | All randomized patients (ITT set) |
| Treatment | Xanomeline High Dose vs placebo, each on top of best supportive care |
| Variable | PFS |
| Intercurrent events | Treatment discontinuation: treatment-policy strategy (keep scanning until progression). Death: part of the endpoint (composite strategy). Start of new anticancer therapy: hypothetical strategy (censor at the last adequate assessment before it) |
| Summary measure | Hazard ratio (Cox model), tested with the log-rank test |

## Statistical design

* **Hypothesis**: H0: HR (High Dose / placebo) = 1 vs H1: HR < 1, one-sided alpha = 2.5%.
* **Assumptions**: median PFS on placebo 1.7 months (as in placebo arms of refractory
  metastatic colorectal cancer trials, e.g. CORRECT and RECOURSE), target HR = 0.60
  (median 2.8 months on High Dose), 80% power.
* **Group sequential design**: one interim analysis at 50% of the events,
  Lan-DeMets O'Brien-Fleming-type alpha spending; non-binding futility guideline Z < 0.
* **Events**: Schoenfeld gives 120.3 events for a fixed design; x 1.012 inflation
  for the interim -> **122 PFS events** (High Dose + placebo). Interim at **61 events**.
* **Patients**: uniform accrual over 24 months, 3 months minimum follow-up,
  25% dropout by month 3 -> 164.3 -> **166 patients (83 per arm)** for the two arms
  of the primary comparison; with the Low Dose arm, **249 patients** (1:1:1).
  The study randomized 254.

| Analysis | Events | Efficacy boundary (Z) | Nominal one-sided p | HR at boundary | Futility (non-binding) |
|---|---|---|---|---|---|
| Interim | 61 | 2.963 | 0.0015 | 0.468 | Z < 0 (HR > 1) |
| Final | 122 | 1.969 | 0.0245 | 0.700 | - |

* **Multiplicity**: fixed-sequence testing at the full one-sided 2.5%:
  (1) PFS High Dose vs placebo -> (2) PFS Low Dose vs placebo -> (3) ORR High Dose vs placebo.
* **Data Monitoring Committee**: an independent DMC reviews unblinded safety
  data periodically and the efficacy interim; an independent statistician
  prepares the closed report.

Code: `lab/R/01_design.R`.
