/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper - SUPPLEMENTARY MATERIALS

   Code author: Roberto Gonzalez
   Date: 2026-07-07

   Objective:
     Table~1 augmented with share outcomes as additional OLS columns.

     Eight columns total:
        (1) Violent Protests, +-30-day window
        (2) Peaceful Protests, +-30-day window
        (3) Violent Protests, +-120-day window
        (4) Peaceful Protests, +-120-day window
        (5) Share of protests that are violent, +-30-day window
        (6) Share of protests that are peaceful, +-30-day window
        (7) Share of protests that are violent, +-120-day window
        (8) Share of protests that are peaceful, +-120-day window

     Panel A (OLS)     : all eight columns.
     Panel B (Poisson) : only the four count columns (1)-(4).
                         Columns (5)-(8) are left empty because IRR has
                         no meaning for a share in [0,1].  We pad the
                         Poisson tex file with four empty cells per data
                         row before combining panels.

     share_violent  = num_violent_MM  / num_protests_MM  when num_protests_MM > 0
     share_peaceful = num_peaceful_MM / num_protests_MM  when num_protests_MM > 0
     share_violent  = share_peaceful  = 0                when num_protests_MM = 0

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta
     - ${progdir}/define_panelcombine.do

   Outputs (under ${work}/results/tables/):
     - sup_reformat_ols_temp.tex        (intermediate)
     - sup_reformat_poi_temp.tex        (intermediate, padded to 8 data cols)
     - sup_reformat_table1.tex          (final combined two-panel table)
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

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"

gen double share_violent  = num_violent_MM  / num_protests_MM if num_protests_MM > 0
gen double share_peaceful = num_peaceful_MM / num_protests_MM if num_protests_MM > 0
replace    share_violent  = 0 if num_protests_MM == 0
replace    share_peaceful = 0 if num_protests_MM == 0

egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"

local firstyear   = 2008
local ols_out     "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM share_violent share_peaceful share_violent share_peaceful"
local ols_win     "30 30 120 120 30 30 120 120"
local ols_n : word count `ols_out'

local poi_out     "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM"
local poi_win     "30 30 120 120"
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

esttab _all using "${tables}/sup_reformat_ols_temp.tex", ///
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
   PANEL B: Poisson QML (IRR) on the 4 count outcomes only.
   Share columns will be left empty in the final table.
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

esttab _all using "${tables}/sup_reformat_poi_temp.tex", ///
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

/* ------------------------------------------------------------
   Pad the Poisson tex file so each data row has 8 data cells
   (matching the OLS panel).  We insert " & & & &" before the
   first "\\\\" on every line that contains "\\\\".  panelcombine
   discards the Poisson tex file's header rows, so mangling
   the pre-\midrule lines is harmless; only the survived
   data rows need to match the OLS column count.
   ------------------------------------------------------------ */
tempfile poi_padded
tempname pin pout
file open `pin'  using "${tables}/sup_reformat_poi_temp.tex", read  text
file open `pout' using "`poi_padded'",                         write text replace
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
capture erase "${tables}/sup_reformat_poi_temp.tex"

/* ============================================================
   COMBINE PANELS + append FE / Cluster rows
   ============================================================ */
panelcombine, ///
	use("${tables}/sup_reformat_ols_temp.tex" ///
	    "`poi_padded'") ///
	paneltitles("OLS" "Poisson QML") ///
	columncount(9) ///
	save("${tables}/sup_reformat_table1.tex") ///
	cleanup

local d  = char(36)
local fe_row  = "Country `d'\times`d' Year FE&  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         &  \checkmark         \\"
local se_row  = "SE Cluster  &C `d'\times`d' Y `d'\times`d' DB         &C `d'\times`d' Y `d'\times`d' DB         &C `d'\times`d' Y `d'\times`d' DB         &C `d'\times`d' Y `d'\times`d' DB         &C `d'\times`d' Y `d'\times`d' DB         &C `d'\times`d' Y `d'\times`d' DB         &C `d'\times`d' Y `d'\times`d' DB         &C `d'\times`d' Y `d'\times`d' DB         \\"

tempfile patched
tempname fin fout
file open `fin'  using "${tables}/sup_reformat_table1.tex", read  text
file open `fout' using "`patched'",                          write text replace
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
copy "`patched'" "${tables}/sup_reformat_table1.tex", replace

display in green "a_sup_reformat_table1.do finished OK"
