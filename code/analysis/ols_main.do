/* ----------------------------------------------------------------------------
					Violent effects of apex corruption
						
	Code author: Roberto Gonzalez
	Date: July 10, 2025
	
	Objective: Estimate event-study specification with OLS
---------------------------------------------------------------------------- */

/*	------------------- Configuration for collaborators -------------------- */
if "`c(username)'" == "lalov" {
		gl identity "C:\Users\lalov\ITAM Seira Research Dropbox\Eduardo Rivera"
} 
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox"
}
if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
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

/* Define inputs needed for the estimator */
local idvars = "country id"
local panelvar = "country_scandal_id"

local timevar = "date"
local treat_cohort = "event_time"

local extra_fixedeff = "country year"

local se_cluster = "country_id year grupo_dias"

/* First year of data to use */
local firstyear = 2011

/* Define confidence interval level wanted in coefficient plots */
local ci_level = 90
local alphaval = 0.1

/* Define number of days for window */
local window_length = "120"
local bin_width = "30"

/* Loop analysis over window of days around the event ---------------------- */
foreach numbdays in `window_length' {
	/* Set Globals with all treatment leads and lags */
	global leads ""
	global leads1 ""
	global leads2 ""
	global leads3 ""
	
	forvalues i = `numbdays'(-`bin_width')`bin_width'{
		global leads "${leads} s_lead`i'"
		global leads1 "${leads1} s1_lead`i'"
		global leads2 "${leads2} s2_lead`i'"
		global leads3 "${leads3} s3_lead`i'"
	}
	
	global lags ""
	global lags1 ""
	global lags2 ""
	global lags3 ""
	
	forvalues i = `bin_width'(`bin_width')`numbdays' {
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
	egen group_cluster = group(`se_cluster')
	
	if "`extra_fixedeff'" != "" {
			capture drop auxvar
			egen auxvar = group(`extra_fixedeff')
			local fes = "auxvar"
	}
	
	/* Iterate over outcomes and estimate treatment effects */
	estimates clear
	local outcome_counter = 0
	foreach outcome in ${outcome_list} {
		/* Message for knowing outcome */
		display in yellow "Estimating treatment effects for `outcome'"
		
		/* Estimate */
		local ++outcome_counter
		/* Average effect across all event-time periods */
		reghdfe `outcome' post, ///
			absorb(month day `fes') vce(cluster group_cluster)
		local av_est = string(_b[post], "%4.3fc")
		local p_av_est = 2*normal(-abs(_b[post]/_se[post]))
		if `p_av_est' < 0.01 {
			local p_string = "p < 0.01"
		}
		else {
			local p_string = "p = " + string(`p_av_est', "%4.3fc")
		}
		/* Effect for each event-time */
		eststo m_`outcome_counter' : reghdfe `outcome' ${leads} ${lags}, ///
			absorb(month day `fes') cluster(group_cluster)
			
		coefplot, keep(${leads} ${lags}) levels(90) ///
			baselevels omitted vertical ytitle("average effect", size(medium)) yscale(titlegap(2)) ///
			xtitle("days around scandal", size(medium)) xscale(titlegap(2)) xline(4.5, lcolor(black%10) lwidth(vvthick))  ///
			yline(0, lpattern(dash) lcolor(black)) ylabel(, labsize(medlarge) format(%3.2fc)) xlabel(, labsize(medlarge)) ///
			graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white)  ///
			ilwidth(vvvthin)) ciopts(lwidth(*1.5) lcolor(black)) mcolor(black) scheme(plotplain) ///
			legend(order(- "Avg. Effect = `av_est' (`p_string')") pos(4) ring(0) size(medium) region(lcolor(none)))
		graph export "${work}/results/figures/es_`outcome'_`numbdays'd_overlaps_`ci_level'ci.pdf", replace
		
	} /* end loop over outcomes */
} /* end loop over windows */
