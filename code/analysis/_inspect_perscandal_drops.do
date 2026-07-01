/* Quick diagnostic: of the 176 scandals, how many drop out of the
   per-scandal boxplot for each outcome and why?

   We re-trace the filter inside per_scandal_effects_apex_v2.do:
        (a) need > 30 non-missing observations of outcome in the
            scandal's +-30-day window;
        (b) reghdfe must converge (rc == 0);
        (c) _b[post] and _se[post] must be finite and SE > 0.

   For each scandal, we tag which filter killed it. */

if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}
global path   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"

use "${datfin}/protests_scandals_30days_v3_with_lv_of_agent_involved.dta", clear
drop if country == "Venezuela"
keep if abs(window) <= 30
egen scandal_enc = group(id)

quietly levelsof scandal_enc, local(slevels)
local n_scandals : word count `slevels'

/* For each outcome, build per-scandal status flags */
foreach outcome in num_protests_MM num_violent_MM num_peaceful_MM {
	preserve
		matrix DR = J(`n_scandals', 5, .)
		/* columns: nobs, sd_outcome, rc, b_post, se_post */
		forvalues s = 1/`n_scandals' {
			quietly count if !missing(`outcome') & scandal_enc == `s'
			matrix DR[`s', 1] = r(N)
			quietly summarize `outcome' if scandal_enc == `s'
			matrix DR[`s', 2] = r(sd)
			if r(N) > 30 {
				capture reghdfe `outcome' post if scandal_enc == `s', ///
					absorb(month day) vce(robust)
				matrix DR[`s', 3] = _rc
				if _rc == 0 {
					matrix DR[`s', 4] = _b[post]
					matrix DR[`s', 5] = _se[post]
				}
			}
		}
		clear
		svmat DR
		rename (DR1 DR2 DR3 DR4 DR5) (nobs sd_out rc b_post se_post)
		gen byte filt = .
		replace filt = 1 if nobs <= 30
		replace filt = 2 if filt == . & rc != 0
		replace filt = 3 if filt == . & (missing(b_post) | missing(se_post))
		replace filt = 4 if filt == . & se_post == 0
		replace filt = 0 if filt == . & se_post > 0 & !missing(b_post)
		label define FILT 0 "Kept" 1 "Too few obs (nobs<=30)" ///
			2 "reghdfe rc!=0" 3 "missing b/se" 4 "se_post==0 (no variance)", replace
		label values filt FILT
		display _newline "=== Drop diagnostics for `outcome' ==="
		tab filt, missing
		display _newline "    Outcome SD distribution among DROPPED scandals (filt!=0):"
		tabstat sd_out if filt != 0, statistics(n mean p50 min max)
		display _newline "    Outcome SD distribution among KEPT scandals (filt==0):"
		tabstat sd_out if filt == 0, statistics(n mean p50 min max)
	restore
}
