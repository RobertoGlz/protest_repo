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
if "`c(username)'" == "rob98" {
	global identity "C:/Users/rob98/Dropbox"
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
global work "${identity}/Corrupcion/Protest_Work"
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

local window_days = 30
local group_days = 6
local xlinepos = `window_days'/`group_days' + 0.5

/* redefine leads and lags in short windows */
keep if inrange(window, -`window_days', `window_days')
generate event_bin = floor(window/`group_days')

summarize event_bin, detail
local maxevent = r(max)

replace event_bin = event_bin - 1 if event_bin == `maxevent'
tab window event_bin

summarize event_bin
local min_bin = r(min)
generate event_bin_enc = event_bin - `min_bin' + 1

levelsof event_bin, local(bins)
foreach b of local bins {
    local val = `b' - `min_bin' + 1
	local day_label = `b'*`group_days'
    label define event_bin_lbl `val' "`day_label'", add
}
label values event_bin_enc event_bin_lbl

tab window event_bin

summarize event_bin_enc if event_bin == -1
local basegroup = r(mean)

local cilevel = 90
/* Estimate regression and plot coefficients */
estimates clear
local mmm = 0
foreach outcome in "num_protests_MM" "num_violent_MM" "num_peaceful_MM" "government_response_violent" {
	local ++mmm
	/* No overlaps */
	eststo m`mmm' : reghdfe `outcome' post i.month i.day if year>=2008, absorb($fe1) vce(${CLUSTER2})
	quietly levelsof id if e(sample) == 1
	estadd scalar num_scandals = r(r)
	estadd local cy_fe = "\checkmark"
	estadd local serr = "C $\times$ Y $\times$ DB"

	reghdfe `outcome' ib`basegroup'.event_bin_enc i.month i.day if year>=2008, absorb($fe1) vce(${CLUSTER2})

	coefplot, keep(*event_bin_enc) levels(`cilevel') ///
	baselevels omitted vertical ///
	xtitle("Days around scandal") xscale(titlegap(2)) xline(`xlinepos', lcolor(black))  ///
	yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
	graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
	ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
	graph export "${work}/results/figures/es_`outcome'_`window_days'd_`cilevel'ci.png", replace

}

esttab _all using "${work}/results/tables/es_`window_days'd_`cilevel'ci.tex", ///
	replace booktabs nonotes nogaps b(3) se(3) ///
	mtitles("\shortstack{Protests}" "\shortstack{Violent\\Protests}" "\shortstack{Non-Violent\\Protests}" ///
	"\shortstack{Gvt. Violent\\Response}") stats(N num_scandals r2 cy_fe serr, ///
	label("Observations" "Number of Scandals" "R-squared" "Country $\times$ Year FE" "SE Cluster") ///
	fmt(0 0 3 0 0)) keep(post) coeflabels(post "Post Scandal") 

