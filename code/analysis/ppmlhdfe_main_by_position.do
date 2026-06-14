/* ----------------------------------------------------------------------------
	protests
	
	code author: roberto gonzalez
	date: january 16, 2026
	
	objective: estimate effect of corruption scandals on protests 
---------------------------------------------------------------------------- */

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
local firstyear = 2008

/* Define confidence interval level wanted in coefficient plots */
local ci_level = 90
local alphaval = 0.1

/* Define minimum number of observations required to run regression */
local min_obs = 50

/* Loop analysis over window of days around the event ---------------------- */
foreach numbdays in 90 120 {
	local panelnum = 0
	/* loop analysis over positions */
	foreach pos in "president" "governor" "nonpresgov" /*"sc_judge_congressman" "other_judiciary" "others" */ {
		local ++panelnum
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
	
		/* read in dataset with scandal classifications */
		import delimited using "${datfin}/scandals_classified.csv", clear varnames(1) bindquotes(strict)
		drop date
		
		/* Read in dataset */
		merge 1:m id country using "${datfin}/protests_scandals_30days_v3", keep(3)
		drop if (country == "Venezuela")
		
		replace position = "nonpresgov" if (position != "president" & position != "governor")

		
		/* Create groups with days since/to event */
		egen grupo_dias = group(${lags} ${leads})
		egen group_cluster = group(country_id year grupo_dias)
	
		/* Iterate over outcomes */
		estimates clear
		local y_counter = 0
		foreach outcome in ${outcome_list} {
			/* Message for knowing which outcome is being computed */
			display in yellow "Estimate IRR for `outcome' in scandals for `pos'"
			/* Add one to outcome counter */
			local ++y_counter
			
			/* Count observations in subsample */
			count if year >= `firstyear' & position == "`pos'" & !missing(`outcome')
			local nobs = r(N)
			
			/* summarize outcome */
			summarize `outcome' if year >= `firstyear' & position == "`pos'" & !missing(`outcome')
			local outvariance = r(sd)^2
			
			/* Check if there are enough observations to run regression */
			if `nobs' < `min_obs' | `outvariance' == 0 {
				display in red "Insufficient observations (`nobs') for `outcome' with position `pos'. Skipping regression."
				
			}
			else {
				/* Estimate average coefficient */
				eststo m_`y_counter'_`numbdays' : ppmlhdfe `outcome' post ///
					if year >= `firstyear' & position == "`pos'", absorb(month day ${CY_fe}) vce(cluster group_cluster) irr
				local av_est = string(exp(_b[post]), "%3.2fc")
				local p_av_est = 2*normal(-abs(_b[post]/_se[post]))
				if `p_av_est' < 0.01 {
					local p_string = "p < 0.01"
				}
				else {
					local p_string = "p = " + string(`p_av_est', "%4.3fc")
				}
				quietly {
					/* Estimate IRR (exp{b}) with poisson regression and export coefficient plot */
					ppmlhdfe `outcome' ${leads} ${lags} ///
						if year >= `firstyear' & position == "`pos'", absorb(month day ${CY_fe})  vce(cluster group_cluster) irr
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
				"${work}/results/figures/ppmlhdfe_es_`outcome'_`numbdays'window_since`firstyear'_overlaps_`ci_level'ci_`pos'.png", ///
					replace
			}
		}
		/* Export table */
		esttab _all using Panel_`panelnum'.tex, replace b(3) se(3) booktabs ///
		star(* 0.1 ** 0.05 *** 0.01) nonotes ///
		stats(N, labels("Observations") fmt(0 0 3)) ///
		keep(post) varlabels(post "1(Post Scandal = 1)") ///
		mtitles("\shortstack{Violent \\ Protests}" "\shortstack{Non-violent \\ Protests}" "\shortstack{Gvt. Violent \\ Response}")
	}
	
	panelcombine, use(Panel_1.tex Panel_2.tex Panel_3.tex /*Panel_4.tex Panel_5.tex*/) ///
	columncount(3) paneltitles("President" "Governor" "Others" /*"SC Judge - Congressman" "Other Judiciary" "Others"*/) ///
	save("${work}/results/tables/ppmlhdfe_es_`numbdays'window_since`firstyear'_overlaps_`ci_level'ci_panels_byposition.tex") cleanup
}
