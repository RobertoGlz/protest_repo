/* ----------------------------------------------------------------------------
						Corruption and Protests
					
	Author: Diego Tocre
	Modifications: Roberto Gonzalez
	Date: November 18, 2024
	
	Objective: Clean corruption scandals data
---------------------------------------------------------------------------- */

/* Read in data with scandals and keep the important (top-top-level) ones */
import excel "${src}/News/Appended_News.xlsx", clear sheet("3. Append") firstrow case(lower)

rename (startdatenews peakdategoogletrends reviseddatepaco) (date_first date_peak date_revised)

replace country = "Venezuela" if country == "Venezuela "

/* ----------------------------------------------------------------------------
							Create id variables 
---------------------------------------------------------------------------- */
/* Main date variable prioritizing peak date according to Google Trends */
generate date = date_peak
replace date = date_revised if date == .
replace date = date_first if date == .
label variable date "Date (prioritizing Google Trends' peak)"
format date %td

/* Secondary date prioritizing first news date according to LexisNexis */
generate date2 = date_first
replace date2 = date_revised if date2 == .
replace date2 = date_peak if date2 == .
label variable date2 "Date (prioritizing LexisNexis' first news)"
format date2 %td

/* Save dataset */
keep if lastcheck == 1

keep id country date date2 importance
order id country date date2 importance

label variable id "Scandal ID"
summarize id, detail
local max_id = r(max)

capture mkdir "${work}/temp/News"
save "${work}/temp/News/corruption_news.dta", replace

/* ----------------------------------------------------------------------------
				Identify 51 events that interesct Latinobarometro
---------------------------------------------------------------------------- */
import excel "${main}/Latinobarometro/Excel/escandalos_finales.xls", clear firstrow case(lower)

rename (pais fecha_escandalo) (country date)
replace country = "Argentina" if country == "ARG"
replace country = "Bolivia" if country == "BOL"
replace country = "Brazil" if country == "BRA"
replace country = "Chile" if country == "CHI"
replace country = "Colombia" if country == "COL"
replace country = "Costa Rica" if country == "COS"
replace country = "Ecuador" if country == "ECU"
replace country = "Guatemala" if country == "GUA"
replace country = "Mexico" if country == "MEX"
replace country = "Nicaragua" if country == "NIC"
replace country = "Panama" if country == "PAN"
replace country = "Paraguay" if country == "PAR"
replace country = "Peru" if country == "PER"
replace country = "Dominican Republic" if country == "REP"
replace country = "El Salvador" if country == "SAL"
replace country = "Venezuela" if country == "VEN"

keep country date
format date %td
sort country date
generate id = _n + `max_id'
label variable id "Scandal ID"
order id country date

save "${work}/temp/News/corruption_news_LB.dta", replace
