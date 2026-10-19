# Protocol synopsis (teaching version of CDISCPILOT01)

> **About the data.** The patients, treatments, dates, adverse events, labs and
> medications are the CDISC SDTM/ADaM Pilot study as distributed by
> [pharmaverse](https://pharmaverse.org) (`pharmaversesdtm`, `pharmaverseadam`):
> xanomeline transdermal patch vs placebo. The tumour-response data (`rs_onco`)
> are synthetic RECIST 1.1 assessments that pharmaverse attached to the same
> patients. For this course we treat the study as a two-arm oncology trial with
> a survival endpoint: High Dose vs placebo (the pilot's Low Dose arm is left
> out of the analysis datasets). All data are synthetic test data; no real
> patient data are used. The design numbers below were chosen for teaching; they
> are not from the original study.

| Item | Content |
|---|---|
| Title | A randomized, double-blind, placebo-controlled study of xanomeline transdermal patch in patients with refractory solid tumours |
| Study ID | CDISCPILOT01 |
| Phase / design | Phase 3, randomized 1:1, double-blind, parallel group, event-driven, two interim analyses |
| Treatments | Placebo patch; Xanomeline High Dose (81 mg/day, after a 54 mg start) |
| Population | Adults with a measurable solid tumour that progressed on standard therapy |
| Tumour assessments | RECIST 1.1 by the investigator at weeks 6, 12, 18 and 24 (independent central review as supportive) |

## Objectives and endpoints

| | Objective | Endpoint |
|---|---|---|
| Primary | Show that High Dose prolongs PFS compared with placebo | PFS: time from randomization to first documented progression (RECIST 1.1, investigator) or death from any cause |
| Key secondary | Survival | OS: time from randomization to death from any cause |
| Secondary | Tumour response | ORR: best overall response of CR or PR (confirmation not required) |
| Secondary | Disease control | DCR: best overall response of CR, PR or SD (or non-CR/non-PD) |
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
  metastatic colorectal cancer trials, e.g. CORRECT and RECOURSE), design HR = 0.60
  (with exponential survival, median 1.7 / 0.6 = 2.8 months on High Dose), 80% power.
* **Step 1, events (fixed design)**: Schoenfeld's formula gives **120.3 events**.
* **Step 2, patients (fixed design)**: uniform accrual over 24 months, 3 months
  minimum follow-up, 25% dropout by month 3; P(event by month 27) = 0.74 ->
  162.4 -> 164 patients.
* **Step 3, group sequential design** ({gsDesign}, Schoenfeld method): analyses at
  50%, 75% and 100% of the **total** number of PFS events (both arms pooled, counted
  blinded); Lan-DeMets O'Brien-Fleming-type alpha spending; efficacy boundaries
  only. 120.3 x 1.020 inflation = 122.7 -> **123 PFS events**, interims at
  **62** and **93** events; **166 patients (83 per arm)**.
* **Futility**: non-binding; the DMC may recommend stopping if conditional power
  under the current trend is below 10%. Because the rule is non-binding, the
  design has no futility boundary and alpha is not affected.

| Analysis | Events | Expected month | Efficacy boundary (Z) | Nominal one-sided p | HR at boundary |
|---|---|---|---|---|---|
| Interim 1 (50%) | 62 | 14.1 | 2.963 | 0.0015 | 0.47 |
| Interim 2 (75%) | 93 | 19.9 | 2.359 | 0.0092 | 0.61 |
| Final | 123 | 27.0 | 2.014 | 0.0220 | 0.70 |

* **Multiplicity**: fixed-sequence (gatekeeping) testing at the full one-sided
  2.5%, order fixed before unblinding: (1) PFS -> (2) OS -> (3) ORR -> (4) DCR.
  Testing stops at the first hypothesis that is not rejected.
* **Data Monitoring Committee**: an independent DMC reviews unblinded data at
  the two efficacy interims and holds regular safety reviews in between
  (safety data only); an independent statistician prepares the closed reports.

Code: `lab/R/01_design.R`.
