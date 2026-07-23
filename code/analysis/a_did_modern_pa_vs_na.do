/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-07-13  (rewritten 2026-07-21: event time is now measured in
                       15-DAY BINS over ±60/90/120-day windows, so the modern
                       staggered-DiD event studies are directly comparable to
                       the OLS event studies of \autoref{sup:es_windows} and
                       to the stacked-DiD design.  Previously the panel was
                       weekly with a ±4/+7-week horizon.)

    Objective:
        Four modern staggered-DiD estimators (OLS TWFE, dCDH, BJS, SA) run
        SEPARATELY on the two apex-partition subsamples used in main Table~1:
            - pa : President + Other Apex   scandals
            - na : Other Non-Apex           scandals
        on a country x 15-day-bin panel, for each event-window width
            T in {60, 90, 120} days  ->  nbin = T/15 in {4, 6, 8} bins/side.

        Event-time bins run from -nbin .. (nbin-1); the bin just before
        disclosure (event time -1, i.e. days [-15,0)) is the omitted
        reference, exactly as in the OLS event studies.

    Data:
        - panel_country_day.dta          (country x day outcomes)
        - protests_scandals_30days_v3    (+ scandals_classified.csv) to define
          the subsample-specific first-scandal date per country.

    Outputs (paper/{tables,figures}/):
        - did_modern_es_<outcome>_<sample>_w<T>.pdf   (event study, 4 estimators)
        - did_modern_main_<sample>_w<T>.tex           (static-coefficient table)
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

/* ============================================================
   STEP 0 - subsample-specific first-scandal date per country
   (uses the event-window panel + scandals_classified.csv).
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
	inlist(id, "202", "NEW26", "NEW30", "332", "NEW23")

gen byte in_na = 0
replace in_na = 1 if position == "sc_judge_congressman" & ///
	!inlist(id, "202", "NEW26", "NEW30", "332", "NEW23")
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
   bins (a fixed grid anchored on 1 Jan 2008, so bin indices are
   comparable across countries and subsamples).
   ============================================================ */
use "${datfin}/panel_country_day.dta", clear
keep if year >= 2008

local anchor = mdy(1, 1, 2008)
gen long bin_idx = floor((date - `anchor') / `BIN') + 1

/* Country-year flag for a scandal of ANY type, so the control pool can be
   restricted to scandal-free country-years.  Protest counts are already 0 on
   no-protest days in the balanced country-day panel, so the (sum) collapse
   0-imputes them for control country-dates. */
bysort country year: egen byte cy_scan = max(scandal_today)

collapse (sum) mm_protests mm_violent mm_nonviolent mm_gvr ///
         (firstnm) country_id (max) cy_any_scandal = cy_scan, ///
	by(country bin_idx)

/* start date of each bin (for locating the first-scandal bin) */
gen long bin_start = `anchor' + (bin_idx - 1) * `BIN'
format bin_start %td

tempfile binpanel
save `binpanel'

/* Accumulate every estimator's event-study coefficient so the figures can
   be drawn AFTERWARDS on a common per-outcome y-axis (estimators run once). */
tempname P
tempfile plotdata
postfile `P' str16 outcome str4 sample int T int slot double days ///
	double b_ols  double se_ols  double b_dcdh double se_dcdh ///
	double b_bjs  double se_bjs  double b_sa   double se_sa ///
	using "`plotdata'", replace

/* ============================================================
   SAMPLE x WINDOW LOOP
   ============================================================ */
foreach sample in pa na {

	foreach T in 60 90 120 {

	local nbin = `T' / `BIN'          /* bins per side: 4, 6, 8 */

	di as result _newline _newline ///
		"=================================================================" _n ///
		"   DID MODERN (15-day bins)  --  sample=`sample'  window=+-`T' (`nbin' bins/side)" _n ///
		"================================================================="

	/* ---- attach subsample first-scandal date and its bin ---- */
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

	gen long first_scandal_bin = ///
		floor((first_scandal_date - `anchor') / `BIN') + 1 ///
		if !missing(first_scandal_date)

	gen byte ever_treated = !missing(first_scandal_date)

	/* Clean controls: a never-treated (in-subsample) country enters the
	   control pool only through its country-years with NO scandal of any
	   type; its scandal-contaminated country-years are dropped. Treated
	   countries keep their full trajectory---their own pre-period is the
	   within-country control. */
	drop if ever_treated == 0 & cy_any_scandal == 1

	gen byte D = ever_treated == 1 & bin_idx >= first_scandal_bin
	gen long cohort = first_scandal_bin
	replace cohort = 999999 if missing(cohort)
	gen byte I_never_treated = (ever_treated == 0)

	xtset country_id bin_idx

	/* ---- event-time dummies in 15-day bins ----
	   leads -nbin..-2 (ref -1 omitted), lags 0..nbin-1 */
	gen long etime = bin_idx - first_scandal_bin if ever_treated == 1
	local es_dummies ""
	forvalues k = `nbin'(-1)2 {
		capture drop ev_lead`k'
		gen byte ev_lead`k' = (etime == -`k') & ever_treated == 1
		local es_dummies "`es_dummies' ev_lead`k'"
	}
	forvalues k = 0/`=`nbin'-1' {
		capture drop ev_lag`k'
		gen byte ev_lag`k' = (etime == `k') & ever_treated == 1
		local es_dummies "`es_dummies' ev_lag`k'"
	}

	tempfile wdata
	save `wdata'

	local outcomes mm_violent mm_nonviolent

	/* number of plotted event-time slots: bins -nbin..(nbin-1) */
	local nslot = 2 * `nbin'
	/* slot(bin b) = b + nbin + 1 ; reference b=-1 -> slot nbin stays 0 */

	local oc = 0
	foreach y of local outcomes {
		local ++oc
		use `wdata', clear

		if "`y'" == "mm_protests"   local ytitle "Number of protests"
		if "`y'" == "mm_violent"    local ytitle "Number of violent protests"
		if "`y'" == "mm_nonviolent" local ytitle "Number of non-violent protests"
		if "`y'" == "mm_gvr"        local ytitle "Number of govt. violent responses"

		matrix M_ols_b   = J(1, `nslot', 0)
		matrix M_ols_se  = J(1, `nslot', 0)
		matrix M_dcdh_b  = J(1, `nslot', 0)
		matrix M_dcdh_se = J(1, `nslot', 0)
		matrix M_bjs_b   = J(1, `nslot', 0)
		matrix M_bjs_se  = J(1, `nslot', 0)
		matrix M_sa_b    = J(1, `nslot', 0)
		matrix M_sa_se   = J(1, `nslot', 0)

		/* (1) OLS TWFE */
		di as result "--- OLS: `y' [`sample' w`T'] ---"
		reghdfe `y' D, absorb(country_id bin_idx) cluster(country_id)
		scalar b_ols_`oc'  = _b[D]
		scalar se_ols_`oc' = _se[D]
		scalar n_ols_`oc'  = e(N)
		quietly reghdfe `y' `es_dummies', ///
			absorb(country_id bin_idx) cluster(country_id)
		forvalues k = `nbin'(-1)2 {
			local slot = -`k' + `nbin' + 1
			matrix M_ols_b[1, `slot']  = _b[ev_lead`k']
			matrix M_ols_se[1, `slot'] = _se[ev_lead`k']
		}
		forvalues k = 0/`=`nbin'-1' {
			local slot = `k' + `nbin' + 1
			matrix M_ols_b[1, `slot']  = _b[ev_lag`k']
			matrix M_ols_se[1, `slot'] = _se[ev_lag`k']
		}

		/* (2) dCDH */
		di as result "--- dCDH: `y' [`sample' w`T'] ---"
		capture noisily did_multiplegt_dyn `y' country_id bin_idx D, ///
			effects(`nbin') placebo(`=`nbin'-1') cluster(country_id) graph_off
		if _rc == 0 {
			scalar b_dcdh_`oc'  = e(Av_tot_effect)
			scalar se_dcdh_`oc' = e(se_avg_total_effect)
			forvalues k = 1/`=`nbin'-1' {
				local slot = -(`k'+1) + `nbin' + 1
				capture matrix M_dcdh_b[1, `slot']  = e(Placebo_`k')
				capture matrix M_dcdh_se[1, `slot'] = e(se_placebo_`k')
			}
			forvalues k = 1/`nbin' {
				local slot = (`k'-1) + `nbin' + 1
				capture matrix M_dcdh_b[1, `slot']  = e(Effect_`k')
				capture matrix M_dcdh_se[1, `slot'] = e(se_effect_`k')
			}
		}
		else {
			scalar b_dcdh_`oc' = .
			scalar se_dcdh_`oc' = .
			display in red "dCDH failed for `y' [`sample' w`T']"
		}

		/* (3) BJS */
		di as result "--- BJS: `y' [`sample' w`T'] ---"
		capture noisily did_imputation `y' country_id bin_idx first_scandal_bin, ///
			autosample minn(0) delta(1) cluster(country_id)
		if _rc == 0 {
			scalar b_bjs_`oc'  = _b[tau]
			scalar se_bjs_`oc' = _se[tau]
		}
		else {
			scalar b_bjs_`oc' = .
			scalar se_bjs_`oc' = .
			display in red "BJS (static) failed for `y' [`sample' w`T']"
		}
		capture noisily did_imputation `y' country_id bin_idx first_scandal_bin, ///
			horizons(0/`=`nbin'-1') pretrends(`nbin') ///
			autosample minn(0) delta(1) cluster(country_id)
		if _rc == 0 {
			forvalues k = 2/`nbin' {
				local slot = -`k' + `nbin' + 1
				capture quietly lincom pre`k' - pre1
				if _rc == 0 {
					matrix M_bjs_b[1, `slot']  = r(estimate)
					matrix M_bjs_se[1, `slot'] = r(se)
				}
			}
			forvalues k = 0/`=`nbin'-1' {
				local slot = `k' + `nbin' + 1
				capture quietly lincom tau`k' - pre1
				if _rc == 0 {
					matrix M_bjs_b[1, `slot']  = r(estimate)
					matrix M_bjs_se[1, `slot'] = r(se)
				}
			}
		}

		/* (4) SA */
		di as result "--- SA: `y' [`sample' w`T'] ---"
		capture noisily eventstudyinteract `y' `es_dummies', ///
			cohort(cohort) control_cohort(I_never_treated) ///
			absorb(country_id bin_idx) vce(cluster country_id)
		if _rc == 0 {
			matrix b_iw = e(b_iw)
			matrix V_iw = e(V_iw)
			forvalues k = `nbin'(-1)2 {
				local slot = -`k' + `nbin' + 1
				local j = colnumb(b_iw, "ev_lead`k'")
				if `j' < . {
					matrix M_sa_b[1, `slot']  = b_iw[1, `j']
					matrix M_sa_se[1, `slot'] = sqrt(V_iw[`j', `j'])
				}
			}
			forvalues k = 0/`=`nbin'-1' {
				local slot = `k' + `nbin' + 1
				local j = colnumb(b_iw, "ev_lag`k'")
				if `j' < . {
					matrix M_sa_b[1, `slot']  = b_iw[1, `j']
					matrix M_sa_se[1, `slot'] = sqrt(V_iw[`j', `j'])
				}
			}
			/* static SA = simple average of post-period IW coefficients */
			matrix wgt = J(1, colsof(b_iw), 0)
			local npost = 0
			forvalues k = 0/`=`nbin'-1' {
				local j = colnumb(b_iw, "ev_lag`k'")
				if `j' < . {
					matrix wgt[1, `j'] = 1
					local ++npost
				}
			}
			if `npost' > 0 {
				matrix wgt = wgt / `npost'
				matrix avg_b = wgt * b_iw'
				matrix avg_V = wgt * V_iw * wgt'
				scalar b_sa_`oc'  = avg_b[1,1]
				scalar se_sa_`oc' = sqrt(avg_V[1,1])
			}
		}
		else {
			scalar b_sa_`oc' = .
			scalar se_sa_`oc' = .
			display in red "SA failed for `y' [`sample' w`T']"
		}

		/* ---------- store event-study coefficients (drawn later on a
		   common per-outcome y-scale) ---------- */
		forvalues j = 1/`nslot' {
			local bin = `j' - `nbin' - 1
			post `P' ("`y'") ("`sample'") (`T') (`j') (`bin' * `BIN') ///
				(M_ols_b[1,`j'])  (M_ols_se[1,`j'])  ///
				(M_dcdh_b[1,`j']) (M_dcdh_se[1,`j']) ///
				(M_bjs_b[1,`j'])  (M_bjs_se[1,`j'])  ///
				(M_sa_b[1,`j'])   (M_sa_se[1,`j'])
		}

		/* store the static coefficients keyed by (window, outcome) so the
		   compact per-sample table can be assembled after the window loop */
		foreach er in ols dcdh bjs sa {
			scalar B_`er'_w`T'_`oc' = b_`er'_`oc'
			scalar S_`er'_w`T'_`oc' = se_`er'_`oc'
		}
		scalar N_w`T'_`oc' = n_ols_`oc'
	}

	/* ---------- compact per-sample table, written once after the last
	   window: rows are the four estimators, columns are outcome x window
	   (Violent / Non-violent / Protests, each at +-60/90/120; the
	   government-violent-response outcome is dropped). ---------- */
	if `T' == 120 {
		capture file close _tbl
		file open _tbl using "${tabout}/did_modern_main_`sample'.tex", write replace
		file write _tbl "{" _n
		file write _tbl "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
		file write _tbl "\begin{tabular}{l*{6}{c}}" _n
		file write _tbl "\toprule" _n
		file write _tbl " & \multicolumn{3}{c}{Violent Protests} & \multicolumn{3}{c}{Non-violent Protests} \\" _n
		file write _tbl "\cmidrule(lr){2-4}\cmidrule(lr){5-7}" _n
		file write _tbl " & \ensuremath{\pm 60} & \ensuremath{\pm 90} & \ensuremath{\pm 120} & \ensuremath{\pm 60} & \ensuremath{\pm 90} & \ensuremath{\pm 120} \\" _n
		file write _tbl "\midrule" _n
		foreach er in ols dcdh bjs sa {
			if "`er'" == "ols"  local rowlab "OLS (TWFE)"
			if "`er'" == "dcdh" local rowlab "dCDH"
			if "`er'" == "bjs"  local rowlab "BJS"
			if "`er'" == "sa"   local rowlab "SA"
			local brow "`rowlab'"
			local srow "            "
			foreach oc of numlist 1/2 {
			foreach TT of numlist 60 90 120 {
				local b = B_`er'_w`TT'_`oc'
				local s = S_`er'_w`TT'_`oc'
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
		local nrow "Observations"
		foreach oc of numlist 1/2 {
		foreach TT of numlist 60 90 120 {
			local ncell = trim(string(N_w`TT'_`oc', "%12.0fc"))
			local nrow "`nrow' & `ncell'"
		}
		}
		file write _tbl "`nrow' \\" _n
		file write _tbl "\bottomrule" _n
		file write _tbl "\end{tabular}" _n
		file write _tbl "}" _n
		file close _tbl
		display in green "did_modern_main_`sample'.tex written"
	}

	}
}

postclose `P'

/* ============================================================
   COMMON-SCALE PLOTTING
   For each outcome, use ONE y-axis range across all (sample,
   window) figures so the estimates can be compared by eye; axis
   labels are enlarged relative to the previous version.
   ============================================================ */
use "`plotdata'", clear
gen double lo_ols  = b_ols  - 1.645 * se_ols
gen double hi_ols  = b_ols  + 1.645 * se_ols
gen double lo_dcdh = b_dcdh - 1.645 * se_dcdh
gen double hi_dcdh = b_dcdh + 1.645 * se_dcdh
gen double lo_bjs  = b_bjs  - 1.645 * se_bjs
gen double hi_bjs  = b_bjs  + 1.645 * se_bjs
gen double lo_sa   = b_sa   - 1.645 * se_sa
gen double hi_sa   = b_sa   + 1.645 * se_sa
egen double lo_all = rowmin(lo_ols lo_dcdh lo_bjs lo_sa)
egen double hi_all = rowmax(hi_ols hi_dcdh hi_bjs hi_sa)
tempfile allcoef
save `allcoef'

foreach y in mm_violent mm_nonviolent {

	if "`y'" == "mm_protests"   local ytitle "Number of protests"
	if "`y'" == "mm_violent"    local ytitle "Number of violent protests"
	if "`y'" == "mm_nonviolent" local ytitle "Number of non-violent protests"
	if "`y'" == "mm_gvr"        local ytitle "Number of govt. violent responses"

	/* common padded, rounded y-range across all (sample,window) figures */
	use `allcoef', clear
	quietly summarize lo_all if outcome == "`y'"
	local ymin = min(r(min), 0)
	quietly summarize hi_all if outcome == "`y'"
	local ymax = max(r(max), 0)
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

	foreach sample in pa na {
	foreach T in 60 90 120 {

		local nbin = `T' / `BIN'

		use `allcoef', clear
		keep if outcome == "`y'" & sample == "`sample'" & T == `T'
		sort slot

		replace days = days + `BIN' if days >= 0   /* POST bins -> right edge; PRE keep left edge */
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

		/* small horizontal offsets (in days) so the 4 estimators don't overlap */
		gen double days_ols  = days - 0.18 * `BIN'
		gen double days_dcdh = days - 0.06 * `BIN'
		gen double days_bjs  = days + 0.06 * `BIN'
		gen double days_sa   = days + 0.18 * `BIN'

		twoway ///
			(rspike lo_ols  hi_ols  days_ols,  lcolor(navy)         lwidth(medthick)) ///
			(scatter b_ols  days_ols,  mcolor(navy)         msymbol(O)  msize(medium)) ///
			(rspike lo_dcdh hi_dcdh days_dcdh, lcolor(cranberry)    lwidth(medthick)) ///
			(scatter b_dcdh days_dcdh, mcolor(cranberry)    msymbol(T)  msize(medium)) ///
			(rspike lo_bjs  hi_bjs  days_bjs,  lcolor(forest_green) lwidth(medthick)) ///
			(scatter b_bjs  days_bjs,  mcolor(forest_green) msymbol(D)  msize(medium)) ///
			(rspike lo_sa   hi_sa   days_sa,   lcolor(midblue)      lwidth(medthick)) ///
			(scatter b_sa   days_sa,   mcolor(midblue)      msymbol(Oh) msize(medium)), ///
			yline(0, lcolor(red) lpattern(solid) lwidth(medthin)) ///
			xline(0, lcolor(black%20) lpattern(solid) lwidth(vthick)) ///
			xtitle("Days since first scandal", size(large)) ///
			ytitle("`ytitle'", size(large)) ///
			yscale(range(`ylo_t' `yhi_t')) ///
			ylabel(`ylo_t'(`step')`yhi_t', labsize(large) format(%4.2fc) angle(0)) ///
			xscale(range(`xlo_ax' `xhi_ax')) ///
			xlabel(`xlabs', labsize(large)) ///
			legend(order(2 "OLS (TWFE)" 4 "dCDH" 6 "BJS" 8 "SA") ///
				rows(1) size(medium) position(6) region(lcolor(none))) ///
			graphregion(color(white)) scheme(s2color)
		graph export "${figout}/did_modern_es_`y'_`sample'_w`T'.pdf", replace
	}
	}
}

display in green "a_did_modern_pa_vs_na.do finished OK"
