/* ----------------------------------------------------------------------------
						Corruption and Protests
					
	Author: Diego Tocre
	Modifications: Roberto Gonzalez
	Date: November 18, 2024
	
	Objective: Protests and scandals at the event-window level
---------------------------------------------------------------------------- */

/* Define maximum time window */
local max_window = 30

/* Read in corruption scandals data and expand rows */
use "${work}/temp/News/corruption_news.dta", clear
generate LB = 0
append using "${work}/temp/News/corruption_news_LB.dta"
replace LB = 1 if LB == .
local total_days = 2*`max_window' + 1
expand `total_days'
bysort id : replace date = date + _n - `max_window' - 1
bysort id : generate post = (date>date[`max_window']) 		// Post variable (=1 after scandal)
bysort id : generate window = date - date[`max_window'] - 1 	// Window variable (distance to scandal)

/* Add protest data from MM by date */
merge m:1 country date using "${work}/temp/MM/MMclean_full_bydate", keep(1 3) nogenerate
// 5.5% observations match from scandal dataset (with a 30 days time window)

global type_protests "protests peaceful violent"
foreach type in $type_protests {
	replace num_`type' = 0 if num_`type' == .
	rename num_`type' num_`type'_MM
	label var num_`type'_MM "Number of protests (MM)"
	if "`type'"!="protests" label var num_`type'_MM "Number of `type' protests (MM)"
}

/* Add protest data from GDELT by date*/
merge m:1 country date using "${work}/temp/GDELT/GDELT_protests_bydate", keep(1 3) nogen
// 17% observations match from scandal dataset (with a 30 days time window)

foreach type in $type_protests {
	replace num_`type' = 0 if num_`type' == .
	rename num_`type' num_`type'_GDELT
	label var num_`type'_GDELT "Number of protests (GDELT)"
	if "`type'"!="protests" label var num_`type'_GDELT "Number of `type' protests (GDELT)"
}

/* Create additional analysis variables */
/* Interactions */
generate post_imp1 = post*(importance == 1)
generate post_imp2 = post*(importance == 2)
generate post_imp3 = post*(importance == 3)

/* Protest indicators */
generate protest_MM = (num_protests_MM > 0)
generate peaceful_MM = (num_peaceful_MM > 0)
generate violent_MM = (num_violent_MM > 0)
generate protest_GDELT = (num_protests_GDELT > 0)
generate peaceful_GDELT = (num_peaceful_GDELT > 0)
generate violent_GDELT = (num_violent_GDELT > 0)

* Protest logs
generate ln_protests_MM = ln(num_protests_MM + 1)
generate ln_peaceful_MM = ln(num_peaceful_MM + 1)
generate ln_violent_MM = ln(num_violent_MM + 1)
generate ln_protests_GDELT = ln(num_protests_GDELT + 1)
generate ln_peaceful_GDELT = ln(num_peaceful_GDELT + 1)
generate ln_violent_GDELT = ln(num_violent_GDELT + 1)

* Labeling
label variable protest_MM "Incidence of a protest (MM)"
label variable peaceful_MM "Incidence of a peaceful protest (MM)"
label variable violent_MM "Incidence of a violent protest (MM)"
label variable protest_GDELT "Incidence of a protest (GDELT)"
label variable peaceful_GDELT "Incidence of a peaceful protest (GDELT)"
label variable violent_GDELT "Incidence of a violent protest (GDELT)"
label variable num_protests_MM "Number of protests (MM)"
label variable num_peaceful_MM "Number of peaceful protests (MM)"
label variable num_violent_MM "Number of violent protests (MM)"
label variable num_protests_GDELT "Number of protests (GDELT)"
label variable num_peaceful_GDELT "Number of peaceful protests (GDELT)"
label variable num_violent_GDELT "Number of violent protests (GDELT)"
label variable ln_protests_MM "log(1 + number of protests) (MM)"
label variable ln_peaceful_MM "log(1 + number of peaceful protests) (MM)"
label variable ln_violent_MM "log(1 + number of violent protests) (MM)"
label variable ln_protests_GDELT "log(1 + number of protests) (GDELT)"
label variable ln_peaceful_GDELT "log(1 + number of peaceful protests) (GDELT)"
label variable ln_violent_GDELT "log(1 + number of violent protests) (GDELT)"

generate year = year(date)
label variable year "Year"
generate month = month(date)
label variable month "Month"
generate day = dow(date)
label variable day "Day of the week (0=Sunday)"
 
/* Dummies for each value of the categorical variable */
tabulate month, gen(month_)
tabulate day, gen(day_)
tabulate importance, gen(importance_)

egen country_id = group(country)

/* Sorting this dataset by state and year */
sort id date

/* Setting the panel and time variables */
tset id date

/* Cloning scandal for day 0 */
gen s = (window == 0)
label var s "0"
gen s1 = (window == 0 & importance == 1)
label var s1 "0"
gen s2 = (window == 0 & importance == 2)
label var s2 "0"
gen s3 = (window == 0 & importance == 3)
label var s3 "0"

/* Creating 5-day period lags of the indicator variable of scandals */
forvalues i = 5(5)30 {
	if `i' == 5 local j = 0
	else local j = `i' - 4
	
	generate s_lag`i' = (window >= `j' & window <= `i')
	label var s_lag`i' "`i'"
	gen s1_lag`i' = (window >= `j' & window<=`i' & importance == 1)
	label var s1_lag`i' "`i'"
	gen s2_lag`i' = (window >= `j' & window<=`i' & importance == 2)
	label var s2_lag`i' "`i'"
	gen s3_lag`i' = (window >= `j' & window<=`i' & importance == 3)
	label var s3_lag`i' "`i'"
}

generate post1 = (window >= 0 & window <= 15)
generate post2 = (window >= 16 & window <= 30)

/* Creating 5-day period leads of the indicator variable of scandals */
generate s_lead5 = 0						/* This is the base/reference category */
label var s_lead5 "-5"
generate s1_lead5 = 0
label var s1_lead5 "-5"
generate s2_lead5 = 0
label var s2_lead5 "-5"
generate s3_lead5 = 0
label var s3_lead5 "-5"

forvalues i = 10(5)30 {
	local j = `i' - 4
	gen s_lead`i' = (window >= -`i' & window <= -`j')
	label var s_lead`i' "-`i'"
	gen s1_lead`i' = (window >= -`i' & window <= -`j' & importance == 1)
	label var s1_lead`i' "-`i'"
	gen s2_lead`i' = (window >= -`i' & window <= -`j' & importance == 2)
	label var s2_lead`i' "-`i'"
	gen s3_lead`i' = (window >= -`i' & window <= -`j' & importance == 3)
	label var s3_lead`i' "-`i'"
}

/* Labeling variables */
label variable post "Post-scandal"
label variable post1 "0-15 days post-scandal"
label variable post2 "16-30 days post-scandal"
label variable post_imp1 "Highest importance $\times$ post-scandal"
label variable post_imp2 "Medium importance $\times$ post-scandal"
label variable post_imp3 "Lower importance $\times$ post-scandal"

/* Save clean and merged dataset */
save "${datfin}/protests_scandals_30days.dta", replace
