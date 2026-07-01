/* Diagnostic: exact unrounded coefficients, SEs, t/z stats, and 2-sided
   p-values for all 8 cells of Table 1 (Panel A OLS + Panel B Poisson,
   each with Violent / Peaceful on 30d / 120d windows). */

if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}
global path   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)

global fe1      "i.country_id#i.year"
global CLUSTER2 "cluster i.country_id#i.year#i.grupo_dias"
local firstyear = 2008

display _newline _newline "================================================================"
display "  PANEL A:  OLS via reghdfe"
display "================================================================"

local outcomes "num_violent_MM num_peaceful_MM num_violent_MM num_peaceful_MM"
local windows  "30 30 120 120"
local labels   `""Violent 30d" "Peaceful 30d" "Violent 120d" "Peaceful 120d""'
local nspecs : word count `outcomes'

forvalues k = 1/`nspecs' {
	local outcome : word `k' of `outcomes'
	local window  : word `k' of `windows'
	local lbl     : word `k' of `labels'

	if `window' == 30 {
		quietly reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear' & abs(window) <= 30, ///
			absorb($fe1) vce($CLUSTER2)
	}
	else {
		quietly reghdfe `outcome' post i.month i.day ///
			if year >= `firstyear', ///
			absorb($fe1) vce($CLUSTER2)
	}

	local b   = _b[post]
	local se  = _se[post]
	local t   = `b' / `se'
	local df  = e(df_r)
	local p_t = 2 * ttail(`df', abs(`t'))

	display _newline "  Col `k': `lbl'"
	display "    coef            = " %12.8f `b'
	display "    SE              = " %12.8f `se'
	display "    t-statistic     = " %10.6f `t'
	display "    df_r            = " `df'
	display "    p-value (2-sided, t-dist) = " %10.6f `p_t'
}

display _newline _newline "================================================================"
display "  PANEL B:  Poisson QML via ppmlhdfe"
display "================================================================"

forvalues k = 1/`nspecs' {
	local outcome : word `k' of `outcomes'
	local window  : word `k' of `windows'
	local lbl     : word `k' of `labels'

	if `window' == 30 {
		quietly ppmlhdfe `outcome' post ///
			if year >= `firstyear' & abs(window) <= 30, ///
			absorb(month day $fe1) vce($CLUSTER2)
	}
	else {
		quietly ppmlhdfe `outcome' post ///
			if year >= `firstyear', ///
			absorb(month day $fe1) vce($CLUSTER2)
	}

	local b   = _b[post]
	local se  = _se[post]
	local z   = `b' / `se'
	local p_n = 2 * (1 - normal(abs(`z')))

	/* Implied proportional effect: exp(b) - 1, delta-method SE */
	local imp_b  = exp(`b') - 1
	local imp_se = exp(`b') * `se'

	display _newline "  Col `k': `lbl'"
	display "    log coef        = " %12.8f `b'
	display "    SE              = " %12.8f `se'
	display "    z-statistic     = " %10.6f `z'
	display "    p-value (2-sided, normal) = " %10.6f `p_n'
	display "    Implied Prop Eff= " %10.6f `imp_b'
	display "    delta-method SE = " %10.6f `imp_se'
}
