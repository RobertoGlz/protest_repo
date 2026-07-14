/* ----------------------------------------------------------------------------
					Violent effects of apex corruption

	Code author: Roberto Gonzalez
	Date: 2026-05-22

	Objective (protests_plan.md, Task 1):
		Re-estimate the headline "scandals raise (violent) protests" effect
		on the *balanced country-week panel* (panel_country_week.dta)
		using three modern staggered-DiD estimators against a TWFE OLS
		baseline:
		  - OLS   two-way FE (country + week)
		  - dCDH  (de Chaisemartin & D'Haultfoeuille):  did_multiplegt_dyn
		  - BJS   (Borusyak, Jaravel & Spiess):         did_imputation
		  - SA    (Sun & Abraham):                      eventstudyinteract

	Design:
		Unit:                country (23 LAC).
		Time:                week (Monday-anchored), 2008-W1..2020-W13.
		Treatment date:      country's FIRST scandal week.
		Treated cohort:      19 countries with >=1 scandal in the data.
		Never-treated cohort: Guyana, Haiti, Jamaica, Suriname.
		Outcomes:            mm_protests, mm_violent, mm_nonviolent, mm_gvr.

	Event-study window: 4 placebo weeks + 8 post weeks (event weeks -4..+7,
	reference = week -1).

	Outputs:
		${tabout}/did_modern_main.tex          (4x4 estimator x outcome,
		                                        two-row coef/SE, \sym stars)
		${figout}/did_modern_es_<outcome>.pdf  (combined event study, all
		                                        4 estimators overlaid)
---------------------------------------------------------------------------- */

if "`c(username)'" == "lalov" {
	gl identity "C:\Users\lalov\ITAM Seira Research Dropbox\Eduardo Rivera"
}
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox"
}
if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}

global work   "${identity}/Corrupcion/Protest_Work"
global path   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"
global tabout "${identity}/Corrupcion/protest_repo/paper/tables"
global figout "${identity}/Corrupcion/protest_repo/paper/figures"

/* ============================================================
   LOAD AND PREP
   ============================================================ */
use "${datfin}/panel_country_week.dta", clear

/* Restrict to 2008+ to match the rest of the analysis */
keep if year >= 2008

/* Integer week index (anchor on the data's first week so week_idx >= 1) */
quietly summarize week_start
local week0 = r(min)
gen long week_idx = (week_start - `week0') / 7 + 1
label variable week_idx "Week index (1 = first week in the sample)"
assert week_idx >= 1

/* First-scandal week per country, aligned with week_idx */
gen long _fs_week_start = first_scandal_date - ///
	mod(first_scandal_date - mdy(1,4,2010), 7) if !missing(first_scandal_date)
gen long first_scandal_week_idx = (_fs_week_start - `week0') / 7 + 1 ///
	if !missing(_fs_week_start)
drop _fs_week_start
label variable first_scandal_week_idx "Week index of country's first scandal"

gen byte ever_treated = !missing(first_scandal_date)
gen byte D = ever_treated == 1 & week_idx >= first_scandal_week_idx
label variable D "Treated x post first-scandal week"

/* SA cohort: sentinel for never-treated; never-treated indicator */
gen long cohort = first_scandal_week_idx
replace cohort = 999999 if missing(cohort)
gen byte I_never_treated = (ever_treated == 0)

di as result "=== Treatment summary ==="
tab ever_treated, missing

xtset country_id week_idx

/* ============================================================
   EVENT-TIME DUMMIES for OLS and SA
   Event weeks -4,-3,-2  (placebos)  /  -1 omitted (reference)  /
   0..7 (post).  12 plot positions in total.
   ============================================================ */
gen long etime = week_idx - first_scandal_week_idx if ever_treated == 1

/* leads (omit -1 = reference) */
forvalues k = 2/4 {
	gen byte ev_lead`k' = (etime == -`k') & ever_treated == 1
}
/* lags */
forvalues k = 0/7 {
	gen byte ev_lag`k' = (etime == `k') & ever_treated == 1
}
local es_dummies ev_lead4 ev_lead3 ev_lead2 ev_lag0 ev_lag1 ev_lag2 ///
	ev_lag3 ev_lag4 ev_lag5 ev_lag6 ev_lag7

/* Plot grid: 12 columns -> event weeks -4,-3,-2,-1,0,1,2,3,4,5,6,7.
   Column 4 = week -1 = reference.  Matrix column <-> event week:
       col 1..3   = weeks -4,-3,-2
       col 4      = week -1 (reference, left at 0)
       col 5..12  = weeks 0..7                                        */

local outcomes mm_protests mm_violent mm_nonviolent mm_gvr

/* ============================================================
   MAIN LOOP OVER OUTCOMES: estimate all 4 estimators, build the
   combined event-study plot.
   ============================================================ */
local oc = 0
foreach y of local outcomes {
	local ++oc

	if "`y'" == "mm_protests"   local ytitle "Number of protests"
	if "`y'" == "mm_violent"    local ytitle "Number of violent protests"
	if "`y'" == "mm_nonviolent" local ytitle "Number of non-violent protests"
	if "`y'" == "mm_gvr"        local ytitle "Number of govt. violent responses"

	matrix M_ols_b  = J(1,12,0)
	matrix M_ols_se = J(1,12,0)
	matrix M_dcdh_b  = J(1,12,0)
	matrix M_dcdh_se = J(1,12,0)
	matrix M_bjs_b  = J(1,12,0)
	matrix M_bjs_se = J(1,12,0)
	matrix M_sa_b  = J(1,12,0)
	matrix M_sa_se = J(1,12,0)

	/* ---------- (1) OLS two-way FE ---------- */
	di as result "--- OLS: `y' ---"
	/* static ATT */
	reghdfe `y' D, absorb(country_id week_idx) cluster(country_id)
	scalar b_ols_`oc'  = _b[D]
	scalar se_ols_`oc' = _se[D]
	scalar n_ols_`oc'  = e(N)
	/* event study */
	quietly reghdfe `y' `es_dummies', absorb(country_id week_idx) cluster(country_id)
	matrix M_ols_b[1,1] = _b[ev_lead4]
	matrix M_ols_b[1,2] = _b[ev_lead3]
	matrix M_ols_b[1,3] = _b[ev_lead2]
	matrix M_ols_se[1,1] = _se[ev_lead4]
	matrix M_ols_se[1,2] = _se[ev_lead3]
	matrix M_ols_se[1,3] = _se[ev_lead2]
	forvalues k = 0/7 {
		matrix M_ols_b[1, 5+`k']  = _b[ev_lag`k']
		matrix M_ols_se[1, 5+`k'] = _se[ev_lag`k']
	}

	/* ---------- (2) dCDH ---------- */
	di as result "--- dCDH: `y' ---"
	capture noisily did_multiplegt_dyn `y' country_id week_idx D, ///
		effects(8) placebo(4) cluster(country_id) graph_off
	if _rc == 0 {
		scalar b_dcdh_`oc'  = e(Av_tot_effect)
		scalar se_dcdh_`oc' = e(se_avg_total_effect)
		/* placebos -> cols 1..4 (weeks -4..-1); effects -> cols 5..12 (weeks 0..7) */
		forvalues k = 1/4 {
			capture matrix M_dcdh_b[1, 5-`k']  = e(Placebo_`k')
			capture matrix M_dcdh_se[1, 5-`k'] = e(se_placebo_`k')
		}
		forvalues k = 1/8 {
			capture matrix M_dcdh_b[1, 4+`k']  = e(Effect_`k')
			capture matrix M_dcdh_se[1, 4+`k'] = e(se_effect_`k')
		}
	}
	else {
		scalar b_dcdh_`oc' = .
		scalar se_dcdh_`oc' = .
		display in red "dCDH failed for `y'"
	}

	/* ---------- (3) BJS (did_imputation) ---------- */
	di as result "--- BJS: `y' ---"
	/* static ATT */
	capture noisily did_imputation `y' country_id week_idx first_scandal_week_idx, ///
		autosample minn(0) delta(1) cluster(country_id)
	if _rc == 0 {
		scalar b_bjs_`oc'  = _b[tau]
		scalar se_bjs_`oc' = _se[tau]
	}
	else {
		scalar b_bjs_`oc' = .
		scalar se_bjs_`oc' = .
		display in red "BJS (static) failed for `y'"
	}
	/* event study: 8 horizons, 4 pretrends; normalise to pre1 (week -1) */
	capture noisily did_imputation `y' country_id week_idx first_scandal_week_idx, ///
		horizons(0/7) pretrends(4) autosample minn(0) delta(1) cluster(country_id)
	if _rc == 0 {
		forvalues k = 2/4 {
			capture quietly lincom pre`k' - pre1
			if _rc == 0 {
				matrix M_bjs_b[1, 5-`k']  = r(estimate)
				matrix M_bjs_se[1, 5-`k'] = r(se)
			}
		}
		forvalues k = 0/7 {
			capture quietly lincom tau`k' - pre1
			if _rc == 0 {
				matrix M_bjs_b[1, 5+`k']  = r(estimate)
				matrix M_bjs_se[1, 5+`k'] = r(se)
			}
		}
	}
	else {
		display in red "BJS (event study) failed for `y'"
	}

	/* ---------- (4) SA (eventstudyinteract) ---------- */
	di as result "--- SA: `y' ---"
	capture noisily eventstudyinteract `y' `es_dummies', ///
		cohort(cohort) control_cohort(I_never_treated) ///
		absorb(country_id week_idx) vce(cluster country_id)
	if _rc == 0 {
		matrix b_iw = e(b_iw)
		matrix V_iw = e(V_iw)
		/* leads -> cols 1..3 */
		local cc = 0
		foreach d in ev_lead4 ev_lead3 ev_lead2 {
			local ++cc
			local j = colnumb(b_iw, "`d'")
			if `j' < . {
				matrix M_sa_b[1, `cc']  = b_iw[1, `j']
				matrix M_sa_se[1, `cc'] = sqrt(V_iw[`j', `j'])
			}
		}
		/* lags -> cols 5..12 */
		forvalues k = 0/7 {
			local j = colnumb(b_iw, "ev_lag`k'")
			if `j' < . {
				matrix M_sa_b[1, 5+`k']  = b_iw[1, `j']
				matrix M_sa_se[1, 5+`k'] = sqrt(V_iw[`j', `j'])
			}
		}
		/* static = equally weighted avg of the 8 post coefficients */
		matrix wgt = J(1, colsof(b_iw), 0)
		local npost = 0
		forvalues k = 0/7 {
			local j = colnumb(b_iw, "ev_lag`k'")
			if `j' < . {
				matrix wgt[1, `j'] = 1
				local ++npost
			}
		}
		if `npost' > 0 {
			matrix wgt = wgt / `npost'
			matrix avg_b = wgt * b_iw'
			matrix avg_V = wgt * V_iw * wgt'
			scalar b_sa_`oc'  = avg_b[1,1]
			scalar se_sa_`oc' = sqrt(avg_V[1,1])
		}
	}
	else {
		scalar b_sa_`oc' = .
		scalar se_sa_`oc' = .
		display in red "SA failed for `y'"
	}

	/* ============================================================
	   COMBINED EVENT-STUDY PLOT (all 4 estimators, dodged)
	   ============================================================ */
	preserve
		clear
		set obs 12
		gen bin = _n - 5          /* event week: -4,-3,...,7 */
		foreach est in ols dcdh bjs sa {
			gen double b_`est'  = .
			gen double se_`est' = .
			forvalues j = 1/12 {
				replace b_`est'  = M_`est'_b[1, `j']  in `j'
				replace se_`est' = M_`est'_se[1, `j'] in `j'
			}
			/* drop the reference cell (week -1) for OLS/BJS/SA so it shows
			   as a clean 0 dot without a spurious CI; dCDH keeps its placebo */
			gen double ci_lo_`est' = b_`est' - 1.645 * se_`est'
			gen double ci_hi_`est' = b_`est' + 1.645 * se_`est'
		}
		/* dodge x-positions so the 4 estimators don't overlap */
		gen double bin_ols  = bin - 0.18
		gen double bin_dcdh = bin - 0.06
		gen double bin_bjs  = bin + 0.06
		gen double bin_sa   = bin + 0.18

		twoway ///
			(rspike ci_lo_ols  ci_hi_ols  bin_ols,  lcolor(navy)         lwidth(medthick)) ///
			(scatter b_ols  bin_ols,  mcolor(navy)         msymbol(O)  msize(medium)) ///
			(rspike ci_lo_dcdh ci_hi_dcdh bin_dcdh, lcolor(cranberry)    lwidth(medthick)) ///
			(scatter b_dcdh bin_dcdh, mcolor(cranberry)    msymbol(T)  msize(medium)) ///
			(rspike ci_lo_bjs  ci_hi_bjs  bin_bjs,  lcolor(forest_green) lwidth(medthick)) ///
			(scatter b_bjs  bin_bjs,  mcolor(forest_green) msymbol(D)  msize(medium)) ///
			(rspike ci_lo_sa   ci_hi_sa   bin_sa,   lcolor(midblue)      lwidth(medthick)) ///
			(scatter b_sa   bin_sa,   mcolor(midblue)      msymbol(Oh) msize(medium)), ///
			yline(0, lcolor(red) lpattern(solid) lwidth(medthin)) ///
			xline(-0.5, lcolor(black%20) lpattern(solid) lwidth(vthick)) ///
			xtitle("Weeks since first scandal", size(medium)) ///
			ytitle("`ytitle'", size(medium)) ///
			xlabel(-4(1)7, labsize(medium)) ///
			ylabel(, labsize(medium) format(%4.2fc)) ///
			legend(order(2 "OLS (TWFE)" 4 "dCDH" 6 "BJS" 8 "SA") ///
				rows(1) size(small) position(6) region(lcolor(none))) ///
			graphregion(color(white)) scheme(s2color)
		graph export "${figout}/did_modern_es_`y'.pdf", replace
	restore
}

/* ============================================================
   COMBINED 4 x 4 RESULTS TABLE  ->  did_modern_main.tex
   Two-row (coef / se) layout matching the paper's esttab tables;
   \sym{} stars from p = 2*Phi(-|b/se|) at 0.10 / 0.05 / 0.01.
   ============================================================ */
capture file close _tbl
file open _tbl using "${tabout}/did_modern_main.tex", write replace
file write _tbl "{" _n
file write _tbl "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
file write _tbl "\begin{tabular}{l*{4}{c}}" _n
file write _tbl "\toprule" _n
file write _tbl "            &\multicolumn{1}{c}{\shortstack{Protests}}&\multicolumn{1}{c}{\shortstack{Violent\\Protests}}&\multicolumn{1}{c}{\shortstack{Non-violent\\Protests}}&\multicolumn{1}{c}{\shortstack{Gvt.~Violent\\Response}}\\" _n
file write _tbl "\midrule" _n

foreach er in ols dcdh bjs sa {
	if "`er'" == "ols"  local rowlab "OLS (TWFE)"
	if "`er'" == "dcdh" local rowlab "dCDH"
	if "`er'" == "bjs"  local rowlab "BJS"
	if "`er'" == "sa"   local rowlab "SA"
	local brow "`rowlab'"
	local srow "            "
	foreach oc of numlist 1/4 {
		local b = b_`er'_`oc'
		local s = se_`er'_`oc'
		if missing(`b') | missing(`s') | `s' <= 0 {
			local brow "`brow' & --"
			local srow "`srow' & "
		}
		else {
			local p = 2*normal(-abs(`b'/`s'))
			local st = ""
			if `p' < 0.10 local st = "*"
			if `p' < 0.05 local st = "**"
			if `p' < 0.01 local st = "***"
			if "`st'" != "" {
				local bcell = string(`b',"%5.3f") + "\sym{`st'}"
			}
			else {
				local bcell = string(`b',"%5.3f")
			}
			local scell = "(" + string(`s',"%5.3f") + ")"
			local brow "`brow' & `bcell'"
			local srow "`srow' & `scell'"
		}
	}
	file write _tbl "`brow' \\" _n
	file write _tbl "`srow' \\" _n
}
file write _tbl "\midrule" _n
local nrow "Observations"
foreach oc of numlist 1/4 {
	local ncell = trim(string(n_ols_`oc', "%12.0fc"))
	local nrow "`nrow' & `ncell'"
}
file write _tbl "`nrow' \\" _n
file write _tbl "\bottomrule" _n
file write _tbl "\end{tabular}" _n
file write _tbl "}" _n
file close _tbl
display in green "did_modern_main.tex written"

/* ============================================================
   LOG SUMMARY
   ============================================================ */
di as result "================================================"
di as result " 4 x 4 SUMMARY: post-treatment coefficient (se)"
di as result "================================================"
di "Estimator | mm_protests        mm_violent         mm_nonviolent      mm_gvr"
foreach er in ols dcdh bjs sa {
	local row "`er'   "
	foreach oc of numlist 1/4 {
		local b = b_`er'_`oc'
		local s = se_`er'_`oc'
		local bs = cond(missing(`b'), "    .   ", string(`b', "%9.4f"))
		local ss = cond(missing(`s'), "    .   ", string(`s', "%9.4f"))
		local row "`row'  `bs' (`ss')"
	}
	display "`row'"
}

display in green "a_did_modern.do finished OK"
