/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-08-03

    Objective:
        Diagnostic figures for the stacked synthetic difference-in-differences
        of a_sdid_stacked_pa_vs_na.do, for the headline case (apex scandals,
        violent protests), at the +-30/60/90-day windows and at three temporal
        resolutions (daily, and pooled into 5- and 10-day bins, to smooth):

          (A) sdid_trends_apex_violent_w<K>_b<B>.pdf
              Observed treated trajectory, the synthetic control as estimated,
              and the synthetic shifted up by its pre-scandal DiD intercept
              (aligned to the observed pre-period), averaged across apex scandals.

          (B) sdid_placebo_apex_violent_w<K>_b<B>.pdf
              In-space placebo / permutation: each donor country is re-treated
              as a placebo (synthetic rebuilt from the remaining donors); gray
              lines are donor-country average placebo gaps, red is the true apex
              gap.  A black medthick line marks the zero gap.

    Requires: sdid  (ssc install sdid)

    Inputs:
        - ${datfin}/scandals_classified.csv
        - ${datfin}/protests_scandals_30days_v3.dta
        - ${datfin}/panel_country_day.dta
    Outputs (paper/figures/): sdid_{trends,placebo}_apex_violent_w{30,60,90}_b{1,5,10}.pdf
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

local OC   = "mm_violent"
local KMAX = 90

/* ---- apex scandal list with dates ---- */
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
gen double _sd = date if window==0
bysort country id: egen double scandate = max(_sd)
keep if in_pa
keep country id scandate
duplicates drop
drop if missing(scandate)
gsort scandate country id
local NS = _N
quietly summarize scandate
local dlo = r(min) - `KMAX' - 10
local dhi = r(max) + `KMAX' + 10
forvalues i = 1/`NS' {
	local sc_c`i' = country[`i']
	local sc_t`i' = scandate[`i']
}

/* ---- daily panel ---- */
use "${datfin}/panel_country_day", clear
drop if country == "Venezuela"
keep if inrange(date, `dlo', `dhi')
keep country date `OC' scandal_today
tempfile daily
save `daily'

/* ============================================================
   STEP 1 - collect observed/synthetic trajectories and placebo gaps,
   per window K, saved so the figures can be rebuilt without re-fitting.
   Set REFIT=1 to force the ~3600 SDID fits; otherwise, if the saved draws
   already exist, skip STEP 1 and only rebuild the figures (STEP 2).
   ============================================================ */
local REFIT = 0
local dofit = `REFIT'
foreach K of numlist 30 60 90 {
	capture confirm file "${datfin}/sdid_fig_series_w`K'.dta"
	if _rc local dofit = 1
	capture confirm file "${datfin}/sdid_fig_gaps_w`K'.dta"
	if _rc local dofit = 1
}
if `dofit' {
foreach K of numlist 30 60 90 {
	tempname SER GAP
	tempfile ser gap
	postfile `SER' int sid int tvar double obs double syn using "`ser'", replace
	postfile `GAP' int sid str24 who int tvar double g using "`gap'", replace

	forvalues i = 1/`NS' {
		local ct "`sc_c`i''"
		local t0 = `sc_t`i''

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
	save "${datfin}/sdid_fig_series_w`K'.dta", replace
	use "`gap'", clear
	save "${datfin}/sdid_fig_gaps_w`K'.dta", replace
	di as result "window `K' fits done"
}
}

/* ============================================================
   STEP 2 - figures, per window K x bin width B (1 = daily, 5, 10)
   ============================================================ */
foreach K of numlist 30 60 90 {
	local xs = `K'/3
foreach B of numlist 1 5 10 {

	/* ---- FIGURE A: observed vs synthetic (+ shifted) ---- */
	use "${datfin}/sdid_fig_series_w`K'.dta", clear
	gen double _d = obs - syn if tvar < 0
	bysort sid: egen double _off = mean(_d)
	gen double synsh = syn + _off
	drop _d _off
	if `B' == 1 {
		gen double tbin = tvar
	}
	else {
		gen double tbin = .
		replace tbin =  (floor(tvar/`B')*`B' + `B'/2)      if tvar >= 0
		replace tbin = -(floor((-tvar-1)/`B')*`B' + `B'/2) if tvar <  0
	}
	collapse (mean) obs syn synsh, by(tbin)
	twoway (line obs   tbin, lcolor(cranberry) lwidth(medthick)) ///
	       (line syn   tbin, lcolor(navy) lwidth(medthick) lpattern(dash)) ///
	       (line synsh tbin, lcolor(forest_green) lwidth(medthick) lpattern(shortdash)), ///
		xline(0, lcolor(black%30) lwidth(medthick)) ///
		ytitle("Violent protests (daily count)", size(medium)) ///
		xtitle("Days since scandal", size(medium)) ///
		xlabel(-`K'(`xs')`K') ///
		legend(order(1 "Apex countries (observed)" ///
		             2 "Synthetic control (as estimated)" ///
		             3 "Synthetic control (shifted to pre-period)") ///
			pos(6) cols(1) region(lstyle(none)) size(small)) ///
		graphregion(color(white) fcolor(white)) scheme(s2color)
	graph export "${figout}/sdid_trends_apex_violent_w`K'_b`B'.pdf", replace

	/* ---- FIGURE B: in-space placebo permutation (gap, demeaned) ---- */
	use "${datfin}/sdid_fig_gaps_w`K'.dta", clear
	gen double _preg = g if tvar<0
	bysort sid who: egen double pregap = mean(_preg)
	replace g = g - pregap
	drop _preg pregap
	collapse (mean) g, by(who tvar)
	if `B' == 1 {
		gen double tbin = tvar
	}
	else {
		gen double tbin = .
		replace tbin =  (floor(tvar/`B')*`B' + `B'/2)      if tvar >= 0
		replace tbin = -(floor((-tvar-1)/`B')*`B' + `B'/2) if tvar <  0
	}
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
		legend(order(1 "Placebo (each donor country treated)" `redlayer' "Apex (observed)") ///
			pos(6) cols(1) region(lstyle(none)) size(small)) ///
		graphregion(color(white) fcolor(white)) scheme(s2color)
	graph export "${figout}/sdid_placebo_apex_violent_w`K'_b`B'.pdf", replace
}
	di as result "window `K' figures done"
}

display in green "a_sdid_figures_pa_vs_na.do finished OK"
