/* ----------------------------------------------------------------------------
					Corruption Scandals and Protests
					
	Code author: Roberto Gonzalez
	Date: December 13, 2024
	
	Objective: Produce table with 3 panels
		- Corruption scandal on outcomes
		- Depreciation on outcomes
		- Football match loss on outcomes
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

/*
In this version we use 3 pre-months and 3 post months ; we allow for overlap 
and we include (a) Country x Year or (b) Scandal fixed effects
*/

/* Create globals with fixed effects */
global cy_fe "i.country_id#i.year"
global scandal_fe "i.id_group"

/* --------------------------- Corruption Effects -------------------------- */
/* Read in dataset */
use "${datfin}/protests_scandals_30days_v3", clear
/* Drop observations from Venezuela */
drop if (country == "Venezuela")

/* Create categorical variable for groups of days */
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lead30 s_lead60 s_lead90)
/* Create categorical variable for Country x Year x DaysGroup */
egen group_cluster = group(country_id year grupo_dias)

/* Create global with cluster spec for se's */
global cydays = "cluster i.country_id#i.year#i.grupo_dias"

/* Start model counter and loop for estimation using country x year FE */
local mmm = 0
estimates clear
foreach outcome of varlist num_violent_MM num_peaceful_MM government_response_violent {
	local ++mmm
	eststo m`mmm' : reghdfe `outcome' post i.month i.month i.day if inrange(window, -90, 90), absorb(${cy_fe}) vce(${cydays})
	estadd local cyfe = "\checkmark"
	levelsof id_group if e(sample) == 1
	estadd scalar nscand = r(r)
}
/* Loop for estimation using scandal FE */
foreach outcome of varlist num_violent_MM num_peaceful_MM government_response_violent {
	local ++mmm
	eststo m`mmm' : reghdfe `outcome' post i.month i.month i.day if inrange(window, -90, 90), absorb(${scandal_fe}) vce(${cydays})
	estadd local scandalfe = "\checkmark"
	levelsof id_group if e(sample) == 1
	estadd scalar nscand = r(r)
}

esttab _all using Panel1.tex, replace b(3) se(3) ///
	star(* 0.1 ** 0.05 *** 0.01) nonotes ///
	stats(N nscand r2, ///
		labels("Observations" "Scandals" "R squared") ///
		fmt(0 0 3)) ///
	keep(post) varlabels(post "1(Post Scandal = 1)") ///
	mtitles("\shortstack{Violent \\ Protests}" "\shortstack{Non-violent \\ Protests}" "\shortstack{Gvt. Violent \\ Response}" ///
		"\shortstack{Violent \\ Protests}" "\shortstack{Non-violent \\ Protests}" "\shortstack{Gvt. Violent \\ Response}")
		
/* -------------------------- Depreciation Effects ------------------------- */
/* Read in dataset */
use "${datfin}/protests_scandals_30days_depreciation_v3", clear
/* Drop observations from Venezuela */
drop if (country == "Venezuela")

/* Create categorical variable for groups of days */
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lead30 s_lead60 s_lead90)
/* Create categorical variable for Country x Year x DaysGroup */
egen group_cluster = group(country_id year grupo_dias)

/* Create global with cluster spec for se's */
global cydays = "cluster i.country_id#i.year#i.grupo_dias"

/* Start model counter and loop for estimation using country x year FE */
local mmm = 0
estimates clear
foreach outcome of varlist num_violent_MM num_peaceful_MM government_response_violent {
	local ++mmm
	eststo m`mmm' : reghdfe `outcome' post i.month i.month i.day if inrange(window, -90, 90), absorb(${cy_fe}) vce(${cydays})
	estadd local cyfe = "\checkmark"
	levelsof id_group if e(sample) == 1
	estadd scalar nscand = r(r)
}
/* Loop for estimation using scandal FE */
foreach outcome of varlist num_violent_MM num_peaceful_MM government_response_violent {
	local ++mmm
	eststo m`mmm' : reghdfe `outcome' post i.month i.month i.day if inrange(window, -90, 90), absorb(${scandal_fe}) vce(${cydays})
	estadd local scandalfe = "\checkmark"
	levelsof id_group if e(sample) == 1
	estadd scalar nscand = r(r)
}

esttab _all using Panel2.tex, replace b(3) se(3) ///
	star(* 0.1 ** 0.05 *** 0.01) nonotes ///
	stats(N nscand r2, ///
		labels("Observations" "Depreciations" "R squared") ///
		fmt(0 0 3)) ///
	keep(post) varlabels(post "1(Post Depreciation = 1)") ///
	mtitles("\shortstack{Violent \\ Protests}" "\shortstack{Non-violent \\ Protests}" "\shortstack{Gvt. Violent \\ Response}" ///
		"\shortstack{Violent \\ Protests}" "\shortstack{Non-violent \\ Protests}" "\shortstack{Gvt. Violent \\ Response}")
		
/* ------------------------- Football Match Effects ------------------------ */
/* Read in dataset */
use "${datfin}/protests_scandals_30days_football_v3", clear
/* Drop observations from Venezuela */
drop if (country == "Venezuela")

/* Create categorical variable for groups of days */
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lead30 s_lead60 s_lead90)
/* Create categorical variable for Country x Year x DaysGroup */
egen group_cluster = group(country_id year grupo_dias)

/* Create global with cluster spec for se's */
global cydays = "cluster i.country_id#i.year#i.grupo_dias"

/* Start model counter and loop for estimation using country x year FE */
local mmm = 0
estimates clear
foreach outcome of varlist num_violent_MM num_peaceful_MM government_response_violent {
	local ++mmm
	eststo m`mmm' : reghdfe `outcome' post i.month i.month i.day if inrange(window, -90, 90), absorb(${cy_fe}) vce(${cydays})
	estadd local cyfe = "\checkmark"
	levelsof id_group if e(sample) == 1
	estadd scalar nscand = r(r)
}
/* Loop for estimation using scandal FE */
foreach outcome of varlist num_violent_MM num_peaceful_MM government_response_violent {
	local ++mmm
	eststo m`mmm' : reghdfe `outcome' post i.month i.month i.day if inrange(window, -90, 90), absorb(${scandal_fe}) vce(${cydays})
	estadd local scandalfe = "\checkmark"
	levelsof id_group if e(sample) == 1
	estadd scalar nscand = r(r)
}

esttab _all using Panel3.tex, replace b(3) se(3) ///
	star(* 0.1 ** 0.05 *** 0.01) nonotes ///
	stats(N nscand r2 cyfe scandalfe, ///
		labels("Observations" "Losses" "R squared" "Country $\times$ Year FE" "Scandal FE") ///
		fmt(0 0 3 0 0)) ///
	keep(post) varlabels(post "1(Post Match = 1)") ///
	mtitles("\shortstack{Violent \\ Protests}" "\shortstack{Non-violent \\ Protests}" "\shortstack{Gvt. Violent \\ Response}" ///
		"\shortstack{Violent \\ Protests}" "\shortstack{Non-violent \\ Protests}" "\shortstack{Gvt. Violent \\ Response}")
		
/* Make table with 3 panels */
include "https://raw.githubusercontent.com/steveofconnell/PanelCombine/master/PanelCombine.do"
panelcombine, use(Panel1.tex Panel2.tex Panel3.tex) columncount(6) ///
	paneltitles("Corruption Scandals" "Depreciation (Month-on-Month)" "Loss of Football Matches") ///
		save("${tables}/Protests/Regressions/panels_corruption_depreciation_football_6months.tex") cleanup
		
/* ----------------------------------------------------------------------------
								Event-Study Plots
---------------------------------------------------------------------------- */
/* Define lags to be used*/

local maxdays = 90

global leads ""
global leads1 ""
global leads2 ""
global leads3 ""

forval i = `maxdays'(-30)30{
	global leads "${leads} s_lead`i'"
	global leads1 "${leads1} s1_lead`i'"
	global leads2 "${leads2} s2_lead`i'"
	global leads3 "${leads3} s3_lead`i'"
}

global lags ""
global lags1 ""
global lags2 ""
global lags3 ""

forval i = 30(30)`maxdays' {
	global lags "${lags} s_lag`i'"
	global lags1 "${lags1} s1_lag`i'"
	global lags2 "${lags2} s2_lag`i'"
	global lags3 "${lags3} s3_lag`i'"
}

/* --------------------------- Corruption Scandals ------------------------- */
/* Read in dataset */
use "${datfin}/protests_scandals_30days_v3", clear
/* Drop observations from Venezuela */
drop if (country == "Venezuela")

/* Create categorical variable for groups of days */
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lead30 s_lead60 s_lead90)
/* Create categorical variable for Country x Year x DaysGroup */
egen group_cluster = group(country_id year grupo_dias)

/* Loop for estimation with Country x Year FE */
foreach outcome of varlist num_violent_MM num_peaceful_MM government_response_violent {
	reghdfe `outcome' ${leads} ${lags} i.month i.month i.day if inrange(window, -90, 90), absorb(${cy_fe}) vce(${cydays})
	
	coefplot,  keep(${leads} ${lags}) levels(90) ///
	baselevels omitted vertical ///
	xtitle("Days around scandal", size(medium)) xscale(titlegap(2)) ///
	xlabel(, labsize(medium)) ///
	xline(3.5, lcolor(black)) ///
	ylabel(, labsize(medium)) ///
	yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ///
	graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
	ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
	
	graph export "${graphs}/Protests/`outcome'_corruption_cyfe_6m.pdf", replace
}
/* Loop for estimation using scandal FE */
foreach outcome of varlist num_violent_MM num_peaceful_MM government_response_violent {
	reghdfe `outcome' ${leads} ${lags} i.month i.month i.day if inrange(window, -90, 90), absorb(${scandal_fe}) vce(${cydays})

	coefplot,  keep(${leads} ${lags}) levels(90) ///
	baselevels omitted vertical ///
	xtitle("Days around scandal", size(medium)) xscale(titlegap(2)) ///
	xlabel(, labsize(medium)) ///
	xline(3.5, lcolor(black)) ///
	ylabel(, labsize(medium)) ///
	yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ///
	graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
	ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
	
	graph export "${graphs}/Protests/`outcome'_corruption_scandalfe_6m.pdf", replace
}

/* ------------------------------- Depreciations --------------------------- */
/* Read in dataset */
use "${datfin}/protests_scandals_30days_depreciation_v3", clear
/* Drop observations from Venezuela */
drop if (country == "Venezuela")

/* Create categorical variable for groups of days */
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lead30 s_lead60 s_lead90)
/* Create categorical variable for Country x Year x DaysGroup */
egen group_cluster = group(country_id year grupo_dias)

/* Loop for estimation with Country x Year FE */
foreach outcome of varlist num_violent_MM num_peaceful_MM government_response_violent {
	reghdfe `outcome' ${leads} ${lags} i.month i.month i.day if inrange(window, -90, 90), absorb(${cy_fe}) vce(${cydays})
	
	coefplot,  keep(${leads} ${lags}) levels(90) ///
	baselevels omitted vertical ///
	xtitle("Days around scandal", size(medium)) xscale(titlegap(2)) ///
	xlabel(, labsize(medium)) ///
	xline(3.5, lcolor(black)) ///
	ylabel(, labsize(medium)) ///
	yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ///
	graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
	ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
	
	graph export "${graphs}/Protests/`outcome'_depreciation_cyfe_6m.pdf", replace
}
/* Loop for estimation using scandal FE */
foreach outcome of varlist num_violent_MM num_peaceful_MM government_response_violent {
	reghdfe `outcome' ${leads} ${lags} i.month i.month i.day if inrange(window, -90, 90), absorb(${scandal_fe}) vce(${cydays})

	coefplot,  keep(${leads} ${lags}) levels(90) ///
	baselevels omitted vertical ///
	xtitle("Days around scandal", size(medium)) xscale(titlegap(2)) ///
	xlabel(, labsize(medium)) ///
	xline(3.5, lcolor(black)) ///
	ylabel(, labsize(medium)) ///
	yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ///
	graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
	ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
	
	graph export "${graphs}/Protests/`outcome'_depreciation_scandalfe_6m.pdf", replace
}

/* --------------------------- Corruption Scandals ------------------------- */
/* Read in dataset */
use "${datfin}/protests_scandals_30days_football_v3", clear
/* Drop observations from Venezuela */
drop if (country == "Venezuela")

/* Create categorical variable for groups of days */
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lead30 s_lead60 s_lead90)
/* Create categorical variable for Country x Year x DaysGroup */
egen group_cluster = group(country_id year grupo_dias)

/* Loop for estimation with Country x Year FE */
foreach outcome of varlist num_violent_MM num_peaceful_MM government_response_violent {
	reghdfe `outcome' ${leads} ${lags} i.month i.month i.day if inrange(window, -90, 90), absorb(${cy_fe}) vce(${cydays})
	
	coefplot,  keep(${leads} ${lags}) levels(90) ///
	baselevels omitted vertical ///
	xtitle("Days around scandal", size(medium)) xscale(titlegap(2)) ///
	xlabel(, labsize(medium)) ///
	xline(3.5, lcolor(black)) ///
	ylabel(, labsize(medium)) ///
	yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ///
	graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
	ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
	
	graph export "${graphs}/Protests/`outcome'_football_cyfe_6m.pdf", replace
}
/* Loop for estimation using scandal FE */
foreach outcome of varlist num_violent_MM num_peaceful_MM government_response_violent {
	reghdfe `outcome' ${leads} ${lags} i.month i.month i.day if inrange(window, -90, 90), absorb(${scandal_fe}) vce(${cydays})

	coefplot,  keep(${leads} ${lags}) levels(90) ///
	baselevels omitted vertical ///
	xtitle("Days around scandal", size(medium)) xscale(titlegap(2)) ///
	xlabel(, labsize(medium)) ///
	xline(3.5, lcolor(black)) ///
	ylabel(, labsize(medium)) ///
	yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ///
	graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
	ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
	
	graph export "${graphs}/Protests/`outcome'_football_scandalfe_6m.pdf", replace
}
