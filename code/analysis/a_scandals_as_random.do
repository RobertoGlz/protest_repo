/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-08-05

    Objective:
        Show that the EXACT calendar date on which a corruption scandal is first
        disclosed cannot be predicted from observable calendar structure or the
        electoral cycle -- i.e., that disclosure timing is, for our purposes, as
        good as random.  We build a country-by-day panel over the sample countries
        (Venezuela excluded) with an indicator for one of our 176 scandals being
        disclosed that day, and try to predict it from progressively richer sets
        of predictors:

            (1) day of week
            (2) + month of year
            (3) + day of month
            (4) + proximity to a national election (0-30 / 31-60 / 61-90 /
                  91-120 days before)

        The identifying claim is specifically that, WITHIN a country-year, citizens
        cannot predict the exact disclosure day: a citizen may know a country-year
        is scandal-prone, but not on which day the scoop drops.  We therefore
        condition on country-by-year (conditional / fixed-effects logit grouped by
        country-year) and ask whether the calendar/electoral predictors pick the
        scandal day out of the other days of the SAME country-year.

        Because scandals are rare (~0.2% of country-days), raw accuracy is
        uninformative (always predicting "no scandal" scores ~99.8%).  The honest
        "can we beat a coin flip?" metric is the AUC -- the probability the model
        ranks a scandal-day above a non-scandal-day; 0.5 is a coin flip and is
        base-rate invariant.  We report the WITHIN-country-year AUC (Harrell's c
        restricted to within-country-year pairs, via somersd), both in sample and
        out of sample (train on a random half of the days, rank the held-out half
        within each country-year).

    Inputs:
        - ${datfin}/protests_scandals_30days_v3.dta (the 176 paper scandals; the
                                                     window==0 row dates each one)
        - ${datfin}/panel_country_day.dta           (country-day calendar skeleton)
        - ${datwrk}/election_dates_for_merge.dta     (national election dates)

    Outputs:
        - paper/tables/scandals_as_random.tex
---------------------------------------------------------------------------- */

set more off
clear all

/* ----------------------- User-specific paths ----------------------- */
if "`c(username)'" == "Diego"  global identity "D:/Documents/Dropbox"
if "`c(username)'" == "dtocre" global identity "C:/Users/dtocre/Dropbox"
if "`c(username)'" == "lalov"  global identity "C:/Users/lalov/ITAM Seira Research Dropbox/Eduardo Rivera"
if "`c(username)'" == "Rob_9"  global identity "C:/Users/Rob_9/Dropbox"
if "`c(username)'" == "rob98"  global identity "~/Dropbox"

global path    "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin  "${path}/Data/final"
global datwrk  "${path}/Data/working"
global tabout  "${identity}/Corrupcion/protest_repo/paper/tables"

/* ---- national election dates: one row per country-election ---- */
use "${datwrk}/election_dates_for_merge", clear
capture confirm string variable date_election
if _rc == 0 gen double eldate = date(date_election, "MDY")   /* stored as string */
else        gen double eldate = date_election                /* stored as %td    */
format eldate %td
keep country eldate
drop if missing(eldate)
tempfile elec
save `elec'

/* ---- the paper's 176 scandals (Venezuela excluded): the window==0 row dates
        each scandal's disclosure.  Reduce to a country-day indicator. ---- */
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
count
di as result "scandal events (excl Venezuela): " r(N)      /* 176 */
gen scandal = 1
rename scandate date
collapse (max) scandal, by(country date)                   /* 1 per country-day */
count
di as result "distinct scandal country-days: " r(N)        /* 171 */
tempfile scand
save `scand'
keep country
duplicates drop
tempfile scountries
save `scountries'

/* ---- country-day calendar skeleton over the sample countries, spanning the
        full range of scandal dates (2008-2019). ---- */
use "${datfin}/panel_country_day", clear
keep if inrange(year, 2008, 2019)
drop if country == "Venezuela"
capture confirm variable id
if _rc==0 {
	drop if id == "TWNEWLATINO14" & country == "Ecuador"   // duplicate of scandal 108 (Alex Bravo, Petroecuador)
	drop if id == "TWNEWLATINO23" & country == "Brazil"     // Gurgel statement, not a corruption scandal
}
merge m:1 country using `scountries', keep(3) nogenerate    /* countries at risk */
keep country country_id date year month dow
merge 1:1 country date using `scand', keep(1 3) nogenerate
replace scandal = 0 if missing(scandal)
gen int dom = day(date)                                     /* day of the month */
count if scandal == 1
di as result "scandal country-days matched into panel: " r(N)

/* ---- distance to the nearest UPCOMING national election ---- */
joinby country using `elec', unmatched(master)
gen double dtoelec = eldate - date
replace dtoelec = . if dtoelec < 0            /* only elections still ahead */
collapse (firstnm) country_id year month dow dom scandal (min) dmin = dtoelec, ///
	by(country date)
gen byte close_election = 0
replace close_election = 1 if inrange(dmin,  0,  30)
replace close_election = 2 if inrange(dmin, 31,  60)
replace close_election = 3 if inrange(dmin, 61,  90)
replace close_election = 4 if inrange(dmin, 91, 120)
label define ce 0 "far / none" 1 "0-30d" 2 "31-60d" 3 "61-90d" 4 "91-120d"
label values close_election ce

egen cy = group(country year)

capture which somersd
if _rc ssc install somersd, replace

/* The exact-date question lives WITHIN a country-year, so the comparison set is
   the country-years that actually contain a scandal (a scandal-free country-year
   offers no scandal-day to rank).  Count them for the table. */
bysort cy: egen byte hasS = max(scandal)
count if hasS == 1
local Ndays = r(N)
egen byte _tagcy = tag(cy) if hasS == 1
count if _tagcy == 1
local Ncy = r(N)
drop _tagcy

/* ---- random 50/50 split of country-days for out-of-sample evaluation ---- */
set seed 300124
set sortseed 300124
gen double _u = runiform()
gen byte insamp = (_u >= 0.5)
drop _u

/* ============================================================
   Within-country-year prediction: conditional (FE) logit grouped by country-year,
   with progressively richer calendar / electoral predictors.  Discrimination is
   the within-country-year AUC (somersd, transf(c), wstrata(cy)), in and out of
   sample.  ~0.5 == citizens cannot pick the disclosure day out of the year.
   ============================================================ */
local t1 "i.dow"
local t2 "i.dow i.month"
local t3 "i.dow i.month i.dom"
local t4 "i.dow i.month i.dom i.close_election"

forvalues i = 1/4 {

	local terms "`t`i''"

	/* within-CY model + joint test of the predictors */
	quietly clogit scandal `terms', group(cy)
	quietly testparm `terms'
	local jp`i' = r(p)
	quietly predict double _xb, xb
	quietly somersd scandal _xb if hasS == 1, transf(c) wstrata(cy)
	matrix C = e(b)
	local ai`i' = C[1,1]
	drop _xb

	/* out of sample: train on a random half, rank the held-out half within CY */
	quietly clogit scandal `terms' if insamp == 1, group(cy)
	quietly predict double _xo, xb
	quietly somersd scandal _xo if insamp == 0 & hasS == 1, transf(c) wstrata(cy)
	matrix C2 = e(b)
	local ao`i' = C2[1,1]
	drop _xo

	di as result "spec `i': within-CY AUC in = " %5.3f `ai`i'' ///
		"  out = " %5.3f `ao`i'' "  joint p = " %5.3f `jp`i''
}

/* ---- write the table (stats only; the predictors are nuisance day/month/dom
        dummies, so we report the specification switches and the fit). ---- */
local Ndf : di %9.0fc `Ndays'
local Ncf : di %4.0f `Ncy'
forvalues i = 1/4 {
	local jpf`i' : di %5.3f `jp`i''
	local aif`i' : di %5.3f `ai`i''
	local aof`i' : di %5.3f `ao`i''
}
capture file close tb
file open tb using "${tabout}/scandals_as_random.tex", write replace
file write tb "\begin{tabular}{lcccc}" _n
file write tb "\toprule" _n
file write tb " & (1) & (2) & (3) & (4) \\" _n
file write tb "\midrule" _n
file write tb "Day of week & Yes & Yes & Yes & Yes \\" _n
file write tb "Month of year & No & Yes & Yes & Yes \\" _n
file write tb "Day of month & No & No & Yes & Yes \\" _n
file write tb "Election proximity & No & No & No & Yes \\" _n
file write tb "Country \$\times\$ year FE & Yes & Yes & Yes & Yes \\" _n
file write tb "\midrule" _n
file write tb "Country-days & `Ndf' & `Ndf' & `Ndf' & `Ndf' \\" _n
file write tb "Scandal country-years & `Ncf' & `Ncf' & `Ncf' & `Ncf' \\" _n
file write tb "Joint test \$p\$-value & `jpf1' & `jpf2' & `jpf3' & `jpf4' \\" _n
file write tb "Within-year AUC (in-sample) & `aif1' & `aif2' & `aif3' & `aif4' \\" _n
file write tb "Within-year AUC (out-of-sample) & `aof1' & `aof2' & `aof3' & `aof4' \\" _n
file write tb "\bottomrule" _n
file write tb "\end{tabular}" _n
file close tb

display in green "a_scandals_as_random.do finished OK"
