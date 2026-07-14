/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-07-13

    Objective:
        Split version of a_did_modern_countrypanel.do.  Same country x
        3-day-bin panel and same four modern DiD estimators, but run
        SEPARATELY on the two apex-partition subsamples used in Table~1:
            - pa : President + Other Apex   scandals
            - na : Other Non-Apex           scandals

    Outputs (paper/{tables,figures}/):
        - did_modern_cp_main_<sample>.tex
        - did_modern_cp_es_<outcome>_<sample>.pdf
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

/* ============================================================
   STEP 0 - per-country first-scandal date per subsample
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

preserve
	keep if in_pa == 1
	bysort country: egen double fs_pa = min(date)
	format fs_pa %td
	keep country fs_pa
	duplicates drop
	tempfile pa_dates
	save `pa_dates'
restore
preserve
	keep if in_na == 1
	bysort country: egen double fs_na = min(date)
	format fs_na %td
	keep country fs_na
	duplicates drop
	tempfile na_dates
	save `na_dates'
restore

/* ============================================================
   SAMPLE LOOP
   ============================================================ */
foreach sample in pa na {

	di as result _newline _newline ///
		"=================================================================" _n ///
		"   DID MODERN (country x 3-day-bin)  --  subsample = `sample'" _n ///
		"================================================================="

	/* Load daily panel, override first_scandal_date, then collapse */
	use "${datfin}/panel_country_day.dta", clear
	keep if year >= 2008

	if "`sample'" == "pa" {
		merge m:1 country using `pa_dates', keep(1 3) nogenerate
		replace first_scandal_date = fs_pa
		drop fs_pa
	}
	else {
		merge m:1 country using `na_dates', keep(1 3) nogenerate
		replace first_scandal_date = fs_na
		drop fs_na
	}

	quietly summarize date
	local d0 = r(min)
	gen long bin3 = floor((date - `d0')/3) + 1

	collapse (sum) mm_protests mm_violent mm_nonviolent mm_gvr ///
		(firstnm) country_id first_scandal_date, by(country bin3)

	gen long first_scandal_bin = floor((first_scandal_date - `d0')/3) + 1 ///
		if !missing(first_scandal_date)
	gen byte ever_treated   = !missing(first_scandal_bin)
	gen byte I_never_treated = (ever_treated == 0)
	gen byte D = ever_treated == 1 & bin3 >= first_scandal_bin
	gen long etime  = bin3 - first_scandal_bin if ever_treated == 1
	gen long cohort = first_scandal_bin
	replace cohort = 999999 if missing(cohort)

	xtset country_id bin3

	forvalues k = 2/10 {
		gen byte ev_l`k' = (etime == -`k') & ever_treated == 1
	}
	forvalues k = 0/9 {
		gen byte ev_g`k' = (etime == `k') & ever_treated == 1
	}
	local es_dummies ev_l10 ev_l9 ev_l8 ev_l7 ev_l6 ev_l5 ev_l4 ev_l3 ev_l2 ///
		ev_g0 ev_g1 ev_g2 ev_g3 ev_g4 ev_g5 ev_g6 ev_g7 ev_g8 ev_g9

	local outcomes mm_protests mm_violent mm_nonviolent mm_gvr

	local oc = 0
	foreach y of local outcomes {
		local ++oc

		if "`y'" == "mm_protests"   local ytitle "Number of protests"
		if "`y'" == "mm_violent"    local ytitle "Number of violent protests"
		if "`y'" == "mm_nonviolent" local ytitle "Number of non-violent protests"
		if "`y'" == "mm_gvr"        local ytitle "Number of govt. violent responses"

		matrix M_ols_b   = J(1,20,0)
		matrix M_ols_se  = J(1,20,0)
		matrix M_dcdh_b  = J(1,20,0)
		matrix M_dcdh_se = J(1,20,0)
		matrix M_bjs_b   = J(1,20,0)
		matrix M_bjs_se  = J(1,20,0)
		matrix M_sa_b    = J(1,20,0)
		matrix M_sa_se   = J(1,20,0)

		/* (1) OLS TWFE */
		di as result "--- OLS: `y' [`sample'] ---"
		reghdfe `y' D, absorb(country_id bin3) cluster(country_id)
		scalar b_ols_`oc'  = _b[D]
		scalar se_ols_`oc' = _se[D]
		scalar n_ols_`oc'  = e(N)
		quietly reghdfe `y' `es_dummies', absorb(country_id bin3) cluster(country_id)
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

		/* (2) dCDH */
		di as result "--- dCDH: `y' [`sample'] ---"
		capture noisily did_multiplegt_dyn `y' country_id bin3 D, ///
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
		}

		/* (3) BJS */
		di as result "--- BJS: `y' [`sample'] ---"
		capture noisily did_imputation `y' country_id bin3 first_scandal_bin, ///
			autosample minn(0) delta(1) cluster(country_id)
		if _rc == 0 {
			scalar b_bjs_`oc'  = _b[tau]
			scalar se_bjs_`oc' = _se[tau]
		}
		else {
			scalar b_bjs_`oc' = .
			scalar se_bjs_`oc' = .
		}
		capture noisily did_imputation `y' country_id bin3 first_scandal_bin, ///
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

		/* (4) SA */
		di as result "--- SA: `y' [`sample'] ---"
		capture noisily eventstudyinteract `y' `es_dummies', ///
			cohort(cohort) control_cohort(I_never_treated) ///
			absorb(country_id bin3) vce(cluster country_id)
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
		}

		/* Combined event-study plot */
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
				xtitle("Days since first scandal (3-day bins)", size(medium)) ///
				ytitle("`ytitle'", size(medium)) ///
				xlabel(-10 "-30" -8 "-24" -6 "-18" -4 "-12" -2 "-6" ///
					0 "0" 2 "6" 4 "12" 6 "18" 8 "24", labsize(medsmall)) ///
				ylabel(, labsize(medsmall) format(%4.3fc)) ///
				legend(order(2 "OLS (TWFE)" 4 "dCDH" 6 "BJS" 8 "SA") ///
					rows(1) size(small) position(6) region(lcolor(none))) ///
				graphregion(color(white)) scheme(s2color)
			graph export "${figout}/did_modern_cp_es_`y'_`sample'.pdf", replace
		restore
	}

	/* 4x4 results table */
	capture file close _tbl
	file open _tbl using "${tabout}/did_modern_cp_main_`sample'.tex", write replace
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
	display in green "did_modern_cp_main_`sample'.tex written"
}

display in green "a_did_modern_countrypanel_pa_vs_na.do finished OK"
