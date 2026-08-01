/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-07-27

    Objective:
        Leave-one-out (LOO) robustness by scandal, on violent protests in the
        +-30-day window, for THREE splits (each a separate set of figures with a
        common y-axis WITHIN the split so panels are eyeball-comparable):

          - scandal type (interaction): Apex vs Non-Apex          [post_pa/post_na]
          - hierarchy (Table S5): President / Other Apex / Non-Apex
                                                       [post_pres/post_oa/post_ona]
          - democracy tercile: High / Medium / Low   [post_high/post_med/post_low]

        For each coefficient we drop, one at a time, each scandal belonging to
        that group, re-estimate, and plot the leave-one-out estimates (scandals
        on the x-axis, angled labels; estimate + 90% CI on the y-axis).  A red
        line marks the coefficient on all scandals; a faint black line marks 0.

    Outputs (paper/figures/): loo_scandal_beta_<grp>_violent_w30.pdf for
        grp in {apex, nonapex, pres, oa, ona, high, med, low}.
---------------------------------------------------------------------------- */

set more off
clear all

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

local firstyear = 2008
local WIN       = 30
local OUTCOME   = "num_violent_MM"
local zcrit     = invnormal(0.95)

/* --------------- Load + attach classification --------------- */
import delimited using "${datfin}/scandals_classified.csv", ///
	clear varnames(1) bindquotes(strict)
keep id country position
tempfile cls
save `cls'

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
merge m:1 id country using `cls', keep(1 3) generate(_mclass)

/* two-group flags */
gen byte in_pa = 0
replace in_pa = 1 if position == "president"
replace in_pa = 1 if position == "governor"
replace in_pa = 1 if position == "sc_judge_congressman" & ///
	inlist(id, "202", "NEW26", "NEW30", "332")
gen byte in_na = 0
replace in_na = 1 if position == "sc_judge_congressman" & ///
	!inlist(id, "202", "NEW26", "NEW30", "332")
replace in_na = 1 if position == "other_judiciary"
replace in_na = 1 if position == "others"

/* three-group hierarchy category (as in Table S5) */
gen byte apex_cat = .
replace apex_cat = 1 if position == "president"
replace apex_cat = 2 if position == "governor"
replace apex_cat = 2 if position == "sc_judge_congressman" & ///
	inlist(id, "202", "NEW26", "NEW30", "332")
replace apex_cat = 3 if position == "sc_judge_congressman" & ///
	!inlist(id, "202", "NEW26", "NEW30", "332")
replace apex_cat = 3 if position == "other_judiciary"
replace apex_cat = 3 if position == "others"

gen byte post_pa   = post * in_pa
gen byte post_na   = post * in_na
gen byte post_pres = post * (apex_cat == 1)
gen byte post_oa   = post * (apex_cat == 2)
gen byte post_ona  = post * (apex_cat == 3)

egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)

gen int _sy = year if window == 0
gen double _sd = date if window == 0
bysort country id: egen scanyear = max(_sy)
bysort country id: egen double scandate = max(_sd)
drop _sy _sd

/* WITHIN COUNTRY-YEAR ORDINAL: rank each scandal by disclosure date within its
   (country, year), so a figure label like "Peru - 2017 - 3" reads as the third
   Peru-2017 scandal (by date) -- easy to find in the date-sorted classification
   table, unlike a global running number.  cycount is how many scandals share
   that country-year, so singletons can drop the ordinal. */
preserve
	keep country id scandate scanyear
	duplicates drop
	bysort country scanyear (scandate id): gen int cyrank = _n
	bysort country scanyear: gen int cycount = _N
	keep country id cyrank cycount
	tempfile ord
	save `ord'
restore
merge m:1 country id using `ord', nogenerate

/* --- democracy terciles (V-Dem 2008), as in a_sup_democracy_terciles.do --- */
tempfile scdata
save `scdata'
capture confirm file "${identity}/Corrupcion/replication-package-jpe/data/raw/protest/VDEM/vdem cy full others.dta"
if _rc == 0 {
	use "${identity}/Corrupcion/replication-package-jpe/data/raw/protest/VDEM/vdem cy full others.dta", clear
}
else {
	use "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals/Data/raw/VDEM/VDEM CY Full Others.dta", clear
}
keep country_name year v2x_polyarchy
keep if year == 2008
replace country_name = "Dominican Republic" if country_name == "Dominican Rep."
rename country_name country
rename v2x_polyarchy elec_demo_index
keep country elec_demo_index
tempfile vdem
save `vdem'
use `scdata', clear
merge m:1 country using `vdem', keep(1 3) nogenerate
preserve
	keep if !missing(elec_demo_index)
	bysort country: keep if _n == 1
	xtile terc3 = elec_demo_index, nq(3)
	keep country terc3
	tempfile terc
	save `terc'
restore
merge m:1 country using `terc', keep(1 3) nogenerate
gen byte post_high = post * (terc3 == 3)
gen byte post_med  = post * (terc3 == 2)
gen byte post_low  = post * (terc3 == 1)

tempfile base
save `base'

/* ---- full-sample coefficients (red reference lines) ---- */
use `base', clear
reghdfe `OUTCOME' post_pa post_na i.month i.day ///
	if year >= `firstyear' & abs(window) <= `WIN' & (in_pa == 1 | in_na == 1), ///
	absorb(i.country_id#i.year) vce(cluster i.country_id#i.year#i.grupo_dias)
scalar b_apex    = _b[post_pa]
scalar b_nonapex = _b[post_na]

use `base', clear
reghdfe `OUTCOME' post_pres post_oa post_ona i.month i.day ///
	if year >= `firstyear' & abs(window) <= `WIN' & !missing(apex_cat), ///
	absorb(i.country_id#i.year) vce(cluster i.country_id#i.year#i.grupo_dias)
scalar b_pres = _b[post_pres]
scalar b_oa   = _b[post_oa]
scalar b_ona  = _b[post_ona]

use `base', clear
reghdfe `OUTCOME' post_high post_med post_low i.month i.day ///
	if year >= `firstyear' & abs(window) <= `WIN' & !missing(terc3), ///
	absorb(i.country_id#i.year) vce(cluster i.country_id#i.year#i.grupo_dias)
scalar b_high = _b[post_high]
scalar b_med  = _b[post_med]
scalar b_low  = _b[post_low]

/* ---- per-group settings ---- */
capture program drop grpset
program define grpset
	args grp
	if "`grp'" == "apex" {
		global g_rhs "post_pa post_na"
		global g_coef "post_pa"
		global g_samp "(in_pa == 1 | in_na == 1)"
		global g_mem "in_pa == 1"
		global g_split "sc"
		global g_bf "b_apex"
		global g_ytit "Leave-one-out estimate"
	}
	else if "`grp'" == "nonapex" {
		global g_rhs "post_pa post_na"
		global g_coef "post_na"
		global g_samp "(in_pa == 1 | in_na == 1)"
		global g_mem "in_na == 1"
		global g_split "sc"
		global g_bf "b_nonapex"
		global g_ytit "Leave-one-out estimate"
	}
	else if "`grp'" == "pres" {
		global g_rhs "post_pres post_oa post_ona"
		global g_coef "post_pres"
		global g_samp "!missing(apex_cat)"
		global g_mem "apex_cat == 1"
		global g_split "hier"
		global g_bf "b_pres"
		global g_ytit "Leave-one-out estimate"
	}
	else if "`grp'" == "oa" {
		global g_rhs "post_pres post_oa post_ona"
		global g_coef "post_oa"
		global g_samp "!missing(apex_cat)"
		global g_mem "apex_cat == 2"
		global g_split "hier"
		global g_bf "b_oa"
		global g_ytit "Leave-one-out estimate"
	}
	else if "`grp'" == "ona" {
		global g_rhs "post_pres post_oa post_ona"
		global g_coef "post_ona"
		global g_samp "!missing(apex_cat)"
		global g_mem "apex_cat == 3"
		global g_split "hier"
		global g_bf "b_ona"
		global g_ytit "Leave-one-out estimate"
	}
	else if "`grp'" == "high" {
		global g_rhs "post_high post_med post_low"
		global g_coef "post_high"
		global g_samp "!missing(terc3)"
		global g_mem "terc3 == 3"
		global g_split "demo"
		global g_bf "b_high"
		global g_ytit "Leave-one-out estimate"
	}
	else if "`grp'" == "med" {
		global g_rhs "post_high post_med post_low"
		global g_coef "post_med"
		global g_samp "!missing(terc3)"
		global g_mem "terc3 == 2"
		global g_split "demo"
		global g_bf "b_med"
		global g_ytit "Leave-one-out estimate"
	}
	else {
		global g_rhs "post_high post_med post_low"
		global g_coef "post_low"
		global g_samp "!missing(terc3)"
		global g_mem "terc3 == 1"
		global g_split "demo"
		global g_bf "b_low"
		global g_ytit "Leave-one-out estimate"
	}
end

/* ============================================================
   PASS 1 - run each LOO, store estimates
   ============================================================ */
tempname A
tempfile allres
postfile `A' str8 grp str8 split int sid double est double se str48 lab ///
	using "`allres'", replace

foreach grp in apex nonapex pres oa ona high med low {
	grpset "`grp'"
	local IF "year >= `firstyear' & abs(window) <= `WIN' & ${g_samp}"

	use `base', clear
	keep if `IF' & ${g_mem}
	keep country id scanyear cyrank cycount
	duplicates drop
	sort country id
	local NS = _N
	forvalues i = 1/`NS' {
		local ctry`i' = country[`i']
		local idv`i'  = id[`i']
		local yr`i'   = scanyear[`i']
		local cyr`i'  = cyrank[`i']
		local cyc`i'  = cycount[`i']
	}
	di as result "Group `grp' [${g_split}]: `NS' scandals..."

	use `base', clear
	forvalues i = 1/`NS' {
		local c "`ctry`i''"
		local s "`idv`i''"
		capture reghdfe `OUTCOME' ${g_rhs} i.month i.day ///
			if `IF' & !(country == "`c'" & id == "`s'"), ///
			absorb(i.country_id#i.year) vce(cluster i.country_id#i.year#i.grupo_dias)
		if _rc continue
		/* Country - Year, plus a within-country-year ordinal (by date) when
		   that country-year has more than one scandal, e.g. "Peru - 2017 - 3" */
		if `cyc`i'' > 1 local lab "`ctry`i'' - `yr`i'' - `cyr`i''"
		else            local lab "`ctry`i'' - `yr`i''"
		post `A' ("`grp'") ("${g_split}") (`i') (_b[${g_coef}]) (_se[${g_coef}]) ("`lab'")
	}
}
postclose `A'

/* ---- common y-range per split (constant within split), in scalars ---- */
use "`allres'", clear
gen double lo = est - `zcrit' * se
gen double hi = est + `zcrit' * se
foreach sp in sc hier demo {
	quietly summarize lo if split == "`sp'"
	scalar rmin = r(min)
	quietly summarize hi if split == "`sp'"
	scalar rmax = r(max)
	scalar rpad = 0.05 * (rmax - rmin)
	scalar ylo_`sp' = rmin - rpad
	scalar yhi_`sp' = rmax + rpad
	/* nice label step spanning the full range (~7 ticks) */
	scalar rraw = (yhi_`sp' - ylo_`sp') / 7
	scalar rmag = 10 ^ floor(log10(rraw))
	scalar rmul = rraw / rmag
	if      rmul < 1.5 scalar step_`sp' = 1  * rmag
	else if rmul < 3.5 scalar step_`sp' = 2  * rmag
	else if rmul < 7.5 scalar step_`sp' = 5  * rmag
	else               scalar step_`sp' = 10 * rmag
	scalar lolab_`sp' = ceil(ylo_`sp' / step_`sp') * step_`sp'
	scalar hilab_`sp' = floor(yhi_`sp' / step_`sp') * step_`sp'
}

/* ============================================================
   PASS 2 - plot each group with its split's common y-range
   ============================================================ */
/* Common FIGURE SIZE within each split: use the largest group's scandal
   count to set ONE width for every panel in the split, so all panels share
   an identical aspect ratio (and hence an identical visual y-scale once each
   is displayed at the same width in the paper). */
foreach sp in sc hier demo {
	scalar nmax_`sp' = 0
}
use "`allres'", clear
foreach grp in apex nonapex pres oa ona high med low {
	grpset "`grp'"
	local sp2 "${g_split}"
	quietly count if grp == "`grp'"
	scalar nmax_`sp2' = max(nmax_`sp2', r(N))
}

foreach grp in apex nonapex pres oa ona high med low {
	grpset "`grp'"
	local sp "${g_split}"
	scalar bfull = ${g_bf}
	if "`sp'" == "sc" {
		local ylo = ylo_sc
		local yhi = yhi_sc
		local ylab = lolab_sc
		local yhib = hilab_sc
		local ystp = step_sc
	}
	if "`sp'" == "hier" {
		local ylo = ylo_hier
		local yhi = yhi_hier
		local ylab = lolab_hier
		local yhib = hilab_hier
		local ystp = step_hier
	}
	if "`sp'" == "demo" {
		local ylo = ylo_demo
		local yhi = yhi_demo
		local ylab = lolab_demo
		local yhib = hilab_demo
		local ystp = step_demo
	}

	use "`allres'", clear
	keep if grp == "`grp'"
	gen double lo = est - `zcrit' * se
	gen double hi = est + `zcrit' * se
	gsort est
	gen int rank = _n
	capture label drop rlab
	forvalues i = 1/`=_N' {
		local L = lab[`i']
		label define rlab `i' "`L'", add
	}
	label values rank rlab
	/* width from the split's LARGEST group, so every panel in the split is
	   the same physical size (identical aspect ratio and visual y-scale) */
	if "`sp'" == "sc"   local nmx = nmax_sc
	if "`sp'" == "hier" local nmx = nmax_hier
	if "`sp'" == "demo" local nmx = nmax_demo
	/* minimum width keeps a wide/short aspect so that a 3-panel split (e.g.
	   the democracy terciles) fits on a single page when stacked */
	local wd = max(13, `nmx' * 0.13)

	twoway (rspike lo hi rank, lcolor(gs8) lwidth(thin)) ///
	       (scatter est rank, mcolor(navy) msymbol(O) msize(small)), ///
		yline(0, lcolor(black%10) lwidth(vvthick) lpattern(solid)) ///
		yline(`=bfull', lcolor(red) lwidth(medthick) lpattern(solid)) ///
		yscale(range(`ylo' `yhi')) ///
		ylabel(`ylab'(`ystp')`yhib', angle(horizontal) format(%4.3fc)) ///
		ytitle("${g_ytit}", size(medium)) ///
		xtitle("") ///
		xlabel(1(1)`=_N', valuelabel labsize(tiny) angle(90) nogrid) ///
		xscale(range(0 `=_N+1')) ///
		legend(off) ///
		note("Red line: coefficient estimated on all scandals.", size(small)) ///
		graphregion(color(white) fcolor(white)) scheme(s2color) ///
		xsize(`wd') ysize(4.3)
	graph export "${figout}/loo_scandal_beta_`grp'_violent_w`WIN'.pdf", replace
	display in green "loo_scandal_beta_`grp'_violent_w`WIN'.pdf written"
}

display in green "a_loo_scandal_pa_vs_na.do finished OK"
