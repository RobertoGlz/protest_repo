/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper - SUPPLEMENTARY MATERIALS

   Code author: Roberto Gonzalez
   Date: 2026-07-02

   Objective:
     Regression-based (pooled) version of the hierarchy heterogeneity
     result that the main paper shows via per-scandal box plots
     (Figure 2 / per_scandal_effects_apex_v2.do).

     For each (outcome, window) we estimate

        Y_{c(s)t} = beta_pres * post_st * 1{Pres_s}
                  + beta_oa   * post_st * 1{OtherApex_s}
                  + beta_ona  * post_st * 1{OtherNonApex_s}
                  + alpha_d + lambda_m + theta_cy + eps_{c(s)t}

     There is NO stand-alone `post' term, so each coefficient is the
     estimated average post-scandal effect for that category (rather
     than a differential relative to a reference).  We additionally
     report tests of

        H0: beta_pres = beta_ona          (Pres vs Other Non-Apex)
        H0: beta_oa   = beta_ona          (Other Apex vs Other Non-Apex)
        H0: beta_pres = beta_oa           (Pres vs Other Apex)

     Category assignment follows apex_cat v2:
        President      = position == "president"
        Other Apex     = position == "governor"
                         OR (position == "sc_judge_congressman" AND
                             id in {"202","NEW26","NEW30","332","NEW23"})
        Other Non-Apex = position == "other_judiciary" | "others"
                         OR (position == "sc_judge_congressman" AND
                             id not in the SC-Judge set above)

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta
     - ${datfin}/scandals_classified.csv

   Outputs (under ${work}/results/tables/):
     - sup_hierarchy_regression.tex   (single-panel OLS table;
                                        4 columns matching main Table 1)
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

/* --------------- Position lookup --------------- */
import delimited using "${datfin}/scandals_classified.csv", ///
	clear varnames(1) bindquotes(strict)
keep id country position
tempfile cls
save `cls'

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
merge m:1 id country using `cls', keep(1 3) generate(_mclass)

/* --------------- Share outcomes --------------- */
gen double share_violent  = num_violent_MM  / num_protests_MM if num_protests_MM > 0
gen double share_peaceful = num_peaceful_MM / num_protests_MM if num_protests_MM > 0
replace    share_violent  = 0 if num_protests_MM == 0
replace    share_peaceful = 0 if num_protests_MM == 0

/* --------------- Apex categorical (v2) --------------- */
gen byte apex_cat = .
replace apex_cat = 1 if position == "president"
replace apex_cat = 2 if position == "governor"
replace apex_cat = 2 if position == "sc_judge_congressman" & ///
	inlist(id, "202", "NEW26", "NEW30", "332", "NEW23")
replace apex_cat = 3 if position == "sc_judge_congressman" & ///
	!inlist(id, "202", "NEW26", "NEW30", "332", "NEW23")
replace apex_cat = 3 if position == "other_judiciary"
replace apex_cat = 3 if position == "others"

label define APEX 1 "President" 2 "Other Apex" 3 "Other Non-Apex", replace
label values apex_cat APEX

/* Category-specific post interactions (no stand-alone post term). */
gen byte post_pres = post * (apex_cat == 1)
gen byte post_oa   = post * (apex_cat == 2)
gen byte post_ona  = post * (apex_cat == 3)

egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"

local firstyear = 2008
local outcomes "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM share_violent share_peaceful share_violent share_peaceful"
local windows  "30 30 120 120 30 30 120 120"
local nspecs : word count `outcomes'

eststo clear
forvalues k = 1/`nspecs' {
	local outcome : word `k' of `outcomes'
	local window  : word `k' of `windows'
	local bin_size = cond(`window' == 30, 6, 30)

	if `window' == 30 {
		eststo m`k': reghdfe `outcome' post_pres post_oa post_ona i.month i.day ///
			if year >= `firstyear' & abs(window) <= 30 & !missing(apex_cat), ///
			absorb($fe1) vce($CLUSTER2)
	}
	else {
		eststo m`k': reghdfe `outcome' post_pres post_oa post_ona i.month i.day ///
			if year >= `firstyear' & !missing(apex_cat), ///
			absorb($fe1) vce($CLUSTER2)
	}

	quietly summarize `outcome' if e(sample) ///
		& window >= -`bin_size' & window <= -1
	estadd scalar baseline = r(mean)

	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)

	/* Category-difference tests */
	test post_pres = post_ona
	estadd scalar p_pres_ona = r(p)
	test post_oa = post_ona
	estadd scalar p_oa_ona   = r(p)
	test post_pres = post_oa
	estadd scalar p_pres_oa  = r(p)
}

esttab _all using "${tables}/sup_hierarchy_regression.tex", ///
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
	stats(p_pres_ona p_oa_ona p_pres_oa baseline N num_scandals r2, ///
	      label("p-value: President $$=$$ Other Non-Apex" ///
	            "p-value: Other Apex $$=$$ Other Non-Apex" ///
	            "p-value: President $$=$$ Other Apex" ///
	            "Mean (Pre-Scandal Bin)" ///
	            "Observations" ///
	            "Number of Scandals" ///
	            "R-squared") ///
	      fmt(3 3 3 3 0 0 3)) ///
	keep(post_pres post_oa post_ona) ///
	coeflabels(post_pres "Post $\times$ President" ///
	           post_oa   "Post $\times$ Other Apex" ///
	           post_ona  "Post $\times$ Other Non-Apex") ///
	substitute(\$ $)

display in green "a_sup_hierarchy_regression.do finished OK"
