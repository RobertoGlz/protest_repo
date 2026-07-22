/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper

   Objective:
     POOLED event study -- the dynamic analog of the interaction table
     (Table 1 / eq:interaction).  Instead of estimating a separate event
     study on the Apex and Non-Apex subsamples, we estimate ONE regression on
     the pooled sample in which the event-time bin indicators are interacted
     with the apex and non-apex flags:

        Y = sum_k ( bApex_k D_k 1{Apex} + bNA_k D_k 1{Non-Apex} )
            + month + day + country#year + e

     The bin just before disclosure (event time -1, days [-15,-1]) is the
     omitted reference for EACH group.  Because both groups are estimated
     jointly on the same sample with the same fixed effects, the resulting
     paths bApex_k and bNA_k are directly comparable to the pooled
     Post x {Apex, Non-Apex} coefficients of Table 1.

     For each outcome we overlay the Apex and Non-Apex paths on one axis.

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta
     - ${datfin}/scandals_classified.csv

   Outputs (paper/figures/):
     - es_pooled_<outcome>_w<T>_b<B>_ols_90ci.pdf
       for outcome in {num_violent_MM, num_peaceful_MM}, T in {60,120}, B=15.
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
global figout  "${identity}/Corrupcion/protest_repo/paper/figures"

local firstyear = 2008
local ci_level  = 90
local zcrit     = invnormal(0.95)   /* 1.6449 for a 90% CI */

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

egen grupo_dias    = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                           s_lead30 s_lead60 s_lead90 s_lead120)
egen group_cluster = group(country_id year grupo_dias)
egen auxvar        = group(country year)   /* country x year FE */

tempfile base
save `base'

/* ============================================================
   LOOP OVER EVENT-WINDOW WIDTH (15-day bins)
   ============================================================ */
local B = 15
foreach T in 30 60 90 120 {

	local nb = `T' / `B'                  /* bins per side */

	/* ---- names of the interacted event-time dummies ---- */
	local esvars ""
	forvalues j = `nb'(-1)2 {
		local esvars "`esvars' pa_m`j' na_m`j'"
	}
	forvalues j = 1/`nb' {
		local esvars "`esvars' pa_p`j' na_p`j'"
	}

	/* ============ PASS 1: common y-range across both outcomes ============ */
	local ymin = 0
	local ymax = 0
	foreach outcome in num_violent_MM num_peaceful_MM {
		use `base', clear
		keep if year >= `firstyear' & abs(window) <= `T'
		gen int ebin = .
		replace ebin =  floor(window / `B') + 1        if window >= 0
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
		foreach v of local esvars {
			local lo = _b[`v'] - `zcrit' * _se[`v']
			local hi = _b[`v'] + `zcrit' * _se[`v']
			local ymin = min(`ymin', `lo')
			local ymax = max(`ymax', `hi')
		}
	}
	local rng = `ymax' - `ymin'
	if `rng' <= 0 local rng = 0.01
	local ylo = `ymin' - 0.08 * `rng'
	local yhi = `ymax' + 0.08 * `rng'
	local raw = (`yhi' - `ylo') / 6
	local mag = 10 ^ floor(log10(`raw'))
	local mult = `raw' / `mag'
	if `mult' < 1.5      local step = 1  * `mag'
	else if `mult' < 3.5 local step = 2  * `mag'
	else if `mult' < 7.5 local step = 5  * `mag'
	else                 local step = 10 * `mag'
	local ylo_t = floor(`ylo' / `step') * `step'
	local yhi_t = ceil( `yhi' / `step') * `step'

	/* x-axis: PRE bins keep their left edge (-15,-30,...), POST bins use
	   their right edge (15,30,...), with the disclosure gap at 0, so the
	   axis is symmetric around 0.  15-day labels at +-60, 30-day at wider T. */
	local labday = 15
	if `B' == 15 & `T' >= 90 local labday = 30
	local xlabs ""
	forvalues bi = -`nb'/`=`nb'-1' {
		if `bi' < 0 local d = `bi' * `B'
		else        local d = (`bi' + 1) * `B'
		if mod(`d', `labday') == 0 {
			local xlabs "`xlabs' `d'"
		}
	}
	local xpad   = 0.6 * `B'
	local xlo_ax = -`nb' * `B' - `xpad'
	local xhi_ax = `nb' * `B' + `xpad'

	/* ============ PASS 2: estimate + overlay Apex vs Non-Apex ============ */
	foreach outcome in num_violent_MM num_peaceful_MM {

		use `base', clear
		keep if year >= `firstyear' & abs(window) <= `T'
		gen int ebin = .
		replace ebin =  floor(window / `B') + 1        if window >= 0
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

		/* one row per bin, keyed by the bin's start day; separate columns
		   for the Apex and Non-Apex paths (reference bin -1 = 0 for both) */
		local nrows = 2 * `nb'
		matrix B = J(`nrows', 5, .)
		matrix colnames B = day bpa sepa bna sena
		local row = 0
		forvalues bi = -`nb'/`=`nb'-1' {
			local ++row
			matrix B[`row', 1] = `bi' * `B'
			if `bi' == -1 {
				matrix B[`row', 2] = 0
				matrix B[`row', 3] = 0
				matrix B[`row', 4] = 0
				matrix B[`row', 5] = 0
			}
			else if `bi' <= -2 {
				local jj = -`bi'
				matrix B[`row', 2] = _b[pa_m`jj']
				matrix B[`row', 3] = _se[pa_m`jj']
				matrix B[`row', 4] = _b[na_m`jj']
				matrix B[`row', 5] = _se[na_m`jj']
			}
			else {
				local jj = `bi' + 1
				matrix B[`row', 2] = _b[pa_p`jj']
				matrix B[`row', 3] = _se[pa_p`jj']
				matrix B[`row', 4] = _b[na_p`jj']
				matrix B[`row', 5] = _se[na_p`jj']
			}
		}

		preserve
			clear
			svmat B, names(col)
			replace day = day + `B' if day >= 0   /* POST bins -> right edge; PRE bins keep left edge */
			gen ci_lo_pa = bpa - `zcrit' * sepa
			gen ci_hi_pa = bpa + `zcrit' * sepa
			gen ci_lo_na = bna - `zcrit' * sena
			gen ci_hi_na = bna + `zcrit' * sena
			/* small horizontal offset so Apex/Non-Apex don't overlap */
			gen double day_pa = day - 0.12 * `B'
			gen double day_na = day + 0.12 * `B'

			twoway (rspike ci_lo_pa ci_hi_pa day_pa, lcolor(navy) lwidth(medthick)) ///
			       (scatter bpa day_pa, mcolor(navy) msymbol(O) msize(medium)) ///
			       (rspike ci_lo_na ci_hi_na day_na, lcolor(cranberry) lwidth(medthick)) ///
			       (scatter bna day_na, mcolor(cranberry) msymbol(D) msize(medium)), ///
				xline(0, lcolor(black%10) lwidth(vvthick) lpattern(solid)) ///
				yline(0, lpattern(dash) lcolor(black)) ///
				ytitle("Effect on protests", size(large)) ///
				yscale(range(`ylo_t' `yhi_t')) ///
				ylabel(`ylo_t'(`step')`yhi_t', labsize(large) format(%5.3fc) angle(0)) ///
				xtitle("Days since scandal", size(large)) ///
				xscale(range(`xlo_ax' `xhi_ax')) ///
				xlabel(`xlabs', labsize(large)) ///
				legend(order(2 "Apex" 4 "Non-Apex") rows(1) ///
					size(medium) position(6) region(lcolor(none))) ///
				graphregion(color(white) fcolor(white)) scheme(s2color)
			graph export ///
				"${figout}/es_pooled_`outcome'_w`T'_b`B'_ols_`ci_level'ci.pdf", ///
				replace
		restore
	}
}

display in green "a_pooled_event_study_pa_vs_na.do finished OK"
