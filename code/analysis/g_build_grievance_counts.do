/* ----------------------------------------------------------------------------
   Grievance-split replication -- FOUNDATION

   Build a (country, date) lookup of daily protest counts split by grievance
   class x violence, so every downstream g_*.do can merge it onto its panel and
   swap the two paper outcomes for the four grievance outcomes:
        gcorr_v  = corruption/accountability-related, violent
        gunrel_v = unrelated, violent
        gcorr_p  = corruption/accountability-related, peaceful
        gunrel_p = unrelated, peaceful
   (gcorr_v+gunrel_v reproduce num_violent_MM; likewise for peaceful.)

   Classifier: a protest is corruption/accountability-related if its MM notes
   mention corruption/malfeasance, OR its demand is "removal of politician", OR
   the notes call for a resignation/impeachment; else unrelated.

   Output: ${datfin}/grievance_counts.dta  (unique by country date)
---------------------------------------------------------------------------- */
set more off
clear all
if "`c(username)'" == "rob98" global identity "~/Dropbox"
if "`c(username)'" == "Rob_9" global identity "C:/Users/Rob_9/Dropbox"
global path   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"
global mmraw  "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals/Data/raw/Protests/MM/MMraw.csv"

/* sample countries (union over the scandal panel) */
use "${datfin}/protests_scandals_30days_v3", clear
keep country
duplicates drop
tempfile sc
save `sc'

import delimited using "${mmraw}", clear varnames(1) bindquotes(strict) stringcols(30 31)
keep if protest == 1
merge m:1 country using `sc', keep(3) nogenerate

gen double pstart = mdy(startmonth, startday, startyear)
gen double pend   = mdy(endmonth,   endday,   endyear)
replace pend = pstart if missing(pend) | pend < pstart
keep if inrange(startyear, 2008, 2019)

gen note = lower(notes)
gen d1 = lower(strtrim(protesterdemand1))
gen d2 = lower(strtrim(protesterdemand2))
gen byte kw_corrupt = regexm(note, "corrupt|bribe|coima|kickback|embezzl|graft|scandal|odebrecht|lava jato|launder|fraud|misappropriat|malfeasan")
gen byte kw_removal = regexm(note, "resign|step down|stepped down|impeach|ouster|renuncia")
gen byte dem_removal = (d1 == "removal of politician") | (d2 == "removal of politician")
gen byte related = kw_corrupt | kw_removal | dem_removal
gen byte viol    = (protesterviolence == 1)

/* expand each protest across its active days (t .. t+X-1) */
gen long _pid = _n
gen int dur = pend - pstart + 1
replace dur = 1 if missing(dur) | dur < 1
expand dur
bysort _pid: gen double date = pstart + _n - 1
format date %td

gen byte c_cv = related  & viol
gen byte c_cp = related  & !viol
gen byte c_uv = !related & viol
gen byte c_up = !related & !viol
collapse (sum) gcorr_v=c_cv gunrel_v=c_uv gcorr_p=c_cp gunrel_p=c_up, by(country date)
label var gcorr_v  "Corruption-related violent protests"
label var gunrel_v "Unrelated violent protests"
label var gcorr_p  "Corruption-related peaceful protests"
label var gunrel_p "Unrelated peaceful protests"
isid country date
compress
save "${datfin}/grievance_counts.dta", replace
di as green "grievance_counts.dta saved: " _N " country-dates"
