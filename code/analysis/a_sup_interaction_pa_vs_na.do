/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper - SUPPLEMENTARY MATERIALS

   Code author: Roberto Gonzalez
   Date: 2026-07-13

   Objective:
     Two-group pooled-interaction regression that lets us formally
     test whether the post-scandal effect on protests differs between:
        (i)  scandals implicating President + Other Apex officials
             (post_pa)
        (ii) scandals implicating Other Non-Apex officials
             (post_na)

     For each (outcome, window) we estimate

        Y_{c(s)t} = beta_pa * post_st * 1{PA_s}
                  + beta_na * post_st * 1{NA_s}
                  + alpha_d + lambda_m + theta_cy + eps_{c(s)t}

     and report the p-value from testing H0: beta_pa = beta_na.

     Eight columns (same layout as main Table~1): count outcomes on
     +-30 and +-120 windows, then share outcomes on the same two
     windows.  Poisson columns are NOT included -- this table is
     OLS-only.

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta
     - ${datfin}/scandals_classified.csv

   Outputs (under paper/tables/):
     - sup_interaction_pa_vs_na.tex
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

/* Interaction terms (no stand-alone post term below). */
gen byte post_pa = post * in_pa
gen byte post_na = post * in_na

egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"

local firstyear = 2008
local outcomes  "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM share_violent share_peaceful share_violent share_peaceful"
local windows   "30 30 120 120 30 30 120 120"
local nspecs : word count `outcomes'

eststo clear
forvalues k = 1/`nspecs' {
	local outcome : word `k' of `outcomes'
	local window  : word `k' of `windows'
	local bin_size = cond(`window' == 30, 6, 30)

	if `window' == 30 {
		eststo m`k': reghdfe `outcome' post_pa post_na i.month i.day ///
			if year >= `firstyear' & abs(window) <= 30 & (in_pa == 1 | in_na == 1), ///
			absorb($fe1) vce($CLUSTER2)
	}
	else {
		eststo m`k': reghdfe `outcome' post_pa post_na i.month i.day ///
			if year >= `firstyear' & (in_pa == 1 | in_na == 1), ///
			absorb($fe1) vce($CLUSTER2)
	}

	quietly summarize `outcome' if e(sample) ///
		& window >= -`bin_size' & window <= -1
	estadd scalar baseline = r(mean)

	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)

	/* Equality test */
	test post_pa = post_na
	estadd scalar p_pa_na = r(p)
}

esttab _all using "${tables}/sup_interaction_pa_vs_na.tex", ///
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
	stats(p_pa_na baseline N num_scandals r2, ///
	      label("p-value: Pres.+Other Apex $$=$$ Other Non-Apex" ///
	            "Mean (Pre-Scandal Bin)" ///
	            "Observations" ///
	            "Number of Scandals" ///
	            "R-squared") ///
	      fmt(3 3 0 0 3)) ///
	keep(post_pa post_na) ///
	coeflabels(post_pa "Post $\times$ (President + Other Apex)" ///
	           post_na "Post $\times$ Other Non-Apex") ///
	substitute("$$" "$")

display in green "a_sup_interaction_pa_vs_na.do finished OK"
