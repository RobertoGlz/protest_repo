/* ----------------------------------------------------------------------------
								Protests
									
	Code author: Roberto Gonzalez
	Date: July 24, 2025
	
	Objective: Add to the analysis dataset a variable in which we store
	whether the scandal involves (i) a president or prime minister, 
	(ii) a Supreme Court Judge or Secretary, or (iii) any other official
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

/* Create categorical variable for apex official involved */
generate official_involved = .
replace official_involved = 1 if strpos(lower(summary), "president") > 0 | ///
	strpos(lower(summary), "dilma") > 0 | strpos(lower(summary), "lula") > 0 
replace official_involved = 2 if (strpos(lower(summary), "supreme court") > 0 | ///
	strpos(lower(summary), "supreme court") > 0 | ///
	strpos(lower(summary), "juez de la suprema corte") > 0 | ///
	strpos(lower(summary), "fiscal") > 0 | strpos(lower(summary), "minister") > 0 | ///
	strpos(lower(summary), "ministro") > 0 | strpos(lower(summary), "ministry of") | ///
	strpos(lower(summary), "ricardo jaime") > 0 | strpos(lower(summary), "julio de vido") > 0 | ///
	strpos(lower(summary), "military") > 0 | strpos(lower(summary), "intendente") > 0 | ///
	strpos(lower(summary), "alcalde") > 0 | strpos(lower(summary), "mayor") > 0 | ///
	strpos(lower(summary), "governor") > 0 | strpos(lower(summary), "prosecutor") > 0 | ///
	strpos(lower(summary), "governador") > 0 | strpos(lower(summary), "diputad") | ///
	strpos(lower(summary), "inassa") | strpos(lower(summary), "senador") | ///
	strpos(lower(summary), "senator") | strpos(lower(summary), "procurador") | ///
	strpos(lower(summary), "secretario") | strpos(lower(summary), "gobernador") | ///
	strpos(lower(summary), "javier duarte")) & ///
	(official_involved != 1)
replace official_involved = 3 if !inlist(official_involved, 1, 2)

replace official_involved = 3 if id == "73" // Armed forces captains involved in drug trafficking
replace official_involved = 2 if id == "NEW23" // Congressman (diputado) in San Luis Potosi, Mexico embezzlement
replace official_involved = 3 if id == "153" // uncle of vice-president linked to Odebrecht (1 maybe?)
replace official_involved = 3 if id == "TWNEWLATINO14" // ex manager of Petroecuador for traffick of influences

label define OFF 1 "President" 2 "Supreme Court Judge/Secretary" 3 "Others"
label values official_involved OFF

egen tag_id = tag(id)
br if official_involved == 3 & tag_id == 1 & country != "Venezuela"
fre official_involved if tag_id == 1 & country != "Venezuela"

/* save dataset */
save "${datfin}/protests_scandals_30days_v3_with_lv_of_agent_involved.dta", replace
