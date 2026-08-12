/* ----------------------------------------------------------------------------
   Grievance-split replication of Table 1 (two-group interaction).

   Same 6-column layout as Table 1 (Violent/Peaceful x +-30/60/90), but TWO
   panels stacked by grievance class:
        Panel A: Corruption-related      (outcomes gcorr_v, gcorr_p)
        Panel B: Unrelated to corruption (outcomes gunrel_v, gunrel_p)
   Rows: Post x Apex, Post x Non-Apex, with the Apex=Non-Apex tests.

   Output (paper/tables/): g_interaction_panels.tex
   NOTE: run g_build_grievance_counts.do first (creates grievance_counts.dta).
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

/* ---- build the estimation base (panel + classification + grievance counts) ---- */
import delimited using "${datfin}/scandals_classified.csv", clear varnames(1) bindquotes(strict)
keep id country position
tempfile cls
save `cls'

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
capture confirm string variable id
if _rc==0 {
	drop if id == "TWNEWLATINO14" & country == "Ecuador"
	drop if id == "TWNEWLATINO23" & country == "Brazil"
}
merge m:1 id country using `cls', keep(1 3) nogenerate
merge m:1 country date using "${datfin}/grievance_counts.dta", keep(1 3) generate(_mg)
foreach v in gcorr_v gunrel_v gcorr_p gunrel_p {
	replace `v' = 0 if missing(`v')
}
gen byte in_pa = 0
replace in_pa = 1 if position == "president"
replace in_pa = 1 if position == "governor"
replace in_pa = 1 if position == "sc_judge_congressman" & inlist(id,"202","NEW26","NEW30","332")
gen byte in_na = 0
replace in_na = 1 if position == "sc_judge_congressman" & !inlist(id,"202","NEW26","NEW30","332")
replace in_na = 1 if position == "other_judiciary"
replace in_na = 1 if position == "others"
gen byte post_pa = post * in_pa
gen byte post_na = post * in_na
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
		eststo m`k': reghdfe `outcome' post_pa post_na i.month i.day ///
			if year >= `firstyear' & abs(window) <= `window' & (in_pa==1 | in_na==1), ///
			absorb($fe1) vce($CLUSTER2)
		quietly summarize `outcome' if e(sample) & window >= -`window' & window <= -1
		estadd scalar baseline = r(mean)
		quietly levelsof id if e(sample) == 1
		estadd scalar num_scandals = r(r)
		test post_pa = post_na
		local p2 = r(p)
		estadd scalar p_pa_na = `p2'
		quietly lincom post_pa - post_na
		if r(estimate) > 0 local p1 = `p2'/2
		else               local p1 = 1 - `p2'/2
		estadd scalar p_pa_gt_na = `p1'
	}
	esttab m1 m2 m3 m4 m5 m6 using "${tables}/g_interaction_`cls'_temp.tex", ///
		replace booktabs nonotes nogaps b(3) se(3) ///
		star(* 0.10 ** 0.05 *** 0.01) ///
		mtitles("\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}" ///
		        "\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}" ///
		        "\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}") ///
		mgroups("$\pm 30$-Day Window" "$\pm 60$-Day Window" "$\pm 90$-Day Window", ///
		        pattern(1 0 1 0 1 0) prefix(\multicolumn{2}{c}{) suffix(}) span ///
		        erepeat(\cmidrule(lr){@span})) ///
		stats(p_pa_na p_pa_gt_na baseline N num_scandals r2, ///
		      label("p-value: Apex $$=$$ Non-Apex" "p-value: Apex $$>$$ Non-Apex (one-sided)" ///
		            "Mean (Pre-Scandal)" "Observations" "Number of Scandals" "R-squared") ///
		      fmt(3 3 3 0 0 3)) ///
		keep(post_pa post_na) ///
		coeflabels(post_pa "Post $\times$ Apex" post_na "Post $\times$ Non-Apex") ///
		substitute("$$" "$")
}

panelcombine, ///
	use("${tables}/g_interaction_corr_temp.tex" "${tables}/g_interaction_unrel_temp.tex") ///
	paneltitles("Corruption-related protests" "Unrelated to corruption") ///
	columncount(7) save("${tables}/g_interaction_panels.tex") cleanup

display in green "g_interaction_pa_vs_na.do finished OK"
