/* Verify that panel_country_day.dta gives the same protest counts as
   protests_scandals_30days_v3.dta for the SAME (country, date) cells.
   This is the assumption the randomization-inference test relies on. */

if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}
global path   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"
global work   "${identity}/Corrupcion/Protest_Work"

display _newline "=== Describe MMclean_full_bydate (source of the event-window build) ==="
use "${work}/temp/MM/MMclean_full_bydate.dta", clear
describe, short
describe

display _newline "=== Describe panel_country_day.dta ==="
use "${datfin}/panel_country_day.dta", clear
describe, short

display _newline "=== Describe protests_scandals_30days_v3.dta ==="
use "${datfin}/protests_scandals_30days_v3.dta", clear
describe, short

/* Head-to-head spot check: pick 10 random (country, date) cells that
   appear in BOTH panels and compare num_violent_MM vs mm_violent. */
display _newline "=== Spot check: same (country, date) cells, both datasets ==="

use country date num_violent_MM num_peaceful_MM num_protests_MM ///
    using "${datfin}/protests_scandals_30days_v3.dta", clear
drop if country == "Venezuela"
bysort country date: keep if _n == 1  /* one row per (country, date) */
rename num_violent_MM  violent_evwin
rename num_peaceful_MM peaceful_evwin
rename num_protests_MM protests_evwin
tempfile evwin
save `evwin'

use country date mm_violent mm_nonviolent mm_protests ///
    using "${datfin}/panel_country_day.dta", clear
drop if country == "Venezuela"
rename mm_violent    violent_pcd
rename mm_nonviolent peaceful_pcd
rename mm_protests   protests_pcd

merge 1:1 country date using `evwin', keep(3) nogenerate

display _newline "=== Cell-by-cell agreement (should be 100% if same source) ==="
count
count if violent_evwin != violent_pcd
display "  violent disagreements:  " r(N)
count if peaceful_evwin != peaceful_pcd
display "  peaceful disagreements: " r(N)
count if protests_evwin != protests_pcd
display "  protests disagreements: " r(N)

display _newline "=== First 15 disagreements (violent), if any ==="
list country date violent_evwin violent_pcd ///
    if violent_evwin != violent_pcd, sepby(country) noobs
