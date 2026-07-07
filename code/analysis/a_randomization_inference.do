/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper

   Code author: Roberto Gonzalez
   Date: 2026-07-01

   Objective:
     Randomization-inference (permutation) test for the headline OLS
     estimate of the effect of apex corruption scandals on both violent
     and peaceful protests, run separately for the +-30-day and +-120-day
     windows (so four combinations in total).

     For each of `n_reps' replications and each (outcome, T) cell:
        1. draw a placebo disclosure date for every scandal, uniformly at
           random within the SAME country-year as the original scandal
           (this preserves the country x year composition of the treated
           observations while breaking the actual timing).  A draw is
           REJECTED whenever the placebo's +-T-day window would contain
           an actual disclosure date of any scandal in the same country
           (i.e., there exists a real scandal in that country with
           |placebo_date - real_date| <= T).  We redraw within the
           original country-year for up to 20 attempts; if none of those
           is accepted, we fall back to an UNCONDITIONAL draw (uniformly
           random country in the panel and uniformly random date in the
           2008-2018 analysis period) for up to 30 more attempts, still
           subject to the same overlap check;
        2. rebuild the stacked +-T-day event-window panel from the
           country-day panel using the placebo dates -- the outcome for
           each new (country_id, date) cell is pulled by a merge from the
           country-day panel of protest counts;
        3. re-estimate the headline OLS specification and store beta.

     The observed beta is then compared against the resulting placebo
     distribution; the randomization-inference p-value is the fraction of
     placebo betas at least as large in absolute value as the observed one.

   Inputs:
     - ${datfin}/panel_country_day.dta        (balanced country x day
       panel with both outcomes, year, month-of-year, and day-of-week
       variables; source of the outcomes in the placebo iterations)
     - ${datfin}/protests_scandals_30days_v3.dta   (observed event-window
       panel; used to enumerate scandals and to compute the observed beta)

   Outputs (under ${work}/results/):
     - randomization_inference_beta_<outcome>_w<T>.dta   (four files;
       1000 rows each; columns: rep, beta_placebo, outcome, T_window,
       firstyear, observed_beta)
   Output figures (under ${work}/results/figures/):
     - randomization_inference_hist_<outcome>_w<T>.pdf   (four files;
       y-axis in percent, bars gs6, vertical red line (RGB 220 0 0) at
       the observed beta, RI p-value in the note.)
---------------------------------------------------------------------------- */

set more off
clear all
set seed 20260701      /* Reproducible seed */

/* ---------------------------- User paths ---------------------------- */
if "`c(username)'" == "Diego" {
	gl identity "D:/Documents/Dropbox"
}
if "`c(username)'" == "dtocre" {
	gl identity "C:/Users/dtocre/Dropbox"
}
if "`c(username)'" == "lalov" {
	gl identity "C:/Users/lalov/ITAM Seira Research Dropbox/Eduardo Rivera"
}
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox"
}
if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}

global path    "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin  "${path}/Data/final"
global work    "${identity}/Corrupcion/Protest_Work"
global resout  "${work}/results"
global figout  "${identity}/Corrupcion/protest_repo/paper/figures"

/* ---------------------------- Config ---------------------------- */
local outcome_list = "num_violent_MM num_peaceful_MM"
local firstyear    = 2008
local n_reps       = 1000                 /* # of placebo replications */

/* ============================================================
   STEP 1 - COUNTRY-DAY PANEL AS THE SOURCE OF OUTCOMES
   The randomization merges this file onto each placebo event-window
   panel to attach outcome values at each (country, date) cell.

   IMPORTANT: We use MMclean_full_bydate.dta directly (rather than
   panel_country_day.dta) because the OBSERVED event-window panel
   protests_scandals_30days_v3.dta is itself built by merging
   MMclean_full_bydate.dta onto scandal windows. panel_country_day.dta
   is aggregated from the raw event file MMclean_full.dta via a
   separate collapse step, which produces a handful of cell-level
   discrepancies (~0.2% of shared cells). Using MMclean_full_bydate.dta
   guarantees the placebo iterations see the exact same outcome values
   as the observed regression.

   MMclean_full_bydate.dta has 5 variables:
        country (string)  date  num_protests  num_peaceful  num_violent
   We rename with the _MM suffix used elsewhere and derive the calendar
   features (year, month, day-of-week) plus a numeric country_id for
   the fixed-effect absorb.
   ============================================================ */
use "${work}/temp/MM/MMclean_full_bydate.dta", clear
drop if country == "Venezuela"
rename num_violent  num_violent_MM
rename num_peaceful num_peaceful_MM
rename num_protests num_protests_MM
gen year  = year(date)
gen month = month(date)
gen day   = dow(date)                       /* day-of-week: 0=Sun..6=Sat */
egen country_id = group(country)
tempfile day_panel
save `day_panel'

/* ============================================================
   STEP 2 - LIST OF SCANDALS (one row per unique scandal)
   ============================================================ */
use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"

/* Cluster group variable (needed for the observed-beta SE later) */
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)

tempfile obs_panel
save `obs_panel'

preserve
	keep if window == 0
	keep id country year
	duplicates drop id country, force
	quietly count
	local n_scandals = r(N)
	tempfile scandal_list
	save `scandal_list'
restore

/* Attach the numeric country_id that we generated in the country-day
   panel (STEP 1) so the observed and placebo regressions absorb the
   same fixed-effect identifier. */
preserve
	use `day_panel', clear
	bysort country: keep if _n == 1
	keep country country_id
	tempfile cid_lookup
	save `cid_lookup'
restore
use `scandal_list', clear
merge m:1 country using `cid_lookup', keep(1 3) nogenerate
save `scandal_list', replace

display in yellow "`n_scandals' distinct scandals in the event-window panel."

/* ============================================================
   STEP 2b - LOOKUPS FOR OVERLAP-REJECTION AND UNCONDITIONAL FALLBACK
   ============================================================ */
/* Real disclosure dates per country (used by the overlap check). */
preserve
	use `obs_panel', clear
	keep if window == 0
	keep country_id date
	duplicates drop
	rename date real_date
	tempfile real_dates_by_country
	save `real_dates_by_country'
restore

/* country_id -> country string lookup, for updating the country
   variable when the unconditional fallback picks a new country_id. */
preserve
	use `day_panel', clear
	bysort country: keep if _n == 1
	keep country_id country
	quietly count
	local n_countries = r(N)
	tempfile cid_to_name
	save `cid_to_name'
restore

/* Date range for the unconditional fallback (uniform over the full
   2008-2018 analysis period).                                       */
local date_lo    = mdy(1, 1, `firstyear')
local date_hi    = mdy(12, 31, 2018)
local date_range = `date_hi' - `date_lo' + 1

/* Draw-attempt budgets */
local max_cy_attempts     = 20
local max_uncond_attempts = 30
local max_att : display `max_cy_attempts' + `max_uncond_attempts'

/* ============================================================
   STEP 3 - LOOP OVER (OUTCOME, WINDOW) AND RUN THE PERMUTATION TEST
   ============================================================ */
foreach outcome of local outcome_list {
foreach T in 30 120 {

	local win_size = 2*`T' + 1

	/* ----- 3a. Compute the OBSERVED beta on this (outcome, window) ----- */
	use `obs_panel', clear
	if `T' == 30 {
		quietly reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear' & abs(window) <= `T', ///
			absorb(i.country_id#i.year) ///
			vce(cluster i.country_id#i.year#i.grupo_dias)
	}
	else {
		quietly reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear', ///
			absorb(i.country_id#i.year) ///
			vce(cluster i.country_id#i.year#i.grupo_dias)
	}
	local observed_beta_T = _b[post]
	local observed_se_T   = _se[post]

	display _newline in yellow ///
		"[outcome=`outcome', T=`T'] Observed beta = " %10.6f `observed_beta_T' ///
		"   (SE = " %10.6f `observed_se_T' ")"

	/* ----- 3b. Run the placebo loop ----- */
	matrix betas = J(`n_reps', 1, .)

	quietly {
	forvalues r = 1/`n_reps' {

		/* ------------- Draw placebo dates with overlap rejection -------------
		   Round 1..`max_cy_attempts': redraw within the original
		     country-year of each still-bad scandal.
		   Round `max_cy_attempts'+1..`max_att': unconditional fallback --
		     redraw both country and date uniformly over the whole
		     panel/period for each still-bad scandal.
		   A scandal is BAD if its currently-drawn placebo date is
		   within T days of any actual disclosure date in the same
		   country (so the placebo's +-T window would contain a real
		   scandal date). --------------------------------------------------- */
		use `scandal_list', clear
		gen scandal_id = _n
		gen rday         = int(runiform()*365) + 1
		gen scandal_date = mdy(1, 1, year) + rday - 1
		drop rday

		forvalues att = 1/`max_att' {

			preserve
				keep scandal_id country_id scandal_date
				joinby country_id using `real_dates_by_country'
				gen dist = abs(scandal_date - real_date)
				collapse (min) mindist=dist, by(scandal_id)
				tempfile _chk
				save `_chk'
			restore

			merge 1:1 scandal_id using `_chk', keep(1 3) nogenerate
			gen byte bad = (mindist <= `T')
			drop mindist

			quietly count if bad == 1
			if r(N) == 0 {
				drop bad
				continue, break
			}

			if `att' <= `max_cy_attempts' {
				gen rday = int(runiform()*365) + 1 if bad == 1
				replace scandal_date = mdy(1, 1, year) + rday - 1 if bad == 1
				drop rday
			}
			else {
				gen rday = int(runiform() * `date_range') if bad == 1
				replace scandal_date = `date_lo' + rday if bad == 1
				gen rcid = 1 + int(runiform() * `n_countries') if bad == 1
				replace country_id = rcid if bad == 1
				drop country
				merge m:1 country_id using `cid_to_name', keep(1 3) nogenerate
				drop rday rcid
			}

			drop bad
		}

		/* Expand to +-T-day window around each accepted placebo date */
		expand `win_size'
		bysort scandal_id: gen window = _n - `T' - 1
		gen date = scandal_date + window
		drop scandal_date

		/* Merge outcomes and calendar features from the country-day panel.
		   Merge is on (country, date) since MMclean_full_bydate.dta keys
		   by string country. After this step every retained row has
		   `outcome', country_id, year, month, and day (= dow) attached. */
		drop country_id                             /* re-fetched from day_panel */
		merge m:1 country date using `day_panel', keep(1 3) nogenerate

		/* post indicator, sample restriction, drop cells outside the
		   country-day panel's coverage (window edge running past the
		   panel's date range) */
		gen post = (window >= 0)
		keep if year >= `firstyear'
		drop if missing(`outcome')

		/* Fit the OLS specification (robust SE for speed; per-placebo SE
		   irrelevant to the RI p-value). This mirrors the observed
		   regression's absorb / control structure. */
		capture reghdfe `outcome' post i.month i.day, ///
			absorb(i.country_id#i.year) vce(robust)
		if _rc == 0 & !missing(_b[post]) {
			matrix betas[`r', 1] = _b[post]
		}

		if mod(`r', 50) == 0 {
			noisily display in green ///
				"[`outcome', T=`T'] Rep `r' / `n_reps'   beta_placebo = " ///
				%10.6f _b[post]
		}
	}
	}

	/* ----- 3c. Save the placebo distribution ----- */
	clear
	svmat betas, names(beta_)
	rename beta_1 beta_placebo
	gen rep = _n
	gen str32 outcome        = "`outcome'"
	gen      T_window        = `T'
	gen      firstyear       = `firstyear'
	gen double observed_beta = `observed_beta_T'
	order rep beta_placebo outcome T_window firstyear observed_beta
	save "${resout}/randomization_inference_beta_`outcome'_w`T'.dta", replace

	/* ----- 3d. Summary and p-values ----- */
	quietly count if !missing(beta_placebo)
	local n_valid = r(N)

	quietly count if !missing(beta_placebo) & ///
		abs(beta_placebo) >= abs(`observed_beta_T')
	local ri_p_two = r(N) / `n_valid'

	quietly count if !missing(beta_placebo) & ///
		beta_placebo >= `observed_beta_T'
	local ri_p_one = r(N) / `n_valid'

	quietly summarize beta_placebo, detail
	local mean_placebo = r(mean)
	local sd_placebo   = r(sd)
	local p50_placebo  = r(p50)

	display _newline in yellow ///
	"================================================================"
	display in yellow "  Randomization inference"
	display in yellow "  outcome = `outcome',  window = +-`T' days"
	display in yellow ///
	"================================================================"
	display "  n_reps               = `n_reps'  (valid: `n_valid')"
	display "  observed beta        = " %10.6f `observed_beta_T'
	display "  placebo mean         = " %10.6f `mean_placebo'
	display "  placebo SD           = " %10.6f `sd_placebo'
	display "  placebo median       = " %10.6f `p50_placebo'
	display "  two-sided RI p-value = " %6.4f `ri_p_two'
	display "  one-sided (right) p  = " %6.4f `ri_p_one'
	display in yellow ///
	"================================================================"

	/* ----- 3e. Histogram: y-axis = percent, bars gs6, red vertical
	           line (RGB 220 0 0) at the observed beta ----- */
	local obs_str = string(`observed_beta_T', "%5.3f")
	local p2_str  = string(`ri_p_two',        "%5.3f")
	local p1_str  = string(`ri_p_one',        "%5.3f")

	if "`outcome'" == "num_violent_MM"  local outlbl "violent protests"
	if "`outcome'" == "num_peaceful_MM" local outlbl "peaceful protests"

	/* Invisible dummy series so the legend can carry the RI p-value.  */
	gen double _leg_dummy = .

	twoway (histogram beta_placebo, percent bin(50) ///
	            color(gs6) lcolor(gs8)) ///
	       (scatter _leg_dummy beta_placebo, msymbol(none)), ///
		xline(`observed_beta_T', lcolor("220 0 0") lwidth(medthick) ///
		     lpattern(solid)) ///
		xline(0, lcolor(black) lwidth(vthin) lpattern(dot)) ///
		text(5 `observed_beta_T' "{&beta} = `obs_str'", ///
		     place(e) orientation(vertical) size(medsmall) ///
		     color("220 0 0")) ///
		xtitle("Effect on `outlbl'", size(medium)) ///
		ytitle("Percent", size(medium)) ///
		xlabel(, format(%5.3f)) ///
		ylabel(, angle(0) format(%3.0f)) ///
		legend(order(2) label(2 "RI p = `p2_str'") ///
		       pos(2) ring(0) region(lcolor(black) fcolor(white)) ///
		       size(medium) symxsize(0)) ///
		scheme(s2color) graphregion(color(white))
	graph export "${figout}/randomization_inference_hist_`outcome'_w`T'.pdf", replace
}
}

display in green "a_randomization_inference.do finished OK"
