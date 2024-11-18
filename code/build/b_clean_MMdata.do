/* ----------------------------------------------------------------------------
						Corruption and Protests
					
	Author: Diego Tocre
	Modifications: Roberto Gonzalez
	Date: November 18, 2024
	
	Objective: Clean MM datasets
---------------------------------------------------------------------------- */

/* ----------------------------------------------------------------------------
								World Bank data
---------------------------------------------------------------------------- */
/* Read in dataset with World Bank regions and country codes */
import excel using "${src}/Protests/CLASS.xlsx", clear firstrow case(lower)
/* Rename region and code variables to specify the source */
rename (code region) (countrycode region_wb)
save "${work}/temp/wb_regions.dta", replace

/* ----------------------------------------------------------------------------
								GDELT data
---------------------------------------------------------------------------- */
/* Read in dataset with FIPS 10-4 and alpha3 country codes */
import excel "${src}/Protests/GDELT/country_codes.xlsx", clear firstrow sheet("Match") case(lower)
rename (countryname) (country)
/* Clean country names to homogenize */
replace country = "Bolivia" if strpos(country, "Bolivia") > 0
replace country = "Bosnia" if strpos(country, "Bosnia") > 0
replace country = "Congo Kinshasa" if strpos(country, "Congo, the Democratic Republic of the") > 0
replace country = "Congo Brazzaville" if country == "Congo"
replace country = "Czech Republic" if strpos(country, "Czechia") > 0
replace country = "Iran" if strpos(country, "Iran") > 0
replace country = "Ivory Coast" if isoalpha3 == "CIV"
replace country = "Macedonia" if strpos(country, "Macedonia") > 0
replace country = "Moldova" if strpos(country, "Moldova") > 0
replace country = "North Korea" if isoalpha3 == "PRK"
replace country = "Russia" if strpos(country, "Russia") > 0
replace country = "Slovak Republic" if strpos(country, "Slovakia") > 0
replace country = "South Korea" if strpos(country, "Korea, Republic of") > 0
replace country = "Syria" if strpos(country, "Syrian Arab Republic") > 0
replace country = "Tanzania" if strpos(country, "Tanzania") > 0
replace country = "Timor Leste" if strpos(country, "Timor-Leste") > 0
replace country = "Venezuela" if strpos(country, "Venezuela") > 0
replace country = "Vietnam" if strpos(country, "Viet Nam") > 0
replace country = "Cape Verde" if strpos(country, "Cabo Verde") > 0
replace country = "Laos" if strpos(country, "Lao People") > 0
replace country = "United Arab Emirate" if strpos(country, "United Arab Emirates") > 0
/* Save temporary file for merging */
tempfile codes
save `codes', replace

/* ----------------------------------------------------------------------------
								Protests Data
---------------------------------------------------------------------------- */
/* Read in dataset */
import delimited "${src}/Protests/MM/MMraw.csv", clear 
/* Keep observations associated to protests */
keep if (protest == 1)
/* Sort information by country, protest start year-month-day */
sort country startyear startmonth startday

/* Create a date variable */
generate startdate = mdy(startmonth, startday, startyear)
format startdate %td
generate enddate = mdy(endmonth, endday, endyear)
format enddate %td
generate numdays = (enddate - startdate + 1) // number of days the protest lasted
tabulate numdays 

/* Clean the number of participants and create groups of participants */
replace participants = subinstr(participants, ",", "", .)
replace participants_category = "50-99" if inlist(participants, "10s", "50+", ">50", ">50-100s", "50s")
replace participants_category = "100-999" if inlist(participants, "100+", "100S", "100s", "100s-10000", "100s-10000s", "100s-1000s") | ///
	inlist(participants, "300s", ">100", ">200", ">300", "100s-1000", "300-1000s")
replace participants_category = "1000-1999" if inlist(participants, "1000-10000", "1000s", "1000s-10000", "1000s-10000s", "1000s-40000") | ///
	inlist(participants, "1500-10000", "<2000", "1000+", "1100-10000s")
replace participants_category = "2000-4999" if inlist(participants, "2000-200000", ">2000", ">4000")
replace participants_category = "5000-10000" if inlist(participants, "5000+", "5000-50000", "6000+", ">5000")
replace participants_category = ">10000" if inlist(participants, "100,000s", "100000+", "1000000s", "100000s", "10000s", "10000s ") | ///
	inlist(participants, "20000s", "51000+", "75000-170000", ">10000", ">100000", ">1000000") | ///
	inlist(participants, ">15000", ">150000", ">30000", ">50000", "Between 11000 and 45000", "10000+") | ///
	inlist(participants, "1000000s", "23000+")
	
/* Generate variable with the simple average of protesters within each category defined above */
generate numprotesters = participants
destring numprotesters, force replace
replace numprotesters = 75 if (numprotesters == . & participants_category == "50-99")
replace numprotesters = 550 if (numprotesters == . & participants_category == "100-999")
replace numprotesters = 1500 if (numprotesters == . & participants_category == "1000-1999")
replace numprotesters = 3500 if (numprotesters == . & participants_category == "2000-4999")
replace numprotesters = 7500 if (numprotesters == . & participants_category == "5000-10000")
replace numprotesters = 15000 if (numprotesters == . & participants_category == ">10000")
destring participants, force generate(exact_number)
replace exact_number = (exact_number != .) // Dummy for whether we have the exact number of protesters or an estimate

/* Impute values for participants if there are missing values in protester category */
replace participants_category = "50-99" if numprotesters <= 99
replace participants_category = "100-999" if numprotesters >= 100 & numprotesters <= 999
replace participants_category = "1000-1999" if numprotesters >= 1000 & numprotesters <= 1999
replace participants_category = "2000-4999" if numprotesters >= 2000 & numprotesters <= 4999
replace participants_category = "5000-10000" if numprotesters >= 5000 & numprotesters <= 10000
replace participants_category = ">10000" if numprotesters > 10000 & numprotesters != .

/* Create an additional way of aggregating number of protesters */
generate participants_category2 = participants_category
replace participants_category2 = "1000-9999" if numprotesters >= 1000 & numprotesters <= 9999
replace participants_category2 = ">=10000" if numprotesters >= 10000 & numprotesters != .

/* Create indicator for latin american countries */
generate lac = (inlist(region, "North America", "Central America", "South America"))
replace lac = 0 if country == "Canada"
label variable lac "Latin America and the Caribbean"

generate selected = (inlist(country, "Argentina", "Bolivia", "Brazil", "Guatemala", "Honduras", "El Salvador", "Chile") | ///
	inlist(country, "Nicaragua", "Costa Rica", "Panama", "Colombia", "Dominican Republic", "Venezuela", "Ecuador") | ///
	inlist(country, "Peru", "Mexico", "Paraguay", "Uruguay"))
	
/* Create globals for state response indicators */
global responses "accomodation arrests beatings dispersal ignore killings shootings"
global res_texts `" "accomodation" "arrests" "beatings" "crowd dispersal" "ignore" "killings" "shootings" "'

local j = 1
foreach rrr in $responses {
	local text: word `j' of ${res_texts}
	generate response_`rrr' = (stateresponse1 == "`text'")
	forvalues i = 2/7 {
		replace response_`rrr' = 1 if stateresponse`i' == "`text'"
	}
	local j = `j' + 1
}

* Success dummy:
gen success = (response_accomodation==1)

* Protester demands dummies:
global demands "wages land police politics prices politician restrictions"
global dem_texts `" "labor wage dispute" "land farm issue" "police brutality" "political behavior, process" "price increases, tax policy" "removal of politician" "social restrictions" "'

local j = 1
foreach d in $demands {
	local text: word `j' of $dem_texts
	gen demand_`d' = (protesterdemand1=="`text'")
	forval i = 2/4 {
		replace demand_`d' = 1 if protesterdemand`i'=="`text'"
	}
	label var demand_`d' "Demand: `text'"
	local j = `j' + 1
}

/* Create variables for whether protests are peaceful or violent */
generate peaceful_protest = (protesterviolence == 0)
generate violent_protest = (protesterviolence == 1)
generate violence_against_peacefulprot = (protesterviolence == 0 & (response_beatings == 1 | response_killings == 1 | response_shootings == 1))

/* Categories for number of protesters */
// tabulate participants_category2, generate(numprotesters)
generate numprotesters1 = (participants_category2 == "50-99")
generate numprotesters2 = (participants_category2 == "100-999")
generate numprotesters3 = (participants_category2 == "1000-9999")
generate numprotesters4 = (participants_category2 == ">=10000")

generate violent_50_99 = violent_protest*numprotesters1
generate violent_100_999 = violent_protest*numprotesters2
generate violent_1000_9999 = violent_protest*numprotesters3
generate violent_10000 = violent_protest*numprotesters4

local scale = 10000
replace numprotesters = numprotesters/`scale' // For coefficients to be readable from table
generate numprotesters_sq = numprotesters*numprotesters
generate violent_number = violent_protest*numprotesters
generate violent_number_sq = violent_protest*numprotesters_sq

/* We standardize the names of some countries over time */
gen country2 = country
replace country = "Germany" if country == "Germany East" | country == "Germany West"
replace country = "Serbia" if country == "Serbia and Montenegro"
replace country = "Russia" if country == "USSR"
replace country = "Czech Republic" if country == "Czechoslovakia"
replace country = "Serbia" if country == "Yugoslavia"

/* Create country encoded id's for regression FE's */
egen country_id = group(country)

/* Categories for protest duration */
generate duration_1 = (numdays == 1)
generate duration_2 = (numdays > 1 & numdays <= 7)
generate duration_3 = (numdays > 7 & numdays <= 30)
generate duration_4 = (numdays > 31 & numdays != .)

/* ----------------------------------------------------------------------------
			Add world bank region, country code and capital
---------------------------------------------------------------------------- */
/* Codes and WB regions */
merge m:1 country using `codes', keep(1 3) nogen keepusing(isoalpha3) // All from master merge (except Kosovo)
rename (isoalpha3) (countrycode)
replace countrycode = "XKX" if country == "Kosovo"
merge m:1 countrycode using "${work}/temp/wb_regions.dta", keep(3) nogenerate keepusing(region_wb) // All from master merge

/* Capitals and coordinates */
preserve
	import delimited "${src}/Protests/country-capitals.csv", clear case(lower)
	rename (countryname capitalname capitallatitude capitallongitude countrycode) (country capital capital_lat capital_long countrycode2)
	replace country = "Bosnia" if strpos(country, "Bosnia") > 0
	replace country = "Congo Kinshasa" if strpos(country, "Democratic Republic of the Congo") > 0
	replace country = "Congo Brazzaville" if country == "Republic of Congo"
	replace country = "Gambia" if strpos(country, "The Gambia") > 0
	replace country = "Ivory Coast" if strpos(country, "Cote d'Ivoire") > 0
	replace country = "Slovak Republic" if strpos(country, "Slovakia") > 0
	replace country = "Timor Leste" if strpos(country, "Timor-Leste") > 0
	replace country = "United Arab Emirate" if strpos(country, "United Arab Emirates") > 0
	tempfile capitals
	save `capitals', replace
restore
merge m:1 country using `capitals', keep(3) nogen // All from master merge

/* Indicator if event takes place in capital */
replace capital = "Kiev" if capital == "Kyiv"
generate event_capital = (strpos(strlower(location), strlower(capital)) > 0)
replace event_capital = 1 if (strpos(strlower(location), "national") > 0 | strpos(strlower(location), "nation wide") > 0 | ///
	strpos(strlower(location), "nationwide") > 0 | strpos(strlower(location), "natoinwide") > 0 | ///
	strpos(strlower(location), "natonal") > 0 | strpos(strlower(location), "naitonwide") > 0)
replace event_capital = 1 if country == "Kazakhstan" & (strpos(strlower(location), "akmolinsk") > 0 | ///
	strpos(strlower(location), "tselinograd") > 0 | strpos(strlower(location), "nur sultan") > 0  | strpos(strlower(location), "nur-sultan") > 0)
replace event_capital = 1 if country == "Mongolia" & (strpos(strlower(location), "ulan bator") > 0)
replace event_capital = 1 if country == "Myanmar" & (strpos(strlower(location), "yangon") > 0)
replace event_capital = 1 if country == "Chad" & (strpos(strlower(location), "djamena") > 0)
// We could still look for more mismatching capitals
// Already taken care of the most suspicious cases

// We may want to replace as missing the capital variable's values of the observations
// for which the country name equals the event location exactly (no info of city)
replace event_capital = . if (country == location & country != capital) | (location == "undefined" | location == "unspecified")

/* ----------------------------------------------------------------------------
								Label variables
---------------------------------------------------------------------------- */
label variable peaceful_protest "Peaceful protest"
label variable violent_protest "Violent protest"
label variable violence_against_peacefulprot "Violence against peaceful protest"
label variable success "Successful protest"
label variable numprotesters "Number of protesters/`scale'"
label variable numprotesters1 "Number of protesters: 50-99"
label variable numprotesters2 "Number of protesters: 100-999"
label variable numprotesters3 "Number of protesters: 1000-9999"
label variable numprotesters4 "Number of protesters: >=10000"
label variable violent_50_99 "Violent*50-99 protesters"
label variable violent_100_999 "Violent*100-999 protesters"
label variable violent_1000_9999 "Violent*1000-9999 protesters"
label variable violent_10000 "Violent*>=10000 protesters"
label variable event_capital "Protest took place in the capital"
label variable duration_1 "Protest lasted 1 day"
label variable duration_2 "Protest lasted between 2 and 7 days"
label variable duration_3 "Protest lasted between 8 and 30 days"
label variable duration_4 "Protest lasted more than 30 days"
label variable numprotesters_sq "(Number of protesters/`scale')$^2$"
label variable violent_number "Violent*(Number of protesters/`scale')"
label variable violent_number_sq "Violent*(Number of protesters/`scale')$^2$"
label variable exact_number "Exact number of protesters"

capture mkdir "${work}/temp/MM"
save "${work}/temp/MM/MMclean_event.dta", replace

/* Create one row per each day of duration of a given protest */
/* i.e. if a protest lasts X days there will be X rows of it */
generate date = startdate
expand numdays
bysort id : replace date = date + _n - 1
format date %td
drop startdate enddate

generate month = month(date)
drop year
generate year = year(date)

/* Save full data */
save "${work}/temp//MM/MMclean_full", replace

preserve
	collapse (sum) num_protests=protest num_peaceful=peaceful_protest num_violent=violent_protest, by(country date)
	save "${work}/temp/MM/MMclean_full_bydate", replace
restore
