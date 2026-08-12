/* ----------------------------------------------------------------------------
   Grievance-split replication of the window-sensitivity figure.

   For each (subsample x margin) panel -- Apex/Non-Apex x violent/peaceful --
   overlay the point estimate vs. event-window width T for the two grievance
   classes:
       corruption-related : solid black line + circle markers
       unrelated          : short-dashed black!50 line + square markers
   OLS only. Panels share a common y-axis.

   Output (paper/figures/): g_window_{violent,peaceful}_{pa,na}.pdf
   NOTE: run g_build_grievance_counts.do first.
---------------------------------------------------------------------------- */
set more off
clear all
if "`c(username)'" == "rob98" global identity "~/Dropbox"
if "`c(username)'" == "Rob_9" global identity "C:/Users/Rob_9/Dropbox"
global path    "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin  "${path}/Data/final"
global figout  "${identity}/Corrupcion/protest_repo/paper/figures"

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
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 s_lead30 s_lead60 s_lead90 s_lead120)
global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"
local firstyear = 2008
tempfile base
save `base'

tempfile res
postfile P str8 sample str8 cls str8 margin int T double beta double se using `res', replace
foreach sample in pa na {
foreach margin in v p {
foreach cls in corr unrel {
foreach T of numlist 15(15)150 {
	use `base', clear
	capture reghdfe g`cls'_`margin' post i.month i.day ///
		if year >= `firstyear' & abs(window) <= `T' & in_`sample' == 1, ///
		absorb($fe1) vce($CLUSTER2)
	if _rc == 0 & !missing(_b[post]) post P ("`sample'") ("`cls'") ("`margin'") (`T') (_b[post]) (_se[post])
}
}
}
}
postclose P

use `res', clear
local zcrit = invnormal(0.95)
gen double ci_lo = beta - `zcrit'*se
gen double ci_hi = beta + `zcrit'*se
tempfile allests
save `allests'

/* common y-range across all series */
quietly summarize ci_lo
local ymin = min(r(min), 0)
quietly summarize ci_hi
local ymax = max(r(max), 0)
local pad = 0.10*(`ymax'-`ymin')
local ylo = `ymin'-`pad'
local yhi = `ymax'+`pad'
local raw = (`yhi'-`ylo')/6
local mag = 10 ^ floor(log10(`raw'))
local mult = `raw'/`mag'
if `mult' < 1.5      local step = 1  * `mag'
else if `mult' < 3.5 local step = 2  * `mag'
else if `mult' < 7.5 local step = 5  * `mag'
else                 local step = 10 * `mag'
local ylo_t = floor(`ylo'/`step')*`step'
local yhi_t = ceil( `yhi'/`step')*`step'

foreach sample in pa na {
foreach margin in v p {
	if "`margin'" == "v" local outlbl "violent protests"
	if "`margin'" == "v" local mlong  "violent"
	if "`margin'" == "p" local outlbl "peaceful protests"
	if "`margin'" == "p" local mlong  "peaceful"
	preserve
		use `allests', clear
		keep if sample == "`sample'" & margin == "`margin'"
		gen double Tc = T - 1.8
		gen double Tu = T + 1.8
		twoway (rcap ci_lo ci_hi Tc if cls=="corr",  lcolor(black)    lwidth(thin)) ///
		       (line beta Tc if cls=="corr",         lcolor(black)    lwidth(medium)) ///
		       (scatter beta Tc if cls=="corr",      msymbol(O) mcolor(black)    msize(medium)) ///
		       (rcap ci_lo ci_hi Tu if cls=="unrel", lcolor(black%45) lwidth(thin) lpattern(shortdash)) ///
		       (line beta Tu if cls=="unrel",        lcolor(black%45) lwidth(medium) lpattern(shortdash)) ///
		       (scatter beta Tu if cls=="unrel",     msymbol(S) mcolor(black%45) msize(medium)), ///
			yline(0, lcolor(black%10) lwidth(vvthick) lpattern(solid)) ///
			xlabel(15(15)150) ///
			xtitle("Event-window width (days)", size(medium)) ///
			ytitle("Effect on `outlbl'", size(medium)) ///
			ylabel(`ylo_t'(`step')`yhi_t', format(%5.3f) angle(0)) ///
			yscale(range(`ylo_t' `yhi_t')) ///
			scheme(s2color) graphregion(color(white)) legend(off)
		graph export "${figout}/g_window_`mlong'_`sample'.pdf", replace
	restore
}
}
display in green "g_window_sensitivity.do finished OK"
