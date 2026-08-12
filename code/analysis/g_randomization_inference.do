/* ----------------------------------------------------------------------------
   Grievance-split replication of the randomization-inference test.

   Same permutation design as a_randomization_inference_pa_vs_na.do, but the
   outcome is one of the four grievance counts (gcorr_v, gunrel_v, gcorr_p,
   gunrel_p), estimated on the Apex (pa) and Non-Apex (na) subsamples at
   T in {30,60,90}. One placebo histogram per (outcome, T, sample).

   Output figures (paper/figures/): g_ri_hist_<outcome>_w<T>_<sample>.pdf
   NOTE: run g_build_grievance_counts.do first.
---------------------------------------------------------------------------- */
set more off
clear all
set seed 20260713
if "`c(username)'" == "rob98" global identity "~/Dropbox"
if "`c(username)'" == "Rob_9" global identity "C:/Users/Rob_9/Dropbox"
global path    "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin  "${path}/Data/final"
global work    "${identity}/Corrupcion/Protest_Work"
global resout  "${work}/results"
global figout  "${identity}/Corrupcion/protest_repo/paper/figures"

local outcome_list = "gcorr_v gunrel_v gcorr_p gunrel_p"
local firstyear    = 2008
local n_reps       = 1000
local sample_list  = "pa na"

/* ---- STEP 1: balanced country-day panel + grievance counts ---- */
use "${work}/temp/MM/MMclean_full_bydate.dta", clear
drop if country == "Venezuela"
capture confirm string variable id
if _rc==0 {
	drop if id == "TWNEWLATINO14" & country == "Ecuador"
	drop if id == "TWNEWLATINO23" & country == "Brazil"
}
rename num_violent  num_violent_MM
rename num_peaceful num_peaceful_MM
rename num_protests num_protests_MM
egen country_id = group(country)
preserve
	keep country_id country
	duplicates drop
	tempfile _cw
	save `_cw'
restore
tsset country_id date
tsfill, full
drop country
merge m:1 country_id using `_cw', nogenerate
foreach v in num_violent_MM num_peaceful_MM num_protests_MM {
	replace `v' = 0 if missing(`v')
}
merge m:1 country date using "${datfin}/grievance_counts.dta", keep(1 3) nogenerate
foreach v in gcorr_v gunrel_v gcorr_p gunrel_p {
	replace `v' = 0 if missing(`v')
}
gen year  = year(date)
gen month = month(date)
gen day   = dow(date)
tempfile day_panel
save `day_panel'

/* ---- STEP 2: scandal list + apex flags ---- */
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
gen byte in_pa = 0
replace in_pa = 1 if position == "president"
replace in_pa = 1 if position == "governor"
replace in_pa = 1 if position == "sc_judge_congressman" & inlist(id,"202","NEW26","NEW30","332")
gen byte in_na = 0
replace in_na = 1 if position == "sc_judge_congressman" & !inlist(id,"202","NEW26","NEW30","332")
replace in_na = 1 if position == "other_judiciary"
replace in_na = 1 if position == "others"
egen grupo_dias = group(s_lag30 s_lag60 s_lag90 s_lag120 s_lead30 s_lead60 s_lead90 s_lead120)
tempfile obs_panel
save `obs_panel'

preserve
	keep if window == 0
	keep id country year in_pa in_na
	duplicates drop id country, force
	tempfile scandal_list
	save `scandal_list'
restore
preserve
	use `day_panel', clear
	bysort country: keep if _n == 1
	keep country country_id
	tempfile cid_lookup
	save `cid_lookup'
restore
use `scandal_list', clear
merge m:1 country using `cid_lookup', keep(1 3) nogenerate
save `scandal_list', replace
preserve
	use `obs_panel', clear
	keep if window == 0
	keep country_id date
	duplicates drop
	rename date real_date
	tempfile real_dates_by_country
	save `real_dates_by_country'
restore
preserve
	use `day_panel', clear
	bysort country: keep if _n == 1
	keep country_id country
	quietly count
	local n_countries = r(N)
	tempfile cid_to_name
	save `cid_to_name'
restore

local date_lo    = mdy(1, 1, `firstyear')
local date_hi    = mdy(12, 31, 2019)
local date_range = `date_hi' - `date_lo' + 1
local max_cy_attempts     = 20
local max_uncond_attempts = 30
local max_att : display `max_cy_attempts' + `max_uncond_attempts'

/* ---- STEP 3: loop (subsample, outcome, window) ---- */
foreach sample of local sample_list {
foreach outcome of local outcome_list {
foreach T in 30 60 90 {

	local win_size = 2*`T' + 1
	use `obs_panel', clear
	merge m:1 country date using "${datfin}/grievance_counts.dta", keep(1 3) nogenerate
	foreach v in gcorr_v gunrel_v gcorr_p gunrel_p {
		replace `v' = 0 if missing(`v')
	}
	quietly reghdfe `outcome' post i.month i.day ///
		if year >= `firstyear' & abs(window) <= `T' & in_`sample' == 1, ///
		absorb(i.country_id#i.year) vce(cluster i.country_id#i.year#i.grupo_dias)
	local observed_beta_T = _b[post]

	matrix betas = J(`n_reps', 1, .)
	quietly {
	forvalues r = 1/`n_reps' {
		use `scandal_list', clear
		keep if in_`sample' == 1
		gen scandal_id = _n
		gen rday         = int(runiform()*365) + 1
		gen scandal_date = mdy(1, 1, year) + rday - 1
		drop rday
		forvalues att = 1/`max_att' {
			preserve
				keep scandal_id country_id scandal_date
				joinby country_id using `real_dates_by_country'
				gen dist = abs(scandal_date - real_date)
				collapse (min) mindist=dist, by(scandal_id)
				tempfile _chk
				save `_chk'
			restore
			merge 1:1 scandal_id using `_chk', keep(1 3) nogenerate
			gen byte bad = (mindist <= `T')
			drop mindist
			quietly count if bad == 1
			if r(N) == 0 {
				drop bad
				continue, break
			}
			if `att' <= `max_cy_attempts' {
				gen rday = int(runiform()*365) + 1 if bad == 1
				replace scandal_date = mdy(1, 1, year) + rday - 1 if bad == 1
				drop rday
			}
			else {
				gen rday = int(runiform() * `date_range') if bad == 1
				replace scandal_date = `date_lo' + rday if bad == 1
				gen rcid = 1 + int(runiform() * `n_countries') if bad == 1
				replace country_id = rcid if bad == 1
				drop country
				merge m:1 country_id using `cid_to_name', keep(1 3) nogenerate
				drop rday rcid
			}
			drop bad
		}
		expand `win_size'
		bysort scandal_id: gen window = _n - `T' - 1
		gen date = scandal_date + window
		drop scandal_date
		drop country_id
		merge m:1 country date using `day_panel', keep(1 3) nogenerate
		gen post = (window >= 0)
		keep if year >= `firstyear'
		drop if missing(`outcome')
		capture reghdfe `outcome' post i.month i.day, absorb(i.country_id#i.year) vce(robust)
		if _rc == 0 & !missing(_b[post]) matrix betas[`r', 1] = _b[post]
	}
	}

	clear
	svmat betas, names(beta_)
	rename beta_1 beta_placebo
	save "${resout}/g_ri_beta_`outcome'_w`T'_`sample'.dta", replace

	quietly count if !missing(beta_placebo)
	local n_valid = r(N)
	quietly count if !missing(beta_placebo) & abs(beta_placebo) >= abs(`observed_beta_T')
	local ri_p_two = r(N) / `n_valid'
	local obs_str = string(`observed_beta_T', "%5.3f")
	local p2_str  = string(`ri_p_two',        "%5.3f")

	if "`outcome'" == "gcorr_v"  local outlbl "corruption-related violent protests"
	if "`outcome'" == "gunrel_v" local outlbl "unrelated violent protests"
	if "`outcome'" == "gcorr_p"  local outlbl "corruption-related peaceful protests"
	if "`outcome'" == "gunrel_p" local outlbl "unrelated peaceful protests"

	gen double _leg_beta = .
	gen double _leg_p    = .
	quietly summarize beta_placebo
	local xlo = min(r(min), `observed_beta_T', 0)
	local xhi = max(r(max), `observed_beta_T', 0)
	local xrng = `xhi' - `xlo'
	if `xrng' <= 0 local xrng = 0.01
	local xlo = `xlo' - 0.10*`xrng'
	local xhi = `xhi' + 0.10*`xrng'
	local xraw = (`xhi' - `xlo')/5
	local xmag = 10 ^ floor(log10(`xraw'))
	local xmul = `xraw'/`xmag'
	if `xmul' < 1.5      local xstep = 1  * `xmag'
	else if `xmul' < 3.5 local xstep = 2  * `xmag'
	else if `xmul' < 7.5 local xstep = 5  * `xmag'
	else                 local xstep = 10 * `xmag'
	local xlo_t = floor(`xlo'/`xstep')*`xstep'
	local xhi_t = ceil( `xhi'/`xstep')*`xstep'
	quietly summarize beta_placebo
	local _bmin = r(min)
	local _bw   = (r(max) - r(min))/50
	if `_bw' <= 0 local _bw = 1
	capture drop _rbin _rbc
	gen double _rbin = min(floor((beta_placebo - `_bmin')/`_bw'), 49)
	quietly count
	local _N = r(N)
	bysort _rbin: gen long _rbc = _N
	quietly summarize _rbc
	local _ymax = 100 * r(max)/`_N' * 1.04

	twoway (histogram beta_placebo, percent bin(50) color(gs13) lcolor(gs10)) ///
	       (line _leg_beta beta_placebo, lcolor("128 0 0") lwidth(medthick)) ///
	       (line _leg_p    beta_placebo, lcolor(none)) ///
	       (pci 0 `observed_beta_T' `_ymax' `observed_beta_T', lcolor("128 0 0") lwidth(medthick)), ///
		xline(0, lcolor(black) lwidth(vthin) lpattern(dot)) ///
		xtitle("Effect on `outlbl'", size(medium)) ytitle("Percent", size(medium)) ///
		xscale(range(`xlo_t' `xhi_t')) ///
		xlabel(`xlo_t'(`xstep')`xhi_t', format(%5.3f) labsize(small)) ///
		ylabel(, angle(0) format(%3.0f)) ///
		legend(order(2 3) label(2 "Observed {&beta} = `obs_str'") label(3 "RI p = `p2_str'") ///
		       cols(1) pos(2) ring(0) region(lcolor(black) fcolor(white)) size(medsmall)) ///
		scheme(s2color) graphregion(color(white))
	graph export "${figout}/g_ri_hist_`outcome'_w`T'_`sample'.pdf", replace
	di as green "wrote g_ri_hist_`outcome'_w`T'_`sample'.pdf"
}
}
}
display in green "g_randomization_inference.do finished OK"
