/* ----------------------------------------------------------------------------
   Project: Apex corruption protests paper

   Code author: Roberto Gonzalez
   Date: 2026-06-27

   Objective:
        Combined table with two panels (Panel A: OLS, Panel B: Poisson QML)
        and four columns:
            (1) Violent protests, +-30-day window
            (2) Peaceful protests, +-30-day window
            (3) Violent protests, +-120-day window
            (4) Peaceful protests, +-120-day window
        Same specification as \autoref{eq:main} (country-by-year, day-of-week,
        and month-of-year fixed effects; standard errors clustered at
        country x year x day-bin).  Reports the Pre-Scandal Bin Mean as a
        reporting statistic; Country x Year FE and SE Cluster rows appear
        only once, at the very bottom of the combined table.

   Inputs:
        - ${datfin}/protests_scandals_30days_v3.dta
        - ${progdir}/define_panelcombine.do

   Outputs (under ${work}/results/tables/):
        - violent_peaceful_ols_temp.tex      (intermediate; deleted via cleanup)
        - violent_peaceful_poi_temp.tex      (intermediate; deleted via cleanup)
        - violent_peaceful_ols_poi_panels.tex  (final combined two-panel table)
---------------------------------------------------------------------------- */

set more off
clear all

/* ----------------------- User-specific paths ----------------------- */
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
global tables  "${work}/results/tables"
global progdir "${identity}/Corrupcion/protest_repo/code/programs"

/* --------------- Load the panelcombine program --------------- */
do "${progdir}/define_panelcombine.do"

/* --------------- Read the event-window panel --------------- */
use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"

egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"

local firstyear = 2008

/* Order of columns: violent 30d, peaceful 30d, violent 120d, peaceful 120d */
local outcomes "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM"
local windows  "30 30 120 120"
local nspecs : word count `outcomes'

/* ============================================================
   PANEL A: OLS via reghdfe
   ============================================================ */
eststo clear
forvalues k = 1/`nspecs' {
	local outcome : word `k' of `outcomes'
	local window  : word `k' of `windows'
	local bin_size = cond(`window' == 30, 6, 30)

	if `window' == 30 {
		eststo m`k': reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear' & abs(window) <= 30, ///
			absorb($fe1) vce($CLUSTER2)
	}
	else {
		eststo m`k': reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear', ///
			absorb($fe1) vce($CLUSTER2)
	}

	quietly summarize `outcome' if e(sample) ///
		& window >= -`bin_size' & window <= -1
	estadd scalar baseline = r(mean)

	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)
}

esttab _all using "${tables}/violent_peaceful_ols_temp.tex", ///
	replace booktabs nonotes nogaps b(3) se(3) ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	mtitles("\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}" ///
	        "\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}") ///
	mgroups("$\pm 30$-Day Window" "$\pm 120$-Day Window", ///
	        pattern(1 0 1 0) ///
	        prefix(\multicolumn{2}{c}{) suffix(}) span ///
	        erepeat(\cmidrule(lr){@span})) ///
	stats(baseline N num_scandals r2, ///
	      label("Mean (Pre-Scandal Bin)" ///
	            "Observations" ///
	            "Number of Scandals" ///
	            "R-squared") ///
	      fmt(3 0 0 3)) ///
	keep(post) coeflabels(post "Post Scandal")

/* ============================================================
   PANEL B: Poisson QML via ppmlhdfe
   ============================================================ */
eststo clear
forvalues k = 1/`nspecs' {
	local outcome : word `k' of `outcomes'
	local window  : word `k' of `windows'
	local bin_size = cond(`window' == 30, 6, 30)

	/* For ppmlhdfe we absorb month and day rather than including
	   them as i.month i.day covariates, matching the existing
	   convention in a_poissreg_allscandals.do (avoids the separation
	   pre-solver tripping over high-cardinality dummy controls). */
	if `window' == 30 {
		eststo m`k': ppmlhdfe `outcome' post ///
			if year >= `firstyear' & abs(window) <= 30, ///
			absorb(month day $fe1) vce($CLUSTER2)
	}
	else {
		eststo m`k': ppmlhdfe `outcome' post ///
			if year >= `firstyear', ///
			absorb(month day $fe1) vce($CLUSTER2)
	}

	quietly summarize `outcome' if e(sample) ///
		& window >= -`bin_size' & window <= -1
	estadd scalar baseline = r(mean)

	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)

	/* Implied proportional effect with delta-method SE and stars.
	   For a Poisson regression with log link, exp(beta) is the
	   incidence-rate ratio, exp(beta) - 1 is the implied proportional
	   change, and the delta-method SE of the transformed coefficient
	   is exp(beta) * SE(beta).
	   We compute the 2-sided p-value from the delta-method
	   z-statistic imp_b / imp_se and attach the standard 3-tier
	   significance stars (1%/5%/10%) using string() concatenation,
	   so the displayed row carries its own stars instead of inheriting
	   the log-coefficient's stars. */
	local imp_b   = exp(_b[post]) - 1
	local imp_se  = exp(_b[post]) * _se[post]
	local imp_z   = `imp_b' / `imp_se'
	local imp_p   = 2 * (1 - normal(abs(`imp_z')))
	local stars   = cond(`imp_p' < 0.01, "\sym{***}", ///
	                cond(`imp_p' < 0.05, "\sym{**}", ///
	                cond(`imp_p' < 0.10, "\sym{*}", "")))
	local imp_b_str  = string(`imp_b',  "%5.3f") + "`stars'"
	local imp_se_str = "(" + string(`imp_se', "%5.3f") + ")"
	estadd local imp_eff_lbl = "`imp_b_str'"
	estadd local imp_se_lbl  = "`imp_se_str'"
}

esttab _all using "${tables}/violent_peaceful_poi_temp.tex", ///
	replace booktabs nonotes nogaps b(3) se(3) ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	mtitles("\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}" ///
	        "\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}") ///
	mgroups("$\pm 30$-Day Window" "$\pm 120$-Day Window", ///
	        pattern(1 0 1 0) ///
	        prefix(\multicolumn{2}{c}{) suffix(}) span ///
	        erepeat(\cmidrule(lr){@span})) ///
	stats(imp_eff_lbl imp_se_lbl baseline N num_scandals r2_p, ///
	      label("Implied Prop. Effect" ///
	            " " ///
	            "Mean (Pre-Scandal Bin)" ///
	            "Observations" ///
	            "Number of Scandals" ///
	            "Pseudo R-squared") ///
	      fmt(%s %s 3 0 0 3)) ///
	keep(post) coeflabels(post "Post Scandal")

/* ============================================================
   COMBINE PANELS
   ============================================================ */
panelcombine, ///
	use("${tables}/violent_peaceful_ols_temp.tex" ///
	    "${tables}/violent_peaceful_poi_temp.tex") ///
	paneltitles("OLS" "Poisson QML") ///
	columncount(5) ///
	save("${tables}/violent_peaceful_ols_poi_panels.tex") ///
	cleanup

/* --------------- Append global FE / Cluster rows at the bottom --------- */
local d  = char(36)
local fe_row  = "Country `d'\times`d' Year FE&  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         \\"
local se_row  = "SE Cluster  &C `d'\times`d' Y `d'\times`d' DB         &C `d'\times`d' Y `d'\times`d' DB         &C `d'\times`d' Y `d'\times`d' DB         &C `d'\times`d' Y `d'\times`d' DB         \\"

tempfile patched
tempname fin fout
file open `fin'  using "${tables}/violent_peaceful_ols_poi_panels.tex", read  text
file open `fout' using "`patched'",                                      write text replace

file read `fin' line
while r(eof) == 0 {
	if `"`macval(line)'"' == "\bottomrule" {
		file write `fout' "\midrule"   _n
		file write `fout' "`fe_row'"   _n
		file write `fout' "`se_row'"   _n
	}
	file write `fout' `"`macval(line)'"' _n
	file read `fin' line
}
file close `fin'
file close `fout'

copy "`patched'" "${tables}/violent_peaceful_ols_poi_panels.tex", replace

display in green "a_reg_violent_peaceful_panels.do finished OK"
