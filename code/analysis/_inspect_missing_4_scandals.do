/* Diagnostic v2 -- compare master corruption_news_v2 vs scandals_classified.csv
   to find the 5 master IDs NOT in the manual-classification CSV, and to see
   whether any field (importance, LB, date2 != date, etc.) distinguishes them
   from the 186 IDs that DO appear in the manual classification. */

if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}
global path   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"
global datwrk "${path}/Data/working"

/* 1. Load master and tag which IDs are in the CSV */
use "${datwrk}/News/corruption_news_v2.dta", clear

/* Merge in the CSV's id+position to flag classified vs not */
preserve
	import delimited using "${datfin}/scandals_classified.csv", ///
		clear varnames(1) bindquotes(strict)
	keep id country position
	tempfile cls
	save `cls'
restore

display _newline "=== Duplicates on (id, country) in master ==="
duplicates report id country
duplicates list id country, sepby(id)

/* Master has duplicates on (id, country); use m:1 merge to flag */
merge m:1 id country using `cls', keep(1 3) generate(_in_csv)
gen byte unclassified = (_in_csv == 1)
label define UNCLASS 0 "In CSV" 1 "Missing from CSV", replace
label values unclassified UNCLASS

display _newline "=== How many master rows are missing from CSV ==="
tab unclassified, missing

display _newline "=== All master rows MISSING from CSV ==="
list id country date date2 importance LB if unclassified == 1, ///
    noobs string(20) sepby(id)

display _newline "=== importance distribution, classified vs not ==="
tab importance unclassified, missing
display _newline "=== LB distribution, classified vs not ==="
tab LB unclassified, missing
