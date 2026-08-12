/* ----------------------------------------------------------------------------
   Grievance-split replication of the RD-in-event-time evidence.

   TABLE (g_rd_time_panels.tex): two grievance panels (Corruption-related /
   Unrelated), each with the Apex/Non-Apex x {linear, quadratic, nonparametric}
   rows and Violent/Peaceful x h={30,60,90} columns -- i.e. the paper's RD table
   stacked by grievance class.

   FIGURES (g_rd_<margin>_<sample>_h<BW>.pdf): local-linear RD plots that OVERLAY
   corruption-related (black circles, solid black fits) and unrelated (black!45
   squares, short-dashed black!45 fits) on a common vertical scale.

   NOTE: run g_build_grievance_counts.do first.
---------------------------------------------------------------------------- */
set more off
clear all
capture which rdrobust
if _rc ssc install rdrobust, replace
if "`c(username)'" == "rob98" global identity "~/Dropbox"
if "`c(username)'" == "Rob_9" global identity "C:/Users/Rob_9/Dropbox"
global path    "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin  "${path}/Data/final"
global tabout  "${identity}/Corrupcion/protest_repo/paper/tables"
global figout  "${identity}/Corrupcion/protest_repo/paper/figures"
local firstyear = 2008

import delimited using "${datfin}/scandals_classified.csv", clear varnames(1) bindquotes(strict)
keep id country position
tempfile cls
save `cls'
use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
capture confirm string variable id
if _rc==0 {
	drop if id == "TWNEWLATINO14" & country == "Ecuador"
	drop if id == "TWNEWLATINO23" & country == "Brazil"
}
merge m:1 id country using `cls', keep(1 3) generate(_mclass)
merge m:1 country date using "${datfin}/grievance_counts.dta", keep(1 3) generate(_mg)
foreach v in gcorr_v gunrel_v gcorr_p gunrel_p {
	replace `v' = 0 if missing(`v')
}
gen byte in_pa = 0
replace in_pa = 1 if position == "president"
replace in_pa = 1 if position == "governor"
replace in_pa = 1 if position == "sc_judge_congressman" & inlist(id,"202","NEW26","NEW30","332")
gen byte in_na = 0
replace in_na = 1 if position == "sc_judge_congressman" & !inlist(id,"202","NEW26","NEW30","332")
replace in_na = 1 if position == "other_judiciary"
replace in_na = 1 if position == "others"
egen grupo_dias    = group(s_lag30 s_lag60 s_lag90 s_lag120 s_lead30 s_lead60 s_lead90 s_lead120)
egen group_cluster = group(country_id year grupo_dias)
egen auxvar        = group(country year)
gen double rv   = window
gen byte   Post = (window >= 0)
tempfile base
save `base'

/* ---------------- ESTIMATION ---------------- */
tempname R
tempfile rdres
postfile `R' str6 cls str4 sample str4 mrg int bw int poly double tau double se ///
	using "`rdres'", replace
foreach cls in corr unrel {
foreach sample in pa na {
foreach mrg in v p {
	local oc "g`cls'_`mrg'"
	foreach BW in 30 60 90 {
		use `base', clear
		quietly reghdfe `oc' i.Post##c.rv ///
			if year >= `firstyear' & abs(rv) <= `BW' & in_`sample' == 1, ///
			absorb(month day auxvar) cluster(group_cluster)
		post `R' ("`cls'") ("`sample'") ("`mrg'") (`BW') (1) (_b[1.Post]) (_se[1.Post])
		use `base', clear
		quietly reghdfe `oc' i.Post##c.rv i.Post##c.rv#c.rv ///
			if year >= `firstyear' & abs(rv) <= `BW' & in_`sample' == 1, ///
			absorb(month day auxvar) cluster(group_cluster)
		post `R' ("`cls'") ("`sample'") ("`mrg'") (`BW') (2) (_b[1.Post]) (_se[1.Post])
		use `base', clear
		keep if year >= `firstyear' & abs(rv) <= `BW' & in_`sample' == 1
		quietly reghdfe `oc', absorb(month day auxvar) residuals(_ryr)
		capture rdrobust _ryr rv, c(0) kernel(triangular) bwselect(mserd) vce(cluster group_cluster)
		if _rc == 0 post `R' ("`cls'") ("`sample'") ("`mrg'") (`BW') (3) (e(tau_cl)) (e(se_tau_cl))
		else        post `R' ("`cls'") ("`sample'") ("`mrg'") (`BW') (3) (.) (.)
	}
}
}
}
postclose `R'

/* ---------------- TABLE (2 grievance panels) ---------------- */
use "`rdres'", clear
capture file close _tbl
file open _tbl using "${tabout}/g_rd_time_panels.tex", write replace
file write _tbl "{" _n
file write _tbl "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
file write _tbl "\begin{tabular}{ll*{6}{c}}" _n
file write _tbl "\toprule" _n
file write _tbl " & & \multicolumn{3}{c}{Violent Protests} & \multicolumn{3}{c}{Peaceful Protests} \\" _n
file write _tbl "\cmidrule(lr){3-5}\cmidrule(lr){6-8}" _n
file write _tbl " & & \ensuremath{h=30} & \ensuremath{h=60} & \ensuremath{h=90} & \ensuremath{h=30} & \ensuremath{h=60} & \ensuremath{h=90} \\" _n
foreach cls in corr unrel {
	if "`cls'" == "corr" local clab "Panel A: Corruption-related protests"
	else                 local clab "Panel B: Unrelated to corruption"
	file write _tbl "\midrule \multicolumn{8}{l}{\textbf{\textit{`clab'}}}\\" _n
	foreach s in pa na {
		if "`s'" == "pa" local slab "Apex"
		else             local slab "Non-Apex"
		file write _tbl "\multicolumn{8}{l}{\textit{`slab'}}\\" _n
		foreach p in 1 2 3 {
			if `p' == 1      local plab "Local linear"
			else if `p' == 2 local plab "Local quadratic"
			else             local plab "Nonparametric"
			local brow "`plab' &"
			local srow " &"
			foreach mrg in v p {
			foreach BW in 30 60 90 {
				quietly summarize tau if cls=="`cls'" & sample=="`s'" & mrg=="`mrg'" & bw==`BW' & poly==`p', meanonly
				local b = r(mean)
				quietly summarize se if cls=="`cls'" & sample=="`s'" & mrg=="`mrg'" & bw==`BW' & poly==`p', meanonly
				local se = r(mean)
				if missing(`b') | missing(`se') | `se' <= 0 {
					local brow "`brow' & --"
					local srow "`srow' & "
				}
				else {
					local pv = 2*normal(-abs(`b'/`se'))
					local st = ""
					if `pv' < 0.10 local st = "*"
					if `pv' < 0.05 local st = "**"
					if `pv' < 0.01 local st = "***"
					if "`st'" != "" local bcell = string(`b',"%5.3f") + "\sym{`st'}"
					else            local bcell = string(`b',"%5.3f")
					local brow "`brow' & `bcell'"
					local srow = "`srow' & (" + string(`se',"%5.3f") + ")"
				}
			}
			}
			file write _tbl "`brow' \\" _n
			file write _tbl "`srow' \\" _n
		}
	}
}
file write _tbl "\bottomrule" _n
file write _tbl "\end{tabular}" _n
file write _tbl "}" _n
file close _tbl
di as green "g_rd_time_panels.tex written"

/* ---------------- FIGURES (overlay corr vs unrel, local-linear) ---------------- */
local gmax = 0
foreach BW in 30 60 90 {
foreach sample in pa na {
foreach cls in corr unrel {
foreach mrg in v p {
	use `base', clear
	keep if year >= `firstyear' & abs(rv) <= `BW' & in_`sample' == 1
	quietly reghdfe g`cls'_`mrg', absorb(month day auxvar) residuals(_ry0)
	gen int _wb0 = 5 * floor(rv / 5) + 2
	quietly collapse (mean) _ry0, by(_wb0)
	quietly summarize _ry0
	local gmax = max(`gmax', abs(r(min)), abs(r(max)))
}
}
}
}
local yr  = ceil((`gmax' * 1.6) / 0.02) * 0.02
local ylo = -`yr'
local yhi =  `yr'

foreach BW in 30 60 90 {
	local xs = 15
	if `BW' == 90 local xs = 30
foreach sample in pa na {
foreach mrg in v p {
	if "`mrg'" == "v" local mlong "violent"
	else              local mlong "peaceful"
	use `base', clear
	keep if year >= `firstyear' & abs(rv) <= `BW' & in_`sample' == 1
	quietly reghdfe gcorr_`mrg',  absorb(month day auxvar) residuals(ryc)
	quietly reghdfe gunrel_`mrg', absorb(month day auxvar) residuals(ryu)
	gen int wbin = 5 * floor(rv / 5) + 2
	preserve
		collapse (mean) ryc ryu, by(wbin)
		twoway (scatter ryc wbin, mcolor(black) msymbol(O) msize(small)) ///
		       (lfit ryc wbin if wbin < 0,  lcolor(black) lwidth(medthick)) ///
		       (lfit ryc wbin if wbin >= 0, lcolor(black) lwidth(medthick)) ///
		       (scatter ryu wbin, mcolor(black%45) msymbol(S) msize(small)) ///
		       (lfit ryu wbin if wbin < 0,  lcolor(black%45) lwidth(medthick) lpattern(shortdash)) ///
		       (lfit ryu wbin if wbin >= 0, lcolor(black%45) lwidth(medthick) lpattern(shortdash)), ///
			ytitle("Protest count (residualised)", size(medium)) ///
			xtitle("Days since scandal", size(medium)) ///
			xlabel(-`BW'(`xs')`BW') ///
			yscale(range(`ylo' `yhi')) ylabel(`ylo'(0.02)`yhi', format(%4.3fc) angle(horizontal)) ///
			legend(off) graphregion(color(white) fcolor(white)) scheme(s2color)
		graph export "${figout}/g_rd_`mlong'_`sample'_h`BW'.pdf", replace
	restore
	drop ryc ryu wbin
}
}
}
display in green "g_rd_time.do finished OK"
