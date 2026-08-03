/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-08-03

    Objective:
        Diagnostic figures for the stacked synthetic difference-in-differences
        of a_sdid_stacked_pa_vs_na.do, for the headline case (apex scandals,
        violent protests, +-90-day window):

          (A) sdid_trends_apex_violent.pdf
              Observed treated trajectory vs. the synthetic-control counterfactual,
              averaged across the apex scandals in event time.  (From e(series).)

          (B) sdid_placebo_apex_violent.pdf
              In-space placebo / permutation test.  For every apex scandal we also
              treat each DONOR country as a placebo-treated unit (synthetic control
              rebuilt from the remaining donors) and take the gap (treated minus
              synthetic).  Each gray line is a donor country's average placebo gap
              across scandals; the red line is the true apex gap.  A true gap that
              separates from the placebo cloud after disclosure is the inference.
              (From e(difference); gaps demeaned by their pre-scandal average.)

    Requires: sdid  (ssc install sdid)

    Inputs:
        - ${datfin}/scandals_classified.csv
        - ${datfin}/protests_scandals_30days_v3.dta
        - ${datfin}/panel_country_day.dta
    Outputs (paper/figures/):
        - sdid_trends_apex_violent.pdf
        - sdid_placebo_apex_violent.pdf
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

local K  = 90
local OC = "mm_violent"

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
local dlo = r(min) - `K' - 10
local dhi = r(max) + `K' + 10
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

	/* real fit: store observed + synthetic trajectory and the gap */
	capture sdid `OC' uid tvar treat, method(sdid) vce(noinference)
	if _rc continue
	matrix Sr = e(series)
	matrix Dr = e(difference)
	local nr = rowsof(Sr)
	forvalues r = 1/`nr' {
		post `SER' (`i') (`=Sr[`r',1]') (`=Sr[`r',3]') (`=Sr[`r',2]')
		post `GAP' (`i') ("TREATED") (`=Dr[`r',1]') (`=Dr[`r',2]')
	}

	/* in-space placebos: each donor as pseudo-treated (real treated dropped) */
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
	if mod(`i',10)==0 di as result "scandal `i'/`NS' done"
}
postclose `SER'
postclose `GAP'

/* persist the trajectory/gap draws so the figures can be rebuilt without
   re-running the ~1000 SDID fits */
use "`ser'", clear
save "${datfin}/sdid_fig_series.dta", replace
use "`gap'", clear
save "${datfin}/sdid_fig_gaps.dta", replace

/* ============================================================
   FIGURE A - observed vs synthetic control (levels), averaged.
   SDID identifies off the CHANGE in the treated-minus-synthetic gap, so the
   synthetic need not match the treated's pre-period level.  We show three
   series: (i) observed apex trajectory; (ii) the synthetic control as
   estimated (which sits below, since apex countries protest more at baseline);
   and (iii) the same synthetic shifted up by its pre-scandal offset (the DiD
   intercept), which aligns it to the observed pre-period so the post-disclosure
   divergence is the estimated effect.
   ============================================================ */
use "${datfin}/sdid_fig_series.dta", clear
gen double _d = obs - syn if tvar < 0
bysort sid: egen double _off = mean(_d)
gen double synsh = syn + _off
drop _d _off
collapse (mean) obs syn synsh, by(tvar)
twoway (line obs   tvar, lcolor(cranberry) lwidth(medthick)) ///
       (line syn   tvar, lcolor(navy) lwidth(medthick) lpattern(dash)) ///
       (line synsh tvar, lcolor(forest_green) lwidth(medthick) lpattern(shortdash)), ///
	xline(0, lcolor(black%30) lwidth(medthick)) ///
	ytitle("Violent protests (daily count)", size(medium)) ///
	xtitle("Days since scandal", size(medium)) ///
	xlabel(-`K'(30)`K') ///
	legend(order(1 "Apex countries (observed)" ///
	             2 "Synthetic control (as estimated)" ///
	             3 "Synthetic control (shifted to pre-period)") ///
		pos(11) ring(0) cols(1) region(lstyle(none)) size(small)) ///
	graphregion(color(white) fcolor(white)) scheme(s2color)
graph export "${figout}/sdid_trends_apex_violent.pdf", replace
di as result "sdid_trends_apex_violent.pdf written"

/* ============================================================
   FIGURE B - in-space placebo permutation (gap, demeaned)
   ============================================================ */
use "`gap'", clear
/* demean each unit's gap by its own pre-scandal (tvar<0) average */
gen double _preg = g if tvar<0
bysort sid who: egen double pregap = mean(_preg)
replace g = g - pregap
drop _preg pregap
/* average across scandals per (who, event-day) */
collapse (mean) g, by(who tvar)
gen byte istreat = who=="TREATED"
/* build the overlay: one faint line per donor country, then the treated line */
levelsof who if istreat==0, local(dons)
local ndon : word count `dons'
local redlayer = `ndon' + 1
local pc ""
foreach d of local dons {
	local pc `"`pc' (line g tvar if who=="`d'", lcolor(gs11) lwidth(vthin))"'
}
sort who tvar
twoway `pc' ///
       (line g tvar if istreat, lcolor(cranberry) lwidth(thick)), ///
	yline(0, lcolor(black%25) lwidth(medium)) ///
	xline(0, lcolor(black%30) lwidth(medthick)) ///
	ytitle("Gap: treated {&minus} synthetic (demeaned)", size(medium)) ///
	xtitle("Days since scandal", size(medium)) ///
	xlabel(-`K'(30)`K') ///
	legend(order(1 "Placebo (each donor country treated)" `redlayer' "Apex (observed)") ///
		pos(11) ring(0) cols(1) region(lstyle(none)) size(small)) ///
	graphregion(color(white) fcolor(white)) scheme(s2color)
graph export "${figout}/sdid_placebo_apex_violent.pdf", replace
di as result "sdid_placebo_apex_violent.pdf written"

display in green "a_sdid_figures_pa_vs_na.do finished OK"
