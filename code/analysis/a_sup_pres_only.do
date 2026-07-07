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
global tables  "${work}/results/tables"
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

/* ============================================================
   PANEL B: Poisson QML (IRR) on the 4 count outcomes only
   ============================================================ */
eststo clear
forvalues k = 1/`poi_n' {
	local outcome : word `k' of `poi_out'
	local window  : word `k' of `poi_win'
	local bin_size = cond(`window' == 30, 6, 30)

	if `window' == 30 {
		capture eststo m`k': ppmlhdfe `outcome' post ///
			if year >= `firstyear' & abs(window) <= 30, ///
			absorb(month day $fe1) vce($CLUSTER2)
	}
	else {
		capture eststo m`k': ppmlhdfe `outcome' post ///
			if year >= `firstyear', ///
			absorb(month day $fe1) vce($CLUSTER2)
	}

	quietly summarize `outcome' if e(sample) ///
		& window >= -`bin_size' & window <= -1
	estadd scalar baseline = r(mean)

	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)
}

esttab _all using "${tables}/sup_pres_only_poi_temp.tex", ///
	replace booktabs nonotes nogaps b(3) se(3) eform ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	mtitles("\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}" ///
	        "\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}") ///
	mgroups("$\pm 30$-Day Window" "$\pm 120$-Day Window", ///
	        pattern(1 0 1 0) ///
	        prefix(\multicolumn{2}{c}{) suffix(}) span ///
	        erepeat(\cmidrule(lr){@span})) ///
	stats(baseline N num_scandals r2_p, ///
	      label("Mean (Pre-Scandal Bin)" ///
	            "Observations" ///
	            "Number of Scandals" ///
	            "Pseudo R-squared") ///
	      fmt(3 0 0 3)) ///
	keep(post) coeflabels(post "Post Scandal (IRR)")

/* --- Pad Poisson tex so each data row has 8 data cells ---
   Padded content goes to an OS-temp file (not in Dropbox) to avoid
   r(608) if the target file is briefly locked.                      */
tempfile poi_padded
tempname pin pout
file open `pin'  using "${tables}/sup_pres_only_poi_temp.tex", read  text
file open `pout' using "`poi_padded'",                          write text replace
file read `pin' line
while r(eof) == 0 {
	if strpos(`"`macval(line)'"', "\\") > 0 {
		local newline = subinstr(`"`macval(line)'"', "\\", " & & & & \\", 1)
		file write `pout' `"`macval(newline)'"' _n
	}
	else {
		file write `pout' `"`macval(line)'"' _n
	}
	file read `pin' line
}
file close `pin'
file close `pout'
capture erase "${tables}/sup_pres_only_poi_temp.tex"

panelcombine, ///
	use("${tables}/sup_pres_only_ols_temp.tex" ///
	    "`poi_padded'") ///
	paneltitles("OLS" "Poisson QML") ///
	columncount(9) ///
	save("${tables}/sup_pres_only_table.tex") ///
	cleanup

display in green "a_sup_pres_only.do finished OK"
