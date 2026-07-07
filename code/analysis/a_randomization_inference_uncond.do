/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper

   Code author: Roberto Gonzalez
   Date: 2026-07-02

   Objective:
     ALTERNATIVE (unconditional) randomization-inference test built in
     the spirit of the older "_fake_" placebo pipeline in
       Codigo/Alef/Protest/Random scandals/
     (generate_random_scandals.do  ->
      5_d_EventWindow_Merge_middlerun_fake.do  ->
      3_a_EventWindow_Regs_midterm_fake.do).

     Difference vs. a_randomization_inference.do:
       - a_randomization_inference.do  (WITHIN country-year):
             for each scandal, keep the original country and the original
             year; permute only the day-of-year.
       - THIS FILE (UNCONDITIONAL / _fake_ style):
             draw each placebo scandal's COUNTRY uniformly at random over
             the panel's countries (Venezuela excluded) AND its DATE
             uniformly at random over 2008-01-01 to 2018-12-31.  Country
             and date are independent, so this destroys the country-year
             composition of the treated set entirely.

     This is a looser null and the placebo distribution should be wider;
     the RI p-value reported here is expected to be smaller (i.e., the
     observed effect looks more extreme) than the one from
     a_randomization_inference.do.  The two are meant to be read together
     as bracketing tests.

     Every replication draws N = 176 placebo scandals (matches the
     observed total).  Machinery downstream of the draw is identical to
     a_randomization_inference.do: build the +-T event window, merge in
     outcomes from MMclean_full_bydate.dta, re-run the headline OLS,
     store beta_placebo.

   Inputs:
     - ${work}/temp/MM/MMclean_full_bydate.dta      (country x day counts;
       source of outcomes for both observed and placebo regressions)
     - ${datfin}/protests_scandals_30days_v3.dta    (observed event-window
       panel; used to compute the observed beta only)

   Outputs (under ${work}/results/):
     - randomization_inference_uncond_beta_<outcome>_w<T>.dta   (four files;
       1000 rows each; columns: rep, beta_placebo, outcome, T_window,
       firstyear, observed_beta)
   Output figures (under ${work}/results/figures/):
     - randomization_inference_uncond_hist_<outcome>_w<T>.pdf   (four files;
       y-axis in percent, bars gs6, vertical red line (RGB 220 0 0) at
       the observed beta, RI p-value in the note.)
---------------------------------------------------------------------------- */

set more off
clear all
set seed 20260702      /* Reproducible seed; different from the within-CY file */

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
global figout  "${work}/results/figures"

/* ---------------------------- Config ---------------------------- */
local outcome_list = "num_violent_MM num_peaceful_MM"
local firstyear    = 2008
local lastyear     = 2018
local n_reps       = 1000
local n_scandals   = 176                  /* matches the observed total */

local date_lo    = mdy(1, 1, `firstyear')
local date_hi    = mdy(12, 31, `lastyear')
local date_range = `date_hi' - `date_lo' + 1

/* ============================================================
   STEP 1 - COUNTRY-DAY PANEL AS THE SOURCE OF OUTCOMES
   Same source used to build the observed event-window file, so the
   placebo iterations see exactly the same outcome values as the
   observed regression.
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

/* Enumerate countries in the panel: we draw the placebo country label
   as a uniform integer 1..n_countries and map it to a name via a
   foreach loop below.                                                 */
levelsof country, local(country_list)
local n_countries : word count `country_list'
display in yellow "Panel has `n_countries' countries (Venezuela already dropped)."

/* ============================================================
   STEP 2 - LOAD THE OBSERVED PANEL (for computing observed beta only)
   Cluster group variable identical to a_randomization_inference.do.
   ============================================================ */
use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)
tempfile obs_panel
save `obs_panel'

/* ============================================================
   STEP 3 - LOOP OVER (OUTCOME, WINDOW) AND RUN THE PLACEBO TEST
   ============================================================ */
foreach outcome of local outcome_list {
foreach T in 30 120 {

	local win_size = 2*`T' + 1

	/* ----- 3a. OBSERVED beta on this (outcome, window) ----- */
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

	/* ----- 3b. UNCONDITIONAL placebo loop ----- */
	matrix betas = J(`n_reps', 1, .)

	quietly {
	forvalues r = 1/`n_reps' {

		/* Draw N placebo scandals from scratch:
		   - country  ~ Uniform{1, .., n_countries}
		     (equal weight on every panel country; drops the observed
		      country marginal distribution, in the spirit of the old
		      _fake_ exercise's runiformint(1,16))
		   - date     ~ Uniform{Jan 1 `firstyear', .., Dec 31 `lastyear'}
		     (uniform over the paper's headline sample period)          */
		clear
		set obs `n_scandals'
		gen scandal_id = _n
		gen cid_draw   = runiformint(1, `n_countries')
		gen str44 country = ""
		local i = 0
		foreach c of local country_list {
			local ++i
			replace country = "`c'" if cid_draw == `i'
		}
		gen scandal_date = `date_lo' + int(runiform() * `date_range')
		format scandal_date %td
		drop cid_draw

		/* Expand to +-T-day window around each placebo date */
		expand `win_size'
		bysort scandal_id: gen window = _n - `T' - 1
		gen date = scandal_date + window
		drop scandal_date

		/* Merge outcomes and calendar features from the country-day panel.
		   Merge is on (country, date); after this step every retained row
		   has `outcome', country_id, year, month, and day (= dow).       */
		merge m:1 country date using `day_panel', keep(1 3) nogenerate

		/* post indicator, sample restriction, drop cells outside the
		   country-day panel's coverage.                                  */
		gen post = (window >= 0)
		keep if year >= `firstyear' & year <= `lastyear'
		drop if missing(`outcome')

		/* Fit the OLS specification (robust SE for speed; per-placebo SE
		   irrelevant to the RI p-value). Same absorb/control structure as
		   the observed regression.                                       */
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
	save "${resout}/randomization_inference_uncond_beta_`outcome'_w`T'.dta", replace

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
	display in yellow "  Randomization inference (UNCONDITIONAL / _fake_ style)"
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

	twoway (histogram beta_placebo, percent bin(50) ///
	            color(gs6) lcolor(gs8)), ///
		xline(`observed_beta_T', lcolor("220 0 0") lwidth(medthick) ///
		     lpattern(solid)) ///
		xline(0, lcolor(black) lwidth(vthin) lpattern(dot)) ///
		xtitle("Effect on `outlbl'", size(medium)) ///
		ytitle("Percent", size(medium)) ///
		xlabel(, format(%5.3f)) ///
		ylabel(, angle(0) format(%3.0f)) ///
		scheme(s2color) graphregion(color(white))
	graph export "${figout}/randomization_inference_uncond_hist_`outcome'_w`T'.pdf", replace
}
}

display in green "a_randomization_inference_uncond.do finished OK"
