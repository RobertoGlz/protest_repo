/* ----------------------------------------------------------------------------
   Project: Apex corruption protests paper

   Code author: Roberto Gonzalez
   Date: 2026-07-13

   Objective:
        Two-panel OLS table for the main text (Table 1):
          Panel A: scandals implicating a sitting President OR an Other
                    Apex official (Governors + SC Justices) -- 64 scandals.
          Panel B: scandals implicating an Other Non-Apex official
                    (Congressmen, lower judiciary, other officials) --
                    112 scandals.

        Eight columns per panel (same layout as pre-split Table 1):
            (1) Violent count,   +-30-day window
            (2) Peaceful count,  +-30-day window
            (3) Violent count,   +-120-day window
            (4) Peaceful count,  +-120-day window
            (5) Share Violent,   +-30-day window
            (6) Share Peaceful,  +-30-day window
            (7) Share Violent,   +-120-day window
            (8) Share Peaceful,  +-120-day window

        Same specification as \autoref{eq:main} (country-by-year,
        day-of-week, and month-of-year fixed effects; standard errors
        clustered at country x year x day-bin).

        The analogous Poisson QML (IRR) two-panel table for the appendix
        lives in a_reg_violent_peaceful_panels_poisson.do.

   Inputs:
        - ${datfin}/protests_scandals_30days_v3.dta
        - ${datfin}/scandals_classified.csv
        - ${progdir}/define_panelcombine.do

   Outputs (under paper/tables/):
        - violent_peaceful_ols_pa_temp.tex   (intermediate; deleted via cleanup)
        - violent_peaceful_ols_na_temp.tex   (intermediate; deleted via cleanup)
        - violent_peaceful_ols_panels.tex    (final combined two-panel table)
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

/* Apex partition v2 flags */
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

/* Share outcomes (0 imputed on no-protest days) */
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

tempfile base
save `base'

/* ============================================================
   PANEL A: President + Other Apex (in_pa == 1)
   ============================================================ */
eststo clear
forvalues k = 1/`ols_n' {
	local outcome : word `k' of `ols_out'
	local window  : word `k' of `ols_win'
	local bin_size = cond(`window' == 30, 6, 30)

	use `base', clear
	if `window' == 30 {
		eststo m`k': reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear' & abs(window) <= 30 & in_pa == 1, ///
			absorb($fe1) vce($CLUSTER2)
	}
	else {
		eststo m`k': reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear' & in_pa == 1, ///
			absorb($fe1) vce($CLUSTER2)
	}

	quietly summarize `outcome' if e(sample) ///
		& window >= -`bin_size' & window <= -1
	estadd scalar baseline = r(mean)

	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)
}

esttab _all using "${tables}/violent_peaceful_ols_pa_temp.tex", ///
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
	mgroups("$\pm 30$-Day Window" "$\pm 120$-Day Window" ///
	        "Shares ($\pm 30$-Day)" "Shares ($\pm 120$-Day)", ///
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
   PANEL B: Other Non-Apex (in_na == 1)
   ============================================================ */
eststo clear
forvalues k = 1/`ols_n' {
	local outcome : word `k' of `ols_out'
	local window  : word `k' of `ols_win'
	local bin_size = cond(`window' == 30, 6, 30)

	use `base', clear
	if `window' == 30 {
		eststo m`k': reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear' & abs(window) <= 30 & in_na == 1, ///
			absorb($fe1) vce($CLUSTER2)
	}
	else {
		eststo m`k': reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear' & in_na == 1, ///
			absorb($fe1) vce($CLUSTER2)
	}

	quietly summarize `outcome' if e(sample) ///
		& window >= -`bin_size' & window <= -1
	estadd scalar baseline = r(mean)

	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)
}

esttab _all using "${tables}/violent_peaceful_ols_na_temp.tex", ///
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
	mgroups("$\pm 30$-Day Window" "$\pm 120$-Day Window" ///
	        "Shares ($\pm 30$-Day)" "Shares ($\pm 120$-Day)", ///
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
   COMBINE PANELS + append Country x Year FE checkmark row
   (clustering level lives in the caption)
   ============================================================ */
panelcombine, ///
	use("${tables}/violent_peaceful_ols_pa_temp.tex" ///
	    "${tables}/violent_peaceful_ols_na_temp.tex") ///
	paneltitles("President + Other Apex" "Other Non-Apex") ///
	columncount(9) ///
	save("${tables}/violent_peaceful_ols_panels.tex") ///
	cleanup

local d  = char(36)
local fe_row  = "Country `d'\times`d' Year FE&  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         \\"

tempfile patched
tempname fin fout
file open `fin'  using "${tables}/violent_peaceful_ols_panels.tex", read  text
file open `fout' using "`patched'",                                  write text replace

file read `fin' line
while r(eof) == 0 {
	if `"`macval(line)'"' == "\bottomrule" {
		file write `fout' "\midrule"   _n
		file write `fout' "`fe_row'"   _n
	}
	file write `fout' `"`macval(line)'"' _n
	file read `fin' line
}
file close `fin'
file close `fout'

capture erase "${tables}/violent_peaceful_ols_panels.tex"
copy "`patched'" "${tables}/violent_peaceful_ols_panels.tex", replace

display in green "a_reg_violent_peaceful_panels.do finished OK"
