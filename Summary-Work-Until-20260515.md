# Summary of Work Until 2026-05-15 — Protests Project

This document summarizes the contents of the results-tracking file `Protests.pdf`
("Protests Project — Tracking File"), as of 2026-05-15. It records every dated
working session, every table and figure, the main estimates, and the patterns
that emerge across specifications. Methodological detail is cross-referenced
with the do-files in `code/` where it clarifies what the numbers mean.

---

## 1. Research question and design

**Question.** Do apex (top-level) corruption scandals generate violence —
specifically, do they cause more protests, and more *violent* protests, in the
country where the scandal breaks?

**Identification logic (interrupted time series / event study around the
scandal date):**

1. Identify the exact date on which an apex corruption scandal becomes public.
2. Build a symmetric window of days around that date (the headline window is
   **±120 days**; a **narrow ±30-day** window is used as a robustness/sharpness
   check from the Feb 5, 2026 session onward).
3. On a country-date grid, code whether a protest occurred, and whether it was
   **violent** or **non-violent**, using the **Mass Mobilization (MM)** dataset.
   A fourth outcome codes a **government violent response** to a protest.
4. Compare protest activity **after** vs **before** the scandal via a `Post
   Scandal` indicator.

**Unit of observation.** A country-date (every table footnote states "An
observation is a country-date").

**Outcomes (four, in every table, columns 1–4):**

| Col | Outcome | MM variable (per code) |
|-----|---------|------------------------|
| (1) | Protests (any) | `num_protests_MM` |
| (2) | Violent Protests | `num_violent_MM` |
| (3) | Non-Violent / Peaceful Protests | `num_peaceful_MM` |
| (4) | Gvt. Violent Response | `government_response_violent` |

Two functional forms of the outcome are reported throughout:
- **Count** ("Number of …") — the raw protest count.
- **Indicator** ("Outcomes are Indicators", `> 0`) — a 0/1 dummy for whether at
  least one protest of that type occurred.

**Estimators.**
- **OLS** (`reghdfe`) with `Post Scandal` as the regressor.
- **Poisson** (`poisson … , irr`) reporting both the coefficient and the
  **Incidence Rate Ratio**, `exp(β)`.

**Fixed-effects schemes** (the PDF is organized around these):
- **Country × Year FE** (the main scheme).
- **Scandal FE** (`i.id_group`) — exploits only within-scandal variation; a
  demanding robustness check.
- Day-of-week and month FE are also absorbed inside the specs (see code).

**Standard errors.** Clustered at `C × Y × DB` = **Country × Year × Day-Bin**
(`country_id × year × grupo_dias`).

**Event-study figures.** Every table is paired with a four-panel
"Associated Interrupted Survey Design Plots" figure: coefficients at
30-day bins across ±120 days (wide window) or 6-day bins across ±30 days
(narrow window), 90% CIs, with the bin just before the scandal as the omitted
reference.

**Sample / data notes (from `code/`):**
- Source dataset: `protests_scandals_30days_v3.dta`, built by
  `b_merge_protests_scandals_eventwindow.do` (scandal rows expanded into a
  ±-day window and merged `m:1 country date` to cleaned MM data; missing
  protest counts set to 0).
- **Venezuela is dropped** in the main analysis files.
- First year of data used: **2011**.
- "**LB**" = **Latinobarómetro** — a secondary scandal list appended in the
  build (`corruption_news_LB.dta`, flagged `LB == 1`); Section 1.3 isolates
  scandals that intersect this Latinobarómetro set.
- "Number of Scandals" varies across columns in the Poisson tables because
  Poisson drops groups with all-zero outcomes (e.g. far fewer scandals
  contribute to the rare "Gvt. Violent Response" outcome).

---

## 2. Document structure

The PDF is a chronological tracking log. There are two working sessions:

- **January 29, 2026** — Sections 1–7 (main results, FE variants, official-type
  heterogeneity), wide ±120-day window.
- **February 5, 2026** — Sections 8–11 (narrow ±30-day bandwidth re-runs of the
  headline and heterogeneity specs).

19 tables and 19 figures in total.

---

## 3. January 29, 2026 — results (wide ±120-day window)

### Section 1 — Country × Year Fixed Effects, OLS

#### 1.1 OLS, all scandals

**Table 1 — OLS, all scandals (counts).** N = 42,449; 176 scandals.

| | (1) Protests | (2) Violent | (3) Non-Violent | (4) Gvt. Violent Resp. |
|---|---|---|---|---|
| Post Scandal | 0.008 (0.010) | **0.016\*** (0.006) | −0.008 (0.007) | **0.011\*** (0.005) |
| R² | 0.232 | 0.126 | 0.302 | 0.176 |

**Table 2 — same, outcomes as indicators.** N = 42,449; 176 scandals.
Post Scandal: 0.007 (0.009); **0.016\*** (0.006); −0.009 (0.007);
**0.011\*** (0.006).

*Reading:* The headline pattern. After a scandal, **violent protests rise
(~+0.016, significant at 10%)** and **government violent responses rise
(~+0.011, significant at 10%)**, while **non-violent protests do not rise (if
anything slightly negative)** and the *overall* protest count is not
significant. So the scandal effect is concentrated in the *violent* margin, not
in protest activity generally. Figures 1–2 show the event-study versions: no
clear pre-trend, with the violent and gvt-response panels drifting up post-zero.

#### 1.2 OLS, first scandal only when windows overlap

To avoid contaminating windows when two scandals in a country fall close
together, keep only the **first** scandal. N = 29,917; 124 scandals.

- **Table 3 (counts):** 0.017 (0.011); **0.016\*** (0.008); 0.001 (0.009);
  **0.014\*** (0.006).
- **Table 4 (indicators):** 0.015 (0.011); **0.016\*** (0.007); −0.001 (0.008);
  **0.014\*** (0.006).

*Reading:* The violent-protest and gvt-response effects are **robust** to
de-overlapping; magnitudes essentially unchanged (~0.016 and ~0.014). Figures
3–4 corroborate.

#### 1.3 OLS, only scandals that intersect LB

Restricting to the LB subset collapses to **28 scandals**, N = 6,748.

- **Table 5 (counts) / Table 6 (indicators):** 0.004 (0.060); 0.011 (0.010);
  −0.007 (0.060); −0.001 (0.001).

*Reading:* Nothing is significant — but with only 28 scandals the standard
errors explode (note the 0.060 SE on protests). This is a small-sample subset,
not evidence against the main result. Figures 5–6 are correspondingly noisy.

### Section 2 — Scandal Fixed Effects, OLS

Replacing Country × Year FE with **Scandal FE** (within-scandal variation only).
N = 42,449; 176 scandals.

- **Table 7 (counts) / Table 8 (indicators):** 0.001 (0.009); 0.008 (0.006);
  −0.006 (0.007); 0.004 (0.005).

*Reading:* Under the demanding scandal-FE design the point estimates **shrink
toward zero and lose significance** (violent protests fall from ~0.016 to
~0.008). The effect is identified largely off cross-scandal/country×year
variation; the pure within-scandal pre/post contrast is weaker. Figures 7–8.

### Section 3 — Country × Year FE, Poisson

**Table 9 — Poisson, all scandals.** Coef (SE) / IRR:

| | (1) Protests | (2) Violent | (3) Non-Violent | (4) Gvt. Resp. |
|---|---|---|---|---|
| Post Scandal | 0.122 (0.123) | **0.491\*** (0.195) | −0.229 (0.138) | 0.533 (0.300) |
| IRR exp(β) | 1.130 | **1.633** | 0.796 | 1.704 |
| N | 35,338 | 21,377 | 33,321 | 5,586 |
| Scandals | 152 | 97 | 148 | 40 |

**Table 10 — Poisson, first scandal (overlap).** N = 23,454 / 13,586 / 21,732 /
3,390. Post Scandal 0.218 (0.147); **0.711\*** (0.298); −0.057 (0.172); 0.720
(0.585). IRR: 1.243; **2.037**; 0.944; 2.055.

*Reading:* Poisson sharpens the story. **Violent protests rise ~63% (IRR 1.63,
sig.)** in the all-scandals spec and **double (IRR 2.04, sig.)** in the
first-scandal spec. Gvt response IRRs are large (~1.7–2.1) but imprecise;
non-violent protests sit below 1. Figures 9–10.

### Section 4 — Scandal FE, Poisson

**Table 11 — Poisson, all scandals, Scandal FE.** Post Scandal 0.020 (0.114);
0.127 (0.199); −0.153 (0.139); 0.050 (0.301). IRR 1.020; 1.135; 0.858; 1.051.
N = 33,258 / 16,388 / 32,535 / 3,441.

*Reading:* As with OLS, **Scandal FE absorbs the effect** — the violent IRR
drops from 1.63 to 1.14 and is no longer significant. Figure 11.

### Section 5 — Presidents: Incumbent vs Non-Incumbent

**Table 12 — OLS by type of president.**
- *Panel A — Incumbent presidents* (24 scandals, N = 5,784): Post Scandal
  0.029 (0.020); 0.026 (0.018); 0.003 (0.008); −0.000 (0.000).
- *Panel B — Non-incumbent presidents* (21 scandals, N = 5,061): 0.012 (0.014);
  −0.008 (0.005); 0.020 (0.013); −0.000 (0.000).

**Table 13 — Poisson by type of president.**
- *Panel A — Incumbent* (22/13/21/1 scandals): 0.640 (0.378); 0.478 (0.403);
  0.128 (0.367); 0.000 (.). IRR 1.897; 1.613; 1.136; 1.000.
- *Panel B — Non-incumbent*: −0.794 (0.631); 0.000 (.); −0.080 (0.658); 0.000
  (.). IRR 0.452; 1.000; 0.923; 1.000.

*Reading:* The effect appears **concentrated when a sitting (incumbent)
president is implicated** — point estimates are larger for incumbents (OLS
violent 0.026 vs −0.008; Poisson protests IRR 1.90 vs 0.45) — but small
subsamples make these **statistically imprecise** (nothing starred). The "Gvt.
Violent Response" Poisson columns barely identify (1 scandal). Figures 12–13.

### Section 6 — Incumbent Presidents vs Incumbent Governors

**Table 14 — OLS.**
- *Panel A — Incumbent presidents* (24 scandals, N = 5,784): identical to Table
  12 Panel A — 0.029 (0.020); 0.026 (0.018); 0.003 (0.008); −0.000 (0.000).
- *Panel B — Incumbent governors* (only **5 scandals**, N = 1,446): 0.131
  (0.080); 0.042 (0.053); 0.089 (0.056); 0.039 (0.051).

*Reading:* Incumbent-governor scandals show *larger* point estimates than
presidents (0.131 on overall protests) but rest on just 5 scandals — suggestive,
not conclusive. Figure 14.

### Section 7 — Incumbent Governors vs Others excluding Presidents

**Table 15 — OLS.**
- *Panel A — Incumbent governors* (5 scandals, N = 1,446): same as Table 14
  Panel B.
- *Panel B — Others excl. presidents* (113 scandals, N = 27,025): 0.011 (0.012);
  **0.019\*** (0.008); −0.008 (0.009); 0.011 (0.007).

*Reading:* The "other officials, excluding presidents" group (the large
residual category) **reproduces the headline violent-protest result**
(0.019\*, significant). Figure 15.

---

## 4. February 5, 2026 — narrow bandwidth (±30-day window)

This session re-runs the headline and heterogeneity specs on a **tight ±30-day
window** (6-day bins in the figures). Narrowing the window trades sample size
for sharper identification (less seasonal/secular contamination).

### Section 8 — OLS, all scandals, narrow bandwidth

**Table 16.** N = 10,675; 175 scandals.

| | (1) Protests | (2) Violent | (3) Non-Violent | (4) Gvt. Resp. |
|---|---|---|---|---|
| Post Scandal | **0.025\*\*** (0.009) | **0.016\*\*** (0.005) | 0.009 (0.008) | 0.006 (0.004) |
| R² | 0.369 | 0.161 | 0.473 | 0.219 |

*Reading:* **The narrow window strengthens the result substantially.** Overall
protests are now **significant at 5% (+0.025\*\*)** — they were insignificant in
the wide window — and violent protests stay at 0.016 but now at **5%
significance** (tighter SE, 0.005). The effect is sharper close to the scandal.
Figure 16 shows the post-scandal jump concentrated in the bins right after day 0.

### Section 9 — Poisson, all scandals, narrow bandwidth

**Table 17.** Post Scandal **0.391\*\*\*** (0.090); **0.448\*\*\*** (0.097);
0.223 (0.122); −0.043 (0.041). IRR **1.479**; **1.566**; 1.249; 0.958.
N = 7,012 / 3,961 / 6,393 / 365.

*Reading:* The **strongest results in the document.** Within ±30 days, overall
protests rise ~48% (IRR 1.48, p<0.01) and violent protests ~57% (IRR 1.57,
p<0.01) — both highly significant. Non-violent is positive but insignificant;
gvt response near 1. Figure 17.

### Section 10 — Presidents: Incumbent vs Non-Incumbent, narrow bandwidth

**Table 18 — OLS.**
- *Panel A — Incumbent presidents* (24 scandals, N = 1,464): **0.083\*\***
  (0.028); **0.078\*** (0.029); 0.005 (0.006); 0.000 (.).
- *Panel B — Non-incumbent presidents* (21 scandals, N = 1,281): 0.009 (0.007);
  0.000 (.); 0.009 (0.007); 0.002 (0.002).

*Reading:* In the narrow window the **incumbent-president channel becomes
significant**: overall protests +0.083\*\* and violent protests +0.078\* after
scandals implicating a sitting president, versus null effects for non-incumbents.
This is the clearest heterogeneity finding — scandals hurt most when the
*current* president is implicated. Figure 18.

### Section 11 — Incumbent Governors vs Others excluding Presidents, narrow bw

**Table 19 — OLS.**
- *Panel A — Incumbent governors* (5 scandals, N = 305): 0.252 (0.194); −0.008
  (0.038); 0.260 (0.186); −0.017 (0.029).
- *Panel B — Others excl. presidents* (112 scandals, N = 6,832): 0.009 (0.012);
  0.001 (0.005); 0.009 (0.010); −0.005 (0.003).

*Reading:* Governor point estimates are large (0.25 on protests) but, with 5
scandals and a 30-day window, statistically uninformative. The "others" group is
null in the narrow window. Figure 19.

---

## 5. Cross-cutting takeaways

1. **The core finding is a violence effect, not a generic protest effect.** In
   the wide-window main spec, apex scandals raise *violent* protests
   (~+0.016, 10%) and government violent responses (~+0.011, 10%), while
   non-violent protests are flat/negative and overall protest counts are
   insignificant.

2. **The effect is sharpest close to the scandal.** Tightening the window to
   ±30 days turns the overall-protest effect significant at 5% (OLS) and yields
   the document's strongest estimates under Poisson (IRR ≈ 1.48 overall, ≈ 1.57
   violent, both p<0.01). This is consistent with a short-lived, scandal-driven
   spike.

3. **Robust to de-overlapping; fragile to Scandal FE.** Keeping only first
   scandals preserves the result. Replacing Country×Year FE with Scandal FE
   shrinks everything toward zero — the identifying variation is largely
   cross-scandal / country×year, not purely within-scandal pre/post.

4. **Heterogeneity points to incumbent presidents.** Scandals implicating a
   *sitting* president drive larger effects; in the narrow window these become
   statistically significant (protests +0.083\*\*, violent +0.078\*), while
   non-incumbent-president scandals are null. Incumbent-governor estimates are
   large but rest on only 5 scandals.

5. **Poisson > OLS in magnitude and significance** for the count outcomes —
   expected given the heavy zero-inflation of daily protest counts (the
   `protests_plan.md` notes this is why future DiD work will default to weekly).

6. **Small-N caveats throughout.** The LB-only subset (28 scandals), the
   incumbent-governor panels (5 scandals), and several Poisson "Gvt. Violent
   Response" columns (often <25 contributing scandals, sometimes 1) are too thin
   to interpret beyond suggestive point estimates.

---

## 6. Open items (per `protests_plan.md`, not yet in the PDF)

The tracking file stops at the Feb 5, 2026 narrow-bandwidth runs. The working
plan lists five not-yet-reported next steps:

1. **Per-scandal effect-size distribution** by official type (`per_scandal_effects.do`).
2. **Weekend vs weekday scandals** sample split + adding `i.dow` FE to the main
   spec (currently day-of-week is only partially absorbed).
3. **Validate MM against ACLED** (aggregate agreement + Table 1 replicated with
   ACLED counts).
4. **Build a balanced country-day (and country-week) panel**.
5. **Re-estimate with modern DiD estimators** — dCDH (`did_multiplegt_dyn`),
   BJS (`did_imputation`), SA (`eventstudyinteract`) — on the balanced panel,
   stacked Cengiz-style by scandal, compared to the OLS/Poisson baselines above.

---

*Generated 2026-05-15 from `C:\Users\rob98\Downloads\Protests.pdf` (32 pages,
19 tables, 19 figures) and the build/analysis do-files in `protest_repo/code/`.*
