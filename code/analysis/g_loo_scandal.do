/* ----------------------------------------------------------------------------
   Grievance-split leave-one-out-by-scandal robustness.

   Re-estimate the two-group interaction (Post x Apex, Post x Non-Apex) on each
   of the four grievance outcomes, dropping one scandal's event window at a time
   (+-30-day window). One plot per (group, outcome).

   SCALE: all four VIOLENT panels share one common y-axis, and all four PEACEFUL
   panels share another; every panel uses the same physical width. Estimates are
   computed once and stored, so the common ranges are exact.

   Output (paper/figures/): g_loo_{apex,nonapex}_{gcorr_v,gunrel_v,gcorr_p,gunrel_p}.pdf
   NOTE: run g_build_grievance_counts.do first.
---------------------------------------------------------------------------- */
set more off
clear all
if "`c(username)'" == "rob98" global identity "~/Dropbox"
if "`c(username)'" == "Rob_9" global identity "C:/Users/Rob_9/Dropbox"
global path    "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin  "${path}/Data/final"
global figout  "${identity}/Corrupcion/protest_repo/paper/figures"
local firstyear = 2008
local WIN       = 30
local zcrit     = invnormal(0.95)

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
merge m:1 id country using `cls', keep(1 3) generate(_mclass)
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
gen int _sy = year if window == 0
bysort country id: egen scanyear = max(_sy)
gen double _sd2 = date if window == 0
bysort country id: egen double scandate = max(_sd2)
drop _sy _sd2
preserve
	keep country id scandate scanyear
	duplicates drop
	bysort country scanyear (scandate id): gen int cyrank = _n
	bysort country scanyear: gen int cycount = _N
	keep country id cyrank cycount
	tempfile ord
	save `ord'
restore
merge m:1 country id using `ord', nogenerate
tempfile base
save `base'

/* ============ PASS 1: estimate all LOO betas, store to a master file ============ */
tempname M
tempfile master
postfile `M' str8 outcome str8 grp int sid double est double se str48 lab using `master', replace
local maxNS = 0
foreach OUTCOME in gcorr_v gunrel_v gcorr_p gunrel_p {
	use `base', clear
	reghdfe `OUTCOME' post_pa post_na i.month i.day ///
		if year >= `firstyear' & abs(window) <= `WIN' & (in_pa==1 | in_na==1), ///
		absorb(i.country_id#i.year) vce(cluster i.country_id#i.year#i.grupo_dias)
	scalar bf_`OUTCOME'_apex    = _b[post_pa]
	scalar bf_`OUTCOME'_nonapex = _b[post_na]
	foreach grp in apex nonapex {
		if "`grp'" == "apex" {
			local coef "post_pa"
			local mem  "in_pa == 1"
		}
		else {
			local coef "post_na"
			local mem  "in_na == 1"
		}
		local IF "year >= `firstyear' & abs(window) <= `WIN' & (in_pa==1 | in_na==1)"
		use `base', clear
		keep if `IF' & `mem'
		keep country id scanyear cyrank cycount
		duplicates drop
		sort country id
		local NS = _N
		local maxNS = max(`maxNS', `NS')
		forvalues i = 1/`NS' {
			local ctry`i' = country[`i']
			local idv`i'  = id[`i']
			local yr`i'   = scanyear[`i']
			local cyr`i'  = cyrank[`i']
			local cyc`i'  = cycount[`i']
		}
		use `base', clear
		forvalues i = 1/`NS' {
			local c "`ctry`i''"
			local s "`idv`i''"
			capture reghdfe `OUTCOME' post_pa post_na i.month i.day ///
				if `IF' & !(country == "`c'" & id == "`s'"), ///
				absorb(i.country_id#i.year) vce(cluster i.country_id#i.year#i.grupo_dias)
			if _rc continue
			if `cyc`i'' > 1 local lab "`ctry`i'' - `yr`i'' - `cyr`i''"
			else            local lab "`ctry`i'' - `yr`i''"
			post `M' ("`OUTCOME'") ("`grp'") (`i') (_b[`coef']) (_se[`coef']) ("`lab'")
		}
	}
}
postclose `M'

/* ============ common y-range per margin (violent / peaceful) ============ */
use `master', clear
gen double lo = est - `zcrit'*se
gen double hi = est + `zcrit'*se
gen str1 mg = "v" if inlist(outcome,"gcorr_v","gunrel_v")
replace   mg = "p" if inlist(outcome,"gcorr_p","gunrel_p")
foreach m in v p {
	if "`m'" == "v" local ocs "gcorr_v gunrel_v"
	else            local ocs "gcorr_p gunrel_p"
	quietly summarize lo if mg == "`m'"
	local rmin = min(r(min), 0)
	quietly summarize hi if mg == "`m'"
	local rmax = r(max)
	foreach oc of local ocs {
		foreach grp in apex nonapex {
			local rmin = min(`rmin', bf_`oc'_`grp')
			local rmax = max(`rmax', bf_`oc'_`grp')
		}
	}
	local pad = 0.05*(`rmax'-`rmin')
	local rlo = `rmin'-`pad'
	local rhi = `rmax'+`pad'
	local raw = (`rhi'-`rlo')/7
	local mag = 10 ^ floor(log10(`raw'))
	local mult = `raw'/`mag'
	if `mult' < 1.5      local step = 1  * `mag'
	else if `mult' < 3.5 local step = 2  * `mag'
	else if `mult' < 7.5 local step = 5  * `mag'
	else                 local step = 10 * `mag'
	local ylo_`m'  = floor(`rlo'/`step')*`step'
	local yhi_`m'  = ceil( `rhi'/`step')*`step'
	local step_`m' = `step'
}
local wd = max(13, `maxNS' * 0.13)

/* ============ PASS 2: plot each panel on its margin's common scale ============ */
foreach OUTCOME in gcorr_v gunrel_v gcorr_p gunrel_p {
	if inlist("`OUTCOME'","gcorr_v","gunrel_v") local m "v"
	else                                        local m "p"
	foreach grp in apex nonapex {
		use `master', clear
		keep if outcome == "`OUTCOME'" & grp == "`grp'"
		gen double lo = est - `zcrit'*se
		gen double hi = est + `zcrit'*se
		gsort est
		gen int rank = _n
		capture label drop rlab
		forvalues i = 1/`=_N' {
			local L = lab[`i']
			label define rlab `i' "`L'", add
		}
		label values rank rlab
		twoway (rspike lo hi rank, lcolor(gs8) lwidth(thin)) ///
		       (scatter est rank, mcolor(navy) msymbol(O) msize(small)), ///
			yline(0, lcolor(black%10) lwidth(vvthick) lpattern(solid)) ///
			yline(`=bf_`OUTCOME'_`grp'', lcolor(red) lwidth(medthick) lpattern(solid)) ///
			yscale(range(`ylo_`m'' `yhi_`m'')) ///
			ylabel(`ylo_`m''(`step_`m'')`yhi_`m'', angle(horizontal) format(%4.3fc)) ///
			ytitle("Leave-one-out estimate", size(medium)) xtitle("") ///
			xlabel(1(1)`=_N', valuelabel labsize(tiny) angle(90) nogrid) ///
			xscale(range(0 `=_N+1')) legend(off) ///
			note("Red line: coefficient estimated on all scandals.", size(small)) ///
			graphregion(color(white) fcolor(white)) scheme(s2color) ///
			xsize(`wd') ysize(4.3)
		graph export "${figout}/g_loo_`grp'_`OUTCOME'.pdf", replace
		di as green "wrote g_loo_`grp'_`OUTCOME'.pdf"
	}
}
display in green "g_loo_scandal.do finished OK"
