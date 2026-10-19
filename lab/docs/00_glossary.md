# Glossary

Every acronym used in the slides and the lab, spelled out. When you meet a new
term in the course material it should be here; if it is not, please add it.

| Acronym | Full name | What it means in practice |
|---|---|---|
| aCRF | Annotated Case Report Form | The blank CRF with every field labelled by the SDTM variable it maps to; part of the submission |
| ADaM | Analysis Data Model | CDISC standard for analysis-ready datasets (ADSL, ADAE, ADTTE ...) |
| ADaMIG | ADaM Implementation Guide | Rules for building ADaM datasets |
| ADRG | Analysis Data Reviewer's Guide | PDF that explains the ADaM datasets to the FDA reviewer |
| ADSL | Subject-Level Analysis Dataset | One row per patient: treatment, analysis-set flags, key dates, baseline covariates |
| ADTTE | Time-to-Event Analysis Dataset | One row per patient per time-to-event parameter (PFS, OS): AVAL, CNSR, dates |
| AE | Adverse Event | Any untoward medical occurrence in a patient |
| ATC | Anatomical Therapeutic Chemical classification | Drug class hierarchy used by WHODrug |
| BDS | Basic Data Structure | ADaM structure: one row per patient per parameter per time point |
| BICR | Blinded Independent Central Review | Radiologists, blind to treatment, who re-read tumour scans |
| BOR | Best Overall Response | Best RECIST response recorded from randomization until progression |
| CDASH | Clinical Data Acquisition Standards Harmonization | CDISC standard for CRF fields, so they map cleanly to SDTM |
| CDISC | Clinical Data Interchange Standards Consortium | Organisation that publishes SDTM, ADaM, CDASH, define.xml |
| CI | Confidence Interval | |
| CI/CD | Continuous Integration / Continuous Delivery | Software practice: every change is tested and released automatically (used by {admiral}) |
| CM | Concomitant Medications | Other medicines the patient takes during the trial |
| CNSR | Censor | ADTTE variable: 0 = event, 1 = censored |
| CP | Conditional Power | Probability of a significant final result given the interim data and an assumed effect |
| CR / PR / SD / PD / NE | Complete Response / Partial Response / Stable Disease / Progressive Disease / Not Evaluable | RECIST 1.1 response categories |
| CRF | Case Report Form | The (electronic) form sites fill in for each patient |
| cSDRG | Clinical Study Data Reviewer's Guide | PDF that explains the SDTM datasets to the reviewer |
| CSR | Clinical Study Report | Final report of the trial (structure defined by ICH E3) |
| CSV | Comma-Separated Values | Plain-text table format; easy to check, but keeps no types or labels (the lab's data format, not a submission format) |
| CT | Controlled Terminology | CDISC code lists, e.g. SEX must be "F" or "M" |
| CTCAE | Common Terminology Criteria for Adverse Events | NCI grading scale (grade 1 mild ... grade 5 death); also used for lab values |
| DBL | Database Lock | Data are frozen; analysis can start |
| DCR | Disease Control Rate | Proportion of patients with BOR = CR, PR or SD (or non-CR/non-PD) |
| DMC | Data Monitoring Committee | Independent experts who review unblinded interim results (also called IDMC or DSMB, Data Safety Monitoring Board) |
| DSUR | Development Safety Update Report | Yearly safety report to regulators for a drug in development (ICH E2F) |
| DM / DS / EX / LB / RS / TU / VS | Demographics / Disposition / Exposure / Laboratory / Response / Tumor Identification / Vital Signs | SDTM domains |
| eCTD | electronic Common Technical Document | Folder structure of a regulatory submission; data go in module 5 |
| EDC | Electronic Data Capture | System the sites type CRF data into (e.g. Medidata Rave) |
| GSD | Group Sequential Design | Design with pre-planned interim analyses and stopping boundaries |
| HR | Hazard Ratio | |
| ICH | International Council for Harmonisation | Publishes E3 (CSR), E6 (GCP), E9 (statistics), E9(R1) (estimands) |
| IA / FA | Interim Analysis / Final Analysis | |
| IRT | Interactive Response Technology | Randomization and drug-supply system (also IxRS, IWRS) |
| ISO 8601 | International date-time standard | SDTM dates: "2014-01-02T08:30", partial "2014-01" |
| ITT | Intention-To-Treat | Analyse patients as randomized, regardless of what they received |
| KM | Kaplan-Meier | Non-parametric survival estimator |
| MedDRA | Medical Dictionary for Regulatory Activities | Dictionary for coding AEs: LLT (lowest level term) -> PT (preferred term) -> HLT -> HLGT -> SOC (system organ class) |
| NC | Not Calculated | Shown in a table when a statistic cannot be calculated, for example a hazard ratio when an arm has no events |
| OBF | O'Brien-Fleming | Conservative early stopping boundary |
| ODM | Operational Data Model | CDISC XML standard for exchanging collected (EDC) data |
| OCCDS | Occurrence Data Structure | ADaM structure for events/interventions (ADAE, ADCM) |
| ORR | Objective Response Rate | Proportion of patients with BOR = CR or PR |
| OS | Overall Survival | Time from randomization to death from any cause |
| PFS | Progression-Free Survival | Time from randomization to progression or death, whichever first |
| P21 | Pinnacle 21 | Software that checks datasets against CDISC and FDA rules |
| QC | Quality Control | Independent re-programming and comparison of outputs ("double programming") |
| RECIST | Response Evaluation Criteria in Solid Tumors (version 1.1) | Rules for measuring tumour response on scans |
| RTF | Rich Text Format | Usual file format for TFLs pasted into the CSR |
| SAP | Statistical Analysis Plan | Detailed, pre-specified description of every analysis |
| SDTM | Study Data Tabulation Model | CDISC standard for collected data, organised in domains |
| SDTMIG | SDTM Implementation Guide | Rules for building SDTM datasets |
| SRC | Safety Review Committee | Group (often internal to the sponsor) that reviews safety data at regular meetings |
| SSR | Sample Size Re-estimation | Pre-specified change of the target events or patients at an interim analysis, with methods that protect alpha |
| SUPPQUAL | Supplemental Qualifiers | SDTM datasets (SUPPDM, SUPPAE ...) for non-standard variables |
| TEAE | Treatment-Emergent Adverse Event | AE starting on/after the first dose (here: up to 30 days after the last dose) |
| TFL | Tables, Figures and Listings | The outputs of the analysis (also TLF) |
| WHODrug | World Health Organization Drug Dictionary | Dictionary for coding medications |
| XPT | SAS Transport File (version 5) | File format FDA requires for datasets |
