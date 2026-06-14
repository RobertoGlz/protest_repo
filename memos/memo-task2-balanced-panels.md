# Memo — Task 2: Balanced country-day and country-week panels

**Date:** 2026-05-21.  **Script:** [code/build/b_panel_country_day.do](../code/build/b_panel_country_day.do).

## Outputs

| File | Path | N | Granularity |
|---|---|---:|---|
| `panel_country_day.dta` | `Event Study - Scandals/Data/final/` | 254,104 | country × calendar day |
| `panel_country_week.dta` | same | 36,317 | country × Monday-anchored week |

23 LAC countries (Argentina, Bolivia, Brazil, Chile, Colombia, Costa Rica,
Cuba, Dominican Republic, Ecuador, El Salvador, Guatemala, Guyana, Haiti,
Honduras, Jamaica, Mexico, Nicaragua, Panama, Paraguay, Peru, Suriname,
Uruguay, Venezuela).  Date range: **1990-01-01 to 2020-03-31** (the
full MM window).

## Schema (per the plan)

| Variable | Source | Description |
|---|---|---|
| `country`, `country_id`, `date`, `week_start`, `year`, `month`, `dow` | constructed | calendar / panel index |
| `mm_protests`, `mm_violent`, `mm_nonviolent`, `mm_gvr` | MM (aggregated from `MMclean_full.dta`, sum per country-date) | counts |
| `mm_*_ind` | derived | indicators `>0` |
| `acled_protests`, `acled_violent`, `acled_nonviolent`, `acled_gvr` | ACLED `ACLEDclean_bydate.dta` | counts; missing outside 2018-01-01..2025-05-21 |
| `acled_*_ind` | derived | indicators `>0`; missing outside ACLED coverage |
| `acled_coverage` | derived | 1 if date in ACLED window, else 0 |
| `scandal_today` | derived | 1 if a scandal broke in (country, date) |
| `scandal_id` | scandals | string scandal id when `scandal_today == 1` |
| `scandal_official_type` | `add_catvar_of_level_of_official_involved.do` | 1 President, 2 SCJ/Secretary, 3 Others |
| `scandal_position`, `scandal_political_affiliation` | `scandals_classified.csv` | the PDF Table 12-style classification |
| `first_scandal_date` | derived | per-country minimum scandal date |
| `days_since_first_scandal` | derived | `date − first_scandal_date` (negative pre-scandal) |

## Sanity checks (from the build log)

**Daily panel.** 254,104 rows = 23 countries × 11,047 days. Outcome means:

| Outcome | mean / day |
|---|---:|
| `mm_protests` | 0.038 |
| `mm_violent` | 0.012 |
| `mm_nonviolent` | 0.026 |
| `mm_gvr` | 0.0017 |

MM is highly zero-inflated (~96% of country-days are zero) — exactly why
the plan recommends weekly as the DiD default.

ACLED (only on `acled_coverage == 1`, i.e., 18,883 covered country-days):

| Outcome | mean / day |
|---|---:|
| `acled_protests` | 2.75 |
| `acled_violent` | 0.48 |
| `acled_nonviolent` | 2.17 |
| `acled_gvr` | 0.020 |

ACLED counts are ~70-130× denser than MM (see Task 3 memo for the
implications).

**Weekly panel.** 36,317 rows = 23 countries × 1,579 weeks. MM weekly
means: protests 0.267, violent 0.084, nonviolent 0.182, gvr 0.012 —
roughly 7× the daily means, as expected.

**Scandals on the panel.** 188 country-day rows have `scandal_today == 1`
(daily) and 185 weeks have a scandal (weekly). Note: this is ~4% above
the 176 scandals reported in PDF Table 1 (which dropped Venezuela and
required `year >= 2011`); the panel keeps all scandals across the full
1990-2020 window, hence the difference. The breakdown by
`scandal_official_type` matches the source-of-truth `add_catvar` build:
64 Presidents / 72 SCJ-Secretary / 52 Others = 188.

## Notes / caveats

- **MM ends 2020-03-31.** Any DiD/event study using this panel naturally
  truncates at that date; scandals after Mar 2020 cannot use MM outcomes.
  ACLED extends to 2025-05-21 for that subset.
- **Weekly is the recommended base for DiD.** Daily MM is so sparse that
  Poisson SEs collapse onto the few non-zero days; weekly aggregation
  smooths that out (compare daily means ≈ 0.04 to weekly means ≈ 0.27).
- **`first_scandal_date` is missing for countries that never have a
  scandal** in the 1990-2020 window. In the LAC universe this affects 4
  countries (Guyana, Haiti, Jamaica, Suriname — these have no scandals
  in the data). They are the natural "never-treated" controls for the
  Cengiz-style stacked DiD (Task 1).
- **Ties on (country, date) with two scandals on the same day** are
  resolved by keeping the first encountered (via
  `bysort country date: keep if _n == 1`). Spot-check after the build
  if you need a different tie-break rule.
- **Both panels also carry ACLED counts** even though the plan only
  asked for MM. This is free given the ACLED clean already exists and
  it lets Task 1 / robustness work use ACLED outcomes without a rebuild.
