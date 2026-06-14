/* ----------------------------------------------------------------------------
					Violent effects of apex corruption

	Code author: Roberto Gonzalez
	Date: 2026-05-21

	Objective (protests_plan.md, Task 2):
		Build a *balanced* country x calendar-date panel covering the full
		Mass Mobilization period for the 23 LAC countries that appear in
		MM.  Merge:
		  - MM daily counts and >0 indicators (any/violent/peaceful/gvr)
		  - ACLED daily counts (parallel four outcomes; coverage 2018-2025)
		  - Scandal metadata at the country-date level (scandal_today,
		    scandal_id, scandal_official_type, scandal_position,
		    scandal_incumbent), and a derived `days_since_first_scandal`.

		Output two files for downstream DiD work (Task 1 - dCDH/BJS/SA):
		  - ${datfin}/panel_country_day.dta   (daily)
		  - ${datfin}/panel_country_week.dta  (weekly aggregation)

	Schema (daily; weekly identical up to time aggregation):
		country country_id  date  week_start  year  month  dow
		mm_protests mm_violent mm_nonviolent mm_gvr
		mm_protest mm_violent_ind mm_nonviolent_ind mm_gvr_ind   (>0)
		acled_protests acled_violent acled_nonviolent acled_gvr
		acled_protest acled_violent_ind ...                       (>0)
		acled_coverage   (1 if date in ACLED coverage window)
		scandal_today  scandal_id  scandal_official_type
		scandal_position  scandal_incumbent
		days_since_first_scandal
---------------------------------------------------------------------------- */

if "`c(username)'" == "lalov" {
	gl identity "C:\Users\lalov\ITAM Seira Research Dropbox\Eduardo Rivera"
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

/* ============================================================
   1.  Aggregate MM events per (country, date) within LAC
   ============================================================ */
use country date protest peaceful_protest violent_protest ///
	violence_against_peacefulprot lac ///
	using "${work}/temp/MM/MMclean_full.dta", clear
keep if lac == 1
collapse (sum) mm_protests   = protest ///
	mm_nonviolent = peaceful_protest ///
	mm_violent    = violent_protest ///
	mm_gvr        = violence_against_peacefulprot, ///
	by(country date)
tempfile mm_daily
save `mm_daily'

di as result "=== MM LAC events aggregated to country-date ==="
count
quietly levelsof country
di "LAC countries in MM: " r(r)

/* ============================================================
   2.  Balanced country x date grid (LAC universe, full MM window)
   ============================================================ */
preserve
	use `mm_daily', clear
	keep country
	duplicates drop
	tempfile lac_countries
	save `lac_countries'
restore

use `lac_countries', clear
local d_start = mdy(1, 1, 1990)
local d_end   = mdy(3, 31, 2020)
local nd      = `d_end' - `d_start' + 1
display in yellow "Grid: " _N " countries x `nd' days = " _N*`nd' " rows"
expand `nd'
bysort country: gen date = `d_start' + _n - 1
format date %td

/* ============================================================
   3.  Merge MM aggregates (zero-fill non-event days)
   ============================================================ */
merge 1:1 country date using `mm_daily', keep(1 3) nogen
foreach v in mm_protests mm_violent mm_nonviolent mm_gvr {
	replace `v' = 0 if missing(`v')
	label variable `v' "MM: number of `v' on the day"
}
foreach v in mm_protests mm_violent mm_nonviolent mm_gvr {
	gen byte `v'_ind = (`v' > 0)
}

/* ============================================================
   4.  Merge ACLED daily counts (zero-fill outside 2018-2025)
   ============================================================ */
merge 1:1 country date using "${work}/temp/ACLED/ACLEDclean_bydate.dta", keep(1 3) nogen

/* Coverage flag: 1 if date is in the ACLED extract window for that country */
gen byte acled_coverage = (date >= mdy(1,1,2018) & date <= mdy(5,21,2025))

/* Rename to match the panel convention; zero-fill */
rename num_protests_ACLED  acled_protests
rename num_violent_ACLED   acled_violent
rename num_peaceful_ACLED  acled_nonviolent
rename num_gvr_ACLED       acled_gvr
foreach v in acled_protests acled_violent acled_nonviolent acled_gvr {
	replace `v' = 0 if missing(`v')
	gen byte `v'_ind = (`v' > 0)
}
/* drop the old ACLED >0 indicators that came in with names protest_ACLED etc */
capture drop protest_ACLED violent_ACLED peaceful_ACLED gvr_ACLED

/* Outside ACLED coverage window, set ACLED counts to .  not 0
   (so we can distinguish "ACLED searched and found 0" from "no ACLED data") */
foreach v in acled_protests acled_violent acled_nonviolent acled_gvr {
	replace `v' = . if acled_coverage == 0
	replace `v'_ind = . if acled_coverage == 0
}

/* ============================================================
   5.  Scandal metadata (one country-date row per scandal where it broke)
   ============================================================ */
preserve
	/* Get scandal-level metadata: id, country, scandal_date, official_involved
	   (from add_catvar dataset) + position + political_affiliation (from CSV) */
	use id country date official_involved ///
		using "${datfin}/protests_scandals_30days_v3_with_lv_of_agent_involved.dta", clear
	bysort id country: keep if _n == 1   /* one row per scandal */
	/* The dataset stores window-row date; the "scandal date" is the one where
	   window == 0, which is what tag_id==1 gives in the source.  Use the
	   `date` carried on that row. */
	tempfile scandals_meta
	save `scandals_meta'
restore
preserve
	/* Take scandals_classified.csv for position + political_affiliation */
	import delimited using "${datfin}/scandals_classified.csv", ///
		clear varnames(1) bindquotes(strict)
	keep id country position political_affiliation
	tempfile cls
	save `cls'
restore

preserve
	use `scandals_meta', clear
	rename date scandal_date
	format scandal_date %td
	merge 1:1 id country using `cls', keep(1 3) nogen
	rename position scandal_position
	rename political_affiliation scandal_political_affiliation
	rename official_involved scandal_official_type
	rename id scandal_id
	tempfile sc
	save `sc'
restore

/* Merge scandals onto the panel by (country, date).  Multiple scandals
   could in principle break on the same country-date; rare but possible -
   use joinby and then collapse to a max-one-row-per (country, date)
   representation, keeping scandal_id as a list when there's a tie. */
preserve
	use `sc', clear
	rename scandal_date date
	bysort country date: keep if _n == 1     /* drop ties; almost never happens */
	tempfile sc1
	save `sc1'
restore

merge m:1 country date using `sc1', keep(1 3) nogen
gen byte scandal_today = !missing(scandal_id)

/* days_since_first_scandal: per country, days since min(scandal_date) */
preserve
	use `sc', clear
	collapse (min) first_scandal_date = scandal_date, by(country)
	tempfile firsts
	save `firsts'
restore
merge m:1 country using `firsts', keep(1 3) nogen
gen long days_since_first_scandal = date - first_scandal_date
label variable days_since_first_scandal ///
	"Days since this country's first scandal (negative = before)"

/* ============================================================
   6.  Calendar variables
   ============================================================ */
gen int  year       = year(date)
gen byte month      = month(date)
gen byte dow        = dow(date)              /* 0=Sun .. 6=Sat */
/* Monday-anchored week_start (2010-01-04 was a Monday) */
gen int  week_start = date - mod(date - mdy(1,4,2010), 7)
format week_start %td
label variable dow        "Day of week (0=Sun..6=Sat)"
label variable week_start "Monday start of the date's calendar week"

/* ============================================================
   7.  Country id, ordering, compress, save daily
   ============================================================ */
egen country_id = group(country)

order country country_id date week_start year month dow ///
	mm_protests mm_violent mm_nonviolent mm_gvr ///
	mm_protests_ind mm_violent_ind mm_nonviolent_ind mm_gvr_ind ///
	acled_protests acled_violent acled_nonviolent acled_gvr ///
	acled_protests_ind acled_violent_ind acled_nonviolent_ind acled_gvr_ind ///
	acled_coverage ///
	scandal_today scandal_id scandal_official_type ///
	scandal_position scandal_political_affiliation ///
	first_scandal_date days_since_first_scandal

compress

di as result "=== panel_country_day: coverage ==="
count
summarize date, format
quietly levelsof country
di "Countries: " r(r)
di as result "=== MM outcome means (daily, all years) ==="
summarize mm_protests mm_violent mm_nonviolent mm_gvr
di as result "=== ACLED outcome means (daily, only acled_coverage==1) ==="
summarize acled_protests acled_violent acled_nonviolent acled_gvr if acled_coverage == 1
di as result "=== Scandals on the grid (one row per scandal date) ==="
count if scandal_today == 1
preserve
	keep if scandal_today == 1
	tab scandal_official_type, missing
	tab scandal_position, missing
restore

save "${datfin}/panel_country_day.dta", replace
display in green "panel_country_day.dta saved"

/* ============================================================
   8.  Weekly collapse and save
   ============================================================ */
preserve
	use "${datfin}/panel_country_day.dta", clear

	/* counts -> sum;  indicators -> max (any during the week);
	   scandal_today -> max (any scandal that week);
	   first_scandal_date -> firstnm (constant per country);
	   days_since_first_scandal -> mean of the (Mon..Sun) days for the week,
	   which equals (start-of-week - first_scandal_date) + 3 -- but cleaner
	   to recompute at the week level. */

	collapse (sum)  mm_protests mm_violent mm_nonviolent mm_gvr ///
		acled_protests acled_violent acled_nonviolent acled_gvr ///
		(max)  mm_protests_ind mm_violent_ind mm_nonviolent_ind mm_gvr_ind ///
			acled_protests_ind acled_violent_ind acled_nonviolent_ind acled_gvr_ind ///
			scandal_today ///
		(min)  acled_coverage ///
		(firstnm) country_id first_scandal_date ///
			scandal_id scandal_official_type ///
			scandal_position scandal_political_affiliation, ///
		by(country week_start)

	gen int  year  = year(week_start)
	gen byte month = month(week_start)
	gen long days_since_first_scandal = week_start - first_scandal_date

	order country country_id week_start year month ///
		mm_protests mm_violent mm_nonviolent mm_gvr ///
		mm_protests_ind mm_violent_ind mm_nonviolent_ind mm_gvr_ind ///
		acled_protests acled_violent acled_nonviolent acled_gvr ///
		acled_protests_ind acled_violent_ind acled_nonviolent_ind acled_gvr_ind ///
		acled_coverage ///
		scandal_today scandal_id scandal_official_type ///
		scandal_position scandal_political_affiliation ///
		first_scandal_date days_since_first_scandal

	compress

	di as result "=== panel_country_week: coverage ==="
	count
	summarize week_start, format
	quietly levelsof country
	di "Countries: " r(r)
	di as result "=== MM outcome means (weekly) ==="
	summarize mm_protests mm_violent mm_nonviolent mm_gvr
	di as result "=== Scandals on the weekly grid ==="
	count if scandal_today == 1

	save "${datfin}/panel_country_week.dta", replace
	display in green "panel_country_week.dta saved"
restore

display in green "b_panel_country_day.do finished OK"
