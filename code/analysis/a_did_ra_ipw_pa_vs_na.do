/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-07-25

    Objective:
        A TRANSPARENT robustness check in the spirit of Acemoglu, Naidu,
        Restrepo & Robinson (2019): condition the event study on the outcome's
        own pre-scandal dynamics and on a propensity reweighting, and show that
        (i) the post-scandal effect is stable and (ii) the pre-scandal LEAD
        coefficients stay flat.  Everything is built by hand from reghdfe +
        probit, so each step is legible:

            No adjustment  : event study with country + 15-day-bin FE only (TWFE)
            Regression adj.: + J lags of the outcome        (Acemoglu Panel A)
            IPW            : reweight clean controls by p/(1-p), where p is the
                             propensity of being a treated country given a
                             baseline protest covariate   (Acemoglu Panel B)
            Doubly robust  : IPW weights AND outcome lags   (Acemoglu Panel C)

        Run SEPARATELY on the two apex-partition subsamples (pa / na) on the
        country x 15-day-bin panel, at +-60/90/120-day windows.  The J outcome
        lags are the direct analog of Acemoglu et al.'s "four lags of GDP".

    Control group: identical clean-control rule as the imputation design
        (a_did_modern_pa_vs_na.do): never-treated country-YEARS that contain a
        scandal of any type are dropped; treated countries keep their full
        trajectory.  So the "No adjustment" column reproduces the existing
        OLS TWFE event study, and the other columns are perturbations of it.

    Outputs (paper/{tables,figures}/):
        - did_ra_es_mm_violent_<sample>_w<T>.pdf  (event study: 4 specs overlaid)
        - did_ra_main_<sample>.tex                 (windowed ATT + pre-trend p)
      where <sample> in {pa, na}, <T> in {60, 90, 120}.
---------------------------------------------------------------------------- */

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

global work   "${identity}/Corrupcion/Protest_Work"
global path   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"
global tabout "${identity}/Corrupcion/protest_repo/paper/tables"
global figout "${identity}/Corrupcion/protest_repo/paper/figures"

local BIN = 15                       /* bin width in days */
local J   = 4                        /* # of outcome lags (Acemoglu use 4) */

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
capture confirm string variable id
if _rc==0 {
	drop if id == "TWNEWLATINO14" & country == "Ecuador"   // duplicate of scandal 108 (Alex Bravo, Petroecuador)
	drop if id == "TWNEWLATINO23" & country == "Brazil"     // Gurgel statement, not a corruption scandal
}
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
   STEP 1 - collapse the country-DAY panel into 15-day bins
   ============================================================ */
use "${datfin}/panel_country_day.dta", clear
keep if year >= 2008

local anchor = mdy(1, 1, 2008)
gen long bin_idx = floor((date - `anchor') / `BIN') + 1
gen int  binyear = year(`anchor' + (bin_idx - 1) * `BIN')

bysort country year: egen byte cy_scan = max(scandal_today)

collapse (sum) mm_protests mm_violent mm_nonviolent mm_gvr ///
         (firstnm) country_id (max) cy_any_scandal = cy_scan ///
         (firstnm) binyear, ///
	by(country bin_idx)

tempfile binpanel
save `binpanel'

/* postfile for the violent-outcome event-study paths (all four specs) */
tempname P
tempfile plotdata
postfile `P' str4 sample int T str6 spec int etime double days ///
	double b double se using "`plotdata'", replace

/* ============================================================
   SAMPLE LOOP
   ============================================================ */
foreach sample in pa na {

	di as result _newline _newline ///
		"================================================================="  _n ///
		"   RA / IPW / DR event study  --  sample=`sample'"                   _n ///
		"================================================================="

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

	/* clean controls: drop never-treated country-YEARS with any scandal */
	drop if ever_treated == 0 & cy_any_scandal == 1

	xtset country_id bin_idx
	gen long etime = bin_idx - first_scandal_bin if ever_treated == 1

	tempfile samp
	save `samp'

	/* pre-initialise every table cell to missing so the write-out loop
	   never references an undefined scalar (Stata does not short-circuit) */
	foreach spec in none ra ipw dr {
	foreach tg in v nv {
	foreach T in 60 90 120 {
		scalar B_`spec'_`tg'_`T'  = .
		scalar S_`spec'_`tg'_`T'  = .
		scalar PP_`spec'_`tg'_`T' = .
	}
	}
	}

	foreach oc in mm_violent mm_nonviolent {

		local tag = cond("`oc'" == "mm_violent", "v", "nv")

		use `samp', clear

		/* ---- J lags of the outcome (computed on the full series) ---- */
		local lagvars ""
		forvalues j = 1/`J' {
			gen double Lo`j' = L`j'.`oc'
			local lagvars "`lagvars' Lo`j'"
		}

		/* ---- baseline pre-scandal protest intensity (country level) ---- */
		gen double _pre = `oc' if (ever_treated == 0 | bin_idx < first_scandal_bin)
		bysort country_id: egen double basecov = mean(_pre)
		drop _pre

		/* ---- propensity of being a treated country given the baseline
		        covariate; Abadie/Sant'Anna-Zhao IPW weights ---- */
		preserve
			keep country_id ever_treated basecov
			duplicates drop
			capture probit ever_treated basecov
			if _rc {
				gen double pscore = .
			}
			else {
				predict double pscore, pr
			}
			keep country_id pscore
			tempfile ps
			save `ps'
		restore
		merge m:1 country_id using `ps', nogenerate
		replace pscore = min(max(pscore, .001), .999)
		gen double ipw = cond(ever_treated == 1, 1, ///
			cond(missing(pscore), 1, pscore / (1 - pscore)))

		/* ---- window loop: build event dummies, run the 4 specs ---- */
		foreach T in 60 90 120 {
			local nbin = `T' / `BIN'

			capture drop ev_lead* ev_lag*
			local esv ""
			local leadv ""
			local lagv ""
			forvalues k = `nbin'(-1)2 {
				gen byte ev_lead`k' = (etime == -`k') & ever_treated == 1
				local esv   "`esv' ev_lead`k'"
				local leadv "`leadv' ev_lead`k'"
			}
			forvalues k = 0/`=`nbin'-1' {
				gen byte ev_lag`k' = (etime == `k') & ever_treated == 1
				local esv  "`esv' ev_lag`k'"
				local lagv "`lagv' ev_lag`k'"
			}

			/* windowed post-average = (ev_lag0+...+ev_lag[nbin-1]) / nbin */
			local postsum ""
			forvalues k = 0/`=`nbin'-1' {
				local postsum "`postsum' + ev_lag`k'"
			}
			local postsum = subinstr("`postsum'", "+", "", 1)   /* drop leading + */
			local postexpr "(`postsum') / `nbin'"

			/* estimation sample: all clean-control obs + treated obs inside
			   the +-T window (far treated periods excluded, not binned to 0) */
			gen byte insamp`T' = (ever_treated == 0) | ///
				inrange(etime, -`nbin', `=`nbin'-1')

			foreach spec in none ra ipw dr {

				if "`spec'" == "none" local rhs "`esv'"
				if "`spec'" == "ra"   local rhs "`esv' `lagvars'"
				if "`spec'" == "ipw"  local rhs "`esv'"
				if "`spec'" == "dr"   local rhs "`esv' `lagvars'"
				local wgt ""
				if inlist("`spec'", "ipw", "dr") local wgt "[pw=ipw]"

				capture noisily reghdfe `oc' `rhs' `wgt' if insamp`T' == 1, ///
					absorb(country_id bin_idx) cluster(country_id)
				if _rc {
					display in red "reghdfe failed: `spec' `oc' `sample' w`T'"
					continue
				}

				/* windowed post ATT */
				capture quietly lincom `postexpr'
				if _rc == 0 {
					scalar B_`spec'_`tag'_`T' = r(estimate)
					scalar S_`spec'_`tag'_`T' = r(se)
				}
				/* joint pre-trend test on the lead coefficients */
				capture quietly test `leadv'
				if _rc == 0 scalar PP_`spec'_`tag'_`T' = r(p)

				/* store the event-study path (violent only) for the figure */
				if "`oc'" == "mm_violent" {
					forvalues k = `nbin'(-1)2 {
						post `P' ("`sample'") (`T') ("`spec'") ///
							(-`k') (-`k' * `BIN') (_b[ev_lead`k']) (_se[ev_lead`k'])
					}
					post `P' ("`sample'") (`T') ("`spec'") (-1) (-1 * `BIN') (0) (0)
					forvalues k = 0/`=`nbin'-1' {
						post `P' ("`sample'") (`T') ("`spec'") ///
							(`k') (`k' * `BIN') (_b[ev_lag`k']) (_se[ev_lag`k'])
					}
				}
			}
			drop insamp`T'
		}
	}

	/* ---------- compact per-sample table ---------- */
	capture file close _tbl
	file open _tbl using "${tabout}/did_ra_main_`sample'.tex", write replace
	file write _tbl "{" _n
	file write _tbl "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
	file write _tbl "\begin{tabular}{l*{6}{c}}" _n
	file write _tbl "\toprule" _n
	file write _tbl " & \multicolumn{3}{c}{Violent Protests} & \multicolumn{3}{c}{Non-violent Protests} \\" _n
	file write _tbl "\cmidrule(lr){2-4}\cmidrule(lr){5-7}" _n
	file write _tbl " & \ensuremath{\pm 60} & \ensuremath{\pm 90} & \ensuremath{\pm 120} & \ensuremath{\pm 60} & \ensuremath{\pm 90} & \ensuremath{\pm 120} \\" _n
	file write _tbl "\midrule" _n
	file write _tbl "\multicolumn{7}{l}{\textit{Panel A: windowed ATT (average post-scandal effect)}}\\" _n
	foreach spec in none ra ipw dr {
		if "`spec'" == "none" local rl "No adjustment"
		if "`spec'" == "ra"   local rl "Regression adj."
		if "`spec'" == "ipw"  local rl "IPW"
		if "`spec'" == "dr"   local rl "Doubly robust"
		local brow "`rl'"
		local srow "            "
		foreach tag in v nv {
		foreach T in 60 90 120 {
			if missing(B_`spec'_`tag'_`T') | S_`spec'_`tag'_`T' <= 0 {
				local brow "`brow' & --"
				local srow "`srow' & "
			}
			else {
				local b = B_`spec'_`tag'_`T'
				local s = S_`spec'_`tag'_`T'
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
	file write _tbl "\multicolumn{7}{l}{\textit{Panel B: pre-trend test, \(p\)-value (joint: all lead coefficients \(=0\))}}\\" _n
	foreach spec in none ra ipw dr {
		if "`spec'" == "none" local rl "No adjustment"
		if "`spec'" == "ra"   local rl "Regression adj."
		if "`spec'" == "ipw"  local rl "IPW"
		if "`spec'" == "dr"   local rl "Doubly robust"
		local prow "`rl'"
		foreach tag in v nv {
		foreach T in 60 90 120 {
			if missing(PP_`spec'_`tag'_`T') {
				local prow "`prow' & --"
			}
			else {
				local pcell = string(PP_`spec'_`tag'_`T', "%4.3f")
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
	display in green "did_ra_main_`sample'.tex written"

	/* clear this sample's stored scalars before the next sample */
	capture scalar drop _all
}

postclose `P'

/* ============================================================
   FIGURES: violent-protest event study, four specs overlaid,
   right-edge 15-day-bin labelling.
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

		replace days = days + `BIN' if etime >= 0

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

		gen double days_p = days
		replace days_p = days - 0.21 * `BIN' if spec == "none"
		replace days_p = days - 0.07 * `BIN' if spec == "ra"
		replace days_p = days + 0.07 * `BIN' if spec == "ipw"
		replace days_p = days + 0.21 * `BIN' if spec == "dr"

		twoway ///
			(rspike lo hi days_p if spec=="none", lcolor(gs9)          lwidth(medthick)) ///
			(scatter b days_p    if spec=="none", mcolor(gs9)          msymbol(O)  msize(medium)) ///
			(rspike lo hi days_p if spec=="ra",   lcolor(navy)         lwidth(medthick)) ///
			(scatter b days_p    if spec=="ra",   mcolor(navy)         msymbol(S)  msize(medium)) ///
			(rspike lo hi days_p if spec=="ipw",  lcolor(cranberry)    lwidth(medthick)) ///
			(scatter b days_p    if spec=="ipw",  mcolor(cranberry)    msymbol(T)  msize(medium)) ///
			(rspike lo hi days_p if spec=="dr",   lcolor(forest_green) lwidth(medthick)) ///
			(scatter b days_p    if spec=="dr",   mcolor(forest_green) msymbol(D)  msize(medium)), ///
			yline(0, lcolor(red) lpattern(solid) lwidth(medthin)) ///
			xline(0, lcolor(black%20) lpattern(solid) lwidth(vthick)) ///
			xtitle("Days since scandal", size(large)) ///
			ytitle("Number of violent protests", size(large)) ///
			ylabel(, labsize(large) format(%4.2fc) angle(0)) ///
			xscale(range(`xlo_ax' `xhi_ax')) ///
			xlabel(`xlabs', labsize(large)) ///
			legend(order(2 "No adj." 4 "Reg. adj." 6 "IPW" 8 "Doubly robust") ///
				rows(1) size(small) position(6) region(lcolor(none))) ///
			graphregion(color(white)) scheme(s2color)
		graph export "${figout}/did_ra_es_mm_violent_`sample'_w`T'.pdf", replace
	restore
}
}

display in green "a_did_ra_ipw_pa_vs_na.do finished OK"
