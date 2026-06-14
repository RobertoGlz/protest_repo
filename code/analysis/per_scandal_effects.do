/* ----------------------------------------------------------------------------
						Violent effects of apex corruption

	Code author: Roberto Gonzalez
	Date: April 29, 2026  (rewritten 2026-05-15 to match the actual
		protests_scandals_30days_v3_with_lv_of_agent_involved.dta schema)

	Objective (protests_plan.md, Task 5):
		For each scandal, run the within-window pre/post regression on its
		own country and extract a single `Post Scandal` coefficient.
		Plot the distribution of those per-scandal coefficients by the type
		of official involved (1 President, 2 Supreme Court Judge/Secretary,
		3 Others).

	Design (per the plan):
		- Per scandal s: reghdfe outcome post, absorb(month dow) on the
		  narrow +-30-day window of that scandal's country.  Fewer obs but
		  tighter identification than +-120.
		- Save (scandal_id, official_involved, b_s, se_s, n_s).
		- Plot: jittered scatter of b_s by official type, overlaid with the
		  category mean and its 95% CI (more honest than graph box because
		  it shows the small-N categories).  Marker size ~ 1/se_s^2 so the
		  eye does not confuse a noisy b_s with a sharp one.  A companion
		  box plot is also produced.

	Caveat: with one country and a +-30-day window each per-scandal
	regression has very limited leverage; individual b_s are noisy by
	construction.  The object of interest is the *distribution*, not any
	single estimate.
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

global work "${identity}/Corrupcion/Protest_Work"

/* Creating Global File Paths ---------------------------------------------- */
global path 	"${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin 	"${path}/Data/final"
global output 	"${path}/Output"
global graphs 	"${output}/Graphs"
global tables 	"${output}/Tables"
global figout	"${work}/results/figures"
global resout	"${work}/results"
/* ------------------------------------------------------------------------- */

/* Narrow window per the plan */
local window_length = 30

/* Outcomes (mirrors the 4-outcome panels in Protests.pdf) */
local outcome_list = "num_protests_MM num_violent_MM num_peaceful_MM government_response_violent"
local outcome_number : word count `outcome_list'

/* CI level for the category-mean overlay and the exported per-scandal CIs */
local ci_level = 95
local zcrit = invnormal(1 - (100-`ci_level')/200)

/* ============================================================
   READ AND PREPARE
   ============================================================ */

use "${datfin}/protests_scandals_30days_v3_with_lv_of_agent_involved.dta", clear
drop if country == "Venezuela"

/* Merge in scandals_classified.csv to get the position + political_affiliation
   labels used by ppmlhdfe_main_by_position.do and by the PDF's Tables 12-15
   incumbent / non-incumbent panels.  172/176 scandals match; the 4 unmatched
   fall through to the "Others" category below. */
preserve
	import delimited using "${datfin}/scandals_classified.csv", ///
		clear varnames(1) bindquotes(strict)
	keep id country position political_affiliation
	tempfile cls
	save `cls'
restore
merge m:1 id country using `cls', keep(1 3) nogenerate

/* Refined 5-way categorisation that matches the PDF heterogeneity panels:
     1 Incumbent President     (position=="president"  & incumbent)
     2 Non-Incumbent President (position=="president"  & !incumbent)
     3 Incumbent Governor      (position=="governor"   & incumbent)
     4 SCJ / Congressman       (position in sc_judge_congressman, other_judiciary)
     5 Others                  (everything else, incl. unmatched and non-incumbent
                                governors)
*/
gen byte official_class = .
replace official_class = 1 if position == "president" & political_affiliation == "incumbent"
replace official_class = 2 if position == "president" & political_affiliation != "incumbent" ///
	& !missing(political_affiliation)
replace official_class = 3 if position == "governor"  & political_affiliation == "incumbent"
replace official_class = 4 if inlist(position, "sc_judge_congressman", "other_judiciary")
replace official_class = 5 if missing(official_class)

label define OCLASS ///
	1 "Inc. President" ///
	2 "Non-Inc. President" ///
	3 "Inc. Governor" ///
	4 "SCJ/Congressman" ///
	5 "Others", replace
label values official_class OCLASS

/* event-time variable in this dataset is `window`; restrict to +-30 days */
keep if abs(window) <= `window_length'

/* Numeric per-scandal id (id is the str scandal identifier; one scandal
   belongs to exactly one country, so id alone identifies a scandal-country) */
egen scandal_enc = group(id)
egen scandal_tag = tag(id)

/* Scandal date = calendar date at window == 0 (carried to every row) */
gen double _sd = date if window == 0
bysort scandal_enc (_sd): replace _sd = _sd[1]
format _sd %td

/* Defensive: drop scandals with no within-window post variation
   (diagnostics showed 0 such scandals, but keep the guard) */
bysort scandal_enc: egen _pm = mean(post)
drop if _pm == 0 | _pm == 1
drop _pm

/* month and dow already exist in the data (month = month(date),
   day = dow(date), 0 = Sunday); use them directly as FE */

quietly levelsof scandal_enc, local(slevels)
local n_scandals : word count `slevels'
display in yellow "Per-scandal regressions: `n_scandals' scandals x `outcome_number' outcomes"

/* One-row-per-scandal metadata to merge back after the matrix is filled */
preserve
	keep if scandal_tag == 1
	keep scandal_enc id country official_involved official_class ///
		position political_affiliation _sd
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

/* Convert matrix to dataset and merge metadata back in */
clear
svmat scandal_info
generate scandal_enc = _n
merge 1:1 scandal_enc using `metadata', nogenerate

/* Name the columns: b_/se_/n_ per outcome */
local oc = 0
foreach outcome of local outcome_list {
	local ++oc
	rename scandal_info`=3*`oc'-2' b_`outcome'
	rename scandal_info`=3*`oc'-1' se_`outcome'
	rename scandal_info`=3*`oc''   n_`outcome'
	/* per-scandal CI */
	generate lb_`outcome' = b_`outcome' - `zcrit'*se_`outcome'
	generate ub_`outcome' = b_`outcome' + `zcrit'*se_`outcome'
}

label define OFF 1 "President" 2 "SCJ/Secretary" 3 "Others", replace
label values official_involved OFF
label define OCLASS ///
	1 "Inc. President" ///
	2 "Non-Inc. President" ///
	3 "Inc. Governor" ///
	4 "SCJ/Congressman" ///
	5 "Others", replace
label values official_class OCLASS

order scandal_enc id country official_involved official_class ///
	position political_affiliation scandal_date b_* se_* n_* lb_* ub_*
compress

/* ============================================================
   EXPORT THE PER-SCANDAL ESTIMATES
   ============================================================ */
save   "${resout}/per_scandal_effects_w`window_length'.dta", replace
export delimited using ///
	"${resout}/per_scandal_effects_w`window_length'.csv", replace

/* ============================================================
   DISTRIBUTION SUMMARY  (printed to the log)
   Both categorisations: the broad 3-way (official_involved) for back-compat
   with the previous run, and the 5-way (official_class) that splits
   President by incumbency and identifies Incumbent Governors.
   ============================================================ */
foreach grouping in official_involved official_class {
	foreach outcome of local outcome_list {
		display in yellow "=== `grouping': `outcome' ==="
		tabstat b_`outcome', by(`grouping') ///
			statistics(n mean p50 sd min max) columns(statistics)
		mean b_`outcome', over(`grouping')
	}
}

/* ============================================================
   PLOTS BY TYPE OF OFFICIAL INVOLVED
   Generates the jitter + box pair under both groupings (3-way and 5-way),
   filename-suffixed with `_3cat` or `_5cat`.  The 5-way version is the
   point of this revision (splits President by incumbency, isolates
   Incumbent Governors -- mirrors the PDF's Tables 12/14 panels).
   ============================================================ */
foreach grouping in official_involved official_class {

	if "`grouping'" == "official_involved" {
		local suffix    = "3cat"
		local xlab      = `"1 "President" 2 "SCJ/Sec." 3 "Others""'
		local xmax      = 3
	}
	else {
		local suffix    = "5cat"
		local xlab      = `"1 "Inc. Pres" 2 "Non-Inc. Pres" 3 "Inc. Gov" 4 "SCJ/Cong" 5 "Others""'
		local xmax      = 5
	}

	foreach outcome of local outcome_list {

		if "`outcome'" == "num_protests_MM"             local ytitle "protests (any)"
		if "`outcome'" == "num_violent_MM"              local ytitle "violent protests"
		if "`outcome'" == "num_peaceful_MM"             local ytitle "peaceful protests"
		if "`outcome'" == "government_response_violent" local ytitle "gvt. violent response"

		/* ---- (a) jittered scatter with category mean + 95% CI overlay ---- */
		preserve
			keep if !missing(b_`outcome')
			generate double prec = 1 / se_`outcome'^2
			quietly summarize prec
			replace prec = prec / r(max)          /* normalize to (0,1] */

			quietly levelsof `grouping', local(cats)
			gen double cmean = .
			gen double clo   = .
			gen double chi   = .
			foreach c of local cats {
				quietly count if `grouping' == `c'
				if r(N) >= 2 {
					quietly mean b_`outcome' if `grouping' == `c'
					matrix mb = r(table)
					quietly replace cmean = mb[1,1] if `grouping' == `c'
					quietly replace clo   = mb[5,1] if `grouping' == `c'
					quietly replace chi   = mb[6,1] if `grouping' == `c'
				}
			}

			twoway ///
				(scatter b_`outcome' `grouping' [aw=prec], ///
					jitter(8) mcolor(navy%35) msymbol(O)) ///
				(rcap clo chi `grouping', lcolor(black) lwidth(medthick)) ///
				(scatter cmean `grouping', mcolor(black) msymbol(D) msize(medlarge)), ///
				yline(0, lpattern(dash) lcolor(gs8)) ///
				ytitle("Per-scandal effect on `ytitle'") ///
				xtitle("Type of official involved") ///
				xlabel(`xlab', noticks labsize(small)) ///
				xscale(range(0.5 `=`xmax'+0.5')) ///
				ylabel(, format(%4.2f) angle(0)) ///
				legend(order(3 "Category mean" 2 "95% CI" 1 "Per-scandal b") ///
					pos(1) ring(0) region(lcolor(gs10)) size(small) cols(1)) ///
				note("Each point is one scandal; marker size proportional to 1/SE^2." ///
					"Narrow +-`window_length'-day window.") ///
				scheme(s2color) graphregion(color(white))
			graph export ///
				"${figout}/per_scandal_jitter_`outcome'_w`window_length'_`suffix'.pdf", ///
				replace
		restore

		/* ---- (b) companion box plot ---- */
		graph box b_`outcome', over(`grouping', label(labsize(small))) ///
			nooutsides ///
			ytitle("Per-scandal effect on `ytitle'") ///
			ylabel(, format(%4.2f) angle(0)) ///
			yline(0, lpattern(dash) lcolor(gs8)) ///
			title("Per-scandal effect on `ytitle'", size(medium)) ///
			note("Narrow +-`window_length'-day window; outliers hidden.") ///
			scheme(s2color) graphregion(color(white))
		graph export ///
			"${figout}/per_scandal_box_`outcome'_w`window_length'_`suffix'.pdf", ///
			replace
	}
}

display in green "per_scandal_effects.do finished OK"
