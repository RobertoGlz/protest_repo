/* ----------------------------------------------------------------------------
   Project: Apex corruption protests paper

   Code author: Roberto Gonzalez
   Date: 2026-06-25

   Objective:
     Combined headline table with two panels (Panel A: +-30-day window,
     Panel B: +-120-day window) for three protest outcomes:
         (1) any protests, (2) violent protests, (3) peaceful protests.
     Uses panelcombine to merge the two windows into one .tex file.
     Adds the average value of the outcome in the bin immediately before
     the scandal date as an extra reporting statistic.

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta (event-window panel of
       176 hand-curated apex corruption scandals; the same dataset used by
       a_reg_allscandals.do and a_reg_allscandals_narrowbw.do).
     - ${progdir}/define_panelcombine.do (panelcombine program definition).

   Outputs (under ${work}/results/tables/):
     - three_outcomes_30d.tex     -- intermediate, deleted by cleanup option
     - three_outcomes_120d.tex    -- intermediate, deleted by cleanup option
     - three_outcomes_panels.tex  -- final combined two-panel table
       (the file the main paper \input's)
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

/* Day-bin grouping for clustering (matches a_reg_allscandals.do convention) */
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)

/* --------------- Specification --------------- */
global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"

local firstyear    = 2008
local outcome_list = "num_protests_MM num_violent_MM num_peaceful_MM"

/* --------------- Loop over windows: build intermediate tables --------------- */
foreach window_days in 30 120 {

	/* Width of the bin immediately before the scandal:
	   6 days at the narrow window, 30 days at the wide window. */
	local bin_size = cond(`window_days' == 30, 6, 30)

	eststo clear
	local m = 0
	foreach outcome of local outcome_list {
		local ++m

		if `window_days' == 30 {
			eststo m`m': reghdfe `outcome' post i.month i.day ///
				if year >= `firstyear' & abs(window) <= 30, ///
				absorb($fe1) vce($CLUSTER2)
		}
		else {
			eststo m`m': reghdfe `outcome' post i.month i.day ///
				if year >= `firstyear', ///
				absorb($fe1) vce($CLUSTER2)
		}

		/* Pre-scandal-bin mean of the outcome */
		quietly summarize `outcome' if e(sample) ///
			& window >= -`bin_size' & window <= -1
		estadd scalar baseline = r(mean)

		/* Other reporting scalars / locals.
		   Country x Year FE and SE Cluster are NOT included here -- we add
		   them once at the bottom of the combined table after panelcombine. */
		quietly levelsof id if e(sample) == 1
		estadd scalar num_scandals = r(r)
	}

	/* Export one intermediate table per window. */
	esttab _all using "${tables}/three_outcomes_`window_days'd.tex", ///
		replace booktabs nonotes nogaps b(3) se(3) ///
		star(* 0.10 ** 0.05 *** 0.01) ///
		mtitles("\shortstack{Any\\Protests}" ///
		        "\shortstack{Violent\\Protests}" ///
		        "\shortstack{Peaceful\\Protests}") ///
		stats(baseline N num_scandals r2, ///
		      label("Mean (Pre-Scandal Bin)" ///
		            "Observations" ///
		            "Number of Scandals" ///
		            "R-squared") ///
		      fmt(3 0 0 3)) ///
		keep(post) coeflabels(post "Post Scandal")
}

/* --------------- Combine the two panels into the final table --------------- */
panelcombine, ///
	use("${tables}/three_outcomes_30d.tex" ///
	    "${tables}/three_outcomes_120d.tex") ///
	paneltitles("$\pm$30-Day Window" "$\pm$120-Day Window") ///
	columncount(4) ///
	save("${tables}/three_outcomes_panels.tex") ///
	cleanup

/* --------------- Append the global FE / Cluster rows once at the bottom ---
   The combined table ends with \bottomrule \end{tabular} }. We insert a
   \midrule plus the Country x Year FE and SE Cluster rows just before
   \bottomrule, so they appear only once at the very bottom of the table.
--------------------------------------------------------------------------- */
local d  = char(36)   /* literal $ used in math-mode "$\times$" strings */
local fe_row  = "Country `d'\times`d' Year FE&  \checkmark         &  \checkmark         &  \checkmark         \\"
local se_row  = "SE Cluster  &C `d'\times`d' Y `d'\times`d' DB         &C `d'\times`d' Y `d'\times`d' DB         &C `d'\times`d' Y `d'\times`d' DB         \\"

tempfile patched
tempname fin fout
file open `fin'  using "${tables}/three_outcomes_panels.tex", read  text
file open `fout' using "`patched'",                            write text replace

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

copy "`patched'" "${tables}/three_outcomes_panels.tex", replace

display in green "a_reg_main_panels.do finished OK"
