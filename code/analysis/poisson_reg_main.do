/* ----------------------------------------------------------------------------
					Violent Effects of Apex Corruption
					
	Code author: Roberto Gonzalez
	Date: May 26, 2025
	
	Objective: Estimate incidence rate ratios with Poisson regression for the
	number of Protests occuring after Corruption scandals, depreciations and 
	football match losses
---------------------------------------------------------------------------- */

/*	------------------- Configuration for collaborators -------------------- */
if "`c(username)'" == "lalov" {
		gl identity "C:\Users\lalov\ITAM Seira Research Dropbox\Eduardo Rivera"
} 
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox"
}

global work "${identity}/Corrupcion/Protest_Work"

/* Creating Global File Paths ---------------------------------------------- */
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
/* ------------------------------------------------------------------------- */

/* Define global with list of outcomes */
global outcome_list = "num_violent_MM num_peaceful_MM government_response_violent"

/* Define Cluster and FE --------------------------------------------------- */
global CY_fe "i.country_id#i.year"
global fe2 "i.country_id i.year"
global scandal_fe "i.id_group"

global cl_country_year = "cluster i.country_id#i.year"
global cl_country_year_group = "cluster i.country_id#i.year#i.grupo_dias"
global cl_country = "cluster i.country_id"
global cl_country_year_window = "cluster i.country_id#i.year#i.window"

/* Define sample of years from which we want to use the data */
local firstyear = 2011

/* Define confidence interval level wanted in coefficient plots */
local ci_level = 90
local alphaval = 0.1
	
/* Loop analysis over window of days around the event ---------------------- */
foreach numbdays in 90 120 {
	/* Set Globals with all treatment leads and lags */
	global leads ""
	global leads1 ""
	global leads2 ""
	global leads3 ""
	
	forvalues i = `numbdays'(-30)30{
		global leads "${leads} s_lead`i'"
		global leads1 "${leads1} s1_lead`i'"
		global leads2 "${leads2} s2_lead`i'"
		global leads3 "${leads3} s3_lead`i'"
	}
	
	global lags ""
	global lags1 ""
	global lags2 ""
	global lags3 ""
	
	forvalues i = 30(30)`numbdays' {
		global lags "${lags} s_lag`i'"
		global lags1 "${lags1} s1_lag`i'"
		global lags2 "${lags2} s2_lag`i'"
		global lags3 "${lags3} s3_lag`i'"
	}
	
	/* Read in dataset */
	use "${datfin}/protests_scandals_30days_v3", clear
	drop if (country == "Venezuela")
	
	/* Create groups with days since/to event */
	egen grupo_dias = group(${lags} ${leads})
	egen group_cluster = group(country_id year grupo_dias)
	
	/* Iterate over outcomes */
	estimates clear
	local y_counter = 0
	foreach outcome in ${outcome_list} {
		/* Message for knowing which outcome is being computed */
		display in yellow "Estimate IRR for `outcome'"
		/* Add one to outcome counter */
		local ++y_counter
		/* Estimate average coefficient */
		eststo m_`y_counter'_`numbdays' : poisson `outcome' post i.month i.day ///
			${fe2} if year >= `firstyear', vce(cluster group_cluster) irr
		local av_est = string(exp(_b[post])-1, "%3.2fc")
		local p_av_est = 2*normal(-abs(_b[post]/_se[post]))
		if `p_av_est' < 0.01 {
			local p_string = "p < 0.01"
		}
		else {
			local p_string = "p = " + string(`p_av_est', "%4.3fc")
		}
		quietly {
			/* Estimate IRR (exp{b}) with poisson regression and export coefficient plot */
			poisson `outcome' ${leads} ${lags} i.month i.day ///
				${fe2} if year >= `firstyear', vce(cluster group_cluster) irr
			/* Compute x-axis value in which vertical line must be drawn */
			local x_line_pos = (`numbdays'/30) + 0.5
			/* Get y-axis value of smallest CI to show effect estimate text at that height */
			local numcoefs = 2*(`numbdays'/30)
			local y_eff_pos = 1
			forvalues bbb = 1/`numcoefs' {
				local bound = r(table)[6, `bbb']
				if `bound' > `y_eff_pos' & `bound' != . { 
					local y_eff_pos = `bound'
				}
			}
		}
		/* Show coefficient plot */
		coefplot, keep(${leads} ${lags}) eform(${leads} ${lags}) ///
			levels(`ci_level') baselevels omitted vertical ///
			xtitle("days since scandal", size(medium)) xscale(titlegap(2)) ///
			xline(`x_line_pos', lwidth(vthick) lpattern(solid) lcolor(black%10)) ///
			ytitle("incidence rate ratio", size(medium)) yscale(titlegap(2)) ///
			yline(1, lwidth(medthin) lpattern(shortdash) lcolor(black)) ///
			xlabel(, labsize(medium)) ylabel(#5, nogrid format(%3.1fc) labsize(medium)) ///
			ciopts(lcolor(black) lwidth(medthin)) mcolor(black) msize(medium) ///
			legend(order(- "Avg. Effect = `av_est' (`p_string')") pos(11) ring(0))
		graph export ///
		"${work}/results/figures/poisson_es_`outcome'_`numbdays'window_since`firstyear'_overlaps_`ci_level'ci.png", ///
			replace
	}
	/* Export table */
	esttab _all using Panel_`numbdays'_corruption.tex, replace b(3) se(3) booktabs ///
	star(* 0.1 ** 0.05 *** 0.01) nonotes ///
	stats(N, ///
		labels("Observations") ///
		fmt(0 0 3)) ///
	keep(post) varlabels(post "1(Post Scandal = 1)") ///
	mtitles("\shortstack{Violent \\ Protests}" "\shortstack{Non-violent \\ Protests}" "\shortstack{Gvt. Violent \\ Response}")
}
