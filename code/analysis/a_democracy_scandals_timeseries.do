/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-08-05

    Objective (idea from Saumitra, 2026-08-05):
        Do apex corruption scandals PRECEDE changes in democracy levels?  Small
        multiples, one facet per scandal country (16, as in Table S3):
          - x axis : year (2008-2019);
          - y axis : that country's V-Dem democracy index;
          - VERTICAL gray lines mark the year-month of each apex scandal;
          - two short-dashed reference lines per facet: the bottom-tercile and
            top-tercile MEAN index (2008 terciles of the same index).
        Produced for BOTH the Electoral (v2x_polyarchy) and Liberal (v2x_libdem)
        democracy indices.

    Inputs:
      - ${datfin}/protests_scandals_30days_v3.dta        (scandal dates)
      - ${datfin}/scandals_classified.csv                (position -> apex)
      - VDEM CY Full Others.dta                          (v2x_polyarchy, v2x_libdem)
    Outputs:
      - paper/figures/democracy_scandals_timeseries.pdf  (Electoral)
      - paper/figures/democracy_scandals_liberal.pdf     (Liberal)
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
   STEP 1 - apex scandal dates (year-month) per country + per-country xline lists
   ============================================================ */
import delimited using "${datfin}/scandals_classified.csv", clear varnames(1) bindquotes(strict)
keep id country position
tempfile cls
save `cls'

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
capture confirm variable id
if _rc==0 {
	drop if id == "TWNEWLATINO14" & country == "Ecuador"   // duplicate of scandal 108 (Alex Bravo, Petroecuador)
	drop if id == "TWNEWLATINO23" & country == "Brazil"     // Gurgel statement, not a corruption scandal
}
gen double _sd = date if window == 0
bysort country id: egen double scandate = max(_sd)
keep country id scandate
duplicates drop
drop if missing(scandate)
merge 1:1 id country using `cls', keep(3) nogenerate
gen byte in_pa = inlist(position,"president","governor") | ///
	(position=="sc_judge_congressman" & inlist(id,"202","NEW26","NEW30","332"))
keep if in_pa == 1
gen double decyear = year(scandate) + (month(scandate)-1)/12
keep country decyear

levelsof country, local(apexctys)
foreach c of local apexctys {
	local ctok = subinstr("`c'", " ", "_", .)
	levelsof decyear if country=="`c'", local(dd)
	local sd_`ctok' `"`dd'"'
}

/* ============================================================
   STEP 2 - V-Dem time series (both indices) + scandal-country list
   ============================================================ */
use "${vdem_src}/`vdem_file'", clear
keep country_name year v2x_polyarchy v2x_libdem
replace country_name = "Dominican Republic" if country_name == "Dominican Rep."
rename country_name country
keep if inrange(year, `ylo', `yhi')
tempfile vdemts
save `vdemts'

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
capture confirm variable id
if _rc==0 {
	drop if id == "TWNEWLATINO14" & country == "Ecuador"   // duplicate of scandal 108 (Alex Bravo, Petroecuador)
	drop if id == "TWNEWLATINO23" & country == "Brazil"     // Gurgel statement, not a corruption scandal
}
keep country
duplicates drop
tempfile sc
save `sc'

/* ============================================================
   STEP 3 - one faceted figure per index (Electoral, Liberal)
   ============================================================ */
foreach spec in polyarchy libdem {

	if "`spec'" == "polyarchy" {
		local idx  "v2x_polyarchy"
		local ilab "Electoral"
		local fout "democracy_scandals_timeseries.pdf"
		local ylb  "0.4(0.2)0.8"
	}
	else {
		local idx  "v2x_libdem"
		local ilab "Liberal"
		local fout "democracy_scandals_liberal.pdf"
		local ylb  "0.2(0.2)0.8"
	}

	/* terciles of the 2008 index over the scandal countries */
	use `vdemts', clear
	keep if year == 2008
	merge 1:1 country using `sc', keep(3) nogenerate
	xtile terc3 = `idx', nq(3)
	keep country terc3
	tempfile terc
	save `terc'

	/* country x year grid + bottom/top tercile mean index */
	use `terc', clear
	expand `=`yhi'-`ylo'+1'
	bysort country: gen int year = `ylo' + _n - 1
	merge 1:1 country year using `vdemts', keep(1 3) nogenerate
	gen double bidx = `idx' if terc3 == 1
	bysort year: egen double vdem_bot = mean(bidx)
	gen double tidx = `idx' if terc3 == 3
	bysort year: egen double vdem_top = mean(tidx)
	drop bidx tidx

	/* facet per scandal country */
	levelsof country, local(allctys)
	local graphs ""
	local i = 0
	foreach c of local allctys {
		local ++i
		local ctok = subinstr("`c'", " ", "_", .)
		local xlopt ""
		if `"`sd_`ctok''"' != "" local xlopt "xline(`sd_`ctok'', lcolor(gs9) lwidth(vthin))"
		twoway (line `idx'     year if country=="`c'", lcolor(black) lwidth(medthick)) ///
		       (line vdem_bot   year if country=="`c'", lcolor(cranberry) lpattern(shortdash) lwidth(thin)) ///
		       (line vdem_top   year if country=="`c'", lcolor(navy) lpattern(shortdash) lwidth(thin)) ///
		    , `xlopt' ///
		      title("`c'", size(medlarge)) ytitle("") xtitle("") ///
		      ylabel(0.2 0.5 0.8, format(%3.1f) labsize(medsmall)) ///
		      xlabel(2010 2014 2018, labsize(medsmall)) ///
		      legend(off) scheme(s2color) graphregion(color(white)) nodraw name(gg`i', replace)
		local graphs "`graphs' gg`i'"
	}

	graph combine `graphs', cols(4) imargin(small) ycommon ///
	    b1title("Year", size(small)) ///
	    l1title("V-Dem `ilab' Democracy Index", size(small)) ///
	    graphregion(color(white))
	graph export "${figout}/`fout'", replace
	di as result "exported `ilab' figure: `fout'"
}

display in green "a_democracy_scandals_timeseries.do finished OK"
