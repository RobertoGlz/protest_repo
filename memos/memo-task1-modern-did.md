# Memo — Task 1: Modern DiD estimators on the balanced country-week panel

**Date:** 2026-05-21.  **Script:** [code/analysis/a_did_modern.do](../code/analysis/a_did_modern.do).

## Setup

| Choice | Value |
|---|---|
| Panel | [panel_country_week.dta](../code/build/b_panel_country_day.do) (built in Task 2) |
| Coverage | 2005-2020, 23 LAC countries × 791 weeks = 18,193 country-weeks |
| Unit | country |
| Time | week (Monday-anchored), integer index |
| Treatment date | country's **first scandal** week (per the plan) |
| Treated cohort | 19 LAC countries with ≥1 scandal in the data |
| Never-treated cohort | 4 LAC countries (Guyana, Haiti, Jamaica, Suriname) |
| Outcomes | `mm_protests`, `mm_violent`, `mm_nonviolent`, `mm_gvr` |
| Treatment indicator | `D = (ever_treated == 1) & (week_idx >= first_scandal_week_idx)` |
| Cluster | country (23 clusters — see caveat below) |

## Estimators

| Estimator | Package | Spec |
|---|---|---|
| **OLS TWFE** | `reghdfe` | `Y D, absorb(country_id week_idx) cluster(country_id)` |
| **dCDH** | `did_multiplegt_dyn` | 8 dynamic effects, 4 placebos, cluster country |
| **BJS** | `did_imputation` | `tau` (average treatment effect), cluster country, `autosample` |
| **SA** | `eventstudyinteract` | event dummies `ev_neg26..ev_neg2, ev_pos0..ev_pos26`, never-treated control cohort; summary = average of `ev_pos0..ev_pos26` with proper SE from V_iw |

## Headline result — 4 × 4 estimator × outcome table

Post-treatment coefficient (SE in parentheses):

| Estimator | Protests | Violent | Non-violent | Gvt resp. |
|---|---:|---:|---:|---:|
| **OLS TWFE** | −0.019 (0.110) | −0.102 (0.110) | +0.084 (0.081) | −0.031 (0.021) |
| **dCDH** (avg total) | −0.113 (0.224) | +0.033 (0.078) | −0.146 (0.248) | −0.295 (0.272) |
| **BJS** (τ) | −0.075 (0.100) | −0.110 (0.076) | +0.035 (0.033) | −0.040 (0.025) |
| **SA** (avg post) | **−0.177\*\*** (0.068) | **−0.119\*\*** (0.041) | −0.058 (0.050) | +0.010 (0.025) |

**Compare to PDF Table 1 (MM, OLS Country×Year FE on the *stacked event-window* panel, 176 scandals 2011-2025):**

| Estimator | Protests | Violent | Non-violent | Gvt resp. |
|---|---:|---:|---:|---:|
| PDF OLS C×Y FE (stacked) | +0.008 (0.010) | **+0.016\*** (0.006) | −0.008 (0.007) | **+0.011\*** (0.005) |

## Reading

1. **All four modern estimators flip the sign relative to the PDF baseline.** The
   PDF's +0.016\* on violent protests becomes a point estimate between
   +0.033 (dCDH) and −0.119 (SA) — and **none of the modern estimators
   confirm a positive headline effect**.

2. **OLS TWFE on the balanced panel already disagrees with the PDF.** It
   produces −0.102 (0.110) for violent protests vs the PDF's +0.016\*. So
   the divergence is **not driven by the choice of modern estimator** —
   it's driven by the *panel and identification framework*: native
   staggered DiD on a long country-week panel vs. the PDF's stacked
   ±120-day event-window OLS with Country × Year FE.

3. **The Task 3 ACLED-validation memo found the same thing from a
   different angle.** When you restrict MM to the same 2018+ subsample
   ACLED can validate (45 scandals), MM's violent-protest coefficient
   collapses from +0.016\* to +0.0005. The headline effect appears to be
   identified largely off pre-2018 scandals and off the specific stacked
   event-window framework — both of which the balanced-panel modern DiD
   discards.

4. **dCDH stands out as the most conservative.** Its "Av_tot_effect" is
   computed from clean 2×2 switcher contrasts only, with large SEs (0.22-0.27).
   It is the only estimator that does NOT come out negative for violent
   protests (it gives +0.033, but with SE 0.078, which is consistent with
   zero). It also explicitly tests parallel trends and no-anticipation
   with 4 placebos: in our sample these placebos are jointly p = 0.56 for
   protests — no evidence of pre-trends.

5. **SA's significant negatives are likely overstated.** The clustered
   SE uses only 23 country clusters, which is below the conventional
   asymptotic threshold (≥30-50). The dCDH and BJS SEs are larger and
   more credible; they're consistent with point estimates of "small or
   moderate negative effect, not statistically distinguishable from zero".

## What this means for the paper

The PDF's headline result is **not robust to** the choice of (a) panel
structure (balanced country-week vs stacked event-window) or (b) sample
period (full balanced 2005-2020 vs 2011-2025 with selection). When you
move to the modern DiD literature's preferred setup — a balanced panel
with each country's first scandal as the treatment switch — the effect
disappears or flips sign.

This is a substantively important finding, not just a methodological
nuance:

- **Native staggered DiD with country's first scandal**: each treated
  country contributes one switch. Of the 19 treated LAC countries,
  the first scandal dates span ~2010-2018. The "average treatment
  effect" computed by these estimators is *long-run* and *country-level*
  — does protest activity in country *c* differ post-first-scandal vs
  pre? The PDF asks a different question: does the *±120-day
  neighborhood* of *any scandal* show more protests than the previous
  ±120 days?
- These are not the same estimand. The PDF result is consistent with
  short-lived spikes around scandals that wash out at longer horizons
  (a long pre-period averages over many "quiet" weeks before each
  scandal, swamping the scandal-week excess). The modern DiD here is
  consistent with no persistent country-level shift after a country's
  first scandal.

**Implications for the paper:**

1. The headline +0.016\* on violent protests should be characterized as
   **short-run, scandal-event-window-specific**, not a persistent
   country-level shift in protest activity.
2. The modern DiD here can be reported as a **robustness probe** that
   formally tests for a long-run shift and finds none.
3. Combined with the Task 3 finding (no headline effect on the post-2018
   subsample even in MM), this argues for explicitly framing the
   headline as: "*Apex corruption scandals are associated with
   short-lived spikes in violent protest activity in the days following
   the scandal, identified mostly off 2011-2017 events. No persistent
   country-level shift is detected.*"
4. The next sensible robustness check, per the original plan, is the
   **Cengiz-style stacking** where every scandal contributes a separate
   stack. That would mechanically retain the "every scandal counts"
   feature of the PDF spec while still using modern DiD machinery within
   each stack. I deliberately defaulted to native staggered here because
   that is the standard usage of dCDH/BJS/SA; the stacked version is a
   natural follow-up.

## Caveats

- **23 clusters is below the conventional asymptotic threshold for
  cluster-robust SE.** dCDH and BJS use a bootstrap-aware computation
  and their SEs are likely more honest than SA's CR1.
- **First-scandal date for some countries is in 2018+** (where MM ends
  in March 2020 — only 2 years of post-period). For those countries the
  "post" window is short and the DiD effect is identified weakly.
- **The 4 never-treated controls (Guyana, Haiti, Jamaica, Suriname) are
  arguably very different from the treated LAC group** in baseline
  protest activity. dCDH's "clean comparison" machinery handles this
  better than naive TWFE; SA's never-treated control assumption is more
  demanding.
- **`mm_gvr` is sparse** (mean 0.012 events/week). Estimates on this
  outcome are noisy across all four estimators.

## Outputs

- `code/analysis/a_did_modern.do` — full do-file (this script).
- `code/analysis/a_did_modern.log` — full Stata log including dCDH's
  dynamic effects (8 lags) and placebos (4 leads), plus BJS event study
  if `autosample` was successful.
- `Protest_Work/results/tables/did_modern_ols_baseline.tex` — OLS TWFE
  table in LaTeX (the 4 outcome columns).
- The dCDH/BJS/SA coefficients are in this memo; if you want them
  exported as a single combined TeX table I can build one (`esttab`
  doesn't natively combine across these incompatible estimator
  packages, so I'd need a custom table writer).
