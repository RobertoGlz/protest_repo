/* ----------------------------------------------------------------------------
						Corruption and Protests
					
	Author: Diego Tocre
	Modifications: Roberto Gonzalez
	Date: November 18, 2024
	
	Objective: Clean GDELT datasets
---------------------------------------------------------------------------- */

/* Save country codes (fips 10-4 and alpha3) */
import excel "${src}/Protests/GDELT/country_codes.xlsx", clear firstrow sheet("Match") case(lower)
rename (isoalpha3) (actor1countrycode)
tempfile codes
save `codes'

/* Save continent codes */
import excel "${src}/Protests/GDELT/continent_codes.xlsx", clear firstrow case(lower)
rename (a3) (actor1countrycode)
tempfile continents
save `continents'

/* Open GDELT raw data */
import delimited "${src}/Protests/GDELT/gdelt_v1_raw.csv", clear case(lower)
keep if inlist(actiongeo_type, 1, 4, 5)
tempfile gdelt1
save `gdelt1'

import delimited "${src}/Protests/GDELT/gdelt_v2_raw.csv", clear case(lower)
keep if inlist(actiongeo_type, 1, 4, 5)

append using `gdelt1'

replace actor1countrycode = "TLS" if (actor1countrycode == "TMP") // for East Timor
merge m:1 actor1countrycode using `codes', keep(3) nogenerate // Non-matches are orgs such as, e.g., NATO (about 4300 of 490000 obs)

/* Keep only the events that occur within the country */ 
keep if inlist(fips104, actor1geo_countrycode, actor2geo_countrycode, actiongeo_countrycode)

/* Drop dulicates in terms of the events */
duplicates drop globaleventid, force

/* ----------------------------------------------------------------------------
								Create variables
---------------------------------------------------------------------------- */
/* Add the contintent information */
merge m:1 actor1countrycode using `continents', keepusing(cc) keep(1 3) nogenerate
generate continent = "Africa" if cc == "AF"
replace continent = "Asia" if cc == "AS"
replace continent = "Europe" if cc == "EU"
replace continent = "North America" if cc == "NA"
replace continent = "Oceania" if cc == "OC"
replace continent = "South America" if cc == "SA"

/* Add world bank regions */
rename (continent) (region)
generate countrycode = actor1countrycode
merge m:1 countrycode using "${work}/temp/wb_regions.dta", keep(1 3) nogenerate keepusing(region_wb)
/* Vatican, Cook Islands and Anguilla do not match so assign by hand */
replace region_wb = "Europe & Central Asia" if countrycode == "VAT"
replace region_wb = "East Asia & Pacific" if countrycode == "COK"
replace region_wb = "Latin America & Caribbean" if countrycode == "AIA"

/* Indicator for whether we have news data for this country */
generate selected = (inlist(countryname, "Argentina", "Bolivia, Plurinational State Of", "Brazil", "Guatemala", "Honduras", "El Salvador") | ///
	inlist(countryname, "Chile", "Nicaragua", "Costa Rica", "Panama", "Colombia", "Dominican Republic") | ///
	inlist(countryname, "Venezuela, Bolivarian Republic of", "Ecuador", "Peru", "Mexico", "Paraguay", "Uruguay"))
	
/* Create a date variable */
tostring sqldate, generate(sqldate2)
generate day = substr(sqldate2, 7, 2)
generate month = substr(sqldate2, 5, 2)
destring day month, replace
generate date = mdy(month, day, year)
format date %td

/* Indicators for peaceful or violent protests */
generate peaceful_protest = (eventbasecode != 145)
generate violent_protest = (eventbasecode == 145)

/* Indicator for other types of protests */
generate rally_protest = (eventbasecode == 141)
generate hunger_protest = (eventbasecode == 142)
generate boycott_protest = (eventbasecode == 143)
generate blocking_protest = (eventbasecode == 144)
generate economic_damage_protest = (inlist(eventbasecode, 141, 143, 144))
generate protest_v2 = (eventbasecode > 140)

/* Add capitals and coordinates */
preserve
	import delimited "${src}/Protests/country-capitals.csv", clear case(lower)
	rename (countryname capitalname capitallatitude capitallongitude countrycode) ///
		(country capital capital_lat capital_long iso31661)
	drop if iso31661 == "NULL"
	tempfile capitals
	save `capitals'
restore
merge m:1 iso31661 using `capitals', keep(3) nogenerate // All from master merged

/* Compute distance to capital */
geodist actiongeo_lat actiongeo_long capital_lat capital_long, generate(dist_capital)

/* Indicator if event took place in the capital */
generate event_capital = (strpos(strlower(actiongeo_fullname), strlower(capital)) > 0)
replace event_capital = 1 if strpos(strlower(actiongeo_fullname), "national") > 0 | ///
	strpos(strlower(actiongeo_fullname), "nation wide") > 0 | strpos(strlower(actiongeo_fullname), "nationwide") > 0 | ///
	strpos(strlower(actiongeo_fullname), "natoinwide") > 0 | strpos(strlower(actiongeo_fullname), "natonal") > 0
replace event_capital = 1 if country == "Myanmar" & (strpos(strlower(actiongeo_fullname), "yangon") > 0)
replace event_capital = 1 if country == "Chad" & (strpos(strlower(actiongeo_fullname), "djamena") > 0)
replace event_capital = 1 if country == "India" & (strpos(strlower(actiongeo_fullname), "delhi") > 0)

// We could still look for more mismatching capitals
// Already taken care of the most suspicious cases

// United States is a special case; there is no variation in the location name
// We may want to replace as missing the capital variables' values of the observations
// for which the country name equals the event location exactly (no info of city)
replace event_capital = . if country == actiongeo_fullname & country != capital
replace dist_capital = . if country == actiongeo_fullname & country != capital

/* Save protests data */
capture mkdir "${work}/temp/GDELT"
save "${work}/temp/GDELT/GDELT_protests.dta", replace

preserve
	generate protest = 1
	collapse (sum) num_protests=protest num_peaceful=peaceful_protest num_violent=violent_protest num_rally=rally_protest ///
		num_hunger=hunger_protest num_boycott=boycott_protest num_blocking=blocking_protest ///
		num_economic_damage=economic_damage_protest num_protest_v2=protest_v2, by(country date)
	save "${work}/temp/GDELT/GDELT_protests_bydate", replace
restore