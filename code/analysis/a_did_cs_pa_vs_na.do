/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-07-25

    Objective:
        Callaway & Sant'Anna (2021) doubly-robust staggered DiD as a ROBUSTNESS
        check, in the spirit of Acemoglu, Naidu, Restrepo & Robinson (2019,
        Table 5): the same estimator run three ways,

            method(reg)    = outcome-regression adjustment      (their Panel A)
            method(ipw)    = inverse-propensity-score weighting  (their Panel B)
            method(dripw)  = doubly robust                       (their Panel C)

        conditioning on a BASELINE pre-scandal protest covariate -- the direct
        analog of Acemoglu et al.'s "four lags of GDP".  The event-study
        aggregation gives the pre-scandal placebo (lead) coefficients, so we can
        show a FLAT pre-trend before disclosure and a robust post effect.

        Run SEPARATELY on the two apex-partition subsamples of main Table~1:
            - pa : President + Other Apex   scandals
            - na : Other Non-Apex           scandals
        on a country x 15-day-bin panel, aggregated to +-60/90/120-day windows.

    Control group (clean):
        Treated  = countries with an in-subsample (pa/na) scandal; cohort = bin
                   of their FIRST such scandal.
        Controls = countries with NO scandal of ANY type over 2008-2018
                   (gvar = 0, never treated).  Countries that have scandals only
                   of the OTHER type are dropped from the estimation, so the
                   comparison group is clean, exactly as in the imputation and
                   stacked designs.

    Requires:  csdid, drdid  (ssc install csdid, replace ; ssc install drdid, replace)

    Outputs (paper/{tables,figures}/):
        - did_cs_es_mm_violent_<sample>_w<T>.pdf   (event study: reg/ipw/dr overlaid)
        - did_cs_main_<sample>.tex                  (windowed ATT + pre-trend p)
      where <sample> in {pa, na}, <T> in {60, 90, 120}.
---------------------------------------------------------------------------- */

set more off
clear all

capture which csdid
if _rc ssc install csdid, replace
capture which drdid
if _rc ssc install drdid, replace

if "`c(username)'" == "lalov" {
	gl identity "C:\Users\lalov\ITAM Seira Research Dropbox\Eduardo Rivera"
}
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox"
}
if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}

global work   "${identity}/Corrupcion/Protest_Work"
global path   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"
global tabout "${identity}/Corrupcion/protest_repo/paper/tables"
global figout "${identity}/Corrupcion/protest_repo/paper/figures"

local BIN = 15                       /* bin width in days */

/* ============================================================
   STEP 0 - subsample-specific first-scandal date per country
   ============================================================ */
import delimited using "${datfin}/scandals_classified.csv", ///
	clear varnames(1) bindquotes(strict)
keep id country position
tempfile cls
save `cls'

use "${datfin}/protests_scandals_30days_v3", clear
keep if window == 0
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

preserve
	keep if in_pa == 1
	bysort country: egen double fs_pa = min(date)
	format fs_pa %td
	keep country fs_pa
	duplicates drop
	tempfile pa_dates
	save `pa_dates'
restore

preserve
	keep if in_na == 1
	bysort country: egen double fs_na = min(date)
	format fs_na %td
	keep country fs_na
	duplicates drop
	tempfile na_dates
	save `na_dates'
restore

/* ============================================================
   STEP 1 - collapse the country-DAY panel into 15-day calendar
   bins on a fixed grid anchored on 1 Jan 2008.
   ============================================================ */
use "${datfin}/panel_country_day.dta", clear
keep if year >= 2008

local anchor = mdy(1, 1, 2008)
gen long bin_idx = floor((date - `anchor') / `BIN') + 1

/* country has a scandal of ANY type in this country-year? */
bysort country year: egen byte cy_scan = max(scandal_today)

collapse (sum) mm_protests mm_violent mm_nonviolent mm_gvr ///
         (firstnm) country_id (max) cy_any_scandal = cy_scan, ///
	by(country bin_idx)

gen long bin_start = `anchor' + (bin_idx - 1) * `BIN'
format bin_start %td

/* a country that has NO scandal of any type in ANY year is a clean control */
bysort country: egen byte ever_any_scandal = max(cy_any_scandal)

tempfile binpanel
save `binpanel'

/* postfile to accumulate the violent-outcome event-study paths for plotting */
tempname P
tempfile plotdata
postfile `P' str4 sample int T str8 method int etime double days ///
	double b double se using "`plotdata'", replace

/* ============================================================
   SAMPLE LOOP
   ============================================================ */
foreach sample in pa na {

	di as result _newline _newline ///
		"================================================================="  _n ///
		"   CALLAWAY & SANT'ANNA DR-DiD  --  sample=`sample'"                 _n ///
		"================================================================="

	capture scalar drop _all   /* reset stored cells between subsamples */

	/* ---- attach the subsample's first-scandal bin, build gvar ---- */
	use `binpanel', clear
	if "`sample'" == "pa" {
		merge m:1 country using `pa_dates', keep(1 3) nogenerate
		rename fs_pa first_scandal_date
	}
	else {
		merge m:1 country using `na_dates', keep(1 3) nogenerate
		rename fs_na first_scandal_date
	}
	format first_scandal_date %td

	gen byte ever_treated = !missing(first_scandal_date)
	gen long first_scandal_bin = ///
		floor((first_scandal_date - `anchor') / `BIN') + 1 if ever_treated

	/* keep treated countries (full trajectory) + clean never-any-scandal
	   controls; drop countries whose only scandals are of the OTHER type */
	keep if ever_treated == 1 | ever_any_scandal == 0

	/* Callaway-Sant'Anna group variable: cohort bin, 0 for never-treated */
	gen long gvar = cond(ever_treated == 1, first_scandal_bin, 0)

	xtset country_id bin_idx

	tempfile samp
	save `samp'

	/* pre-initialise every table cell to missing so the write-out loop
	   never references an undefined scalar (Stata does not short-circuit) */
	foreach method in reg ipw dripw {
	foreach tg in v nv {
	foreach T in 60 90 120 {
		scalar B_`method'_`tg'_`T'  = .
		scalar S_`method'_`tg'_`T'  = .
		scalar PP_`method'_`tg'_`T' = .
	}
	}
	}

	/* store static/pretrend numbers keyed by method x outcome x window */
	foreach oc in mm_violent mm_nonviolent {

		local tag = cond("`oc'" == "mm_violent", "v", "nv")

		use `samp', clear

		/* baseline pre-scandal protest intensity (country-level, time-
		   invariant): mean of the outcome over each country's PRE-treatment
		   bins (all bins for never-treated).  This is the analog of Acemoglu
		   et al.'s conditioning on recent GDP. */
		gen double _pre = `oc' if (gvar == 0 | bin_idx < gvar)
		bysort country_id: egen double basecov = mean(_pre)
		drop _pre

		foreach method in reg ipw dripw {

			di as result "--- CS-DiD `method' : `oc' [`sample'] ---"
			capture noisily csdid `oc' basecov, ///
				ivar(country_id) time(bin_idx) gvar(gvar) method(`method')
			if _rc {
				display in red "csdid failed: `method' `oc' [`sample'] (rc=`_rc')"
				continue
			}

			foreach T in 60 90 120 {
				local nbin = `T' / `BIN'

				/* aggregate to an event study restricted to the +-T window;
				   csdid_estat returns the table in r(table), with columns
				   Tm# / Tp# (event time) plus Pre_avg / Post_avg. */
				capture noisily estat event, window(-`nbin' `=`nbin'-1')
				if _rc continue
				matrix rt = r(table)
				local cols : colnames rt

				/* windowed post ATT + its two-sided p */
				local jp = colnumb(rt, "Post_avg")
				local att = rt[1, `jp']
				local ase = rt[2, `jp']
				/* average pre (placebo) ATT + its p = flat-pretrend check */
				local jm = colnumb(rt, "Pre_avg")
				local pre  = rt[1, `jm']
				local pse  = rt[2, `jm']
				local pp   = 2 * normal(-abs(`pre' / `pse'))

				scalar B_`method'_`tag'_`T'  = `att'
				scalar S_`method'_`tag'_`T'  = `ase'
				scalar PP_`method'_`tag'_`T' = `pp'

				/* store the full lead/lag path (violent only) for the figure */
				if "`oc'" == "mm_violent" {
					forvalues k = `nbin'(-1)2 {
						local j = colnumb(rt, "Tm`k'")
						if `j' < . {
							post `P' ("`sample'") (`T') ("`method'") ///
								(-`k') (-`k' * `BIN') (rt[1,`j']) (rt[2,`j'])
						}
					}
					/* reference bin -1 pinned to 0 */
					post `P' ("`sample'") (`T') ("`method'") ///
						(-1) (-1 * `BIN') (0) (0)
					forvalues k = 0/`=`nbin'-1' {
						local j = colnumb(rt, "Tp`k'")
						if `j' < . {
							post `P' ("`sample'") (`T') ("`method'") ///
								(`k') (`k' * `BIN') (rt[1,`j']) (rt[2,`j'])
						}
					}
				}
			}
		}
	}

	/* ---------- compact per-sample table (Acemoglu Table 5 style) ----------
	   rows = the three CS estimators; columns = Violent / Non-violent, each at
	   +-60/90/120; then a pre-trend p-value block. ---------- */
	capture file close _tbl
	file open _tbl using "${tabout}/did_cs_main_`sample'.tex", write replace
	file write _tbl "{" _n
	file write _tbl "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
	file write _tbl "\begin{tabular}{l*{6}{c}}" _n
	file write _tbl "\toprule" _n
	file write _tbl " & \multicolumn{3}{c}{Violent Protests} & \multicolumn{3}{c}{Non-violent Protests} \\" _n
	file write _tbl "\cmidrule(lr){2-4}\cmidrule(lr){5-7}" _n
	file write _tbl " & \ensuremath{\pm 60} & \ensuremath{\pm 90} & \ensuremath{\pm 120} & \ensuremath{\pm 60} & \ensuremath{\pm 90} & \ensuremath{\pm 120} \\" _n
	file write _tbl "\midrule" _n
	file write _tbl "\multicolumn{7}{l}{\textit{Panel A: windowed ATT (average post-scandal effect)}}\\" _n
	foreach method in reg ipw dripw {
		if "`method'" == "reg"   local rl "Regression adj."
		if "`method'" == "ipw"   local rl "IPW"
		if "`method'" == "dripw" local rl "Doubly robust"
		local brow "`rl'"
		local srow "            "
		foreach tag in v nv {
		foreach T in 60 90 120 {
			local b = B_`method'_`tag'_`T'
			local s = S_`method'_`tag'_`T'
			if missing(`b') | missing(`s') | `s' <= 0 {
				local brow "`brow' & --"
				local srow "`srow' & "
			}
			else {
				local pv = 2*normal(-abs(`b'/`s'))
				local st = ""
				if `pv' < 0.10 local st = "*"
				if `pv' < 0.05 local st = "**"
				if `pv' < 0.01 local st = "***"
				if "`st'" != "" local bcell = string(`b',"%5.3f") + "\sym{`st'}"
				else            local bcell = string(`b',"%5.3f")
				local scell = "(" + string(`s',"%5.3f") + ")"
				local brow "`brow' & `bcell'"
				local srow "`srow' & `scell'"
			}
		}
		}
		file write _tbl "`brow' \\" _n
		file write _tbl "`srow' \\" _n
	}
	file write _tbl "\midrule" _n
	file write _tbl "\multicolumn{7}{l}{\textit{Panel B: pre-trend test, \(p\)-value (avg.\ pre-scandal placebo ATT \(=0\))}}\\" _n
	foreach method in reg ipw dripw {
		if "`method'" == "reg"   local rl "Regression adj."
		if "`method'" == "ipw"   local rl "IPW"
		if "`method'" == "dripw" local rl "Doubly robust"
		local prow "`rl'"
		foreach tag in v nv {
		foreach T in 60 90 120 {
			local p = PP_`method'_`tag'_`T'
			if missing(`p') {
				local prow "`prow' & --"
			}
			else {
				local pcell = string(`p',"%4.3f")
				local prow "`prow' & `pcell'"
			}
		}
		}
		file write _tbl "`prow' \\" _n
	}
	file write _tbl "\bottomrule" _n
	file write _tbl "\end{tabular}" _n
	file write _tbl "}" _n
	file close _tbl
	display in green "did_cs_main_`sample'.tex written"
}

postclose `P'

/* ============================================================
   FIGURES: violent-protest event study, reg / ipw / dr overlaid,
   in the same 15-day-bin, right-edge-labelled style as the other
   DiD event-study figures.
   ============================================================ */
use "`plotdata'", clear
gen double lo = b - 1.645 * se
gen double hi = b + 1.645 * se

foreach sample in pa na {
foreach T in 60 90 120 {

	local nbin = `T' / `BIN'

	preserve
		keep if sample == "`sample'" & T == `T'
		if _N == 0 {
			restore
			continue
		}

		/* POST bins -> right edge; PRE bins keep their left edge */
		replace days = days + `BIN' if etime >= 0

		/* x labels: every bin at +-60, every other bin at wider windows */
		local labday = 15
		if `T' >= 90 local labday = 30
		local xlabs ""
		forvalues bi = -`nbin'/`=`nbin'-1' {
			if `bi' < 0 local d = `bi' * `BIN'
			else        local d = (`bi' + 1) * `BIN'
			if mod(`d', `labday') == 0 local xlabs "`xlabs' `d'"
		}
		local xpad   = 0.6 * `BIN'
		local xlo_ax = -`nbin' * `BIN' - `xpad'
		local xhi_ax = `nbin' * `BIN' + `xpad'

		/* small horizontal offsets so the three estimators don't overlap */
		gen double days_p = days
		replace     days_p = days - 0.15 * `BIN' if method == "reg"
		replace     days_p = days                if method == "ipw"
		replace     days_p = days + 0.15 * `BIN' if method == "dripw"

		twoway ///
			(rspike lo hi days_p if method=="reg",   lcolor(navy)         lwidth(medthick)) ///
			(scatter b days_p    if method=="reg",   mcolor(navy)         msymbol(O)  msize(medium)) ///
			(rspike lo hi days_p if method=="ipw",   lcolor(cranberry)    lwidth(medthick)) ///
			(scatter b days_p    if method=="ipw",   mcolor(cranberry)    msymbol(T)  msize(medium)) ///
			(rspike lo hi days_p if method=="dripw", lcolor(forest_green) lwidth(medthick)) ///
			(scatter b days_p    if method=="dripw", mcolor(forest_green) msymbol(D)  msize(medium)), ///
			yline(0, lcolor(red) lpattern(solid) lwidth(medthin)) ///
			xline(0, lcolor(black%20) lpattern(solid) lwidth(vthick)) ///
			xtitle("Days since scandal", size(large)) ///
			ytitle("Number of violent protests", size(large)) ///
			ylabel(, labsize(large) format(%4.2fc) angle(0)) ///
			xscale(range(`xlo_ax' `xhi_ax')) ///
			xlabel(`xlabs', labsize(large)) ///
			legend(order(2 "Reg. adj." 4 "IPW" 6 "Doubly robust") ///
				rows(1) size(medium) position(6) region(lcolor(none))) ///
			graphregion(color(white)) scheme(s2color)
		graph export "${figout}/did_cs_es_mm_violent_`sample'_w`T'.pdf", replace
	restore
}
}

display in green "a_did_cs_pa_vs_na.do finished OK"
