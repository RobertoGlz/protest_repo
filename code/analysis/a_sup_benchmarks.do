/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper - SUPPLEMENTARY MATERIALS

   Code author: Roberto Gonzalez
   Date: 2026-07-13  (updated 2026-07-14: OLS table extended to 8 columns
                      -- counts + shares -- to match Table 1.)

   Objective:
     Benchmark the headline corruption protest effects against two other
     high-salience national shocks that are plausibly as-good-as-randomly
     timed with respect to the protest baseline:
        - Football (soccer) national-team match losses.
        - Currency depreciation episodes.

     For each "treatment" we estimate EXACTLY the headline specification
     of Table~1 (\autoref{eq:main}) -- OLS in the main body and Poisson
     QML (IRR) in the appendix.

     The OLS table has the SAME eight columns as Table~1 (violent/peaceful
     counts and shares on the +-30 and +-120 windows).  The Poisson table
     keeps the four count columns only (IRR has no meaning for a share).

     Same fixed effects (country x year, month-of-year, day-of-week), same
     clustering (country x year x day-bin), same 2008-2018 sample, Venezuela
     dropped.

     Each table has FOUR panels so that both headline corruption
     regressions can be benchmarked against the two shocks:
        Panel A: Apex corruption   (President + Other Apex, 64 scandals)
        Panel B: Non-apex corruption (Other Non-Apex, 112 scandals)
        Panel C: Football match losses
        Panel D: Currency depreciations

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta               (corruption)
     - ${datfin}/scandals_classified.csv                       (apex partition)
     - ${datfin}/protests_scandals_30days_football_v3.dta      (football)
     - ${datfin}/protests_scandals_30days_depreciation_v3.dta  (depreciation)
     - ${progdir}/define_panelcombine.do

   Outputs (paper/tables/):
     - sup_benchmarks_ols_panels.tex          (OLS, 4 cols; appendix)
     - sup_benchmarks_ols_panels_shares.tex   (OLS, 8 cols; focused draft)
     - sup_benchmarks_poi_panels.tex          (Poisson IRR, 4 cols; appendix)
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

/* ------------------------------------------------------------------
   Log the full run so errors can be inspected.
   Written to: code/analysis/a_sup_benchmarks.log
   ------------------------------------------------------------------ */
capture log close _all
log using "${identity}/Corrupcion/protest_repo/code/analysis/a_sup_benchmarks.log", replace text

do "${progdir}/define_panelcombine.do"

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"
local  firstyear = 2008

/* ============================================================
   Loop over estimator (ols/poi) and panel.  Each panel loads its
   OWN source dataset directly from disk and builds the share
   outcomes inline -- no pre-built tempfiles, no helper programs.
   ============================================================ */
foreach est in ols poi {

	if "`est'" == "ols" {
		local out_list "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM share_violent share_peaceful share_violent share_peaceful"
		local win_list "30 30 120 120 30 30 120 120"
	}
	else {
		local out_list "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM"
		local win_list "30 30 120 120"
	}
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

		/* share outcomes (0 imputed on no-protest days) */
		capture confirm variable num_protests_MM
		if _rc gen double num_protests_MM = num_violent_MM + num_peaceful_MM
		gen double share_violent  = num_violent_MM  / num_protests_MM if num_protests_MM > 0
		gen double share_peaceful = num_peaceful_MM / num_protests_MM if num_protests_MM > 0
		replace    share_violent  = 0 if num_protests_MM == 0
		replace    share_peaceful = 0 if num_protests_MM == 0

		egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
		                        s_lead30 s_lead60 s_lead90 s_lead120)

		tempfile pdata
		save `pdata'

		/* ---------- run the cells on this panel's data ---------- */
		eststo clear
		forvalues k = 1/`ncell' {
			local outcome : word `k' of `out_list'
			local window  : word `k' of `win_list'
			local bin_size = cond(`window' == 30, 6, 30)

			use `pdata', clear
			if "`est'" == "ols" {
				if `window' == 30 {
					eststo m`k': reghdfe `outcome' post i.month i.day ///
						if year >= `firstyear' & abs(window) <= 30 & `flag' == 1, ///
						absorb($fe1) vce($CLUSTER2)
				}
				else {
					eststo m`k': reghdfe `outcome' post i.month i.day ///
						if year >= `firstyear' & `flag' == 1, ///
						absorb($fe1) vce($CLUSTER2)
				}
			}
			else {
				if `window' == 30 {
					capture eststo m`k': ppmlhdfe `outcome' post ///
						if year >= `firstyear' & abs(window) <= 30 & `flag' == 1, ///
						absorb(month day $fe1) vce($CLUSTER2)
				}
				else {
					capture eststo m`k': ppmlhdfe `outcome' post ///
						if year >= `firstyear' & `flag' == 1, ///
						absorb(month day $fe1) vce($CLUSTER2)
				}
			}

			quietly summarize `outcome' if e(sample) ///
				& window >= -`bin_size' & window <= -1
			estadd scalar baseline = r(mean)

			capture quietly levelsof id if e(sample) == 1
			if _rc == 0 estadd scalar num_events = r(r)
		}

		/* ---------- write this panel's temp table(s) ---------- */
		if "`est'" == "ols" {
			/* 4-column (counts only): appendix Table S7 layout */
			esttab m1 m2 m3 m4 using "${tables}/bench_ols4_`p'_temp.tex", ///
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
				stats(baseline N num_events r2, ///
				      label("Mean (Pre-Event Bin)" "Observations" ///
				            "Number of Events" "R-squared") ///
				      fmt(3 0 0 3)) ///
				keep(post) coeflabels(post "Post Event")

			/* 8-column (counts + shares): comparable to Table 1 */
			esttab m1 m2 m3 m4 m5 m6 m7 m8 using "${tables}/bench_ols8_`p'_temp.tex", ///
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
				stats(baseline N num_events r2, ///
				      label("Mean (Pre-Event Bin)" "Observations" ///
				            "Number of Events" "R-squared") ///
				      fmt(3 0 0 3)) ///
				keep(post) coeflabels(post "Post Event")
		}
		else {
			esttab m1 m2 m3 m4 using "${tables}/bench_poi_`p'_temp.tex", ///
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
				stats(baseline N num_events r2_p, ///
				      label("Mean (Pre-Event Bin)" "Observations" ///
				            "Number of Events" "Pseudo R-squared") ///
				      fmt(3 0 0 3)) ///
				keep(post) coeflabels(post "Post Event (IRR)")
		}
	}

	/* ---------- combine the four panels ---------- */
	if "`est'" == "ols" {
		panelcombine, ///
			use("${tables}/bench_ols4_corrpa_temp.tex" ///
			    "${tables}/bench_ols4_corrna_temp.tex" ///
			    "${tables}/bench_ols4_football_temp.tex" ///
			    "${tables}/bench_ols4_deprec_temp.tex") ///
			paneltitles("Apex corruption (President + Other Apex)" ///
			            "Non-apex corruption (Other Non-Apex)" ///
			            "Football match losses" ///
			            "Currency depreciations") ///
			columncount(5) ///
			save("${tables}/sup_benchmarks_ols_panels.tex") ///
			cleanup

		panelcombine, ///
			use("${tables}/bench_ols8_corrpa_temp.tex" ///
			    "${tables}/bench_ols8_corrna_temp.tex" ///
			    "${tables}/bench_ols8_football_temp.tex" ///
			    "${tables}/bench_ols8_deprec_temp.tex") ///
			paneltitles("Apex corruption (President + Other Apex)" ///
			            "Non-apex corruption (Other Non-Apex)" ///
			            "Football match losses" ///
			            "Currency depreciations") ///
			columncount(9) ///
			save("${tables}/sup_benchmarks_ols_panels_shares.tex") ///
			cleanup
	}
	else {
		panelcombine, ///
			use("${tables}/bench_poi_corrpa_temp.tex" ///
			    "${tables}/bench_poi_corrna_temp.tex" ///
			    "${tables}/bench_poi_football_temp.tex" ///
			    "${tables}/bench_poi_deprec_temp.tex") ///
			paneltitles("Apex corruption (President + Other Apex)" ///
			            "Non-apex corruption (Other Non-Apex)" ///
			            "Football match losses" ///
			            "Currency depreciations") ///
			columncount(5) ///
			save("${tables}/sup_benchmarks_poi_panels.tex") ///
			cleanup
	}
}

display in green "a_sup_benchmarks.do finished OK"

capture log close _all
