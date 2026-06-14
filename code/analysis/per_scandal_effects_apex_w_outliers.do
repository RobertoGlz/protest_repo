/* ----------------------------------------------------------------------------
						Violent effects of apex corruption

	Code author: Roberto Gonzalez
	Date: 2026-05-22

	Same as per_scandal_effects_apex.do (President / Other Apex / Other
	Non-Apex, from `position' with the sc_judge_congressman split), but
	the box plots are produced WITH OUTLIERS SHOWN (no `nooutsides').
	Box plots only -- no jitter.

	Outputs (in ${work}/results/figures/):
		per_scandal_box_<outcome>_w30_apex_w_outliers.pdf
---------------------------------------------------------------------------- */

if "`c(username)'" == "lalov" {
	gl identity "C:/Users/lalov/ITAM Seira Research Dropbox/Eduardo Rivera"
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
global figout "${work}/results/figures"

local window_length = 30
local outcome_list = "num_protests_MM num_violent_MM num_peaceful_MM government_response_violent"
local outcome_number : word count `outcome_list'

/* ============================================================
   READ AND PREPARE
   ============================================================ */
use "${datfin}/protests_scandals_30days_v3_with_lv_of_agent_involved.dta", clear
drop if country == "Venezuela"
keep if abs(window) <= `window_length'

egen scandal_enc = group(id)
egen scandal_tag = tag(id)

gen double _sd = date if window == 0
bysort scandal_enc (_sd): replace _sd = _sd[1]
format _sd %td

bysort scandal_enc: egen _pm = mean(post)
drop if _pm == 0 | _pm == 1
drop _pm

quietly levelsof scandal_enc, local(slevels)
local n_scandals : word count `slevels'
display in yellow "Per-scandal regressions: `n_scandals' scandals x `outcome_number' outcomes"

preserve
	keep if scandal_tag == 1
	keep scandal_enc id country official_involved _sd
	rename _sd scandal_date
	tempfile metadata
	save `metadata'
restore

/* ============================================================
   PER-SCANDAL REGRESSIONS
   ============================================================ */
matrix define scandal_info = J(`n_scandals', 3*`outcome_number', .)

forvalues s = 1/`n_scandals' {
	local oc = 0
	foreach outcome of local outcome_list {
		local ++oc
		quietly count if !missing(`outcome') & scandal_enc == `s'
		local nobs = r(N)
		if `nobs' > 30 {
			capture reghdfe `outcome' post if scandal_enc == `s', ///
				absorb(month day) vce(robust)
			if _rc == 0 & !missing(_b[post]) & _se[post] < . & _se[post] > 0 {
				matrix scandal_info[`s', 3*`oc'-2] = _b[post]
				matrix scandal_info[`s', 3*`oc'-1] = _se[post]
				matrix scandal_info[`s', 3*`oc']   = `nobs'
			}
		}
	}
}

clear
svmat scandal_info
generate scandal_enc = _n
merge 1:1 scandal_enc using `metadata', nogenerate

local oc = 0
foreach outcome of local outcome_list {
	local ++oc
	rename scandal_info`=3*`oc'-2' b_`outcome'
	rename scandal_info`=3*`oc'-1' se_`outcome'
	rename scandal_info`=3*`oc''   n_`outcome'
}

/* ============================================================
   MERGE IN position FROM scandals_classified.csv
   ============================================================ */
preserve
	import delimited using "${datfin}/scandals_classified.csv", ///
		clear varnames(1) bindquotes(strict)
	keep id country position
	tempfile cls
	save `cls'
restore
merge 1:1 id country using `cls', keep(1 3) nogenerate

/* ============================================================
   THREE-WAY CLASSIFICATION: President / Other Apex / Other Non-Apex
   (sc_judge_congressman split: 4 SC judges -> Non-Apex, rest -> Apex)
   ============================================================ */
gen byte apex_cat = .
replace apex_cat = 1 if position == "president"
replace apex_cat = 2 if position == "governor"
replace apex_cat = 2 if position == "sc_judge_congressman"
replace apex_cat = 3 if position == "sc_judge_congressman" & ///
	inlist(id, "202", "NEW26", "NEW30", "332")
replace apex_cat = 3 if position == "other_judiciary"
replace apex_cat = 3 if position == "others"

label define APEX 1 "President" 2 "Other Apex" 3 "Other Non-Apex", replace
label values apex_cat APEX
label variable apex_cat "Official involved (President / Other Apex / Other Non-Apex)"

di as result "=== Scandals by apex_cat ==="
tab apex_cat, missing

/* ============================================================
   BOX PLOTS (OUTLIERS SHOWN -- no `nooutsides')
   ============================================================ */
foreach outcome of local outcome_list {

	if "`outcome'" == "num_protests_MM"             local ytitle "protests (any)"
	if "`outcome'" == "num_violent_MM"              local ytitle "violent protests"
	if "`outcome'" == "num_peaceful_MM"             local ytitle "peaceful protests"
	if "`outcome'" == "government_response_violent" local ytitle "gvt. violent response"

	display in yellow "=== Per-scandal `outcome': by apex_cat ==="
	tabstat b_`outcome', by(apex_cat) ///
		statistics(n mean p50 sd min max) columns(statistics)

	graph box b_`outcome', over(apex_cat, label(labsize(small))) ///
		ytitle("Per-scandal effect on `ytitle'") ///
		ylabel(, format(%4.2f) angle(0)) ///
		yline(0, lpattern(dash) lcolor(gs8)) ///
		title("Per-scandal effect on `ytitle'", size(medium)) ///
		note("Narrow +-`window_length'-day window; outliers shown.") ///
		scheme(s2color) graphregion(color(white))
	graph export ///
		"${figout}/per_scandal_box_`outcome'_w`window_length'_apex_w_outliers.pdf", replace
}

display in green "per_scandal_effects_apex_w_outliers.do finished OK"
