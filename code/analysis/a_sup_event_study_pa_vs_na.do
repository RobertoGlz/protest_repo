/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper - SUPPLEMENTARY MATERIALS

   Code author: Roberto Gonzalez
   Date: 2026-07-13

   Objective:
     Event-study figures (30-day bins, +-120-day window) run SEPARATELY
     on the two apex-partition subsamples of the main Table~1:
        - pa : President + Other Apex
        - na : Other Non-Apex

     For each subsample x outcome we produce BOTH:
        - OLS       (reghdfe): main-body result -- reuses the exact
                    specification of ols_main.do (which is the file
                    that produced the paper's Figure~1 file
                    es_<outcome>_120d_overlaps_90ci.pdf -> renamed to
                    es_<outcome>_120d_90ci.png in the paper).
        - Poisson QML (ppmlhdfe, IRR): appendix result -- reuses the
                    exact specification of ppmlhdfe_reg_main_
                    countryxyear_fe.do, with coefplot eform(${leads}
                    ${lags}) so the IRR CIs are asymmetric (obtained
                    by exponentiating the CI bounds on the log scale).

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta
     - ${datfin}/scandals_classified.csv

   Outputs (paper/figures/):
     - es_<outcome>_120d_<sample>_ols_90ci.pdf   (OLS)
     - es_<outcome>_120d_<sample>_poi_90ci.pdf   (Poisson IRR)
     where <sample> in {pa, na}.
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

/* --------------- Bin dummies exactly like ols_main.do --------------- */
local firstyear   = 2008
local ci_level    = 90
local window_length = 120
local bin_width     = 30

global leads ""
forvalues i = `window_length'(-`bin_width')`bin_width' {
	global leads "${leads} s_lead`i'"
}
global lags ""
forvalues i = `bin_width'(`bin_width')`window_length' {
	global lags "${lags} s_lag`i'"
}

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

/* Groups and cluster identifier used by ols_main.do */
egen grupo_dias    = group(${lags} ${leads})
egen group_cluster = group(country_id year grupo_dias)
egen auxvar        = group(country year)   /* country x year FE */

global CY_fe "i.country_id#i.year"

tempfile base
save `base'

/* ============================================================
   LOOP OVER (SAMPLE, OUTCOME)
   ============================================================ */
foreach sample in pa na {
foreach outcome in num_violent_MM num_peaceful_MM {

	/* ---------- OLS (ols_main.do format) ---------- */
	use `base', clear

	/* average (static) OLS effect for the legend text */
	quietly reghdfe `outcome' post ///
		if in_`sample' == 1, ///
		absorb(month day auxvar) vce(cluster group_cluster)
	local av_est   = string(_b[post], "%4.3fc")
	local p_av_est = 2 * normal(-abs(_b[post] / _se[post]))
	if `p_av_est' < 0.01 {
		local p_string = "p < 0.01"
	}
	else {
		local p_string = "p = " + string(`p_av_est', "%4.3fc")
	}

	/* event-study OLS */
	eststo mols : reghdfe `outcome' ${leads} ${lags} ///
		if in_`sample' == 1, ///
		absorb(month day auxvar) cluster(group_cluster)

	coefplot, keep(${leads} ${lags}) levels(`ci_level') ///
		baselevels omitted vertical ///
		ytitle("average effect", size(medium)) yscale(titlegap(2)) ///
		xtitle("days around scandal", size(medium)) xscale(titlegap(2)) ///
		xline(4.5, lcolor(black%10) lwidth(vvthick)) ///
		yline(0, lpattern(dash) lcolor(black)) ///
		ylabel(, labsize(medlarge) format(%3.2fc)) ///
		xlabel(, labsize(medlarge)) ///
		graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ///
		    ifcolor(white) ilcolor(white) ilwidth(vvvthin)) ///
		ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain) ///
		legend(off)
	graph export ///
		"${figout}/es_`outcome'_`window_length'd_`sample'_ols_`ci_level'ci.pdf", ///
		replace

	/* ---------- Poisson QML (ppmlhdfe_reg_main_countryxyear_fe.do format) ---------- */
	use `base', clear

	/* average (static) Poisson IRR for the legend text */
	capture noisily ppmlhdfe `outcome' post ///
		if year >= `firstyear' & in_`sample' == 1, ///
		absorb(month day ${CY_fe}) vce(cluster group_cluster) irr
	if _rc == 0 {
		local av_est   = string(exp(_b[post]), "%3.2fc")
		local p_av_est = 2 * normal(-abs(_b[post] / _se[post]))
		if `p_av_est' < 0.01 {
			local p_string = "p < 0.01"
		}
		else {
			local p_string = "p = " + string(`p_av_est', "%4.3fc")
		}

		/* event-study Poisson (quietly to avoid the r(table)-dependent
		   y_eff_pos block that ppmlhdfe_reg_main_countryxyear_fe.do
		   uses; we don't need it here). */
		quietly ppmlhdfe `outcome' ${leads} ${lags} ///
			if year >= `firstyear' & in_`sample' == 1, ///
			absorb(month day ${CY_fe}) vce(cluster group_cluster) irr

		coefplot, keep(${leads} ${lags}) eform(${leads} ${lags}) ///
			levels(`ci_level') baselevels omitted vertical ///
			xtitle("days since scandal", size(medium)) xscale(titlegap(2)) ///
			xline(4.5, lwidth(vthick) lpattern(solid) lcolor(black%10)) ///
			ytitle("incidence rate ratio", size(medium)) yscale(titlegap(2)) ///
			yline(1, lwidth(medthin) lpattern(shortdash) lcolor(black)) ///
			xlabel(, labsize(medium)) ///
			ylabel(#5, nogrid format(%3.1fc) labsize(medium)) ///
			ciopts(lcolor(black) lwidth(medthin)) mcolor(black) msize(medium) ///
			legend(off)
		graph export ///
			"${figout}/es_`outcome'_`window_length'd_`sample'_poi_`ci_level'ci.pdf", ///
			replace
	}
	else {
		display in red "SKIP: Poisson `outcome' [`sample'] failed (rc=`=_rc')"
	}
}
}

display in green "a_sup_event_study_pa_vs_na.do finished OK"
