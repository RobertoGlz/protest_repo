/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-07-27

    Objective:
        Treat the scandal disclosure as a REGRESSION DISCONTINUITY IN TIME.
        The running variable is the event-time day (window), the cutoff is the
        disclosure date (window = 0), and treatment is Post = 1{window >= 0}.
        A polynomial in window---allowed to differ on each side of the cutoff---
        models the smooth (pre- and post-scandal) trend; the discontinuity at
        0, tau, is the immediate effect of disclosure, net of that trend.  This
        handles the incoming pre-scandal trend directly, without the modern-DiD
        machinery.

           Y_{c(s)t} = tau*Post + f(window) + Post*g(window)
                     + alpha_d + lambda_m + theta_cy + eps

        With window centred at 0, the coefficient on Post is exactly the jump
        at the cutoff.  Estimated SEPARATELY on the apex (pa) and non-apex (na)
        subsamples, for bandwidths h in {30, 60} days and polynomial orders
        p in {1 (local linear), 2 (local quadratic)}.

    Inputs:
        - ${datfin}/protests_scandals_30days_v3.dta
        - ${datfin}/scandals_classified.csv

    Outputs (paper/{tables,figures}/):
        - sup_rd_time.tex                              (RD jump estimates)
        - rd_time_<outcome>_<sample>.pdf               (RD plots, h=60, linear)
---------------------------------------------------------------------------- */

capture log close _all
log using "a_rd_time_pa_vs_na_run.log", replace text

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

local firstyear = 2008

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

/* running variable centred at the cutoff; Post = 1{window >= 0} */
gen double rv   = window
gen byte   Post = (window >= 0)

tempfile base
save `base'

/* ============================================================
   ESTIMATION: RD jump (tau) for sample x outcome x bandwidth x poly
   ============================================================ */
tempname R
tempfile rdres
postfile `R' str4 sample str16 outcome int bw int poly ///
	double tau double se double n double nsc double mn double hbw double neff ///
	using "`rdres'", replace

foreach sample in pa na {
foreach oc in num_violent_MM num_peaceful_MM {
foreach BW in 30 60 90 {

	/* local linear: Post + rv + Post#rv.  This regression also fixes the
	   column's sample size (N), number of scandals, and pre-scandal control
	   mean, all reported at the foot of the table for comparability. */
	use `base', clear
	quietly reghdfe `oc' i.Post##c.rv ///
		if year >= `firstyear' & abs(rv) <= `BW' & in_`sample' == 1, ///
		absorb(month day auxvar) cluster(group_cluster)
	local Nlin = e(N)
	quietly levelsof id if e(sample), local(_ids)
	local nsc : word count `_ids'
	quietly summarize `oc' if e(sample) & rv >= -`BW' & rv <= -1
	local mn = r(mean)
	post `R' ("`sample'") ("`oc'") (`BW') (1) ///
		(_b[1.Post]) (_se[1.Post]) (`Nlin') (`nsc') (`mn') (.) (.)

	/* local quadratic: Post + rv + rv^2, each interacted with Post */
	use `base', clear
	quietly reghdfe `oc' i.Post##c.rv i.Post##c.rv#c.rv ///
		if year >= `firstyear' & abs(rv) <= `BW' & in_`sample' == 1, ///
		absorb(month day auxvar) cluster(group_cluster)
	post `R' ("`sample'") ("`oc'") (`BW') (2) ///
		(_b[1.Post]) (_se[1.Post]) (e(N)) (.) (.) (.) (.)

	/* nonparametric: rdrobust (MSE-optimal data-driven bandwidth, triangular
	   kernel) on the FE-residualised outcome, restricted to the +-BW window.
	   We also keep the selected bandwidth and the effective (in-bandwidth)
	   observations -- the standard reported quantities for an RD estimate. */
	use `base', clear
	keep if year >= `firstyear' & abs(rv) <= `BW' & in_`sample' == 1
	quietly reghdfe `oc', absorb(month day auxvar) residuals(_ryr)
	capture rdrobust _ryr rv, c(0) kernel(triangular) bwselect(mserd) ///
		vce(cluster group_cluster)
	if _rc == 0 {
		local heff = e(h_l)
		local neff = e(N_h_l) + e(N_h_r)
		post `R' ("`sample'") ("`oc'") (`BW') (3) ///
			(e(tau_cl)) (e(se_tau_cl)) (e(N)) (.) (.) (`heff') (`neff')
	}
	else {
		post `R' ("`sample'") ("`oc'") (`BW') (3) (.) (.) (.) (.) (.) (.) (.)
	}
}
}
}
postclose `R'

/* ============================================================
   TABLE: rows = Apex/Non-Apex x poly; cols = Violent/Non... x bw
   ============================================================ */
use "`rdres'", clear
capture file close _tbl
file open _tbl using "${tabout}/sup_rd_time.tex", write replace
file write _tbl "{" _n
file write _tbl "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
file write _tbl "\begin{tabular}{ll*{6}{c}}" _n
file write _tbl "\toprule" _n
file write _tbl " & & \multicolumn{3}{c}{Violent Protests} & \multicolumn{3}{c}{Peaceful Protests} \\" _n
file write _tbl "\cmidrule(lr){3-5}\cmidrule(lr){6-8}" _n
file write _tbl " & & \ensuremath{h=30} & \ensuremath{h=60} & \ensuremath{h=90} & \ensuremath{h=30} & \ensuremath{h=60} & \ensuremath{h=90} \\" _n
file write _tbl "\midrule" _n

foreach s in pa na {
	if "`s'" == "pa" local slab "Apex"
	else             local slab "Non-Apex"
	file write _tbl "\multicolumn{8}{l}{\textit{`slab'}}\\" _n
	foreach p in 1 2 3 {
		if `p' == 1 local plab "Local linear"
		else if `p' == 2 local plab "Local quadratic"
			else             local plab "Nonparametric"
		local brow "`plab' &"
		local srow " &"
		foreach oc in num_violent_MM num_peaceful_MM {
		foreach BW in 30 60 90 {
			quietly summarize tau if sample=="`s'" & outcome=="`oc'" & bw==`BW' & poly==`p', meanonly
			local b = r(mean)
			quietly summarize se if sample=="`s'" & outcome=="`oc'" & bw==`BW' & poly==`p', meanonly
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
	/* --- foot statistics: standard RD quantities (bandwidth, effective
	   observations) plus the sample size, number of scandals, and pre-scandal
	   control mean reported by the paper's other tables --- */
	file write _tbl "\addlinespace" _n
	foreach st in hbw neff n nsc mn {
		if "`st'" == "hbw"  local stlab "MSE-optimal bandwidth (days)"
		if "`st'" == "neff" local stlab "Effective observations"
		if "`st'" == "n"    local stlab "Observations"
		if "`st'" == "nsc"  local stlab "Number of scandals"
		if "`st'" == "mn"   local stlab "Mean (pre-scandal)"
		if "`st'" == "hbw" | "`st'" == "neff" local psel 3
		else                                  local psel 1
		local row "\multicolumn{2}{l}{`stlab'}"
		foreach oc in num_violent_MM num_peaceful_MM {
		foreach BW in 30 60 90 {
			quietly summarize `st' if sample=="`s'" & outcome=="`oc'" & bw==`BW' & poly==`psel', meanonly
			local v = r(mean)
			if missing(`v') local cell "--"
			else if "`st'" == "mn"  local cell = string(`v', "%5.3f")
			else if "`st'" == "hbw" local cell = string(`v', "%4.1f")
			else                    local cell = string(`v', "%9.0fc")
			local row "`row' & `cell'"
		}
		}
		file write _tbl "`row' \\" _n
	}
	if "`s'" == "pa" file write _tbl "\midrule" _n
}
file write _tbl "\bottomrule" _n
file write _tbl "\end{tabular}" _n
file write _tbl "}" _n
file close _tbl
display in green "sup_rd_time.tex written"

/* ============================================================
   FIGURES: RD plots (residualise on FE, bin, fit each side).
   Linear and local-quadratic fits, at h = 30, 60, 90 days.
   Output: rd_time[_quad]_<outcome>_<sample>_h<BW>.pdf
   ============================================================ */

/* common y-range across all bandwidth x sample x outcome, so every RD plot
   (all bandwidths, both fits) shares one vertical scale for eyeballing */
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

foreach BW in 30 60 90 {
	local xs = 15
	if `BW' == 90 local xs = 30

foreach sample in pa na {
foreach oc in num_violent_MM num_peaceful_MM {

	use `base', clear
	keep if year >= `firstyear' & abs(rv) <= `BW' & in_`sample' == 1

	/* residualise the outcome on the fixed effects only */
	quietly reghdfe `oc', absorb(month day auxvar) residuals(ry)

	/* 5-day bins of the running variable, mean residual per bin */
	gen int wbin = 5 * floor(rv / 5) + 2          /* bin centre */
	preserve
		collapse (mean) ry (mean) rvbar = rv, by(wbin)
		gen byte Postb = (wbin >= 0)

		/* local-linear fit each side */
		twoway (scatter ry wbin, mcolor(navy%70) msymbol(O) msize(small)) ///
		       (lfit ry wbin if wbin < 0,  lcolor(navy)      lwidth(medthick)) ///
		       (lfit ry wbin if wbin >= 0, lcolor(cranberry) lwidth(medthick)), ///
			ytitle("Protest count (residualised)", size(medium)) ///
			xtitle("Days since scandal", size(medium)) ///
			xlabel(-`BW'(`xs')`BW') ///
			yscale(range(`ylo' `yhi')) ylabel(`ylo'(0.02)`yhi', format(%4.3fc) angle(horizontal)) ///
			legend(off) ///
			graphregion(color(white) fcolor(white)) scheme(s2color)
		graph export "${figout}/rd_time_`oc'_`sample'_h`BW'.pdf", replace

		/* local-quadratic fit each side */
		twoway (scatter ry wbin, mcolor(navy%70) msymbol(O) msize(small)) ///
		       (qfit ry wbin if wbin < 0,  lcolor(navy)      lwidth(medthick)) ///
		       (qfit ry wbin if wbin >= 0, lcolor(cranberry) lwidth(medthick)), ///
			ytitle("Protest count (residualised)", size(medium)) ///
			xtitle("Days since scandal", size(medium)) ///
			xlabel(-`BW'(`xs')`BW') ///
			yscale(range(`ylo' `yhi')) ylabel(`ylo'(0.02)`yhi', format(%4.3fc) angle(horizontal)) ///
			legend(off) ///
			graphregion(color(white) fcolor(white)) scheme(s2color)
		graph export "${figout}/rd_time_quad_`oc'_`sample'_h`BW'.pdf", replace
	restore
	drop ry wbin
}
}
}

display in green "a_rd_time_pa_vs_na.do finished OK"
capture log close _all
