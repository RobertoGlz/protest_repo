/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper - SUPPLEMENTARY MATERIALS

   Code author: Roberto Gonzalez
   Date: 2026-07-13

   Objective:
     Test whether the post-scandal effect on protests concentrates in
     countries with a lower level of democracy in 2008.

     We use V-Dem's Electoral Democracy Index (`v2x_polyarchy`) in 2008
     as the "level of democracy" measure.  We split the panel countries
     (16 with a scandal in the sample, Venezuela dropped) at the median
     of `v2x_polyarchy` in 2008 and estimate

        Y_{c(s)t} = beta_high * Post_st * 1{HIGH_c}
                  + beta_low  * Post_st * 1{LOW_c}
                  + alpha_d + lambda_m + theta_cy + eps_{c(s)t}

     "HIGH" = above-median country, "LOW" = at-or-below-median country.
     The row `p-value: HIGH = LOW' reports the two-sided p-value on
     H0: beta_high = beta_low.

     Same 8-column layout as main Table~1: counts on +-30/+-120 windows,
     shares on the same windows.  OLS goes to the main body via
     `sup_democracy_split_ols.tex`; Poisson QML (IRR, count outcomes
     only) goes to the appendix via `sup_democracy_split_poi.tex`.

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta
     - VDEM: ${vdem_src}/VDEM CY Full Others.dta

   Outputs (paper/tables/):
     - sup_democracy_split_ols.tex
     - sup_democracy_split_poi.tex
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

/* V-Dem source: try both known locations. */
capture confirm file "${identity}/Corrupcion/replication-package-jpe/data/raw/protest/VDEM/vdem cy full others.dta"
if _rc == 0 {
	global vdem_src "${identity}/Corrupcion/replication-package-jpe/data/raw/protest/VDEM"
	local vdem_file "vdem cy full others.dta"
}
else {
	global vdem_src "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals/Data/raw/VDEM"
	local vdem_file "VDEM CY Full Others.dta"
}

/* ============================================================
   STEP 1 - Build country-level HIGH/LOW democracy flag (2008)
   ============================================================ */
use "${vdem_src}/`vdem_file'", clear
keep country_name country_text_id country_id year v2x_polyarchy
keep if year == 2008
keep country_name v2x_polyarchy

/* Standardise country name to match the protests panel's `country'
   (string) variable.  Add or edit lines here if a country name
   disagrees between the two datasets. */
replace country_name = "Dominican Republic" if country_name == "Dominican Rep."

rename country_name country
rename v2x_polyarchy elec_demo_index

tempfile vdem_2008
save `vdem_2008'

/* ============================================================
   STEP 2 - Merge into event-window panel and build split flag
   ============================================================ */
use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"

merge m:1 country using `vdem_2008', keep(1 3) generate(_mvdem)

/* Median across the panel countries with a V-Dem 2008 score */
preserve
	keep if !missing(elec_demo_index)
	bysort country: keep if _n == 1
	quietly summarize elec_demo_index, detail
	local med_edi = r(p50)
	local n_countries = r(N)
	di as result "Median V-Dem v2x_polyarchy (2008) across `n_countries' " ///
		"panel countries: " %6.3f `med_edi'
restore

gen byte high_dem = elec_demo_index >  `med_edi' if !missing(elec_demo_index)
gen byte low_dem  = elec_demo_index <= `med_edi' if !missing(elec_demo_index)

/* Share outcomes (0 imputed on no-protest days) */
gen double share_violent  = num_violent_MM  / num_protests_MM if num_protests_MM > 0
gen double share_peaceful = num_peaceful_MM / num_protests_MM if num_protests_MM > 0
replace    share_violent  = 0 if num_protests_MM == 0
replace    share_peaceful = 0 if num_protests_MM == 0

/* Interaction terms */
gen byte post_high = post * high_dem
gen byte post_low  = post * low_dem

egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"

local firstyear = 2008
tempfile base
save `base'

local outcomes  "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM share_violent share_peaceful share_violent share_peaceful"
local windows   "30 30 120 120 30 30 120 120"
local nspecs : word count `outcomes'

local poi_out   "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM"
local poi_win   "30 30 120 120"
local poi_n : word count `poi_out'

/* ============================================================
   STEP 3 - OLS (main body)
   ============================================================ */
eststo clear
forvalues k = 1/`nspecs' {
	local outcome : word `k' of `outcomes'
	local window  : word `k' of `windows'
	local bin_size = cond(`window' == 30, 6, 30)

	use `base', clear
	if `window' == 30 {
		eststo m`k': reghdfe `outcome' post_high post_low i.month i.day ///
			if year >= `firstyear' & abs(window) <= 30 & !missing(high_dem), ///
			absorb($fe1) vce($CLUSTER2)
	}
	else {
		eststo m`k': reghdfe `outcome' post_high post_low i.month i.day ///
			if year >= `firstyear' & !missing(high_dem), ///
			absorb($fe1) vce($CLUSTER2)
	}

	quietly summarize `outcome' if e(sample) ///
		& window >= -`bin_size' & window <= -1
	estadd scalar baseline = r(mean)
	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)

	test post_high = post_low
	estadd scalar p_hl = r(p)
}

esttab _all using "${tables}/sup_democracy_split_ols.tex", ///
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
	stats(p_hl baseline N num_scandals r2, ///
	      label("$$p$$-value: HIGH $$=$$ LOW" ///
	            "Mean (Pre-Scandal Bin)" ///
	            "Observations" ///
	            "Number of Scandals" ///
	            "R-squared") ///
	      fmt(3 3 0 0 3)) ///
	keep(post_high post_low) ///
	coeflabels(post_high "Post $\times$ High Democracy (2008)" ///
	           post_low  "Post $\times$ Low Democracy (2008)") ///
	substitute("$$" "$")

/* ============================================================
   STEP 4 - Poisson QML (IRR) on count outcomes only (appendix)
   ============================================================ */
eststo clear
forvalues k = 1/`poi_n' {
	local outcome : word `k' of `poi_out'
	local window  : word `k' of `poi_win'
	local bin_size = cond(`window' == 30, 6, 30)

	use `base', clear
	if `window' == 30 {
		capture eststo m`k': ppmlhdfe `outcome' post_high post_low ///
			if year >= `firstyear' & abs(window) <= 30 & !missing(high_dem), ///
			absorb(month day $fe1) vce($CLUSTER2)
	}
	else {
		capture eststo m`k': ppmlhdfe `outcome' post_high post_low ///
			if year >= `firstyear' & !missing(high_dem), ///
			absorb(month day $fe1) vce($CLUSTER2)
	}

	quietly summarize `outcome' if e(sample) ///
		& window >= -`bin_size' & window <= -1
	estadd scalar baseline = r(mean)
	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)

	capture test post_high = post_low
	if _rc == 0 estadd scalar p_hl = r(p)
}

esttab _all using "${tables}/sup_democracy_split_poi.tex", ///
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
	stats(p_hl baseline N num_scandals r2_p, ///
	      label("p-value: High $$=$$ Low" ///
	            "Mean (Pre-Scandal Bin)" ///
	            "Observations" ///
	            "Number of Scandals" ///
	            "Pseudo R-squared") ///
	      fmt(3 3 0 0 3)) ///
	keep(post_high post_low) ///
	coeflabels(post_high "Post $\times$ High Democracy (2008)" ///
	           post_low  "Post $\times$ Low Democracy (2008)") ///
	substitute("$$" "$")

display in green "a_sup_democracy_split.do finished OK"
