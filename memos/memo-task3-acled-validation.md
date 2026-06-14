# Memo — Task 3: Validating Mass Mobilization with ACLED

**Date:** 2026-05-21
**Author:** Roberto Gonzalez (with Claude)
**Scripts:**
[code/build/b_clean_ACLED.do](../code/build/b_clean_ACLED.do),
[code/build/b_merge_acled_mm.do](../code/build/b_merge_acled_mm.do),
[code/analysis/a_acled_validation.do](../code/analysis/a_acled_validation.do).

---

## 1. Setup

**Question.** Does Mass Mobilization (MM) — the protest-event source the
headline results in `Protests.pdf` rest on — agree with ACLED on the same
country-days, both at the aggregate level and when used as a replacement
on the LHS of the headline Country×Year FE specification?

**ACLED extract used.**
`ACLED Data_2026-05-21.csv` from the ACLED Data Export Tool (LAC +
US/Canada + Caribbean, both `Protests` and `Riots` event types):
- 385,452 events, 53 countries, **2018-01-01 to 2025-05-21**.
- `event_type`: Protests 247,543 / Riots 29,302 / Violence against civilians 108,607 (excluded).
- The full sub-event-type set the plan asked for (Peaceful protest, Protest
  with intervention, Violent demonstration, Mob violence, Excessive force
  against protesters) is present.

**ACLED → MM-outcome mapping (matches the plan exactly).**

| Outcome | ACLED rule |
|---|---|
| Any protest | `event_type ∈ {Protests, Riots}` (276,845 events) |
| Violent protest | `event_type == Riots` (29,302) — equivalently `sub_event_type ∈ {Violent demonstration, Mob violence}` |
| Peaceful protest | `sub_event_type == "Peaceful protest"` (240,769) |
| Gvt. violent response | `sub_event_type == "Excessive force against protesters"` (779) |

**Coverage constraint.** MM's clean `MMclean_full_bydate.dta` ends
2020-03-31. Overlap window for the agreement panel: **2018-01-01 to
2020-03-31**, 24 countries that appear in both sources, **19,704
country-days**.

---

## 2. Aggregate agreement on the 2018-2020 country-day grid

### Density gap

| Outcome | MM mean / country-day | ACLED mean / country-day | ACLED / MM ratio |
|---|---:|---:|---:|
| Protests | 0.020 | 2.63 | ≈ 130× |
| Violent | 0.006 | 0.46 | ≈ 75× |
| Peaceful | 0.014 | 2.08 | ≈ 150× |
| Gvt response | — (not in MM bydate) | 0.019 | — |

ACLED is roughly **two orders of magnitude denser** than MM on protests
and peaceful events, and ~75× denser on violent ones. MM logs a small
curated set of *notable* protests; ACLED logs essentially every reported
event. This means slope coefficients will be small and R² low even when
the two sources are picking up the same signal.

### (a) `regress MM_count on ACLED_count`

| Outcome | Slope | SE | R² |
|---|---:|---:|---:|
| Protests | 0.00265 | 0.00009 | **0.040** |
| Violent | 0.01197 | 0.00029 | **0.077** |
| Peaceful | 0.00198 | 0.00008 | **0.027** |

The slopes are tiny by construction (different scales). R² is **4–8%** —
real positive association, but ACLED counts explain only a small fraction
of MM variance at the daily level.

### (b) Spearman rank correlation on counts

| Outcome | ρ |
|---|---:|
| Protests | 0.130 |
| Violent | 0.098 |
| Peaceful | 0.074 |

All highly significant (p < 0.001) but **modest**. The rank correlation
across country-days is between 0.07 and 0.13.

### (c) 2×2 agreement on `>0` indicators

Of the 19,704 country-days, how often do MM and ACLED both record
≥1 event?

| Outcome | Neither (00) | Only MM (10) | Only ACLED (01) | Both (11) | Cohen's κ |
|---|---:|---:|---:|---:|---:|
| Protests | 10,472 (53.1%) | 74 (0.4%) | 8,856 (44.9%) | 302 (1.5%) | **0.028** |
| Violent | 15,700 (79.7%) | 42 (0.2%) | 3,892 (19.8%) | 70 (0.4%) | **0.024** |
| Peaceful | 11,415 (57.9%) | 89 (0.5%) | 8,019 (40.7%) | 181 (0.9%) | **0.017** |

Two observations from these tables:
1. **Conditional on MM logging a protest, ACLED catches it ~63–80% of the
   time** (e.g. of 376 MM-protest days, 302 are also flagged by ACLED).
   So MM is essentially a *subset* of ACLED's event universe.
2. **Conditional on ACLED logging a protest, MM almost never does** (3.3%
   of ACLED-protest days have an MM protest). MM is a *curated* subset.
3. Kappa is near zero because the marginal frequencies are so unbalanced.
   Once you adjust for chance agreement, MM and ACLED barely covary at
   the binary daily level.

### Reading of Part 2

**MM and ACLED are not measuring the same thing.** ACLED is a near-complete
event log; MM logs notable protests. Their daily counts correlate modestly
positively (Spearman ρ ≈ 0.1, R² ≈ 0.04–0.08), and MM events are usually
also in ACLED (60–80%), but ACLED events are rarely in MM (3–7%). For the
scandal study this means MM is a *selectivity-filtered* measure of protest
activity. The question is whether scandal-driven spikes show up the same
way in both.

---

## 3. Table 1 replication with ACLED on the LHS

The headline spec from `Protests.pdf` Table 1 was OLS with Country×Year FE,
month + day-of-week absorbed, clustered on country × year × 30-day bin,
±120-day event window. Re-running it on the **same scandal event-window
panel** but restricted to dates ≥ 2018-01-01 (the ACLED coverage), with
ACLED counts on the LHS:

**Sample:** 45 scandals contribute (of the 176 in the PDF — these are the
post-2018 ones); N = 8,678 country-day rows.

| Outcome | Post Scandal coef | SE | R² |
|---|---:|---:|---:|
| Protests | **−0.242** | 0.140 | 0.530 |
| Violent | **−0.111** | 0.060 | 0.256 |
| Peaceful | −0.085 | 0.090 | 0.513 |
| Gvt. violent response | **−0.038** | 0.020 | 0.202 |

Three coefficients are negative and approach significance at 10%
(protests p = 0.086, violent p = 0.065, gvr p = 0.052). Compare to the
PDF Table 1 (MM, 176 scandals, 2011-2025):

| Outcome | PDF Table 1 (MM, 176 scandals) | ACLED 2018+ (45 scandals) |
|---|---:|---:|
| Protests | 0.008 (0.010) | **−0.242 (0.140)** |
| Violent | 0.016\* (0.006) | **−0.111 (0.060)** |
| Peaceful | −0.008 (0.007) | −0.085 (0.090) |
| Gvt. violent response | 0.011\* (0.005) | **−0.038 (0.020)** |

The sign on violent protests and gvt response **flips from positive to
marginally significantly negative**. At face value, this looks like
ACLED contradicts MM.

---

## 4. The reframe — MM vs ACLED on the *same* 2018+ subsample

The sample is *not* the same in §3 above. The PDF uses 176 scandals from
2011 onwards; the ACLED replication uses 45 scandals from 2018 onwards.
Before crediting ACLED with contradicting MM, the fair test is to run MM
on **exactly the same 45-scandal 2018+ panel** and compare.

Doing that (`acled_table1_mm_same_sample.tex`):

| Outcome | **MM, same 45-scandal 2018+ sample** | ACLED, same 45-scandal 2018+ sample |
|---|---:|---:|
| Protests | **−0.026 (0.016)** | −0.242 (0.140) |
| Violent | **0.0005 (0.008)** | −0.111 (0.060) |
| Peaceful | −0.026 (0.014) | −0.085 (0.090) |
| Gvt. violent response | 0.0000 (0.0001) | −0.038 (0.020) |

**This is the key finding.** On the same 2018+ subsample:

- **MM's violent-protest effect collapses from +0.016\* (full 176-scandal
  sample) to +0.0005 (45-scandal subsample)** — essentially zero.
- MM's gvt-response effect collapses from +0.011\* to ~0.
- ACLED's negative coefficients are larger in magnitude than MM's but
  point the same way: **both sources show no positive post-scandal effect
  on the 45 post-2018 scandals.**

So the apparent "ACLED contradicts MM" reading in §3 is wrong: the two
sources actually **agree** on this subsample (neither sees a positive
effect). The divergence in §3 is a *sample-composition difference*, not a
*data-source difference*. The headline +0.016\* on violent protests is
driven by **pre-2018 scandals**, which can't be tested with ACLED.

---

## 5. Bottom line

1. **As a daily measure, MM and ACLED are not interchangeable.** MM logs
   only a small curated set of notable protests (3–7% of ACLED protest
   days have an MM protest; the rest of ACLED-protest activity is below
   MM's reporting threshold). Daily-grid R² ≈ 0.04–0.08, Spearman
   ρ ≈ 0.07–0.13, Cohen's κ ≈ 0.02.

2. **Conditional on MM logging a protest, ACLED catches it 60–80% of the
   time.** So MM events are mostly in ACLED — MM is approximately a
   selectivity-filtered subset of ACLED.

3. **The Table 1 replication with ACLED on the LHS does NOT contradict
   MM.** When you put both sources on the same 45-scandal 2018+
   subsample, *both* show null-to-weakly-negative effects of post-scandal
   on all four outcomes. The PDF's headline +0.016\* on violent protests
   is identified mostly off pre-2018 scandals, where we cannot validate
   with ACLED.

4. **Implication for the paper.** Reporting an ACLED robustness check is
   feasible but should be framed as "on the post-2018 subsample, neither
   source shows the headline effect; the full-sample MM result is driven
   by 2011-2017 scandals." That's a *substantive* fact about the data
   the paper should engage with — it raises a real question about
   whether the headline effect is era-specific, and motivates trying to
   secure a longer ACLED extract (ACLED's LAC coverage runs back further
   for some countries; the current extract was filtered to 2018+).

## 6. Caveats

- **MM coverage ends 2020-03-31** in the clean file used here. If a more
  recent MM extract exists, the agreement comparison and the same-sample
  test should be rerun to extend through 2025.
- **ACLED's pre-2018 coverage in LAC varies by country**; a fuller
  back-extension would let us test the headline effect with ACLED
  directly. Worth checking ACLED's country-level start dates before
  concluding the 2018+ era is the right cutoff.
- `government_response_violent` is not in `MMclean_full_bydate.dta`;
  the same-sample MM column for this outcome uses the value carried in
  `protests_scandals_30days_v3.dta` (which is aggregated upstream from
  MM's full event file). It's flat-zero in the 2018+ subsample, which
  may reflect under-aggregation rather than absence; worth verifying.
- **n_scandals contributing = 45**, with full ±120-day windows that fall
  in ACLED coverage. Scandals dated in 2018-01 to 2018-04 have
  pre-windows truncated by the 2018-01-01 ACLED start — kept in the
  sample but with shorter pre-periods.

## 7. Outputs

- `Protest_Work/temp/ACLED/ACLEDclean_bydate.dta` — country-day ACLED
  counts (46,796 event-days).
- `Protest_Work/temp/MM_ACLED_panel_bydate.dta` — balanced country-day
  grid 2018-01..2020-03, 24 countries × 821 days = 19,704 rows.
- `Protest_Work/results/tables/acled_validation_agreement.tex` — slope
  and R² of MM~ACLED for the three outcomes.
- `Protest_Work/results/tables/acled_validation_2x2.csv` — 2×2 agreement
  counts and Cohen's κ for the `>0` indicators.
- `Protest_Work/results/tables/acled_table1_replication.tex` — PDF
  Table 1 spec re-estimated with ACLED on the LHS, 2018+ subsample.
- `Protest_Work/results/tables/acled_table1_mm_same_sample.tex` —
  **PDF Table 1 spec with MM on the LHS, restricted to the same
  2018+ subsample as the ACLED replication. This is the apples-to-
  apples test in §4.**
- Full Stata log: [code/analysis/a_acled_validation.log](../code/analysis/a_acled_validation.log).
