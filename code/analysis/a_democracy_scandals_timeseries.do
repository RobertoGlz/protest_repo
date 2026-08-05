/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-08-05

    Objective (idea from Saumitra, 2026-08-05):
        Do apex corruption scandals PRECEDE changes in democracy levels?  A
        dual-axis time series, 2008 onward:
          - LEFT axis  : cumulative number of APEX scandals the average country
                         has experienced since 2008;
          - RIGHT axis : V-Dem Electoral Democracy Index (v2x_polyarchy) level,
        each split into the bottom vs.\ the top tercile of the 2008 Electoral
        Democracy Index (the same tercile classification as the paper's
        democracy tables: xtile nq(3) over the scandal countries).  Four lines:
        {bottom, top} x {cumulative apex scandals (solid), democracy (dashed)}.

    Inputs:
      - ${datfin}/protests_scandals_30days_v3.dta        (scandal dates)
      - ${datfin}/scandals_classified.csv                (position -> apex)
      - VDEM CY Full Others.dta                          (v2x_polyarchy by year)
    Output:
      - paper/figures/democracy_scandals_timeseries.pdf
---------------------------------------------------------------------------- */

set more off
clear all

if "`c(username)'" == "Diego"  global identity "D:/Documents/Dropbox"
if "`c(username)'" == "dtocre" global identity "C:/Users/dtocre/Dropbox"
if "`c(username)'" == "lalov"  global identity "C:/Users/lalov/ITAM Seira Research Dropbox/Eduardo Rivera"
if "`c(username)'" == "Rob_9"  global identity "C:/Users/Rob_9/Dropbox"
if "`c(username)'" == "rob98"  global identity "~/Dropbox"

global path    "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin  "${path}/Data/final"
global figout  "${identity}/Corrupcion/protest_repo/paper/figures"

/* V-Dem source: try both known locations. */
capture confirm file "${identity}/Corrupcion/replication-package-jpe/data/raw/protest/VDEM/vdem cy full others.dta"
if _rc == 0 {
	global vdem_src "${identity}/Corrupcion/replication-package-jpe/data/raw/protest/VDEM"
	local vdem_file "vdem cy full others.dta"
}
else {
	global vdem_src "${path}/Data/raw/VDEM"
	local vdem_file "VDEM CY Full Others.dta"
}

local ylo = 2008
local yhi = 2019

/* ============================================================
   STEP 1 - apex scandals per country-year
   ============================================================ */
import delimited using "${datfin}/scandals_classified.csv", clear varnames(1) bindquotes(strict)
keep id country position
tempfile cls
save `cls'

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
gen double _sd = date if window == 0
bysort country id: egen double scandate = max(_sd)
keep country id scandate
duplicates drop
drop if missing(scandate)
merge 1:1 id country using `cls', keep(3) nogenerate
gen byte in_pa = inlist(position,"president","governor") | ///
	(position=="sc_judge_congressman" & inlist(id,"202","NEW26","NEW30","332"))
keep if in_pa == 1
gen int year = year(scandate)
gen byte one = 1
collapse (sum) n_apex = one, by(country year)
tempfile apex
save `apex'

/* ============================================================
   STEP 2 - V-Dem 2008 terciles (over the scandal countries) + time series
   ============================================================ */
use "${vdem_src}/`vdem_file'", clear
keep country_name year v2x_polyarchy
replace country_name = "Dominican Republic" if country_name == "Dominican Rep."
rename country_name country
keep if inrange(year, `ylo', `yhi')
tempfile vdemts
save `vdemts'

/* scandal-country universe (the countries in the event panel) */
use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
keep country
duplicates drop
tempfile sc
save `sc'

/* 2008 index -> terciles over scandal countries */
use `vdemts', clear
keep if year == 2008
merge 1:1 country using `sc', keep(3) nogenerate
xtile terc3 = v2x_polyarchy, nq(3)
count
di as result "tercile split over `r(N)' scandal countries"
tab terc3
keep country terc3
tempfile terc
save `terc'

/* ============================================================
   STEP 3 - country x year grid: cumulative apex scandals + democracy
   ============================================================ */
use `terc', clear
expand `=`yhi'-`ylo'+1'
bysort country: gen int year = `ylo' + _n - 1
merge 1:1 country year using `vdemts', keep(1 3) nogenerate
merge 1:1 country year using `apex', keep(1 3) nogenerate
replace n_apex = 0 if missing(n_apex)
bysort country (year): gen int cum_apex = sum(n_apex)

/* aggregate to tercile x year */
collapse (mean) cum_apex (mean) vdem = v2x_polyarchy (count) ncty = n_apex, by(terc3 year)

/* ============================================================
   STEP 4 - dual-axis figure (bottom = cranberry, top = navy;
             scandals = solid on left axis, democracy = dashed on right axis)
   ============================================================ */
twoway ///
    (line cum_apex year if terc3==1, yaxis(1) lcolor(cranberry) lwidth(thick)) ///
    (line cum_apex year if terc3==3, yaxis(1) lcolor(navy)      lwidth(thick)) ///
    (line vdem     year if terc3==1, yaxis(2) lcolor(cranberry) lwidth(medthick) lpattern(dash)) ///
    (line vdem     year if terc3==3, yaxis(2) lcolor(navy)      lwidth(medthick) lpattern(dash)) ///
    , ///
    ytitle("Cumulative apex scandals per country", axis(1) size(medium)) ///
    ytitle("V-Dem Electoral Democracy Index", axis(2) size(medium)) ///
    xtitle("Year", size(medium)) ///
    xlabel(`ylo'(2)`yhi', angle(0)) ///
    legend(order(1 "Bottom tercile: cumulative scandals (left)" ///
                 2 "Top tercile: cumulative scandals (left)" ///
                 3 "Bottom tercile: democracy index (right)" ///
                 4 "Top tercile: democracy index (right)") ///
           rows(4) position(6) size(small) region(lstyle(none))) ///
    graphregion(color(white) fcolor(white)) scheme(s2color)
graph export "${figout}/democracy_scandals_timeseries.pdf", replace

display in green "a_democracy_scandals_timeseries.do finished OK"
