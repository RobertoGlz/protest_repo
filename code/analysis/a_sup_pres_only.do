/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper - SUPPLEMENTARY MATERIALS

   Code author: Roberto Gonzalez
   Date: 2026-07-02

   Objective:
     Version of Table 1 (main text) restricted to scandals where the
     implicated official is a sitting PRESIDENT.

     Classification (v2 partition; see also
     per_scandal_effects_apex_v2.do):
        President  <=> scandals_classified.csv position == "president"

     Specification identical to a_reg_violent_peaceful_panels.do.

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta
     - ${datfin}/scandals_classified.csv
     - ${progdir}/define_panelcombine.do

   Outputs (under ${work}/results/tables/):
     - sup_pres_only_ols_temp.tex, sup_pres_only_poi_temp.tex  (intermediate)
     - sup_pres_only_table.tex                                 (final)
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
global tables  "${identity}/Corrupcion/protest_repo/paper/tables"
global progdir "${identity}/Corrupcion/protest_repo/code/programs"

do "${progdir}/define_panelcombine.do"

/* --------------- Build the position lookup --------------- */
import delimited using "${datfin}/scandals_classified.csv", ///
	clear varnames(1) bindquotes(strict)
keep id country position
tempfile cls
save `cls'

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"

merge m:1 id country using `cls', keep(1 3) generate(_mclass)

/* --------------- KEEP ONLY PRESIDENT SCANDALS --------------- */
keep if position == "president"

/* --------------- Share outcomes --------------- */
gen double share_violent  = num_violent_MM  / num_protests_MM if num_protests_MM > 0
gen double share_peaceful = num_peaceful_MM / num_protests_MM if num_protests_MM > 0
replace    share_violent  = 0 if num_protests_MM == 0
replace    share_peaceful = 0 if num_protests_MM == 0

egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"

local firstyear = 2008
local ols_out   "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM share_violent share_peaceful share_violent share_peaceful"
local ols_win   "30 30 120 120 30 30 120 120"
local ols_n : word count `ols_out'
local poi_out   "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM"
local poi_win   "30 30 120 120"
local poi_n : word count `poi_out'

/* ============================================================
   PANEL A: OLS on all 8 outcomes
   ============================================================ */
eststo clear
forvalues k = 1/`ols_n' {
	local outcome : word `k' of `ols_out'
	local window  : word `k' of `ols_win'
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

esttab _all using "${tables}/sup_pres_only_ols_temp.tex", ///
	replace booktabs nonotes nogaps b(3) se(3) ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	mtitles("\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}" ///
	        "\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}" ///
	        "\shortstack{Share\\Violent}" ///
	        "\shortstack{Share\\Peaceful}" ///
	        "\shortstack{Share\\Violent}" ///
	        "\shortstack{Share\\Peaceful}") ///
	mgroups("$\pm 30$-Day Window" "$\pm 120$-Day Window" "Shares ($\pm 30$-Day)" "Shares ($\pm 120$-Day)", ///
	        pattern(1 0 1 0 1 0 1 0) ///
	        prefix(\multicolumn{2}{c}{) suffix(}) span ///
	        erepeat(\cmidrule(lr){@span})) ///
	stats(baseline N num_scandals r2, ///
	      label("Mean (Pre-Scandal Bin)" ///
	            "Observations" ///
	            "Number of Scandals" ///
	            "R-squared") ///
	      fmt(3 0 0 3)) ///
	keep(post) coeflabels(post "Post Scandal")

/* Poisson panel removed per author request: the President table is now
   OLS-only.  Use the OLS esttab output directly as the final table.       */
copy "${tables}/sup_pres_only_ols_temp.tex" ///
     "${tables}/sup_pres_only_table.tex", replace
capture erase "${tables}/sup_pres_only_ols_temp.tex"

display in green "a_sup_pres_only.do finished OK (OLS only)"
