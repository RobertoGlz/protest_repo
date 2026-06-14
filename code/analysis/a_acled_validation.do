/* ----------------------------------------------------------------------------
					Violent effects of apex corruption

	Code author: Roberto Gonzalez
	Date: 2026-05-21

	Objective (protests_plan.md, Task 3):

		(1) Agreement diagnostics on the country-day grid for the
		    2018-2020 MM x ACLED overlap (24 LAC + Canada, 821 days):
		      - regress MM_count on ACLED_count : slope and R^2
		      - 2x2 agreement on >0 indicators       (any, violent, peaceful)
		      - Spearman rank correlation on counts
		      - share where MM and ACLED agree / one source unique

		(2) Replicate the headline OLS Country x Year FE Table 1 spec but
		    with ACLED counts on the LHS, on the scandal event-window
		    sample restricted to dates >= 2018-01-01 (the ACLED coverage).

	Inputs:
		${work}/temp/MM_ACLED_panel_bydate.dta  -- from b_merge_acled_mm.do
		${datfin}/protests_scandals_30days_v3   -- scandal event-window panel

	Outputs:
		${work}/results/tables/acled_validation_agreement.tex  (slope/R^2 by outcome)
		${work}/results/tables/acled_validation_2x2.tex        (>0 indicator agreement)
		${work}/results/tables/acled_table1_replication.tex    (PDF Table 1 with ACLED)
		Numbers printed to log for the markdown note.
---------------------------------------------------------------------------- */

if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}
global work   "${identity}/Corrupcion/Protest_Work"
global path   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"
global tabout "${work}/results/tables"

/* ============================================================
   PART 1: AGREEMENT ON THE COUNTRY-DAY GRID (2018-01..2020-03)
   ============================================================ */
use "${work}/temp/MM_ACLED_panel_bydate.dta", clear

di as result "=== Sample ==="
count
quietly levelsof country
di "Countries: " r(r)

di as result "=== Outcome means (already in build log; re-printed) ==="
summarize num_protests_MM num_violent_MM num_peaceful_MM ///
	num_protests_ACLED num_violent_ACLED num_peaceful_ACLED num_gvr_ACLED

/* --- (a) slope and R^2: MM count ~ ACLED count, by outcome --- */
estimates clear
di as result "=== Slope/R^2: MM = a + b * ACLED ==="
foreach pair in "num_protests_MM num_protests_ACLED" ///
		"num_violent_MM num_violent_ACLED" ///
		"num_peaceful_MM num_peaceful_ACLED" {
	tokenize `pair'
	local mm_var "`1'"
	local ac_var "`2'"
	eststo `mm_var' : regress `mm_var' `ac_var'
	local b  = string(_b[`ac_var'], "%9.5f")
	local se = string(_se[`ac_var'], "%9.5f")
	local r2 = string(e(r2), "%5.3f")
	local r2a = string(e(r2_a), "%5.3f")
	display ///
		"`mm_var' ~ `ac_var':  slope = `b' (se `se')   R2 = `r2'  R2_adj = `r2a'"
}

esttab num_protests_MM num_violent_MM num_peaceful_MM ///
	using "${tabout}/acled_validation_agreement.tex", replace ///
	b(4) se(4) booktabs star(* 0.1 ** 0.05 *** 0.01) ///
	stats(N r2 r2_a, labels("Observations" "R-squared" "Adj R-squared") fmt(0 3 3)) ///
	mtitles("MM Protests" "MM Violent" "MM Peaceful") ///
	varlabels(num_protests_ACLED "ACLED protests count" ///
		num_violent_ACLED "ACLED violent count" ///
		num_peaceful_ACLED "ACLED peaceful count") ///
	keep(num_protests_ACLED num_violent_ACLED num_peaceful_ACLED _cons) ///
	nonotes nonumber

/* --- (b) Spearman rank correlation --- */
di as result "=== Spearman rho on counts ==="
spearman num_protests_MM num_protests_ACLED, stats(rho p)
spearman num_violent_MM num_violent_ACLED, stats(rho p)
spearman num_peaceful_MM num_peaceful_ACLED, stats(rho p)

/* --- (c) 2x2 agreement on >0 indicators --- */
di as result "=== 2x2 agreement: MM>0 vs ACLED>0 ==="
foreach pair in "protest_MM protest_ACLED" ///
		"violent_MM violent_ACLED" ///
		"peaceful_MM peaceful_ACLED" {
	tokenize `pair'
	local mm_var "`1'"
	local ac_var "`2'"
	display in yellow "--- `mm_var' x `ac_var' ---"
	tab `mm_var' `ac_var'
	/* Cohen's kappa */
	kap `mm_var' `ac_var'
}

/* Build a small dataset of 2x2 counts + kappa for an exported summary */
preserve
	tempfile twoxtwo
	clear
	set obs 0
	gen str20 outcome = ""
	gen long n_neither = .
	gen long n_mm_only = .
	gen long n_ac_only = .
	gen long n_both    = .
	gen double kappa   = .
	save `twoxtwo', emptyok
restore

foreach pair in "protest_MM protest_ACLED protest" ///
		"violent_MM violent_ACLED violent" ///
		"peaceful_MM peaceful_ACLED peaceful" {
	tokenize `pair'
	local mm_var "`1'"
	local ac_var "`2'"
	local out    "`3'"
	quietly count if `mm_var' == 0 & `ac_var' == 0
	local n00 = r(N)
	quietly count if `mm_var' == 1 & `ac_var' == 0
	local n10 = r(N)
	quietly count if `mm_var' == 0 & `ac_var' == 1
	local n01 = r(N)
	quietly count if `mm_var' == 1 & `ac_var' == 1
	local n11 = r(N)
	quietly kap `mm_var' `ac_var'
	local k = r(kappa)
	preserve
		use `twoxtwo', clear
		insobs 1
		replace outcome    = "`out'" in L
		replace n_neither  = `n00' in L
		replace n_mm_only  = `n10' in L
		replace n_ac_only  = `n01' in L
		replace n_both     = `n11' in L
		replace kappa      = `k'   in L
		save `twoxtwo', replace
	restore
}
use `twoxtwo', clear
list, sep(0)
export delimited "${tabout}/acled_validation_2x2.csv", replace

/* ============================================================
   PART 2: TABLE 1 REPLICATION WITH ACLED ON LHS
   ============================================================ */
use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"

/* Restrict to scandal-window rows that fall within ACLED coverage */
keep if date >= mdy(1,1,2018)

/* Merge in ACLED counts */
merge m:1 country date using "${work}/temp/ACLED/ACLEDclean_bydate.dta", keep(1 3) nogen
foreach v in num_protests_ACLED num_violent_ACLED num_peaceful_ACLED num_gvr_ACLED ///
		protest_ACLED violent_ACLED peaceful_ACLED gvr_ACLED {
	replace `v' = 0 if missing(`v')
}

/* Build the cluster as in the main spec (30-day window bin) */
gen long bin30 = floor(window/30)
egen group_cluster = group(country_id year bin30)

di as result "=== ACLED Table 1 replication: sample ==="
count
quietly levelsof id
di "Number of scandals contributing: " r(r)

estimates clear

/* (a) ACLED on LHS, 2018+ subsample */
local oc = 0
foreach outcome in num_protests_ACLED num_violent_ACLED num_peaceful_ACLED num_gvr_ACLED {
	local ++oc
	eststo acled_t1_`oc' : reghdfe `outcome' post, ///
		absorb(month day i.country_id#i.year) ///
		cluster(group_cluster)
}

/* (b) MM on LHS, SAME 2018+ subsample (apples-to-apples comparison).
   The scandals dataset already carries num_*_MM and government_response_violent;
   use them on exactly the rows ACLED is identified on. */
local oc = 0
foreach outcome in num_protests_MM num_violent_MM num_peaceful_MM government_response_violent {
	local ++oc
	eststo mm_t1same_`oc' : reghdfe `outcome' post, ///
		absorb(month day i.country_id#i.year) ///
		cluster(group_cluster)
}

/* Side-by-side table: MM (top half) vs ACLED (bottom half) on the same sample */
esttab mm_t1same_1 mm_t1same_2 mm_t1same_3 mm_t1same_4 ///
	using "${tabout}/acled_table1_mm_same_sample.tex", replace ///
	b(3) se(3) booktabs star(* 0.1 ** 0.05 *** 0.01) ///
	stats(N r2, labels("Observations" "R-squared") fmt(0 3)) ///
	keep(post) varlabels(post "Post Scandal") nonotes nonumber ///
	mtitles("\shortstack{Protests}" ///
		"\shortstack{Violent\\Protests}" ///
		"\shortstack{Non-violent\\Protests}" ///
		"\shortstack{Gvt.~Violent\\Response}")

esttab acled_t1_1 acled_t1_2 acled_t1_3 acled_t1_4 ///
	using "${tabout}/acled_table1_replication.tex", replace ///
	b(3) se(3) booktabs star(* 0.1 ** 0.05 *** 0.01) ///
	stats(N r2, labels("Observations" "R-squared") fmt(0 3)) ///
	keep(post) varlabels(post "Post Scandal") nonotes nonumber ///
	mtitles("\shortstack{Protests}" ///
		"\shortstack{Violent\\Protests}" ///
		"\shortstack{Non-violent\\Protests}" ///
		"\shortstack{Gvt.~Violent\\Response}")

di as result "=== Coefficients on Post: MM vs ACLED on the SAME 2018+ subsample ==="
display "                       MM coef     MM se         ACLED coef  ACLED se"
foreach oc of numlist 1/4 {
	estimates restore mm_t1same_`oc'
	local bm  = string(_b[post], "%9.4f")
	local sem = string(_se[post], "%9.4f")
	local Nm  = string(e(N), "%9.0fc")
	estimates restore acled_t1_`oc'
	local ba  = string(_b[post], "%9.4f")
	local sea = string(_se[post], "%9.4f")
	local Na  = string(e(N), "%9.0fc")
	display "outcome `oc' (N=`Nm'):   `bm'   `sem'    `ba'   `sea'"
}

display in green "a_acled_validation.do finished OK"
