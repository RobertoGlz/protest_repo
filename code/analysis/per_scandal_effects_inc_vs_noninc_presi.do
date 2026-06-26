/* ----------------------------------------------------------------------------
						Violent effects of apex corruption
		Appendix figure: Incumbent vs Non-Incumbent Presidents only.

	Code author: Roberto Gonzalez
	Date: 2026-05-29

	Objective:
		Per-scandal effect-size box / jitter plots restricted to the
		President subsample (`position == "president"` in
		scandals_classified.csv), split by `political_affiliation`:
			incumbent       (n ~ 27)
			non-incumbent   (opposition; n ~ 21)
		"different_constituency" is empty for Presidents (a President
		is always either incumbent or opposition).

	Method:
		For each scandal s, inside its narrow +-30-day country window,
			reghdfe outcome post, absorb(month day) vce(robust)
		and store the Post coefficient. Then plot the distribution of
		those per-scandal coefficients by incumbent vs non-incumbent.

	Outputs (in ${work}/results/figures/):
		per_scandal_box_<outcome>_w30_incpres.pdf
		per_scandal_jitter_<outcome>_w30_incpres.pdf
		per_scandal_effects_w30_incpres.dta
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
   MERGE position + political_affiliation FROM scandals_classified.csv
   ============================================================ */
preserve
	import delimited using "${datfin}/scandals_classified.csv", ///
		clear varnames(1) bindquotes(strict)
	keep id country position political_affiliation
	tempfile cls
	save `cls'
restore
merge 1:1 id country using `cls', keep(1 3) nogenerate

/* ============================================================
   PRESIDENT-ONLY SUBSAMPLE,  Incumbent  vs  Non-incumbent
   ============================================================ */
keep if position == "president"

gen byte incpres = .
replace incpres = 1 if political_affiliation == "incumbent"
replace incpres = 2 if inlist(political_affiliation, "opposition", "different_constituency")
label define INCPRES 1 "Incumbent Pres." 2 "Non-Incumbent Pres.", replace
label values incpres INCPRES
label variable incpres "President: incumbent vs non-incumbent"

order scandal_enc id country official_involved position political_affiliation ///
	incpres scandal_date b_* se_* n_*
compress
save "${resout}/per_scandal_effects_w`window_length'_incpres.dta", replace

di as result "=== Presidents: Incumbent vs Non-incumbent (one row per scandal) ==="
tab incpres political_affiliation, missing

/* ============================================================
   PLOTS: BOX (no outliers) AND JITTER
   ============================================================ */
foreach outcome of local outcome_list {

	if "`outcome'" == "num_protests_MM"             local ytitle "protests (any)"
	if "`outcome'" == "num_violent_MM"              local ytitle "violent protests"
	if "`outcome'" == "num_peaceful_MM"             local ytitle "peaceful protests"
	if "`outcome'" == "government_response_violent" local ytitle "gvt. violent response"

	display in yellow "=== Per-scandal `outcome': Incumbent vs Non-incumbent Presidents ==="
	tabstat b_`outcome', by(incpres) ///
		statistics(n mean p50 sd min max) columns(statistics)
	mean b_`outcome', over(incpres)

	/* ---- (a) box plot ---- */
	/* Build per-category median note for this outcome.
	   Each category becomes its own quoted string so graph box renders
	   one median per row in the figure note. */
	quietly levelsof incpres, local(__cats)
	local med_note `""'
	foreach c of local __cats {
		quietly summarize b_`outcome' if incpres == `c', detail
		local __mstr = string(r(p50), "%5.3f")
		local __lbl : label INCPRES `c'
		local med_note `"`med_note' "Median `__lbl': `__mstr'""'
	}

	graph box b_`outcome', over(incpres, label(labsize(large))) ///
		nooutsides ///
		ytitle("Per-scandal effect on `ytitle'", size(medlarge)) ///
		ylabel(, format(%4.2f) angle(0) labsize(large)) ///
		yline(0, lpattern(dash) lcolor(gs8)) ///
		note(`med_note', size(medlarge)) ///
		medtype(line) ///
		box(1, lcolor(black) lwidth(thick)) ///
		box(2, lcolor(black) lwidth(thick)) ///
		scheme(s2color) graphregion(color(white))
	graph export ///
		"${figout}/per_scandal_box_`outcome'_w`window_length'_incpres.pdf", replace

	/* ---- (b) jittered scatter with category mean + 95% CI ---- */
	preserve
		keep if !missing(b_`outcome') & !missing(incpres)
		generate double prec = 1 / se_`outcome'^2
		quietly summarize prec
		replace prec = prec / r(max)

		quietly levelsof incpres, local(cats)
		gen double cmean = .
		gen double clo   = .
		gen double chi   = .
		foreach c of local cats {
			quietly count if incpres == `c'
			if r(N) >= 2 {
				quietly mean b_`outcome' if incpres == `c'
				matrix mb = r(table)
				quietly replace cmean = mb[1,1] if incpres == `c'
				quietly replace clo   = mb[5,1] if incpres == `c'
				quietly replace chi   = mb[6,1] if incpres == `c'
			}
		}

		twoway ///
			(scatter b_`outcome' incpres [aw=prec], ///
				jitter(8) mcolor(navy%35) msymbol(O)) ///
			(rcap clo chi incpres, lcolor(black) lwidth(medthick)) ///
			(scatter cmean incpres, mcolor(black) msymbol(D) msize(medlarge)), ///
			yline(0, lpattern(dash) lcolor(gs8)) ///
			ytitle("Per-scandal effect on `ytitle'") ///
			xtitle("Political affiliation of the President") ///
			xlabel(1 "Incumbent" 2 "Non-incumbent", noticks) ///
			xscale(range(0.5 2.5)) ///
			ylabel(, format(%4.2f) angle(0)) ///
			legend(order(3 "Category mean" 2 "95% CI" 1 "Per-scandal b") ///
				pos(1) ring(0) region(lcolor(gs10)) size(small) cols(1)) ///
			note("Each point is one scandal; marker size proportional to 1/SE^2." ///
				"Narrow +-`window_length'-day window; Presidents only.") ///
			scheme(s2color) graphregion(color(white))
		graph export ///
			"${figout}/per_scandal_jitter_`outcome'_w`window_length'_incpres.pdf", replace
	restore
}

display in green "per_scandal_effects_inc_vs_noninc_presi.do finished OK"
