********************************************************************************
* PROJECT: Rebuilding trust, social cohesion and democratic values
* TASK: (Master dofile) CLEANING of the corruption scandal data
* By: Roberto Gonzalez
* Date Created: November, 2024
********************************************************************************

set more off
clear all

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




/* Globals with all treatment leads and lags */

global leads ""
global leads1 ""
global leads2 ""
global leads3 ""

forval i = 120(-30)30{
	global leads "${leads} s_lead`i'"
	global leads1 "${leads1} s1_lead`i'"
	global leads2 "${leads2} s2_lead`i'"
	global leads3 "${leads3} s3_lead`i'"
}

global lags ""
global lags1 ""
global lags2 ""
global lags3 ""

forval i = 30(30)120 {
	global lags "${lags} s_lag`i'"
	global lags1 "${lags1} s1_lag`i'"
	global lags2 "${lags2} s2_lag`i'"
	global lags3 "${lags3} s3_lag`i'"
}


/*
El presente do-file genera los  resultados de la parte de protestas dividiendolas despues de 2010 y durante todo el periodo. De igual forma analiza protestas pacificas, protestas violentas y protestas en general

*/


use "${datfin}/protests_scandals_30days_v3", clear

eststo clear

drop if country=="Venezuela" 


*Define Cluster and FE

global fe1 "i.country_id#i.year"
global fe2 "i.country_id i.year"
global fe3 "i.id_group"


egen grupo_dias=group(s_lag30 s_lag60 s_lag90 s_lag120 s_lead30 s_lead60 s_lead90 s_lead120)

global CLUSTER1 = "cluster i.country_id#i.year"
global CLUSTER2 = "cluster i.country_id#i.year#i.grupo_dias"
global CLUSTER3 = "cluster i.country_id"
global CLUSTER4 = "cluster i.country_id#i.year#i.window"

egen group_cluster=group( country_id year grupo_dias)

/* Flag scandals for which there is overlap and drop them */
generate date_0 = date if window == 0
bysort id : ereplace date_0 = min(date_0) 

generate window_start = date_0 - 120
generate window_end = date_0 + 120 

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

/* Keep only scandals without overlap */
keep if overlap == 0

/* Estimate regression and plot coefficients */

/* After 2010, No overlaps */
eststo mm1 : reghdfe num_violent_MM post i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})
estadd local cy_fe = "\checkmark"
estadd local serr = "Country $\times$ Year $\times$ Days Bin"

reghdfe num_violent_MM ${leads} ${lags} i.month i.day if year>2010, absorb($fe1) vce(${CLUSTER2})

coefplot, keep(${leads} ${lags}) levels(90) ///
baselevels omitted vertical ///
xtitle("Days around scandal") xscale(titlegap(2)) xline(4.5, lcolor(black))  ///
yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ///
graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
graph export "${work}/results/figures/es_numviolentMM_120d_after2010_nooverlaps_90ci.png", replace