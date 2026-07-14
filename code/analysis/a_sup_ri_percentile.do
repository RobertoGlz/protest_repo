/* ----------------------------------------------------------------------------
   Project: Apex Corruption protests paper - SUPPLEMENTARY MATERIALS

   Code author: Roberto Gonzalez
   Date: 2026-07-13

   Objective:
     "Scandals as random" revisit.  The team recalled that, in an earlier
     (2024) permutation exercise, the observed violent-protest effect fell
     around the 90th percentile of the placebo distribution.  This do-file
     re-expresses the CURRENT randomization-inference output (produced by
     a_randomization_inference.do and a_randomization_inference_pa_vs_na.do)
     in the same percentile/rank language, so the two exercises can be
     compared directly.

     It does NOT re-run the permutation loop -- it just reads the saved
     placebo-beta distributions and, for each (subsample, outcome, window)
     cell, reports:
        - observed beta
        - one-sided upper percentile of the observed beta among the
          placebo betas  = 100 * share(beta_placebo <= observed_beta)
          (a value near 90 reproduces the 2024 "~90th percentile" figure)
        - rank of the observed beta (1 = largest) among placebos+observed
        - two-sided randomization-inference p-value
          = share(|beta_placebo| >= |observed_beta|)

     Outputs a compact LaTeX table for the appendix and prints the same
     numbers to the log.

   Inputs (produced by the two RI do-files, under ${resout}):
     - randomization_inference_beta_<outcome>_w<T>.dta            (full)
     - randomization_inference_beta_<outcome>_w<T>_<sample>.dta   (pa / na)

   Outputs (paper/tables/):
     - sup_ri_percentile.tex
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
global tables  "${identity}/Corrupcion/protest_repo/paper/tables"

/* Collect results into a postfile */
tempname P
postfile `P' str8 sample str16 outcome int T ///
	double obs_beta double pctile double rank double n_pl double p_two ///
	using "${work}/temp/ri_percentile_summary.dta", replace

foreach sample in full pa na {
foreach outcome in num_violent_MM num_peaceful_MM {
foreach T in 30 120 {

	if "`sample'" == "full" {
		local f "${resout}/randomization_inference_beta_`outcome'_w`T'.dta"
	}
	else {
		local f "${resout}/randomization_inference_beta_`outcome'_w`T'_`sample'.dta"
	}

	capture confirm file "`f'"
	if _rc {
		display in red "MISSING: `f' (run the RI do-file first) -- skipped"
		continue
	}

	use "`f'", clear
	quietly count if !missing(beta_placebo)
	local npl = r(N)
	local obs = observed_beta[1]

	quietly count if !missing(beta_placebo) & beta_placebo <= `obs'
	local pct = 100 * r(N) / `npl'

	quietly count if !missing(beta_placebo) & beta_placebo > `obs'
	local rank = r(N) + 1

	quietly count if !missing(beta_placebo) & abs(beta_placebo) >= abs(`obs')
	local p2 = r(N) / `npl'

	post `P' ("`sample'") ("`outcome'") (`T') ///
		(`obs') (`pct') (`rank') (`npl') (`p2')

	display as result "[`sample' | `outcome' | T=`T'] " ///
		"obs=" %7.4f `obs' "  pct=" %5.1f `pct' ///
		"  rank=" %4.0f `rank' "/" %5.0f (`npl'+1) "  p2=" %5.3f `p2'
}
}
}
postclose `P'

/* ============================================================
   Build a compact LaTeX table
   ============================================================ */
use "${work}/temp/ri_percentile_summary.dta", clear

gen str24 samplelab = ""
replace samplelab = "Full sample"            if sample == "full"
replace samplelab = "President + Other Apex" if sample == "pa"
replace samplelab = "Other Non-Apex"         if sample == "na"

gen str20 outlab = ""
replace outlab = "Violent"  if outcome == "num_violent_MM"
replace outlab = "Peaceful" if outcome == "num_peaceful_MM"

gen order_s = cond(sample=="full",1,cond(sample=="pa",2,3))
gen order_o = cond(outcome=="num_violent_MM",1,2)
sort order_s order_o T

local dol = char(36)   /* literal $, so Stata does not expand $p$ as a macro */

capture file close _t
file open _t using "${tables}/sup_ri_percentile.tex", write replace
file write _t "\begin{tabular}{llccc}" _n
file write _t "\toprule" _n
file write _t "Subsample & Outcome & Window & Percentile & RI `dol'p`dol' (two-sided) \\" _n
file write _t "\midrule" _n

local curr_s ""
forvalues i = 1/`=_N' {
	local sl = samplelab[`i']
	local ol = outlab[`i']
	local tt = T[`i']
	local pc = string(pctile[`i'], "%4.1f")
	local p2 = string(p_two[`i'],  "%5.3f")

	/* print the subsample label only on its first row */
	if "`sl'" != "`curr_s'" {
		if "`curr_s'" != "" file write _t "\midrule" _n
		local slcell "`sl'"
		local curr_s "`sl'"
	}
	else {
		local slcell ""
	}
	file write _t "`slcell' & `ol' & $\pm`tt'$ & `pc' & `p2' \\" _n
}
file write _t "\bottomrule" _n
file write _t "\end{tabular}" _n
file close _t

display in green "a_sup_ri_percentile.do finished OK -> sup_ri_percentile.tex"
