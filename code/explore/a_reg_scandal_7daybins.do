********************************************************************************
* PROJECT: Rebuilding trust, social cohesion and democratic values
* TASK: (Master dofile) CLEANING of the corruption scandal data
* By: Roberto Gonzalez
* Date Created: November, 2024
********************************************************************************

set more off
//clear all

*** THIS IS THE INPUT THAT MUST BE CHANGED SPECIFIC TO THE USER/ANALYSIS ***
if "`c(username)'" == "Diego" {
		gl identity "D:/Documents/Dropbox"
} 
if "`c(username)'" == "dtocre" {
		gl identity "C:/Users/dtocre/Dropbox"
} 
if "`c(username)'" == "" {
		gl identity ""
} 

if "`c(username)'" == "lalov" {
		gl identity "C:\Users\lalov\ITAM Seira Research Dropbox\Eduardo Rivera"
} 
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox"
}
********************************************************************************

** Creating Global File Paths **
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
El presente do-file genera los  resultados de la parte de protestas dividiendolas despues de 2010 y durante todo el periodo. De igual forma analiza protestas pacificas, protestas violentas y protestas en general

*/


use "${datfin}/protests_scandals_30days_v3", clear

// eststo clear

drop if country=="Venezuela" 


*Define Cluster and FE

global fe1 "i.country_id#i.year"
global fe2 "i.country_id i.year"
global fe3 "i.id_group"


egen grupo_dias=group(s_lag30 s_lag60 s_lead30 s_lead60)

global CLUSTER1 = "cluster i.country_id#i.year"
global CLUSTER2 = "cluster i.country_id#i.year#i.grupo_dias"
global CLUSTER3 = "cluster i.country_id"
global CLUSTER4 = "cluster i.country_id#i.year#i.window"

egen group_cluster=group( country_id year grupo_dias)

/* Globals with all treatment leads and lags */
global leads ""
global leads1 ""
global leads2 ""
global leads3 ""

forval i = 84(-7)7{
	global leads "${leads} s_lead`i'"
	global leads1 "${leads1} s1_lead`i'"
	global leads2 "${leads2} s2_lead`i'"
	global leads3 "${leads3} s3_lead`i'"
}

global lags ""
global lags1 ""
global lags2 ""
global lags3 ""

forval i = 7(7)84 {
	global lags "${lags} s_lag`i'"
	global lags1 "${lags1} s1_lag`i'"
	global lags2 "${lags2} s2_lag`i'"
	global lags3 "${lags3} s3_lag`i'"
}

drop s_lag* s_lead*

forvalues ddd = 1/12 {
	generate s_lead`=`ddd'*7' = (window >= -7*`ddd' & window < -7*`=`ddd'-1') 
	generate s_lag`=`ddd'*7' = (window <= 7*`ddd' & window > -7*`=`ddd'-1')  
}
forvalues kkk = 7(7)84 {
	label variable s_lag`kkk' "`kkk'"
}
forvalues kkk = -84(7)-7 {
	label variable s_lead`=-1*`kkk'' "`kkk'"
}

replace s_lead7 = 0 // Base category

/* Estimate regression and plot coefficients */

/* After 2010, No overlaps */
eststo mm4 : reghdfe num_violent_MM post i.month i.day if year>2010 & (inrange(window, -84, 84)), absorb($fe1) vce(${CLUSTER2})
estadd local cy_fe = "\checkmark"
estadd local serr = "Country $\times$ Year $\times$ Days Bin"

reghdfe num_violent_MM ${leads} ${lags} i.month i.day if year>2010 & (inrange(window, -84, 84)), absorb($fe1) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(12.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)

graph export "${work}/results/figures/es_numviolentMM_84d_7dgroup_after2010_90ci.png", replace
