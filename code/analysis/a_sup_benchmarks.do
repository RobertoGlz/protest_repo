/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper

   Code author: Roberto Gonzalez
   Date: 2026-07-13  (updated 2026-07-14: columns are now violent/peaceful
                      COUNTS at four event-window widths -- 30/60/90/120 --
                      replacing the old share columns; panels renamed
                      "Apex" / "Non-Apex".)

   Objective:
     Main results table.  Estimates \autoref{eq:main} on the four
     event-window widths T in {30, 60, 90, 120}, with two columns per
     window (violent and peaceful protest counts), for four samples:

        Panel A: Apex        (President + Other Apex, 64 scandals)
        Panel B: Non-Apex    (Other Non-Apex, 112 scandals)
        Panel C: Football match losses
        Panel D: Currency depreciations

     Panels C and D benchmark the corruption effect against two other
     high-salience national shocks whose timing is plausibly as-good-as-
     random with respect to the protest baseline.

     Eight columns: (violent, peaceful) x (30, 60, 90, 120).
     Same fixed effects (country x year, month-of-year, day-of-week),
     same clustering (country x year x day-bin), 2008-2018, Venezuela
     dropped.  "Mean (Pre-Event)" is the outcome mean over the same
     +-window as the column (30 days before for the +-30 column, 60 for
     the +-60 column, etc.).

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta               (corruption)
     - ${datfin}/scandals_classified.csv                       (apex partition)
     - ${datfin}/protests_scandals_30days_football_v3.dta      (football)
     - ${datfin}/protests_scandals_30days_depreciation_v3.dta  (depreciation)
     - ${progdir}/define_panelcombine.do

   Outputs (paper/tables/):
     - sup_benchmarks_ols_panels.tex   (OLS, 8 cols; main body)
     - sup_benchmarks_poi_panels.tex   (Poisson QML IRR, 8 cols; appendix)
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

capture log close _all
log using "${identity}/Corrupcion/protest_repo/code/analysis/a_sup_benchmarks.log", replace text

do "${progdir}/define_panelcombine.do"

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"
local  firstyear = 2008

/* ============================================================
   Loop over estimator (ols/poi) and panel.  Each panel loads its
   own source dataset directly from disk.
   ============================================================ */
foreach est in ols poi {

	/* eight cells: (violent, peaceful) x (30, 60, 90, 120) */
	local out_list "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM"
	local win_list "30 30 60 60 90 90 120 120"
	local ncell : word count `out_list'

	foreach p in corrpa corrna football deprec {

		/* ---------- load + prep this panel's data ---------- */
		if "`p'" == "corrpa" | "`p'" == "corrna" {
			import delimited using "${datfin}/scandals_classified.csv", ///
				clear varnames(1) bindquotes(strict)
			keep id country position
			tempfile cls
			save `cls'

			use "${datfin}/protests_scandals_30days_v3", clear
			drop if country == "Venezuela"
			merge m:1 id country using `cls', keep(1 3) nogenerate

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

			if "`p'" == "corrpa" local flag "in_pa"
			else                 local flag "in_na"
		}
		else if "`p'" == "football" {
			use "${datfin}/protests_scandals_30days_football_v3", clear
			drop if country == "Venezuela"
			gen byte keepall = 1
			local flag "keepall"
		}
		else if "`p'" == "deprec" {
			use "${datfin}/protests_scandals_30days_depreciation_v3", clear
			drop if country == "Venezuela"
			gen byte keepall = 1
			local flag "keepall"
		}

		egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
		                        s_lead30 s_lead60 s_lead90 s_lead120)

		tempfile pdata
		save `pdata'

		/* ---------- run the eight cells ---------- */
		eststo clear
		forvalues k = 1/`ncell' {
			local outcome : word `k' of `out_list'
			local window  : word `k' of `win_list'

			use `pdata', clear
			if "`est'" == "ols" {
				eststo m`k': reghdfe `outcome' post i.month i.day ///
					if year >= `firstyear' & abs(window) <= `window' & `flag' == 1, ///
					absorb($fe1) vce($CLUSTER2)
			}
			else {
				capture eststo m`k': ppmlhdfe `outcome' post ///
					if year >= `firstyear' & abs(window) <= `window' & `flag' == 1, ///
					absorb(month day $fe1) vce($CLUSTER2)
			}

			/* pre-scandal mean over the SAME +-window as the column */
			quietly summarize `outcome' if e(sample) ///
				& window >= -`window' & window <= -1
			estadd scalar baseline = r(mean)

			capture quietly levelsof id if e(sample) == 1
			if _rc == 0 estadd scalar num_events = r(r)
		}

		/* ---------- write this panel's temp table ---------- */
		if "`est'" == "ols" {
			local eformopt ""
			local r2stat   "r2"
			local r2lab    "R-squared"
			local postlab  "Post Event"
		}
		else {
			local eformopt "eform"
			local r2stat   "r2_p"
			local r2lab    "Pseudo R-squared"
			local postlab  "Post Event (IRR)"
		}

		esttab m1 m2 m3 m4 m5 m6 m7 m8 using "${tables}/bench_`est'_`p'_temp.tex", ///
			replace booktabs nonotes nogaps b(3) se(3) `eformopt' ///
			star(* 0.10 ** 0.05 *** 0.01) ///
			mtitles("\shortstack{Violent\\Protests}" ///
			        "\shortstack{Peaceful\\Protests}" ///
			        "\shortstack{Violent\\Protests}" ///
			        "\shortstack{Peaceful\\Protests}" ///
			        "\shortstack{Violent\\Protests}" ///
			        "\shortstack{Peaceful\\Protests}" ///
			        "\shortstack{Violent\\Protests}" ///
			        "\shortstack{Peaceful\\Protests}") ///
			mgroups("$\pm 30$-Day Window" "$\pm 60$-Day Window" ///
			        "$\pm 90$-Day Window" "$\pm 120$-Day Window", ///
			        pattern(1 0 1 0 1 0 1 0) ///
			        prefix(\multicolumn{2}{c}{) suffix(}) span ///
			        erepeat(\cmidrule(lr){@span})) ///
			stats(baseline N num_events `r2stat', ///
			      label("Mean (Pre-Event)" "Observations" ///
			            "Number of Events" "`r2lab'") ///
			      fmt(3 0 0 3)) ///
			keep(post) coeflabels(post "`postlab'")
	}

	/* ---------- combine the four panels ---------- */
	if "`est'" == "ols" local outname "sup_benchmarks_ols_panels.tex"
	else                 local outname "sup_benchmarks_poi_panels.tex"

	panelcombine, ///
		use("${tables}/bench_`est'_corrpa_temp.tex" ///
		    "${tables}/bench_`est'_corrna_temp.tex" ///
		    "${tables}/bench_`est'_football_temp.tex" ///
		    "${tables}/bench_`est'_deprec_temp.tex") ///
		paneltitles("Apex" "Non-Apex" ///
		            "Football match losses" "Currency depreciations") ///
		columncount(9) ///
		save("${tables}/`outname'") ///
		cleanup
}

display in green "a_sup_benchmarks.do finished OK"

capture log close _all
