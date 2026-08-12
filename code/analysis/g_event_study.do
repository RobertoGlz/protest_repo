/* ----------------------------------------------------------------------------
   Grievance-split replication of Figure 1 (event-study dynamics, +-60d, 15-day
   bins), estimated separately on the Apex (pa) and Non-Apex (na) subsamples.

   Same four panels (violent/peaceful x Apex/Non-Apex), but each panel now
   OVERLAYS two grievance series:
       corruption-related : solid black line, circle markers
       unrelated          : short-dashed black!50 line, square markers
   A small horizontal dodge separates the two CI spikes. All four panels share
   a common y-axis (computed over all eight series).

   Output (paper/figures/): g_dynamics_{violent,peaceful}_{pa,na}.pdf
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
local zcrit     = invnormal(0.95)
local B = 15
local T = 60
local nb = `T'/`B'          /* 4 bins per side */

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
egen grupo_dias    = group(s_lag30 s_lag60 s_lag90 s_lag120 s_lead30 s_lead60 s_lead90 s_lead120)
egen group_cluster = group(country_id year grupo_dias)
egen auxvar        = group(country year)
tempfile base
save `base'

/* event-time dummies (bin -1 is the omitted reference) */
local esvars ""
forvalues j = `nb'(-1)2 {
	local esvars "`esvars' ebin_m`j'"
}
forvalues j = 1/`nb' {
	local esvars "`esvars' ebin_p`j'"
}

/* ============ PASS 1: common y-range over all 8 series ============ */
local ymin = 0
local ymax = 0
foreach sample in pa na {
foreach m in v p {
foreach cls in corr unrel {
	use `base', clear
	gen int ebin = .
	replace ebin =  floor(window/`B') + 1          if window >= 0
	replace ebin = -(floor((-window-1)/`B') + 1)   if window <  0
	forvalues j = 2/`nb' {
		gen byte ebin_m`j' = (ebin == -`j')
	}
	forvalues j = 1/`nb' {
		gen byte ebin_p`j' = (ebin ==  `j')
	}
	quietly reghdfe g`cls'_`m' `esvars' ///
		if year >= `firstyear' & abs(window) <= `T' & in_`sample' == 1, ///
		absorb(month day auxvar) cluster(group_cluster)
	foreach v of local esvars {
		local ymin = min(`ymin', _b[`v'] - `zcrit'*_se[`v'])
		local ymax = max(`ymax', _b[`v'] + `zcrit'*_se[`v'])
	}
}
}
}
local rng = `ymax' - `ymin'
if `rng' <= 0 local rng = 0.01
local ylo = `ymin' - 0.08*`rng'
local yhi = `ymax' + 0.08*`rng'
local raw = (`yhi' - `ylo')/6
local mag = 10 ^ floor(log10(`raw'))
local mult = `raw'/`mag'
if `mult' < 1.5      local step = 1  * `mag'
else if `mult' < 3.5 local step = 2  * `mag'
else if `mult' < 7.5 local step = 5  * `mag'
else                 local step = 10 * `mag'
local ylo_t = floor(`ylo'/`step')*`step'
local yhi_t = ceil( `yhi'/`step')*`step'

local xlabs "-60 -30 0 30 60"
local xpad   = 0.6*`B'
local xlo_ax = -`nb'*`B' - `xpad'
local xhi_ax =  `nb'*`B' + `xpad'
local dodge  = 1.8

/* ============ PASS 2: overlay corr + unrel in each panel ============ */
foreach sample in pa na {
foreach m in v p {
	if "`m'" == "v" local mlong "violent"
	else            local mlong "peaceful"

	matrix M = J(`=2*`nb'', 5, .)
	matrix colnames M = day bc sec bu seu
	local ic = 0
	foreach cls in corr unrel {
		local ++ic
		use `base', clear
		gen int ebin = .
		replace ebin =  floor(window/`B') + 1          if window >= 0
		replace ebin = -(floor((-window-1)/`B') + 1)   if window <  0
		forvalues j = 2/`nb' {
			gen byte ebin_m`j' = (ebin == -`j')
		}
		forvalues j = 1/`nb' {
			gen byte ebin_p`j' = (ebin ==  `j')
		}
		quietly reghdfe g`cls'_`m' `esvars' ///
			if year >= `firstyear' & abs(window) <= `T' & in_`sample' == 1, ///
			absorb(month day auxvar) cluster(group_cluster)
		local row = 0
		forvalues bi = -`nb'/`=`nb'-1' {
			local ++row
			if `ic' == 1 matrix M[`row', 1] = `bi'*`B'
			if `bi' == -1 {
				local bb = 0
				local ss = 0
			}
			else if `bi' <= -2 {
				local jj = -`bi'
				local bb = _b[ebin_m`jj']
				local ss = _se[ebin_m`jj']
			}
			else {
				local jj = `bi' + 1
				local bb = _b[ebin_p`jj']
				local ss = _se[ebin_p`jj']
			}
			matrix M[`row', `=2*`ic''] = `bb'
			matrix M[`row', `=2*`ic'+1'] = `ss'
		}
	}
	preserve
		clear
		svmat M, names(col)
		replace day = day + `B' if day >= 0
		gen bc_lo = bc - `zcrit'*sec
		gen bc_hi = bc + `zcrit'*sec
		gen bu_lo = bu - `zcrit'*seu
		gen bu_hi = bu + `zcrit'*seu
		gen day_c = day - `dodge'
		gen day_u = day + `dodge'
		twoway (rspike bc_lo bc_hi day_c, lcolor(black) lwidth(medthick)) ///
		       (scatter bc day_c, mcolor(black) msymbol(O) msize(medlarge)) ///
		       (rspike bu_lo bu_hi day_u, lcolor(black%45) lwidth(medthick) lpattern(shortdash)) ///
		       (scatter bu day_u, mcolor(black%45) msymbol(S) msize(medlarge)), ///
			xline(0, lcolor(black%10) lwidth(vvthick) lpattern(solid)) ///
			yline(0, lpattern(dash) lcolor(black)) ///
			ytitle("Effect on protests", size(large)) ///
			yscale(range(`ylo_t' `yhi_t')) ///
			ylabel(`ylo_t'(`step')`yhi_t', labsize(large) format(%5.3fc) angle(0)) ///
			xtitle("Days since scandal", size(large)) ///
			xscale(range(`xlo_ax' `xhi_ax')) ///
			xlabel(`xlabs', labsize(large)) ///
			graphregion(color(white) fcolor(white)) scheme(s2color) legend(off)
		graph export "${figout}/g_dynamics_`mlong'_`sample'.pdf", replace
	restore
}
}
display in green "g_event_study.do finished OK"
