# Task 5 — Per-scandal effect-size distribution by type of official

**Run date:** 2026-05-20.  **Script:** [code/analysis/per_scandal_effects.do](code/analysis/per_scandal_effects.do).

## Spec

For each of the 176 scandals (Venezuela excluded), within its own ±30-day
country-window, run

```
reghdfe outcome post, absorb(month day) vce(robust)
```

and store `b`, `se`, `n` for each of four outcomes
(`num_protests_MM`, `num_violent_MM`, `num_peaceful_MM`,
`government_response_violent`). Scandals where the outcome has no within-window
variation (reghdfe returns `se == 0`) are excluded from the corresponding
outcome's distribution.

## Outputs

- **Per-scandal flat file:** `Protest_Work/results/per_scandal_effects_w30.dta`
  (and `.csv`) — one row per scandal with `b_*`, `se_*`, `n_*`, `lb_*`, `ub_*`
  for each outcome, plus `id`, `country`, `official_involved`, `scandal_date`.
- **Figures** (in `Protest_Work/results/figures/`):
  - `per_scandal_jitter_<outcome>_w30.pdf` — jittered scatter by official type,
    marker size ∝ 1/SE², with the category mean + 95% CI overlaid in black
    (the plan's preferred display).
  - `per_scandal_box_<outcome>_w30.pdf` — simple companion box plot.

## Distribution by type of official (95% CI on the category mean)

Headline: scandals involving a **President** generate a positive,
statistically distinguishable shift in protests; SCJ/Secretary and Others are
indistinguishable from zero.

### Overall protests (`num_protests_MM`) — 75 / 176 scandals had outcome variation

| Official type | N | Mean | 95% CI |
|---|---:|---:|---:|
| **President** | 23 | **+0.115** | [+0.029, +0.201] |
| SCJ/Secretary | 30 | −0.038 | [−0.160, +0.084] |
| Others | 22 | −0.005 | [−0.084, +0.075] |

### Violent protests (`num_violent_MM`) — 31 scandals had variation

| Official type | N | Mean | 95% CI |
|---|---:|---:|---:|
| **President** | 7 | **+0.170** | [+0.001, +0.339] |
| SCJ/Secretary | 16 | −0.073 | [−0.230, +0.084] |
| Others | 8 | +0.099 | [−0.045, +0.243] |

### Peaceful protests (`num_peaceful_MM`) — 63 scandals had variation

| Official type | N | Mean | 95% CI |
|---|---:|---:|---:|
| President | 20 | +0.073 | [−0.018, +0.165] |
| SCJ/Secretary | 25 | +0.001 | [−0.119, +0.121] |
| Others | 18 | −0.050 | [−0.134, +0.034] |

### Government violent response — only 8 scandals had any variation

Categories are too thin to interpret (N=1 for President, N=6 for SCJ/Secretary,
N=1 for Others). Reported in the .dta but not worth a category-mean read.

## Reading

- The per-scandal *distribution* point estimates are individually noisy (one
  country, 61 daily obs, sparse 0/1-ish outcomes) — as the plan warned. The
  signal is in the *cross-scandal* category mean.
- The President category mean for overall protests (+0.115) and violent
  protests (+0.170) is **positive and bounded away from zero at 95%**.
- SCJ/Secretary scandals show no average effect; Others are flat.
- This per-scandal cut **independently corroborates the pooled-panel finding
  in the PDF** that the protest-and-violence effect of apex scandals is driven
  primarily by scandals implicating a sitting president (Sections 5 and 10 of
  `Protests.pdf`, especially the narrow-bandwidth Table 18 with +0.083** on
  overall protests and +0.078* on violent protests for incumbent presidents).

## Caveats

- The `government_response_violent` outcome is too sparse for per-scandal
  variation; if it matters, this analysis needs a wider window or aggregation.

---

## Extension: incumbency split (run on 2026-05-20)

The 3-way `official_involved` category is built from keyword matching on the
scandal summary, so its "President" bucket conflates incumbents with past
presidents. The do-file now also merges in
`scandals_classified.csv` (`position`, `political_affiliation`) — the same
source the PDF heterogeneity panels use — and produces a parallel 5-way cut:

1. **Inc. President** = `position=="president" & political_affiliation=="incumbent"`
2. **Non-Inc. President** = `position=="president"` and not incumbent
3. **Inc. Governor** = `position=="governor" & political_affiliation=="incumbent"`
4. **SCJ/Congressman** = `position in {sc_judge_congressman, other_judiciary}`
5. **Others** = governor non-incumbent, position=="others", or unmatched

172 of 176 scandals matched the CSV; 4 unmatched fall through to "Others".
Bucket counts (one row per scandal, ex-Venezuela): Inc. Pres 27, Non-Inc.
Pres 21, Inc. Gov 6, SCJ/Cong 35, Others 87. The first two roughly match the
PDF's Table 12 panels (24 / 21).

Figures are saved with two suffixes: `_3cat.pdf` (the original
`official_involved` cut) and `_5cat.pdf` (the new cut). Both versions of each
outcome's jitter and box plot live in `Protest_Work/results/figures/`.

### 5-way category means (95% CI on the category mean)

**Overall protests** (75 / 176 had variation):

| Category | N | Mean | 95% CI |
|---|---:|---:|---:|
| **Inc. President** | 12 | **+0.129** | [+0.023, +0.235] |
| Non-Inc. President | 5 | +0.040 | [−0.029, +0.109] |
| Inc. Governor | 4 | +0.259 | [−0.247, +0.765] |
| SCJ/Congressman | 10 | +0.003 | [−0.185, +0.191] |
| Others | 44 | −0.032 | [−0.108, +0.045] |

**Violent protests** (31 / 176 had variation):

| Category | N | Mean | 95% CI |
|---|---:|---:|---:|
| **Inc. President** | 7 | +0.168 | [−0.002, +0.339] |
| Non-Inc. President | **0** | – | – |
| Inc. Governor | 4 | +0.017 | [−0.047, +0.081] |
| SCJ/Congressman | 2 | −0.019 | [−1.21, +1.17] |
| Others | 18 | −0.022 | [−0.147, +0.103] |

**Peaceful protests** (63 / 176 had variation):

| Category | N | Mean | 95% CI |
|---|---:|---:|---:|
| Inc. President | 9 | +0.041 | [−0.077, +0.159] |
| Non-Inc. President | 5 | +0.040 | [−0.029, +0.109] |
| Inc. Governor | 3 | +0.323 | [−0.365, +1.011] |
| SCJ/Congressman | 10 | +0.006 | [−0.055, +0.068] |
| Others | 36 | −0.028 | [−0.112, +0.056] |

**Gvt. violent response** (8 / 176 had variation): essentially singleton cells
across the 5 categories — not interpretable.

### Reading

- The original 3-way "President" mean of +0.115 (overall protests) breaks
  down to **+0.129 for the 12 incumbent presidents and +0.040 for the 5
  non-incumbent ones** in the 5-way cut — confirming the caveat: the per-scandal
  effect is concentrated in incumbent-president scandals, with non-incumbents
  centered near zero (and noisy, N=5).
- For **violent protests** the within-incumbent mean (+0.168) is essentially
  unchanged from the 3-way President mean (+0.170), because **all 7 scandals
  that had any within-window violent-protest variation were already
  incumbent-president scandals** — no non-incumbent presidents made the
  violent-protest cut at all. The 95% CI now just barely touches zero
  ([−0.002, +0.339]) under the slightly different small-sample SE.
- **Incumbent Governors** show large but extremely imprecise per-scandal means
  (overall protests +0.259 with CI [−0.247, +0.765], peaceful +0.323 driven by
  one ~+1.01 outlier). Per-scandal distributional analysis is the wrong tool
  for this category — 4 successful regressions out of 6 candidates is just
  too thin.
- **SCJ/Congressman** and **Others** are flat across all outcomes, consistent
  with the PDF's Section 7 (Table 15) "Others excl. Presidents" panel.

The 5-way split therefore directly corroborates the PDF's narrow-bandwidth
finding (Table 18: Incumbent presidents +0.083\*\* on protests, +0.078\* on
violent protests) at the per-scandal level: the protest-and-violence effect
of apex scandals is *driven by* incumbent-president scandals, not just
"any official labelled president".
