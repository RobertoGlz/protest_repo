/* ----------------------------------------------------------------------------
                        Violent effects of apex corruption
        Per-scandal box / jitter plots under a REVISED three-way apex
        partition (v2).

    Code author: Roberto Gonzalez
    Date: 2026-06-27

    Difference from per_scandal_effects_apex.do:
        - Supreme Court Judges (the 4 IDs {202, NEW26, NEW30, 332})
          MOVE from Other Non-Apex to Other Apex.
        - Congressmen (the remaining `sc_judge_congressman` IDs)
          MOVE from Other Apex to Other Non-Apex.

    New categories:
        1. President               -> position == "president"
        2. Other Apex              -> position == "governor"
                                      OR (sc_judge_congressman AND id is
                                          one of the 4 SC-Judge IDs)
        3. Other Non-Apex          -> position == "other_judiciary"
                                      OR position == "others"
                                      OR (sc_judge_congressman AND id is
                                          NOT one of the 4 SC-Judge IDs,
                                          i.e., Congressmen)

    Diagnostic:
        We also list the scandals in our event-window panel that have no
        position assignment in scandals_classified.csv -- the "unclassified
        residual" the team has been asking about.

    Outputs (under ${work}/results/figures/):
        per_scandal_box_<outcome>_w30_apex_v2.pdf
        per_scandal_jitter_<outcome>_w30_apex_v2.pdf
        per_scandal_effects_w30_apex_v2.dta
    Output (under ${work}/results/):
        per_scandal_apex_v2_unclassified.csv
            One row per event-window scandal with no position in the CSV.
---------------------------------------------------------------------------- */

/* ------------------- Configuration for collaborators -------------------- */
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
global resout "${work}/results"
global figout "${work}/results/figures"

local window_length = 30
local outcome_list = "num_protests_MM num_violent_MM num_peaceful_MM government_response_violent"
local outcome_number : word count `outcome_list'
local ci_level = 95
local zcrit = invnormal(1 - (100-`ci_level')/200)

/* The IDs the team agreed are SC Justices inside the lumped
   `sc_judge_congressman` code.  NEW23 (Mexico) added on 2026-06-27
   when its row was added to scandals_classified.csv. */
local sc_judge_ids `""202" "NEW26" "NEW30" "332" "NEW23""'

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
   MERGE position FROM scandals_classified.csv
   ============================================================ */
preserve
	import delimited using "${datfin}/scandals_classified.csv", ///
		clear varnames(1) bindquotes(strict)
	keep id country position political_affiliation
	tempfile cls
	save `cls'
restore
merge 1:1 id country using `cls', keep(1 3) generate(_mclass)

/* ============================================================
   NEW THREE-WAY CLASSIFICATION (v2)
        1. President
        2. Other Apex   = Governors + SC Judges (the 4 IDs)
        3. Other Non-Apex = Other judiciary + Others + Congressmen
                            (the remaining sc_judge_congressman IDs)
   ============================================================ */
gen byte apex_cat = .
replace apex_cat = 1 if position == "president"
replace apex_cat = 2 if position == "governor"
replace apex_cat = 2 if position == "sc_judge_congressman" & ///
	inlist(id, "202", "NEW26", "NEW30", "332", "NEW23")
replace apex_cat = 3 if position == "sc_judge_congressman" & ///
	!inlist(id, "202", "NEW26", "NEW30", "332", "NEW23")
replace apex_cat = 3 if position == "other_judiciary"
replace apex_cat = 3 if position == "others"

label define APEX 1 "President" 2 "Other Apex" 3 "Other Non-Apex", replace
label values apex_cat APEX
label variable apex_cat "Apex partition (v2: SC Judges + Governors in Apex; Congressmen in Non-Apex)"

order scandal_enc id country official_involved position political_affiliation ///
	apex_cat scandal_date b_* se_* n_*
compress
save "${resout}/per_scandal_effects_w`window_length'_apex_v2.dta", replace

display in result "=== Apex partition v2 ==="
tab apex_cat, missing

/* ============================================================
   DIAGNOSTIC: which scandals have NO position in the CSV?
   ============================================================ */
preserve
	keep if missing(position)
	display in red "=== Unclassified scandals (no row in scandals_classified.csv) ==="
	count
	display in red "Total unclassified: " r(N)
	list scandal_enc id country official_involved scandal_date, ///
		string(30) sepby(country) noobs
	keep scandal_enc id country official_involved scandal_date
	export delimited using "${resout}/per_scandal_apex_v2_unclassified.csv", ///
		replace
restore

/* ============================================================
   PLOTS: BOX (no outliers) AND JITTER
        Note format follows the standard adopted on 2026-06-27:
           "Median <label> = <p50>     (Scandals = <count>)"
   ============================================================ */
foreach outcome of local outcome_list {

	if "`outcome'" == "num_protests_MM"             local ytitle "protests (any)"
	if "`outcome'" == "num_violent_MM"              local ytitle "violent protests"
	if "`outcome'" == "num_peaceful_MM"             local ytitle "peaceful protests"
	if "`outcome'" == "government_response_violent" local ytitle "gvt. violent response"

	display in yellow "=== Per-scandal `outcome': by apex_cat (v2) ==="
	tabstat b_`outcome', by(apex_cat) ///
		statistics(n mean p50 sd min max) columns(statistics)
	mean b_`outcome', over(apex_cat)

	/* Per-category note: one row per category */
	quietly levelsof apex_cat, local(__cats)
	local med_note `""'
	foreach c of local __cats {
		quietly summarize b_`outcome' if apex_cat == `c', detail
		local __mstr = string(r(p50), "%5.3f")
		quietly count if !missing(b_`outcome') & apex_cat == `c'
		local __nstr = r(N)
		local __lbl : label APEX `c'
		local med_note `"`med_note' "Median `__lbl' = `__mstr'     (Scandals = `__nstr')""'
	}

	/* ---- (a) box plot ---- */
	graph box b_`outcome', over(apex_cat, label(labsize(large))) ///
		nooutsides ///
		ytitle("Per-scandal effect on `ytitle'", size(medlarge)) ///
		ylabel(, format(%4.2f) angle(0) labsize(large)) ///
		yline(0, lpattern(dash) lcolor(gs8)) ///
		note(`med_note', size(medlarge)) ///
		medtype(line) ///
		box(1, lcolor(black) lwidth(thick)) ///
		box(2, lcolor(black) lwidth(thick)) ///
		box(3, lcolor(black) lwidth(thick)) ///
		scheme(s2color) graphregion(color(white))
	graph export ///
		"${figout}/per_scandal_box_`outcome'_w`window_length'_apex_v2.pdf", replace

	/* ---- (b) jittered scatter with category mean + 95% CI ---- */
	preserve
		keep if !missing(b_`outcome') & !missing(apex_cat)
		generate double prec = 1 / se_`outcome'^2
		quietly summarize prec
		replace prec = prec / r(max)

		quietly levelsof apex_cat, local(cats)
		gen double cmean = .
		gen double clo   = .
		gen double chi   = .
		foreach c of local cats {
			quietly count if apex_cat == `c'
			if r(N) >= 2 {
				quietly mean b_`outcome' if apex_cat == `c'
				matrix mb = r(table)
				quietly replace cmean = mb[1,1] if apex_cat == `c'
				quietly replace clo   = mb[5,1] if apex_cat == `c'
				quietly replace chi   = mb[6,1] if apex_cat == `c'
			}
		}

		twoway ///
			(scatter b_`outcome' apex_cat [aw=prec], ///
				jitter(8) mcolor(navy%35) msymbol(O)) ///
			(rcap clo chi apex_cat, lcolor(black) lwidth(medthick)) ///
			(scatter cmean apex_cat, mcolor(black) msymbol(D) msize(medlarge)), ///
			yline(0, lpattern(dash) lcolor(gs8)) ///
			ytitle("Per-scandal effect on `ytitle'") ///
			xtitle("Apex partition (v2)") ///
			xlabel(1 "President" 2 "Other Apex" 3 "Other Non-Apex", noticks) ///
			xscale(range(0.5 3.5)) ///
			ylabel(, format(%4.2f) angle(0)) ///
			legend(order(3 "Category mean" 2 "95% CI" 1 "Per-scandal b") ///
				pos(1) ring(0) region(lcolor(gs10)) size(small) cols(1)) ///
			note("Each point is one scandal; marker size proportional to 1/SE^2." ///
				"Narrow +-`window_length'-day window; classification v2.") ///
			scheme(s2color) graphregion(color(white))
		graph export ///
			"${figout}/per_scandal_jitter_`outcome'_w`window_length'_apex_v2.pdf", replace
	restore
}

display in green "per_scandal_effects_apex_v2.do finished OK"
