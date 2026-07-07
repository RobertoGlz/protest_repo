/* ----------------------------------------------------------------------------
   Project: Apex corruption protests paper

   Code author: Roberto Gonzalez
   Date: 2026-07-07

   Objective:
        Combined table with two panels (Panel A: OLS, Panel B: Poisson QML
        IRR) and eight columns:
            (1) Violent protests,   +-30-day window   [count]
            (2) Peaceful protests,  +-30-day window   [count]
            (3) Violent protests,   +-120-day window  [count]
            (4) Peaceful protests,  +-120-day window  [count]
            (5) Share Violent,      +-30-day window
            (6) Share Peaceful,     +-30-day window
            (7) Share Violent,      +-120-day window
            (8) Share Peaceful,     +-120-day window
        Same specification as \autoref{eq:main} (country-by-year, day-of-week,
        and month-of-year fixed effects; standard errors clustered at
        country x year x day-bin).
        Panel B (Poisson QML) is estimated only on the four count columns
        (1)-(4); the share columns are left blank because the IRR has no
        meaning for a share in [0,1].  We pad the Poisson tex file with
        four empty cells per data row so panelcombine can align it with
        the OLS panel.
        Reports the Pre-Scandal Bin Mean as a reporting statistic; the
        Country x Year FE checkmark row is appended at the very bottom of
        the combined table (clustering level lives in the paper's caption).

   Inputs:
        - ${datfin}/protests_scandals_30days_v3.dta
        - ${progdir}/define_panelcombine.do

   Outputs (under ${work}/results/tables/):
        - violent_peaceful_ols_temp.tex        (intermediate; deleted via cleanup)
        - violent_peaceful_poi_temp.tex        (intermediate; deleted via cleanup)
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
global tables  "${identity}/Corrupcion/protest_repo/paper/tables"
global progdir "${identity}/Corrupcion/protest_repo/code/programs"

/* --------------- Load the panelcombine program --------------- */
do "${progdir}/define_panelcombine.do"

/* --------------- Read the event-window panel --------------- */
use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"

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

esttab _all using "${tables}/violent_peaceful_ols_temp.tex", ///
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
}

esttab _all using "${tables}/violent_peaceful_poi_temp.tex", ///
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
   Write the padded content to an OS-temp file (not in Dropbox) to
   avoid r(608) "cannot modify or erase" when the target file is
   briefly locked (open in an editor or being synced by Dropbox).   */
tempfile poi_padded
tempname pin pout
file open `pin'  using "${tables}/violent_peaceful_poi_temp.tex", read  text
file open `pout' using "`poi_padded'",                             write text replace
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
capture erase "${tables}/violent_peaceful_poi_temp.tex"

/* ============================================================
   COMBINE PANELS + append Country x Year FE checkmark row
   (clustering level lives in the caption; no SE row here)
   Panelcombine reads the padded Poisson tex directly from OS temp.
   ============================================================ */
panelcombine, ///
	use("${tables}/violent_peaceful_ols_temp.tex" ///
	    "`poi_padded'") ///
	paneltitles("OLS" "Poisson QML") ///
	columncount(9) ///
	save("${tables}/violent_peaceful_ols_poi_panels.tex") ///
	cleanup

local d  = char(36)
local fe_row  = "Country `d'\times`d' Year FE&  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         \\"

tempfile patched
tempname fin fout
file open `fin'  using "${tables}/violent_peaceful_ols_poi_panels.tex", read  text
file open `fout' using "`patched'",                                      write text replace

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

/* Force the target file to be writable before overwriting it.
   Fails silently if the file is not read-only.                     */
capture erase "${tables}/violent_peaceful_ols_poi_panels.tex"
copy "`patched'" "${tables}/violent_peaceful_ols_poi_panels.tex", replace

display in green "a_reg_violent_peaceful_panels.do finished OK"
