/* ----------------------------------------------------------------------------
									Protests
									
	Code author: Roberto Gonzalez
	Date: July 21, 2025
	
	Objective: Run estimation with raw number of protests on country-date 
	level merged to analysis dataset (BJS estimator)
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

/* Read in raw MM data */
import delimited "${datraw}/Protests/MM/MMraw.csv", clear

/* Create data of protest */
generate date = mdy(startmonth, startday, startyear)
format date %td

/* Keep protests only */
keep if protest == 1

/* create peaceful and violent protest counts */
generate raw_num_peaceful_MM = (protesterviolence == 0)
generate raw_num_violent_MM = (protesterviolence == 1)
generate raw_num_protests_MM = (raw_num_violent_MM + raw_num_peaceful_MM)
generate raw_government_response_violent = inlist(stateresponse1, "arrests", "beatings", "killings", "shootings")

/* Aggregate at the country-date level */
collapse (rawsum) raw_*, by(country date)

/* Merge in the current analysis data */
local analysis_data = "${datfin}/protests_scandals_30days_v3.dta"
merge 1:m country date using "`analysis_data'", keep(2 3)

/* _merge == 2 implies there were no protests in that country-date so impute zero */
count if _merge == 2
local n_no_protests = r(N)

foreach ptype in "protests" "peaceful" "violent" {
	count if missing(raw_num_`ptype'_MM)
	replace raw_num_`ptype'_MM = 0 if _merge == 2
}

replace raw_government_response_violent = 0 if _merge == 2

/* Assert that within country-date the outcomes are constant (only relevant for scandals with overlap) */
local aux = 0
foreach outvar of varlist raw_* {
	local ++aux
	bysort country date : egen mean_`aux' = mean(`outvar')
	assert `outvar' == mean_`aux' 
}

/* Define locals needed for Poisson Estimation */
/* Define global with list of outcomes */
global outcome_list = "raw_num_violent_MM raw_num_peaceful_MM raw_government_response_violent"

/* Define inputs needed for the estimator */
local idvars = "country id"
local panelvar = "country_scandal_id"

local timevar = "date"
local treat_cohort = "event_time"

local extra_fixedeff = "country year"

local se_cluster = "country_id year grupo_dias"

/* First year of data to use */
local firstyear = 2011

/* Define sample of years from which we want to use the data */
local firstyear = 2011

/* Define confidence interval level wanted in coefficient plots */
local ci_level = 90
local alphaval = 0.1

/* Define number of days for window */
local window_length = "120"
local bin_width = "30"

/* Specify number of horizons and/or pretrends to be estimated */
local hzns = "horizons(0/120)"
local pretrends = "pretrends(120)"

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
	
	/* drop observations from Venezuela */
	// use "${datfin}/protests_scandals_30days_v3", clear
	drop if (country == "Venezuela")
	
	/* Iterate over outcomes and estimate treatment effects */
	estimates clear
	local outcome_counter = 0
	foreach outcome in ${outcome_list} {
		/* Message for knowing outcome */
		display in yellow "Estimating treatment effects for `outcome'"
		
		/* Estimate */
		local ++outcome_counter
		if `outcome_counter' == 1 {
			egen `panelvar' = group(`idvars')
			display in yellow "Generated panel id variable"
			/* Create groups with days since/to event */
			egen grupo_dias = group(${lags} ${leads})
			egen group_cluster = group(`se_cluster')
		}
		/* Create event period variable */
		display in yellow "Creating event-time variable"
		capture drop `timevar'_aux
		generate `timevar'_aux = `timevar' if window == 0
		capture drop `treat_cohort'
		bysort `panelvar' : egen `treat_cohort' = min(`timevar'_aux)
		
		if "`extra_fixedeff'" != "" {
			capture drop auxvar
			egen auxvar = group(`extra_fixedeff')
			local fes = "auxvar"
		}
		/* Average effect across all event-time periods */
		did_imputation `outcome' `panelvar' `timevar' `treat_cohort', ///
			fe(`fes' month day) autosample cluster(group_cluster) delta(1) minn(0)
		local av_est = string(e(b)[1,1], "%4.3fc")
		local p_av_est = 2*normal(-abs(e(b)[1,1]/sqrt(e(V)[1,1])))
		if `p_av_est' < 0.01 {
			local p_string = "p < 0.01"
		}
		else {
			local p_string = "p = " + string(`p_av_est', "%4.3fc")
		}
		/* Effect for each event-time */
		eststo m_`outcome_counter' : did_imputation `outcome' `panelvar' `timevar' `treat_cohort', ///
			fe(`fes' month day) autosample cluster(group_cluster) delta(1) ///
			`hzns' `pretrends' minn(0)
			
		event_plot, plottype(scatter) ciplottype(rspike) lag_opt(color(maroon)) lag_ci_opt(color(maroon%20)) ///
			lead_opt(color(navy)) lead_ci_opt(color(navy%20)) stub_lead(pre#) stub_lag(tau#) ///
			graph_opt(xline(0, lcolor(black%10) lpattern(solid) lwidth(thick)) ///
				yline(0, lcolor(black) lpattern(solid)) ///
				xtitle("days since scandal", size(medium)) ytitle("average effect", size(medium)) ///
				legend(off) ///
				xlabel(-`window_length'(`bin_width')`window_length', nogrid labsize(medium)) ///
				ylabel(, labsize(medlarge) format(%3.2fc)))
		graph export "${work}/results/figures/bjs_`outcome'_`window'_cxyfe_rawmmdata.pdf", replace
		
		/* Store effect estimates in a matrix to aggregate in bins */
		local n_bins = 2*`window_length'/`bin_width'
		display in yellow "Number of `bin_width' day bins: `n_bins'"
		
		matrix agg_b = J(`n_bins', 1, .)
		matrix agg_se = J(`n_bins', 1, .)
		
		matrix ones = J(1, `bin_width', 1)
		matrix ones_t = ones'
		
		display in yellow "Subsetting estimates to be aggregated"
		forvalues kkk = 1/`n_bins' {
			if `kkk' == 1 {
				matrix effs = e(b)[1, `bin_width'*(`kkk'-1)+`kkk'..`bin_width'*(`kkk')+`kkk'-1]
				matrix effs_t = effs'
				matrix wts = e(Nt)[1, `bin_width'*(`kkk'-1)+`kkk'..`bin_width'*(`kkk')+`kkk'-1]
				matrix wts_t = wts'
				matrix vcovs = e(V)[`bin_width'*(`kkk'-1)+`kkk'..`bin_width'*(`kkk')+`kkk'-1, `bin_width'*(`kkk'-1)+`kkk'..`bin_width'*(`kkk')+`kkk'-1]
			}
			else if `kkk' <= `=`n_bins'/2' & `kkk' != 1 {
				matrix effs = e(b)[1, `bin_width'*(`kkk'-1)+(`kkk'-`=`kkk'-1')..`bin_width'*(`kkk')]
				matrix effs_t = effs'
				matrix wts = e(Nt)[1, `bin_width'*(`kkk'-1)+(`kkk'-`=`kkk'-1')..`bin_width'*(`kkk')]
				matrix wts_t = wts'
				matrix vcovs = e(V)[`bin_width'*(`kkk'-1)+(`kkk'-`=`kkk'-1')..`bin_width'*(`kkk'), `bin_width'*(`kkk'-1)+(`kkk'-`=`kkk'-1')..`bin_width'*(`kkk')]
			}
			else if `kkk' > `=`n_bins'/2' & `kkk' < `n_bins' {
				matrix effs = e(b)[1, `bin_width'*(`kkk'-1)+(`kkk'-`=`kkk'-1')+1..`bin_width'*(`kkk')+1]
				matrix effs_t = effs'
				forvalues ppp = 1/`bin_width' {
					matrix wts[1, `ppp'] = e(Nt)[1, 1]
				}
				matrix wts_t = wts'
				matrix vcovs = e(V)[`bin_width'*(`kkk'-1)+(`kkk'-`=`kkk'-1')+1..`bin_width'*(`kkk')+1, `bin_width'*(`kkk'-1)+(`kkk'-`=`kkk'-1')+1..`bin_width'*(`kkk')+1]
			}
			else if `kkk' == `n_bins' {
				matrix effs = e(b)[1, `bin_width'*(`kkk'-1)+(`kkk'-`=`kkk'-1')+1..`bin_width'*(`kkk')]
				matrix effs_t = effs'
				matrix wts = J(1, `=`bin_width'-1', .)
				forvalues ppp = 1/`=`bin_width'-1' {
					matrix wts[1, `ppp'] = e(Nt)[1, 1]
				}
				matrix wts_t = wts'
				matrix vcovs = e(V)[`bin_width'*(`kkk'-1)+(`kkk'-`=`kkk'-1')+1..`bin_width'*(`kkk'), `bin_width'*(`kkk'-1)+(`kkk'-`=`kkk'-1')+1..`bin_width'*(`kkk')]
				matrix ones = J(1, `bin_width'-1, 1)
				matrix ones_t = ones'
			}
			display in yellow "Defined matrices for aggregating estimates"
			
			matrix tot_N = wts*ones_t
			display in yellow "Total obs used in effect estimates: `=tot_N[1,1]'"
			
			matrix agg_b[`kkk', 1] = (1/tot_N[1,1])*wts*effs_t
			display in yellow "Aggregated treatment effect for bin `kkk'"
			matrix agg_se[`kkk', 1] = (1/tot_N[1,1])*wts*vcovs*wts_t*(1/tot_N[1,1])
			display in yellow "Aggregated vcov matrix for bin `kkk'"
			matrix agg_se[`kkk', 1] = sqrt(agg_se[`kkk', 1])
			display in yellow "Aggregated std err for bin `kkk'"
		} /* end loop for aggregating treatment effects */
		matrix list agg_b
		matrix list agg_se
		
		preserve
			clear
			svmat agg_b
			svmat agg_se
		
			generate ci_low = agg_b1 + invnormal(`alphaval')*agg_se1
			generate ci_high = agg_b1 + invnormal(1-`alphaval')*agg_se1
		
			generate time_til = 30*_n if inrange(_n, 1, `n_bins'/2)
			replace time_til = -30*(_n-4) if inrange(_n, (`n_bins'/2)+1, `n_bins')
		
			quietly {
				summarize time_til, detail
				local mintime = r(min)
				local maxtime = r(max)
			}
		
			twoway (scatter agg_b1 time_til, color(black)) ///
				(rspike ci_low ci_high time_til, lcolor(black)), ///
				xtitle("days since scandal", size(medium)) xlabel(`mintime'(`bin_width')`maxtime', ///
					nogrid labsize(medium)) ///
				ytitle("average effect", size(medium)) ylabel(, labsize(medium) format(%4.3fc)) ///
				yline(0, lcolor(black)) xline(0, lcolor(black%10) lwidth(vvthick) lpattern(solid)) ///
				legend(order(- "Avg. Effect = `av_est' (`p_string')") pos(4) ring(0) size(medium))
			graph export "${work}/results/figures/bjs_`outcome'_`window'_cxyfe_aggregated_with_month_day_fe_rawmmdata.pdf", replace
		restore
	} /* end loop over outcomes */
} /* end loop over windows */
