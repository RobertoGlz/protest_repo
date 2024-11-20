/* ----------------------------------------------------------------------------
					Corruption scandals and protests 
							
	Author: Roberto Gonzalez
	Adapated from: various codes by Diego Tocre and Eduardo Rivera
	
	Date: November 20, 2024
---------------------------------------------------------------------------- */

estimates clear

/*	------------------- Configuration for collaborators -------------------- */
if "`c(username)'" == "lalov" {
		gl identity "C:\Users\lalov\ITAM Seira Research Dropbox\Eduardo Rivera"
} 
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox"
}

global work "${identity}/Corrupcion/Protest_Work"

/* Creating Global File Paths */
global path "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global dof 		"${path}/Dofiles"
global datraw 	"${path}/Data/raw"
global datfin 	"${path}/Data/final"
global datwrk 	"${path}/Data/working"
global datold 	"${path}/Data/archive"
global datpub 	"${path}/Data/publication"
global output 	"${path}/Output"
global violent  "$output/Violent"
global mid 		"$violent/mid"
global logs 	"${path}/Logs"
global graphs 	"${output}/Graphs"
global tables 	"${output}/Tables"
global overleaf	"${identity}/Apps/Overleaf"
local date: dis %td_NN_DD_CCYY date(c(current_date), "DMY")
gl date_string = subinstr(trim("`date'"), " " , "_", .)

/* ----------------------------------------------------------------------------
		Analysis for 3 months pre and 3 months post scandals
							Using 30 day bins
---------------------------------------------------------------------------- */
local numbdays = 90 // 30*3 days

/* Globals with all treatment leads and lags */
global leads ""
global leads1 ""
global leads2 ""
global leads3 ""

forval i = `numbdays'(-30)30{
	global leads "${leads} s_lead`i'"
	global leads1 "${leads1} s1_lead`i'"
	global leads2 "${leads2} s2_lead`i'"
	global leads3 "${leads3} s3_lead`i'"
}

global lags ""
global lags1 ""
global lags2 ""
global lags3 ""

forval i = 30(30)`numbdays' {
	global lags "${lags} s_lag`i'"
	global lags1 "${lags1} s1_lag`i'"
	global lags2 "${lags2} s2_lag`i'"
	global lags3 "${lags3} s3_lag`i'"
}

/* Define Cluster and FE */
global fe1 "i.country_id#i.year"
global fe2 "i.country_id i.year"
global fe3 "i.id_group"

global CLUSTER1 = "cluster i.country_id#i.year"
global CLUSTER2 = "cluster i.country_id#i.year#i.grupo_dias"
global CLUSTER3 = "cluster i.country_id"
global CLUSTER4 = "cluster i.country_id#i.year#i.window"

/* --------------------- Analysis allowing for overlap ----------------------*/
/* Read in dataset */
use "${datfin}/protests_scandals_30days_v3", clear
drop if (country == "Venezuela")

egen grupo_dias=group(s_lag30 s_lag60 s_lag90 s_lead30 s_lead60 s_lead90)
egen group_cluster=group( country_id year grupo_dias)


/* Estimate regression for Violent Protests */
eststo mm1 : reghdfe num_violent_MM post i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})
estadd local cy_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe num_violent_MM ${leads} ${lags} i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_numviolentMM_90d_after2010_overlaps_90ci.png", replace

/* Estimate regression for Gvt Responses */
eststo gg1 : reghdfe government_response_violent post i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})
estadd local cy_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe government_response_violent ${leads} ${lags} i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_gvtviolent_90d_after2010_overlaps_90ci.png", replace

/* ----------------- Analysis without allowing for overlap ------------------*/
/* Read in dataset */
use "${datfin}/protests_scandals_30days_v3", clear
drop if (country == "Venezuela")

egen grupo_dias=group(s_lag30 s_lag60 s_lag90 s_lead30 s_lead60 s_lead90)
egen group_cluster=group( country_id year grupo_dias)

/* Flag scandals for which there is overlap and drop them */
generate date_0 = date if window == 0
bysort id : ereplace date_0 = min(date_0) 

generate window_start = date_0 - `numbdays'
generate window_end = date_0 + `numbdays'

sort country date_0
preserve 
keep if window == 0
	bysort country id : generate scandal_numb = _n
	generate overlap = 0
	bysort country : replace overlap = 1 if ((window_end[_n-1] >= window_start[_n]) & (window_end[_n-1] <= window_end[_n]))
	sort country date_0
	keep id overlap
	local totscandals = _N
	summarize overlap, detail
	display in yellow "There are `r(sum)' scandals which overlap with another one out of `totscandals'"
	tempfile overlaps
	save `overlaps'
restore

merge m:1 id using `overlaps'
assert (_merge == 3)
drop _merge date_0 window_start window_end 

keep if overlap == 0

/* Estimate regression for Violent Protests */
eststo mm2 : reghdfe num_violent_MM post i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})
estadd local cy_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe num_violent_MM ${leads} ${lags} i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_numviolentMM_90d_after2010_nooverlaps_90ci.png", replace

/* Estimate regression for Gvt Responses */
eststo gg2 : reghdfe government_response_violent post i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})
estadd local cy_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe government_response_violent ${leads} ${lags} i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_gvtviolent_90d_after2010_nooverlaps_90ci.png", replace

/* --------------------- Analysis allowing for overlap ----------------------*/
/* --------------------------- Using scandal FE ---------------------------- */
/* Read in dataset */
use "${datfin}/protests_scandals_30days_v3", clear
drop if (country == "Venezuela")

egen grupo_dias=group(s_lag30 s_lag60 s_lag90 s_lead30 s_lead60 s_lead90)
egen group_cluster=group( country_id year grupo_dias)

/* Estimate regression for Violent Protests */
eststo mm3 : reghdfe num_violent_MM post i.month i.day if year>2010, absorb($fe3) vce(${CLUSTER2})
estadd local scandal_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe num_violent_MM ${leads} ${lags} i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_numviolentMM_90d_after2010_overlaps_90ci_scandalfe.png", replace

/* Estimate regression for Gvt Responses */
eststo gg3 : reghdfe government_response_violent post i.month i.day if year>2010, absorb($fe3) vce(${CLUSTER2})
estadd local scandal_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe government_response_violent ${leads} ${lags} i.month i.day if year>2010, absorb($fe3) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_gvtviolent_90d_after2010_overlaps_90ci_scandalfe.png", replace

/* ----------------- Analysis without allowing for overlap ------------------*/
/* -------------------------- Using scandal FE ----------------------------- */
/* Read in dataset */
use "${datfin}/protests_scandals_30days_v3", clear
drop if (country == "Venezuela")

egen grupo_dias=group(s_lag30 s_lag60 s_lag90 s_lead30 s_lead60 s_lead90)
egen group_cluster=group( country_id year grupo_dias)

/* Flag scandals for which there is overlap and drop them */
generate date_0 = date if window == 0
bysort id : ereplace date_0 = min(date_0) 

generate window_start = date_0 - `numbdays'
generate window_end = date_0 + `numbdays'

sort country date_0
preserve 
keep if window == 0
	bysort country id : generate scandal_numb = _n
	generate overlap = 0
	bysort country : replace overlap = 1 if ((window_end[_n-1] >= window_start[_n]) & (window_end[_n-1] <= window_end[_n]))
	sort country date_0
	keep id overlap
	local totscandals = _N
	summarize overlap, detail
	display in yellow "There are `r(sum)' scandals which overlap with another one out of `totscandals'"
	tempfile overlaps
	save `overlaps'
restore

merge m:1 id using `overlaps'
assert (_merge == 3)
drop _merge date_0 window_start window_end 

keep if overlap == 0

/* Estimate regression for Violent Protests */
eststo mm4 : reghdfe num_violent_MM post i.month i.day if year>2010, absorb($fe3) vce(${CLUSTER2})
estadd local scandal_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe num_violent_MM ${leads} ${lags} i.month i.day if year>2010, absorb($fe3) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_numviolentMM_90d_after2010_nooverlaps_90ci_scandalfe.png", replace

/* Estimate regression for Gvt Responses */
eststo gg4 : reghdfe government_response_violent post i.month i.day if year>2010, absorb($fe3) vce(${CLUSTER2})
estadd local scandal_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe government_response_violent ${leads} ${lags} i.month i.day if year>2010, absorb($fe3) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_gvtviolent_90d_after2010_nooverlaps_90ci_scandalfe.png", replace

/* ----------------------------------------------------------------------------
		Analysis for 4 months pre and 4 months post scandals
							Using 30 day bins
---------------------------------------------------------------------------- */
local numbdays = 120 // 30*4 days

/* Globals with all treatment leads and lags */
global leads ""
global leads1 ""
global leads2 ""
global leads3 ""

forval i = `numbdays'(-30)30{
	global leads "${leads} s_lead`i'"
	global leads1 "${leads1} s1_lead`i'"
	global leads2 "${leads2} s2_lead`i'"
	global leads3 "${leads3} s3_lead`i'"
}

global lags ""
global lags1 ""
global lags2 ""
global lags3 ""

forval i = 30(30)`numbdays' {
	global lags "${lags} s_lag`i'"
	global lags1 "${lags1} s1_lag`i'"
	global lags2 "${lags2} s2_lag`i'"
	global lags3 "${lags3} s3_lag`i'"
}

/* Define Cluster and FE */
global fe1 "i.country_id#i.year"
global fe2 "i.country_id i.year"
global fe3 "i.id_group"

global CLUSTER1 = "cluster i.country_id#i.year"
global CLUSTER2 = "cluster i.country_id#i.year#i.grupo_dias"
global CLUSTER3 = "cluster i.country_id"
global CLUSTER4 = "cluster i.country_id#i.year#i.window"

/* --------------------- Analysis allowing for overlap ----------------------*/
/* Read in dataset */
use "${datfin}/protests_scandals_30days_v3", clear
drop if (country == "Venezuela")

egen grupo_dias=group(s_lag30 s_lag60 s_lag90 s_lag120 s_lead30 s_lead60 s_lead90 s_lead120)
egen group_cluster=group(country_id year grupo_dias)

/* Estimate regression for Violent Protests */
eststo mm5 : reghdfe num_violent_MM post i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})
estadd local cy_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe num_violent_MM ${leads} ${lags} i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_numviolentMM_120d_after2010_overlaps_90ci.png", replace

/* Estimate regression for Gvt Responses */
eststo gg5 : reghdfe government_response_violent post i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})
estadd local cy_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe government_response_violent ${leads} ${lags} i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_gvtviolent_120d_after2010_overlaps_90ci.png", replace

/* ----------------- Analysis without allowing for overlap ------------------*/
/* Read in dataset */
use "${datfin}/protests_scandals_30days_v3", clear
drop if (country == "Venezuela")

egen grupo_dias=group(s_lag30 s_lag60 s_lag90 s_lag120 s_lead30 s_lead60 s_lead90 s_lead120)
egen group_cluster=group(country_id year grupo_dias)

/* Flag scandals for which there is overlap and drop them */
generate date_0 = date if window == 0
bysort id : ereplace date_0 = min(date_0) 

generate window_start = date_0 - `numbdays'
generate window_end = date_0 + `numbdays'

sort country date_0
preserve 
keep if window == 0
	bysort country id : generate scandal_numb = _n
	generate overlap = 0
	bysort country : replace overlap = 1 if ((window_end[_n-1] >= window_start[_n]) & (window_end[_n-1] <= window_end[_n]))
	sort country date_0
	keep id overlap
	local totscandals = _N
	summarize overlap, detail
	display in yellow "There are `r(sum)' scandals which overlap with another one out of `totscandals'"
	tempfile overlaps
	save `overlaps'
restore

merge m:1 id using `overlaps'
assert (_merge == 3)
drop _merge date_0 window_start window_end 

keep if overlap == 0

/* Estimate regression for Violent Protests */
eststo mm6 : reghdfe num_violent_MM post i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})
estadd local cy_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe num_violent_MM ${leads} ${lags} i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_numviolentMM_120d_after2010_nooverlaps_90ci.png", replace

/* Estimate regression for Gvt Responses */
eststo gg6 : reghdfe government_response_violent post i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})
estadd local cy_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe government_response_violent ${leads} ${lags} i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_gvtviolent_120d_after2010_nooverlaps_90ci.png", replace

/* --------------------- Analysis allowing for overlap ----------------------*/
/* --------------------------- Using scandal FE ---------------------------- */
/* Read in dataset */
use "${datfin}/protests_scandals_30days_v3", clear
drop if (country == "Venezuela")

egen grupo_dias=group(s_lag30 s_lag60 s_lag90 s_lag120 s_lead30 s_lead60 s_lead90 s_lead120)
egen group_cluster=group(country_id year grupo_dias)

/* Estimate regression for Violent Protests */
eststo mm7 : reghdfe num_violent_MM post i.month i.day if year>2010, absorb($fe3) vce(${CLUSTER2})
estadd local scandal_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe num_violent_MM ${leads} ${lags} i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_numviolentMM_120d_after2010_overlaps_90ci_scandalfe.png", replace

/* Estimate regression for Gvt Responses */
eststo gg7 : reghdfe government_response_violent post i.month i.day if year>2010, absorb($fe3) vce(${CLUSTER2})
estadd local scandal_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe government_response_violent ${leads} ${lags} i.month i.day if year>2010, absorb($fe3) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_gvtviolent_120d_after2010_overlaps_90ci_scandalfe.png", replace

/* ----------------- Analysis without allowing for overlap ------------------*/
/* -------------------------- Using scandal FE ----------------------------- */
/* Read in dataset */
use "${datfin}/protests_scandals_30days_v3", clear
drop if (country == "Venezuela")

egen grupo_dias=group(s_lag30 s_lag60 s_lag90 s_lag120 s_lead30 s_lead60 s_lead90 s_lead120)
egen group_cluster=group(country_id year grupo_dias)

/* Flag scandals for which there is overlap and drop them */
generate date_0 = date if window == 0
bysort id : ereplace date_0 = min(date_0) 

generate window_start = date_0 - `numbdays'
generate window_end = date_0 + `numbdays'

sort country date_0
preserve 
keep if window == 0
	bysort country id : generate scandal_numb = _n
	generate overlap = 0
	bysort country : replace overlap = 1 if ((window_end[_n-1] >= window_start[_n]) & (window_end[_n-1] <= window_end[_n]))
	sort country date_0
	keep id overlap
	local totscandals = _N
	summarize overlap, detail
	display in yellow "There are `r(sum)' scandals which overlap with another one out of `totscandals'"
	tempfile overlaps
	save `overlaps'
restore

merge m:1 id using `overlaps'
assert (_merge == 3)
drop _merge date_0 window_start window_end 

keep if overlap == 0

/* Estimate regression for Violent Protests */
eststo mm8 : reghdfe num_violent_MM post i.month i.day if year>2010, absorb($fe3) vce(${CLUSTER2})
estadd local scandal_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe num_violent_MM ${leads} ${lags} i.month i.day if year>2010, absorb($fe3) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_numviolentMM_120d_after2010_nooverlaps_90ci_scandalfe.png", replace

/* Estimate regression for Gvt Responses */
eststo gg8 : reghdfe government_response_violent post i.month i.day if year>2010, absorb($fe3) vce(${CLUSTER2})
estadd local scandal_fe = "\checkmark"
estadd local serr = "C $\times$ Y $\times$ DB"
levelsof id if e(sample) == 1
estadd scalar nscand = r(r)

reghdfe government_response_violent ${leads} ${lags} i.month i.day if year>2010, absorb($fe3) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(3.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_gvtviolent_120d_after2010_nooverlaps_90ci_scandalfe.png", replace

/* ------------------------- Make regression tables ------------------------ */
esttab mm1 mm2 mm3 mm4 mm5 mm6 mm7 mm8 using Panel1.tex, replace nonotes ///
	b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
	mtitles("\shortstack{6 months \\ Overlap}" "\shortstack{6 months \\ No Overlap}" "\shortstack{6 months Overlap \\ Scandal FE }" ///
	"\shortstack{6 months No Overlap \\ Scandal FE}" ///
	"\shortstack{8 months \\ Overlap}" "\shortstack{8 months \\ No Overlap}" "\shortstack{8 months Overlap \\ Scandal FE }" ///
	"\shortstack{8 months No Overlap \\ Scandal FE}") ///
	keep(post) coeflabels(post "Post Scandal") ///
	stats(N nscand R2, ///
		labels("Observations" "Scandals" "R2") fmt(0 0 3 0 0 0))
		
esttab gg1 gg2 gg3 gg4 gg5 gg6 gg7 gg8 using Panel2.tex, replace nonotes ///
	b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
	mtitles("\shortstack{6 months \\ Overlap}" "\shortstack{6 months \\ No Overlap}" "\shortstack{6 months Overlap \\ Scandal FE }" ///
	"\shortstack{6 months No Overlap \\ Scandal FE}" ///
	"\shortstack{8 months \\ Overlap}" "\shortstack{8 months \\ No Overlap}" "\shortstack{8 months Overlap \\ Scandal FE }" ///
	"\shortstack{8 months No Overlap \\ Scandal FE}") ///
	keep(post) coeflabels(post "Post Scandal") ///
	stats(N nscand R2 cy_fe scandal_fe serr, ///
		labels("Observations" "Scandals" "R2" "C $\times$ Y FE" "Scandal FE" "Cluster SE") fmt(0 0 3 0 0 0))
	
include "https://raw.githubusercontent.com/steveofconnell/PanelCombine/master/PanelCombine.do"
panelcombine, use(Panel1.tex Panel2.tex) columncount(8) ///
	paneltitles("\underline{Violent Protests}" "\underline{Gvt. Violent Response}") ///
	save("${work}/results/tables/protests_gvtresp_alt_specs.tex") cleanup