/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper

   Code author: Roberto Gonzalez
   Date: 2026-07-14

   Objective:
     OLS event studies of \autoref{eq:main}, estimated separately on the
     two apex-partition subsamples (pa = Apex, na = Non-Apex), for every
     event-window width T in {30, 60, 90, 120} and two bin widths:

        B = 15 days  -> main specification
        B = 30 days  -> appendix version

     Event-time bins are built directly from the window variable, so
     any (T, B) combination is available (the pre-built s_lag and s_lead
     dummies only support 30-day bins).  Bin -1 (the B days immediately
     preceding disclosure) is the omitted reference.

     KEY: within each (T, B) cell the FOUR panels -- violent/peaceful x
     Apex/Non-Apex -- share a COMMON y-axis range, so the four plots can
     be compared by eye and the zero line is aligned across all of them.

     Axis labels are enlarged relative to the previous version.

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta
     - ${datfin}/scandals_classified.csv

   Outputs (paper/figures/):
     - es_<outcome>_w<T>_b<B>_<sample>_ols_90ci.pdf
       for outcome in {num_violent_MM, num_peaceful_MM},
           T in {30,60,90,120}, B in {15,30}, sample in {pa, na}.
     (T=30 with B=30 is skipped: only one bin per side.)
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
global figout  "${identity}/Corrupcion/protest_repo/paper/figures"

capture log close _all
log using "${identity}/Corrupcion/protest_repo/code/analysis/a_sup_event_study_pa_vs_na.log", replace text

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

/* Clustering / FE identifiers (same as the tables) */
egen grupo_dias    = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                           s_lead30 s_lead60 s_lead90 s_lead120)
egen group_cluster = group(country_id year grupo_dias)
egen auxvar        = group(country year)   /* country x year FE */

tempfile base
save `base'

/* ============================================================
   LOOP OVER BIN WIDTH AND EVENT-WINDOW WIDTH
   ============================================================ */
foreach B in 15 30 {
foreach T in 30 60 90 120 {

	local nb = `T' / `B'                  /* bins per side */
	if `nb' < 2 {
		display in yellow "SKIP: T=`T', B=`B' gives only `nb' bin(s) per side."
		continue
	}

	/* ---- names of the event-time dummies and their axis labels ---- */
	local esvars ""
	local eslabs ""
	forvalues j = `nb'(-1)2 {
		local esvars "`esvars' ebin_m`j'"
		local lo = -`j' * `B'
		local eslabs `"`eslabs' ebin_m`j' = "`lo'""'
	}
	forvalues j = 1/`nb' {
		local esvars "`esvars' ebin_p`j'"
		local lo = (`j' - 1) * `B'
		local eslabs `"`eslabs' ebin_p`j' = "`lo'""'
	}

	/* ============ PASS 1: common y-range across all four panels ============ */
	local ymin = 0
	local ymax = 0

	foreach sample in pa na {
	foreach outcome in num_violent_MM num_peaceful_MM {

		use `base', clear
		/* event-time bin index; bin -1 (the B days before) is the reference */
		gen int ebin = .
		replace ebin =  floor(window / `B') + 1        if window >= 0
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

		foreach v of local esvars {
			local lo = _b[`v'] - `zcrit' * _se[`v']
			local hi = _b[`v'] + `zcrit' * _se[`v']
			local ymin = min(`ymin', `lo')
			local ymax = max(`ymax', `hi')
		}
	}
	}

	/* padded, rounded tick sequence spanning [ymin, ymax] (0 always inside) */
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

	display in green "T=`T', B=`B': common y-range [`ylo_t', `yhi_t'] step `step'"

	/* ---- x-axis labels: 15-day labels (every bin) in the +-30 and +-60
	        windows; 30-day labels (every other bin) in the wider +-90 and
	        +-120 windows so labels do not pile up.  With 30-day bins every
	        bin is already 30 days, so label every bin. ---- */
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

	/* ---- x-axis range with a small gap on each side, so the first
	        coefficient is not jammed against the y-axis ---- */
	local xpad   = 0.6 * `B'
	local xlo_ax = -`nb' * `B' - `xpad'
	local xhi_ax = `nb' * `B' + `xpad'

	/* ============ PASS 2: plot each panel with the fixed range ============
	   Manual twoway (not coefplot) so the format is identical across
	   windows: the omitted reference bin (days [-`B',-1]) is shown as a
	   point at 0, a faint thick vertical line marks the disclosure cutoff
	   between the reference bin and bin 0, and the x-axis is continuous in
	   days.                                                                 */
	foreach sample in pa na {
	foreach outcome in num_violent_MM num_peaceful_MM {

		use `base', clear
		gen int ebin = .
		replace ebin =  floor(window / `B') + 1        if window >= 0
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

		/* one row per bin (incl. the reference bin at 0), keyed by the
		   bin's start day */
		local nrows = 2 * `nb'
		matrix B = J(`nrows', 3, .)
		matrix colnames B = day b se
		local row = 0
		forvalues bi = -`nb'/`=`nb'-1' {
			local ++row
			matrix B[`row', 1] = `bi' * `B'
			if `bi' == -1 {
				matrix B[`row', 2] = 0
				matrix B[`row', 3] = 0
			}
			else if `bi' <= -2 {
				local jj = -`bi'
				matrix B[`row', 2] = _b[ebin_m`jj']
				matrix B[`row', 3] = _se[ebin_m`jj']
			}
			else {
				local jj = `bi' + 1
				matrix B[`row', 2] = _b[ebin_p`jj']
				matrix B[`row', 3] = _se[ebin_p`jj']
			}
		}

		preserve
			clear
			svmat B, names(col)
			replace day = day + `B' if day >= 0   /* POST bins -> right edge; PRE keep left edge */
			gen ci_lo = b - `zcrit' * se
			gen ci_hi = b + `zcrit' * se

			twoway (rspike ci_lo ci_hi day, lcolor(black) lwidth(medthick)) ///
			       (scatter b day, mcolor(black) msymbol(O) msize(medlarge)), ///
				xline(0, lcolor(black%10) lwidth(vvthick) lpattern(solid)) ///
				yline(0, lpattern(dash) lcolor(black)) ///
				ytitle("Effect on protests", size(large)) ///
				yscale(range(`ylo_t' `yhi_t')) ///
				ylabel(`ylo_t'(`step')`yhi_t', labsize(large) format(%5.3fc) angle(0)) ///
				xtitle("Days since scandal", size(large)) ///
				xscale(range(`xlo_ax' `xhi_ax')) ///
				xlabel(`xlabs', labsize(large)) ///
				graphregion(color(white) fcolor(white)) scheme(s2color) legend(off)
			graph export ///
				"${figout}/es_`outcome'_w`T'_b`B'_`sample'_ols_`ci_level'ci.pdf", ///
				replace
		restore
	}
	}
}
}

display in green "a_sup_event_study_pa_vs_na.do finished OK"

capture log close _all
