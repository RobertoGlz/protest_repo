/* ----------------------------------------------------------------------------
   Project: Apex corruption protests paper

   Code author: Roberto Gonzalez
   Date: 2026-06-28

   Objective:
        Plot the RAW count of protests by time-to-scandal in 3-day bins
        (matching the Latinobarometro modern-DiD bin convention used
        elsewhere in the project). For each 3-day event-time bin we sum
        the daily country-level protest counts across all 176 scandals,
        so the y-axis is the total number of protests recorded in the
        country-day panel cells inside that 3-day bin (a non-negative
        integer), and the x-axis is the bin midpoint in days.

        Four outcomes are produced:
           num_protests_MM             -- any protests
           num_violent_MM              -- violent protests
           num_peaceful_MM             -- peaceful protests
           government_response_violent -- government's violent response

        Two windows: +-30 days and +-120 days.

   Inputs:
        - ${datfin}/protests_scandals_30days_v3.dta

   Outputs (in ${work}/results/figures/):
        raw_count_<outcome>_w<window>.pdf   (8 files; 4 outcomes x 2 windows)
---------------------------------------------------------------------------- */

set more off
clear all

/* ----------------------- User-specific paths ----------------------- */
if "`c(username)'" == "Diego" {
	gl identity "D:/Documents/Dropbox"
}
if "`c(username)'" == "dtocre" {
	gl identity "C:/Users/dtocre/Dropbox"
}
if "`c(username)'" == "lalov" {
	gl identity "C:/Users/lalov/ITAM Seira Research Dropbox/Eduardo Rivera"
}
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox"
}
if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}

global path   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"
global work   "${identity}/Corrupcion/Protest_Work"
global figout "${work}/results/figures"

/* --------------- Read the event-window panel --------------- */
use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
keep if year >= 2008

/* --------------- Sanity check ---------------
   Each scandal contributes one country-day at every value of window in
   [-120, 120]; with 176 scandals, the count at each window value should
   be at most 176.
   ------------------------------------------- */
quietly levelsof id, local(_ids)
local n_scandals : word count `_ids'
display in yellow "Number of scandals: `n_scandals'"

/* --------------- 3-day binning ---------------
   bin = floor(window/3) -- matches the project's Latinobarometro modern-
   DiD convention. bin_mid = 3*bin + 1 is the midpoint of the 3-day range
   the bin covers, used as the x-axis position of the bar. E.g.,
        bin =  0 covers days {0, 1, 2}, plotted at x = 1
        bin = -1 covers days {-3, -2, -1}, plotted at x = -2
        bin = 10 covers days {30, 31, 32}; only day 30 is in the data
   The bin furthest from zero may therefore aggregate fewer than 3 days
   on each side; this is the standard edge effect of the floor-binning.
   --------------------------------------------- */
gen bin     = floor(window/3)
gen bin_mid = 3*bin + 1

/* --------------- Collapse to one row per 3-day bin --------------- */
collapse (sum)    sum_protests = num_protests_MM ///
                  sum_violent  = num_violent_MM ///
                  sum_peaceful = num_peaceful_MM ///
                  sum_gvtresp  = government_response_violent ///
        (count)   n_obs        = num_protests_MM, ///
        by(bin bin_mid)

quietly summarize n_obs
display in yellow "Min/Max contributing country-days per 3-day bin: " ///
    r(min) " / " r(max)

display _newline "=== 3-day-binned totals around scandal (sample: |bin_mid| <= 6) ==="
list bin bin_mid n_obs sum_protests sum_violent sum_peaceful sum_gvtresp ///
    if abs(bin_mid) <= 6, noobs

/* --------------- Bar plots, 4 outcomes x 2 windows ---------------
   Twoway with two bar series: navy for the pre-scandal period
   (bin_mid < 0) and maroon for the post-scandal period (bin_mid >= 0).
   Pre/post is determined by the scandal date (window = 0), which falls
   inside bin 0 (days 0, 1, 2). Bin 0's midpoint is bin_mid = 1, so
   bin_mid >= 0 captures the post-scandal bins.
--------------------------------------------------------------------- */
foreach outcome in protests violent peaceful gvtresp {

	if "`outcome'" == "protests" local outlbl "protests"
	if "`outcome'" == "violent"  local outlbl "violent protests"
	if "`outcome'" == "peaceful" local outlbl "peaceful protests"
	if "`outcome'" == "gvtresp"  local outlbl "violent gvt. responses"

	foreach win in 30 120 {

		/* x-axis tick step: 6-day ticks on +-30, 30-day on +-120 */
		local tick = cond(`win' == 30, 6, 30)

		twoway (bar sum_`outcome' bin_mid ///
		            if abs(bin_mid) <= `win' & bin_mid < 0, ///
		            barwidth(2.85) color(navy*0.6) lcolor(navy)) ///
		       (bar sum_`outcome' bin_mid ///
		            if abs(bin_mid) <= `win' & bin_mid >= 0, ///
		            barwidth(2.85) color(maroon) lcolor(maroon*1.3)), ///
		    xline(0, lcolor(black) lpattern(dash) lwidth(medthick)) ///
		    yline(0, lcolor(gs10) lwidth(vthin)) ///
		    xlabel(-`win'(`tick')`win', labsize(medsmall)) ///
		    xtitle("Time-to-scandal", size(medium)) ///
		    ytitle("Total `outlbl'", size(medium)) ///
		    ylabel(, format(%4.0f) angle(0) labsize(medsmall)) ///
		    legend(off) ///
		    note("Raw count of `outlbl' aggregated to 3-day bins (bin = floor(t/3)*3+1)" ///
		         "summed across all `n_scandals' apex corruption scandals" ///
		         "(post-2008, Venezuela excluded). Maroon = post-scandal bins.") ///
		    scheme(s2color) graphregion(color(white))
		graph export "${figout}/raw_count_`outcome'_w`win'.pdf", replace
	}
}

display in green "a_raw_protest_count.do finished OK"
