/* ----------------------------------------------------------------------------
                        Violent effects of apex corruption
        Per-scandal box / jitter plots under the v2 apex partition,
        ZERO-IMPUTED variant.

    Code author: Roberto Gonzalez
    Date: 2026-06-28

    Difference from per_scandal_effects_apex_v2.do:
        Scandals whose outcome has zero within-window variation (so that
        reghdfe cannot produce a coefficient) are entered into the box
        plot at b_s = 0 rather than being silently dropped. The rationale
        is that, when the country recorded zero protests of the relevant
        type throughout the +-30-day window, the implicit per-scandal
        effect of the scandal on that outcome IS zero -- the scandal did
        not move a margin that was at zero to begin with. Dropping these
        scandals from the box plot biases the visible distribution toward
        nonzero (and typically positive) effects, since the "no movement"
        observations are excluded.

    Apex categories (unchanged from v2):
        1. President
        2. Other Apex  = Governors + SC Judges (the 5 IDs:
                          202, NEW26, NEW30, 332, NEW23)
        3. Other Non-Apex = Other judiciary + Others + Congressmen

    Outputs (under ${work}/results/figures/):
        per_scandal_box_<outcome>_w30_apex_v2_zero.pdf
        per_scandal_jitter_<outcome>_w30_apex_v2_zero.pdf
    Output (under ${work}/results/):
        per_scandal_effects_w30_apex_v2_zero.dta
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
global resout "${work}/results"
global figout "${work}/results/figures"

local window_length = 30
local outcome_list = "num_protests_MM num_violent_MM num_peaceful_MM government_response_violent"
local outcome_number : word count `outcome_list'
local ci_level = 95
local zcrit = invnormal(1 - (100-`ci_level')/200)

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
display in yellow "Per-scandal regressions: `n_scandals' scandals x `outcome_number' outcomes (ZERO-IMPUTED)"

preserve
	keep if scandal_tag == 1
	keep scandal_enc id country official_involved _sd
	rename _sd scandal_date
	tempfile metadata
	save `metadata'
restore

/* ============================================================
   PER-SCANDAL REGRESSIONS (zero-imputed)
   ============================================================ */
matrix define scandal_info = J(`n_scandals', 3*`outcome_number', .)
matrix define zero_flag    = J(`n_scandals',   `outcome_number', 0)

forvalues s = 1/`n_scandals' {
	local oc = 0
	foreach outcome of local outcome_list {
		local ++oc
		quietly summarize `outcome' if scandal_enc == `s'
		local n_obs  = r(N)
		local sd_out = cond(r(N) > 1, r(sd), .)
		if `n_obs' > 30 {
			if `sd_out' == 0 & !missing(`sd_out') {
				/* Outcome has zero within-window variation:
				   record b = 0 and leave SE missing. */
				matrix scandal_info[`s', 3*`oc'-2] = 0
				matrix scandal_info[`s', 3*`oc'-1] = .
				matrix scandal_info[`s', 3*`oc']   = `n_obs'
				matrix zero_flag[`s', `oc']        = 1
			}
			else {
				capture reghdfe `outcome' post if scandal_enc == `s', ///
					absorb(month day) vce(robust)
				if _rc == 0 & !missing(_b[post]) & _se[post] < . & _se[post] > 0 {
					matrix scandal_info[`s', 3*`oc'-2] = _b[post]
					matrix scandal_info[`s', 3*`oc'-1] = _se[post]
					matrix scandal_info[`s', 3*`oc']   = `n_obs'
				}
			}
		}
	}
}

clear
svmat scandal_info
svmat zero_flag, names(zflag)
generate scandal_enc = _n
merge 1:1 scandal_enc using `metadata', nogenerate

local oc = 0
foreach outcome of local outcome_list {
	local ++oc
	rename scandal_info`=3*`oc'-2' b_`outcome'
	rename scandal_info`=3*`oc'-1' se_`outcome'
	rename scandal_info`=3*`oc''   n_`outcome'
	rename zflag`oc' zero_`outcome'
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
   v2 PARTITION (SC Judges + Governors in Apex; Congressmen in Non-Apex)
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

order scandal_enc id country official_involved position political_affiliation ///
	apex_cat scandal_date b_* se_* n_* zero_*
compress
save "${resout}/per_scandal_effects_w`window_length'_apex_v2_zero.dta", replace

display in result "=== Apex partition v2 (zero-imputed) ==="
tab apex_cat, missing

display _newline "=== Zero-imputed counts per outcome ==="
foreach outcome of local outcome_list {
	quietly count if zero_`outcome' == 1
	display "    `outcome': " r(N) " zero-imputed"
}

/* ============================================================
   PLOTS: BOX AND JITTER (zero-imputed)
   ============================================================ */
foreach outcome of local outcome_list {

	if "`outcome'" == "num_protests_MM"             local ytitle "protests (any)"
	if "`outcome'" == "num_violent_MM"              local ytitle "violent protests"
	if "`outcome'" == "num_peaceful_MM"             local ytitle "peaceful protests"
	if "`outcome'" == "government_response_violent" local ytitle "gvt. violent response"

	display in yellow "=== Per-scandal `outcome': by apex_cat (v2, zero-imputed) ==="
	tabstat b_`outcome', by(apex_cat) ///
		statistics(n mean p50 sd min max) columns(statistics)

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
		"${figout}/per_scandal_box_`outcome'_w`window_length'_apex_v2_zero.pdf", replace

	/* Jittered scatter: still uses inverse-variance weighting, so the
	   zero-imputed points (SE missing) are EXCLUDED from the jitter to
	   avoid divide-by-missing. */
	preserve
		keep if !missing(b_`outcome') & !missing(apex_cat) & !missing(se_`outcome')
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
				"Narrow +-`window_length'-day window; zero-variation scandals excluded from jitter.") ///
			scheme(s2color) graphregion(color(white))
		graph export ///
			"${figout}/per_scandal_jitter_`outcome'_w`window_length'_apex_v2_zero.pdf", replace
	restore
}

display in green "per_scandal_effects_apex_v2_zero.do finished OK"
