/* ----------------------------------------------------------------------------
					Violent effects of apex corruption

	Code author: Roberto Gonzalez
	Date: 2026-05-20

	Objective (protests_plan.md, Task 4):
		Sample-split the headline OLS / Poisson C x Y FE specifications by
		whether the scandal date falls on a weekend (Sat/Sun) or a weekday
		(Mon-Fri).  Two motivations:
		  (a) Weekend baselines are mechanically lower (less protest
		      activity on weekend days), so a post-scandal jump can look
		      bigger.  The heterogeneity check disciplines this.
		  (b) Weekend scandals may be more "exogenously timed" relative to
		      the news cycle (less strategic timing by political actors).

	Audit note:
		The plan asked to add i.dow to the main specs, but inspection of
		ols_main.do and poisson_reg_main_countryxyear_fe.do shows day-of-week
		IS already in the spec (absorb(month day ...) in OLS;
		`i.month i.day` in Poisson).  The plan's note was stale.  So this
		task focuses on the heterogeneity split only.

	Spec mirrored exactly from the headline scripts:
		OLS:  reghdfe outcome post, absorb(month day country#year)
		         cluster(group_cluster)
		Poi:  poisson outcome post i.month i.day i.country_id#i.year,
		         vce(cluster group_cluster) irr
		group_cluster = group(country_id year bin30), where bin30 is the
		30-day window bin (matches PDF's "C x Y x DB" clustering).

	Outputs:
		- Tex tables (OLS + Poisson, wide +-120 + narrow +-30):
		    ${work}/results/tables/wkd_vs_wkend_<estimator>_w<W>d.tex
		- Console log: panelled coefficient tables to read into the
		  markdown results note.
---------------------------------------------------------------------------- */

/* ------------------- Configuration for collaborators -------------------- */
if "`c(username)'" == "lalov" {
	gl identity "C:\Users\lalov\ITAM Seira Research Dropbox\Eduardo Rivera"
}
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox"
}
if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}

global work "${identity}/Corrupcion/Protest_Work"
global path "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"
global tabout "${work}/results/tables"

/* All 4 outcomes from the PDF main tables */
global outcome_list "num_protests_MM num_violent_MM num_peaceful_MM government_response_violent"

local firstyear = 2008

/* Loop over the two windows used in the PDF: wide (Table 1 et al.) and
   narrow (Section 8, Tables 16-17) */
foreach numbdays in 120 30 {

	display in yellow as result "================================================"
	display in yellow as result " WINDOW = +-`numbdays' days"
	display in yellow as result "================================================"

	use "${datfin}/protests_scandals_30days_v3", clear
	drop if country == "Venezuela"
	keep if abs(window) <= `numbdays'
	keep if year >= `firstyear'

	/* Scandal date's day-of-week, then weekend flag */
	gen byte _sdow = day if window == 0
	bysort id (_sdow): replace _sdow = _sdow[1]
	label var _sdow "Day-of-week of the scandal date (0=Sun..6=Sat)"
	gen byte weekend_scandal = (inlist(_sdow, 0, 6))
	label var weekend_scandal "Scandal date is Sat/Sun"
	label define WKE 0 "Weekday scandal (Mon-Fri)" 1 "Weekend scandal (Sat/Sun)", replace
	label values weekend_scandal WKE

	/* Tab the scandal-level distribution */
	preserve
		bysort id: keep if _n == 1
		display in yellow "=== one row per scandal: dow of scandal ==="
		tab _sdow, missing
		display in yellow "=== one row per scandal: weekday vs weekend ==="
		tab weekend_scandal, missing
	restore

	/* 30-day window bin for clustering (matches C x Y x DB convention) */
	gen long bin30 = floor(window/30)
	egen group_cluster = group(country_id year bin30)

	/* Estimate both estimators x {Full, Weekend, Weekday} x 4 outcomes */
	estimates clear
	local oc = 0
	foreach outcome in $outcome_list {
		local ++oc

		/* ---- OLS ---- */
		eststo ols_full_`oc' : reghdfe `outcome' post, ///
			absorb(month day i.country_id#i.year) ///
			cluster(group_cluster)
		eststo ols_wend_`oc' : reghdfe `outcome' post if weekend_scandal == 1, ///
			absorb(month day i.country_id#i.year) ///
			cluster(group_cluster)
		eststo ols_wday_`oc' : reghdfe `outcome' post if weekend_scandal == 0, ///
			absorb(month day i.country_id#i.year) ///
			cluster(group_cluster)

		/* ---- Poisson (IRR) ---- */
		capture eststo poi_full_`oc' : poisson `outcome' post i.month i.day i.country_id#i.year, ///
			vce(cluster group_cluster) irr
		capture eststo poi_wend_`oc' : poisson `outcome' post i.month i.day i.country_id#i.year ///
			if weekend_scandal == 1, vce(cluster group_cluster) irr
		capture eststo poi_wday_`oc' : poisson `outcome' post i.month i.day i.country_id#i.year ///
			if weekend_scandal == 0, vce(cluster group_cluster) irr
	}

	/* ------------------ Export LaTeX tables ------------------ */
	/* Build the model list per panel from successfully-stored estimates
	   (some cells -- gvt response on the 25-scandal weekend subsample --
	   may fail to converge; capture eststo absorbs the error but esttab
	   then errors if you reference a missing estimate name).
	   esttab is invoked only over the existing models, with mtitles
	   matched to that subset. */
	/* Note: ~ instead of a literal space inside the Gvt. Violent title --
	   esttab's mtitles() option tokenises by whitespace, so a space inside
	   one mtitle splits it into two, leaving "Gvt." in the header and the
	   remainder leaking into the next column.  Using LaTeX's `~` keeps
	   esttab from breaking the title and LaTeX renders it as a space. */
	local mt_protests  `"\shortstack{Protests}"'
	local mt_violent   `"\shortstack{Violent\\Protests}"'
	local mt_peaceful  `"\shortstack{Non-violent\\Protests}"'
	local mt_gvr       `"\shortstack{Gvt.~Violent\\Response}"'

	foreach est in ols poi {
		foreach sam in full wend wday {
			local mlist
			local mttls
			foreach oc of numlist 1/4 {
				capture estimates restore `est'_`sam'_`oc'
				if _rc == 0 {
					local mlist `mlist' `est'_`sam'_`oc'
					if `oc' == 1 local mttls `mttls' `mt_protests'
					if `oc' == 2 local mttls `mttls' `mt_violent'
					if `oc' == 3 local mttls `mttls' `mt_peaceful'
					if `oc' == 4 local mttls `mttls' `mt_gvr'
				}
				else display in red "skip: `est'_`sam'_`oc' (no estimate)"
			}
			if "`mlist'" == "" {
				display in red "no estimates for `est' / `sam' / w`numbdays'd"
				continue
			}
			if "`est'" == "ols" {
				esttab `mlist' ///
					using "${tabout}/wkd_vs_wkend_`est'_w`numbdays'd_`sam'.tex", ///
					replace b(3) se(3) booktabs star(* 0.1 ** 0.05 *** 0.01) ///
					stats(N r2, labels("Observations" "R-squared") fmt(0 3)) ///
					keep(post) varlabels(post "Post Scandal") nonotes nonumber ///
					mtitles(`mttls')
			}
			else {
				esttab `mlist' ///
					using "${tabout}/wkd_vs_wkend_`est'_w`numbdays'd_`sam'.tex", ///
					replace b(3) se(3) booktabs star(* 0.1 ** 0.05 *** 0.01) eform ///
					stats(N, labels("Observations") fmt(0)) ///
					keep(post) varlabels(post "Post Scandal (IRR)") nonotes nonumber ///
					mtitles(`mttls')
			}
		}
	}

	/* ------------------ Print to log for the markdown note ------------------ */
	display in yellow as result "=== OLS coefficients on Post (w`numbdays'd) ==="
	display in yellow "outcome  | sample   | b          | se         | N"
	foreach oc of numlist 1/4 {
		local outcome : word `oc' of $outcome_list
		foreach sam in full wend wday {
			capture estimates restore ols_`sam'_`oc'
			if _rc == 0 {
				local b  = string(_b[post], "%9.4f")
				local se = string(_se[post], "%9.4f")
				local N  = string(e(N), "%9.0fc")
				display "`outcome'  `sam'  `b'  `se'  `N'"
			}
		}
	}

	display in yellow as result "=== Poisson IRR on Post (w`numbdays'd) ==="
	display in yellow "outcome  | sample   | b          | se         | IRR        | N"
	foreach oc of numlist 1/4 {
		local outcome : word `oc' of $outcome_list
		foreach sam in full wend wday {
			capture estimates restore poi_`sam'_`oc'
			if _rc == 0 {
				local b   = string(_b[post], "%9.4f")
				local se  = string(_se[post], "%9.4f")
				local irr = string(exp(_b[post]), "%9.4f")
				local N   = string(e(N), "%9.0fc")
				display "`outcome'  `sam'  `b'  `se'  `irr'  `N'"
			}
		}
	}
}

display in green "a_weekend_vs_weekday.do finished OK"
