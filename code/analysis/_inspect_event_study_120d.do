/* Diagnostic: extract the unrounded event-study point estimates and
   standard errors for the +-120-day window, both violent and peaceful
   protests. Bin indicators are 30 days wide: s_lead120, s_lead90,
   s_lead60, s_lead30 (pre) and s_lag30, s_lag60, s_lag90, s_lag120
   (post). One bin is omitted by reghdfe as the reference. */

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

/* leads (pre): s_lead120 ... s_lead30; lags (post): s_lag30 ... s_lag120 */
global leads "s_lead120 s_lead90 s_lead60 s_lead30"
global lags  "s_lag30 s_lag60 s_lag90 s_lag120"

local firstyear = 2008

foreach outcome in num_violent_MM num_peaceful_MM {
	quietly reghdfe `outcome' ${leads} ${lags} i.month i.day ///
		if year >= `firstyear', absorb($fe1) vce($CLUSTER2)

	display _newline _newline "================================================================"
	display "  Event-study coefficients, outcome = `outcome', +-120-day window"
	display "================================================================"
	display "  Bin label             coef             SE              t           p-value(2-sided)"
	display "  ------------------    -----------      -----------     --------    -----------"

	foreach v of varlist ${leads} ${lags} {
		capture local b  = _b[`v']
		capture local se = _se[`v']
		if _rc == 0 & "`b'" != "" {
			local t  = `b' / `se'
			local p  = 2 * ttail(e(df_r), abs(`t'))
			display "  " %-20s "`v'" "    " %10.6f `b' "      " %10.6f `se' "     " %8.4f `t' "    " %10.6f `p'
		}
		else {
			display "  " %-20s "`v'" "    (omitted as reference)"
		}
	}
	display "  df_r = " e(df_r)
}
