/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper - SUPPLEMENTARY MATERIALS

   Code author: Roberto Gonzalez
   Date: 2026-07-13

   Objective:
     Re-estimate the headline OLS and Poisson QML specifications
     (\autoref{eq:main}) at every event-window width in
        T in {15, 30, 45, ..., 150} days
     and plot the point estimate against T with a 90% confidence
     interval.

     Three subsamples:
        - full         : all 176 scandals
        - pa           : President + Other Apex (45 + 19 = 64)
        - na           : Other Non-Apex (112)

     For each subsample we produce four PDFs (OLS/Poisson x violent/
     peaceful).  Within a given (subsample, estimator) pair the
     violent and peaceful panels SHARE the same y-axis range so
     readers can compare them side-by-side and see the null line
     aligned across panels.

     Highlights: T = 30 and T = 120 markers and CI bars in RGB
     (220, 0, 0); a thick, very faint horizontal line marks the
     null (beta = 0 for OLS, IRR = 1 for Poisson).

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta
     - ${datfin}/scandals_classified.csv

   Outputs (under paper/figures/, one PDF per subsample x estimator
   x outcome):
     - sup_window_sensitivity_ols_num_violent_MM[<suf>].pdf
     - sup_window_sensitivity_ols_num_peaceful_MM[<suf>].pdf
     - sup_window_sensitivity_poi_num_violent_MM[<suf>].pdf
     - sup_window_sensitivity_poi_num_peaceful_MM[<suf>].pdf
     where <suf> is empty (full sample), "_pa" (President + Other
     Apex) or "_na" (Other Non-Apex).
---------------------------------------------------------------------------- */

set more off
clear all

/* ----------------------- User-specific paths ----------------------- */
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
global figout  "${identity}/Corrupcion/protest_repo/paper/figures"

/* ----------------------- Load base panel + classification ----------------------- */
import delimited using "${datfin}/scandals_classified.csv", ///
	clear varnames(1) bindquotes(strict)
keep id country position
tempfile cls
save `cls'

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"

merge m:1 id country using `cls', keep(1 3) generate(_mclass)

/* Apex partition v2 flags */
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

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"

local firstyear = 2008
tempfile base
save `base'

/* ============================================================
   STEP 1 - Loop over subsample, outcome, window, estimator
   ============================================================ */
tempname res
postfile `res' str8 sample int T str16 outcome str8 estimator ///
	double beta double se ///
	using "${work}/temp/window_sensitivity_estimates.dta", replace

foreach sample in full pa na {

	/* subsample filter */
	if "`sample'" == "full" local sample_if ""
	if "`sample'" == "pa"   local sample_if "& in_pa == 1"
	if "`sample'" == "na"   local sample_if "& in_na == 1"

	foreach outcome in num_violent_MM num_peaceful_MM {
	foreach T of numlist 15(15)150 {

		/* --- OLS --- */
		use `base', clear
		capture reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear' & abs(window) <= `T' `sample_if', ///
			absorb($fe1) vce($CLUSTER2)
		if _rc == 0 & !missing(_b[post]) {
			post `res' ("`sample'") (`T') ("`outcome'") ("OLS") ///
				(_b[post]) (_se[post])
		}

		/* --- Poisson QML --- */
		use `base', clear
		capture ppmlhdfe `outcome' post ///
			if year >= `firstyear' & abs(window) <= `T' `sample_if', ///
			absorb(month day $fe1) vce($CLUSTER2)
		if _rc == 0 & !missing(_b[post]) {
			post `res' ("`sample'") (`T') ("`outcome'") ("Poisson") ///
				(_b[post]) (_se[post])
		}

		display in yellow "sample=`sample', outcome=`outcome', T=`T' done"
	}
	}
}

postclose `res'

/* ============================================================
   STEP 2 - Load estimates, compute 90% CI, and plot
   ============================================================ */
use "${work}/temp/window_sensitivity_estimates.dta", clear

local zcrit = invnormal(0.95)  /* 1.6449 for 90% CI */

/* OLS: beta and CI on the linear scale */
gen double ci_lo   = beta - `zcrit' * se
gen double ci_hi   = beta + `zcrit' * se

/* Poisson: IRR = exp(beta) with delta-method SE and CI */
gen double irr        = exp(beta)         if estimator == "Poisson"
gen double irr_se     = exp(beta) * se    if estimator == "Poisson"
gen double irr_ci_lo  = irr - `zcrit' * irr_se
gen double irr_ci_hi  = irr + `zcrit' * irr_se

tempfile allests
save `allests'

/* --- Precompute shared y-ranges.
       For the Apex / Non-Apex plots we use ONE common range, computed
       across BOTH subsamples and BOTH outcomes, so pa and na (placed
       side by side in the paper) are directly comparable by eye.  The
       full-sample plots use their own range. --- */
foreach est in OLS Poisson {
	if "`est'" == "OLS" {
		local rylo "ci_lo"
		local ryhi "ci_hi"
		local nullref 0
	}
	else {
		local rylo "irr_ci_lo"
		local ryhi "irr_ci_hi"
		local nullref 1
	}

	foreach grp in split full {
		use `allests', clear
		if "`grp'" == "split" keep if inlist(sample, "pa", "na") & estimator == "`est'"
		else                  keep if sample == "full"           & estimator == "`est'"

		quietly summarize `rylo'
		local ymin = min(r(min), `nullref')
		quietly summarize `ryhi'
		local ymax = max(r(max), `nullref')
		local ypad = 0.10 * (`ymax' - `ymin')
		local ylo_pad = `ymin' - `ypad'
		local yhi_pad = `ymax' + `ypad'
		local range = `yhi_pad' - `ylo_pad'
		if `range' <= 0 local range = 0.01
		local raw = `range' / 6
		local mag = 10 ^ floor(log10(`raw'))
		local mult = `raw' / `mag'
		if `mult' < 1.5      local step = 1  * `mag'
		else if `mult' < 3.5 local step = 2  * `mag'
		else if `mult' < 7.5 local step = 5  * `mag'
		else                 local step = 10 * `mag'
		local ylo_`est'_`grp'  = floor(`ylo_pad' / `step') * `step'
		local yhi_`est'_`grp'  = ceil( `yhi_pad' / `step') * `step'
		local step_`est'_`grp' = `step'
	}
}

/* --- Plot.  Highlight ALL four table windows (30/60/90/120) in red. --- */
foreach sample in full pa na {

	if "`sample'" == "full" local suf ""
	if "`sample'" == "full" local grp "full"
	if "`sample'" == "pa"   local suf "_pa"
	if "`sample'" == "pa"   local grp "split"
	if "`sample'" == "na"   local suf "_na"
	if "`sample'" == "na"   local grp "split"

	foreach est in OLS Poisson {

		if "`est'" == "OLS" {
			local yvar "beta"
			local ylo "ci_lo"
			local yhi "ci_hi"
			local nullref 0
			local ytpre "Effect on"
			local outfx "ols"
		}
		else {
			local yvar "irr"
			local ylo "irr_ci_lo"
			local yhi "irr_ci_hi"
			local nullref 1
			local ytpre "IRR on"
			local outfx "poi"
		}
		local ylo_tick = `ylo_`est'_`grp''
		local yhi_tick = `yhi_`est'_`grp''
		local step     = `step_`est'_`grp''

		foreach outcome in num_violent_MM num_peaceful_MM {

			if "`outcome'" == "num_violent_MM"  local outlbl "violent protests"
			if "`outcome'" == "num_peaceful_MM" local outlbl "peaceful protests"

			preserve
				use `allests', clear
				keep if sample == "`sample'" & estimator == "`est'" & outcome == "`outcome'"
				sort T

				twoway (rcap `ylo' `yhi' T if !inlist(T, 30, 60, 90, 120), ///
				            lcolor(gs6) lwidth(thin)) ///
				       (rcap `ylo' `yhi' T if  inlist(T, 30, 60, 90, 120), ///
				            lcolor("220 0 0") lwidth(medthick)) ///
				       (line `yvar' T, lcolor(black) lwidth(medium)) ///
				       (scatter `yvar' T, msymbol(O) msize(medium) mcolor(black)) ///
				       (scatter `yvar' T if inlist(T, 30, 60, 90, 120), ///
				            msymbol(O) msize(medlarge) mcolor("220 0 0")), ///
					yline(`nullref', lcolor(black%10) lwidth(vvthick) lpattern(solid)) ///
					xlabel(15(15)150) ///
					xtitle("Event-window width (days)", size(medium)) ///
					ytitle("`ytpre' `outlbl'", size(medium)) ///
					ylabel(`ylo_tick'(`step')`yhi_tick', format(%5.3f) angle(0)) ///
					yscale(range(`ylo_tick' `yhi_tick')) ///
					scheme(s2color) graphregion(color(white)) legend(off)
				graph export ///
					"${figout}/sup_window_sensitivity_`outfx'_`outcome'`suf'.pdf", ///
					replace
			restore
		}
	}
}

display in green "a_sup_window_sensitivity.do finished OK"
