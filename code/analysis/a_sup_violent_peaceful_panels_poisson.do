/* ----------------------------------------------------------------------------
   Project: Apex corruption protests paper - SUPPLEMENTARY MATERIALS

   Code author: Roberto Gonzalez
   Date: 2026-07-13

   Objective:
        Appendix (Poisson QML IRR) counterpart to the main-text OLS
        two-panel Table 1 (a_reg_violent_peaceful_panels.do):
          Panel A: President + Other Apex   -- 64 scandals.
          Panel B: Other Non-Apex           -- 112 scandals.

        Same 8-column layout as main Table 1: violent/peaceful counts
        for +-30 and +-120 windows, plus violent/peaceful shares for
        each window.  Poisson is estimated only on the four count
        outcomes (cols. 1-4); the share columns (5-8) are left blank
        because IRR has no meaning for a share in [0,1].

   Inputs:
        - ${datfin}/protests_scandals_30days_v3.dta
        - ${datfin}/scandals_classified.csv
        - ${progdir}/define_panelcombine.do

   Outputs (under paper/tables/):
        - violent_peaceful_poi_pa_temp.tex   (intermediate)
        - violent_peaceful_poi_na_temp.tex   (intermediate)
        - sup_violent_peaceful_poi_panels.tex (final combined table)
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

egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"

local firstyear = 2008
local poi_out   "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM"
local poi_win   "30 30 120 120"
local poi_n : word count `poi_out'

tempfile base
save `base'

/* ============================================================
   Helper: run Poisson panel + write padded tempfile
   Padding turns 4 data cols into 8 so panelcombine aligns with
   the OLS 8-column layout.
   ============================================================ */

/* --------------- Panel A: Pres + Other Apex --------------- */
eststo clear
forvalues k = 1/`poi_n' {
	local outcome : word `k' of `poi_out'
	local window  : word `k' of `poi_win'
	local bin_size = cond(`window' == 30, 6, 30)

	use `base', clear
	if `window' == 30 {
		capture eststo m`k': ppmlhdfe `outcome' post ///
			if year >= `firstyear' & abs(window) <= 30 & in_pa == 1, ///
			absorb(month day $fe1) vce($CLUSTER2)
	}
	else {
		capture eststo m`k': ppmlhdfe `outcome' post ///
			if year >= `firstyear' & in_pa == 1, ///
			absorb(month day $fe1) vce($CLUSTER2)
	}
	quietly summarize `outcome' if e(sample) ///
		& window >= -`bin_size' & window <= -1
	estadd scalar baseline = r(mean)
	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)
}

esttab _all using "${tables}/violent_peaceful_poi_pa_temp.tex", ///
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

/* Pad Panel A to 8 data cells */
tempfile pa_padded
tempname pinA poutA
file open `pinA'  using "${tables}/violent_peaceful_poi_pa_temp.tex", read  text
file open `poutA' using "`pa_padded'",                                 write text replace
file read `pinA' line
while r(eof) == 0 {
	if strpos(`"`macval(line)'"', "\\") > 0 {
		local newline = subinstr(`"`macval(line)'"', "\\", " & & & & \\", 1)
		file write `poutA' `"`macval(newline)'"' _n
	}
	else {
		file write `poutA' `"`macval(line)'"' _n
	}
	file read `pinA' line
}
file close `pinA'
file close `poutA'
capture erase "${tables}/violent_peaceful_poi_pa_temp.tex"

/* --------------- Panel B: Other Non-Apex --------------- */
eststo clear
forvalues k = 1/`poi_n' {
	local outcome : word `k' of `poi_out'
	local window  : word `k' of `poi_win'
	local bin_size = cond(`window' == 30, 6, 30)

	use `base', clear
	if `window' == 30 {
		capture eststo m`k': ppmlhdfe `outcome' post ///
			if year >= `firstyear' & abs(window) <= 30 & in_na == 1, ///
			absorb(month day $fe1) vce($CLUSTER2)
	}
	else {
		capture eststo m`k': ppmlhdfe `outcome' post ///
			if year >= `firstyear' & in_na == 1, ///
			absorb(month day $fe1) vce($CLUSTER2)
	}
	quietly summarize `outcome' if e(sample) ///
		& window >= -`bin_size' & window <= -1
	estadd scalar baseline = r(mean)
	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)
}

esttab _all using "${tables}/violent_peaceful_poi_na_temp.tex", ///
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

/* Pad Panel B to 8 data cells */
tempfile na_padded
tempname pinB poutB
file open `pinB'  using "${tables}/violent_peaceful_poi_na_temp.tex", read  text
file open `poutB' using "`na_padded'",                                 write text replace
file read `pinB' line
while r(eof) == 0 {
	if strpos(`"`macval(line)'"', "\\") > 0 {
		local newline = subinstr(`"`macval(line)'"', "\\", " & & & & \\", 1)
		file write `poutB' `"`macval(newline)'"' _n
	}
	else {
		file write `poutB' `"`macval(line)'"' _n
	}
	file read `pinB' line
}
file close `pinB'
file close `poutB'
capture erase "${tables}/violent_peaceful_poi_na_temp.tex"

/* ============================================================
   COMBINE the two padded Poisson panels
   ============================================================ */
panelcombine, ///
	use("`pa_padded'" "`na_padded'") ///
	paneltitles("President + Other Apex" "Other Non-Apex") ///
	columncount(9) ///
	save("${tables}/sup_violent_peaceful_poi_panels.tex") ///
	cleanup

display in green "a_sup_violent_peaceful_panels_poisson.do finished OK"
