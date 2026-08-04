/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-08-03

    Objective:
        Robustness writeup "including_ven": re-estimate the paper's core evidence
        WITHOUT dropping Venezuela (the main analysis excludes it), on the same
        outcomes (violent / peaceful protest counts):

          Table 1  (Apex vs Non-Apex interaction)       -> interaction_ven.tex
          Figure 1 (subsample event study, w60 b15)     -> es_ven_<out>_<samp>.pdf
          Table 2  (main effect + benchmarks, 4 panels) -> main_ven.tex
          Table 3  (democracy, Electoral, L vs M+H)     -> democracy_elec_ven.tex
          Table S3 (democracy, Liberal, L vs M+H)       -> democracy_lib_ven.tex

        Everything else---fixed effects (country x year, month, day-of-week),
        clustering (country x year x day-bin), sample period 2008-2018---matches
        the paper; the only change is that Venezuela's scandals are kept.  For the
        democracy splits the terciles are recomputed over the countries with a
        V-Dem score INCLUDING Venezuela.

    Requires: reghdfe, esttab, define_panelcombine.do
    Outputs:  tables interaction_ven, main_ven, democracy_elec_ven,
              democracy_lib_ven; event-study figures es_ven_...
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
global tables  "${identity}/Corrupcion/protest_repo/paper/tables"
global figout  "${identity}/Corrupcion/protest_repo/paper/figures"
global progdir "${identity}/Corrupcion/protest_repo/code/programs"

do "${progdir}/define_panelcombine.do"

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"
local firstyear = 2008
local zcrit = invnormal(0.95)

/* NOTE: no "drop if country == Venezuela" anywhere below -- that is the point. */

import delimited using "${datfin}/scandals_classified.csv", ///
	clear varnames(1) bindquotes(strict)
keep id country position
tempfile cls
save `cls'

local out_list "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM"
local win_list "30 30 60 60 90 90"
local nsp : word count `out_list'

/* ============================================================
   TABLE 1 - Apex vs Non-Apex interaction (incl. Venezuela)
   ============================================================ */
use "${datfin}/protests_scandals_30days_v3", clear
merge m:1 id country using `cls', keep(1 3) nogenerate
gen byte in_pa = 0
replace in_pa = 1 if position == "president"
replace in_pa = 1 if position == "governor"
replace in_pa = 1 if position == "sc_judge_congressman" & inlist(id,"202","NEW26","NEW30","332")
gen byte in_na = 0
replace in_na = 1 if position == "sc_judge_congressman" & !inlist(id,"202","NEW26","NEW30","332")
replace in_na = 1 if position == "other_judiciary"
replace in_na = 1 if position == "others"
gen byte post_pa = post * in_pa
gen byte post_na = post * in_na
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 s_lead30 s_lead60 s_lead90 s_lead120)
tempfile baseint
save `baseint'

eststo clear
forvalues k = 1/`nsp' {
	local outcome : word `k' of `out_list'
	local window  : word `k' of `win_list'
	use `baseint', clear
	eststo m`k': reghdfe `outcome' post_pa post_na i.month i.day ///
		if year >= `firstyear' & abs(window) <= `window' & (in_pa==1 | in_na==1), ///
		absorb($fe1) vce($CLUSTER2)
	quietly summarize `outcome' if e(sample) & window >= -`window' & window <= -1
	estadd scalar baseline = r(mean)
	quietly levelsof id if e(sample)==1
	estadd scalar num_scandals = r(r)
	test post_pa = post_na
	local p2 = r(p)
	estadd scalar p_pa_na = `p2'
	quietly lincom post_pa - post_na
	if r(estimate) > 0 estadd scalar p_pa_gt_na = `p2'/2
	else               estadd scalar p_pa_gt_na = 1 - `p2'/2
}
esttab _all using "${tables}/interaction_ven.tex", replace booktabs nonotes nogaps b(3) se(3) ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	mtitles("\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}" ///
	        "\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}" ///
	        "\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}") ///
	mgroups("$\pm 30$-Day Window" "$\pm 60$-Day Window" "$\pm 90$-Day Window", ///
	        pattern(1 0 1 0 1 0) prefix(\multicolumn{2}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
	stats(p_pa_na p_pa_gt_na baseline N num_scandals r2, ///
	      label("p-value: Apex $$=$$ Non-Apex" "p-value: Apex $$>$$ Non-Apex (one-sided)" ///
	            "Mean (Pre-Scandal)" "Observations" "Number of Scandals" "R-squared") fmt(3 3 3 0 0 3)) ///
	keep(post_pa post_na) coeflabels(post_pa "Post $\times$ Apex" post_na "Post $\times$ Non-Apex") ///
	substitute("$$" "$")
di as result "interaction_ven.tex written"

/* ============================================================
   TABLE 2 - main effect + benchmarks (4 panels, incl. Venezuela)
   ============================================================ */
foreach p in corrpa corrna football deprec {
	if inlist("`p'","corrpa","corrna") {
		use "${datfin}/protests_scandals_30days_v3", clear
		merge m:1 id country using `cls', keep(1 3) nogenerate
		gen byte in_pa = 0
		replace in_pa = 1 if position == "president"
		replace in_pa = 1 if position == "governor"
		replace in_pa = 1 if position == "sc_judge_congressman" & inlist(id,"202","NEW26","NEW30","332")
		gen byte in_na = 0
		replace in_na = 1 if position == "sc_judge_congressman" & !inlist(id,"202","NEW26","NEW30","332")
		replace in_na = 1 if position == "other_judiciary"
		replace in_na = 1 if position == "others"
		if "`p'"=="corrpa" local flag "in_pa"
		else               local flag "in_na"
	}
	else if "`p'"=="football" {
		use "${datfin}/protests_scandals_30days_football_v3", clear
		gen byte keepall = 1
		local flag "keepall"
	}
	else {
		use "${datfin}/protests_scandals_30days_depreciation_v3", clear
		gen byte keepall = 1
		local flag "keepall"
	}
	egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 s_lead30 s_lead60 s_lead90 s_lead120)
	tempfile pdata
	save `pdata'

	eststo clear
	forvalues k = 1/`nsp' {
		local outcome : word `k' of `out_list'
		local window  : word `k' of `win_list'
		use `pdata', clear
		eststo m`k': reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear' & abs(window) <= `window' & `flag'==1, ///
			absorb($fe1) vce($CLUSTER2)
		quietly summarize `outcome' if e(sample) & window >= -`window' & window <= -1
		estadd scalar baseline = r(mean)
		capture quietly levelsof id if e(sample)==1
		if _rc==0 estadd scalar num_events = r(r)
	}
	esttab m1 m2 m3 m4 m5 m6 using "${tables}/vbench_`p'_temp.tex", replace booktabs nonotes nogaps b(3) se(3) ///
		star(* 0.10 ** 0.05 *** 0.01) ///
		mtitles("\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}" ///
		        "\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}" ///
		        "\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}") ///
		mgroups("$\pm 30$-Day Window" "$\pm 60$-Day Window" "$\pm 90$-Day Window", ///
		        pattern(1 0 1 0 1 0) prefix(\multicolumn{2}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
		stats(baseline N num_events r2, label("Mean (Pre-Event)" "Observations" "Number of Events" "R-squared") fmt(3 0 0 3)) ///
		keep(post) coeflabels(post "Post Event")
}
panelcombine, ///
	use("${tables}/vbench_corrpa_temp.tex" "${tables}/vbench_corrna_temp.tex" ///
	    "${tables}/vbench_football_temp.tex" "${tables}/vbench_deprec_temp.tex") ///
	paneltitles("Apex" "Non-Apex" "Football match losses" "Currency depreciations") ///
	columncount(7) save("${tables}/main_ven.tex") cleanup
di as result "main_ven.tex written"

/* ============================================================
   TABLE 3 / S3 - democracy Low vs Medium+High (incl. Venezuela)
   ============================================================ */
capture confirm file "${identity}/Corrupcion/replication-package-jpe/data/raw/protest/VDEM/vdem cy full others.dta"
if _rc == 0 local vdem "${identity}/Corrupcion/replication-package-jpe/data/raw/protest/VDEM/vdem cy full others.dta"
else        local vdem "${path}/Data/raw/VDEM/VDEM CY Full Others.dta"

foreach idx in polyarchy libdem {
	if "`idx'"=="polyarchy" local out "democracy_elec_ven.tex"
	else                    local out "democracy_lib_ven.tex"

	use "`vdem'", clear
	keep country_name year v2x_`idx'
	keep if year == 2008
	replace country_name = "Dominican Republic" if country_name == "Dominican Rep."
	rename country_name country
	rename v2x_`idx' demo_index
	keep country demo_index
	tempfile vd
	save `vd'

	use "${datfin}/protests_scandals_30days_v3", clear
	merge m:1 country using `vd', keep(1 3) nogenerate
	preserve
		keep if !missing(demo_index)
		bysort country: keep if _n == 1
		xtile terc3 = demo_index, nq(3)
		keep country terc3
		tempfile terc
		save `terc'
	restore
	merge m:1 country using `terc', keep(1 3) nogenerate
	gen byte grp_low     = (terc3==1)            if !missing(terc3)
	gen byte grp_medhigh = (terc3==2 | terc3==3) if !missing(terc3)
	gen byte post_low     = post * grp_low
	gen byte post_medhigh = post * grp_medhigh
	egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 s_lead30 s_lead60 s_lead90 s_lead120)
	tempfile based
	save `based'

	eststo clear
	forvalues k = 1/`nsp' {
		local outcome : word `k' of `out_list'
		local window  : word `k' of `win_list'
		use `based', clear
		eststo m`k': reghdfe `outcome' post_medhigh post_low i.month i.day ///
			if year >= `firstyear' & abs(window) <= `window' & !missing(terc3), ///
			absorb($fe1) vce($CLUSTER2)
		quietly summarize `outcome' if e(sample) & window >= -`window' & window <= -1
		estadd scalar baseline = r(mean)
		test post_medhigh = post_low
		local p2 = r(p)
		estadd scalar p_mh_l = `p2'
		quietly lincom post_medhigh - post_low
		if r(estimate) > 0 estadd scalar p_mh_gt_l = `p2'/2
		else               estadd scalar p_mh_gt_l = 1 - `p2'/2
	}
	esttab _all using "${tables}/`out'", replace booktabs nonotes nogaps b(3) se(3) ///
		star(* 0.10 ** 0.05 *** 0.01) ///
		mtitles("\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}" ///
		        "\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}" ///
		        "\shortstack{Violent\\Protests}" "\shortstack{Peaceful\\Protests}") ///
		mgroups("$\pm 30$-Day Window" "$\pm 60$-Day Window" "$\pm 90$-Day Window", ///
		        pattern(1 0 1 0 1 0) prefix(\multicolumn{2}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
		stats(p_mh_l p_mh_gt_l baseline N r2, ///
		      label("p-value: Medium+High $$=$$ Low" "p-value: Medium+High $$>$$ Low (one-sided)" ///
		            "Mean (Pre-Scandal)" "Observations" "R-squared") fmt(3 3 3 0 3)) ///
		keep(post_medhigh post_low) ///
		coeflabels(post_medhigh "Post $\times$ Medium+High" post_low "Post $\times$ Low") ///
		substitute("$$" "$")
	di as result "`out' written"
}

/* ============================================================
   FIGURE 1 - subsample event study (incl. Venezuela), w60 b15
   ============================================================ */
use "${datfin}/protests_scandals_30days_v3", clear
merge m:1 id country using `cls', keep(1 3) nogenerate
gen byte in_pa = 0
replace in_pa = 1 if position == "president"
replace in_pa = 1 if position == "governor"
replace in_pa = 1 if position == "sc_judge_congressman" & inlist(id,"202","NEW26","NEW30","332")
gen byte in_na = 0
replace in_na = 1 if position == "sc_judge_congressman" & !inlist(id,"202","NEW26","NEW30","332")
replace in_na = 1 if position == "other_judiciary"
replace in_na = 1 if position == "others"
egen group_cluster = group(country_id year s_lag30 s_lag60 s_lag90 s_lag120 s_lead30 s_lead60 s_lead90 s_lead120)
egen auxvar = group(country year)
tempfile basees
save `basees'

local B = 15
local T = 60
local nb = `T'/`B'
local esvars ""
forvalues j = `nb'(-1)2 {
	local esvars "`esvars' ebin_m`j'"
}
forvalues j = 1/`nb' {
	local esvars "`esvars' ebin_p`j'"
}
local xlabs ""
forvalues bi = -`nb'/`=`nb'-1' {
	if `bi' < 0 local d = `bi'*`B'
	else        local d = (`bi'+1)*`B'
	if mod(`d', 15) == 0 local xlabs "`xlabs' `d'"
}

foreach oc in num_violent_MM num_peaceful_MM {
	local ostub = cond("`oc'"=="num_violent_MM","violent","peaceful")
	/* common y-range across the two subsamples for this outcome */
	local ymin = 0
	local ymax = 0
	foreach sample in pa na {
		use `basees', clear
		gen int ebin = .
		replace ebin =  floor(window/`B') + 1        if window >= 0
		replace ebin = -(floor((-window-1)/`B') + 1) if window <  0
		forvalues j = 2/`nb' {
			gen byte ebin_m`j' = (ebin == -`j')
		}
		forvalues j = 1/`nb' {
			gen byte ebin_p`j' = (ebin ==  `j')
		}
		quietly reghdfe `oc' `esvars' if year >= `firstyear' & abs(window) <= `T' & in_`sample'==1, ///
			absorb(month day auxvar) cluster(group_cluster)
		foreach v of local esvars {
			local ymin = min(`ymin', _b[`v'] - `zcrit'*_se[`v'])
			local ymax = max(`ymax', _b[`v'] + `zcrit'*_se[`v'])
		}
	}
	local rng = `ymax' - `ymin'
	if `rng' <= 0 local rng = 0.01
	local ylo = `ymin' - 0.08*`rng'
	local yhi = `ymax' + 0.08*`rng'
	local raw = (`yhi'-`ylo')/6
	local mag = 10^floor(log10(`raw'))
	local mult = `raw'/`mag'
	if `mult' < 1.5      local step = 1*`mag'
	else if `mult' < 3.5 local step = 2*`mag'
	else if `mult' < 7.5 local step = 5*`mag'
	else                 local step = 10*`mag'
	local ylo_t = floor(`ylo'/`step')*`step'
	local yhi_t = ceil(`yhi'/`step')*`step'
	local xpad = 0.6*`B'
	local xlo_ax = -`nb'*`B' - `xpad'
	local xhi_ax =  `nb'*`B' + `xpad'

	foreach sample in pa na {
		use `basees', clear
		gen int ebin = .
		replace ebin =  floor(window/`B') + 1        if window >= 0
		replace ebin = -(floor((-window-1)/`B') + 1) if window <  0
		forvalues j = 2/`nb' {
			gen byte ebin_m`j' = (ebin == -`j')
		}
		forvalues j = 1/`nb' {
			gen byte ebin_p`j' = (ebin ==  `j')
		}
		quietly reghdfe `oc' `esvars' if year >= `firstyear' & abs(window) <= `T' & in_`sample'==1, ///
			absorb(month day auxvar) cluster(group_cluster)
		local nrows = 2*`nb'
		matrix B = J(`nrows', 3, .)
		matrix colnames B = day b se
		local row = 0
		forvalues bi = -`nb'/`=`nb'-1' {
			local ++row
			matrix B[`row',1] = `bi'*`B'
			if `bi' == -1 {
				matrix B[`row',2] = 0
				matrix B[`row',3] = 0
			}
			else if `bi' <= -2 {
				local jj = -`bi'
				matrix B[`row',2] = _b[ebin_m`jj']
				matrix B[`row',3] = _se[ebin_m`jj']
			}
			else {
				local jj = `bi'+1
				matrix B[`row',2] = _b[ebin_p`jj']
				matrix B[`row',3] = _se[ebin_p`jj']
			}
		}
		preserve
			clear
			svmat B, names(col)
			replace day = day + `B' if day >= 0
			gen ci_lo = b - `zcrit'*se
			gen ci_hi = b + `zcrit'*se
			twoway (rspike ci_lo ci_hi day, lcolor(black) lwidth(medthick)) ///
			       (scatter b day, mcolor(black) msymbol(O) msize(medlarge)), ///
				xline(0, lcolor(black%10) lwidth(vvthick) lpattern(solid)) ///
				yline(0, lpattern(dash) lcolor(black)) ///
				ytitle("Effect on protests", size(medium)) ///
				yscale(range(`ylo_t' `yhi_t')) ///
				ylabel(`ylo_t'(`step')`yhi_t', format(%5.3fc) angle(0)) ///
				xtitle("Days since scandal", size(medium)) ///
				xscale(range(`xlo_ax' `xhi_ax')) ///
				xlabel(`xlabs', labsize(medium)) ///
				graphregion(color(white) fcolor(white)) scheme(s2color) legend(off)
			graph export "${figout}/es_ven_`ostub'_`sample'.pdf", replace
		restore
	}
}
di as result "es_ven_*.pdf written"

display in green "a_including_ven.do finished OK"
