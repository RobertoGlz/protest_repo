/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper

   Code author: Roberto Gonzalez
   Date: 2026-07-13

   Objective:
     Randomization-inference test for the headline OLS estimate,
     RUN SEPARATELY on the two apex-partition subsamples used in the
     main Table~1:
        - pa : President + Other Apex   (~64 scandals)
        - na : Other Non-Apex           (~112 scandals)

     For each (subsample, outcome, T) cell, we run `n_reps' placebo
     replications with the same within-country-year draw and overlap
     rejection as a_randomization_inference.do -- but only draw for
     the scandals belonging to the subsample and estimate the OLS
     specification restricting to those scandal IDs.

     Rejection rule: a draw is rejected if its +-T-day window would
     contain an actual disclosure date of any scandal in the same
     country (both PA and NA scandals count as "actual disclosures"
     for the overlap check).  If no acceptable date is found within
     the original country-year after 20 attempts, we fall back to an
     UNCONDITIONAL draw over all 22 panel countries and all dates in
     2008-2018 for up to 30 additional attempts.

   Inputs:
     - ${work}/temp/MM/MMclean_full_bydate.dta      (country x day)
     - ${datfin}/protests_scandals_30days_v3.dta    (event-window panel)
     - ${datfin}/scandals_classified.csv            (apex partition)

   Outputs (under ${work}/results/):
     - randomization_inference_beta_<outcome>_w<T>_<sample>.dta
   Output figures (under paper/figures/):
     - randomization_inference_hist_<outcome>_w<T>_<sample>.pdf
       where <sample> is 'pa' or 'na'.
---------------------------------------------------------------------------- */

set more off
clear all
set seed 20260713

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
local n_reps       = 1000
local sample_list  = "pa na"

/* ============================================================
   STEP 1 - COUNTRY-DAY PANEL
   ============================================================ */
use "${work}/temp/MM/MMclean_full_bydate.dta", clear
drop if country == "Venezuela"
rename num_violent  num_violent_MM
rename num_peaceful num_peaceful_MM
rename num_protests num_protests_MM
egen country_id = group(country)

/* --------------------------------------------------------------------
   BALANCE THE COUNTRY-DAY PANEL (see a_randomization_inference.do for
   the full explanation).  MMclean_full_bydate.dta holds only protest-
   days; tsfill the zero-protest country-days and set their counts to 0
   so each placebo regression runs on the same balanced support as the
   observed event-window panel.
   -------------------------------------------------------------------- */
preserve
	keep country_id country
	duplicates drop
	tempfile _cw
	save `_cw'
restore
tsset country_id date
tsfill, full
drop country
merge m:1 country_id using `_cw', nogenerate
foreach v in num_violent_MM num_peaceful_MM num_protests_MM {
	replace `v' = 0 if missing(`v')
}
gen year  = year(date)
gen month = month(date)
gen day   = dow(date)
tempfile day_panel
save `day_panel'

/* ============================================================
   STEP 2 - LIST OF SCANDALS + apex-partition flags
   ============================================================ */
import delimited using "${datfin}/scandals_classified.csv", ///
	clear varnames(1) bindquotes(strict)
keep id country position
tempfile cls
save `cls'

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
merge m:1 id country using `cls', keep(1 3) generate(_mclass)

gen byte in_pa = 0
replace in_pa = 1 if position == "president"
replace in_pa = 1 if position == "governor"
replace in_pa = 1 if position == "sc_judge_congressman" & ///
	inlist(id, "202", "NEW26", "NEW30", "332", "NEW23")

gen byte in_na = 0
replace in_na = 1 if position == "sc_judge_congressman" & ///
	!inlist(id, "202", "NEW26", "NEW30", "332", "NEW23")
replace in_na = 1 if position == "other_judiciary"
replace in_na = 1 if position == "others"

egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)

tempfile obs_panel
save `obs_panel'

preserve
	keep if window == 0
	keep id country year in_pa in_na
	duplicates drop id country, force
	tempfile scandal_list
	save `scandal_list'
restore

/* Attach country_id from day_panel */
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

/* Real disclosure dates by country (used for overlap rejection). */
preserve
	use `obs_panel', clear
	keep if window == 0
	keep country_id date
	duplicates drop
	rename date real_date
	tempfile real_dates_by_country
	save `real_dates_by_country'
restore

/* country_id <-> country string lookup for the unconditional fallback. */
preserve
	use `day_panel', clear
	bysort country: keep if _n == 1
	keep country_id country
	quietly count
	local n_countries = r(N)
	tempfile cid_to_name
	save `cid_to_name'
restore

local date_lo    = mdy(1, 1, `firstyear')
local date_hi    = mdy(12, 31, 2018)
local date_range = `date_hi' - `date_lo' + 1

local max_cy_attempts     = 20
local max_uncond_attempts = 30
local max_att : display `max_cy_attempts' + `max_uncond_attempts'

/* ============================================================
   STEP 3 - LOOP OVER (SUBSAMPLE, OUTCOME, WINDOW)
   ============================================================ */
foreach sample of local sample_list {

	if "`sample'" == "pa" local sample_desc "President + Other Apex"
	if "`sample'" == "na" local sample_desc "Other Non-Apex"

foreach outcome of local outcome_list {
foreach T in 30 60 90 120 {

	local win_size = 2*`T' + 1

	/* ----- 3a. Observed beta on this subsample x (outcome, T) -----
	   Restrict to the +-T window for EVERY T, so the observed beta
	   matches the corresponding column of the main table (previously
	   only T==30 was restricted, so 60/90 used the full +-120 panel). */
	use `obs_panel', clear
	quietly reghdfe `outcome' post i.month i.day ///
		if year >= `firstyear' & abs(window) <= `T' & in_`sample' == 1, ///
		absorb(i.country_id#i.year) ///
		vce(cluster i.country_id#i.year#i.grupo_dias)
	local observed_beta_T = _b[post]
	local observed_se_T   = _se[post]

	display _newline in yellow ///
		"[sample=`sample', outcome=`outcome', T=`T'] Observed beta = " ///
		%10.6f `observed_beta_T' "   (SE = " %10.6f `observed_se_T' ")"

	/* ----- 3b. Placebo loop (restrict to subsample scandals) ----- */
	matrix betas = J(`n_reps', 1, .)

	quietly {
	forvalues r = 1/`n_reps' {

		use `scandal_list', clear
		keep if in_`sample' == 1
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

		expand `win_size'
		bysort scandal_id: gen window = _n - `T' - 1
		gen date = scandal_date + window
		drop scandal_date

		drop country_id
		merge m:1 country date using `day_panel', keep(1 3) nogenerate

		gen post = (window >= 0)
		keep if year >= `firstyear'
		drop if missing(`outcome')

		capture reghdfe `outcome' post i.month i.day, ///
			absorb(i.country_id#i.year) vce(robust)
		if _rc == 0 & !missing(_b[post]) {
			matrix betas[`r', 1] = _b[post]
		}

		if mod(`r', 50) == 0 {
			noisily display in green ///
				"[`sample', `outcome', T=`T'] Rep `r' / `n_reps'   beta_placebo = " ///
				%10.6f _b[post]
		}
	}
	}

	/* ----- 3c. Save the placebo distribution ----- */
	clear
	svmat betas, names(beta_)
	rename beta_1 beta_placebo
	gen rep = _n
	gen str8  sample_key      = "`sample'"
	gen str32 outcome         = "`outcome'"
	gen       T_window        = `T'
	gen       firstyear       = `firstyear'
	gen double observed_beta  = `observed_beta_T'
	order rep beta_placebo sample_key outcome T_window firstyear observed_beta
	save "${resout}/randomization_inference_beta_`outcome'_w`T'_`sample'.dta", replace

	/* ----- 3d. Summary + RI p-value ----- */
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
	display in yellow "  Randomization inference [`sample_desc']"
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

	/* ----- 3e. Histogram (maroon observed line, legend p-value) ----- */
	local obs_str = string(`observed_beta_T', "%5.3f")
	local p2_str  = string(`ri_p_two',        "%5.3f")
	local p1_str  = string(`ri_p_one',        "%5.3f")

	if "`outcome'" == "num_violent_MM"  local outlbl "violent protests"
	if "`outcome'" == "num_peaceful_MM" local outlbl "peaceful protests"

	/* invisible dummy series that seed the two legend rows:
	   _leg_beta -> a maroon line key (matches the observed-beta line)
	   _leg_p    -> a blank key (p-value row, text only)                 */
	gen double _leg_beta = .
	gen double _leg_p    = .

	/* ----- x-axis wide enough to show BOTH the placebo distribution and
	         the observed estimate (the observed beta can sit far outside
	         the placebo mass, in which case a default axis would clip it) ----- */
	quietly summarize beta_placebo
	local xlo = min(r(min), `observed_beta_T', 0)
	local xhi = max(r(max), `observed_beta_T', 0)
	local xrng = `xhi' - `xlo'
	if `xrng' <= 0 local xrng = 0.01
	local xlo = `xlo' - 0.10 * `xrng'
	local xhi = `xhi' + 0.10 * `xrng'
	local xraw = (`xhi' - `xlo') / 5
	local xmag = 10 ^ floor(log10(`xraw'))
	local xmul = `xraw' / `xmag'
	if `xmul' < 1.5      local xstep = 1  * `xmag'
	else if `xmul' < 3.5 local xstep = 2  * `xmag'
	else if `xmul' < 7.5 local xstep = 5  * `xmag'
	else                 local xstep = 10 * `xmag'
	local xlo_t = floor(`xlo' / `xstep') * `xstep'
	local xhi_t = ceil( `xhi' / `xstep') * `xstep'

	/* The observed-beta VALUE lives in the legend (a maroon-keyed row), not
	   as a floating text label that gets clipped when the line sits high. */
	twoway (histogram beta_placebo, percent bin(50) ///
	            color(gs13) lcolor(gs10)) ///
	       (line _leg_beta beta_placebo, lcolor("128 0 0") lwidth(medthick)) ///
	       (line _leg_p    beta_placebo, lcolor(none)), ///
		xline(`observed_beta_T', lcolor("128 0 0") lwidth(medthick) ///
		     lpattern(solid)) ///
		xline(0, lcolor(black) lwidth(vthin) lpattern(dot)) ///
		xtitle("Effect on `outlbl'", size(medium)) ///
		ytitle("Percent", size(medium)) ///
		xscale(range(`xlo_t' `xhi_t')) ///
		xlabel(`xlo_t'(`xstep')`xhi_t', format(%5.3f) labsize(small)) ///
		ylabel(, angle(0) format(%3.0f)) ///
		legend(order(2 3) ///
		       label(2 "Observed {&beta} = `obs_str'") ///
		       label(3 "RI p = `p2_str'") ///
		       cols(1) pos(2) ring(0) ///
		       region(lcolor(black) fcolor(white)) size(medsmall)) ///
		scheme(s2color) graphregion(color(white))
	graph export ///
		"${figout}/randomization_inference_hist_`outcome'_w`T'_`sample'.pdf", ///
		replace
}
}
}

display in green "a_randomization_inference_pa_vs_na.do finished OK"
