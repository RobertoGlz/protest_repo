/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper - SUPPLEMENTARY MATERIALS

   Objective:
     Tercile version of the democracy split.  Countries are grouped by their
     2008 V-Dem Electoral Democracy Index (v2x_polyarchy) into
        - Low     : bottom tercile
        - Medium  : middle tercile
        - High    : top tercile
     and we estimate

        Y_{c(s)t} = b_H Post 1{HIGH} + b_M Post 1{MED} + b_L Post 1{LOW}
                  + alpha_d + lambda_m + theta_cy + eps

     reporting the three coefficients and the ONE-SIDED p-values for
        H1: b_H > b_M ,  H1: b_M > b_L ,  H1: b_H > b_L
     (each obtained by halving the two-sided F/t p-value in the direction of
     the estimated difference).

     Eight columns: violent/peaceful protest counts on the +-30/60/90/120
     windows.  OLS only.

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta
     - VDEM: ${vdem_src}/VDEM CY Full Others.dta

   Outputs (paper/tables/):
     - sup_democracy_terciles_ols.tex
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
   STEP 1 - V-Dem 2008 index per country
   ============================================================ */
use "${vdem_src}/`vdem_file'", clear
keep country_name country_text_id country_id year v2x_polyarchy
keep if year == 2008
keep country_name v2x_polyarchy
replace country_name = "Dominican Republic" if country_name == "Dominican Rep."
rename country_name country
rename v2x_polyarchy elec_demo_index
tempfile vdem_2008
save `vdem_2008'

/* ============================================================
   STEP 2 - Merge into event-window panel and build tercile flags
   ============================================================ */
use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
merge m:1 country using `vdem_2008', keep(1 3) generate(_mvdem)

/* Terciles of the country-level 2008 index (one obs per country) */
preserve
	keep if !missing(elec_demo_index)
	bysort country: keep if _n == 1
	xtile terc3 = elec_demo_index, nq(3)
	quietly count
	di as result "Tercile split across `r(N)' panel countries"
	keep country terc3
	tempfile terc
	save `terc'
restore
merge m:1 country using `terc', keep(1 3) nogenerate

gen byte terc_low  = (terc3 == 1) if !missing(terc3)
gen byte terc_med  = (terc3 == 2) if !missing(terc3)
gen byte terc_high = (terc3 == 3) if !missing(terc3)

/* Interaction terms */
gen byte post_high = post * terc_high
gen byte post_med  = post * terc_med
gen byte post_low  = post * terc_low

egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"

local firstyear = 2008
tempfile base
save `base'

local outcomes  "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM"
local windows   "30 30 60 60 90 90 120 120"
local nspecs : word count `outcomes'

/* ============================================================
   STEP 3 - OLS with one-sided ordering tests
   ============================================================ */
eststo clear
forvalues k = 1/`nspecs' {
	local outcome : word `k' of `outcomes'
	local window  : word `k' of `windows'

	use `base', clear
	eststo m`k': reghdfe `outcome' post_high post_med post_low i.month i.day ///
		if year >= `firstyear' & abs(window) <= `window' & !missing(terc3), ///
		absorb($fe1) vce($CLUSTER2)

	quietly summarize `outcome' if e(sample) ///
		& window >= -`window' & window <= -1
	estadd scalar baseline = r(mean)
	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)

	/* One-sided p-values (halve the two-sided F/t p in the estimated
	   direction of the difference). */
	test post_high = post_med
	local p2 = r(p)
	quietly lincom post_high - post_med
	if r(estimate) > 0 local p = `p2'/2
	else               local p = 1 - `p2'/2
	estadd scalar p_h_gt_m = `p'

	test post_med = post_low
	local p2 = r(p)
	quietly lincom post_med - post_low
	if r(estimate) > 0 local p = `p2'/2
	else               local p = 1 - `p2'/2
	estadd scalar p_m_gt_l = `p'

	test post_high = post_low
	local p2 = r(p)
	quietly lincom post_high - post_low
	if r(estimate) > 0 local p = `p2'/2
	else               local p = 1 - `p2'/2
	estadd scalar p_h_gt_l = `p'
}

esttab _all using "${tables}/sup_democracy_terciles_ols.tex", ///
	replace booktabs nonotes nogaps b(3) se(3) ///
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
	stats(p_h_gt_m p_m_gt_l p_h_gt_l baseline N num_scandals r2, ///
	      label("p-value: High $$>$$ Medium (one-sided)" ///
	            "p-value: Medium $$>$$ Low (one-sided)" ///
	            "p-value: High $$>$$ Low (one-sided)" ///
	            "Mean (Pre-Scandal)" ///
	            "Observations" ///
	            "Number of Scandals" ///
	            "R-squared") ///
	      fmt(3 3 3 3 0 0 3)) ///
	keep(post_high post_med post_low) ///
	coeflabels(post_high "Post $\times$ High Democracy (2008)" ///
	           post_med  "Post $\times$ Medium Democracy (2008)" ///
	           post_low  "Post $\times$ Low Democracy (2008)") ///
	substitute("$$" "$")

display in green "a_sup_democracy_terciles.do finished OK"
