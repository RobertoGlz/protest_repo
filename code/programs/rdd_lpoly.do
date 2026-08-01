/* ----------------------------------------------------------------------------
   Apex corruption protests paper

   RD-in-time helper: non-parametric (local-polynomial) RD estimate + plot.
   Adapted from ~/research-repos/electoral_bbj_repo/code/programs/rdd_lpoly.do
   (author: Roberto Gonzalez) for this project:
     - running variable is event-time in DAYS (integer x-axis labels);
     - the outcome passed in is ALREADY residualised on the fixed effects
       (so no covariate partialling here); pass covs() only if you want extra
       linear controls;
     - graphs export to PDF;
     - the estimate (tau, se, p) is returned in r().

   Uses rdrobust for the estimate/bandwidth and lpolyci for the fit.
---------------------------------------------------------------------------- */

capture program drop rdd_lpoly
program define rdd_lpoly, rclass

	syntax [if], outcome(varname) runvar(varname) rangemin(real) rangemax(real) ///
		cluster(varname) kernel(string) bwscale(real) bwselect(string)   ///
		outputfolder(string) [covs(varlist)] [ytitle(string)]            ///
		[graphname(string)] [cilevel(integer 90)] [polycolor(string)]    ///
		[xstep(real 15)] [ylo(real 0)] [yhi(real 0)] [ystep(real 0.02)]  ///
		[nbins(integer 12)]

	marksample touse, novarlist
	markout `touse' `outcome' `runvar'
	quietly replace `touse' = 0 if `runvar' < `rangemin' | `runvar' > `rangemax'

	local cov_opt ""
	if "`covs'" != "" local cov_opt "covs(`covs')"

	/* ---- data-driven bandwidth, then re-estimate at scaled bandwidth ---- */
	rdrobust `outcome' `runvar' if `touse', c(0) kernel(`kernel') ///
		bwselect(`bwselect') vce(cluster `cluster') `cov_opt' all
	local h_opt    = e(h_l)
	local h_scaled = `h_opt' * `bwscale'

	rdrobust `outcome' `runvar' if `touse', c(0) kernel(`kernel') ///
		h(`h_scaled') vce(cluster `cluster') `cov_opt' all
	local coef = e(tau_cl)
	local se   = e(se_tau_cl)

	/* ---- residualise on extra covariates for plotting (usually none) ---- */
	tempvar yplot
	if "`covs'" != "" {
		quietly regress `outcome' `covs' if `touse'
		quietly predict `yplot' if `touse', residuals
	}
	else {
		quietly generate double `yplot' = `outcome' if `touse'
	}

	if "`ytitle'" == ""    local ytitle "`outcome'"
	if "`polycolor'" == "" local polycolor "0 71 133"

	local tau_p = 2*normal(-abs(`coef'/`se'))
	if `tau_p' < 0.01 {
		local TAU = "{&tau} = " + string(`coef', "%6.3fc") + " (p < 0.01)"
	}
	else {
		local TAU = "{&tau} = " + string(`coef', "%6.3fc") + " (p = " + string(`tau_p', "%4.3fc") + ")"
	}

	/* ---- equal-width binned means either side of the cutoff ---- */
	/* fixed number of equal-width bins per side (nbins), independent of the
	   estimation bandwidth, so the scatter shows enough points */
	local totbins_l = `nbins'
	local totbins_r = `nbins'
	local bw_l = abs(`rangemin') / `totbins_l'
	local bw_r = `rangemax' / `totbins_r'
	capture drop _rdbin _rvb _ycb
	quietly generate _rdbin = min(floor((`runvar' - `rangemin') / `bw_l') + 1, `totbins_l') if `touse' & `runvar' < 0
	quietly replace  _rdbin = min(floor(`runvar' / `bw_r') + 1, `totbins_r')                if `touse' & `runvar' >= 0
	quietly generate _rvb = `rangemin' + (_rdbin - 0.5) * `bw_l' if `touse' & `runvar' < 0
	quietly replace  _rvb = (_rdbin - 0.5) * `bw_r'             if `touse' & `runvar' >= 0
	quietly generate _ycb = .
	quietly bysort _rdbin : egen _tm = mean(`yplot') if `touse' & `runvar' < 0
	quietly replace _ycb = _tm if `touse' & `runvar' < 0
	drop _tm
	quietly bysort _rdbin : egen _tm = mean(`yplot') if `touse' & `runvar' >= 0
	quietly replace _ycb = _tm if `touse' & `runvar' >= 0
	drop _tm

	local kp "`kernel'"
	if "`kernel'" == "triangular" local kp "triangle"

	if `ylo' != `yhi' {
		local yopts "yscale(range(`ylo' `yhi')) ylabel(`ylo'(`ystep')`yhi', labsize(medium) format(%4.3fc) angle(horizontal))"
	}
	else {
		local yopts "ylabel(, labsize(medium) format(%4.3fc) angle(horizontal))"
	}

	twoway ///
		(lpolyci `yplot' `runvar' if `touse' & `runvar' < 0 & inrange(`runvar', `rangemin', `rangemax'), ///
			kernel(`kp') bwidth(`h_scaled') degree(1) level(`cilevel') ///
			acolor("`polycolor'%20") alwidth(none) lcolor("`polycolor'") lpattern(solid)) ///
		(lpolyci `yplot' `runvar' if `touse' & `runvar' >= 0 & inrange(`runvar', `rangemin', `rangemax'), ///
			kernel(`kp') bwidth(`h_scaled') degree(1) level(`cilevel') ///
			acolor("`polycolor'%20") alwidth(none) lcolor("`polycolor'") lpattern(solid)) ///
		(scatter _ycb _rvb if `touse' & inrange(_rvb, `rangemin', `rangemax'), ///
			msize(medsmall) msymbol(O) color("`polycolor'")), ///
		legend(order(1 "`cilevel'% CI" 2 "Local linear fit" 5 "Binned means" - "`TAU'") ///
			row(2) pos(6) region(lcolor(gs10))) ///
		xlabel(`rangemin'(`xstep')`rangemax', labsize(medium) nogrid) ///
		`yopts' ///
		ytitle("`ytitle'", size(medium)) ///
		xtitle("Days since scandal", size(medium)) ///
		graphregion(color(white) fcolor(white)) scheme(s2color) ///
		note("Bandwidth h = `=round(`h_scaled', 1)' days (scale `bwscale' of MSE-optimal); kernel `kernel'.", size(vsmall))

	if "`graphname'" == "" local graphname "rdd_`outcome'"
	capture mkdir "`outputfolder'"
	graph export "`outputfolder'/`graphname'.pdf", replace
	capture drop _rdbin _rvb _ycb

	return scalar tau  = `coef'
	return scalar se   = `se'
	return scalar pval = `tau_p'
	return scalar h    = `h_scaled'
end
