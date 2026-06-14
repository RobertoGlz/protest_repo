/* ----------------------------------------------------------------------------
	protests
	
	code author: roberto gonzalez
	date: january 16, 2026
	
	objective: create a csv file to have ChatGPT classify each scandal according
	to different dimensions:
	- incumbent vs opposition vs others
	- presidents, sc judges, national congressmen, etc
	- indictment vs media report vs sentenced vs formal accusation
---------------------------------------------------------------------------- */

/* Set up globals for pointing to each users's Dropbox */
if "`c(username)'" == "lalov" {
	global identity "C:/Users/lalov/ITAM Seira Research Dropbox/Eduardo Rivera"
}
if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
	global work "${identity}/Corrupcion/Protest_Work"
}

/* Define globals with relative paths */
global path "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global dof 		"${path}/Dofiles"
global datraw 	"${path}/Data/raw"
global datfin 	"${path}/Data/final"
global datwrk 	"${path}/Data/working"
global datold 	"${path}/Data/archive"
global datpub 	"${path}/Data/publication"
global output 	"${path}/Output"
global logs 	"${path}/Logs"
global graphs 	"${output}/Graphs"
global tables 	"${output}/Tables"
global overleaf	"${identity}/Apps/Overleaf"
local date: dis %td_NN_DD_CCYY date(c(current_date), "DMY")
global date_string = subinstr(trim("`date'"), " " , "_", .)

/* Read in scandals dataset */
import excel "${datraw}/News/Appended_News_v4.xlsx", sheet("7.Append") first clear

/* Rename variables */
rename (ID Country StartDateLalo PeakDateRevised RevisedDatePaco Importance SummaryText) (id country date_first date_peak date_revised importance summary)

/* Main date variable: Prioritizes peak date according to Google Trends */
generate date = date_peak
label variable date "Date (prioritizing Google Trends' peak)"
format date %td

/* Secondary date variable: Prioritizes first news date according to LexisNexis */
generate date2 = date_first
label variable date2 "Date (prioritizing LexisNexis' first news)"
format date2 %td

/* keep observations which are not 'Mal' (?) */
keep if Mal == 0

/* Fix some country names */
replace country = "Venezuela" if country=="Venezuela "
replace country="Brazil" if country=="Brazil "
replace country="Ecuador" if country=="Ecuador "

/* Label scandal id variable */
label variable id "Scandal ID"

/* Drop duplicates */
replace country = strtrim(country)
duplicates drop country date, force

/* Keep relevant variables */
keep id country date summary

/* Make sure data is unique by country scandal */
unique id country

/* Add analysis data */
merge 1:m country id using "${datfin}/protests_scandals_30days_v3.dta"

drop if missing(summary)
display in red _N

keep if window == 0

keep id country summary date

/* export file with summary of scandals */
export delimited using "${datfin}/protests_scandals_for_heterogeneity_classification.csv", replace quote
