/* ----------------------------------------------------------------------------
					Violent effects of apex corruption

	Code author: Roberto Gonzalez
	Date: 2026-05-21

	Objective (protests_plan.md, Task 3):
		Clean the ACLED extract and produce country-day counts of:
		  num_protests_ACLED  = #(event_type in {Protests, Riots})
		  num_violent_ACLED   = #(event_type == Riots)        i.e. all
		                        sub_event_type in {Violent demonstration,
		                        Mob violence} given the current data
		  num_peaceful_ACLED  = #(sub_event_type == "Peaceful protest")
		  num_gvr_ACLED       = #(sub_event_type == "Excessive force
		                          against protesters")

		Saves a country-date panel parallel in shape to MMclean_full_bydate.

	Source file (latest):
		${datraw}/ACLED/ACLED Data_2026-05-21.csv  (385,452 events,
		2018-01-01..2025-05-21, 53 LAC + US/Canada countries)
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
global datraw "${path}/Data/raw"

/* Make sure target temp folder exists */
capture mkdir "${work}/temp/ACLED"

local acled_csv "${datraw}/ACLED/ACLED Data_2026-05-21.csv"

/* ============================================================
   IMPORT
   ============================================================ */
import delimited using "`acled_csv'", ///
	clear varnames(1) bindquotes(strict) encoding(utf8) stringcols(_all)

/* keep only fields we need to limit memory */
keep event_id_cnty event_date country event_type sub_event_type

/* parse date */
gen date = date(event_date, "YMD")
format date %td
assert !missing(date)

/* ============================================================
   COUNTRY-NAME HARMONIZATION
   ACLED uses standard English names.  MM/scandals do too with minor
   exceptions (which are listed in b_clean_MMdata.do).  Apply the same
   harmonization here so country merges later work cleanly.
   ============================================================ */
replace country = strtrim(country)
/* These differences are the only ones that affect LAC overlap and would
   block a m:1 country merge with the MM/scandals tables: */
replace country = "Bolivia"           if strpos(country, "Bolivia") > 0
replace country = "Venezuela"         if strpos(country, "Venezuela") > 0

/* ============================================================
   OUTCOME FLAGS (one per row, then collapse)
   ============================================================ */
gen byte is_protest       = inlist(event_type, "Protests", "Riots")
gen byte is_violent       = (event_type == "Riots") | ///
	inlist(sub_event_type, "Violent demonstration", "Mob violence")
gen byte is_peaceful      = (sub_event_type == "Peaceful protest")
gen byte is_gvr           = (sub_event_type == "Excessive force against protesters")

/* Sanity: violence + peaceful + intervention + gvr should cover Protests/Riots */
display in yellow "Row distribution under the mapping:"
tabulate event_type, missing
tabulate is_protest is_violent
display in yellow "Any: " r(N)

/* ============================================================
   COLLAPSE to country-date
   ============================================================ */
collapse (sum) ///
	num_protests_ACLED   = is_protest ///
	num_violent_ACLED    = is_violent ///
	num_peaceful_ACLED   = is_peaceful ///
	num_gvr_ACLED        = is_gvr, ///
	by(country date)

label variable num_protests_ACLED "Number of protests (ACLED, Protests + Riots)"
label variable num_violent_ACLED  "Number of violent protests (ACLED, Riots event_type)"
label variable num_peaceful_ACLED "Number of peaceful protests (ACLED, sub_event=Peaceful protest)"
label variable num_gvr_ACLED      "Government violent response (ACLED, sub_event=Excessive force against protesters)"

/* Indicators >0 (parallel to MM's protest_MM/peaceful_MM/violent_MM) */
gen byte protest_ACLED  = (num_protests_ACLED  > 0)
gen byte violent_ACLED  = (num_violent_ACLED   > 0)
gen byte peaceful_ACLED = (num_peaceful_ACLED  > 0)
gen byte gvr_ACLED      = (num_gvr_ACLED       > 0)

label variable protest_ACLED  "Incidence of a protest (ACLED)"
label variable violent_ACLED  "Incidence of a violent protest (ACLED)"
label variable peaceful_ACLED "Incidence of a peaceful protest (ACLED)"
label variable gvr_ACLED      "Incidence of govt violent response (ACLED)"

order country date num_protests_ACLED num_violent_ACLED num_peaceful_ACLED num_gvr_ACLED ///
	protest_ACLED violent_ACLED peaceful_ACLED gvr_ACLED
compress

di as result "=== ACLED clean: panel coverage ==="
count
quietly levelsof country
di "Countries: " r(r)
summarize date, format

di as result "=== ACLED clean: outcome means (country-day) ==="
summarize num_protests_ACLED num_violent_ACLED num_peaceful_ACLED num_gvr_ACLED

save "${work}/temp/ACLED/ACLEDclean_bydate.dta", replace
display in green "b_clean_ACLED.do finished OK"
