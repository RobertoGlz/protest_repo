/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-07-29

    Objective:
        Build the scandal-classification appendix table (sup_scandal_list.tex):
        one row per scandal in the event-window panel with its order-of-
        occurrence number (chronological, by disclosure date -- this replaces
        the internal scandal ID as the public label), country, year, the role of
        the implicated official, a description, and its Apex / Non-Apex class.

    Two things this file does that deserve a note:

    (1) POPULATING MISSING DESCRIPTIONS.
        Four scandals used in the panel have an EMPTY 'summary' in
        scandals_classified.csv (ids 73, 153, TWNEWLATINO14 and NEW23).  The
        classification file simply never received their free text, but the
        scandals were coded from a source: the raw news workbook that fed the
        project, Data/raw/News/Appended_News_v4.xlsx, column "Summary / Text"
        (LexisNexis-sourced rows in sheet "3.Append"/"5.BigScandals"; the
        Twitter-sourced rows in sheet "6.MiddleScandals"/"7.Append").  We
        recover them here and hard-code a concise description (lightly
        translated/trimmed from that source) so the table is reproducible from
        this .do alone.  Each string below is faithful to that raw row.

    (2) NEW23 RECLASSIFICATION (2026-07-29).
        NEW23 (Mexico) had been hand-tagged as a Supreme Court Justice and thus
        promoted to Apex.  Its raw source, however, is a San Luis Potosi
        corruption case involving DIPUTADOS (congressmen) -- it trended after a
        Denise Maerker report and the Google-Trends peak was on the word
        "diputados"; the build file add_catvar_of_level_of_official_involved.do
        already annotates it as "Congressman (diputado)".  Congressmen belong
        in Non-Apex, so NEW23 is removed from the SC-Justice set below.  This
        moves the counts: Other Apex 19->18, Apex 64->63, Non-Apex 112->113.

    Inputs:
        - ${datfin}/scandals_classified.csv
        - ${datfin}/protests_scandals_30days_v3.dta   (for the panel year)

    Output:
        - ${tables}/sup_scandal_list.tex   (longtable, spans multiple pages)
---------------------------------------------------------------------------- */

set more off
clear all

if "`c(username)'" == "lalov" {
	gl identity "C:\Users\lalov\ITAM Seira Research Dropbox\Eduardo Rivera"
}
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox"
}
if "`c(username)'" == "rob98" {
	global identity "~/Dropbox"
}

global path   "${identity}/Corrupcion/WORKING FOLDER/Event Study - Scandals"
global datfin "${path}/Data/final"
global tables "${identity}/Corrupcion/protest_repo/paper/tables"

/* ---- authoritative scandal year AND date from the panel (window == 0) -----
   The disclosure date (window == 0) also fixes the scandal's ORDER OF
   OCCURRENCE, which replaces the internal scandal ID as the public label. */
use "${datfin}/protests_scandals_30days_v3", clear
drop if country == "Venezuela"
gen int _sy = year if window == 0
gen double _sd = date if window == 0
bysort country id: egen scanyear = max(_sy)
bysort country id: egen double scandate = max(_sd)
keep id country scanyear scandate
duplicates drop
tempfile years
save `years'

/* ---- classification file -------------------------------------------------- */
import delimited using "${datfin}/scandals_classified.csv", ///
	clear varnames(1) bindquotes(strict)
keep id country summary position
drop if country == "Venezuela"

/* (1) populate the four blank descriptions from the raw news source --------- */
replace summary = "Fabio Lobo, son of former Honduran president Porfirio Lobo, was arrested on 20 May 2015 for involvement in a drug-trafficking and corruption network." ///
	if id == "73" & country == "Honduras" & summary == ""
replace summary = "Ecuador's Prosecutor's Office charged six people on 3 June 2017 in the Odebrecht case, among them Ricardo Rivera, uncle of Vice-President Jorge Glas." ///
	if id == "153" & country == "Ecuador" & summary == ""
replace summary = "A former manager of Petroecuador (Alex Bravo) was detained on 16 May 2016 for alleged influence peddling." ///
	if id == "TWNEWLATINO14" & country == "Ecuador" & summary == ""
replace summary = "Alleged corruption network involving diputados (congressmen) in San Luis Potosi, Mexico; trended nationally on 21 June 2017 after a Denise Maerker report." ///
	if id == "NEW23" & country == "Mexico" & summary == ""

/* (2) Apex / Non-Apex classification (NEW23 no longer in the SC-Justice set) */
gen byte apex = 0
replace apex = 1 if position == "president"
replace apex = 1 if position == "governor"
replace apex = 1 if position == "sc_judge_congressman" & inlist(id, "202", "NEW26", "NEW30", "332")

/* (2b) Human-readable ROLE of the implicated official, so the reader can see
   the exact basis for the Apex / Non-Apex call (President and Governor and the
   four flagged Supreme Court justices are Apex; everyone else is Non-Apex). */
gen str24 role = "Other official"
replace role = "President"             if position == "president"
replace role = "Governor"              if position == "governor"
replace role = "Supreme Court justice" if position == "sc_judge_congressman" & inlist(id, "202", "NEW26", "NEW30", "332")
replace role = "Congress member"       if position == "sc_judge_congressman" & !inlist(id, "202", "NEW26", "NEW30", "332")
replace role = "Judiciary (lower)"     if position == "other_judiciary"

/* attach the panel year/date, keep the panel scandals */
merge m:1 id country using `years', keep(3) nogenerate

count
di as result "scandals: `r(N)'"
quietly count if apex == 1
di as result "Apex = `r(N)'"
quietly count if apex == 0
di as result "Non-Apex = `r(N)'"

/* ---- clean the description IN THE DATA (vectorised) ----------------------
   Done on the variable, not on a macro, so embedded double quotes/backticks
   in the free text cannot break Stata string parsing later in the loop. */
replace summary = ustrregexra(summary, "[^ -~À-ɏ]", " ")
replace summary = subinstr(summary, char(34), "", .)     /* drop double quotes " */
replace summary = subinstr(summary, char(96), "'", .)    /* backtick -> apostrophe */
replace summary = subinstr(summary, "\", " ", .)
replace summary = subinstr(summary, "{", "(", .)
replace summary = subinstr(summary, "}", ")", .)
replace summary = subinstr(summary, "&gt;", ">", .)
replace summary = subinstr(summary, "&lt;", "<", .)
replace summary = subinstr(summary, "&amp;", " and ", .)
replace summary = ustrregexra(summary, " +", " ")
replace summary = strtrim(summary)

/* ---- ORDER OF OCCURRENCE: chronological rank by disclosure date ----------
   This integer (1..N) replaces the internal scandal ID everywhere the paper
   refers to a scandal (this table and the leave-one-out figures).  Ties on the
   exact date are broken by country then id, deterministically, so the SAME rank
   is reproduced by a_loo_scandal_pa_vs_na.do. */
gsort scandate country id
gen int order = _n
local N = _N

/* ---- write the longtable -------------------------------------------------- */
capture file close _t
file open _t using "${tables}/sup_scandal_list.tex", write replace
file write _t "\begingroup" _n
file write _t "\setstretch{1.0}\footnotesize" _n
file write _t "\setlength{\LTcapwidth}{\textwidth}" _n
file write _t "\begin{longtable}{@{}c p{2.1cm} c p{2.3cm} p{6.4cm} l@{}}" _n
file write _t "\caption{Classification of the 176 scandals in the event-window panel. Scandals are numbered by their order of occurrence (chronological, by disclosure date); the same number labels each scandal in the leave-one-out figures. \textit{Role} is the position of the implicated official and gives the basis for the Apex / Non-Apex classification (President, Governor, and Supreme Court justices are Apex; all other officials are Non-Apex).}\label{tab:sup_scandal_list}\\" _n
file write _t "\toprule" _n
file write _t "\textbf{\#} & \textbf{Country} & \textbf{Year} & \textbf{Role} & \textbf{Description} & \textbf{Class} \\" _n
file write _t "\midrule" _n
file write _t "\endfirsthead" _n
file write _t "\multicolumn{6}{@{}l}{\emph{\tablename~\thetable\ (continued)}}\\" _n
file write _t "\toprule" _n
file write _t "\textbf{\#} & \textbf{Country} & \textbf{Year} & \textbf{Role} & \textbf{Description} & \textbf{Class} \\" _n
file write _t "\midrule" _n
file write _t "\endhead" _n
file write _t "\midrule" _n
file write _t "\multicolumn{6}{r@{}}{\emph{Continued on next page}}\\" _n
file write _t "\endfoot" _n
file write _t "\bottomrule" _n
file write _t "\endlastfoot" _n

forvalues i = 1/`N' {
	local ord = order[`i']
	local ctry = country[`i']
	local yr  = scanyear[`i']
	local rol = role[`i']
	local cls = cond(apex[`i'] == 1, "Apex", "Non-Apex")

	local d = summary[`i']
	/* keep only ASCII-printable + Latin letters (drops emoji, bullets, etc.) */
	local d = ustrregexra("`d'", "[^\u0020-\u007E\u00C0-\u024F]", " ")
	/* remove characters that break Stata parsing / need escaping */
	local d = subinstr("`d'", "\", " ", .)
	local d = subinstr("`d'", "{", "(", .)
	local d = subinstr("`d'", "}", ")", .)
	local d = subinstr("`d'", char(96), "'", .)   /* backtick -> apostrophe */
	/* common HTML entities that appear in the tweet-sourced rows */
	local d = subinstr("`d'", "&gt;", ">", .)
	local d = subinstr("`d'", "&lt;", "<", .)
	local d = subinstr("`d'", "&amp;", " and ", .)
	/* collapse whitespace */
	local d = ustrregexra("`d'", " +", " ")
	local d = strtrim("`d'")
	if "`d'" == "" local d = "(no summary available)"
	/* truncate to ~220 chars at a word boundary, add an ellipsis (kept longer
	   than before for more transparency about who was implicated and why) */
	if ustrlen("`d'") > 220 {
		local d = usubstr("`d'", 1, 220)
		local sp = ustrrpos("`d'", " ")
		if `sp' > 1 local d = usubstr("`d'", 1, `sp' - 1)
		local d = "`d'" + "..."
	}
	/* escape the remaining LaTeX specials */
	local d = subinstr("`d'", "&", "\&", .)
	local d = subinstr("`d'", "%", "\%", .)
	local d = subinstr("`d'", "$", "\$", .)
	local d = subinstr("`d'", "#", "\#", .)
	local d = subinstr("`d'", "_", "\_", .)
	local d = subinstr("`d'", "^", "\textasciicircum{}", .)
	local d = subinstr("`d'", "~", "\textasciitilde{}", .)

	file write _t `"`ord' & `ctry' & `yr' & `rol' & `d' & `cls' \\"' _n
}
file write _t "\end{longtable}" _n
file write _t "\endgroup" _n
file close _t
display in green "sup_scandal_list.tex written (`N' scandals)"
