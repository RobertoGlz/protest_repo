/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper - referee response

   Objective (referee "Issue 5", the highest-value robustness):
     Split the daily violent/peaceful protest counts into protests whose stated
     grievance is CORRUPTION/ACCOUNTABILITY-related vs UNRELATED, and re-estimate
     the two-group (Apex vs Non-Apex) interaction of eq. (1) on each of the four
     outcomes:
        corr_violent, corr_peaceful, unrel_violent, unrel_peaceful.

     A protest is "corruption/accountability-related" if its MM notes mention
     corruption/malfeasance, OR its demand is "removal of politician", OR its
     notes demand a resignation/impeachment.  Otherwise "unrelated".

   Validation: the rebuilt total violent/peaceful counts (corr + unrel) must
   reproduce the panel's num_violent_MM / num_peaceful_MM on the merged
   country-dates.  We print the max abs discrepancy.

   Inputs:
     - ${datfin}/protests_scandals_30days_v3.dta
     - ${datfin}/scandals_classified.csv
     - MM raw CSV
   Output: log only (first pass); coefficients printed for inspection.
---------------------------------------------------------------------------- */
set more off
clear all
if "`c(username)'" == "rob98" global identity "~/Dropbox"
if "`c(username)'" == "Rob_9" global identity "C:/Users/Rob_9/Dropbox"
global path   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"
global mmraw  "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals/Data/raw/Protests/MM/MMraw.csv"

/* ============================================================
   STEP 1 - grievance-split country-date protest counts from MM raw
   ============================================================ */
/* sample countries */
use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
keep country
duplicates drop
tempfile sc
save `sc'

import delimited using "${mmraw}", clear varnames(1) bindquotes(strict) stringcols(30 31)
keep if protest == 1
merge m:1 country using `sc', keep(3) nogenerate      /* keep sample countries */

gen double pstart = mdy(startmonth, startday, startyear)
gen double pend   = mdy(endmonth,   endday,   endyear)
replace pend = pstart if missing(pend) | pend < pstart
keep if inrange(startyear, 2008, 2019)

/* --- grievance flag --- */
gen note = lower(notes)
gen d1 = lower(strtrim(protesterdemand1))
gen d2 = lower(strtrim(protesterdemand2))
gen byte kw_corrupt = regexm(note, "corrupt|bribe|coima|kickback|embezzl|graft|scandal|odebrecht|lava jato|launder|fraud|misappropriat|malfeasan")
gen byte kw_removal = regexm(note, "resign|step down|stepped down|impeach|ouster|renuncia")
gen byte dem_removal = (d1 == "removal of politician") | (d2 == "removal of politician")
gen byte related = kw_corrupt | kw_removal | dem_removal
gen byte viol    = (protesterviolence == 1)

/* --- expand each protest across its active days (t .. t+X-1) --- */
gen long _pid = _n
gen int dur = pend - pstart + 1
replace dur = 1 if missing(dur) | dur < 1
expand dur
bysort _pid: gen double date = pstart + _n - 1
format date %td

/* --- collapse to country x date counts --- */
gen byte c_cv = related  & viol
gen byte c_cp = related  & !viol
gen byte c_uv = !related & viol
gen byte c_up = !related & !viol
gen byte c_v  = viol
gen byte c_p  = !viol
collapse (sum) mm_corr_violent=c_cv mm_corr_peaceful=c_cp ///
               mm_unrel_violent=c_uv mm_unrel_peaceful=c_up ///
               mm_violent=c_v mm_peaceful=c_p, by(country date)
tempfile counts
save `counts'

/* ============================================================
   STEP 2 - merge onto the analysis panel + validate
   ============================================================ */
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

merge m:1 country date using `counts', keep(1 3) generate(_mcnt)
foreach v in mm_corr_violent mm_corr_peaceful mm_unrel_violent mm_unrel_peaceful mm_violent mm_peaceful {
	replace `v' = 0 if missing(`v')
}

/* validation: rebuilt totals vs panel outcomes */
gen double _dv = mm_violent  - num_violent_MM
gen double _dp = mm_peaceful - num_peaceful_MM
quietly summarize _dv
local maxv = max(abs(r(min)), abs(r(max)))
quietly summarize _dp
local maxp = max(abs(r(min)), abs(r(max)))
di as result _n "==== VALIDATION (should be ~0) ===="
di as result "max |mm_violent  - num_violent_MM|  = " `maxv'
di as result "max |mm_peaceful - num_peaceful_MM| = " `maxp'
quietly count if _dv != 0
di as result "country-dates with violent mismatch: " r(N)
quietly count if _dp != 0
di as result "country-dates with peaceful mismatch: " r(N)
/* correlation as a softer check */
quietly corr mm_violent num_violent_MM
di as result "corr(mm_violent, num_violent_MM) = " r(rho)

/* ============================================================
   STEP 3 - estimate eq.(1) on the four grievance x violence outcomes
   ============================================================ */
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

local firstyear = 2008
di as txt _n "================= GRIEVANCE-SPLIT ESTIMATES ================="
di as txt "outcome                window   beta_Apex (p)        beta_NonApex (p)     pre-mean"
foreach oc in mm_corr_violent mm_unrel_violent mm_corr_peaceful mm_unrel_peaceful {
	foreach W in 30 60 90 {
		quietly reghdfe `oc' post_pa post_na i.month i.day ///
			if year >= `firstyear' & abs(window) <= `W' & (in_pa==1 | in_na==1), ///
			absorb(i.country_id#i.year) vce(cluster i.country_id#i.year#i.grupo_dias)
		local bpa = _b[post_pa]
		local ppa = 2*ttail(e(df_r), abs(_b[post_pa]/_se[post_pa]))
		local bna = _b[post_na]
		local pna = 2*ttail(e(df_r), abs(_b[post_na]/_se[post_na]))
		quietly summarize `oc' if e(sample) & window >= -`W' & window <= -1
		local pm = r(mean)
		di as result %-22s "`oc'" %6.0f `W' "   " ///
			%7.4f `bpa' " (" %5.3f `ppa' ")   " ///
			%7.4f `bna' " (" %5.3f `pna' ")   " %7.4f `pm'
	}
}
di as green _n "a_grievance_split_pa_vs_na.do finished OK"
