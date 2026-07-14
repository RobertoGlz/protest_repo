/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper - SUPPLEMENTARY MATERIALS

   Code author: Roberto Gonzalez
   Date: 2026-07-13

   Objective:
     Same enumerated pre-scandal placebo test as
     a_sup_placebo_within_window.do -- for every offset k in
     {-T+1,...,-1} we redefine placebo_post = 1{window >= k} and
     re-estimate the OLS specification -- but run SEPARATELY on the
     two apex-partition subsamples used in Table~1:
        - pa : President + Other Apex
        - na : Other Non-Apex

     Specification exactly matches the corresponding subsample of
     Table~1 (Panel A / Panel B), so the "observed beta" and each
     "placebo beta(k)" are directly comparable to the coefficients
     in the main table.

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta
     - ${datfin}/scandals_classified.csv

   Outputs (under paper/figures/):
     - sup_placebo_within_window_hist_<outcome>_w<T>_<sample>.pdf
     where <sample> in {pa, na} and <outcome> in
     {num_violent_MM, num_peaceful_MM}, <T> in {30, 120}.

   Outputs (under ${work}/results/):
     - sup_placebo_within_window_beta_<outcome>_w<T>_<sample>.dta
---------------------------------------------------------------------------- */

set more off
clear all

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

local outcome_list = "num_violent_MM num_peaceful_MM"
local firstyear    = 2008

/* --------------- Load + attach classification --------------- */
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
tempfile base_panel
save `base_panel'

/* ============================================================
   LOOP OVER (SAMPLE, OUTCOME, WINDOW)
   ============================================================ */
foreach sample in pa na {
foreach outcome of local outcome_list {
foreach T in 30 120 {

	/* ----- Observed beta on this subsample x (outcome, T) ----- */
	use `base_panel', clear
	if `T' == 30 {
		quietly reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear' & abs(window) <= `T' & in_`sample' == 1, ///
			absorb(i.country_id#i.year) ///
			vce(cluster i.country_id#i.year#i.grupo_dias)
	}
	else {
		quietly reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear' & in_`sample' == 1, ///
			absorb(i.country_id#i.year) ///
			vce(cluster i.country_id#i.year#i.grupo_dias)
	}
	local observed_beta_T = _b[post]
	local observed_se_T   = _se[post]

	display _newline in yellow ///
		"[sample=`sample', outcome=`outcome', T=`T'] Observed beta = " ///
		%10.6f `observed_beta_T' "   (SE = " %10.6f `observed_se_T' ")"

	/* ----- Enumerate every pre-scandal offset once ----- */
	local Tm1 = `T' - 1
	matrix results = J(`Tm1', 3, .)

	quietly {
	forvalues i = 1/`Tm1' {
		local k = -`i'

		use `base_panel', clear
		if `T' == 30 {
			keep if year >= `firstyear' & abs(window) <= `T' & in_`sample' == 1
		}
		else {
			keep if year >= `firstyear' & in_`sample' == 1
		}
		drop if missing(`outcome')

		gen byte placebo_post = (window >= `k')

		capture reghdfe `outcome' placebo_post i.month i.day, ///
			absorb(i.country_id#i.year) ///
			vce(cluster i.country_id#i.year#i.grupo_dias)
		if _rc == 0 & !missing(_b[placebo_post]) {
			matrix results[`i', 1] = `k'
			matrix results[`i', 2] = _b[placebo_post]
			matrix results[`i', 3] = _se[placebo_post]
		}
		else {
			matrix results[`i', 1] = `k'
		}

		if mod(`i', 10) == 0 {
			noisily display in green ///
				"[`sample', `outcome', T=`T'] k = `k'   beta_placebo = " ///
				%10.6f _b[placebo_post]
		}
	}
	}

	/* ----- Save the enumerated placebo series ----- */
	clear
	svmat results, names(col)
	rename c1 k
	rename c2 beta_placebo
	rename c3 se_placebo
	gen str8  sample_key     = "`sample'"
	gen str32 outcome        = "`outcome'"
	gen       T_window       = `T'
	gen double observed_beta = `observed_beta_T'
	order k beta_placebo se_placebo sample_key outcome T_window observed_beta
	save "${resout}/sup_placebo_within_window_beta_`outcome'_w`T'_`sample'.dta", replace

	/* ----- Summary ----- */
	quietly summarize beta_placebo, detail
	local mean_placebo = r(mean)
	local sd_placebo   = r(sd)
	local min_placebo  = r(min)
	local max_placebo  = r(max)
	quietly count if !missing(beta_placebo) & ///
		abs(beta_placebo) >= abs(`observed_beta_T')
	local n_extreme = r(N)
	quietly count if !missing(beta_placebo)
	local n_valid = r(N)

	display _newline in yellow ///
	"================================================================"
	display in yellow "  In-window pre-scandal PLACEBO test (enumerated)"
	display in yellow "  sample = `sample',  outcome = `outcome',  window = +-`T'"
	display in yellow ///
	"================================================================"
	display "  observed beta        = " %10.6f `observed_beta_T'
	display "  #placebo cutoffs     = `n_valid'  (each k used exactly once)"
	display "  placebo mean         = " %10.6f `mean_placebo'
	display "  placebo SD           = " %10.6f `sd_placebo'
	display "  placebo min          = " %10.6f `min_placebo'
	display "  placebo max          = " %10.6f `max_placebo'
	display "  # |beta_pl| >= |obs| = `n_extreme'  of `n_valid'"
	display in yellow ///
	"================================================================"

	/* ----- Plot ----- */
	if "`outcome'" == "num_violent_MM"  local outlbl "violent protests"
	if "`outcome'" == "num_peaceful_MM" local outlbl "peaceful protests"

	quietly count if !missing(beta_placebo) & beta_placebo > `observed_beta_T'
	local rank    = r(N) + 1
	local Ttotal  = `Tm1' + 1

	quietly count if !missing(beta_placebo) & ///
		abs(beta_placebo) >= abs(`observed_beta_T')
	local pval    = r(N) / `Tm1'
	local pval_str = string(`pval', "%5.3f")

	gen double _rank_dummy = .

	quietly summarize beta_placebo
	local ymin = min(r(min), `observed_beta_T')
	local ymax = max(r(max), `observed_beta_T')
	local ypad = 0.15 * (`ymax' - `ymin')
	local ylo  = `ymin' - `ypad'
	local yhi  = `ymax' + `ypad'

	twoway (scatter beta_placebo k, msymbol(O) msize(small) mcolor(gs4)) ///
	       (scatter _rank_dummy k, msymbol(none)), ///
		yline(`observed_beta_T', lcolor("220 0 0") lwidth(medthick) ///
		     lpattern(solid)) ///
		yline(0, lcolor(black) lwidth(vthin) lpattern(dot)) ///
		xtitle("Placebo scandal-date offset (days before actual scandal)", size(medium)) ///
		ytitle("Placebo effect on `outlbl'", size(medium)) ///
		xlabel(-`T'(`=cond(`T' == 30, 5, 30)')0) ///
		ylabel(#8, angle(0) format(%5.3f)) ///
		yscale(range(`ylo' `yhi')) ///
		legend(order(2) label(2 "rank = `rank'/`Ttotal'" "p = `pval_str'") ///
		       pos(2) ring(0) region(lcolor(black) fcolor(white)) ///
		       size(medium) symxsize(0)) ///
		scheme(s2color) graphregion(color(white))
	graph export ///
		"${figout}/sup_placebo_within_window_hist_`outcome'_w`T'_`sample'.pdf", ///
		replace
}
}
}

display in green "a_sup_placebo_within_window_pa_vs_na.do finished OK"
