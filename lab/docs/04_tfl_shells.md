# TFL shells

Shells (mock tables) are written with the SAP, **before** any data exist. They
fix titles, populations, rows, statistics and decimals, so programmers and
reviewers agree on the output. `xx` marks a number to be filled.

## TFL index

| Number | Title | Analysis set | Datasets | Program |
|---|---|---|---|---|
| Table 14.1.1 | Patient disposition | ITT | ADSL | `06_tfl_baseline.R` |
| Table 14.1.2 | Demographic and baseline characteristics | ITT | ADSL | `06_tfl_baseline.R` |
| Table 14.1.3 | Concomitant medications | Safety | ADCM | `06_tfl_baseline.R` |
| Table 14.2.1 | Progression-free survival | ITT | ADTTE | `07_tfl_efficacy.R` |
| Figure 14.2.1 | Kaplan-Meier plot of PFS | ITT | ADTTE | `07_tfl_efficacy.R` |
| Table 14.2.2 | Best overall response and ORR | ITT | ADRS | `07_tfl_efficacy.R` |
| Table 14.3.1 | Overview of TEAEs | Safety | ADAE, ADSL | `08_tfl_safety.R` |
| Table 14.3.2 | TEAEs by SOC and PT | Safety | ADAE | `08_tfl_safety.R` |
| Table 14.3.3 | Shift in CTCAE grade, liver and kidney tests | Safety | ADLB | `08_tfl_safety.R` |
| Table IA.1 | Interim analysis of PFS (DMC closed report) | ITT at data cut-off | ADTTE (cut) | `09_interim.R` |

## Table 14.2.1 Progression-free survival by investigator (ITT set)

| | Placebo (N=xx) | Xanomeline Low Dose (N=xx) | Xanomeline High Dose (N=xx) |
|---|---|---|---|
| Events, n (%) | xx (xx.x) | xx (xx.x) | xx (xx.x) |
| &nbsp;&nbsp;Disease progression | xx (xx.x) | xx (xx.x) | xx (xx.x) |
| &nbsp;&nbsp;Death | xx (xx.x) | xx (xx.x) | xx (xx.x) |
| Censored, n (%) | xx (xx.x) | xx (xx.x) | xx (xx.x) |
| Median PFS, months (95% CI) [a] | x.x (x.x, x.x) | x.x (x.x, x.x) | x.x (x.x, x.x) |
| PFS rate at 3 months, % (95% CI) | xx.x (xx.x, xx.x) | xx.x (xx.x, xx.x) | xx.x (xx.x, xx.x) |
| Hazard ratio vs placebo (95% CI) [b] | Reference | x.xx (x.xx, x.xx) | x.xx (x.xx, x.xx) |
| One-sided p-value (log-rank) | | x.xxx | x.xxx |

[a] Kaplan-Meier; Brookmeyer-Crowley CI with log-log transformation.
[b] Unstratified Cox proportional hazards model.

## Figure 14.2.1 Kaplan-Meier plot of PFS (ITT set)

* x-axis: months since randomization (0, 1, ... 6); y-axis: PFS probability
* one line per arm, censoring marks, number at risk below the plot
* annotation: HR (95% CI) and log-rank p-value for High Dose vs placebo

## Table 14.2.2 Best overall response and ORR (ITT set)

| | Placebo (N=xx) | Low Dose (N=xx) | High Dose (N=xx) |
|---|---|---|---|
| Complete response (CR) | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Partial response (PR) | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Stable disease (SD) | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Progressive disease (PD) | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Not evaluable / no post-baseline assessment | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| ORR (CR + PR), n (%) | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| &nbsp;&nbsp;95% exact CI | xx.x, xx.x | xx.x, xx.x | xx.x, xx.x |
| Difference vs placebo, % (95% CI) | | xx.x (xx.x, xx.x) | xx.x (xx.x, xx.x) |

## Table 14.3.1 Overview of TEAEs (safety set)

| Patients with | Placebo (N=xx) | Low Dose (N=xx) | High Dose (N=xx) |
|---|---|---|---|
| Any TEAE | xx (xx%) | xx (xx%) | xx (xx%) |
| TEAE related to study drug | xx (xx%) | xx (xx%) | xx (xx%) |
| Severe TEAE | xx (xx%) | xx (xx%) | xx (xx%) |
| Serious TEAE | xx (xx%) | xx (xx%) | xx (xx%) |
| TEAE leading to death | xx (xx%) | xx (xx%) | xx (xx%) |
| Discontinued study because of an AE | xx (xx%) | xx (xx%) | xx (xx%) |

## Table 14.3.2 TEAEs by SOC and PT (safety set)

| System organ class / Preferred term | Placebo (N=xx) | Low Dose (N=xx) | High Dose (N=xx) |
|---|---|---|---|
| Patients with at least one TEAE | xx (xx%) | xx (xx%) | xx (xx%) |
| SOC 1 (sorted by overall frequency) | xx (xx%) | xx (xx%) | xx (xx%) |
| &nbsp;&nbsp;PT 1 | xx (xx%) | xx (xx%) | xx (xx%) |

A patient is counted once per SOC and once per PT.

## Table IA.1 Interim analysis of PFS (DMC closed report)

| Item | Value |
|---|---|
| Data cut-off date | YYYY-MM-DD |
| PFS events (placebo / High Dose) | xx / xx |
| Information fraction | xx / 122 = xx.x% |
| Hazard ratio (95% CI) | x.xx (x.xx, x.xx) |
| Log-rank Z; one-sided p-value | x.xxx; x.xxx |
| Efficacy boundary (Z; p) | x.xxx; x.xxxx |
| Futility guideline | Z < 0: met / not met |
| Conditional power (design HR; current trend) | xx.x%; xx.x% |
