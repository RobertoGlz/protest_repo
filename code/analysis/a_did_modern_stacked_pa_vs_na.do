/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-07-14

    Objective:
        Modern staggered-DiD estimators on the Cengiz-Dube-Lindner-Zipperer
        "stacked by scandal" design, run SEPARATELY on the two apex-partition
        subsamples (pa = Apex, na = Non-Apex).

        *** ALIGNED WITH THE EVENT STUDIES ***
        To make these estimates as comparable as possible to the OLS event
        studies in a_sup_event_study_pa_vs_na.do, this design now uses the
        SAME event-time geometry as the main event-study specification:
            - 15-day bins (was: 3-day bins)
            - +-8 bins = +-120-day window (was: +-10 bins = +-30 days)
            - bin -1 (the 15 days before disclosure) is the reference
            - same two headline outcomes (violent / non-violent counts)
        Only scandals in the subsample form TREATED stacks; the clean
        control cohort within each stack is every country with NO scandal
        of ANY type in the +-8-bin window.

        Treated-scandal identity comes from the classified event-window
        panel, matched into the country-day panel on country + date.

        Estimators: OLS two-way FE, dCDH, BJS, SA.

    Outputs (paper/{tables,figures}/):
        - did_modern_stk_main_<sample>.tex
        - did_modern_stk_es_<outcome>_<sample>.pdf
      where <sample> in {pa, na}.
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

capture log close _all
log using "${identity}/Corrupcion/protest_repo/code/analysis/a_did_modern_stacked_pa_vs_na.log", replace text

/* ---- event-time geometry: MATCHES the event studies ---- */
local BIN   = 15    /* bin width in days */
/* NBIN (bins per side) loops over 4/6/8 => +-60/90/120-day windows below,
   so the stacked design matches the imputation design's outcome x window
   table and per-window event studies. */

/* ============================================================
   0.  COUNTRY x 15-DAY-BIN PANEL (shared by both subsamples)
   ============================================================ */
use "${datfin}/panel_country_day.dta", clear
keep if year >= 2008
drop if country == "Venezuela"

quietly summarize date
scalar d0 = r(min)
gen long ebin = floor((date - d0)/`BIN') + 1

/* collapsed country-bin panel + per-cell any-scandal indicator */
collapse (sum) mm_protests mm_violent mm_nonviolent mm_gvr ///
	(max) sc = scandal_today (firstnm) country_id, by(country ebin)
tempfile cbin
save `cbin'

/* ============================================================
   1.  APEX-LABELLED SCANDAL LIST (one row per scandal)
   ============================================================ */
import delimited using "${datfin}/scandals_classified.csv", ///
	clear varnames(1) bindquotes(strict)
keep id country position
tempfile cls
save `cls'

use "${datfin}/protests_scandals_30days_v3", clear
keep if window == 0
drop if country == "Venezuela"
merge m:1 id country using `cls', keep(1 3) generate(_mclass)

gen byte in_pa = 0
replace in_pa = 1 if position == "president"
replace in_pa = 1 if position == "governor"
replace in_pa = 1 if position == "sc_judge_congressman" & ///
	inlist(id, "202", "NEW26", "NEW30", "332", "NEW23")

gen byte in_na = 0
replace in_na = 1 if position == "sc_judge_congressman" & ///
	!inlist(id, "202", "NEW26", "NEW30", "332", "NEW23")
replace in_na = 1 if position == "other_judiciary"
replace in_na = 1 if position == "others"

gen long scandal_bin = floor((date - d0)/`BIN') + 1
keep country scandal_bin in_pa in_na
tempfile sclist_all
save `sclist_all'

/* ============================================================
   2.  SUBSAMPLE LOOP
   ============================================================ */
foreach sample in pa na {

	di as result _newline _newline ///
		"=================================================================" _n ///
		"   DID MODERN (stacked, `BIN'-day bins, +-`NBIN' bins) -- `sample'" _n ///
		"================================================================="

	use `sclist_all', clear
	keep if in_`sample' == 1
	gen long scandal_id = _n
	quietly count
	local nscandals = r(N)
	tempfile sclist
	save `sclist'
	display in yellow "Scandals to stack [`sample']: `nscandals'"

	foreach NBIN of numlist 4 6 8 {
	local T = `NBIN' * `BIN'      /* event-window width in days: 60/90/120 */

	/* --- build the stacked panel: +-NBIN bins per scandal --- */
	clear
	tempfile stack
	save `stack', emptyok replace

	forvalues s = 1/`nscandals' {
		use `sclist' in `s', clear
		local scc = country[1]
		local scb = scandal_bin[1]

		use `cbin', clear
		keep if inrange(ebin, `scb'-`NBIN', `scb'+`NBIN')
		bysort country: egen _anysc = max(sc)
		keep if country == "`scc'" | _anysc == 0
		gen long stack        = `s'
		gen long etime        = ebin - `scb'
		gen byte treated_unit = (country == "`scc'")
		drop _anysc
		append using `stack'
		save `stack', replace
	}

	use `stack', clear
	egen long unit_id = group(stack country)
	gen byte D = treated_unit == 1 & etime >= 0
	gen long cohort = 0 if treated_unit == 1
	gen byte I_never_treated = (treated_unit == 0)

	di as result "=== Stacked country x `BIN'-day-bin panel [`sample'] ==="
	count
	quietly levelsof stack
	di "Stacks (scandals): " r(r)

	/* event-study dummies: bins -NBIN..-2 and 0..NBIN-1; bin -1 omitted */
	capture drop ev_l* ev_g*
	forvalues k = 2/`NBIN' {
		gen byte ev_l`k' = (etime == -`k') & treated_unit == 1
	}
	local kmax = `NBIN' - 1
	forvalues k = 0/`kmax' {
		gen byte ev_g`k' = (etime == `k') & treated_unit == 1
	}
	local es_dummies ""
	forvalues k = `NBIN'(-1)2 {
		local es_dummies "`es_dummies' ev_l`k'"
	}
	forvalues k = 0/`kmax' {
		local es_dummies "`es_dummies' ev_g`k'"
	}

	/* plot grid: 2*NBIN columns = bins -NBIN..-1, 0..NBIN-1
	   col 1..NBIN-1 = bins -NBIN..-2 ; col NBIN = bin -1 (reference, 0)
	   col NBIN+1..2*NBIN = bins 0..NBIN-1                              */
	local ncol = 2 * `NBIN'
	local refcol = `NBIN'

	local outcomes mm_violent mm_nonviolent mm_protests

	tempfile stackfull
	save `stackfull'

	/* ---------- outcome loop ---------- */
	local oc = 0
	foreach y of local outcomes {
		local ++oc

		if "`y'" == "mm_protests"   local ytitle "Number of protests"
		if "`y'" == "mm_violent"    local ytitle "Number of violent protests"
		if "`y'" == "mm_nonviolent" local ytitle "Number of non-violent protests"
		if "`y'" == "mm_gvr"        local ytitle "Number of govt. violent responses"

		matrix M_ols_b   = J(1,`ncol',0)
		matrix M_ols_se  = J(1,`ncol',0)
		matrix M_dcdh_b  = J(1,`ncol',0)
		matrix M_dcdh_se = J(1,`ncol',0)
		matrix M_bjs_b   = J(1,`ncol',0)
		matrix M_bjs_se  = J(1,`ncol',0)
		matrix M_sa_b    = J(1,`ncol',0)
		matrix M_sa_se   = J(1,`ncol',0)

		use `stackfull', clear

		/* (1) OLS TWFE */
		di as result "--- OLS: `y' [`sample'] ---"
		reghdfe `y' D, absorb(unit_id etime) cluster(country_id)
		scalar b_ols_`oc'  = _b[D]
		scalar se_ols_`oc' = _se[D]
		scalar n_ols_`oc'  = e(N)
		quietly reghdfe `y' `es_dummies', absorb(unit_id etime) cluster(country_id)
		local cc = 0
		forvalues k = `NBIN'(-1)2 {
			local ++cc
			matrix M_ols_b[1,`cc']  = _b[ev_l`k']
			matrix M_ols_se[1,`cc'] = _se[ev_l`k']
		}
		forvalues k = 0/`kmax' {
			matrix M_ols_b[1, `refcol'+1+`k']  = _b[ev_g`k']
			matrix M_ols_se[1, `refcol'+1+`k'] = _se[ev_g`k']
		}

		/* (2) dCDH */
		di as result "--- dCDH: `y' [`sample'] ---"
		capture noisily did_multiplegt_dyn `y' unit_id etime D, ///
			effects(`NBIN') placebo(`NBIN') cluster(country_id) graph_off
		if _rc == 0 {
			scalar b_dcdh_`oc'  = e(Av_tot_effect)
			scalar se_dcdh_`oc' = e(se_avg_total_effect)
			forvalues k = 1/`NBIN' {
				capture matrix M_dcdh_b[1, `refcol'+1-`k']  = e(Placebo_`k')
				capture matrix M_dcdh_se[1, `refcol'+1-`k'] = e(se_placebo_`k')
			}
			forvalues k = 1/`NBIN' {
				capture matrix M_dcdh_b[1, `refcol'+`k']  = e(Effect_`k')
				capture matrix M_dcdh_se[1, `refcol'+`k'] = e(se_effect_`k')
			}
		}
		else {
			scalar b_dcdh_`oc' = .
			scalar se_dcdh_`oc' = .
			display in red "dCDH failed for `y' [`sample']"
		}

		/* (3) BJS */
		di as result "--- BJS: `y' [`sample'] ---"
		capture noisily did_imputation `y' unit_id etime cohort, ///
			autosample minn(0) delta(1) cluster(country_id)
		if _rc == 0 {
			scalar b_bjs_`oc'  = _b[tau]
			scalar se_bjs_`oc' = _se[tau]
		}
		else {
			scalar b_bjs_`oc' = .
			scalar se_bjs_`oc' = .
			display in red "BJS (static) failed for `y' [`sample']"
		}
		capture noisily did_imputation `y' unit_id etime cohort, ///
			horizons(0/`kmax') pretrends(`NBIN') autosample minn(0) delta(1) ///
			cluster(country_id)
		if _rc == 0 {
			forvalues k = 2/`NBIN' {
				capture quietly lincom pre`k' - pre1
				if _rc == 0 {
					matrix M_bjs_b[1, `refcol'+1-`k']  = r(estimate)
					matrix M_bjs_se[1, `refcol'+1-`k'] = r(se)
				}
			}
			forvalues k = 0/`kmax' {
				capture quietly lincom tau`k' - pre1
				if _rc == 0 {
					matrix M_bjs_b[1, `refcol'+1+`k']  = r(estimate)
					matrix M_bjs_se[1, `refcol'+1+`k'] = r(se)
				}
			}
		}

		/* (4) SA */
		di as result "--- SA: `y' [`sample'] ---"
		capture noisily eventstudyinteract `y' `es_dummies', ///
			cohort(cohort) control_cohort(I_never_treated) ///
			absorb(unit_id etime) vce(cluster country_id)
		if _rc == 0 {
			matrix b_iw = e(b_iw)
			matrix V_iw = e(V_iw)
			local cc = 0
			forvalues k = `NBIN'(-1)2 {
				local ++cc
				local j = colnumb(b_iw, "ev_l`k'")
				if `j' < . {
					matrix M_sa_b[1,`cc']  = b_iw[1,`j']
					matrix M_sa_se[1,`cc'] = sqrt(V_iw[`j',`j'])
				}
			}
			forvalues k = 0/`kmax' {
				local j = colnumb(b_iw, "ev_g`k'")
				if `j' < . {
					matrix M_sa_b[1, `refcol'+1+`k']  = b_iw[1,`j']
					matrix M_sa_se[1, `refcol'+1+`k'] = sqrt(V_iw[`j',`j'])
				}
			}
			matrix wgt = J(1, colsof(b_iw), 0)
			local npost = 0
			forvalues k = 0/`kmax' {
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
			display in red "SA failed for `y' [`sample']"
		}

		/* store static coefficients keyed by (window, outcome) for the
		   compact per-sample table assembled after the window loop */
		foreach er in ols dcdh bjs sa {
			scalar B_`er'_w`T'_`oc' = b_`er'_`oc'
			scalar S_`er'_w`T'_`oc' = se_`er'_`oc'
		}
		scalar N_w`T'_`oc' = n_ols_`oc'

		/* ---------- combined event-study plot ---------- */
		preserve
			clear
			set obs `ncol'
			gen bin = _n - `refcol' - 1        /* event bin: -NBIN..-1, 0..NBIN-1 */
			gen days = bin * `BIN'             /* bin start in days */
			replace days = days + `BIN' if days >= 0   /* POST bins -> right edge; PRE keep left edge */
			foreach est in ols dcdh bjs sa {
				gen double b_`est'  = .
				gen double se_`est' = .
				forvalues j = 1/`ncol' {
					replace b_`est'  = M_`est'_b[1,`j']  in `j'
					replace se_`est' = M_`est'_se[1,`j'] in `j'
				}
				gen double ci_lo_`est' = b_`est' - 1.645*se_`est'
				gen double ci_hi_`est' = b_`est' + 1.645*se_`est'
			}
			gen double days_ols  = days - 0.21 * `BIN'
			gen double days_dcdh = days - 0.07 * `BIN'
			gen double days_bjs  = days + 0.07 * `BIN'
			gen double days_sa   = days + 0.21 * `BIN'

			local labday = 15
			if `NBIN' >= 6 local labday = 30
			local xlabs ""
			forvalues bb = -`NBIN'/`=`NBIN'-1' {
				if `bb' < 0 local dd = `bb' * `BIN'
				else        local dd = (`bb' + 1) * `BIN'
				if mod(`dd', `labday') == 0 local xlabs "`xlabs' `dd'"
			}
			local xpad   = 0.6 * `BIN'
			local xlo_ax = -`NBIN' * `BIN' - `xpad'
			local xhi_ax = `NBIN' * `BIN' + `xpad'

			twoway ///
				(rspike ci_lo_ols  ci_hi_ols  days_ols,  lcolor(navy)         lwidth(medium)) ///
				(scatter b_ols  days_ols,  mcolor(navy)         msymbol(O)  msize(small)) ///
				(rspike ci_lo_dcdh ci_hi_dcdh days_dcdh, lcolor(cranberry)    lwidth(medium)) ///
				(scatter b_dcdh days_dcdh, mcolor(cranberry)    msymbol(T)  msize(small)) ///
				(rspike ci_lo_bjs  ci_hi_bjs  days_bjs,  lcolor(forest_green) lwidth(medium)) ///
				(scatter b_bjs  days_bjs,  mcolor(forest_green) msymbol(D)  msize(small)) ///
				(rspike ci_lo_sa   ci_hi_sa   days_sa,   lcolor(midblue)      lwidth(medium)) ///
				(scatter b_sa   days_sa,   mcolor(midblue)      msymbol(Oh) msize(small)), ///
				yline(0, lcolor(red) lpattern(solid) lwidth(medthin)) ///
				xline(0, lcolor(black%20) lpattern(solid) lwidth(vthick)) ///
				xtitle("Days since scandal", size(large)) ///
				ytitle("`ytitle'", size(large)) ///
				xscale(range(`xlo_ax' `xhi_ax')) ///
				xlabel(`xlabs', labsize(large)) ///
				ylabel(, labsize(large) format(%4.3fc) angle(0)) ///
				legend(order(2 "OLS (TWFE)" 4 "dCDH" 6 "BJS" 8 "SA") ///
					rows(1) size(small) position(6) region(lcolor(none))) ///
				graphregion(color(white)) scheme(s2color)
			graph export "${figout}/did_modern_stk_es_`y'_`sample'_w`T'.pdf", replace
		restore
	}
	}

	/* ---------- compact per-sample table: rows = estimators, columns =
	   outcome x window (Violent / Non-violent / Protests at +-60/90/120;
	   government-violent-response outcome dropped) ---------- */
	capture file close _tbl
	file open _tbl using "${tabout}/did_modern_stk_main_`sample'.tex", write replace
	file write _tbl "{" _n
	file write _tbl "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
	file write _tbl "\begin{tabular}{l*{9}{c}}" _n
	file write _tbl "\toprule" _n
	file write _tbl " & \multicolumn{3}{c}{Violent Protests} & \multicolumn{3}{c}{Non-violent Protests} & \multicolumn{3}{c}{Protests (any)} \\" _n
	file write _tbl "\cmidrule(lr){2-4}\cmidrule(lr){5-7}\cmidrule(lr){8-10}" _n
	file write _tbl " & \ensuremath{\pm 60} & \ensuremath{\pm 90} & \ensuremath{\pm 120} & \ensuremath{\pm 60} & \ensuremath{\pm 90} & \ensuremath{\pm 120} & \ensuremath{\pm 60} & \ensuremath{\pm 90} & \ensuremath{\pm 120} \\" _n
	file write _tbl "\midrule" _n
	foreach er in ols dcdh bjs sa {
		if "`er'" == "ols"  local rowlab "OLS (TWFE)"
		if "`er'" == "dcdh" local rowlab "dCDH"
		if "`er'" == "bjs"  local rowlab "BJS"
		if "`er'" == "sa"   local rowlab "SA"
		local brow "`rowlab'"
		local srow "            "
		foreach oc of numlist 1/3 {
		foreach TT of numlist 60 90 120 {
			local b = B_`er'_w`TT'_`oc'
			local s = S_`er'_w`TT'_`oc'
			if missing(`b') | missing(`s') | `s' <= 0 {
				local brow "`brow' & --"
				local srow "`srow' & "
			}
			else {
				local pv = 2*normal(-abs(`b'/`s'))
				local st = ""
				if `pv' < 0.10 local st = "*"
				if `pv' < 0.05 local st = "**"
				if `pv' < 0.01 local st = "***"
				if "`st'" != "" local bcell = string(`b',"%5.3f") + "\sym{`st'}"
				else            local bcell = string(`b',"%5.3f")
				local scell = "(" + string(`s',"%5.3f") + ")"
				local brow "`brow' & `bcell'"
				local srow "`srow' & `scell'"
			}
		}
		}
		file write _tbl "`brow' \\" _n
		file write _tbl "`srow' \\" _n
	}
	file write _tbl "\midrule" _n
	local nrow "Observations"
	foreach oc of numlist 1/3 {
	foreach TT of numlist 60 90 120 {
		local ncell = trim(string(N_w`TT'_`oc', "%12.0fc"))
		local nrow "`nrow' & `ncell'"
	}
	}
	file write _tbl "`nrow' \\" _n
	file write _tbl "\bottomrule" _n
	file write _tbl "\end{tabular}" _n
	file write _tbl "}" _n
	file close _tbl
	display in green "did_modern_stk_main_`sample'.tex written"
}

display in green "a_did_modern_stacked_pa_vs_na.do finished OK"

capture log close _all
