/* ----------------------------------------------------------------------------
								Protests
									
	Code author: Roberto Gonzalez
	Date: July 21, 2025
	
	Objective: Construct dataset for analysis. We want an observation to be
	a country-year and we observe the time-to-scandal and the number
	of protests in a given country-date
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

/* ----------------------------------------------------------------------------
							Mass Mobilization Data
---------------------------------------------------------------------------- */
/* Read in Mass Mobilization data */
import delimited "${datraw}/Protests/MM/MMraw.csv", clear

/* keep observations of protests */
keep if protest==1
sort country startyear startmonth startday

/* create date of protest occurrence */
generate date = mdy(startmonth, startday, startyear)
format date %td 

/* create indicators for whether the protest was violent or not */
generate peaceful_mm = (protesterviolence == 0)
generate violent_mm = (protesterviolence == 1)

/* create indicator for whether the government's response was violent */
generate gvt_violence_mm = (inlist(stateresponse1, "arrests", "beatings", "killings", "shootings"))

/* if there is more than one protest occurring in the same country-year, sum them */
collapse (rawsum) num_peaceful_mm = peaceful_mm ///
	num_violent_mm = violent_mm ///
	num_gvt_violence_mm = gvt_violence_mm ///
	(max) indicator_peaceful_mm = peaceful_mm ///
	indicator_violent_mm = violent_mm ///
	indicator_gvt_violence_mm = gvt_violence_mm, ///
	by(country date)
	
/* save temproary file to merge later into the scandals data */
tempfile massmob
save `massmob'

/* ----------------------------------------------------------------------------
								Scandals Data
---------------------------------------------------------------------------- */
/* Read in scandals dataset */
import excel "${datraw}/News/Appended_News_v4.xlsx", sheet("8.Big-Middle-Low") first clear

/* Rename variables */
rename (ID Country StartDateLalo PeakDateRevised Revised Importance Summary) (id country date_first date_peak date_revised importance summary)

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

/* Keep relevant variables */
keep id country date date2

/* Fix some country names */
replace country = "Venezuela" if country=="Venezuela "
replace country="Brazil" if country=="Brazil "
replace country="Ecuador" if country=="Ecuador "

/* Drop Venezuela from analysis */
drop if country == "Venezuela"

/* Label scandal id variable */
label variable id "Scandal ID"

/* Drop duplicates */
replace country = strtrim(country)
duplicates drop country date, force

/* create encoding version of country */
egen country_enc = group(country)

/* Observations in this dataset are scandals, tag them */
generate scandal = 1

/* keep observations in a given time frame */
local minyear = 2008
local maxyear = 2019
keep if inrange(year(date), `minyear', `maxyear')

/* Define number of days to be observed before and after the scandal */
local window_days = 120

/* Expand each observation for the whole time window we need */
local days_around_scandal = 2*`window_days' + 1
expand `days_around_scandal'

/* generate dates around scandal variable */
bysort id : replace date = date + _n - 1 + `window_days'
bysort id : generate window = (date - date[`window_days'] - 1)
tabulate window
bysort id : generate post = (window >= 0)

/* add the outcomes of protests from the raw data */
merge m:1 country date using `massmob', keep(1 3)

/* observations only in master data are days around the scandal in which protests do not occurr so recode those values */
recode num_peaceful_mm num_violent_mm num_gvt_violence_mm ///
	indicator_peaceful_mm indicator_violent_mm indicator_gvt_violence_mm ///
	(missing = 0)

/* obtain month of date and day of date and year */
generate month = month(date)
generate day = dow(date)	
generate year = year(date)
	
/* create variable for combination of Country-Year */
egen country_year = group(country year)	
	
/* ----------------------------------------------------------------------------
				Estimate event-study with Poisson QMLE 
---------------------------------------------------------------------------- */
/* Define local with outcomes of interest */
local outcome_list = "num_peaceful_mm num_violent_mm num_gvt_violence_mm"

/* Define local for fixed effects to be absorbed */
local fe_list = "month day country_year"

/* define tratment indicator */
local treatvar = "post"

/* define level for confidence intervals */
local ci_level = 90
local alphaval = (100 - `ci_level')/100

/* define locals for storing days to pool in leads and lags */
local bin_days = 30
/* Check that event windows are divisible by the number of days to be pooled */
assert mod(`window_days', `bin_days') == 0
/* Obtain number of bins that can be obtained with specified window lengths and bin days */
local n_bins = `window_days'/`bin_days'
display in yellow "Based on window length and number of days to be pooled we can create `n_bins' `bin_days'-day bins"

local bin_numb = 0 // counter for bin being created
forvalues bbb = -`bin_days'(-`bin_days')-`window_days' {
	/* add one to bin counter */
	local ++bin_numb
	/* create the indicator for the bin */
	display in yellow "Creating bin for time-to-scandal in [`bbb',`=`bbb'+`bin_days'')"
	generate lead_`bin_numb' = (window >= `bbb' & window <  `bbb'+`bin_days')
	label variable lead_`bin_numb' "`bbb'"
	tabulate window lead_`bin_numb'
}

local bin_numb = 0 // counter for bin being created
forvalues bbb = `bin_days'(`bin_days')`window_days' {
	/* add one to bin counter */
	local ++bin_numb
	/* create the indicator for the bin */
	if `bin_numb' == 1 {
		display in yellow "Creating bin for time-to-scandal in [`=`bbb'-`bin_days'', `bbb']"
		generate lag_`bin_numb' = (window <= `bbb' & window >=  `bbb'-`bin_days')
		label variable lag_`bin_numb' "`bbb'"
		tabulate window lag_`bin_numb'
	}
	else {
		display in yellow "Creating bin for time-to-scandal in (`=`bbb'-`bin_days'', `bbb']"
		generate lag_`bin_numb' = (window <= `bbb' & window > `bbb'-`bin_days')
		label variable lag_`bin_numb' "`bbb'"
		tabulate window lag_`bin_numb'
	}
}

/* Create indicator for combination of leads and lags (i.e. bin of observation) */
ds lead_* lag_*
egen grupo_dias = group(`r(varlist)')

/* Cluster standard errors */
local clustervars = "country_enc year grupo_dias"
egen cluster_variable = group(`clustervars')

/* Perform estimation */
local outcome_counter = 0 // for storing estimates of the coefficients for each outcome
foreach outcome in `outcome_list' {
	/* Clear esimates stored */
	estimates clear
	/* Add one to the outcome counter */
	local ++outcome_counter
	/* Message for noting in which outcome is the algorithm being performed */
	display in yellow "Estimating avg. effect on `outcome' across all post-treatment days"
	/* Estimate average effect in the post period */
	eststo m`outcome_counter' : ppmlhdfe `outcome' `treatvar', absorb(`fe_list') ///
		vce(cluster cluster_variable) irr
	/* Store effect and p-value in locals to add to plot later */
	local av_est = string(exp(_b[`treatvar']), "%3.2fc")
	local p_av_est = 2*normal(-abs(_b[`treatvar']/_se[`treatvar']))
	if `p_av_est' < 0.01 {
		local p_string = "p < 0.01"
	}
	else {
		local p_string = "p = " + string(`p_av_est', "%4.3fc")
	}
	/* Get number of scandals used */
	quietly levelsof id if e(sample) == 1
	local numb_scandals = r(r)
	/* Estimate effect in event-study specification */
	display in yellow "Estimating event-study specification on `outcome'"
	ppmlhdfe `outcome' lag_* lead_2 lead_3 lead_4 lead_1, absorb(`fe_list') vce(cluster cluster_variable) irr
	/* Show coefficient plot */
	display in yellow "Doing coefficient plot..."
	coefplot, keep(lead_* lag_*) eform(lead_* lag_*) ///
		levels(`ci_level') baselevels omitted vertical ///
		relocate(lead_4 = -4 lead_3 = -3 lead_2 = -2 lead_1 = -1 lag_1 = 1 lag_2 = 2 lag_3 = 3 lag_4 = 4) ///
		xtitle("days since scandal", size(medium)) xscale(titlegap(2)) ///
		xline(0, lwidth(vthick) lpattern(solid) lcolor(black%10)) ///
		ytitle("incidence rate ratio", size(medium)) yscale(titlegap(2)) ///
		yline(1, lwidth(medthin) lpattern(shortdash) lcolor(black)) ///
		xlabel(-4 "-120" -3 "-90" -2 "-60" -1 "-30" 1 "30" 2 "60" 3 "90" 4 "120", ///
			labsize(medium)) ylabel(#5, nogrid format(%3.1fc) labsize(medium)) ///
		ciopts(lcolor(black) lwidth(medthin)) mcolor(black) msize(medium) ///
		legend(order(- "Avg. Effect = `av_est' (`p_string')" - "`numb_scandals' Scandals") pos(11) ring(0))
	graph export ///
		"${work}/results/figures/poisson_minimal_`outcome'_`window_days'_`ci_level'ci.pdf", ///
		replace
}
