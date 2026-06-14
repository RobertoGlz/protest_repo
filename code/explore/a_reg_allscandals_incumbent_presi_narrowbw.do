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

/* read in dataset with scandal classifications */
import delimited using "${datfin}/scandals_classified.csv", clear varnames(1) bindquotes(strict)
drop date
		
/* Read in dataset */
merge 1:m id country using "${datfin}/protests_scandals_30days_v3", keep(3)

eststo clear

drop if country=="Venezuela" 

/* generate incumbent presidents */
generate incumbent_presi = .
replace incumbent_presi = 1 if (position == "president" & political_affiliation == "incumbent")
replace incumbent_presi = 0 if (position == "president" & political_affiliation != "incumbent")
tabulate incumbent_presi

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

local posvar "incumbent_presi"

/* Estimate regression and plot coefficients */
foreach rrr in 1 0 {
	estimates clear
	local mmm = 0
	foreach outcome in "num_protests_MM" "num_violent_MM" "num_peaceful_MM" "government_response_violent" {
		local ++mmm
		/* No overlaps */
		eststo m`mmm' : reghdfe `outcome' post i.month i.day if year>=2008 & `posvar' == `rrr', absorb($fe1) vce(${CLUSTER2})
		quietly levelsof id if e(sample) == 1
		estadd scalar num_scandals = r(r)
		estadd local cy_fe = "\checkmark"
		estadd local serr = "C $\times$ Y $\times$ DB"

		reghdfe `outcome' ib`basegroup'.event_bin_enc i.month i.day if year>=2008 & `posvar' == `rrr', absorb($fe1) vce(${CLUSTER2})

		coefplot, keep(*event_bin_enc) levels(`cilevel') ///
		baselevels omitted vertical ///
		xtitle("Days around scandal") xscale(titlegap(2)) xline(`xlinepos', lcolor(black))  ///
		yline(0, lwidth(vvvthin) lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge)) xlabel(, labsize(medlarge)) ///
		graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
		ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain)
		graph export "${work}/results/figures/es_`outcome'_`window_days'd_`cilevel'ci_`posvar'`rrr'.png", replace
	} // end of loop over outcomes
	esttab _all using Panel`rrr'.tex, ///
	replace booktabs nonotes nogaps b(3) se(3) ///
	mtitles("\shortstack{Protests}" "\shortstack{Violent\\Protests}" "\shortstack{Non-Violent\\Protests}" ///
	"\shortstack{Gvt. Violent\\Response}") stats(N num_scandals r2 cy_fe serr, ///
	label("Observations" "Number of Scandals" "R-squared" "Country $\times$ Year FE" "SE Cluster") ///
	fmt(0 0 3 0 0)) keep(post) coeflabels(post "Post Scandal") 
} // end of loop over category restriction

/* Program for combining panels from "https://raw.githubusercontent.com/steveofconnell/PanelCombine/master/PanelCombine.do" */
cap prog drop panelcombine
prog define panelcombine
qui {
syntax, use(str asis) paneltitles(str asis) columncount(integer) save(str asis) [CLEANup]
preserve

tokenize `"`paneltitles'"'
//read in loop
local num 1
while "``num''"~="" {
local panel`num'title="``num''"
local num=`num'+1
}


tokenize `use'
//read in loop
local num 1
while "``num''"~="" {
tempfile temp`num'
insheet using "``num''", clear
save `temp`num''
local max = `num'
local num=`num'+1
}

//conditional processing loop
local num 1
while "``num''"~="" {
local panellabel : word `num' of `c(ALPHA)'
use `temp`num'', clear
	if `num'==1 { //process first panel -- clip bottom
	drop if strpos(v1,"Note:")>0 | strpos(v1,"in parentheses")>0 | strpos(v1,"p<0")>0
	drop if v1=="\end{tabular}" | v1=="}"
	replace v1 = "\midrule \multicolumn{`columncount'}{l}{ \linebreak \textbf{\textit{Panel `panellabel': `panel1title'}}} \\" if v1=="\midrule" & _n<8
	replace v1 = "\midrule" if v1=="\bottomrule" & _n>4 //this is intended to replace the bottom double line; more robust condition probably exists
	}
	else if `num'==`max' { //process final panel -- clip top
	//process header to drop everything until first hline
	g temp = (v1 == "\midrule")
	replace temp = temp+temp[_n-1] if _n>1
	drop if temp==0
	drop temp
	
	replace v1 = " \multicolumn{`columncount'}{l}{\linebreak \textbf{\textit{Panel `panellabel': `panel`num'title'}}} \\" if _n==1
	}
	else { //process middle panels -- clip top and bottom
	//process header to drop everything until first hline
	g temp = (v1 == "\midrule")
	replace temp = temp+temp[_n-1] if _n>1
	drop if temp==0
	drop temp
	
	replace v1 = " \multicolumn{`columncount'}{l}{\linebreak \textbf{\textit{Panel `panellabel': `panel`num'title'}}} \\" if _n==1
	drop if strpos(v1,"Note:")>0 | strpos(v1,"in parentheses")>0 | strpos(v1,"p<0")>0
	drop if v1=="\end{tabular}" | v1=="}"
	replace v1 = "\bottomrule" if v1=="\bottomrule\bottomrule"
	}
	save `temp`num'', replace
local num=`num'+1
}

use `temp1',clear
local num 2
while "``num''"~="" {
append using `temp`num''
local num=`num'+1
}

outsheet using `save', noname replace noquote


	if "`cleanup'"!="" { //erasure loop
	tokenize `use'
	local num 1
		while "``num''"~="" {
		erase "``num''"
		local num=`num'+1
		}
	}

restore
}
end

panelcombine, use(Panel1.tex Panel0.tex) ///
	columncount(3) paneltitles("Incumbent Presidents" "Non-Incumbent Presidents") ///
	save("${work}/results/tables/es_`window_days'd_`cilevel'ci_`posvar'.tex") cleanup