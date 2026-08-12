/* ----------------------------------------------------------------------------
   Grievance-split replication of Table 2 (benchmarks).

   Same 6-column layout (Violent/Peaceful x +-30/60/90). The Apex and Non-Apex
   samples are each split by grievance class, giving six panels:
        A: Apex -- Corruption-related        B: Apex -- Unrelated
        C: Non-Apex -- Corruption-related    D: Non-Apex -- Unrelated
        E: Football match losses             F: Currency depreciations
   (Panels E/F use the total protest counts, as in the paper.) OLS only.

   Output (paper/tables/): g_benchmarks_panels.tex
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

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"
local firstyear = 2008
local win_list  "30 30 60 60 90 90"

import delimited using "${datfin}/scandals_classified.csv", clear varnames(1) bindquotes(strict)
keep id country position
tempfile cls
save `cls'

foreach p in apexcorr apexunrel nacorr naunrel football deprec {

	if inlist("`p'","apexcorr","apexunrel","nacorr","naunrel") {
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
		if inlist("`p'","apexcorr","apexunrel") local flag "in_pa"
		else                                    local flag "in_na"
		if inlist("`p'","apexcorr","nacorr") {
			local ov "gcorr_v"
			local op "gcorr_p"
		}
		else {
			local ov "gunrel_v"
			local op "gunrel_p"
		}
	}
	else {
		if "`p'" == "football" use "${datfin}/protests_scandals_30days_football_v3", clear
		else                   use "${datfin}/protests_scandals_30days_depreciation_v3", clear
		drop if country == "Venezuela"
		capture confirm string variable id
		if _rc==0 {
			drop if id == "TWNEWLATINO14" & country == "Ecuador"
			drop if id == "TWNEWLATINO23" & country == "Brazil"
		}
		gen byte keepall = 1
		local flag "keepall"
		local ov "num_violent_MM"
		local op "num_peaceful_MM"
	}

	egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 s_lead30 s_lead60 s_lead90 s_lead120)
	tempfile pdata
	save `pdata'

	local out_list "`ov' `op' `ov' `op' `ov' `op'"
	eststo clear
	forvalues k = 1/6 {
		local outcome : word `k' of `out_list'
		local window  : word `k' of `win_list'
		use `pdata', clear
		eststo m`k': reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear' & abs(window) <= `window' & `flag' == 1, ///
			absorb($fe1) vce($CLUSTER2)
		quietly summarize `outcome' if e(sample) & window >= -`window' & window <= -1
		estadd scalar baseline = r(mean)
		capture quietly levelsof id if e(sample) == 1
		if _rc == 0 estadd scalar num_events = r(r)
	}
	esttab m1 m2 m3 m4 m5 m6 using "${tables}/bench_g_`p'_temp.tex", ///
		replace booktabs nonotes nogaps b(3) se(3) ///
		star(* 0.10 ** 0.05 *** 0.01) ///
		mtitles("\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}" ///
		        "\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}" ///
		        "\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}") ///
		mgroups("$\pm 30$-Day Window" "$\pm 60$-Day Window" "$\pm 90$-Day Window", ///
		        pattern(1 0 1 0 1 0) prefix(\multicolumn{2}{c}{) suffix(}) span ///
		        erepeat(\cmidrule(lr){@span})) ///
		stats(baseline N num_events r2, ///
		      label("Mean (Pre-Event)" "Observations" "Number of Events" "R-squared") ///
		      fmt(3 0 0 3)) ///
		keep(post) coeflabels(post "Post Event")
}

panelcombine, ///
	use("${tables}/bench_g_apexcorr_temp.tex" "${tables}/bench_g_apexunrel_temp.tex" ///
	    "${tables}/bench_g_nacorr_temp.tex"   "${tables}/bench_g_naunrel_temp.tex" ///
	    "${tables}/bench_g_football_temp.tex" "${tables}/bench_g_deprec_temp.tex") ///
	paneltitles("Apex -- Corruption-related" "Apex -- Unrelated" ///
	            "Non-Apex -- Corruption-related" "Non-Apex -- Unrelated" ///
	            "Football match losses" "Currency depreciations") ///
	columncount(7) save("${tables}/g_benchmarks_panels.tex") cleanup

display in green "g_benchmarks.do finished OK"
