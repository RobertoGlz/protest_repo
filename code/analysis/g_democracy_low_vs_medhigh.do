/* ----------------------------------------------------------------------------
   Grievance-split replication of Table 3 (democracy Low vs. Medium+High).

   Same 6-column layout, TWO panels by grievance class:
        Panel A: Corruption-related      Panel B: Unrelated to corruption
   Rows: Post x Medium+High Democracy (2008), Post x Low Democracy (2008).

   Output (paper/tables/): g_democracy_panels.tex
   NOTE: run g_build_grievance_counts.do first.
---------------------------------------------------------------------------- */
set more off
clear all
if "`c(username)'" == "rob98" global identity "~/Dropbox"
if "`c(username)'" == "Rob_9" global identity "C:/Users/Rob_9/Dropbox"
global path    "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin  "${path}/Data/final"
global tables  "${identity}/Corrupcion/protest_repo/paper/tables"
global progdir "${identity}/Corrupcion/protest_repo/code/programs"
do "${progdir}/define_panelcombine.do"

capture confirm file "${identity}/Corrupcion/replication-package-jpe/data/raw/protest/VDEM/vdem cy full others.dta"
if _rc == 0 {
	global vdem_src "${identity}/Corrupcion/replication-package-jpe/data/raw/protest/VDEM"
	local vdem_file "vdem cy full others.dta"
}
else {
	global vdem_src "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals/Data/raw/VDEM"
	local vdem_file "VDEM CY Full Others.dta"
}

use "${vdem_src}/`vdem_file'", clear
keep country_name year v2x_polyarchy
keep if year == 2008
keep country_name v2x_polyarchy
replace country_name = "Dominican Republic" if country_name == "Dominican Rep."
rename country_name country
rename v2x_polyarchy elec_demo_index
tempfile vdem_2008
save `vdem_2008'

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
capture confirm string variable id
if _rc==0 {
	drop if id == "TWNEWLATINO14" & country == "Ecuador"
	drop if id == "TWNEWLATINO23" & country == "Brazil"
}
merge m:1 country using `vdem_2008', keep(1 3) generate(_mvdem)
merge m:1 country date using "${datfin}/grievance_counts.dta", keep(1 3) generate(_mg)
foreach v in gcorr_v gunrel_v gcorr_p gunrel_p {
	replace `v' = 0 if missing(`v')
}
preserve
	keep if !missing(elec_demo_index)
	bysort country: keep if _n == 1
	xtile terc3 = elec_demo_index, nq(3)
	keep country terc3
	tempfile terc
	save `terc'
restore
merge m:1 country using `terc', keep(1 3) nogenerate
gen byte grp_low     = (terc3 == 1)              if !missing(terc3)
gen byte grp_medhigh = (terc3 == 2 | terc3 == 3) if !missing(terc3)
gen byte post_low     = post * grp_low
gen byte post_medhigh = post * grp_medhigh
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 s_lead30 s_lead60 s_lead90 s_lead120)

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"
local firstyear = 2008
tempfile base
save `base'

local win_list "30 30 60 60 90 90"
foreach cls in corr unrel {
	local out_list "g`cls'_v g`cls'_p g`cls'_v g`cls'_p g`cls'_v g`cls'_p"
	eststo clear
	forvalues k = 1/6 {
		local outcome : word `k' of `out_list'
		local window  : word `k' of `win_list'
		use `base', clear
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
		if r(estimate) > 0 local p1 = `p2'/2
		else               local p1 = 1 - `p2'/2
		estadd scalar p_mh_gt_l = `p1'
	}
	esttab m1 m2 m3 m4 m5 m6 using "${tables}/g_democracy_`cls'_temp.tex", ///
		replace booktabs nonotes nogaps b(3) se(3) ///
		star(* 0.10 ** 0.05 *** 0.01) ///
		mtitles("\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}" ///
		        "\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}" ///
		        "\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}") ///
		mgroups("$\pm 30$-Day Window" "$\pm 60$-Day Window" "$\pm 90$-Day Window", ///
		        pattern(1 0 1 0 1 0) prefix(\multicolumn{2}{c}{) suffix(}) span ///
		        erepeat(\cmidrule(lr){@span})) ///
		stats(p_mh_l p_mh_gt_l baseline N num_scandals r2, ///
		      label("p-value: Medium+High $$=$$ Low" "p-value: Medium+High $$>$$ Low (one-sided)" ///
		            "Mean (Pre-Scandal)" "Observations" "Number of Scandals" "R-squared") ///
		      fmt(3 3 3 0 0 3)) ///
		keep(post_medhigh post_low) ///
		coeflabels(post_medhigh "Post $\times$ Medium+High Democracy (2008)" ///
		           post_low     "Post $\times$ Low Democracy (2008)") ///
		substitute("$$" "$")
}

panelcombine, ///
	use("${tables}/g_democracy_corr_temp.tex" "${tables}/g_democracy_unrel_temp.tex") ///
	paneltitles("Corruption-related protests" "Unrelated to corruption") ///
	columncount(7) save("${tables}/g_democracy_panels.tex") cleanup

display in green "g_democracy_low_vs_medhigh.do finished OK"
