/* ----------------------------------------------------------------------------
   Master runner for the NEW / UPDATED evidence (2026-07 restructuring around
   the President + Other Apex vs Other Non-Apex split).

   Each script below has its own username-based config block, so no globals
   need to be re-asserted between calls.  Scripts are ordered by dependency:
     - the randomization-inference percentile reader (a_sup_ri_percentile.do)
       must run AFTER both RI scripts, which save the placebo .dta files.
     - everything else is independent.

   Wrapped in `capture noisily` so one failure does not abort the batch; the
   failure list prints at the end.

   NOTE (slow scripts): the two randomization-inference scripts run 1,000
   placebo replications per cell and the four modern-DiD scripts call
   did_multiplegt_dyn / did_imputation / eventstudyinteract; expect these to
   take a while.  Comment out any you do not want to refresh.
---------------------------------------------------------------------------- */

set more off

global runner_failures = 0
global runner_failed_list ""

local scripts ///
	a_reg_violent_peaceful_panels.do ///
	a_sup_violent_peaceful_panels_poisson.do ///
	a_sup_interaction_pa_vs_na.do ///
	a_sup_event_study_pa_vs_na.do ///
	a_sup_placebo_within_window.do ///
	a_sup_placebo_within_window_pa_vs_na.do ///
	a_randomization_inference.do ///
	a_randomization_inference_pa_vs_na.do ///
	a_sup_ri_percentile.do ///
	a_sup_window_sensitivity.do ///
	a_sup_democracy_split.do ///
	poisson_reg_football.do ///
	poisson_reg_depreciation.do ///
	a_sup_benchmarks.do ///
	a_did_modern.do ///
	a_did_modern_pa_vs_na.do ///
	a_did_modern_stacked.do ///
	a_did_modern_stacked_pa_vs_na.do

local total : word count `scripts'

local i = 0
foreach s of local scripts {
	local ++i
	di as result _newline _newline ///
		"================================================================" _newline ///
		" Running `i' / `total':  `s'" _newline ///
		"================================================================"
	capture noisily do `s'
	if _rc {
		global runner_failures = ${runner_failures} + 1
		global runner_failed_list "${runner_failed_list} `s'(_rc=`=_rc')"
		di as error "FAILED: `s' with _rc = `=_rc'"
	}
	else {
		di as txt "OK: `s'"
	}
}

di as result _newline _newline ///
	"================================================================" _newline ///
	" New-evidence master runner finished" _newline ///
	"================================================================"
di as result "Scripts run:    `total'"
di as result "Failures:       ${runner_failures}"
if "${runner_failed_list}" != "" {
	di as error "Failed scripts: ${runner_failed_list}"
}
