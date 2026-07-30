/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-07-27

    Objective:
        ANRR semiparametric-style pre-trend correction, regression-adjustment
        form.  Acemoglu, Naidu, Restrepo & Robinson (2019) assume a model for
        selection on observables (they condition on ~4 lags of the outcome) and
        then estimate the counterfactual NON-parametrically over event time.

        We do the analog for the main OLS event study: keep the full set of
        event-time bin dummies (non-parametric in event time) and CONDITION on
        the pre-scandal outcome dynamics -- K daily lags of the protest count --
        as the selection-on-observables control.  Unlike a linear-trend
        de-trend, this (i) leaves the pre-period informative (the bins are still
        estimated), and (ii) does not extrapolate a fitted slope, so a genuinely
        null margin (peaceful) stays null instead of being dragged off zero.

        The event-study coefficients are then the effect net of the conditioned
        dynamics; a flat pre-period is a specification test, as in ANRR Fig. 3.

        Produced for the main OLS event studies, 15-day bins, T in {30,60,90,120}:
          - POOLED  (apex & non-apex jointly)
          - SUBSAMPLE (pa / na separately)

    Inputs:
        - ${datfin}/protests_scandals_30days_v3.dta
        - ${datfin}/scandals_classified.csv

    Outputs (paper/figures/), a "_ra" (regression-adjustment) sibling:
        - es_pooled_<outcome>_w<T>_b15_ols_90ci_ra.pdf
        - es_<outcome>_w<T>_b15_<sample>_ols_90ci_ra.pdf
---------------------------------------------------------------------------- */

capture log close _all
log using "a_es_ra_pa_vs_na_run.log", replace text

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
local K         = 4                  /* # daily lags of the outcome (ANRR: 4) */

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

/* scandal panel id, for within-scandal daily lags of the outcome */
egen long suid = group(country id)
xtset suid window

tempfile base
save `base'

/* helper: right-edge x labels */
capture program drop _xlabs
program define _xlabs, rclass
	args nb B
	local labday = 15
	if `B' == 15 & `=`nb'*`B'' >= 90 local labday = 30
	local xlabs ""
	forvalues bi = -`nb'/`=`nb'-1' {
		if `bi' < 0 local d = `bi' * `B'
		else        local d = (`bi' + 1) * `B'
		if mod(`d', `labday') == 0 local xlabs "`xlabs' `d'"
	}
	return local xlabs "`xlabs'"
end

/* ============================================================
   PART 1 - POOLED, conditioning on K daily lags of the outcome
   ============================================================ */
foreach T in 30 60 90 120 {
	local nb = `T' / `B'

	local esvars ""
	forvalues j = `nb'(-1)2 {
		local esvars "`esvars' pa_m`j' na_m`j'"
	}
	forvalues j = 1/`nb' {
		local esvars "`esvars' pa_p`j' na_p`j'"
	}

	foreach outcome in num_violent_MM num_peaceful_MM {

		use `base', clear
		/* daily lags of THIS outcome (within scandal), then restrict window */
		local lagvars ""
		forvalues j = 1/`K' {
			gen double Lo`j' = L`j'.`outcome'
			local lagvars "`lagvars' Lo`j'"
		}
		keep if year >= `firstyear' & abs(window) <= `T'
		gen int ebin = .
		replace ebin =  floor(window / `B') + 1          if window >= 0
		replace ebin = -(floor((-window - 1) / `B') + 1) if window <  0
		forvalues j = 2/`nb' {
			gen byte pa_m`j' = (ebin == -`j') & in_pa
			gen byte na_m`j' = (ebin == -`j') & in_na
		}
		forvalues j = 1/`nb' {
			gen byte pa_p`j' = (ebin ==  `j') & in_pa
			gen byte na_p`j' = (ebin ==  `j') & in_na
		}
		quietly reghdfe `outcome' `esvars' `lagvars', ///
			absorb(month day auxvar) cluster(group_cluster)

		_xlabs `nb' `B'
		local xlabs "`r(xlabs)'"
		local xpad   = 0.6 * `B'
		local xlo_ax = -`nb' * `B' - `xpad'
		local xhi_ax =  `nb' * `B' + `xpad'

		local nrows = 2 * `nb'
		matrix M = J(`nrows', 5, .)
		matrix colnames M = day bpa sepa bna sena
		local row = 0
		forvalues bi = -`nb'/`=`nb'-1' {
			local ++row
			matrix M[`row', 1] = `bi' * `B'
			if `bi' == -1 {
				matrix M[`row', 2] = 0
				matrix M[`row', 3] = 0
				matrix M[`row', 4] = 0
				matrix M[`row', 5] = 0
			}
			else if `bi' <= -2 {
				local jj = -`bi'
				matrix M[`row', 2] = _b[pa_m`jj']
				matrix M[`row', 3] = _se[pa_m`jj']
				matrix M[`row', 4] = _b[na_m`jj']
				matrix M[`row', 5] = _se[na_m`jj']
			}
			else {
				local jj = `bi' + 1
				matrix M[`row', 2] = _b[pa_p`jj']
				matrix M[`row', 3] = _se[pa_p`jj']
				matrix M[`row', 4] = _b[na_p`jj']
				matrix M[`row', 5] = _se[na_p`jj']
			}
		}

		preserve
			clear
			svmat M, names(col)
			replace day = day + `B' if day >= 0
			gen ci_lo_pa = bpa - `zcrit'*sepa
			gen ci_hi_pa = bpa + `zcrit'*sepa
			gen ci_lo_na = bna - `zcrit'*sena
			gen ci_hi_na = bna + `zcrit'*sena
			gen double day_pa = day - 0.12*`B'
			gen double day_na = day + 0.12*`B'

			twoway (rspike ci_lo_pa ci_hi_pa day_pa, lcolor(navy) lwidth(medthick)) ///
			       (scatter bpa day_pa, mcolor(navy) msymbol(O) msize(medium)) ///
			       (rspike ci_lo_na ci_hi_na day_na, lcolor(cranberry) lwidth(medthick)) ///
			       (scatter bna day_na, mcolor(cranberry) msymbol(D) msize(medium)), ///
				xline(0, lcolor(black%10) lwidth(vvthick) lpattern(solid)) ///
				yline(0, lpattern(dash) lcolor(black)) ///
				ytitle("Effect on protests (lag-adjusted)", size(medium)) ///
				ylabel(, labsize(large) format(%5.3fc) angle(0)) ///
				xtitle("Days since scandal", size(large)) ///
				xscale(range(`xlo_ax' `xhi_ax')) ///
				xlabel(`xlabs', labsize(large)) ///
				legend(order(2 "Apex" 4 "Non-Apex") rows(1) size(medium) ///
					position(6) region(lcolor(none))) ///
				graphregion(color(white) fcolor(white)) scheme(s2color)
			graph export ///
				"${figout}/es_pooled_`outcome'_w`T'_b`B'_ols_`ci_level'ci_ra.pdf", ///
				replace
		restore
	}
}

/* ============================================================
   PART 2 - SUBSAMPLE (pa / na), conditioning on K daily lags
   ============================================================ */
foreach T in 30 60 90 120 {
	local nb = `T' / `B'

	local esvars ""
	forvalues j = `nb'(-1)2 {
		local esvars "`esvars' ebin_m`j'"
	}
	forvalues j = 1/`nb' {
		local esvars "`esvars' ebin_p`j'"
	}

	foreach sample in pa na {
	foreach outcome in num_violent_MM num_peaceful_MM {

		use `base', clear
		local lagvars ""
		forvalues j = 1/`K' {
			gen double Lo`j' = L`j'.`outcome'
			local lagvars "`lagvars' Lo`j'"
		}
		gen int ebin = .
		replace ebin =  floor(window / `B') + 1          if window >= 0
		replace ebin = -(floor((-window - 1) / `B') + 1) if window <  0
		forvalues j = 2/`nb' {
			gen byte ebin_m`j' = (ebin == -`j')
		}
		forvalues j = 1/`nb' {
			gen byte ebin_p`j' = (ebin ==  `j')
		}

		quietly reghdfe `outcome' `esvars' `lagvars' ///
			if year >= `firstyear' & abs(window) <= `T' & in_`sample' == 1, ///
			absorb(month day auxvar) cluster(group_cluster)

		_xlabs `nb' `B'
		local xlabs "`r(xlabs)'"
		local xpad   = 0.6 * `B'
		local xlo_ax = -`nb' * `B' - `xpad'
		local xhi_ax =  `nb' * `B' + `xpad'

		local nrows = 2 * `nb'
		matrix M = J(`nrows', 3, .)
		matrix colnames M = day b se
		local row = 0
		forvalues bi = -`nb'/`=`nb'-1' {
			local ++row
			matrix M[`row', 1] = `bi' * `B'
			if `bi' == -1 {
				matrix M[`row', 2] = 0
				matrix M[`row', 3] = 0
			}
			else if `bi' <= -2 {
				local jj = -`bi'
				matrix M[`row', 2] = _b[ebin_m`jj']
				matrix M[`row', 3] = _se[ebin_m`jj']
			}
			else {
				local jj = `bi' + 1
				matrix M[`row', 2] = _b[ebin_p`jj']
				matrix M[`row', 3] = _se[ebin_p`jj']
			}
		}

		preserve
			clear
			svmat M, names(col)
			replace day = day + `B' if day >= 0
			gen ci_lo = b - `zcrit'*se
			gen ci_hi = b + `zcrit'*se

			twoway (rspike ci_lo ci_hi day, lcolor(black) lwidth(medthick)) ///
			       (scatter b day, mcolor(black) msymbol(O) msize(medlarge)), ///
				xline(0, lcolor(black%10) lwidth(vvthick) lpattern(solid)) ///
				yline(0, lpattern(dash) lcolor(black)) ///
				ytitle("Effect on protests (lag-adjusted)", size(medium)) ///
				ylabel(, labsize(large) format(%5.3fc) angle(0)) ///
				xtitle("Days since scandal", size(large)) ///
				xscale(range(`xlo_ax' `xhi_ax')) ///
				xlabel(`xlabs', labsize(large)) ///
				graphregion(color(white) fcolor(white)) scheme(s2color) legend(off)
			graph export ///
				"${figout}/es_`outcome'_w`T'_b`B'_`sample'_ols_`ci_level'ci_ra.pdf", ///
				replace
		restore
	}
	}
}

display in green "a_es_ra_pa_vs_na.do finished OK"
capture log close _all
