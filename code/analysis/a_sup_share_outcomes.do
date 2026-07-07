/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper - SUPPLEMENTARY MATERIALS

   Code author: Roberto Gonzalez
   Date: 2026-07-02

   Objective:
     OLS panel with SHARE outcomes:
        (1) Share of protests that are violent  (+-30-day window)
        (2) Share of protests that are peaceful (+-30-day window)
        (3) Share of protests that are violent  (+-120-day window)
        (4) Share of protests that are peaceful (+-120-day window)

     share_violent  = num_violent_MM  / num_protests_MM  when num_protests_MM > 0
     share_peaceful = num_peaceful_MM / num_protests_MM  when num_protests_MM > 0
     share_violent  = 0                                  when num_protests_MM = 0
     share_peaceful = 0                                  when num_protests_MM = 0

     Country-days with no protests are imputed to a share of 0 (rather
     than dropped) so the estimation sample matches the count-based
     Table 1's sample.  Under this convention the post-scandal
     coefficient captures the unconditional change in the "fraction of
     country-day protest activity that is violent (peaceful)".

     Specification is otherwise identical to the main Table 1's OLS
     panel: country-by-year, month-of-year, day-of-week fixed effects;
     SE clustered at country x year x day-bin.

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta

   Outputs (under ${work}/results/tables/):
     - sup_share_outcomes.tex   (single OLS panel; 4 columns)
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

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"

egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"

/* --------------- Build the share outcomes --------------- */
gen double share_violent  = num_violent_MM  / num_protests_MM if num_protests_MM > 0
gen double share_peaceful = num_peaceful_MM / num_protests_MM if num_protests_MM > 0
replace    share_violent  = 0 if num_protests_MM == 0
replace    share_peaceful = 0 if num_protests_MM == 0

local firstyear = 2008
local outcomes "share_violent share_peaceful share_violent share_peaceful"
local windows  "30 30 120 120"
local nspecs : word count `outcomes'

/* ============================================================
   OLS on shares (Poisson does not apply for shares in [0,1])
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

esttab _all using "${tables}/sup_share_outcomes.tex", ///
	replace booktabs nonotes nogaps b(3) se(3) ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	mtitles("\shortstack{Share\\Violent}" ///
	        "\shortstack{Share\\Peaceful}" ///
	        "\shortstack{Share\\Violent}" ///
	        "\shortstack{Share\\Peaceful}") ///
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

display in green "a_sup_share_outcomes.do finished OK"
