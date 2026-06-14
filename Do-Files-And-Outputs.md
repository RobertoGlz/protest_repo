# Do-files and outputs — session tracker (2026-05-15 → 2026-05-22)

What each do-file produced this session. Output paths are relative to
the user's Dropbox: `Protest_Work/` = `Corrupcion/Protest_Work/`,
`ES-Final/` = `Corrupcion/WORKING FOLDER/Event Study - Scandals/Data/final/`.
All scripts use `firstyear = 2008` (sweep applied 2026-05-21).

---

## 1. Build pipeline — `code/build/`

| Do-file | Produces |
|---|---|
| [b_clean_ACLED.do](code/build/b_clean_ACLED.do) | `Protest_Work/temp/ACLED/ACLEDclean_bydate.dta` — country-day ACLED counts (any / violent / peaceful / gvt response) for 2018-01..2025-05, 53 LAC + US/Canada countries |
| [b_merge_acled_mm.do](code/build/b_merge_acled_mm.do) | `Protest_Work/temp/MM_ACLED_panel_bydate.dta` — balanced country-day MM × ACLED panel, 2018-01..2020-03, 24 overlapping countries |
| [b_panel_country_day.do](code/build/b_panel_country_day.do) | `ES-Final/panel_country_day.dta` (daily, 254,104 rows) and `ES-Final/panel_country_week.dta` (weekly) — balanced country-time panels, 23 LAC countries, 1990-2020, with MM, ACLED, and scandal metadata |

---

## 2. Analysis — per-scandal effect distributions (Task 5)

| Do-file | What it does | Outputs in `Protest_Work/results/` |
|---|---|---|
| [per_scandal_effects.do](code/analysis/per_scandal_effects.do) | Per-scandal pre/post regressions in each scandal's ±30-day window. Plots by `official_involved` (3cat: President / SCJ-Sec / Others, keyword-based) AND by `official_class` (5cat with incumbency: Inc.Pres / Non-Inc.Pres / Inc.Gov / SCJ-Cong / Others, merging `scandals_classified.csv`). | `figures/per_scandal_{box,jitter}_<outcome>_w30_{3cat,5cat}.pdf` (16 figures), `per_scandal_effects_w30.dta` and `.csv` |
| [per_scandal_effects_presi_vs_others.do](code/analysis/per_scandal_effects_presi_vs_others.do) | Self-contained. **President (from `position`) vs Others.** Pools all non-president positions. 45 / 127 / 4 unclassified. | `figures/per_scandal_{box,jitter}_<outcome>_w30_presi.pdf` (8 figures), `per_scandal_effects_w30_presi.dta` |
| [per_scandal_effects_apex.do](code/analysis/per_scandal_effects_apex.do) | Self-contained. **President / Other Apex / Other Non-Apex.** Built from `position`; `sc_judge_congressman` is split (4 SC judges → Non-Apex, 13 congressmen → Apex). 45 / 27 / 100 / 4 unclassified. | `figures/per_scandal_{box,jitter}_<outcome>_w30_apex.pdf` (8 figures), `per_scandal_effects_w30_apex.dta` |
| [per_scandal_effects_presi_vs_others_w_outliers.do](code/analysis/per_scandal_effects_presi_vs_others_w_outliers.do) | Same President-vs-Others classification as above, but box plots **show outliers** (no `nooutsides`); box plots only, no jitter. | `figures/per_scandal_box_<outcome>_w30_presi_w_outliers.pdf` (4 figures) |
| [per_scandal_effects_apex_w_outliers.do](code/analysis/per_scandal_effects_apex_w_outliers.do) | Same President / Other Apex / Other Non-Apex classification as above, but box plots **show outliers**; box plots only, no jitter. | `figures/per_scandal_box_<outcome>_w30_apex_w_outliers.pdf` (4 figures) |

---

## 3. Analysis — weekend vs weekday (Task 4)

| Do-file | What it does | Outputs in `Protest_Work/results/tables/` |
|---|---|---|
| [a_weekend_vs_weekday.do](code/analysis/a_weekend_vs_weekday.do) | Splits the headline OLS + Poisson C×Y FE specs by whether the scandal date is Sat/Sun vs Mon-Fri, on both ±120-day (wide) and ±30-day (narrow) windows. 4 outcomes. Audit: day-of-week FE is already in the main spec. | 12 tables: `wkd_vs_wkend_{ols,poi}_w{120,30}d_{full,wend,wday}.tex` |

---

## 4. Analysis — MM × ACLED validation (Task 3)

| Do-file | What it does | Outputs |
|---|---|---|
| [a_acled_validation.do](code/analysis/a_acled_validation.do) | (i) Aggregate agreement on the 19,704-row 2018-2020 country-day grid (R², slope, Spearman, Cohen's κ for >0 indicators). (ii) PDF Table 1 spec re-estimated with ACLED on LHS (2018+, 45 scandals). (iii) Same spec with MM on LHS over the *same* 45-scandal subsample (apples-to-apples). | `tables/acled_validation_agreement.tex`, `tables/acled_validation_2x2.csv`, `tables/acled_table1_replication.tex`, `tables/acled_table1_mm_same_sample.tex` |

---

## 5. Analysis — modern DiD (Task 1)

| Do-file | What it does | Outputs in `Protest_Work/results/` |
|---|---|---|
| [a_did_modern.do](code/analysis/a_did_modern.do) | **Superseded.** Original weekly balanced country panel, native staggered DiD (treatment = country's first scandal). 4 estimators (OLS TWFE, dCDH, BJS, SA). Kept for reference. | `tables/did_modern_main.tex`, `figures/did_modern_es_<outcome>.pdf` |
| [a_did_modern_countrypanel.do](code/analysis/a_did_modern_countrypanel.do) | **Design 1 (current).** Country × 3-day-bin balanced panel; treatment = post first scandal; never-treated = scandal-free countries. 4 estimators overlaid in event-study plot. | `tables/did_modern_cp_main.tex` (4×4 estimator × outcome), `figures/did_modern_cp_es_<outcome>.pdf` (4) |
| [a_did_modern_stacked.do](code/analysis/a_did_modern_stacked.do) | **Design 2 (current).** Cengiz-stacked-by-scandal panel (1 treated + clean controls per ±30-day window); country × 3-day-bin observations. 4 estimators overlaid. | `tables/did_modern_stk_main.tex`, `figures/did_modern_stk_es_<outcome>.pdf` (4) |

---

## 6. Master runners

| Do-file | What it does |
|---|---|
| [`code/explore/_run_all_pdf_scripts.do`](code/explore/_run_all_pdf_scripts.do) | Re-runs the 21 `explore/` scripts that produce every table and figure in `Work_2026.tex`. Used for the year-sweep rerun. |
| [`code/analysis/_run_all_analysis.do`](code/analysis/_run_all_analysis.do) | Runs all `analysis/` scripts at `firstyear = 2008` (csdid_main.do excluded — slow bootstrap; a_acled_validation.do excluded — ACLED 2018 coverage, not affected by the year floor). Re-asserts globals before each script to survive any `clear all`. |

---

## 7. Year-floor sweep (no new files — bulk edits)

- All 21 `code/explore/a_*.do` scripts that feed `Work_2026.tex`: `year>=2009` → `year>=2008`; added `global work` to each (they previously inherited it from interactive sessions).
- All 16 `code/analysis/*.do` scripts with `local firstyear = 2011`: → `local firstyear = 2008`.
- One Task-1 script (`a_did_modern.do`): `keep if year >= 2005` → `keep if year >= 2008`.

---

## 8. Memos and results notes

| File | Topic |
|---|---|
| [Summary-Work-Until-20260515.md](Summary-Work-Until-20260515.md) | Section-by-section summary of `Protests.pdf` (the initial deliverable) |
| [results-task5-per-scandal-distribution.md](results-task5-per-scandal-distribution.md) | Task 5 — per-scandal distribution by official type (3cat + 5cat incumbency split) |
| [results-task4-weekend-vs-weekday.md](results-task4-weekend-vs-weekday.md) | Task 4 — weekend vs weekday + main-spec dow audit |
| [memos/memo-task1-modern-did.md](memos/memo-task1-modern-did.md) | Task 1 — modern DiD on the (weekly) balanced panel; 4×4 estimator × outcome table |
| [memos/memo-task2-balanced-panels.md](memos/memo-task2-balanced-panels.md) | Task 2 — balanced country-day and country-week panels |
| [memos/memo-task3-acled-validation.md](memos/memo-task3-acled-validation.md) | Task 3 — MM × ACLED agreement + Table 1 replication with ACLED |

---

## 9. Key dataset filenames (quick reference)

| Path | Contents |
|---|---|
| `ES-Final/protests_scandals_30days_v3.dta` | Scandal × ±~120-day event-window panel (the source of Work_2026.tex's tables) |
| `ES-Final/protests_scandals_30days_v3_with_lv_of_agent_involved.dta` | Same + `official_involved` (keyword: President / SCJ-Sec / Others) |
| `ES-Final/scandals_classified.csv` | Manual classification per scandal: `position` (president/governor/sc_judge_congressman/other_judiciary/others) and `political_affiliation` (incumbent/opposition/different_constituency) |
| `ES-Final/panel_country_day.dta` | Balanced country-day, 23 LAC, 1990-2020, MM + ACLED + scandal metadata |
| `ES-Final/panel_country_week.dta` | Weekly aggregation of the above |
| `Protest_Work/temp/MM/MMclean_full_bydate.dta` | MM cleaned, country-day counts (any / violent / peaceful), 1990-2020-03, 160 countries |
| `Protest_Work/temp/MM/MMclean_full.dta` | MM cleaned, one row per protest event (used to recompute aggregations including `violence_against_peacefulprot` = gvt response) |
| `Protest_Work/temp/ACLED/ACLEDclean_bydate.dta` | ACLED cleaned, country-day counts, 2018-01..2025-05, 53 LAC + US/Canada countries |
| `Protest_Work/temp/MM_ACLED_panel_bydate.dta` | Balanced MM × ACLED overlap grid, 2018-01..2020-03, 24 countries |
