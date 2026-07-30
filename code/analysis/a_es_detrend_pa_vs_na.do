/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-07-27

    Objective:
        ANRR-style pre-trend correction for the MAIN OLS event studies.
        Following Acemoglu, Naidu, Restrepo & Robinson (2019): model the
        incoming (pre-scandal) trend PARAMETRICALLY and subtract it, so the
        pre-period is flat by construction and the post-period path is the
        de-trended effect.

        For each group's event-study path {beta_k} (k = event-time bin relative
        to the reference bin -1, normalised to 0) we fit a LINEAR trend through
        the reference origin using the PRE-scandal bins only,
                    beta_k ~ gamma * x_k   over k <= -2,   x_k = k + 1,
        (OLS through the origin, gamma_hat = sum_pre x_m beta_m / sum_pre x_m^2)
        and report the corrected coefficients
                    beta_k^c = beta_k - gamma_hat * x_k .
        Since beta_k^c is a linear combination of the fitted bin coefficients,
        each one is obtained with a single -lincom-, which returns the exact
        standard error from e(V).  (No Mata, no hand-built matrices.)

        Produced for BOTH main OLS event studies, 15-day bins, T in {30,60,90,120}:
          - POOLED  (apex & non-apex jointly; the main-text dynamics figure)
          - SUBSAMPLE (estimated separately on the pa / na samples)

    Inputs:
        - ${datfin}/protests_scandals_30days_v3.dta
        - ${datfin}/scandals_classified.csv

    Outputs (paper/figures/), a "_dt" (de-trended) sibling of each original:
        - es_pooled_<outcome>_w<T>_b15_ols_90ci_dt.pdf
        - es_<outcome>_w<T>_b15_<sample>_ols_90ci_dt.pdf
---------------------------------------------------------------------------- */

capture log close _all
log using "a_es_detrend_pa_vs_na_run.log", replace text

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

/* ============================================================
   Helper: after an event-study reghdfe, de-trend one group's path
   (dummies named <prefix>_m<j> for leads j=2..nb, <prefix>_p<j> for
   lags j=1..nb).  Returns, in bin order [-nb..-2, 0..nb-1], the
   corrected coefficients r(bc) and SEs r(sec) as 1 x (2*nb-1) rows.
   ============================================================ */
capture program drop _dt
program define _dt, rclass
	args prefix nb
	local nn = 2 * `nb' - 1

	/* linear pre-trend fitted through the origin on the lead bins:
	   gamma = sum_pre x_m beta_m / sum_pre x_m^2                        */
	local denom = 0
	local presum ""
	forvalues j = `nb'(-1)2 {
		local xm = -`j' + 1
		local denom = `denom' + `xm' * `xm'
		local presum "`presum' + (`xm') * `prefix'_m`j'"
	}
	local presum = substr("`presum'", 4, .)   /* drop leading " + " */

	tempname bc sec
	matrix `bc'  = J(1, `nn', 0)
	matrix `sec' = J(1, `nn', 0)

	local i = 0
	forvalues j = `nb'(-1)2 {
		local ++i
		local xk = -`j' + 1
		capture lincom `prefix'_m`j' - (`xk' / `denom') * (`presum')
		if _rc == 0 {
			matrix `bc'[1, `i']  = r(estimate)
			matrix `sec'[1, `i'] = r(se)
		}
	}
	forvalues j = 1/`nb' {
		local ++i
		local xk = `j'
		capture lincom `prefix'_p`j' - (`xk' / `denom') * (`presum')
		if _rc == 0 {
			matrix `bc'[1, `i']  = r(estimate)
			matrix `sec'[1, `i'] = r(se)
		}
	}
	return matrix bc  = `bc'
	return matrix sec = `sec'
end

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
   PART 1 - POOLED event study (apex & non-apex jointly), de-trended
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
		quietly reghdfe `outcome' `esvars', ///
			absorb(month day auxvar) cluster(group_cluster)

		_dt pa `nb'
		matrix bcpa  = r(bc)
		matrix secpa = r(sec)
		_dt na `nb'
		matrix bcna  = r(bc)
		matrix secna = r(sec)

		/* x-axis labels: right edge for post bins, gap at 0 */
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
			gen int    ebin = _n - `nb' - 1        /* -nb .. nb-1 */
			gen double day  = ebin * `B'
			gen double bpa = 0
			gen double sepa = 0
			gen double bna = 0
			gen double sena = 0
			forvalues r = 1/`npts' {
				local bin = `r' - `nb' - 1
				if `bin' == -1 continue
				if `bin' <= -2 local i = `nb' + `bin' + 1
				else           local i = `nb' + `bin'
				quietly replace bpa  = bcpa[1, `i']  in `r'
				quietly replace sepa = secpa[1, `i'] in `r'
				quietly replace bna  = bcna[1, `i']  in `r'
				quietly replace sena = secna[1, `i'] in `r'
			}
			replace day = day + `B' if ebin >= 0
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
				ytitle("Effect on protests (de-trended)", size(large)) ///
				ylabel(, labsize(large) format(%5.3fc) angle(0)) ///
				xtitle("Days since scandal", size(large)) ///
				xscale(range(`xlo_ax' `xhi_ax')) ///
				xlabel(`xlabs', labsize(large)) ///
				legend(order(2 "Apex" 4 "Non-Apex") rows(1) size(medium) ///
					position(6) region(lcolor(none))) ///
				graphregion(color(white) fcolor(white)) scheme(s2color)
			graph export ///
				"${figout}/es_pooled_`outcome'_w`T'_b`B'_ols_`ci_level'ci_dt.pdf", ///
				replace
		restore
	}
}

/* ============================================================
   PART 2 - SUBSAMPLE event studies (pa / na separately), de-trended
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
		gen int ebin = .
		replace ebin =  floor(window / `B') + 1          if window >= 0
		replace ebin = -(floor((-window - 1) / `B') + 1) if window <  0
		forvalues j = 2/`nb' {
			gen byte ebin_m`j' = (ebin == -`j')
		}
		forvalues j = 1/`nb' {
			gen byte ebin_p`j' = (ebin ==  `j')
		}
		quietly reghdfe `outcome' `esvars' ///
			if year >= `firstyear' & abs(window) <= `T' & in_`sample' == 1, ///
			absorb(month day auxvar) cluster(group_cluster)

		_dt ebin `nb'
		matrix bc  = r(bc)
		matrix sec = r(sec)

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
			gen int    ebin = _n - `nb' - 1
			gen double day  = ebin * `B'
			gen double b  = 0
			gen double se = 0
			forvalues r = 1/`npts' {
				local bin = `r' - `nb' - 1
				if `bin' == -1 continue
				if `bin' <= -2 local i = `nb' + `bin' + 1
				else           local i = `nb' + `bin'
				quietly replace b  = bc[1, `i']  in `r'
				quietly replace se = sec[1, `i'] in `r'
			}
			replace day = day + `B' if ebin >= 0
			gen ci_lo = b - `zcrit' * se
			gen ci_hi = b + `zcrit' * se

			twoway (rspike ci_lo ci_hi day, lcolor(black) lwidth(medthick)) ///
			       (scatter b day, mcolor(black) msymbol(O) msize(medlarge)), ///
				xline(0, lcolor(black%10) lwidth(vvthick) lpattern(solid)) ///
				yline(0, lpattern(dash) lcolor(black)) ///
				ytitle("Effect on protests (de-trended)", size(large)) ///
				ylabel(, labsize(large) format(%5.3fc) angle(0)) ///
				xtitle("Days since scandal", size(large)) ///
				xscale(range(`xlo_ax' `xhi_ax')) ///
				xlabel(`xlabs', labsize(large)) ///
				graphregion(color(white) fcolor(white)) scheme(s2color) legend(off)
			graph export ///
				"${figout}/es_`outcome'_w`T'_b`B'_`sample'_ols_`ci_level'ci_dt.pdf", ///
				replace
		restore
	}
	}
}

display in green "a_es_detrend_pa_vs_na.do finished OK"
capture log close _all
