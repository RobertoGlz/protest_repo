/* Quick diagnostic: get the unrounded coefficient, SE, t-stat, df, and
   p-value for the Violent-Protests / 120-day-window OLS specification
   that appears as ** in Table 1. */

if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}
global path   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"

use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 ///
                        s_lead30 s_lead60 s_lead90 s_lead120)

local firstyear = 2008

reghdfe num_violent_MM post i.month i.day ///
    if year >= `firstyear', ///
    absorb(i.country_id#i.year) ///
    vce(cluster i.country_id#i.year#i.grupo_dias)

display _newline "=== Unrounded inference for Violent / 120d / OLS ==="
display "  coef               = " %12.10f _b[post]
display "  cluster-robust SE  = " %12.10f _se[post]
display "  t-statistic        = " %12.10f _b[post] / _se[post]
display "  df_r (reghdfe)     = " e(df_r)
display "  N clusters         = " e(N_clust)
display "  p-value (normal)   = " %12.10f 2 * (1 - normal(abs(_b[post] / _se[post])))
display "  p-value (t, df_r)  = " %12.10f 2 * ttail(e(df_r), abs(_b[post] / _se[post]))
display "  p-value (t, n_clust - 1) = " %12.10f 2 * ttail(e(N_clust) - 1, abs(_b[post] / _se[post]))
