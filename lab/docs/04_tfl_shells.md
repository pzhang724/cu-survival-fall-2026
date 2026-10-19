# TFL shells

Shells (mock tables) are written with the SAP, **before** any data exist. They
fix titles, populations, rows, columns, statistics and decimals, so programmers
and reviewers agree on the output. `xx` marks a number to be filled. Every
table has a **Total** column. The programs build the tables with {rtables} and
{tern}.

## TFL index

| Number | Title | Analysis set | Datasets | Program |
|---|---|---|---|---|
| Table 14.1.1 | Patient disposition | All screened | ADSL | `06_tfl_baseline.R` |
| Table 14.1.2 | Demographic and baseline characteristics | ITT | ADSL | `06_tfl_baseline.R` |
| Table 14.1.3 | Concomitant medications | Safety | ADCM | `06_tfl_baseline.R` |
| Table 14.2.1 | Progression-free survival | ITT | ADTTE | `07_tfl_efficacy.R` |
| Figure 14.2.1 | Kaplan-Meier plot of PFS | ITT | ADTTE | `07_tfl_efficacy.R` |
| Table 14.2.2 | Best overall response, ORR and DCR | ITT | ADRS | `07_tfl_efficacy.R` |
| Table 14.2.3 | Overall survival | ITT | ADTTE | `07_tfl_efficacy.R` |
| Figure 14.2.2 | Kaplan-Meier plot of OS | ITT | ADTTE | `07_tfl_efficacy.R` |
| Table 14.2.4 | Sensitivity analysis: PFS by BICR | ITT | ADTTE (BICR) | `07_tfl_efficacy.R` |
| Table 14.3.1 | Overview of TEAEs | Safety | ADAE, ADSL | `08_tfl_safety.R` |
| Table 14.3.2 | TEAEs by SOC and PT | Safety | ADAE | `08_tfl_safety.R` |
| Table 14.3.3 | Shift in CTCAE grade, liver and kidney tests | Safety | ADLB | `08_tfl_safety.R` |
| Table IA.1 | Interim analysis 1 of PFS (DMC closed report) | ITT at data cut-off | ADTTE (cut) | `09_interim.R` |
| Figure IA.1 | Kaplan-Meier plot of PFS at interim analysis 1 | ITT at data cut-off | ADTTE (cut) | `09_interim.R` |

## Table 14.1.1 Patient disposition (all screened patients)

| | Placebo (N=xx) | High Dose (N=xx) | Total (N=xx) |
|---|---|---|---|
| Patients screened | | | xx |
| Screen failures | | | xx |
| Randomized (ITT set) | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Received study drug (safety set) | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Discontinued study treatment | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| &nbsp;&nbsp;Reason 1 ... | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Discontinued study | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| &nbsp;&nbsp;Reason 1 ... | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |

Screening counts have no arm and appear in the Total column only. Percentages
use the number of randomized patients (N).

## Table 14.2.1 Progression-free survival by investigator (ITT set)

The same layout is used for Table 14.2.3 (OS), Table 14.2.4 (PFS by BICR) and
Table IA.1 (PFS at the interim data cut).

| | Placebo (N=xx) | High Dose (N=xx) | Total (N=xx) |
|---|---|---|---|
| Patients with event | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| &nbsp;&nbsp;Disease progression | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| &nbsp;&nbsp;Death | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Censored | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Median, months (95% CI) [a] | x.x (x.x - x.x) | x.x (x.x - x.x) | x.x (x.x - x.x) |
| Event-free rate at 3 months, % (95% CI) [a] | xx.x (xx.x - xx.x) | xx.x (xx.x - xx.x) | xx.x (xx.x - xx.x) |
| Hazard ratio vs placebo (95% CI) [b] | | x.xx (x.xx - x.xx) | |
| Log-rank chi-square (1 df) | | x.xxx | |
| One-sided p-value (log-rank) | | x.xxxx | |

[a] Kaplan-Meier; Brookmeyer-Crowley CI with log-log transformation.
[b] Unstratified Cox proportional hazards model, Efron ties.

## Figure 14.2.1 Kaplan-Meier plot of PFS (ITT set)

* x-axis: months since randomization; y-axis: PFS probability
* one line per arm, censoring marks, number at risk below the plot
* annotation: HR (95% CI) and one-sided log-rank p-value for High Dose vs placebo
* Figure 14.2.2 (OS) uses the same layout

## Table 14.2.2 Best overall response, ORR and DCR (ITT set)

| | Placebo (N=xx) | High Dose (N=xx) | Total (N=xx) |
|---|---|---|---|
| Complete response (CR) | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Partial response (PR) | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Stable disease (SD) | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Non-CR/non-PD | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Progressive disease (PD) | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Not evaluable (NE) | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| No post-baseline assessment | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| ORR (CR + PR) | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| &nbsp;&nbsp;95% CI (Clopper-Pearson) | (xx.x, xx.x) | (xx.x, xx.x) | (xx.x, xx.x) |
| &nbsp;&nbsp;Difference vs placebo, % (95% CI) | | xx.x (xx.x - xx.x) | |
| &nbsp;&nbsp;Two-sided p-value (chi-square) | | x.xxxx | |
| DCR (CR + PR + SD + non-CR/non-PD) | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| &nbsp;&nbsp;95% CI, difference, p-value | as for ORR | | |

## Table 14.3.1 Overview of TEAEs (safety set)

| | Placebo (N=xx) | High Dose (N=xx) | Total (N=xx) |
|---|---|---|---|
| Patients with any TEAE | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| By maximum severity: Mild / Moderate / Severe | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| TEAE related to study drug | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Serious TEAE | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| TEAE leading to death | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| Discontinued treatment because of an AE | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |

## Table 14.3.2 TEAEs by SOC and PT (safety set)

| System organ class / Preferred term | Placebo (N=xx) | High Dose (N=xx) | Total (N=xx) |
|---|---|---|---|
| Patients with at least one TEAE | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| SOC 1 (sorted by overall frequency) | | | |
| &nbsp;&nbsp;Patients with a TEAE in this SOC | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |
| &nbsp;&nbsp;PT 1 | xx (xx.x%) | xx (xx.x%) | xx (xx.x%) |

A patient is counted once per SOC and once per PT. PTs reported by at least 10%
of all patients (Total column).

## Table 14.3.3 Shift in CTCAE grade (safety set)

Rows: lab parameter, then baseline grade. Columns: arm (Placebo, High Dose,
Total), then worst post-baseline grade (Grade 0, 1, 2, ...). Cells: number of
patients.

## Table IA.1 Interim analysis 1 of PFS (DMC closed report)

Same rows and columns as Table 14.2.1, on the interim data cut. Footnotes:

* Data cut-off date; events at this look / planned events (information fraction)
* Efficacy boundary at this look (Z and one-sided p) and whether it was crossed
* Conditional power under the design HR and under the current trend
* Futility rule (non-binding, CP under the current trend < 10%): met / not met
