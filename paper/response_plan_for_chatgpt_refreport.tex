# Referee-proofing plan — "Apex Corruption causes Violent Protests"

Synthesized from the ChatGPT "Science referee" report (2026). The reviewer's
recommendation is *reject / resubmit after major redesign*; the substance is
mostly fair. This document lists each issue and **2–4 concrete ways to tackle
it**, flagging (a) whether the data already support it, and (b) whether a
do-file already exists (often commented-out) that we can reactivate.

---

## The one-sentence critique we must answer

> We have not shown that it is the *apex nature* of the scandal — rather than the
> greater **salience, severity, media attention, and political-crisis context**
> that comes bundled with apex scandals — that drives violent protest.

Everything below serves that sentence. The reviewer is explicit that **more
conventional robustness checks will not move the needle** — the two highest-ROI
moves are:

1. **Measure scandal salience** and show the effect is not just salience (Issue 1).
2. **Classify protests by grievance** (corruption-related vs unrelated) and show
   the increase is concentrated in scandal-attributable protests (Issue 5).

If we do only two things before resubmission, do those two.

---

## TIER 1 — the analyses that decide the paper

### Issue 1. Apex vs Non-Apex conflates *rank* with *salience/severity*
The reviewer's #1 concern. Apex scandals differ from Non-Apex on ~20 dimensions
(media reach, monetary value, sitting-vs-former, prosecutorial involvement,
national scope, party stakes, …). We currently isolate none of them.

**Tackles**
- **(1a) Build a scandal-salience/severity index — WITHOUT depending on Twitter.**
  Recovering the original scooped tweets may not be feasible (the Twitter/X API
  access has changed and we may not have stored the tweet IDs/text), so lead with
  proxies we can reconstruct independently:
  - **Severity/magnitude from text we already have** (`scandal_descriptions_sources.md`
    and the classification table): monetary amount, number of officials implicated,
    sitting-vs-former, criminal/prosecutorial involvement, national-vs-local scope,
    corruption type. This alone supports the balance table and the matching in 1b —
    **no external API required.** Codable by hand or with a light LLM pass over the
    174 descriptions we already wrote.
  - **Google Trends** search interest for the official's name / scandal keyword by
    country around the disclosure date (public, no auth; `pytrends` or manual).
  - **News/attention volume** from open archives: GDELT article/event counts
    (strongest 2015+), Wikipedia pageviews for the official/scandal (2015+), and
    the outlet/article counts we can still cite from the sources already collected.
  - *(Optional, only if recoverable)* original tweet/retweet counts and number of
    distinct outlets from the scrape — treat as a bonus, not a dependency.

  Report a **balance table**: Apex vs Non-Apex means on each available proxy. Even
  the text-based severity index alone (first bullet) is enough to run the balance
  table and the salience-matched comparison, which is the part the referee cares
  about most.
- **(1b) Salience-matched sample.** Coarsened-exact-match or propensity-weight
  Non-Apex to Apex on the salience/severity covariates, then re-estimate. The
  key comparison the reviewer wants: **high-salience Non-Apex vs low-salience
  Apex**. If the apex gap survives matching, the rank story holds.
- **(1c) Horse-race / conditioning.** Add salience (and magnitude, current/former)
  as controls or interactions in eq. (1); show `β_Apex` survives conditioning on
  salience. Report how much of the gap salience explains.
- **(1d) Fine rank gradient.** Replace the binary with the full ladder
  (president / governor / SC justice / minister / agency head / congressman /
  mayor / lower judiciary / other) and test for a *monotonic* rank gradient.
  *Asset:* `a_sup_hierarchy_regression.do` + `sup:hierarchy` already exist
  (currently commented out) — extend the categories and reactivate.

**Feasibility:** 1d is ready now. 1a needs a salience-scraping/Google-Trends
pass (the biggest new data lift, but the single most important one). 1b/1c
follow mechanically once 1a exists.

---

### Issue 5. The outcome is *any* violent protest, not protest *about* corruption
The supplement's own examples make this vivid: the Colombia (bullfighting) and
Brazil-2012 (oil royalties) protests near Non-Apex scandals are unrelated to the
scandal. So the claim is currently "apex scandals raise violent protest
(including protests unrelated to corruption)", not "apex corruption causes
protest against corruption." The reviewer calls fixing this "the most powerful
improvement" and asks for it three separate times.

**Tackles**
- **(5a) Grievance classification.** MM already carries `protesterdemand1–4`,
  `protesteridentity`, `sources`, and `notes`. Classify each protest as
  corruption/accountability/anti-government/removal-of-official ("scandal-related")
  vs unrelated, using the demand codes plus a keyword/name match of the notes to
  the implicated official and scandal. Re-estimate on **scandal-related violent
  protests**.
- **(5b) The 2×2 "spectacular figure"** the reviewer sketches: event studies for
  {corruption-related, unrelated} × {peaceful, violent}, Apex vs Non-Apex. If the
  apex effect concentrates in corruption-related violent protests → strong causal
  story. If it's equal in unrelated protests → it's a *generalized political
  instability* story (still interesting, different paper). Either way we learn the
  mechanism.
- **(5c) Name/keyword attribution.** Flag protests whose MM `notes` name the
  implicated official or demand their resignation; show the apex effect is larger
  for these "attributable" protests.

**Feasibility:** all doable from existing MM fields — no new scraping. This is
the highest-value *low-cost* task. Start here in parallel with 1a.

---

## TIER 2 — design credibility (mostly reactivate/extend existing work)

### Issue 2. Identification: disclosure date may not be exogenous
"No pre-trend" only shows the *protest series* doesn't move before the coded
date; it doesn't show the date is exogenous to a brewing political crisis
(opposition leaks when the government weakens, prosecutors move during crises).

**Tackles**
- **(2a) Reframe the identifying assumption**: not "all disclosure dates are
  random", but "**conditional on a scandal existing, the timing of the scoop is
  as-good-as-random**." Lean on institutional/idiosyncratic triggers (court
  rulings, prosecutor announcements, foreign shocks like the US-DOJ Odebrecht
  filings, Panama/Pandora Papers) as plausibly-exogenous disclosure timing.
- **(2b) Condition on pre-existing instability.** Add the pre-window protest
  level / a crisis proxy (e.g., recent govt approval, prior-30-day protest count)
  as a covariate; show the jump survives.
- **(2c) Sharpen the placebo.** The enumerated pre-scandal cutoff placebo
  (`a_sup_placebo_within_window*.do`, `sup:placebo`) is already built and
  commented — reactivate it: it holds the sample fixed and only shifts the cutoff,
  which is exactly the "same event, different date" counterfactual the reviewer
  says RI lacks.
- **(2d) Google-Trends validation** (shared with 1a/3): show public attention
  spikes *at* the coded date, not before → supports the no-anticipation claim
  with an independent attention series.

### Issue 3. Treatment timing: "first tweet" ≠ true information arrival
**Tackles**
- **(3a) Alternative treatment dates**: first substantive disclosure, first
  major-national-outlet story, and the **Google-Trends peak day**; re-estimate and
  show the estimate is stable across definitions.
- **(3b) Validate that the first-tweet date coincides with the attention spike**
  (Google Trends / article counts). Where they diverge >N days, re-date and check.

### Issue 4. Overlapping event windows / contamination
The paper footnotes this; the reviewer wants it treated as first-order.

**Tackles**
- **(4a) Robustness battery**: (i) drop all overlapping windows; (ii) keep only
  scandals ≥60/90/120 days apart; (iii) first-scandal-per-country-year;
  (iv) one-randomly-chosen-scandal-per-country-year; (v) nearest-uncontaminated
  control periods. Show the apex effect survives.
- **(4b)** Present the already-existing separate-subsample estimates as one of
  these robustness rows, not as the whole answer.
- *Asset:* the stacked / clean-control DiD (`a_did_modern_stacked_*`, `sup:did`)
  builds clean control cohorts and is already written (commented) — it directly
  addresses contamination; reactivate + report.

### Issue 6. Inference with few clusters + serial correlation
Only ~16 countries; overlapping windows; 10k "observations" are not independent.

**Tackles**
- **(6a) Wild cluster bootstrap** at the country level (16 clusters — this is the
  textbook few-clusters fix).
- **(6b) Report a battery**: cluster by country; by country×year; two-way; and
  the existing country×year×day-bin — as a single robustness table.
- **(6c) Event-level randomization inference** (we already have RI — reframe it as
  the primary design-based inference and state the effective N = 174 scandals /
  16 countries clearly).

### Issue 7. Result may be driven by a few famous scandals
Temer/JBS, Pérez Molina, Casa Blanca, Lava Jato are enormous national crises.

**Tackles**
- **(7a) Country leave-one-out**: drop Brazil, Mexico, Guatemala, and the
  max-effect country; re-estimate.
- **(7b) Famous-event exclusion**: pre-specify and drop the top 5–10 scandals by
  salience (uses the Issue-1 salience index).
- **(7c) Within-country evidence** from countries with multiple apex scandals
  (Peru, Brazil, Mexico have many).
- *Asset:* scandal-level leave-one-out already exists (`a_loo_scandal_*`,
  `sup:loo`, now also for peaceful). Add the **country-level** and
  **famous-event** leave-outs and promote them to the main text.

---

## TIER 3 — mechanism, decomposition, and framing

### Issue 8. Persistence may be mechanical (protest-days coding)
MM codes a protest lasting X days on each of X dates, so one long protest can
manufacture "persistence."

**Tackles**
- **(8a) Onset-only outcome**: count protest **starts** (we already keep the
  earliest date) so each episode counts once; re-run the event study. If
  persistence survives on onsets, it's behavioral, not mechanical.
- **(8b) Report extensive vs intensive margins**: Pr(≥1 violent protest) per
  country-day; number of *distinct episodes*; total participants; cumulative
  protest-days; duration — as separate outcomes.

### Issue 9. Sparse outcome / functional form
Baseline ≈0.02/country-day. (Team decision: **OLS only — no Poisson/PPML/NegBin**;
see project memory. So answer this *without* count models.)

**Tackles**
- **(9a) Binary extensive margin** (LPM: any violent protest) — directly answers
  "is it a handful of spectacular episodes?"
- **(9b) IHS / winsorized / log(1+count) outcomes** as robustness (all OLS-family).
- **(9c) Leave-one-out (scandal + country)** front-and-center for the violent
  outcome (ties to Issue 7).

### Issue 10. Current vs former officials
Directly tests the political-stakes mechanism (sitting official controls the
state; former = historical accountability).

**Tackles**
- **(10a) Code current/former** office-holding at disclosure (the enriched
  scandal descriptions usually say "sitting"/"former" — largely codable from
  existing text). Split Apex into Current vs Former and re-estimate; predict
  Current > Former.

### Issue 11. Violence subtypes + "political violence" overclaim
"Violent vs peaceful" may be too coarse; Science readers read "political
violence" as fatalities/armed conflict.

**Tackles**
- **(11a) Decompose violence** where codable from MM `notes`/`stateresponse`
  (property damage, clashes with police, injuries/deaths, arrests, repression).
- **(11b) Framing:** relabel the outcome "violent protest mobilization"; reserve
  "political violence" unless we add fatality/injury measures. Cheap, do it now.

### Issue 12. Better placebo than football/currency
Football (info shock) and currency (economic shock) don't match a high-salience
corruption scandal.

**Tackles**
- **(12a)** The *within-corruption* placebo is the salience-matched Non-Apex
  comparison (Issue 1b) and the high-salience-non-corruption-apex-event
  comparison. Keep football/currency as supplementary specificity checks.

### Issue 13. Democracy heterogeneity is overinterpreted
Point estimates larger in more-democratic countries but equality not rejected.

**Tackles**
- **(13a) Framing:** present as suggestive; keep in the appendix (mostly already
  there); do not claim moderation. Or expand into a genuine mechanism section if
  we can get power. Low effort — a wording fix.

### Issue 14. Separate the three causal questions in the exposition
Q1 disclosure→protest (strongest), Q2 apex vs non-apex, Q3 *why* (weakest).

**Tackles**
- **(14a)** Restructure intro/abstract to state clearly what is identified vs
  suggested; stop letting the title imply Q3 is settled. Framing only.

---

## Suggested sequencing (what to build, in order)

1. **Grievance classification of protests** (Issue 5) — no new data; MM fields
   only; unlocks the 2×2 figure and reframes the whole contribution.
2. **Scandal-salience index** (Issue 1a) — the main new data lift
   (tweets/outlets/Google Trends). Enables 1b/1c, 7b, 12.
3. **Reactivate & extend existing appendix machinery**: hierarchy gradient
   (Issue 1d), enumerated placebo (2c), stacked clean-control DiD (4), scandal
   LOO → add country + famous-event LOO (7).
4. **Onset-only + extensive/intensive margins** (Issues 8, 9) — cheap, OLS-only.
5. **Current vs former Apex** (Issue 10) — code from existing descriptions.
6. **Inference battery**: wild cluster bootstrap + multi-level clustering +
   overlapping-window drops (Issues 4, 6).
7. **Framing pass**: three-questions restructure, "violent protest mobilization"
   relabel, democracy-as-suggestive (Issues 11b, 13a, 14).

## Constraints / notes
- **No Poisson/QML** anywhere (standing team decision) — answer the sparse-outcome
  point with binary/IHS/winsorized OLS + leave-one-out instead.
- Several referee "essentials" are **already coded and merely commented out**
  (hierarchy, placebo, restricted subsamples, modern DiD, per-scandal boxplots,
  full-sample RI). A large share of the revision is *reactivation + extension*,
  not building from scratch.
- Overlaps with the existing Saumitra roadmap (leave-one-out, alt democracy
  index + V-Dem country list, pre-trend/ANRR, 30-day DiD window): fold those in.
