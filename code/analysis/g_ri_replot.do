/* ----------------------------------------------------------------------------
   Re-draw the grievance-split randomization-inference histograms on a COMMON
   x-axis per grievance outcome (the six Apex/Non-Apex x +-30/60/90 panels of
   each RI figure share one scale). Reads the saved placebo distributions from
   g_randomization_inference.do -- no re-permutation. Observed betas are
   recomputed from the event-window panel (fast).

   Output (paper/figures/): g_ri_hist_<outcome>_w<T>_<sample>.pdf  (overwritten)
---------------------------------------------------------------------------- */
set more off
clear all
if "`c(username)'" == "rob98" global identity "~/Dropbox"
if "`c(username)'" == "Rob_9" global identity "C:/Users/Rob_9/Dropbox"
global path    "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin  "${path}/Data/final"
global resout  "${identity}/Corrupcion/Protest_Work/results"
global figout  "${identity}/Corrupcion/protest_repo/paper/figures"
local firstyear = 2008

/* event-window panel with grievance counts + apex flags (for observed betas) */
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
tempfile obs_panel
save `obs_panel'

foreach outcome in gcorr_v gunrel_v gcorr_p gunrel_p {

	if "`outcome'" == "gcorr_v"  local outlbl "corruption-related violent protests"
	if "`outcome'" == "gunrel_v" local outlbl "unrelated violent protests"
	if "`outcome'" == "gcorr_p"  local outlbl "corruption-related peaceful protests"
	if "`outcome'" == "gunrel_p" local outlbl "unrelated peaceful protests"

	/* ---- PASS 1: observed betas + placebo ranges -> common x-range ---- */
	local xmn = 0
	local xmx = 0
	foreach sample in pa na {
	foreach T in 30 60 90 {
		use `obs_panel', clear
		quietly reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear' & abs(window) <= `T' & in_`sample' == 1, ///
			absorb(i.country_id#i.year) vce(cluster i.country_id#i.year#i.grupo_dias)
		scalar ob_`outcome'_`sample'_`T' = _b[post]
		use "${resout}/g_ri_beta_`outcome'_w`T'_`sample'.dta", clear
		quietly summarize beta_placebo
		local xmn = min(`xmn', r(min), ob_`outcome'_`sample'_`T')
		local xmx = max(`xmx', r(max), ob_`outcome'_`sample'_`T')
	}
	}
	local xrng = `xmx' - `xmn'
	if `xrng' <= 0 local xrng = 0.01
	local xlo = `xmn' - 0.08*`xrng'
	local xhi = `xmx' + 0.08*`xrng'
	local xraw = (`xhi' - `xlo')/5
	local xmag = 10 ^ floor(log10(`xraw'))
	local xmul = `xraw'/`xmag'
	if `xmul' < 1.5      local xstep = 1  * `xmag'
	else if `xmul' < 3.5 local xstep = 2  * `xmag'
	else if `xmul' < 7.5 local xstep = 5  * `xmag'
	else                 local xstep = 10 * `xmag'
	local xlo_t = floor(`xlo'/`xstep')*`xstep'
	local xhi_t = ceil( `xhi'/`xstep')*`xstep'

	/* ---- PASS 2: redraw each panel on the common x-range ---- */
	foreach sample in pa na {
	foreach T in 30 60 90 {
		use "${resout}/g_ri_beta_`outcome'_w`T'_`sample'.dta", clear
		local obeta = ob_`outcome'_`sample'_`T'
		quietly count if !missing(beta_placebo)
		local nvalid = r(N)
		quietly count if !missing(beta_placebo) & abs(beta_placebo) >= abs(`obeta')
		local ri_p = r(N)/`nvalid'
		local obs_str = string(`obeta', "%5.3f")
		local p2_str  = string(`ri_p',  "%5.3f")

		gen double _leg_beta = .
		gen double _leg_p    = .
		quietly summarize beta_placebo
		local _bmin = r(min)
		local _bw   = (r(max) - r(min))/50
		if `_bw' <= 0 local _bw = 1
		capture drop _rbin _rbc
		gen double _rbin = min(floor((beta_placebo - `_bmin')/`_bw'), 49)
		quietly count
		local _N = r(N)
		bysort _rbin: gen long _rbc = _N
		quietly summarize _rbc
		local _ymax = 100 * r(max)/`_N' * 1.04

		twoway (histogram beta_placebo, percent bin(50) color(gs13) lcolor(gs10)) ///
		       (line _leg_beta beta_placebo, lcolor("128 0 0") lwidth(medthick)) ///
		       (line _leg_p    beta_placebo, lcolor(none)) ///
		       (pci 0 `obeta' `_ymax' `obeta', lcolor("128 0 0") lwidth(medthick)), ///
			xline(0, lcolor(black) lwidth(vthin) lpattern(dot)) ///
			xtitle("Effect on `outlbl'", size(medium)) ytitle("Percent", size(medium)) ///
			xscale(range(`xlo_t' `xhi_t')) ///
			xlabel(`xlo_t'(`xstep')`xhi_t', format(%5.3f) labsize(small)) ///
			ylabel(, angle(0) format(%3.0f)) ///
			legend(order(2 3) label(2 "Observed {&beta} = `obs_str'") label(3 "RI p = `p2_str'") ///
			       cols(1) pos(2) ring(0) region(lcolor(black) fcolor(white)) size(medsmall)) ///
			scheme(s2color) graphregion(color(white))
		graph export "${figout}/g_ri_hist_`outcome'_w`T'_`sample'.pdf", replace
	}
	}
	di as green "redrew RI histograms for `outcome' on common scale"
}
display in green "g_ri_replot.do finished OK"
