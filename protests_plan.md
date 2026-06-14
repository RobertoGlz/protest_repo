# Protests project — next steps

Working plan for the corruption-scandals → protests paper. Five tasks, ordered by dependency.

## Order of execution

1. **(5)** Per-scandal effect-size distribution — uses existing window-stacked data.
2. **(4)** Weekend vs weekday scandals — sample split on the existing scandal list.
3. **(3)** Validate Mass Mobilization with ACLED — independent of panel structure.
4. **(2)** Build balanced country-day panel — prerequisite for (1).
5. **(1)** Re-estimate with dCDH, BJS and SA on the balanced panel.

(5), (4) and (3) can be worked in parallel; they don't depend on each other or on (2).

---

## Task 1 — New DiD estimators (dCDH, BJS, SA)

Run `did_multiplegt_dyn` (dCDH), `did_imputation` (BJS) and `eventstudyinteract` (SA) on the balanced panel from Task 2. Compare to the OLS / Poisson baselines in `Protests.pdf`.

### Design choices
- **Unit:** country.
- **Treatment date:** first scandal in the analysis window for that country.
- **Multiple-scandal countries:** stack the data Cengiz-et-al.-style — for each scandal `s` build a clean ±T-day panel of country `c(s)` plus never-scandal controls in the same calendar window, tag by `s`, then pool with `s × time` fixed effects. Lets every scandal contribute and recovers a clean control cohort.
- **Control cohort:** countries with no scandal anywhere in the stack's calendar window.

### Existing scaffolding
- `code/analysis/bjs_main.do`, `bjs_main_w_month_day_fes.do`, `csdid_main.do`, `raw_mm_data_bjs.do`, `raw_mm_data_ppmlhdfe.do`.
- Will likely need new wrappers for dCDH and the stacked-by-scandal data builder.

### Outputs
- A 4 × 3 results panel: estimator (OLS, dCDH, BJS, SA) × outcome (any, violent, non-violent, gvt. response).
- Event-study figures matching the existing ±120 / ±30 plots.

---

## Task 2 — Balanced country-day panel

Build a balanced country × calendar-date panel covering the full Mass Mobilization period; merge protest counts and indicators (any / violent / non-violent / gvt. response) and a vector of scandal events with their exact dates and official-type metadata.

### Design choices
- **Daily, not weekly, as the base.** Daily preserves the exact scandal date (matters for Task 4) and aggregating to weekly is one `collapse` away.
- Store both daily and weekly versions on disk. Default the new-estimator regressions to **weekly** (zero-inflation at the daily level dominates Poisson SEs).
- Schema: `country, date, week_start, year, month, dow, mm_protests, mm_violent, mm_nonviolent, mm_gvr, scandal_today, scandal_official_type, days_since_first_scandal, …`.

### Outputs
- `${datfin}/panel_country_day.dta`
- `${datfin}/panel_country_week.dta`

---

## Task 3 — Validate Mass Mobilization with ACLED

Cross-check the protest counts against ACLED for the overlapping coverage period (full Latin American coverage from ~2018; earlier elsewhere — to be confirmed when the ACLED extract is in hand).

### Checks
1. **Aggregate agreement.** On the country-day grid, regress `mm_count` on `acled_count`; report R², slope, and the share of country-days where the two sources agree on `>0`. Repeat for the violent classification.
2. **Replicate Table 1 with ACLED.** Same specification, same outcome definitions, but ACLED counts on the LHS. Check whether the violent-protest and gvt-response coefficients survive the data-source swap.

### Mapping ACLED → MM categories
- *Any protest:* ACLED `event_type ∈ {Protests, Riots}`.
- *Violent protest:* ACLED `sub_event_type ∈ {Violent demonstration, Mob violence}` plus `event_type == Riots`.
- *Government violent response:* ACLED `sub_event_type ∈ {Excessive force against protesters}`.

### Outputs
- `code/build/b_clean_ACLED.do`, `code/build/b_merge_acled_mm.do`.
- A short note (`results/acled_validation.tex`) reporting the agreement statistics and the replicated Table 1.

---

## Task 4 — Weekend vs weekday scandals

Sample split by day-of-week of the scandal date. Two motivations:
- The scandal-day baseline differs by day of week. Weekend baselines are mechanically lower, so the post-scandal jump can look bigger. Heterogeneity check disciplines this.
- Weekend scandals may be more "exogenously timed" relative to the news cycle (less strategic timing).

### Design
- Heterogeneity version first: split by `dow(scandal_date) ∈ {Sat, Sun}` vs `{Mon–Fri}` and run the same OLS / Poisson C × Y FE specs on each.
- Add `i.dow` to the **main** specifications too — looking at `code/analysis/ols_main.do` it isn't currently absorbed, so the Post coefficient is partly soaking up the post-window day-of-week distribution. Worth doing regardless of whether the weekend-vs-weekday split survives.

### Outputs
- Two results panels (weekend / weekday) for the headline outcomes.
- An updated main spec with `i.dow` FE absorbed.

---

## Task 5 — Per-scandal effect sizes + boxplot

For each scandal, run the within-window pre/post regression on its own country and extract a single `Post Scandal` coefficient. Plot the distribution by official type.

### Design
- Per scandal `s`: `reg outcome post_scandal i.dow i.month` on the ±T-day window of country `c(s)`. Save `(scandal_id, official_type, b_s, se_s, n_s)`.
- Use the narrow ±30 window — fewer obs but tighter identification than ±120.
- Plot: `twoway scatter b_s official_type, jitter(5)` overlaid with category mean and 95% CI. More honest than `graph box` because it shows the small-N categories (governors with ~5 scandals).
- Optional: weight the points visually by `1/se_s²` so the eye doesn't confuse a noisy `b_s` with a sharp one.

### Caveats
- With one country and a ±T-day window the per-scandal regression has very limited FE leverage — individual `b_s` will be noisy. The point of this exercise is the *distribution*, not the individual estimates.

### Outputs
- `code/analysis/per_scandal_effects.do`
- `results/figures/per_scandal_distribution_by_official.pdf`
