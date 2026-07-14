/* ----------------------------------------------------------------------------
					Violent effects of apex corruption

	Code author: Roberto Gonzalez
	Date: 2026-05-22

	Objective (Task 1, Design 2 -- "Cengiz stacked by scandal"):
		Reproduce the Table 16 estimand with modern staggered-DiD
		estimators on a Cengiz-Dube-Lindner-Zipperer stacked panel.
		THE OBSERVATION IS A COUNTRY x 3-DAY BIN -- the same 3-day grouping
		used in the Latinobarometer modern-DiD code.

		For each scandal s: the treated country c(s) over the +-30-day
		window, PLUS every country with no scandal in that window, as the
		clean control cohort; tagged with stack = s.  Stacks are pooled;
		within each stack the treated country switches at event-bin 0 and
		control countries never switch.

	Time unit: 3-day bin.  Event window: +-10 bins (+-30 days); bin -1 =
	reference.  Venezuela dropped (as in Table 16).

	Estimators: OLS two-way FE, dCDH, BJS, SA.

	Outputs:
		${tabout}/did_modern_stk_main.tex
		${figout}/did_modern_stk_es_<outcome>.pdf
---------------------------------------------------------------------------- */

if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}
global work   "${identity}/Corrupcion/Protest_Work"
global path   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"
global tabout "${identity}/Corrupcion/protest_repo/paper/tables"
global figout "${identity}/Corrupcion/protest_repo/paper/figures"

/* ============================================================
   1.  COLLAPSE DAILY PANEL TO COUNTRY x 3-DAY BIN
   ============================================================ */
use "${datfin}/panel_country_day.dta", clear
keep if year >= 2008
drop if country == "Venezuela"

quietly summarize date
local d0 = r(min)
gen long bin3 = floor((date - `d0')/3) + 1

/* scandal list: one row per scandal (country, scandal 3-day bin, id) */
preserve
	keep if scandal_today == 1
	gen long scandal_bin = bin3
	keep country scandal_bin scandal_id
	tempfile sclist
	save `sclist'
	count
	local nscandals = r(N)
restore

/* collapsed country-bin panel + per-cell scandal indicator */
collapse (sum) mm_protests mm_violent mm_nonviolent mm_gvr ///
	(max) sc = scandal_today (firstnm) country_id, by(country bin3)
tempfile cbin
save `cbin'

display in yellow "Scandals to stack: `nscandals'"

/* ============================================================
   2.  BUILD THE STACKED PANEL  (+-10 three-day bins per scandal)
   ============================================================ */
clear
tempfile stack
save `stack', emptyok replace

forvalues s = 1/`nscandals' {
	use `sclist' in `s', clear
	local scc = country[1]
	local scb = scandal_bin[1]
	local sid = scandal_id[1]

	use `cbin', clear
	keep if inrange(bin3, `scb'-10, `scb'+10)
	bysort country: egen _anysc = max(sc)
	keep if country == "`scc'" | _anysc == 0
	gen long stack        = `s'
	gen long etime        = bin3 - `scb'
	gen byte treated_unit = (country == "`scc'")
	drop _anysc
	append using `stack'
	save `stack', replace
}

use `stack', clear
egen long unit_id = group(stack country)
gen byte D = treated_unit == 1 & etime >= 0
label variable D "Treated country x post-scandal"
gen long cohort = 0 if treated_unit == 1
gen byte I_never_treated = (treated_unit == 0)

di as result "=== Stacked country x 3-day-bin panel ==="
count
quietly levelsof stack
di "Stacks (scandals): " r(r)
quietly summarize etime
di "Event-bin range: " r(min) " .. " r(max)

/* ============================================================
   3.  EVENT-STUDY DUMMIES  (+-10 bins, omit bin -1)
   Plot grid = 20 cols, event bins -10..-1,0..9; reference = bin -1.
   ============================================================ */
forvalues k = 2/10 {
	gen byte ev_l`k' = (etime == -`k') & treated_unit == 1
}
forvalues k = 0/9 {
	gen byte ev_g`k' = (etime == `k') & treated_unit == 1
}
local es_dummies ev_l10 ev_l9 ev_l8 ev_l7 ev_l6 ev_l5 ev_l4 ev_l3 ev_l2 ///
	ev_g0 ev_g1 ev_g2 ev_g3 ev_g4 ev_g5 ev_g6 ev_g7 ev_g8 ev_g9

local outcomes mm_protests mm_violent mm_nonviolent mm_gvr

/* ============================================================
   4.  MAIN LOOP
   ============================================================ */
local oc = 0
foreach y of local outcomes {
	local ++oc

	if "`y'" == "mm_protests"   local ytitle "Number of protests"
	if "`y'" == "mm_violent"    local ytitle "Number of violent protests"
	if "`y'" == "mm_nonviolent" local ytitle "Number of non-violent protests"
	if "`y'" == "mm_gvr"        local ytitle "Number of govt. violent responses"

	matrix M_ols_b  = J(1,20,0)
	matrix M_ols_se = J(1,20,0)
	matrix M_dcdh_b  = J(1,20,0)
	matrix M_dcdh_se = J(1,20,0)
	matrix M_bjs_b  = J(1,20,0)
	matrix M_bjs_se = J(1,20,0)
	matrix M_sa_b  = J(1,20,0)
	matrix M_sa_se = J(1,20,0)

	/* ---------- (1) OLS two-way FE ---------- */
	di as result "--- OLS: `y' ---"
	reghdfe `y' D, absorb(unit_id etime) cluster(country_id)
	scalar b_ols_`oc'  = _b[D]
	scalar se_ols_`oc' = _se[D]
	scalar n_ols_`oc'  = e(N)
	quietly reghdfe `y' `es_dummies', absorb(unit_id etime) cluster(country_id)
	local cc = 0
	foreach k of numlist 10 9 8 7 6 5 4 3 2 {
		local ++cc
		matrix M_ols_b[1,`cc']  = _b[ev_l`k']
		matrix M_ols_se[1,`cc'] = _se[ev_l`k']
	}
	forvalues k = 0/9 {
		matrix M_ols_b[1, 11+`k']  = _b[ev_g`k']
		matrix M_ols_se[1, 11+`k'] = _se[ev_g`k']
	}

	/* ---------- (2) dCDH ---------- */
	di as result "--- dCDH: `y' ---"
	capture noisily did_multiplegt_dyn `y' unit_id etime D, ///
		effects(10) placebo(10) cluster(country_id) graph_off
	if _rc == 0 {
		scalar b_dcdh_`oc'  = e(Av_tot_effect)
		scalar se_dcdh_`oc' = e(se_avg_total_effect)
		forvalues k = 1/10 {
			capture matrix M_dcdh_b[1, 11-`k']  = e(Placebo_`k')
			capture matrix M_dcdh_se[1, 11-`k'] = e(se_placebo_`k')
		}
		forvalues k = 1/10 {
			capture matrix M_dcdh_b[1, 10+`k']  = e(Effect_`k')
			capture matrix M_dcdh_se[1, 10+`k'] = e(se_effect_`k')
		}
	}
	else {
		scalar b_dcdh_`oc' = .
		scalar se_dcdh_`oc' = .
		display in red "dCDH failed for `y'"
	}

	/* ---------- (3) BJS (did_imputation) ---------- */
	di as result "--- BJS: `y' ---"
	capture noisily did_imputation `y' unit_id etime cohort, ///
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
	capture noisily did_imputation `y' unit_id etime cohort, ///
		horizons(0/9) pretrends(10) autosample minn(0) delta(1) cluster(country_id)
	if _rc == 0 {
		forvalues k = 2/10 {
			capture quietly lincom pre`k' - pre1
			if _rc == 0 {
				matrix M_bjs_b[1, 11-`k']  = r(estimate)
				matrix M_bjs_se[1, 11-`k'] = r(se)
			}
		}
		forvalues k = 0/9 {
			capture quietly lincom tau`k' - pre1
			if _rc == 0 {
				matrix M_bjs_b[1, 11+`k']  = r(estimate)
				matrix M_bjs_se[1, 11+`k'] = r(se)
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
		absorb(unit_id etime) vce(cluster country_id)
	if _rc == 0 {
		matrix b_iw = e(b_iw)
		matrix V_iw = e(V_iw)
		local cc = 0
		foreach k of numlist 10 9 8 7 6 5 4 3 2 {
			local ++cc
			local j = colnumb(b_iw, "ev_l`k'")
			if `j' < . {
				matrix M_sa_b[1,`cc']  = b_iw[1,`j']
				matrix M_sa_se[1,`cc'] = sqrt(V_iw[`j',`j'])
			}
		}
		forvalues k = 0/9 {
			local j = colnumb(b_iw, "ev_g`k'")
			if `j' < . {
				matrix M_sa_b[1, 11+`k']  = b_iw[1,`j']
				matrix M_sa_se[1, 11+`k'] = sqrt(V_iw[`j',`j'])
			}
		}
		matrix wgt = J(1, colsof(b_iw), 0)
		local npost = 0
		forvalues k = 0/9 {
			local j = colnumb(b_iw, "ev_g`k'")
			if `j' < . {
				matrix wgt[1,`j'] = 1
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

	/* ---------- combined event-study plot ---------- */
	preserve
		clear
		set obs 20
		gen bin = _n - 11
		foreach est in ols dcdh bjs sa {
			gen double b_`est'  = .
			gen double se_`est' = .
			forvalues j = 1/20 {
				replace b_`est'  = M_`est'_b[1,`j']  in `j'
				replace se_`est' = M_`est'_se[1,`j'] in `j'
			}
			gen double ci_lo_`est' = b_`est' - 1.645*se_`est'
			gen double ci_hi_`est' = b_`est' + 1.645*se_`est'
		}
		gen double bin_ols  = bin - 0.21
		gen double bin_dcdh = bin - 0.07
		gen double bin_bjs  = bin + 0.07
		gen double bin_sa   = bin + 0.21

		twoway ///
			(rspike ci_lo_ols  ci_hi_ols  bin_ols,  lcolor(navy)         lwidth(medium)) ///
			(scatter b_ols  bin_ols,  mcolor(navy)         msymbol(O)  msize(small)) ///
			(rspike ci_lo_dcdh ci_hi_dcdh bin_dcdh, lcolor(cranberry)    lwidth(medium)) ///
			(scatter b_dcdh bin_dcdh, mcolor(cranberry)    msymbol(T)  msize(small)) ///
			(rspike ci_lo_bjs  ci_hi_bjs  bin_bjs,  lcolor(forest_green) lwidth(medium)) ///
			(scatter b_bjs  bin_bjs,  mcolor(forest_green) msymbol(D)  msize(small)) ///
			(rspike ci_lo_sa   ci_hi_sa   bin_sa,   lcolor(midblue)      lwidth(medium)) ///
			(scatter b_sa   bin_sa,   mcolor(midblue)      msymbol(Oh) msize(small)), ///
			yline(0, lcolor(red) lpattern(solid) lwidth(medthin)) ///
			xline(-0.5, lcolor(black%20) lpattern(solid) lwidth(vthick)) ///
			xtitle("Days since scandal (3-day bins)", size(medium)) ///
			ytitle("`ytitle'", size(medium)) ///
			xlabel(-10 "-30" -8 "-24" -6 "-18" -4 "-12" -2 "-6" ///
				0 "0" 2 "6" 4 "12" 6 "18" 8 "24", labsize(medsmall)) ///
			ylabel(, labsize(medsmall) format(%4.3fc)) ///
			legend(order(2 "OLS (TWFE)" 4 "dCDH" 6 "BJS" 8 "SA") ///
				rows(1) size(small) position(6) region(lcolor(none))) ///
			graphregion(color(white)) scheme(s2color)
		graph export "${figout}/did_modern_stk_es_`y'.pdf", replace
	restore
}

/* ============================================================
   5.  4 x 4 RESULTS TABLE  ->  did_modern_stk_main.tex
   ============================================================ */
capture file close _tbl
file open _tbl using "${tabout}/did_modern_stk_main.tex", write replace
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
				local bcell = string(`b',"%6.4f") + "\sym{`st'}"
			}
			else {
				local bcell = string(`b',"%6.4f")
			}
			local scell = "(" + string(`s',"%6.4f") + ")"
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
display in green "did_modern_stk_main.tex written"

di as result "=== Stacked 3-day-bin panel: post-scandal coefficient (se) ==="
foreach er in ols dcdh bjs sa {
	local row "`er'   "
	foreach oc of numlist 1/4 {
		local b = b_`er'_`oc'
		local s = se_`er'_`oc'
		local bs = cond(missing(`b'), "    .    ", string(`b', "%9.5f"))
		local ss = cond(missing(`s'), "    .    ", string(`s', "%9.5f"))
		local row "`row'  `bs' (`ss')"
	}
	display "`row'"
}
display in green "a_did_modern_stacked.do finished OK"
