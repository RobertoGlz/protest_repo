/* ----------------------------------------------------------------------------
									Protests
									
	Code author: Roberto Gonzalez
	Date: July 17, 2025
---------------------------------------------------------------------------- */

/*	------------------- Configuration for collaborators -------------------- */
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

/* Creating Global File Paths ---------------------------------------------- */
global path "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global dof 		"${path}/Dofiles"
global datraw 	"${path}/Data/raw"
global datfin 	"${path}/Data/final"
global datwrk 	"${path}/Data/working"
global datold 	"${path}/Data/archive"
global datpub 	"${path}/Data/publication"
global output 	"${path}/Output"
global violent  "$output/Violent"
global mid 		"$violent/mid"
global logs 	"${path}/Logs"
global graphs 	"${output}/Graphs"
global tables 	"${output}/Tables"
global overleaf	"${identity}/Apps/Overleaf"
local date: dis %td_NN_DD_CCYY date(c(current_date), "DMY")
gl date_string = subinstr(trim("`date'"), " " , "_", .)
/* ------------------------------------------------------------------------- */

/* Read in raw MM data */
import delimited "${datraw}/Protests/MM/MMraw.csv", clear

/* Create data of protest */
generate date = mdy(startmonth, startday, startyear)
format date %td

/* Keep protests only */
keep if protest == 1

/* create peaceful and violent protest counts */
generate raw_num_peaceful_MM = (protesterviolence == 0)
generate raw_num_violent_MM = (protesterviolence == 1)
generate raw_num_protests_MM = (raw_num_violent_MM + raw_num_peaceful_MM)
generate raw_government_response_violent = inlist(stateresponse1, "arrests", "beatings", "killings", "shootings")

/* Aggregate at the country-date level */
collapse (rawsum) raw_*, by(country date)

/* Merge in the current analysis data */
local analysis_data = "${datfin}/protests_scandals_30days_v3.dta"
merge 1:m country date using "`analysis_data'", keep(2 3)

/* _merge == 2 implies there were no protests in that country-date so impute zero */
count if _merge == 2
local n_no_protests = r(N)

foreach ptype in "protests" "peaceful" "violent" {
	count if missing(raw_num_`ptype'_MM)
	replace raw_num_`ptype'_MM = 0 if _merge == 2
}
replace raw_government_response_violent = 0 if _merge == 2

/* Create difference in analysis data relative to raw and an indicator for difference not being zero */
foreach ptype in "protests" "peaceful" "violent" {
	generate analysis_minus_raw_`ptype' = (num_`ptype'_MM - raw_num_`ptype'_MM)
	generate difference_in_`ptype' = (analysis_minus_raw_`ptype' != 0)
	
	tabulate analysis_minus_raw_`ptype'
	tabulate difference_in_`ptype' 
	
	tabulate raw_num_`ptype'_MM num_`ptype'_MM, row
}

/* Assert that within country-date the outcomes are constant (only relevant for scandals with overlap) */
local aux = 0
foreach outvar of varlist num_violent_MM num_peaceful_MM government_response_violent {
	local ++aux
	bysort country date : egen mean_`aux' = mean(`outvar')
	assert `outvar' == mean_`aux' 
}
