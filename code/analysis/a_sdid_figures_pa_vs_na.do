/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-08-03

    Objective:
        Diagnostic figures for the stacked synthetic difference-in-differences
        (a_sdid_stacked_pa_vs_na.do), now for BOTH partitions (apex / non-apex)
        and BOTH outcomes (violent / peaceful protests), at the +-30/60/90-day
        windows and at several temporal resolutions (daily and pooled into 5-,
        10- and 15-day bins; 15-day bins match the main-text event studies):

          (A) sdid_trends_<samp>_<out>_w<K>_b<B>.pdf
              Observed treated trajectory, the synthetic control as estimated,
              and the synthetic shifted up by its pre-scandal DiD intercept.

          (B) sdid_placebo_<samp>_<out>_w<K>_b<B>.pdf
              In-space placebo / permutation: each donor country is re-treated
              as a placebo; gray lines are donor-country average placebo gaps,
              red is the true treated gap, a black line marks the zero gap.

        <samp> in {apex, nonapex}; <out> in {violent, peaceful}.  Bin centres are
        exact multiples of B (points on 0, +-B, ... reaching the window edges).

    Requires: sdid  (ssc install sdid)
    Inputs:  scandals_classified.csv, protests_scandals_30days_v3.dta,
             panel_country_day.dta
    Outputs: paper/figures/sdid_{trends,placebo}_{apex,nonapex}_{violent,peaceful}_w{30,60,90}_b{1,5,10,15}.pdf
---------------------------------------------------------------------------- */

set more off
clear all

capture which sdid
if _rc ssc install sdid, replace

if "`c(username)'" == "lalov" {
	gl identity "C:\Users\lalov\ITAM Seira Research Dropbox\Eduardo Rivera"
}
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox"
}
if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}

global path    "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin  "${path}/Data/final"
global figout  "${identity}/Corrupcion/protest_repo/paper/figures"

local KMAX = 90

/* ---- scandal list with dates + apex/non-apex membership ---- */
import delimited using "${datfin}/scandals_classified.csv", ///
	clear varnames(1) bindquotes(strict)
keep id country position
tempfile cls
save `cls'
use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
merge m:1 id country using `cls', keep(3) nogenerate
gen byte in_pa = inlist(position,"president","governor") | ///
	(position=="sc_judge_congressman" & inlist(id,"202","NEW26","NEW30","332"))
gen byte in_na = (position=="sc_judge_congressman" & !inlist(id,"202","NEW26","NEW30","332")) | ///
	inlist(position,"other_judiciary","others")
gen double _sd = date if window==0
bysort country id: egen double scandate = max(_sd)
keep country id scandate in_pa in_na
duplicates drop
drop if missing(scandate)
gsort scandate country id
quietly summarize scandate
local dlo = r(min) - `KMAX' - 10
local dhi = r(max) + `KMAX' + 10
/* stash scandal attributes by membership */
foreach s in pa na {
	preserve
		keep if in_`s' == 1
		local NS_`s' = _N
		forvalues i = 1/`=_N' {
			local c_`s'`i' = country[`i']
			local t_`s'`i' = scandate[`i']
		}
	restore
}

/* ---- daily panel ---- */
use "${datfin}/panel_country_day", clear
drop if country == "Venezuela"
keep if inrange(date, `dlo', `dhi')
keep country date mm_violent mm_nonviolent scandal_today
tempfile daily
save `daily'

/* ============================================================
   STEP 1 - fits per (sample x outcome x window), saved so the figures can be
   rebuilt without re-fitting.  Set REFIT=1 to force the fits.
   ============================================================ */
local REFIT = 0
local dofit = `REFIT'
foreach samp in pa na {
foreach out in violent peaceful {
foreach K of numlist 30 60 90 {
	capture confirm file "${datfin}/sdid_fig_series_`samp'_`out'_w`K'.dta"
	if _rc local dofit = 1
	capture confirm file "${datfin}/sdid_fig_gaps_`samp'_`out'_w`K'.dta"
	if _rc local dofit = 1
}
}
}

if `dofit' {
foreach samp in pa na {
foreach out in violent peaceful {
	local OC = cond("`out'"=="violent","mm_violent","mm_nonviolent")
foreach K of numlist 30 60 90 {
	tempname SER GAP
	tempfile ser gap
	postfile `SER' int sid int tvar double obs double syn using "`ser'", replace
	postfile `GAP' int sid str24 who int tvar double g using "`gap'", replace

	forvalues i = 1/`NS_`samp'' {
		local ct "`c_`samp'`i''"
		local t0 = `t_`samp'`i''

		use `daily', clear
		keep if inrange(date, `t0'-`K', `t0'+`K')
		gen byte _pre = (scandal_today==1) & (date < `t0')
		bysort country: egen byte _haspre = max(_pre)
		keep if country=="`ct'" | _haspre==0
		bysort country: gen int _nd = _N
		keep if _nd == `=2*`K'+1'
		quietly count if country=="`ct'"
		if r(N)==0 continue
		quietly levelsof country, local(cc)
		if `: word count `cc'' < 3 continue

		gen int  tvar  = date - `t0'
		gen byte treat = (country=="`ct'") & (tvar>=0)
		egen uid = group(country)

		capture sdid `OC' uid tvar treat, method(sdid) vce(noinference)
		if _rc continue
		matrix Sr = e(series)
		matrix Dr = e(difference)
		local nr = rowsof(Sr)
		forvalues r = 1/`nr' {
			post `SER' (`i') (`=Sr[`r',1]') (`=Sr[`r',3]') (`=Sr[`r',2]')
			post `GAP' (`i') ("TREATED") (`=Dr[`r',1]') (`=Dr[`r',2]')
		}
		drop treat uid
		drop if country=="`ct'"
		quietly levelsof country, local(dons)
		foreach d of local dons {
			gen byte treat = (country=="`d'") & (tvar>=0)
			egen uid = group(country)
			capture sdid `OC' uid tvar treat, method(sdid) vce(noinference)
			if !_rc {
				matrix Dd = e(difference)
				local nd = rowsof(Dd)
				forvalues r = 1/`nd' {
					post `GAP' (`i') ("`d'") (`=Dd[`r',1]') (`=Dd[`r',2]')
				}
			}
			drop treat uid
		}
	}
	postclose `SER'
	postclose `GAP'
	use "`ser'", clear
	save "${datfin}/sdid_fig_series_`samp'_`out'_w`K'.dta", replace
	use "`gap'", clear
	save "${datfin}/sdid_fig_gaps_`samp'_`out'_w`K'.dta", replace
	di as result "fits done: `samp' `out' w`K'"
}
}
}
}

/* ============================================================
   STEP 2a - common y-scale per (outcome x bin), pooled across the apex/non-apex
   partitions AND the +-30/60/90 windows, so every panel that appears together in
   a figure (and the apex vs non-apex figures side by side) shares one axis.
   Trends: anchored at 0 (daily counts).  Placebo: symmetric about 0 (demeaned
   gap).  A separate scale per bin resolution B, since coarser bins are smoother.
   ============================================================ */
foreach out in violent peaceful {
foreach B of numlist 1 5 10 15 {
	local TRlo_`out'_`B' =  1e9
	local TRhi_`out'_`B' = -1e9
	local PLm_`out'_`B'  =  0
}
}
foreach samp in pa na {
foreach out in violent peaceful {
foreach K of numlist 30 60 90 {
foreach B of numlist 1 5 10 15 {
	/* trends span: obs, syn, shifted-syn */
	use "${datfin}/sdid_fig_series_`samp'_`out'_w`K'.dta", clear
	gen double _d = obs - syn if tvar < 0
	bysort sid: egen double _off = mean(_d)
	gen double synsh = syn + _off
	gen double tbin = round(tvar/`B')*`B'
	collapse (mean) obs syn synsh, by(tbin)
	foreach v in obs syn synsh {
		quietly summarize `v'
		if r(min) < `TRlo_`out'_`B'' local TRlo_`out'_`B' = r(min)
		if r(max) > `TRhi_`out'_`B'' local TRhi_`out'_`B' = r(max)
	}
	/* placebo span: all donor + treated demeaned gaps */
	use "${datfin}/sdid_fig_gaps_`samp'_`out'_w`K'.dta", clear
	gen double _preg = g if tvar<0
	bysort sid who: egen double pregap = mean(_preg)
	replace g = g - pregap
	gen double tbin = round(tvar/`B')*`B'
	collapse (mean) g, by(who tbin)
	quietly summarize g
	local amax = max(abs(r(min)), abs(r(max)))
	if `amax' > `PLm_`out'_`B'' local PLm_`out'_`B' = `amax'
}
}
}
}
/* turn the raw spans into nice, identical tick sets (<= ~6 intervals) */
foreach out in violent peaceful {
foreach B of numlist 1 5 10 15 {
	/* trends: floor at 0, round out to nice bounds */
	local lo = min(0, `TRlo_`out'_`B'')
	local hi = `TRhi_`out'_`B''
	local span = `hi' - `lo'
	local step = 10
	foreach cand of numlist .02 .05 .1 .2 .25 .5 1 2 2.5 5 10 {
		local step = `cand'
		if `span'/`cand' <= 6 continue, break
	}
	local ylo = floor(`lo'/`step')*`step'
	local yhi =  ceil(`hi'/`step')*`step'
	local TRlab_`out'_`B' "`ylo'(`step')`yhi'"
	local TRr_`out'_`B'   "`ylo' `yhi'"
	/* placebo: symmetric about 0 */
	local M = `PLm_`out'_`B''
	local span = 2*`M'
	local step = 10
	foreach cand of numlist .02 .05 .1 .2 .25 .5 1 2 2.5 5 10 {
		local step = `cand'
		if `span'/`cand' <= 6 continue, break
	}
	local yhi = ceil(`M'/`step')*`step'
	local PLlab_`out'_`B' "-`yhi'(`step')`yhi'"
	local PLr_`out'_`B'   "-`yhi' `yhi'"
}
}

/* ============================================================
   STEP 2b - figures per (sample x outcome x window x bin), on the common scale
   ============================================================ */
foreach samp in pa na {
	local slab = cond("`samp'"=="pa","apex","nonapex")
foreach out in violent peaceful {
	local ylab = cond("`out'"=="violent","Violent protests (daily count)","Peaceful protests (daily count)")
foreach K of numlist 30 60 90 {
	local xs = `K'/3
foreach B of numlist 1 5 10 15 {

	/* ---- FIGURE A: observed vs synthetic (+ shifted) ---- */
	use "${datfin}/sdid_fig_series_`samp'_`out'_w`K'.dta", clear
	gen double _d = obs - syn if tvar < 0
	bysort sid: egen double _off = mean(_d)
	gen double synsh = syn + _off
	drop _d _off
	gen double tbin = round(tvar/`B')*`B'
	collapse (mean) obs syn synsh, by(tbin)
	twoway (line obs   tbin, lcolor(cranberry) lwidth(medthick)) ///
	       (line syn   tbin, lcolor(navy) lwidth(medthick) lpattern(dash)) ///
	       (line synsh tbin, lcolor(forest_green) lwidth(medthick) lpattern(shortdash)), ///
		xline(0, lcolor(black%30) lwidth(medthick)) ///
		ytitle("`ylab'", size(medium)) ///
		xtitle("Days since scandal", size(medium)) ///
		xlabel(-`K'(`xs')`K') ///
		ylabel(`TRlab_`out'_`B'', angle(0) labsize(medsmall)) ///
		yscale(range(`TRr_`out'_`B'')) ///
		legend(off) ///
		graphregion(color(white) fcolor(white)) scheme(s2color)
	graph export "${figout}/sdid_trends_`slab'_`out'_w`K'_b`B'.pdf", replace

	/* ---- FIGURE B: in-space placebo permutation (gap, demeaned) ---- */
	use "${datfin}/sdid_fig_gaps_`samp'_`out'_w`K'.dta", clear
	gen double _preg = g if tvar<0
	bysort sid who: egen double pregap = mean(_preg)
	replace g = g - pregap
	drop _preg pregap
	collapse (mean) g, by(who tvar)
	gen double tbin = round(tvar/`B')*`B'
	collapse (mean) g, by(who tbin)
	gen byte istreat = who=="TREATED"
	levelsof who if istreat==0, local(dons)
	local ndon : word count `dons'
	local redlayer = `ndon' + 1
	local pc ""
	foreach d of local dons {
		local pc `"`pc' (line g tbin if who=="`d'", lcolor(gs11) lwidth(vthin))"'
	}
	sort who tbin
	twoway `pc' ///
	       (line g tbin if istreat, lcolor(cranberry) lwidth(thick)), ///
		yline(0, lcolor(black) lwidth(medthick)) ///
		xline(0, lcolor(black%30) lwidth(medthick)) ///
		ytitle("Gap: treated {&minus} synthetic (demeaned)", size(medium)) ///
		xtitle("Days since scandal", size(medium)) ///
		xlabel(-`K'(`xs')`K') ///
		ylabel(`PLlab_`out'_`B'', angle(0) labsize(medsmall)) ///
		yscale(range(`PLr_`out'_`B'')) ///
		legend(off) ///
		graphregion(color(white) fcolor(white)) scheme(s2color)
	graph export "${figout}/sdid_placebo_`slab'_`out'_w`K'_b`B'.pdf", replace
}
}
}
	di as result "figures done: `slab'"
}

display in green "a_sdid_figures_pa_vs_na.do finished OK"
