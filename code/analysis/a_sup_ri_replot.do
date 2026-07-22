/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper

   Objective:
     Re-draw ALL randomization-inference histograms from the saved placebo
     distributions (no re-estimation).  Reads the per-cell beta datasets
     written by a_randomization_inference_pa_vs_na.do (pa/na) and
     a_randomization_inference.do (full sample) and re-exports each PDF with
     the updated legend:

        - the maroon vertical line stays at the observed beta;
        - the observed-beta VALUE moves OFF the plot area into the legend as
          its own row (the old floating vertical text label was clipped when
          the observed line sat near the top of the axis);
        - a second legend row keeps the two-sided RI p-value.

   Inputs (under ${resout}):
     - randomization_inference_beta_<outcome>_w<T>_<sample>.dta   (pa, na)
     - randomization_inference_beta_<outcome>_w<T>.dta            (full)

   Outputs (paper/figures/): same filenames as the estimation do-files, so the
   \includegraphics paths in the paper are unchanged.
---------------------------------------------------------------------------- */

set more off
clear all

if "`c(username)'" == "Diego" {
	gl identity "D:/Documents/Dropbox"
}
if "`c(username)'" == "dtocre" {
	gl identity "C:/Users/dtocre/Dropbox"
}
if "`c(username)'" == "lalov" {
	gl identity "C:/Users/lalov/ITAM Seira Research Dropbox/Eduardo Rivera"
}
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox"
}
if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}

global work    "${identity}/Corrupcion/Protest_Work"
global resout  "${work}/results"
global figout  "${identity}/Corrupcion/protest_repo/paper/figures"

/* ============================================================
   Loop over every (sample, outcome, window) cell and re-draw
   ============================================================ */
foreach sample in pa na full {
foreach outcome in num_violent_MM num_peaceful_MM {
foreach T in 30 60 90 120 {

	/* per-cell dataset name: pa/na carry the suffix, full does not */
	if "`sample'" == "full" local dta "${resout}/randomization_inference_beta_`outcome'_w`T'.dta"
	else                    local dta "${resout}/randomization_inference_beta_`outcome'_w`T'_`sample'.dta"

	capture confirm file "`dta'"
	if _rc {
		display in red "MISSING (skipped): `dta'"
		continue
	}

	use "`dta'", clear

	/* observed beta is stored as a constant column in the dataset */
	quietly summarize observed_beta, meanonly
	local observed_beta_T = r(mean)

	/* two-sided RI p-value = share of placebo draws at least as extreme */
	quietly count if !missing(beta_placebo)
	local n_valid = r(N)
	quietly count if !missing(beta_placebo) & abs(beta_placebo) >= abs(`observed_beta_T')
	local ri_p_two = r(N) / `n_valid'

	local obs_str = string(`observed_beta_T', "%5.3f")
	local p2_str  = string(`ri_p_two',        "%5.3f")

	if "`outcome'" == "num_violent_MM"  local outlbl "violent protests"
	if "`outcome'" == "num_peaceful_MM" local outlbl "peaceful protests"

	/* invisible dummy series that seed the two legend rows:
	   _leg_beta -> a maroon line key (matches the observed-beta line)
	   _leg_p    -> a blank key (p-value row, text only)                 */
	gen double _leg_beta = .
	gen double _leg_p    = .

	/* x-axis wide enough to show BOTH the placebo mass and the observed line */
	quietly summarize beta_placebo
	local xlo = min(r(min), `observed_beta_T', 0)
	local xhi = max(r(max), `observed_beta_T', 0)
	local xrng = `xhi' - `xlo'
	if `xrng' <= 0 local xrng = 0.01
	local xlo = `xlo' - 0.10 * `xrng'
	local xhi = `xhi' + 0.10 * `xrng'
	local xraw = (`xhi' - `xlo') / 5
	local xmag = 10 ^ floor(log10(`xraw'))
	local xmul = `xraw' / `xmag'
	if `xmul' < 1.5      local xstep = 1  * `xmag'
	else if `xmul' < 3.5 local xstep = 2  * `xmag'
	else if `xmul' < 7.5 local xstep = 5  * `xmag'
	else                 local xstep = 10 * `xmag'
	local xlo_t = floor(`xlo' / `xstep') * `xstep'
	local xhi_t = ceil( `xhi' / `xstep') * `xstep'

	twoway (histogram beta_placebo, percent bin(50) ///
	            color(gs13) lcolor(gs10)) ///
	       (line _leg_beta beta_placebo, lcolor("128 0 0") lwidth(medthick)) ///
	       (line _leg_p    beta_placebo, lcolor(none)), ///
		xline(`observed_beta_T', lcolor("128 0 0") lwidth(medthick) ///
		     lpattern(solid)) ///
		xline(0, lcolor(black) lwidth(vthin) lpattern(dot)) ///
		xtitle("Effect on `outlbl'", size(medium)) ///
		ytitle("Percent", size(medium)) ///
		xscale(range(`xlo_t' `xhi_t')) ///
		xlabel(`xlo_t'(`xstep')`xhi_t', format(%5.3f) labsize(small)) ///
		ylabel(, angle(0) format(%3.0f)) ///
		legend(order(2 3) ///
		       label(2 "Observed {&beta} = `obs_str'") ///
		       label(3 "RI p = `p2_str'") ///
		       cols(1) pos(2) ring(0) ///
		       region(lcolor(black) fcolor(white)) size(medsmall)) ///
		scheme(s2color) graphregion(color(white))

	if "`sample'" == "full" local fig "${figout}/randomization_inference_hist_`outcome'_w`T'.pdf"
	else                    local fig "${figout}/randomization_inference_hist_`outcome'_w`T'_`sample'.pdf"
	graph export "`fig'", replace
	display in green "re-drew: `fig'"
}
}
}

display in green "a_sup_ri_replot.do finished OK"
