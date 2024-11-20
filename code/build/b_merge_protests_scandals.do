/* ----------------------------------------------------------------------------
						Corruption and Protests
					
	Author: Diego Tocre
	Modifications: Roberto Gonzalez
	Date: November 18, 2024
	
	Objective: Protests and sandals merge
---------------------------------------------------------------------------- */

/* Read in dataset from MM protests */
use "${work}/temp/MM/MMclean_full_bydate.dta", clear

/* Rename variables to distingusih source */
global type_protests "protests peaceful violent"
foreach type in $type_protests {
	rename (num_`type') (num_`type'_MM)
	label var num_`type'_MM "Number of protests during the day (according to MM)"
	if "`type'" != "protests" label var num_`type'_MM "Number of `type' protests during the day (according to MM)"
}

preserve
/* Read in GDELT data */
use "${work}/temp/GDELT/GDELT_protests_bydate.dta", clear
/* Homogenizing the name of the countries (before the merge */
replace country = "Bolivia" if country == "Bolivia, Plurinational State Of"
replace country = "Congo Kinshasa" if country == "Congo, the Democratic Republic of the"
replace country = "Congo Brazzaville" if country == "Congo"
replace country = "Ivory Coast" if strpos(country,"Ivoire") != 0
replace country = "Czech Republic" if country == "Czechia"
replace country = "Iran" if country == "Iran, Islamic Republic of"
replace country = "North Korea" if strpos(country,"Korea, Democratic People") != 0
replace country = "South Korea" if country == "Korea, Republic of"
replace country = "Laos" if strpos(country,"Lao People") != 0
replace country = "Macedonia" if country == "Macedonia, the former Yugoslav Republic of"
replace country = "Slovak Republic" if country == "Slovakia"
replace country = "Syria" if country == "Syrian Arab Republic"
replace country = "Tanzania" if country == "Tanzania, United Republic of"
replace country = "Timor Leste" if country == "Timor-Leste"
replace country = "United Arab Emirate" if country == "United Arab Emirates"
replace country = "Venezuela" if country == "Venezuela, Bolivarian Republic of"
replace country = "Moldova" if country == "Moldova, Republic of"
replace country = "Russia" if country == "Russian Federation"
replace country = "Micronesia" if country == "Micronesia, Federated States of"
replace country = "Palestine" if country == "Palestine, State of"

tempfile gdelt
save `gdelt'
restore

/* Merging GDELT to MM */
merge 1:1 country date using `gdelt', nogenerate

egen country_id = group(country)
tsset country_id date
tsfill, full	// This command fills the gaps in country-date, to get a balanced panel

bysort country_id (country) : replace country = country[_N] if missing(country)
sort country date

// Renaming the variables to distinguish MM and GDELT
global type_protests "protests peaceful violent"
foreach type in $type_protests {
	rename num_`type' num_`type'_GDELT
	label var num_`type'_GDELT "Number of protests during the day (according to MM)"
	if "`type'"!="protests" label var num_`type'_GDELT "Number of `type' protests during the day (according to GDELT)"
}

// If there is no info of news in a given day, we assume there were none
foreach type in $type_protests {
	replace num_`type'_MM = 0 if num_`type'_MM==.
	replace num_`type'_GDELT = 0 if num_`type'_GDELT==.
}

/* Merge corruption scandal data */
preserve
use "${work}/temp/News/corruption_news", clear
replace country = strtrim(country)
sort country date importance
duplicates drop country date, force

generate scandal = 1

tempfile corruption_news
save `corruption_news'
restore

merge 1:1 country date using `corruption_news', nogenerate

replace scandal = 0 if scandal == .
bys country: egen scandal_country = max(scandal)
keep if scandal_country == 1
keep if year(date) >= 2008 & year(date) <= 2019
drop scandal_country

/* Add extra variables to identify time */
/* Identifying year, month, week, and day */
generate year = year(date)
generate month = month(date)
generate week_calendar = week(date)
generate day = day(date)
generate month_year = string(year) + string(month, "%02.0f")
sort month_year
egen monthyear = group(month_year)

/* Indicators for each value of the categorical variable */
tabulate month, generate(month_)
tabulate day, generate(day_)
tabulate importance, generate(importance_)
replace importance_1 = 0 if importance_1 == .
replace importance_2 = 0 if importance_2 == .
replace importance_3 = 0 if importance_3 == .

/* Interactions */
generate scandal_imp1 = scandal*importance_1
generate scandal_imp2 = scandal*importance_2
generate scandal_imp3 = scandal*importance_3

/* Save data at the daily level */
order country country_id date scandal
save "${datfin}/protests_scandals_balanced.dta", replace

/* Protest occurrence indicators */
generate protest_MM = (num_protests_MM > 0)
generate peaceful_MM = (num_peaceful_MM > 0)
generate violent_MM = (num_violent_MM > 0)
generate protest_GDELT = (num_protests_GDELT > 0)
generate peaceful_GDELT = (num_peaceful_GDELT > 0)
generate violent_GDELT = (num_violent_GDELT > 0)

/* Multi-day scandal indicators: */
// 14 days:
bys country (date): asrol scandal, stat(max) window(date -14 0) generate(post_scandal) min(14)
bys country (date): asrol scandal_imp1, stat(max) window(date -14 0) generate(post_scandal_imp1) min(14)
bys country (date): asrol scandal_imp2, stat(max) window(date -14 0) generate(post_scandal_imp2) min(14)
bys country (date): asrol scandal_imp3, stat(max) window(date -14 0) generate(post_scandal_imp3) min(14)

// 1-7 days:
bys country (date): asrol scandal, stat(max) window(date -7 0) generate(post_scandal1) min(7)
bys country (date): asrol scandal_imp1, stat(max) window(date -7 0) generate(post_scandal1_imp1) min(7)
bys country (date): asrol scandal_imp2, stat(max) window(date -7 0) generate(post_scandal1_imp2) min(7)
bys country (date): asrol scandal_imp3, stat(max) window(date -7 0) generate(post_scandal1_imp3) min(7)

// 7-14 days:
bys country (date): asrol scandal, stat(max) window(date -14 -7) generate(post_scandal2) min(7)
bys country (date): asrol scandal_imp1, stat(max) window(date -14 -7) generate(post_scandal2_imp1) min(7)
bys country (date): asrol scandal_imp2, stat(max) window(date -14 -7) generate(post_scandal2_imp2) min(7)
bys country (date): asrol scandal_imp3, stat(max) window(date -14 -7) generate(post_scandal2_imp3) min(7)

/* Identifying observations within 30 days before/after scandal */
bys country (date): asrol scandal, stat(max) window(date 1 14) generate(pre_scandal) min(14)
egen sample = rowmax(post_scandal pre_scandal) if post_scandal!=. & pre_scandal!=.

/* Sorting this dataset by state and year */
sort country_id date

/* Setting the panel and time variables */
tset country_id date

/* Cloning scandal for day 0 */
clonevar s = scandal
label var s "0"
clonevar s1 = scandal_imp1
label var s1 "0"
clonevar s2 = scandal_imp2
label var s2 "0"
clonevar s3 = scandal_imp3
label var s3 "0"

/* Creating 14-period lags of the indicator variable of scandals */
forval i = 1/14 {
	gen s_lag`i' = L`i'.scandal
	label var s_lag`i' "`i'"
	gen s1_lag`i' = L`i'.scandal_imp1
	label var s1_lag`i' "`i'"
	gen s2_lag`i' = L`i'.scandal_imp2
	label var s2_lag`i' "`i'"
	gen s3_lag`i' = L`i'.scandal_imp3
	label var s3_lag`i' "`i'"
}

/* Creating 14-period leads of the indicator variable of scandals */
gen s_lead1 = 0                /* This is the base/reference category */
label var s_lead1 "-1"
gen s1_lead1 = 0
label var s1_lead1 "-1"
gen s2_lead1 = 0
label var s2_lead1 "-1"
gen s3_lead1 = 0
label var s3_lead1 "-1"

forval i = 2/14 {
	gen s_lead`i' = F`i'.scandal
	label var s_lead`i' "-`i'"
	gen s1_lead`i' = F`i'.scandal_imp1
	label var s1_lead`i' "-`i'"
	gen s2_lead`i' = F`i'.scandal_imp2
	label var s2_lead`i' "-`i'"
	gen s3_lead`i' = F`i'.scandal_imp3
	label var s3_lead`i' "-`i'"
}

sort country date
order country year week_calendar date scandal post_scandal post_scandal1 post_scandal2

save "${datfin}/protests_scandals_balanced_daily.dta", replace

/* Aggregate data at week-level */
use "${datfin}/protests_scandals_balanced.dta", clear

collapse (sum) num_* num_scandals=scandal num_scandals_imp1=scandal_imp1 num_scandals_imp2=scandal_imp2 num_scandals_imp3=scandal_imp3 (firstnm) country_id, by(country year week_calendar)

/* Year-week dummy (to be used as the time variable): */
generate yearweek = year*52 + week_calendar

/* Indicators of scandal existence: */
generate scandal = (num_scandals > 0)
generate scandal_imp1 = (num_scandals_imp1 > 0)
generate scandal_imp2 = (num_scandals_imp2 > 0)
generate scandal_imp3 = (num_scandals_imp3 > 0)

/* Protest indicators */
generate protest_MM = (num_protests_MM > 0)
generate peaceful_MM = (num_peaceful_MM > 0)
generate violent_MM = (num_violent_MM > 0)
generate protest_GDELT = (num_protests_GDELT > 0)
generate peaceful_GDELT = (num_peaceful_GDELT > 0)
generate violent_GDELT = (num_violent_GDELT > 0)

/* Multi-week indicators: */
/* 25 weeks (6 months): */
bysort country (yearweek): asrol scandal, stat(max) window(yearweek -25 0) generate(post_scandal) min(25)
bysort country (yearweek): asrol scandal_imp1, stat(max) window(yearweek -25 0) generate(post_scandal_imp1) min(25)
bysort country (yearweek): asrol scandal_imp2, stat(max) window(yearweek -25 0) generate(post_scandal_imp2) min(25)
bysort country (yearweek): asrol scandal_imp3, stat(max) window(yearweek -25 0) generate(post_scandal_imp3) min(25)

// 1-12 weeks (first 3 months):
bysort country (yearweek): asrol scandal, stat(max) window(yearweek -12 0) generate(post_scandal1) min(12)
bysort country (yearweek): asrol scandal_imp1, stat(max) window(yearweek -12 0) generate(post_scandal1_imp1) min(12)
bysort country (yearweek): asrol scandal_imp2, stat(max) window(yearweek -12 0) generate(post_scandal1_imp2) min(12)
bysort country (yearweek): asrol scandal_imp3, stat(max) window(yearweek -12 0) generate(post_scandal1_imp3) min(12)

// 13-25 weeks (next 3 months):
bysort country (yearweek): asrol scandal, stat(max) window(yearweek -25 -12) generate(post_scandal2) min(13)
bysort country (yearweek): asrol scandal_imp1, stat(max) window(yearweek -25 -12) generate(post_scandal2_imp1) min(13)
bysort country (yearweek): asrol scandal_imp2, stat(max) window(yearweek -25 -12) generate(post_scandal2_imp2) min(13)
bysort country (yearweek): asrol scandal_imp3, stat(max) window(yearweek -25 -12) generate(post_scandal2_imp3) min(13)

/* Save data at the weekly level */
sort country yearweek
order country year week_calendar yearweek scandal post_scandal post_scandal1 post_scandal2
save "${datfin}/protests_scandals_balanced_weekly.dta", replace

/* Aggregate data at the month level */
use "${datfin}/protests_scandals_balanced.dta", clear
collapse (sum) num_* num_scandals=scandal num_scandals_imp1=scandal_imp1 num_scandals_imp2=scandal_imp2 num_scandals_imp3=scandal_imp3 (firstnm) country_id year month, by(country monthyear)

/* Indicators of scandal existence: */
generate scandal = (num_scandals>0)
generate scandal_imp1 = (num_scandals_imp1>0)
generate scandal_imp2 = (num_scandals_imp2>0)
generate scandal_imp3 = (num_scandals_imp3>0)

/* Protest indicators */
generate protest_MM = (num_protests_MM>0)
generate peaceful_MM = (num_peaceful_MM>0)
generate violent_MM = (num_violent_MM>0)
generate protest_GDELT = (num_protests_GDELT>0)
generate peaceful_GDELT = (num_peaceful_GDELT>0)
generate violent_GDELT = (num_violent_GDELT>0)

/* Multi-month indicators: */
// 6 months:
bys country (monthyear): asrol scandal, stat(max) window(monthyear -6 0) gen(post_scandal) min(6)
bys country (monthyear): asrol scandal_imp1, stat(max) window(monthyear -6 0) gen(post_scandal_imp1) min(6)
bys country (monthyear): asrol scandal_imp2, stat(max) window(monthyear -6 0) gen(post_scandal_imp2) min(6)
bys country (monthyear): asrol scandal_imp3, stat(max) window(monthyear -6 0) gen(post_scandal_imp3) min(6)

// First 3 months:
bys country (monthyear): asrol scandal, stat(max) window(monthyear -3 0) gen(post_scandal1) min(3)
bys country (monthyear): asrol scandal_imp1, stat(max) window(monthyear -3 0) gen(post_scandal1_imp1) min(3)
bys country (monthyear): asrol scandal_imp2, stat(max) window(monthyear -3 0) gen(post_scandal1_imp2) min(3)
bys country (monthyear): asrol scandal_imp3, stat(max) window(monthyear -3 0) gen(post_scandal1_imp3) min(3)

// Next 3 months:
bys country (monthyear): asrol scandal, stat(max) window(monthyear -6 -3) gen(post_scandal2) min(3)
bys country (monthyear): asrol scandal_imp1, stat(max) window(monthyear -6 -3) gen(post_scandal2_imp1) min(3)
bys country (monthyear): asrol scandal_imp2, stat(max) window(monthyear -6 -3) gen(post_scandal2_imp2) min(3)
bys country (monthyear): asrol scandal_imp3, stat(max) window(monthyear -6 -3) gen(post_scandal2_imp3) min(3)

/* Identifying observations within 6 months before/after scandal */
bysort country (monthyear): asrol scandal, stat(max) window(monthyear 1 6) gen(pre_scandal) min(6)
egen sample = rowmax(post_scandal pre_scandal) if post_scandal!=. & pre_scandal!=.

/* Sorting this dataset by state and year */
sort country_id monthyear

/* Setting the panel and time variables */
tset country_id monthyear

/* Cloning scandal for month 0 */
clonevar s = scandal
label var s "0"
clonevar s1 = scandal_imp1
label var s1 "0"
clonevar s2 = scandal_imp2
label var s2 "0"
clonevar s3 = scandal_imp3
label var s3 "0"

/* Creating 6-period lags of the indicator variable of scandals */
forval i = 1/6 {
	gen s_lag`i' = L`i'.scandal
	label var s_lag`i' "`i'"
	gen s1_lag`i' = L`i'.scandal_imp1
	label var s1_lag`i' "`i'"
	gen s2_lag`i' = L`i'.scandal_imp2
	label var s2_lag`i' "`i'"
	gen s3_lag`i' = L`i'.scandal_imp3
	label var s3_lag`i' "`i'"
}

/* Creating 6-period leads of the indicator variable of scandals */
gen s_lead1 = 0                /* This is the base/reference category */
label var s_lead1 "-1"
gen s1_lead1 = 0
label var s1_lead1 "-1"
gen s2_lead1 = 0
label var s2_lead1 "-1"
gen s3_lead1 = 0
label var s3_lead1 "-1"

forval i = 2/6 {
	gen s_lead`i' = F`i'.scandal
	label var s_lead`i' "-`i'"
	gen s1_lead`i' = F`i'.scandal_imp1
	label var s1_lead`i' "-`i'"
	gen s2_lead`i' = F`i'.scandal_imp2
	label var s2_lead`i' "-`i'"
	gen s3_lead`i' = F`i'.scandal_imp3
	label var s3_lead`i' "-`i'"
}

/* Save monthly data */
sort country monthyear
order country year month monthyear scandal post_scandal post_scandal1 post_scandal2

save "${datfin}/protests_scandals_balanced_monthly.dta", replace
