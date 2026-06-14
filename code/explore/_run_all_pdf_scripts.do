/* ----------------------------------------------------------------------------
	Master runner: regenerate every table/figure that Work_2026.tex inputs.

	Runs all 21 explore/ scripts that produce the PDF's tables & figures,
	under the new `year >= 2008` floor (applied via sed across the explore
	scripts on 2026-05-21).

	Each `do` call gets its own clean local environment.  Globals persist
	across calls but are typically reset by each script's config block at
	the top, so chaining is safe.

	If any script errors, `capture` lets us continue to the next one and
	collects the failure count at the end.
---------------------------------------------------------------------------- */

clear all
set more off

global runner_failures = 0
global runner_failed_list ""

/* List of scripts that produce Work_2026.tex inputs (order doesn't matter --
   each is independent of the others).  All read protests_scandals_30days_v3
   or corruption_news_LB and write to ${work}/results/{tables,figures}/. */
local scripts ///
	a_reg_allscandals.do ///
	a_reg_allscandals_dummyoutcome.do ///
	a_reg_allscandals_scandalfe.do ///
	a_reg_allscandals_dummyoutcome_scandalfe.do ///
	a_reg_allscandals_narrowbw.do ///
	a_reg_onlyfirst_scandal.do ///
	a_reg_onlyfirst_scandal_dummyoutcomes.do ///
	a_reg_LB_scandals.do ///
	a_reg_LB_scandals_dummyoutcome.do ///
	a_reg_allscandals_incumbent_presi.do ///
	a_reg_allscandals_incumbent_presi_narrowbw.do ///
	a_reg_allscandals_incumbent_governor.do ///
	a_reg_allscandals_incumbent_governor_narrowbw.do ///
	a_reg_allscandals_inc_presi_v_gov.do ///
	a_poissreg_allscandals.do ///
	a_poissreg_allscandals_narrobw.do ///
	a_poissreg_onlyfirst_scandal.do ///
	a_poissregreg_allscandals_scandalfe.do ///
	a_poissreg_allscandals_incumbent_presi.do ///
	a_poissreg_allscandals_incumbent_presi_narrowbw.do ///
	a_poissreg_allscandals_inc_presi_v_gov.do

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
	" Master runner finished" _newline ///
	"================================================================"
di as result "Scripts run:    `total'"
di as result "Failures:       ${runner_failures}"
if "${runner_failed_list}" != "" {
	di as error "Failed scripts: ${runner_failed_list}"
}
