/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-07-27

    Objective:
        Complements the parametric RD-in-time (a_rd_time_pa_vs_na.do) with:
          (1) a NON-PARAMETRIC RD estimate -- local-polynomial (lpoly) fit via
              rdrobust with an MSE-optimal, data-driven bandwidth and a
              triangular kernel -- using the rdd_lpoly program; and
          (2) a local-QUADRATIC polynomial RD plot.
        In both, the outcome is first residualised on the country-by-year,
        month-of-year and day-of-week fixed effects, so the RD is on the same
        variation as the rest of the paper.

    Requires: rdrobust  (ssc install rdrobust, replace)

    Outputs (paper/{tables,figures}/):
        - rd_time_np_<outcome>_<sample>.pdf     (lpoly fit + CI + binned means)
        - sup_rd_time_np.tex                     (non-parametric RD estimates)
---------------------------------------------------------------------------- */

capture log close _all
log using "a_rd_time_np_pa_vs_na_run.log", replace text

set more off
clear all

capture which rdrobust
if _rc ssc install rdrobust, replace

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
global tabout  "${identity}/Corrupcion/protest_repo/paper/tables"
global figout  "${identity}/Corrupcion/protest_repo/paper/figures"
global progdir "${identity}/Corrupcion/protest_repo/code/programs"

do "${progdir}/rdd_lpoly.do"

local firstyear = 2008
local BW = 60                        /* window for the plots / residualisation */

/* --------------- Load + attach classification --------------- */
import delimited using "${datfin}/scandals_classified.csv", ///
	clear varnames(1) bindquotes(strict)
keep id country position
tempfile cls
save `cls'

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
merge m:1 id country using `cls', keep(1 3) generate(_mclass)

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

egen grupo_dias    = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                           s_lead30 s_lead60 s_lead90 s_lead120)
egen group_cluster = group(country_id year grupo_dias)
egen auxvar        = group(country year)

gen double rv = window

tempfile base
save `base'

/* --- common y-range across all bandwidth x sample x outcome (same rule as
   the parametric figures, so every RD figure shares one vertical scale) --- */
local gmax = 0
foreach BW in 30 60 90 {
foreach sample in pa na {
foreach oc in num_violent_MM num_peaceful_MM {
	use `base', clear
	keep if year >= `firstyear' & abs(rv) <= `BW' & in_`sample' == 1
	quietly reghdfe `oc', absorb(month day auxvar) residuals(_ry0)
	gen int _wb0 = 5 * floor(rv / 5) + 2
	quietly collapse (mean) _ry0, by(_wb0)
	quietly summarize _ry0
	local gmax = max(`gmax', abs(r(min)), abs(r(max)))
}
}
}
local yr  = ceil((`gmax' * 1.6) / 0.02) * 0.02
local ylo = -`yr'
local yhi =  `yr'
di as result "Common RD y-range: [`ylo', `yhi']"

/* ============================================================
   NON-PARAMETRIC (rdrobust/lpoly), per bandwidth x sample x outcome.
   The estimation window is +-30/60/90; within each window rdrobust selects
   its own MSE-optimal bandwidth for the local-linear fit.
   Output: rd_time_np_<outcome>_<sample>_h<BW>.pdf
   ============================================================ */
tempname R
tempfile rdnp
postfile `R' str4 sample str16 outcome int bw ///
	double tau double se double pval double h using "`rdnp'", replace

foreach BW in 30 60 90 {
	local xs = 15
	if `BW' == 90 local xs = 30

foreach sample in pa na {
foreach oc in num_violent_MM num_peaceful_MM {

	use `base', clear
	keep if year >= `firstyear' & abs(rv) <= `BW' & in_`sample' == 1

	/* residualise on the fixed effects */
	quietly reghdfe `oc', absorb(month day auxvar) residuals(ry)

	/* non-parametric local-polynomial RD via rdd_lpoly */
	capture noisily rdd_lpoly, outcome(ry) runvar(rv) ///
		rangemin(-`BW') rangemax(`BW') cluster(group_cluster) ///
		kernel(triangular) bwscale(1) bwselect(mserd) ///
		outputfolder("${figout}") graphname("rd_time_np_`oc'_`sample'_h`BW'") ///
		ytitle("Protest count (residualised)") cilevel(90) xstep(`xs') ///
		ylo(`ylo') yhi(`yhi') ystep(0.02)
	if _rc == 0 {
		post `R' ("`sample'") ("`oc'") (`BW') (r(tau)) (r(se)) (r(pval)) (r(h))
	}
	else {
		display in red "rdd_lpoly failed for `oc' [`sample'] h`BW'"
		post `R' ("`sample'") ("`oc'") (`BW') (.) (.) (.) (.)
	}
	drop ry
}
}
}
postclose `R'

/* ============================================================
   TABLE: non-parametric (rdrobust) RD estimates, windows h in {30,60,90}
   ============================================================ */
use "`rdnp'", clear
capture file close _tbl
file open _tbl using "${tabout}/sup_rd_time_np.tex", write replace
file write _tbl "{" _n
file write _tbl "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
file write _tbl "\begin{tabular}{l*{6}{c}}" _n
file write _tbl "\toprule" _n
file write _tbl " & \multicolumn{3}{c}{Violent Protests} & \multicolumn{3}{c}{Peaceful Protests} \\" _n
file write _tbl "\cmidrule(lr){2-4}\cmidrule(lr){5-7}" _n
file write _tbl " & \ensuremath{h=30} & \ensuremath{h=60} & \ensuremath{h=90} & \ensuremath{h=30} & \ensuremath{h=60} & \ensuremath{h=90} \\" _n
file write _tbl "\midrule" _n
foreach s in pa na {
	if "`s'" == "pa" local slab "Apex"
	else             local slab "Non-Apex"
	local brow "`slab'"
	local srow " "
	foreach oc in num_violent_MM num_peaceful_MM {
	foreach BW in 30 60 90 {
		quietly summarize tau if sample=="`s'" & outcome=="`oc'" & bw==`BW', meanonly
		local b = r(mean)
		quietly summarize se if sample=="`s'" & outcome=="`oc'" & bw==`BW', meanonly
		local se = r(mean)
		if missing(`b') | missing(`se') | `se' <= 0 {
			local brow "`brow' & --"
			local srow "`srow' & "
		}
		else {
			local pv = 2*normal(-abs(`b'/`se'))
			local st = ""
			if `pv' < 0.10 local st = "*"
			if `pv' < 0.05 local st = "**"
			if `pv' < 0.01 local st = "***"
			if "`st'" != "" local bcell = string(`b',"%5.3f") + "\sym{`st'}"
			else            local bcell = string(`b',"%5.3f")
			local scell = "(" + string(`se',"%5.3f") + ")"
			local brow "`brow' & `bcell'"
			local srow "`srow' & `scell'"
		}
	}
	}
	file write _tbl "`brow' \\" _n
	file write _tbl "`srow' \\" _n
}
file write _tbl "\bottomrule" _n
file write _tbl "\end{tabular}" _n
file write _tbl "}" _n
file close _tbl
display in green "sup_rd_time_np.tex written"

display in green "a_rd_time_np_pa_vs_na.do finished OK"
capture log close _all
