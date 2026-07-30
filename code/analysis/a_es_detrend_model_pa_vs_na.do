/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-07-27

    Objective:
        ANRR-style pre-trend correction, IN-MODEL version.  Instead of fitting
        a linear trend to the estimated event-study coefficients and subtracting
        it afterwards (a_es_detrend_pa_vs_na.do), here the linear time trend is a
        REGRESSOR in the model -- the selection-on-observables control.  The
        incoming (pre-scandal) trend is modelled parametrically and the
        treatment effects are the post-period deviations from it.

        Specification (per group g in {apex, non-apex} or per subsample):

           Y_{c(s)t} = gamma_g * w_{st}                      (linear event-time
                     + sum_{k=1}^{nb} beta^g_k D_{k,st}        trend, w = 0 at
                     + alpha_d + lambda_m + theta_cy + eps     the reference bin)

        Event-time bins (15-day): ebin = -nb..-1 (pre; -1 = reference) and
        1..nb (post).  w is a CONTINUOUS event-time index equal to 0 at the
        reference bin and stepping by 1 per bin (w = ebin+1 on the pre side,
        w = ebin on the post side), so gamma_g is identified off the pre-scandal
        bins (which carry no post dummy) and the post-bin dummies D_k measure
        the effect NET of the extrapolated linear trend.  beta^g_k and its SE
        come straight from the single regression (no Mata, no post-hoc algebra).

        Produced for BOTH main OLS event studies, 15-day bins, T in {30,60,90,120}:
          - POOLED  (apex & non-apex jointly, group-specific trends)
          - SUBSAMPLE (pa / na separately)

    Inputs:
        - ${datfin}/protests_scandals_30days_v3.dta
        - ${datfin}/scandals_classified.csv

    Outputs (paper/figures/), a "_dtm" (de-trended, in-model) sibling:
        - es_pooled_<outcome>_w<T>_b15_ols_90ci_dtm.pdf
        - es_<outcome>_w<T>_b15_<sample>_ols_90ci_dtm.pdf

    NOTE: the pre-scandal bins are, by construction, modelled by the linear
    trend, so they sit on the reference line (points at 0, no CI); the estimated
    effects are the post-period deviations from the extrapolated trend.
---------------------------------------------------------------------------- */

capture log close _all
log using "a_es_detrend_model_pa_vs_na_run.log", replace text

set more off
clear all

if "`c(username)'" == "lalov" {
	gl identity "C:\Users\lalov\ITAM Seira Research Dropbox\Eduardo Rivera"
}
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox"
}
if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}

global path    "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin  "${path}/Data/final"
global figout  "${identity}/Corrupcion/protest_repo/paper/figures"

local firstyear = 2008
local ci_level  = 90
local zcrit     = invnormal(0.95)
local B         = 15                 /* bin width in days */

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
	inlist(id, "202", "NEW26", "NEW30", "332")

gen byte in_na = 0
replace in_na = 1 if position == "sc_judge_congressman" & ///
	!inlist(id, "202", "NEW26", "NEW30", "332")
replace in_na = 1 if position == "other_judiciary"
replace in_na = 1 if position == "others"

egen grupo_dias    = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                           s_lead30 s_lead60 s_lead90 s_lead120)
egen group_cluster = group(country_id year grupo_dias)
egen auxvar        = group(country year)

tempfile base
save `base'

/* ============================================================
   PART 1 - POOLED (apex & non-apex jointly, group-specific trends)
   ============================================================ */
foreach T in 30 60 90 120 {
	local nb = `T' / `B'

	foreach outcome in num_violent_MM num_peaceful_MM {

		use `base', clear
		keep if year >= `firstyear' & abs(window) <= `T'
		gen int ebin = .
		replace ebin =  floor(window / `B') + 1          if window >= 0
		replace ebin = -(floor((-window - 1) / `B') + 1) if window <  0

		/* continuous event-time index: 0 at the reference bin (ebin -1),
		   +1 per bin (no gap between the reference and the first post bin) */
		gen double et = cond(ebin < 0, ebin + 1, ebin)
		gen double w_pa = et * in_pa
		gen double w_na = et * in_na

		/* post-period bin dummies (ebin 1..nb) by group */
		local rhs "w_pa w_na"
		forvalues k = 1/`nb' {
			gen byte pa_p`k' = (ebin == `k') & in_pa
			gen byte na_p`k' = (ebin == `k') & in_na
			local rhs "`rhs' pa_p`k' na_p`k'"
		}

		quietly reghdfe `outcome' `rhs', ///
			absorb(month day auxvar) cluster(group_cluster)

		/* x-axis labels */
		local labday = 15
		if `T' >= 90 local labday = 30
		local xlabs ""
		forvalues bi = -`nb'/`=`nb'-1' {
			if `bi' < 0 local d = `bi' * `B'
			else        local d = (`bi' + 1) * `B'
			if mod(`d', `labday') == 0 local xlabs "`xlabs' `d'"
		}
		local xpad   = 0.6 * `B'
		local xlo_ax = -`nb' * `B' - `xpad'
		local xhi_ax =  `nb' * `B' + `xpad'

		preserve
			clear
			local npts = 2 * `nb'
			set obs `npts'
			/* plot index bi = -nb..nb-1 (bi = -1 is the reference); post
			   points bi>=0 map to post dummy k = bi+1 (ebin = bi+1) */
			gen int    bi  = _n - `nb' - 1
			gen double day = bi * `B'
			gen double bpa = 0
			gen double sepa = 0
			gen double bna = 0
			gen double sena = 0
			forvalues j = 0/`=`nb'-1' {
				local k = `j' + 1
				quietly replace bpa  = _b[pa_p`k']  if bi == `j'
				quietly replace sepa = _se[pa_p`k'] if bi == `j'
				quietly replace bna  = _b[na_p`k']  if bi == `j'
				quietly replace sena = _se[na_p`k'] if bi == `j'
			}
			replace day = day + `B' if bi >= 0
			gen ci_lo_pa = bpa - `zcrit' * sepa
			gen ci_hi_pa = bpa + `zcrit' * sepa
			gen ci_lo_na = bna - `zcrit' * sena
			gen ci_hi_na = bna + `zcrit' * sena
			gen double day_pa = day - 0.12 * `B'
			gen double day_na = day + 0.12 * `B'

			twoway (rspike ci_lo_pa ci_hi_pa day_pa, lcolor(navy) lwidth(medthick)) ///
			       (scatter bpa day_pa, mcolor(navy) msymbol(O) msize(medium)) ///
			       (rspike ci_lo_na ci_hi_na day_na, lcolor(cranberry) lwidth(medthick)) ///
			       (scatter bna day_na, mcolor(cranberry) msymbol(D) msize(medium)), ///
				xline(0, lcolor(black%10) lwidth(vvthick) lpattern(solid)) ///
				yline(0, lpattern(dash) lcolor(black)) ///
				ytitle("Effect on protests (linear-trend model)", size(medium)) ///
				ylabel(, labsize(large) format(%5.3fc) angle(0)) ///
				xtitle("Days since scandal", size(large)) ///
				xscale(range(`xlo_ax' `xhi_ax')) ///
				xlabel(`xlabs', labsize(large)) ///
				legend(order(2 "Apex" 4 "Non-Apex") rows(1) size(medium) ///
					position(6) region(lcolor(none))) ///
				graphregion(color(white) fcolor(white)) scheme(s2color)
			graph export ///
				"${figout}/es_pooled_`outcome'_w`T'_b`B'_ols_`ci_level'ci_dtm.pdf", ///
				replace
		restore
	}
}

/* ============================================================
   PART 2 - SUBSAMPLE (pa / na separately)
   ============================================================ */
foreach T in 30 60 90 120 {
	local nb = `T' / `B'

	foreach sample in pa na {
	foreach outcome in num_violent_MM num_peaceful_MM {

		use `base', clear
		gen int ebin = .
		replace ebin =  floor(window / `B') + 1          if window >= 0
		replace ebin = -(floor((-window - 1) / `B') + 1) if window <  0

		gen double w = cond(ebin < 0, ebin + 1, ebin)     /* linear trend */
		local rhs "w"
		forvalues k = 1/`nb' {
			gen byte p`k' = (ebin == `k')
			local rhs "`rhs' p`k'"
		}

		quietly reghdfe `outcome' `rhs' ///
			if year >= `firstyear' & abs(window) <= `T' & in_`sample' == 1, ///
			absorb(month day auxvar) cluster(group_cluster)

		local labday = 15
		if `T' >= 90 local labday = 30
		local xlabs ""
		forvalues bi = -`nb'/`=`nb'-1' {
			if `bi' < 0 local d = `bi' * `B'
			else        local d = (`bi' + 1) * `B'
			if mod(`d', `labday') == 0 local xlabs "`xlabs' `d'"
		}
		local xpad   = 0.6 * `B'
		local xlo_ax = -`nb' * `B' - `xpad'
		local xhi_ax =  `nb' * `B' + `xpad'

		preserve
			clear
			local npts = 2 * `nb'
			set obs `npts'
			gen int    bi  = _n - `nb' - 1
			gen double day = bi * `B'
			gen double b  = 0
			gen double se = 0
			forvalues j = 0/`=`nb'-1' {
				local k = `j' + 1
				quietly replace b  = _b[p`k']  if bi == `j'
				quietly replace se = _se[p`k'] if bi == `j'
			}
			replace day = day + `B' if bi >= 0
			gen ci_lo = b - `zcrit' * se
			gen ci_hi = b + `zcrit' * se

			twoway (rspike ci_lo ci_hi day, lcolor(black) lwidth(medthick)) ///
			       (scatter b day, mcolor(black) msymbol(O) msize(medlarge)), ///
				xline(0, lcolor(black%10) lwidth(vvthick) lpattern(solid)) ///
				yline(0, lpattern(dash) lcolor(black)) ///
				ytitle("Effect on protests (linear-trend model)", size(medium)) ///
				ylabel(, labsize(large) format(%5.3fc) angle(0)) ///
				xtitle("Days since scandal", size(large)) ///
				xscale(range(`xlo_ax' `xhi_ax')) ///
				xlabel(`xlabs', labsize(large)) ///
				graphregion(color(white) fcolor(white)) scheme(s2color) legend(off)
			graph export ///
				"${figout}/es_`outcome'_w`T'_b`B'_`sample'_ols_`ci_level'ci_dtm.pdf", ///
				replace
		restore
	}
	}
}

display in green "a_es_detrend_model_pa_vs_na.do finished OK"
capture log close _all
