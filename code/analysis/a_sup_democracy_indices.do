/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper - SUPPLEMENTARY MATERIALS

   Code author: Roberto Gonzalez
   Date: 2026-07-27

   Objective:
     Democracy-measurement robustness for the heterogeneity analysis.
     Three outputs:

       (1) sup_democracy_countrylist.tex
           The sample countries with their 2008 V-Dem Electoral Democracy
           Index (v2x_polyarchy) and tercile (Low / Medium / High).

       (2) sup_democracy_index_ranks.tex
           Where each country falls (High / Medium / Low) under FOUR different
           democracy measures, to show the tercile classification is not an
           artefact of a single index:
             - V-Dem Electoral   (v2x_polyarchy)
             - V-Dem Liberal     (v2x_libdem)
             - Polity2           (e_polity2)
             - Freedom House     (e_fh_status: Free/Partly Free/Not Free)

       (3) sup_democracy_terciles_libdem_ols.tex
           Robustness of the tercile democracy split using an ALTERNATIVE
           continuous index (V-Dem Liberal Democracy) in place of the
           Electoral index -- same specification as a_sup_democracy_terciles.do.

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta
     - VDEM: <auto-detected> CY Full+Others .dta

   Outputs (paper/tables/):
     - sup_democracy_countrylist.tex
     - sup_democracy_index_ranks.tex
     - sup_democracy_terciles_libdem_ols.tex
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

capture log close _all
log using "a_sup_democracy_indices_run.log", replace text

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
   STEP 1 - V-Dem 2008 multi-index, one row per country
   ============================================================ */
use "${vdem_src}/`vdem_file'", clear
keep country_name year v2x_polyarchy v2x_libdem e_polity2 e_fh_status
keep if year == 2008
replace country_name = "Dominican Republic" if country_name == "Dominican Rep."
rename country_name country
keep country v2x_polyarchy v2x_libdem e_polity2 e_fh_status
tempfile vdem2008
save `vdem2008'

/* ============================================================
   STEP 2 - restrict to the SAMPLE countries and build terciles
   ============================================================ */
use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
keep country
duplicates drop
merge 1:1 country using `vdem2008', keep(3) nogenerate   /* sample n V-Dem */

/* terciles of each continuous index (1 = bottom .. 3 = top) */
xtile terc_poly = v2x_polyarchy, nq(3)
xtile terc_lib  = v2x_libdem,    nq(3)
xtile terc_pol  = e_polity2,     nq(3)
/* Freedom House status: 1 Free, 2 Partly Free, 3 Not Free -> High/Med/Low */
gen terc_fh = 4 - e_fh_status

/* H/M/L string for each measure (-- if the source is missing) */
foreach m in poly lib pol fh {
	gen str8 hml_`m' = "--"
	replace hml_`m' = "Low"    if terc_`m' == 1
	replace hml_`m' = "Medium" if terc_`m' == 2
	replace hml_`m' = "High"   if terc_`m' == 3
}

/* Freedom House shown in its NATIVE status categories (not H/M/L) in the
   country-classification table. */
gen str12 fhstat = "--"
replace fhstat = "Free"        if e_fh_status == 1
replace fhstat = "Partly Free" if e_fh_status == 2
replace fhstat = "Not Free"    if e_fh_status == 3

/* sort by the Electoral Democracy Index, the headline measure in the main text */
gsort -v2x_polyarchy country
tempfile ranks
save `ranks'

/* ============================================================
   STEP 3 - Table (1): country list with V-Dem Electoral score + tercile
   ============================================================ */
use `ranks', clear
capture file close _t
file open _t using "${tables}/sup_democracy_countrylist.tex", write replace
file write _t "\begin{tabular}{lcc}" _n
file write _t "\toprule" _n
file write _t "Country & V-Dem Electoral (2008) & Democracy tercile \\" _n
file write _t "\midrule" _n
forvalues i = 1/`=_N' {
	local c  = country[`i']
	local sc = string(v2x_polyarchy[`i'], "%4.3f")
	local t  = hml_poly[`i']
	file write _t "`c' & `sc' & `t' \\" _n
}
file write _t "\bottomrule" _n
file write _t "\end{tabular}" _n
file close _t
display in green "sup_democracy_countrylist.tex written"

/* ============================================================
   STEP 4 - Table (2): cross-index High/Medium/Low ranking
   ============================================================ */
use `ranks', clear
capture file close _t
file open _t using "${tables}/sup_democracy_index_ranks.tex", write replace
file write _t "\begin{tabular}{lcccc}" _n
file write _t "\toprule" _n
file write _t " & V-Dem & V-Dem & & Freedom \\" _n
file write _t "Country & Electoral & Liberal & Polity2 & House \\" _n
file write _t "\midrule" _n
forvalues i = 1/`=_N' {
	local c = country[`i']
	local a = hml_poly[`i']
	local b = hml_lib[`i']
	local d = hml_pol[`i']
	local e = fhstat[`i']
	file write _t "`c' & `a' & `b' & `d' & `e' \\" _n
}
file write _t "\bottomrule" _n
file write _t "\end{tabular}" _n
file close _t
display in green "sup_democracy_index_ranks.tex written"

/* ============================================================
   STEP 5 - Table (3): tercile regression using the ALTERNATIVE
   index (V-Dem Liberal Democracy), mirroring a_sup_democracy_terciles.do
   ============================================================ */
preserve
	use `vdem2008', clear
	keep country v2x_libdem
	rename v2x_libdem alt_index
	tempfile altidx
	save `altidx'
restore

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
merge m:1 country using `altidx', keep(1 3) generate(_malt)

preserve
	keep if !missing(alt_index)
	bysort country: keep if _n == 1
	xtile terc3 = alt_index, nq(3)
	keep country terc3
	tempfile terc
	save `terc'
restore
merge m:1 country using `terc', keep(1 3) nogenerate

gen byte terc_low  = (terc3 == 1) if !missing(terc3)
gen byte terc_med  = (terc3 == 2) if !missing(terc3)
gen byte terc_high = (terc3 == 3) if !missing(terc3)

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

local outcomes "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM"
local windows  "30 30 60 60 90 90"
local nspecs : word count `outcomes'

eststo clear
forvalues k = 1/`nspecs' {
	local outcome : word `k' of `outcomes'
	local window  : word `k' of `windows'

	use `base', clear
	eststo m`k': reghdfe `outcome' post_high post_med post_low i.month i.day ///
		if year >= `firstyear' & abs(window) <= `window' & !missing(terc3), ///
		absorb($fe1) vce($CLUSTER2)

	quietly summarize `outcome' if e(sample) & window >= -`window' & window <= -1
	estadd scalar baseline = r(mean)
	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)

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

esttab _all using "${tables}/sup_democracy_terciles_libdem_ols.tex", ///
	replace booktabs nonotes nogaps b(3) se(3) ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	mtitles("\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}" ///
	        "\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}" ///
	        "\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}") ///
	mgroups("$\pm 30$-Day Window" "$\pm 60$-Day Window" ///
	        "$\pm 90$-Day Window", ///
	        pattern(1 0 1 0 1 0) ///
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
	coeflabels(post_high "Post $\times$ High Democracy (Liberal, 2008)" ///
	           post_med  "Post $\times$ Medium Democracy (Liberal, 2008)" ///
	           post_low  "Post $\times$ Low Democracy (Liberal, 2008)") ///
	substitute("$$" "$")

/* ============================================================
   STEP 6 - Table (4): Liberal-index Low vs Medium+High pooled split,
   mirroring a_sup_democracy_low_vs_medhigh.do (which uses the Electoral
   index), so both indices are presented with the same two cuts.
   ============================================================ */
use `base', clear                 /* base already carries libdem terc3 */
gen byte grp_low     = (terc3 == 1)              if !missing(terc3)
gen byte grp_medhigh = (terc3 == 2 | terc3 == 3) if !missing(terc3)
gen byte post_medhigh = post * grp_medhigh
/* post_low already exists in base (= post * bottom-tercile flag) */
tempfile baselmh
save `baselmh'

eststo clear
forvalues k = 1/`nspecs' {
	local outcome : word `k' of `outcomes'
	local window  : word `k' of `windows'

	use `baselmh', clear
	eststo m`k': reghdfe `outcome' post_medhigh post_low i.month i.day ///
		if year >= `firstyear' & abs(window) <= `window' & !missing(terc3), ///
		absorb($fe1) vce($CLUSTER2)

	quietly summarize `outcome' if e(sample) & window >= -`window' & window <= -1
	estadd scalar baseline = r(mean)
	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)

	test post_medhigh = post_low
	local p2 = r(p)
	estadd scalar p_mh_l = `p2'
	quietly lincom post_medhigh - post_low
	if r(estimate) > 0 local p = `p2'/2
	else               local p = 1 - `p2'/2
	estadd scalar p_mh_gt_l = `p'
}

esttab _all using "${tables}/sup_democracy_terciles_libdem_lmh_ols.tex", ///
	replace booktabs nonotes nogaps b(3) se(3) ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	mtitles("\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}" ///
	        "\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}" ///
	        "\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}") ///
	mgroups("$\pm 30$-Day Window" "$\pm 60$-Day Window" ///
	        "$\pm 90$-Day Window", ///
	        pattern(1 0 1 0 1 0) ///
	        prefix(\multicolumn{2}{c}{) suffix(}) span ///
	        erepeat(\cmidrule(lr){@span})) ///
	stats(p_mh_l p_mh_gt_l baseline N num_scandals r2, ///
	      label("p-value: Medium+High $$=$$ Low" ///
	            "p-value: Medium+High $$>$$ Low (one-sided)" ///
	            "Mean (Pre-Scandal)" ///
	            "Observations" ///
	            "Number of Scandals" ///
	            "R-squared") ///
	      fmt(3 3 3 0 0 3)) ///
	keep(post_medhigh post_low) ///
	coeflabels(post_medhigh "Post $\times$ Medium+High Democracy (Liberal, 2008)" ///
	           post_low     "Post $\times$ Low Democracy (Liberal, 2008)") ///
	substitute("$$" "$")

/* ============================================================
   STEP 7 - Table (5): by-democracy-level split using FREEDOM HOUSE.
   e_fh_status is a 3-category status (1 Free, 2 Partly Free, 3 Not Free) in
   2008.  Among the 16 sample countries none is "Not Free", so this is a
   Free vs Partly Free comparison (there is no Low group).  We report the
   one-sided p-value for Free > Partly Free, matching the "stronger where
   democracy is stronger" ordering used for the other indices.
   ============================================================ */
preserve
	use `vdem2008', clear
	keep country e_fh_status
	tempfile fhidx
	save `fhidx'
restore

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
merge m:1 country using `fhidx', keep(1 3) generate(_mfh)

gen byte fh_free = (e_fh_status == 1) if !missing(e_fh_status)
gen byte fh_pf   = (e_fh_status == 2) if !missing(e_fh_status)

gen byte post_free = post * fh_free
gen byte post_pf   = post * fh_pf

egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)
global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"
local firstyear = 2008
tempfile basefh
save `basefh'

eststo clear
forvalues k = 1/`nspecs' {
	local outcome : word `k' of `outcomes'
	local window  : word `k' of `windows'

	use `basefh', clear
	eststo m`k': reghdfe `outcome' post_free post_pf i.month i.day ///
		if year >= `firstyear' & abs(window) <= `window' & !missing(e_fh_status), ///
		absorb($fe1) vce($CLUSTER2)

	quietly summarize `outcome' if e(sample) & window >= -`window' & window <= -1
	estadd scalar baseline = r(mean)
	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)

	test post_free = post_pf
	local p2 = r(p)
	estadd scalar p_f_pf = `p2'
	quietly lincom post_free - post_pf
	if r(estimate) > 0 local p = `p2'/2
	else               local p = 1 - `p2'/2
	estadd scalar p_f_gt_pf = `p'
}

esttab _all using "${tables}/sup_democracy_fh_ols.tex", ///
	replace booktabs nonotes nogaps b(3) se(3) ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	mtitles("\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}" ///
	        "\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}" ///
	        "\shortstack{Violent\\Protests}" ///
	        "\shortstack{Peaceful\\Protests}") ///
	mgroups("$\pm 30$-Day Window" "$\pm 60$-Day Window" ///
	        "$\pm 90$-Day Window", ///
	        pattern(1 0 1 0 1 0) ///
	        prefix(\multicolumn{2}{c}{) suffix(}) span ///
	        erepeat(\cmidrule(lr){@span})) ///
	stats(p_f_pf p_f_gt_pf baseline N num_scandals r2, ///
	      label("p-value: Free $$=$$ Partly Free" ///
	            "p-value: Free $$>$$ Partly Free (one-sided)" ///
	            "Mean (Pre-Scandal)" ///
	            "Observations" ///
	            "Number of Scandals" ///
	            "R-squared") ///
	      fmt(3 3 3 0 0 3)) ///
	keep(post_free post_pf) ///
	coeflabels(post_free "Post $\times$ Free (Freedom House, 2008)" ///
	           post_pf   "Post $\times$ Partly Free (Freedom House, 2008)") ///
	substitute("$$" "$")

display in green "a_sup_democracy_indices.do finished OK"
capture log close _all
