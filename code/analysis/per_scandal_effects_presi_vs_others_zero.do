/* ----------------------------------------------------------------------------
                        Violent effects of apex corruption
        Per-scandal box / jitter plots: President vs Others,
        ZERO-IMPUTED variant.

    Code author: Roberto Gonzalez
    Date: 2026-06-28

    Difference from per_scandal_effects_presi_vs_others.do:
        Scandals whose outcome has zero within-window variation are
        entered into the box plot at b_s = 0 rather than being silently
        dropped by the regression's SE filter.

    Outputs (under ${work}/results/figures/):
        per_scandal_box_<outcome>_w30_presi_zero.pdf
        per_scandal_jitter_<outcome>_w30_presi_zero.pdf
---------------------------------------------------------------------------- */

if "`c(username)'" == "lalov" {
	gl identity "C:/Users/lalov/ITAM Seira Research Dropbox/Eduardo Rivera"
}
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox"
}
if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}

global work   "${identity}/Corrupcion/Protest_Work"
global path   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"
global resout "${work}/results"
global figout "${work}/results/figures"

local window_length = 30
local outcome_list = "num_protests_MM num_violent_MM num_peaceful_MM government_response_violent"
local outcome_number : word count `outcome_list'
local ci_level = 95
local zcrit = invnormal(1 - (100-`ci_level')/200)

use "${datfin}/protests_scandals_30days_v3_with_lv_of_agent_involved.dta", clear
drop if country == "Venezuela"
keep if abs(window) <= `window_length'

egen scandal_enc = group(id)
egen scandal_tag = tag(id)

gen double _sd = date if window == 0
bysort scandal_enc (_sd): replace _sd = _sd[1]
format _sd %td

bysort scandal_enc: egen _pm = mean(post)
drop if _pm == 0 | _pm == 1
drop _pm

quietly levelsof scandal_enc, local(slevels)
local n_scandals : word count `slevels'
display in yellow "Per-scandal regressions: `n_scandals' scandals (ZERO-IMPUTED)"

preserve
	keep if scandal_tag == 1
	keep scandal_enc id country official_involved _sd
	rename _sd scandal_date
	tempfile metadata
	save `metadata'
restore

matrix define scandal_info = J(`n_scandals', 3*`outcome_number', .)
matrix define zero_flag    = J(`n_scandals',   `outcome_number', 0)

forvalues s = 1/`n_scandals' {
	local oc = 0
	foreach outcome of local outcome_list {
		local ++oc
		quietly summarize `outcome' if scandal_enc == `s'
		local n_obs  = r(N)
		local sd_out = cond(r(N) > 1, r(sd), .)
		if `n_obs' > 30 {
			if `sd_out' == 0 & !missing(`sd_out') {
				matrix scandal_info[`s', 3*`oc'-2] = 0
				matrix scandal_info[`s', 3*`oc'-1] = .
				matrix scandal_info[`s', 3*`oc']   = `n_obs'
				matrix zero_flag[`s', `oc']        = 1
			}
			else {
				capture reghdfe `outcome' post if scandal_enc == `s', ///
					absorb(month day) vce(robust)
				if _rc == 0 & !missing(_b[post]) & _se[post] < . & _se[post] > 0 {
					matrix scandal_info[`s', 3*`oc'-2] = _b[post]
					matrix scandal_info[`s', 3*`oc'-1] = _se[post]
					matrix scandal_info[`s', 3*`oc']   = `n_obs'
				}
			}
		}
	}
}

clear
svmat scandal_info
svmat zero_flag, names(zflag)
generate scandal_enc = _n
merge 1:1 scandal_enc using `metadata', nogenerate

local oc = 0
foreach outcome of local outcome_list {
	local ++oc
	rename scandal_info`=3*`oc'-2' b_`outcome'
	rename scandal_info`=3*`oc'-1' se_`outcome'
	rename scandal_info`=3*`oc''   n_`outcome'
	rename zflag`oc' zero_`outcome'
}

preserve
	import delimited using "${datfin}/scandals_classified.csv", ///
		clear varnames(1) bindquotes(strict)
	keep id country position
	tempfile cls
	save `cls'
restore
merge 1:1 id country using `cls', keep(1 3) nogenerate

gen byte presi = .
replace presi = 1 if position == "president"
replace presi = 2 if !missing(position) & position != "president"
label define PRESI 1 "President" 2 "Others", replace
label values presi PRESI

order scandal_enc id country official_involved position presi scandal_date ///
	b_* se_* n_* zero_*
compress
save "${resout}/per_scandal_effects_w`window_length'_presi_zero.dta", replace

display _newline "=== Zero-imputed counts per outcome ==="
foreach outcome of local outcome_list {
	quietly count if zero_`outcome' == 1
	display "    `outcome': " r(N) " zero-imputed"
}

foreach outcome of local outcome_list {

	if "`outcome'" == "num_protests_MM"             local ytitle "protests (any)"
	if "`outcome'" == "num_violent_MM"              local ytitle "violent protests"
	if "`outcome'" == "num_peaceful_MM"             local ytitle "peaceful protests"
	if "`outcome'" == "government_response_violent" local ytitle "gvt. violent response"

	display in yellow "=== Per-scandal `outcome': President vs Others (zero-imputed) ==="
	tabstat b_`outcome', by(presi) ///
		statistics(n mean p50 sd min max) columns(statistics)

	quietly levelsof presi, local(__cats)
	local med_note `""'
	foreach c of local __cats {
		quietly summarize b_`outcome' if presi == `c', detail
		local __mstr = string(r(p50), "%5.3f")
		quietly count if !missing(b_`outcome') & presi == `c'
		local __nstr = r(N)
		local __lbl : label PRESI `c'
		local med_note `"`med_note' "Median `__lbl' = `__mstr'     (Scandals = `__nstr')""'
	}

	graph box b_`outcome', over(presi, label(labsize(large))) ///
		nooutsides ///
		ytitle("Per-scandal effect on `ytitle'", size(medlarge)) ///
		ylabel(, format(%4.2f) angle(0) labsize(large)) ///
		yline(0, lpattern(dash) lcolor(gs8)) ///
		note(`med_note', size(medlarge)) ///
		medtype(line) ///
		box(1, lcolor(black) lwidth(thick)) ///
		box(2, lcolor(black) lwidth(thick)) ///
		scheme(s2color) graphregion(color(white))
	graph export ///
		"${figout}/per_scandal_box_`outcome'_w`window_length'_presi_zero.pdf", replace

	preserve
		keep if !missing(b_`outcome') & !missing(presi) & !missing(se_`outcome')
		generate double prec = 1 / se_`outcome'^2
		quietly summarize prec
		replace prec = prec / r(max)

		quietly levelsof presi, local(cats)
		gen double cmean = .
		gen double clo   = .
		gen double chi   = .
		foreach c of local cats {
			quietly count if presi == `c'
			if r(N) >= 2 {
				quietly mean b_`outcome' if presi == `c'
				matrix mb = r(table)
				quietly replace cmean = mb[1,1] if presi == `c'
				quietly replace clo   = mb[5,1] if presi == `c'
				quietly replace chi   = mb[6,1] if presi == `c'
			}
		}

		twoway ///
			(scatter b_`outcome' presi [aw=prec], ///
				jitter(8) mcolor(navy%35) msymbol(O)) ///
			(rcap clo chi presi, lcolor(black) lwidth(medthick)) ///
			(scatter cmean presi, mcolor(black) msymbol(D) msize(medlarge)), ///
			yline(0, lpattern(dash) lcolor(gs8)) ///
			ytitle("Per-scandal effect on `ytitle'") ///
			xtitle("Type of official involved") ///
			xlabel(1 "President" 2 "Others", noticks) ///
			xscale(range(0.5 2.5)) ///
			ylabel(, format(%4.2f) angle(0)) ///
			legend(order(3 "Category mean" 2 "95% CI" 1 "Per-scandal b") ///
				pos(1) ring(0) region(lcolor(gs10)) size(small) cols(1)) ///
			note("Each point is one scandal; marker size proportional to 1/SE^2." ///
				"Narrow +-`window_length'-day window; zero-variation scandals excluded from jitter.") ///
			scheme(s2color) graphregion(color(white))
		graph export ///
			"${figout}/per_scandal_jitter_`outcome'_w`window_length'_presi_zero.pdf", replace
	restore
}

display in green "per_scandal_effects_presi_vs_others_zero.do finished OK"
