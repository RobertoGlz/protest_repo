/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper - SUPPLEMENTARY MATERIALS

   Code author: Roberto Gonzalez
   Date: 2026-07-07

   Objective:
     Anticipation / pre-scandal placebo test.  Rather than drawing a
     random pre-scandal cutoff per replication -- which would repeat
     each cutoff many times given that the +-T-day pre-window contains
     at most T-1 candidate offsets -- we enumerate every offset in the
     strictly-pre-scandal portion of the window EXACTLY ONCE.

     For each (outcome, T) and each k in {-T+1, ..., -1}:
        - redefine placebo_post = 1{window >= k} for every cell in the
          original event-window panel (same k applied to every scandal
          in this fit),
        - re-estimate the headline OLS specification,
        - store beta_placebo and se_placebo indexed by k.

     Under the identifying assumption of no anticipation the
     beta_placebo series should be centered on zero across k, and the
     observed beta (from Table 1) should sit outside the range of the
     enumerated placebos.

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta

   Outputs (under ${work}/results/):
     - sup_placebo_within_window_beta_<outcome>_w<T>.dta
       (T-1 rows; columns: k, beta_placebo, se_placebo, outcome, T_window,
        observed_beta)
   Output figures (under ${work}/results/figures/):
     - sup_placebo_within_window_hist_<outcome>_w<T>.pdf
       (beta_placebo vs k, with observed beta as a red horizontal line)
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

/* --- Base panel --- */
use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)
tempfile base_panel
save `base_panel'

foreach outcome of local outcome_list {
foreach T in 30 120 {

	/* ----- Observed beta on this (outcome, window) ----- */
	use `base_panel', clear
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

	/* ----- Enumerate every pre-scandal offset once ----- */
	local Tm1 = `T' - 1
	matrix results = J(`Tm1', 3, .)   /* [k, beta, se] */

	quietly {
	forvalues i = 1/`Tm1' {
		local k = -`i'

		use `base_panel', clear
		if `T' == 30 {
			keep if year >= `firstyear' & abs(window) <= `T'
		}
		else {
			keep if year >= `firstyear'
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
				"[`outcome', T=`T'] k = `k'   beta_placebo = " ///
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
	gen str32 outcome        = "`outcome'"
	gen      T_window        = `T'
	gen double observed_beta = `observed_beta_T'
	order k beta_placebo se_placebo outcome T_window observed_beta
	save "${resout}/sup_placebo_within_window_beta_`outcome'_w`T'.dta", replace

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
	display in yellow "  outcome = `outcome',  window = +-`T' days"
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

	/* ----- Plot: beta_placebo (point + 90% CI) vs k, plus horizontal
	           red line + shaded rarea band for the observed beta's
	           90% CI. z_{0.05} = invnormal(0.95) ~ 1.645. ----- */
	if "`outcome'" == "num_violent_MM"  local outlbl "violent protests"
	if "`outcome'" == "num_peaceful_MM" local outlbl "peaceful protests"

	/* Rank of the observed estimate among all beta values (placebos +
	   observed), largest = 1.  T_total = # placebo betas + 1.        */
	quietly count if !missing(beta_placebo) & beta_placebo > `observed_beta_T'
	local rank    = r(N) + 1
	local Ttotal  = `Tm1' + 1

	/* Two-sided RI p-value: share of placebo estimates that are more
	   extreme in absolute value than the observed estimate.          */
	quietly count if !missing(beta_placebo) & ///
		abs(beta_placebo) >= abs(`observed_beta_T')
	local pval    = r(N) / `Tm1'
	local pval_str = string(`pval', "%5.3f")

	/* Invisible dummy series carries the rank text in the legend.    */
	gen double _rank_dummy = .

	/* Y-axis range: cover both placebo betas AND the observed beta,
	   with 15% padding on each side so the horizontal red line is
	   never flush against the plot border.                          */
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
	graph export "${figout}/sup_placebo_within_window_hist_`outcome'_w`T'.pdf", replace
}
}

display in green "a_sup_placebo_within_window.do finished OK"
