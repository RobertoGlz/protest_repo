/* ----------------------------------------------------------------------------
							Corruption and Protests
							
	Code author: Roberto González
	Date: December 14, 2024
	
	Objective: Try to predict:
		- Depreciation events
		- Football losses
---------------------------------------------------------------------------- */

/* ---------------------------- Root paths --------------------------------- */
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox/"
}

/* Creating Global File Paths */
global path "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
gl dof 		"${path}/Dofiles"
gl datraw 	"${path}/Data/raw"
gl datfin 	"${path}/Data/final"
gl datwrk 	"${path}/Data/working"
gl datold 	"${path}/Data/archive"
gl datpub 	"${path}/Data/publication"
gl output 	"${path}/Output"
gl violent  "$output/Violent"
gl mid 		"$violent/mid"
gl logs 	"${path}/Logs"
gl graphs 	"${output}/Graphs"
gl tables 	"${output}/Tables"
gl overleaf	"${identity}/Apps/Overleaf"
local date: dis %td_NN_DD_CCYY date(c(current_date), "DMY")
gl date_string = subinstr(trim("`date'"), " " , "_", .)

/* Read in depreciation events dataset */
use "${datfin}/protests_scandals_30days_football_v3", clear
/* Drop observations from Venezuela */
drop if (country == "Venezuela")

generate scandal = (window == 0)

egen group_year_country = group(country year)

generate dias_mes = day(date)

/* Logit prediction by day of the week and Year x Country */
logit scandal i.day i.group_year_country, vce(cluster group_year_country)

lroc, nograph
tempname aux4
scalar `aux4'=`r(area)'	
	
/* OLS prediction */	
eststo m1 : reghdfe scandal  i.day, absorb(group_year_country)  vce(cluster group_year_country) 

	summarize scandal, detail 	 
	estadd scalar aux = `r(mean)'
	
	predict y
	summarize scandal, d 
	generate prediction = (y > r(p50))
	generate accuracy = (prediction == scandal)
	summarize accuracy	 
	estadd scalar aux2=`r(mean)'

	testparm i.day
	estadd scalar aux3=`r(p)'
	
	estadd scalar aux4=`aux4'
	estadd local cyfe "Yes"
	estadd local dayw "Yes"	
	estadd local month "No"	
	estadd local daym "No"
	estadd local close "No"

drop y prediction accuracy

*Day and Month 
logit scandal i.day i.month i.group_year_country, vce(cluster group_year_country)

	lroc, nograph
	tempname aux4
	scalar `aux4'=`r(area)'
	
reghdfe scandal i.day i.month, absorb(group_year_country)  vce(cluster group_year_country)
eststo m2

	sum scandal, d
	estadd scalar aux=`r(mean)'
	
	predict y
	sum scandal, d 
	gen prediction = (y > r(p50))
	gen accuracy=(prediction==scandal)
	sum accuracy
	estadd scalar aux2=`r(mean)'

	testparm i.day i.month	
	estadd scalar aux3=`r(p)'
	
	estadd scalar aux4=`aux4'
	estadd local cyfe "Yes"
	estadd local dayw "Yes"	
	estadd local month "Yes"	
	estadd local daym "No"
	estadd local close "No"

drop y prediction accuracy

*Full dates
logit scandal i.day i.month i.dias_mes i.group_year_country, vce(cluster group_year_country)

	lroc, nograph
	tempname aux4
	scalar `aux4'=`r(area)'
	
reghdfe scandal i.day i.month i.dias_mes, absorb(group_year_country) vce(cluster group_year_country)
eststo m3

	sum scandal, d 	 
	estadd scalar aux=`r(mean)'
	
	predict y
	sum scandal, d
	gen prediction=(y>r(p50))
	gen accuracy=(prediction==scandal)
	sum accuracy
	estadd scalar aux2=`r(mean)'

	testparm i.day i.month i.dias_mes
	estadd scalar aux3=`r(p)'
	
	estadd scalar aux4=`aux4'
	estadd local cyfe "Yes"
	estadd local dayw "Yes"	
	estadd local month "Yes"	
	estadd local daym "Yes"
	estadd local close "No"

drop y prediction accuracy

/*
*Full 
probit scandal i.day i.month i.dias_mes i.group_year_country i.close_election, vce(cluster group_year_country)

	lroc, nograph
	tempname aux4
	scalar `aux4'=`r(area)'	

reghdfe scandal i.day i.month i.dias_mes i.close_election, absorb(group_year_country) vce(cluster group_year_country)
eststo m4

	sum scandal, d 
	estadd scalar aux=`r(mean)'
	
	predict y
	sum scandal, d 
	gen prediction=(y>r(p50))
	gen accuracy=(prediction==scandal)
	sum accuracy
	estadd scalar aux2=`r(mean)'

	testparm i.day i.month i.dias_mes	
	estadd scalar aux3=`r(p) '
	
	estadd scalar aux4=`aux4'
	estadd local cyfe "Yes"
	estadd local dayw "Yes"	
	estadd local month "Yes"	
	estadd local daym "Yes"
	estadd local close "Yes"

drop y prediction accuracy
*/

esttab m1 m2 m3 using "${tables}/Protests/Summary/football_losses_as_random.tex", b(3) se(3) stats(aux r2 r2_a aux2 aux3 cyfe dayw month daym close, labels("Mean dep. var" "R-squared" "R-squared adj." "Accuracy" "F-test" "Country x Year FE" "Day of week" "Month" "Day of the Month" "Close to Election")) star(* 0.10 ** 0.05 *** 0.01) substitute("\_" "_") keep(_cons) drop(_cons) noobs nonotes booktabs replace ///
mtitles("1(Match Loss)" "1(Match Loss)" "1(Match Loss)")

*esttab m1 m2 m3 m4 using "${overleaf}/tables_estout/rct/corruption_index.tex", title("Decomposing effect on Corruption Perceptions\label{index_corruption}") mtitle("\shortstack{Corruption\\Index}" "\shortstack{Process Fighting\\Corruption (1-4)}" "\shortstack{Share of Corrupt\\Pol. (0-100)}" "\shortstack{Share of Taxes Stolen\\by Pol (0-100)}") b(3) se(3) stats(N r2 cxy aux pval1 pval2 pval3 pval4 pval5 pval6, labels("Observations" "R-squared" "Mun. and Enum. FE" "Mean dep. var" "CI = CO" "CI = SC" "CI = E" "CO = SC" "CO = E" "SC = E")) varlabels(1.treat2 "Corruption Incumbent (CI)" 2.treat2 "Corruption Opposition (CO)" 3.treat2 "Social Cohesion (SC)" 4.treat2 "Economic (E)") keep(1.treat2 2.treat2 3.treat2 4.treat2) star(* 0.10 ** 0.05 *** 0.01) substitute("\_" "_") noobs nonotes booktabs replace

/* ----------------------------------------------------------------------------
				Scandals as Random - Predict out of sample
---------------------------------------------------------------------------- */
/* Read in depreciation events dataset */
use "${datfin}/protests_scandals_30days_football_v3", clear
/* Drop observations from Venezuela */
drop if (country == "Venezuela")

keep if (window == 0)

keep date country 

egen country_group = group(country)

generate scandal = 1

*Declared panel data
sort country_group date
xtset country_group date

tsfill, full

replace scandal = 0 if scandal == .

gen year = year(date)
label var year "Year"
gen month = month(date)
label var month "Month"
gen day = dow(date)
label var day "Day of the week (0=Sunday)"
gen dias_mes = day(date)
egen group_year_country=group(year country_group)

merge m:1 country_group year using "${datwrk}/election_dates_for_merge"

drop if _merge==2

keep if (2009 <= year & year <= 2019)

gen distancia_eleccion=date_election-date

gen close_election=0

replace close_election=1 if distancia_eleccion<=30 & distancia_eleccion>=0

replace close_election=2 if distancia_eleccion<=60 & distancia_eleccion>=31

replace close_election=3 if distancia_eleccion<=90 & distancia_eleccion>=61

replace close_election=4 if distancia_eleccion<=120 & distancia_eleccion>=91

// Get a sample of half the data points
set seed 20241217
set sortseed 20241217

cap drop country_year
egen country_year = group(country_group year)

gen randomsamp = runiform(0,1)
gen insamp = (randomsamp >= 0.5)
drop randomsamp

est clear

// Estimate logit model
logit scandal i.day i.country_group i.year if insamp == 1, vce(cluster country_year)
eststo m1

lroc if insamp == 0, nograph
estadd scalar aux4 = `r(area)'

predict y 

sum scandal, d 	 
estadd scalar aux=`r(mean)'

sum scandal, d 
gen prediction = .
replace prediction = 0 if y < r(p50) & insamp == 0 & !missing(y)
replace prediction = 1 if y >= r(p50) & insamp == 0 & !missing(y)
gen accuracy=(prediction==scandal) if !missing(prediction)
sum accuracy	 
estadd scalar aux2=`r(mean)'

testparm i.day
estadd scalar aux3=`r(p)'

estadd local countryfe "Yes"
estadd local yearfe  "Yes"
estadd local dayw "Yes"	
estadd local month "No"	
estadd local daym "No"
estadd local close "No"

drop y prediction accuracy

// Day and Month 	
logit scandal i.day i.month i.country_group i.year if insamp == 1, vce(cluster country_year)
eststo m2

lroc if insamp == 0, nograph
estadd scalar aux4 = `r(area)'

predict y 

sum scandal, d 	 
estadd scalar aux=`r(mean)'

sum scandal, d 
gen prediction = .
replace prediction = 0 if y < r(p50) & insamp == 0 & !missing(y)
replace prediction = 1 if y >= r(p50) & insamp == 0 & !missing(y)
gen accuracy=(prediction==scandal) if !missing(prediction)
sum accuracy	 
estadd scalar aux2=`r(mean)'

testparm i.day i.month	
estadd scalar aux3=`r(p)'

estadd local countryfe "Yes"
estadd local yearfe "Yes"
estadd local dayw "Yes"	
estadd local month "Yes"	
estadd local daym "No"
estadd local close "No"

drop y prediction accuracy

// Full dates
logit scandal i.day i.month i.dias_mes i.country_group i.year if insamp == 1, vce(cluster country_year)
eststo m3

lroc if insamp == 0, nograph
estadd scalar aux4 = `r(area)'

predict y 

sum scandal, d 	 
estadd scalar aux=`r(mean)'

sum scandal, d 
gen prediction = .
replace prediction = 0 if y < r(p50) & insamp == 0 & !missing(y)
replace prediction = 1 if y >= r(p50) & insamp == 0 & !missing(y)
gen accuracy=(prediction==scandal) if !missing(prediction)
sum accuracy	 
estadd scalar aux2=`r(mean)'

testparm i.day i.month i.dias_mes
estadd scalar aux3=`r(p)'

estadd local countryfe "Yes"
estadd local yearfe "Yes"
estadd local dayw "Yes"	
estadd local month "Yes"	
estadd local daym "Yes"
estadd local close "No"

drop y prediction accuracy

// Full 
logit scandal i.day i.month i.dias_mes i.close_election i.country_group i.year if insamp == 1, vce(cluster country_year)
eststo m4

lroc if insamp == 0, nograph
estadd scalar aux4 = `r(area)'

predict y 

sum scandal, d 	 
estadd scalar aux=`r(mean)'

sum scandal, d 
gen prediction = .
replace prediction = 0 if y < r(p50) & insamp == 0 & !missing(y)
replace prediction = 1 if y >= r(p50) & insamp == 0 & !missing(y)
gen accuracy=(prediction==scandal) if !missing(prediction)
sum accuracy	 
estadd scalar aux2=`r(mean)'

testparm i.day i.month i.dias_mes i.close_election
estadd scalar aux3=`r(p) '

estadd local countryfe "Yes"
estadd local yearfe "Yes"
estadd local dayw "Yes"	
estadd local month "Yes"	
estadd local daym "Yes"
estadd local close "Yes"
	
drop y prediction accuracy

esttab m1 m2 m3 m4 using "${tables}/Protests/Summary/football_losses_as_random_outsample.tex", ///
	b(3) se(3) stats(aux aux2 aux3 aux4 countryfe yearfe dayw month daym close, ///
	labels("Mean dep. var" "Accuracy (Out of sample)" "F-test p-value (In sample)" ///
	"AUC (Out of sample)" "Country FE" "Year FE" "Day of week" "Month" ///
	"Day of the Month" "Close to Election")) ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	substitute("\_" "_") keep(_cons) drop(_cons) noobs nonotes booktabs replace ///
	mtitles("1(Match Loss)" "1(Match Loss)" "1(Match Loss)" "1(Match Loss)")