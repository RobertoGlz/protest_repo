/* ----------------------------------------------------------------------------
   Summary statistics of protests by {Apex, Non-Apex} x {Corruption-related,
   Unrelated}, to gauge whether the grievance-split results rest on very thin
   protest counts / a few scandals.

   For the POST-disclosure part of the +-30-day window (days 0..30) we report,
   per cell and separately for violent/peaceful:
     - protest-days   (the regression outcome; multi-day protests count each day)
     - episodes       (distinct protests, counted on their start date only)
     - #scandals >=1  (how many of the 63 apex / 111 non-apex scandals contribute)
     - top-1 share %  (largest single-scandal share of the protest-days -> concentration)
     - mean per scandal
   Plus daily-panel sparsity over the full +-30 window (mean count, % nonzero days).

   Output: printed table + ${figout}/../tables/g_summary_stats.csv (scandal-level)
   NOTE: run g_build_grievance_counts.do first (not required, MM is re-read here).
---------------------------------------------------------------------------- */
set more off
clear all
if "`c(username)'" == "rob98" global identity "~/Dropbox"
if "`c(username)'" == "Rob_9" global identity "C:/Users/Rob_9/Dropbox"
global path    "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin  "${path}/Data/final"
global mmraw   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals/Data/raw/Protests/MM/MMraw.csv"
global tables  "${identity}/Corrupcion/protest_repo/paper/tables"

/* ---- sample countries ---- */
use "${datfin}/protests_scandals_30days_v3", clear
keep country
duplicates drop
tempfile sc
save `sc'

/* ---- MM protests with grievance + violence flags ---- */
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
gen long _pid = _n
tempfile mmflags
save `mmflags'

/* ---- ONSET counts (start date only) ---- */
use `mmflags', clear
gen double date = pstart
gen byte on_gcorr_v = related  & viol
gen byte on_gunrel_v = !related & viol
gen byte on_gcorr_p = related  & !viol
gen byte on_gunrel_p = !related & !viol
collapse (sum) on_gcorr_v on_gunrel_v on_gcorr_p on_gunrel_p, by(country date)
tempfile onsets
save `onsets'

/* ---- PROTEST-DAY counts (expand across active days) ---- */
use `mmflags', clear
gen int dur = pend - pstart + 1
replace dur = 1 if missing(dur) | dur < 1
expand dur
bysort _pid: gen double date = pstart + _n - 1
gen byte pd_gcorr_v = related  & viol
gen byte pd_gunrel_v = !related & viol
gen byte pd_gcorr_p = related  & !viol
gen byte pd_gunrel_p = !related & !viol
collapse (sum) pd_gcorr_v pd_gunrel_v pd_gcorr_p pd_gunrel_p, by(country date)
tempfile pdays
save `pdays'

/* ---- event-window panel + apex flag ---- */
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
merge m:1 id country using `cls', keep(1 3) nogenerate
gen byte apex = inlist(position,"president","governor") | ///
	(position=="sc_judge_congressman" & inlist(id,"202","NEW26","NEW30","332"))
merge m:1 country date using `pdays',  keep(1 3) nogenerate
merge m:1 country date using `onsets', keep(1 3) nogenerate
foreach v in pd_gcorr_v pd_gunrel_v pd_gcorr_p pd_gunrel_p on_gcorr_v on_gunrel_v on_gcorr_p on_gunrel_p {
	replace `v' = 0 if missing(`v')
}
keep if abs(window) <= 30
tempfile panel30
save `panel30'

/* number of scandals per partition */
preserve
	keep if window == 0
	keep id country apex
	duplicates drop
	quietly count if apex == 1
	local nsc_apex = r(N)
	quietly count if apex == 0
	local nsc_na = r(N)
restore
di as txt _n "Scandals: Apex = `nsc_apex',  Non-Apex = `nsc_na'"

/* ---- per-scandal POST-window (days 0..30) totals ---- */
use `panel30', clear
keep if window >= 0 & window <= 30
collapse (sum) pd_gcorr_v pd_gunrel_v pd_gcorr_p pd_gunrel_p ///
               on_gcorr_v on_gunrel_v on_gcorr_p on_gunrel_p, by(id country apex)
export delimited using "${tables}/g_summary_stats.csv", replace
tempfile byscandal
save `byscandal'

/* ---- print the summary table ---- */
di as txt _n "{hline 92}"
di as txt "POST-disclosure protest mass (days 0..30), by cell.  pd=protest-days, ep=episodes,"
di as txt "ns=#scandals with >=1, top1=largest single-scandal share of pd (%), mean=pd per scandal"
di as txt "{hline 92}"
di as txt %-26s "Cell" %8s "pd" %8s "ep" %7s "ns" %9s "top1%" %9s "mean"
di as txt "{hline 92}"
foreach mrg in v p {
	if "`mrg'" == "v" di as result _n "  --- VIOLENT ---"
	else              di as result _n "  --- PEACEFUL ---"
	foreach ap in 1 0 {
		if `ap' == 1 local aplab "Apex"
		else         local aplab "Non-Apex"
		foreach cl in corr unrel {
			if "`cl'" == "corr" local cllab "Corruption-related"
			else                local cllab "Unrelated"
			use `byscandal', clear
			keep if apex == `ap'
			quietly summarize pd_g`cl'_`mrg'
			local tot = r(sum)
			local mx  = r(max)
			local nS  = r(N)
			quietly summarize on_g`cl'_`mrg'
			local ep = r(sum)
			quietly count if pd_g`cl'_`mrg' > 0
			local ns = r(N)
			if `tot' > 0 local top1 = 100*`mx'/`tot'
			else         local top1 = 0
			local meanps = `tot'/`nS'
			di as result %-26s "`aplab' x `cllab'" %8.0f `tot' %8.0f `ep' %7.0f `ns' %9.1f `top1' %9.3f `meanps'
		}
	}
}
di as txt "{hline 92}"

/* ---- daily-panel sparsity over the full +-30 window ---- */
di as txt _n "Daily-panel sparsity over the +-30 window (mean daily count; % of country-days with >=1):"
use `panel30', clear
foreach mrg in v p {
	foreach ap in 1 0 {
		if `ap' == 1 local aplab "Apex"
		else         local aplab "Non-Apex"
		foreach cl in corr unrel {
			quietly summarize pd_g`cl'_`mrg' if apex == `ap'
			local mn = r(mean)
			quietly count if apex == `ap'
			local nn = r(N)
			quietly count if apex == `ap' & pd_g`cl'_`mrg' > 0
			local nz = 100*r(N)/`nn'
			di as result %-26s "`aplab' x `cl' `mrg'" "  mean=" %6.4f `mn' "   nonzero=" %5.2f `nz' "%   (N=" `nn' ")"
		}
	}
}
display in green _n "g_summary_stats.do finished OK"
