/* ----------------------------------------------------------------------------
					Violent effects of apex corruption

	Code author: Roberto Gonzalez
	Date: 2026-05-21

	Objective (protests_plan.md, Task 3):
		Build a balanced country-day panel for the MM vs ACLED agreement
		analysis.  Both sources are merged on (country, date); rows where
		one is missing have its counts set to 0.

	Coverage:
		ACLED: 2018-01-01 to 2025-05-21 (53 LAC + US/Canada countries)
		MM   : 1990-01-01 to 2020-03-31 (clean_full_bydate; 160 countries)
		Overlap: 2018-01-01 to 2020-03-31, ~53 countries.

	Output:
		${work}/temp/MM_ACLED_panel_bydate.dta -- balanced country-day grid
		over the 2018-01-01..2020-03-31 overlap, for the countries that
		appear in both sources.  Variables:
		    country, date, year,
		    num_protests_MM   num_violent_MM   num_peaceful_MM
		    num_protests_ACLED  num_violent_ACLED  num_peaceful_ACLED  num_gvr_ACLED
		    protest_*  violent_*  peaceful_*  (>0 indicators)
---------------------------------------------------------------------------- */

if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}
global work "${identity}/Corrupcion/Protest_Work"

/* ============================================================
   List of countries in BOTH sources (for the overlap window)
   ============================================================ */
use country using "${work}/temp/ACLED/ACLEDclean_bydate.dta", clear
duplicates drop
tempfile acled_countries
save `acled_countries'

use country using "${work}/temp/MM/MMclean_full_bydate.dta", clear
duplicates drop
merge 1:1 country using `acled_countries', keep(3) nogen
display in yellow "=== countries in both ACLED and MM ==="
count
list country, sep(0)
tempfile both_countries
save `both_countries'

/* ============================================================
   Balanced country-day grid over the 2018-2020 overlap window
   ============================================================ */
use `both_countries', clear
local d_start = date("2018-01-01", "YMD")
local d_end   = date("2020-03-31", "YMD")
local nd      = `d_end' - `d_start' + 1
expand `nd'
bysort country: gen date = `d_start' + _n - 1
format date %td
gen year = year(date)

/* ============================================================
   Merge ACLED counts (left join: zero-fill non-event days)
   ============================================================ */
merge 1:1 country date using "${work}/temp/ACLED/ACLEDclean_bydate.dta", ///
	keep(1 3) nogen

foreach v in num_protests_ACLED num_violent_ACLED num_peaceful_ACLED num_gvr_ACLED ///
		protest_ACLED violent_ACLED peaceful_ACLED gvr_ACLED {
	replace `v' = 0 if missing(`v')
}

/* ============================================================
   Merge MM counts (left join: zero-fill non-event days)
   ============================================================ */
merge 1:1 country date using "${work}/temp/MM/MMclean_full_bydate.dta", ///
	keep(1 3) nogen

/* The MM file's outcome variable names are bare (`num_protests`,
   `num_peaceful`, `num_violent`).  Rename with `_MM` suffix to mirror
   the scandals dataset convention. */
foreach v in num_protests num_peaceful num_violent {
	rename `v' `v'_MM
	replace `v'_MM = 0 if missing(`v'_MM)
}

/* >0 indicators for MM (parallel to ACLED) */
gen byte protest_MM  = (num_protests_MM  > 0)
gen byte violent_MM  = (num_violent_MM   > 0)
gen byte peaceful_MM = (num_peaceful_MM  > 0)

label variable protest_MM  "Incidence of a protest (MM)"
label variable violent_MM  "Incidence of a violent protest (MM)"
label variable peaceful_MM "Incidence of a peaceful protest (MM)"

order country date year ///
	num_protests_MM num_violent_MM num_peaceful_MM ///
	num_protests_ACLED num_violent_ACLED num_peaceful_ACLED num_gvr_ACLED ///
	protest_MM violent_MM peaceful_MM ///
	protest_ACLED violent_ACLED peaceful_ACLED gvr_ACLED
compress

di as result "=== MM x ACLED balanced panel: coverage ==="
count
quietly levelsof country
di "Countries: " r(r)
summarize date, format

di as result "=== Outcome means (country-day) ==="
summarize num_protests_MM num_violent_MM num_peaceful_MM ///
	num_protests_ACLED num_violent_ACLED num_peaceful_ACLED num_gvr_ACLED

save "${work}/temp/MM_ACLED_panel_bydate.dta", replace
display in green "b_merge_acled_mm.do finished OK"
