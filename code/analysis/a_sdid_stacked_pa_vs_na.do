/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-08-03

    Objective:
        Synthetic difference-in-differences (Arkhangelsky, Athey, Hainmueller,
        Imbens & Wager 2021) estimate of the effect of a scandal disclosure on
        daily protest counts, run PER SCANDAL and then averaged (a "stacked"
        SDID), because a country experiences many scandals over time and SDID
        assumes an absorbing treatment.

        For each scandal s (country c_s, disclosure date t0_s) and each window
        K in {30,60,90} days:
          - treated unit  = c_s, "adopting" at event day 0 (t0_s);
          - donor pool     = every other country (Venezuela excluded) that has
                             NO scandal in the PRE-scandal window [t0_s-K, t0_s-1]
                             and is fully observed over [t0_s-K, t0_s+K];
          - panel          = country x event-day, balanced by construction;
          - estimate tau_s = e(ATT) from  sdid Y country day treat, method(sdid).
        We do this for the apex and non-apex partitions and for violent and
        peaceful protests (mm_violent / mm_nonviolent).

        Aggregation: for each (partition, outcome, window) the reported effect is
        the mean of tau_s across scandals, with a standard error clustered by
        country (regression of tau_s on a constant) -- so repeated scandals in
        the same country are not treated as independent.

        Per-scandal inference is skipped (vce(noinference)); the estimand is the
        average across scandals, and inference is done at that level.

    Requires: sdid  (ssc install sdid)

    Inputs:
        - ${datfin}/scandals_classified.csv          (position -> apex/non-apex)
        - ${datfin}/protests_scandals_30days_v3.dta   (canonical scandal set + dates)
        - ${datfin}/panel_country_day.dta             (donor pool: all countries,
                                                        daily protest counts)
    Output:
        - ${tables}/sup_sdid_stacked.tex              (SDID table, 6 columns)
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
global tables  "${identity}/Corrupcion/protest_repo/paper/tables"

/* ============================================================
   STEP 1 - canonical scandal list (paper's 176) with dates + apex partition v2
   ============================================================ */
import delimited using "${datfin}/scandals_classified.csv", ///
	clear varnames(1) bindquotes(strict)
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
merge m:1 id country using `cls', keep(3) nogenerate

gen byte in_pa = 0
replace in_pa = 1 if position == "president"
replace in_pa = 1 if position == "governor"
replace in_pa = 1 if position == "sc_judge_congressman" & inlist(id, "202", "NEW26", "NEW30", "332")

gen double _sd = date if window == 0
bysort country id: egen double scandate = max(_sd)
keep country id scandate in_pa
duplicates drop
drop if missing(scandate)
gsort scandate country id

local NS = _N
di as result "scandals: `NS'"
quietly summarize scandate
local dlo = r(min) - 100
local dhi = r(max) + 100
/* stash the scandal attributes in locals */
forvalues i = 1/`NS' {
	local sc_c`i'  = country[`i']
	local sc_t`i'  = scandate[`i']
	local sc_pa`i' = in_pa[`i']
}

/* ============================================================
   STEP 2 - donor panel (all countries, daily), trimmed to the relevant span
   ============================================================ */
use "${datfin}/panel_country_day", clear
drop if country == "Venezuela"
capture confirm variable id
if _rc==0 {
	drop if id == "TWNEWLATINO14" & country == "Ecuador"   // duplicate of scandal 108 (Alex Bravo, Petroecuador)
	drop if id == "TWNEWLATINO23" & country == "Brazil"     // Gurgel statement, not a corruption scandal
}
keep if inrange(date, `dlo', `dhi')
keep country date mm_violent mm_nonviolent scandal_today
tempfile daily
save `daily'

/* ============================================================
   STEP 3 - per-scandal SDID, looped over window x scandal (both outcomes)
   ============================================================ */
tempname P
tempfile res
postfile `P' byte apex str16 outcome int win str24 country double tau int ndonor ///
	using "`res'", replace

foreach K in 30 60 90 {
	forvalues i = 1/`NS' {
		local c  "`sc_c`i''"
		local t0 = `sc_t`i''

		use `daily', clear
		keep if inrange(date, `t0'-`K', `t0'+`K')

		/* donor eligibility: no scandal in the PRE-window [t0-K, t0-1] */
		gen byte _pre = (scandal_today == 1) & (date < `t0')
		bysort country: egen byte _haspre = max(_pre)
		keep if country == "`c'" | _haspre == 0

		/* balance: keep only fully-observed countries over the window */
		bysort country: gen int _nd = _N
		keep if _nd == `=2*`K'+1'

		/* need the treated country + at least 2 donors */
		quietly levelsof country, local(cc)
		local ncty : word count `cc'
		quietly count if country == "`c'"
		if `ncty' < 3 | r(N) == 0 continue
		local ndon = `ncty' - 1

		gen int  tvar  = date - `t0'
		gen byte treat = (country == "`c'") & (tvar >= 0)
		egen uid = group(country)

		foreach oc in mm_violent mm_nonviolent {
			capture sdid `oc' uid tvar treat, method(sdid) vce(noinference)
			if _rc continue
			post `P' (`sc_pa`i'') ("`oc'") (`K') ("`c'") (e(ATT)) (`ndon')
		}
	}
	di as result "window `K' done"
}
postclose `P'

/* persist the per-scandal estimates so the table (STEP 4-5) can be rebuilt
   without re-running the ~1000 SDID fits */
use "`res'", clear
save "${datfin}/sdid_perscandal_estimates.dta", replace

/* ============================================================
   STEP 4 - aggregate: mean tau by (apex, outcome, window), clustered by country
   ============================================================ */
use "${datfin}/sdid_perscandal_estimates.dta", clear
tempname R
tempfile agg
postfile `R' byte apex str16 outcome int win ///
	double att double se double pval int nsc double avgdon using "`agg'", replace

levelsof win, local(wins)
foreach a in 1 0 {
foreach oc in mm_violent mm_nonviolent {
foreach K of local wins {
	quietly count if apex==`a' & outcome=="`oc'" & win==`K'
	if r(N) == 0 continue
	quietly regress tau if apex==`a' & outcome=="`oc'" & win==`K', vce(cluster country)
	local b  = _b[_cons]
	local se = _se[_cons]
	local p  = 2*ttail(e(df_r), abs(`b'/`se'))
	quietly summarize ndonor if apex==`a' & outcome=="`oc'" & win==`K', meanonly
	local ad = r(mean)
	post `R' (`a') ("`oc'") (`K') (`b') (`se') (`p') (e(N)) (`ad')
}
}
}
postclose `R'

/* ============================================================
   STEP 5 - write the table (rows Apex/Non-Apex x estimate/se; cols outcome x K)
   ============================================================ */
use "`agg'", clear
capture file close _t
file open _t using "${tables}/sup_sdid_stacked.tex", write replace
file write _t "{" _n
file write _t "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
file write _t "\begin{tabular}{l*{6}{c}}" _n
file write _t "\toprule" _n
file write _t " & \multicolumn{3}{c}{Violent Protests} & \multicolumn{3}{c}{Peaceful Protests} \\" _n
file write _t "\cmidrule(lr){2-4}\cmidrule(lr){5-7}" _n
file write _t " & \ensuremath{K=30} & \ensuremath{K=60} & \ensuremath{K=90} & \ensuremath{K=30} & \ensuremath{K=60} & \ensuremath{K=90} \\" _n
file write _t "\midrule" _n

foreach a in 1 0 {
	if `a' == 1 local slab "Apex"
	else        local slab "Non-Apex"
	local brow "`slab'"
	local srow " "
	local nrow "\quad Number of scandals"
	local drow "\quad Avg.\ donor countries"
	foreach oc in mm_violent mm_nonviolent {
	foreach K in 30 60 90 {
		quietly summarize att if apex==`a' & outcome=="`oc'" & win==`K', meanonly
		local b = r(mean)
		quietly summarize se if apex==`a' & outcome=="`oc'" & win==`K', meanonly
		local s = r(mean)
		quietly summarize pval if apex==`a' & outcome=="`oc'" & win==`K', meanonly
		local pv = r(mean)
		quietly summarize nsc if apex==`a' & outcome=="`oc'" & win==`K', meanonly
		local nn = r(mean)
		quietly summarize avgdon if apex==`a' & outcome=="`oc'" & win==`K', meanonly
		local dd = r(mean)
		if missing(`b') {
			local brow "`brow' & --"
			local srow "`srow' & "
		}
		else {
			local st = ""
			if `pv' < 0.10 local st = "*"
			if `pv' < 0.05 local st = "**"
			if `pv' < 0.01 local st = "***"
			if "`st'" != "" local bc = string(`b',"%5.3f") + "\sym{`st'}"
			else            local bc = string(`b',"%5.3f")
			local brow "`brow' & `bc'"
			local srow = "`srow' & (" + string(`s',"%5.3f") + ")"
		}
		local nrow = "`nrow' & " + string(`nn',"%3.0f")
		local drow = "`drow' & " + string(`dd',"%3.1f")
	}
	}
	file write _t "`brow' \\" _n
	file write _t "`srow' \\" _n
	file write _t "`nrow' \\" _n
	file write _t "`drow' \\" _n
	if `a' == 1 file write _t "\midrule" _n
}
file write _t "\bottomrule" _n
file write _t "\end{tabular}" _n
file write _t "}" _n
file close _t
display in green "sup_sdid_stacked.tex written"
display in green "a_sdid_stacked_pa_vs_na.do finished OK"
