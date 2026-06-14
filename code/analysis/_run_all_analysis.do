/* ----------------------------------------------------------------------------
	Master runner: re-run every code/analysis/ script under firstyear = 2008.

	The year floor was swept to 2008 across all analysis scripts on
	2026-05-21 (firstyear local).  This runner regenerates every analysis
	output so all results are consistent at the 2008 floor.

	Globals are re-asserted before each `do` call: a couple of analysis
	scripts (ppmlhdfe_main_by_position.do, make_panels_poisson.do) have no
	config block and inherit ${identity}/${work}/${path}/${datfin}; and a
	`clear all` inside any script would otherwise wipe them for the next.

	Each script is wrapped in `capture noisily` so one failure does not
	abort the batch; the failure list is printed at the end.

	a_acled_validation.do is intentionally excluded -- its 2018 cutoff is
	dictated by ACLED coverage, not the firstyear floor, so re-running it
	would just redo Task 3 with no change.

	csdid_main.do is intentionally excluded -- csdid's bootstrap is very
	slow; run it on its own when needed.
---------------------------------------------------------------------------- */

set more off

global runner_failures = 0
global runner_failed_list ""

/* Scripts to run.  make_* assembly scripts last (they combine panels other
   scripts produce). */
local scripts ///
	ols_main.do ///
	poisson_reg_main.do ///
	poisson_reg_main_countryxyear_fe.do ///
	poisson_reg_main_nooverlap.do ///
	poisson_minimalist_check.do ///
	ppmlhdfe_corruption_countryfe_yearfe.do ///
	ppmlhdfe_reg_main_countryxyear_fe.do ///
	ppmlhdfe_reg_main_countryxyear_fe_by_lv_of_official.do ///
	ppmlhdfe_main_by_position.do ///
	protests_as_dummies_poisson_v3_vs_raw.do ///
	raw_mm_data_ppmlhdfe.do ///
	raw_mm_data_bjs.do ///
	bjs_main.do ///
	bjs_main_w_month_day_fes.do ///
	poisson_reg_depreciation.do ///
	poisson_reg_depreciation_nooverlap.do ///
	poisson_reg_football.do ///
	a_depreciations_as_random.do ///
	a_football_losses_as_random.do ///
	a_6_8_months_altspecs.do ///
	a_6_8_months_altspecs_mildscandals.do ///
	a_protests_gvr_gnv.do ///
	a_protests_gvr_gnv_nooverlap.do ///
	a_protests_gvr_gnv_6month.do ///
	a_protests_gvr_gnv_6month_nooverlap.do ///
	a_did_modern.do ///
	a_weekend_vs_weekday.do ///
	per_scandal_effects.do ///
	make_alternative_specs.do ///
	make_panels_poisson.do

local total : word count `scripts'

local i = 0
foreach s of local scripts {
	local ++i

	/* Re-assert globals (defensive: survives any prior script's clear all) */
	global identity "~/Dropbox"
	global work    "${identity}/Corrupcion/Protest_Work"
	global path    "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
	global datfin  "${path}/Data/final"

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
	" Analysis master runner finished" _newline ///
	"================================================================"
di as result "Scripts run:    `total'"
di as result "Failures:       ${runner_failures}"
if "${runner_failed_list}" != "" {
	di as error "Failed scripts: ${runner_failed_list}"
}
