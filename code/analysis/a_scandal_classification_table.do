/* ----------------------------------------------------------------------------
                    Violent effects of apex corruption

    Code author: Roberto Gonzalez
    Date: 2026-07-29

    Objective:
        Build the scandal-classification appendix table (sup_scandal_list.tex):
        a LANDSCAPE longtable, one row per scandal in the event-window panel:
        country, year, a description, and its Apex / Non-Apex class.  Rows are
        ordered by disclosure date (order of occurrence) -- the same ordering
        used to number the scandals in the leave-one-out figures -- but the
        number itself is not printed as a column.

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

/* (0) enriched descriptions for 168 scandals (auto-generated from the research
   workflow; full detail and sources in paper/scandal_descriptions_sources.md).
   Runs first so the blank-description back-fills below still fire on the four
   empty summaries, and the sample block (1b) overrides where present. --------- */
do "scandal_enriched_descriptions.do"

/* (1) populate the four blank descriptions from the raw news source --------- */
replace summary = "Fabio Lobo, son of former Honduran president Porfirio Lobo, was arrested on 20 May 2015 for involvement in a drug-trafficking and corruption network." ///
	if id == "73" & country == "Honduras" & summary == ""
replace summary = "Ecuador's Prosecutor's Office charged six people on 3 June 2017 in the Odebrecht case, among them Ricardo Rivera, uncle of Vice-President Jorge Glas." ///
	if id == "153" & country == "Ecuador" & summary == ""
replace summary = "A former manager of Petroecuador (Alex Bravo) was detained on 16 May 2016 for alleged influence peddling." ///
	if id == "TWNEWLATINO14" & country == "Ecuador" & summary == ""
replace summary = "Alleged corruption network involving diputados (congressmen) in San Luis Potosi, Mexico; trended nationally on 21 June 2017 after a Denise Maerker report." ///
	if id == "NEW23" & country == "Mexico" & summary == ""

/* (1b) enriched descriptions -- rewritten to a uniform who/what/when/outcome
   template from verifiable sources; full detail and citations for each are in
   paper/scandal_descriptions_sources.md.  (Sample batch; more to follow.) ----- */
replace summary = "President Enrique Pena Nieto was implicated in the Casa Blanca conflict-of-interest scandal, revealed on 9 November 2014 by journalist Carmen Aristegui: the president's family occupied an 86-million-peso (about 7-million-dollar) Mexico City mansion built and financed by Grupo Higa, a state contractor favoured by his administration. An official inquiry cleared him in 2015; the affair became emblematic of his presidency." ///
	if id == "64" & country == "Mexico"
replace summary = "President Michel Temer was implicated on 17 May 2017 when a covert recording released through the JBS (Batista brothers) plea bargain appeared to capture him endorsing hush-money payments to jailed former House speaker Eduardo Cunha. Prosecutors charged him with passive corruption and obstruction; the Chamber of Deputies twice voted to block his trial, and he was briefly arrested in March 2019 in a separate Lava Jato operation." ///
	if id == "104" & country == "Brazil"
replace summary = "Cesar Alvarez, regional president (governor) of Ancash from 2007 to 2014, was arrested in May 2014 as the alleged head of the La Centralita criminal network, which rigged public-works contracts for bribes and ordered killings of political opponents. He was later sentenced to 19.5 years for criminal association and money laundering, and separately to 35 years as the mastermind of the murder of former councillor Ezequiel Nolasco." ///
	if id == "58" & country == "Peru"
replace summary = "Senator Antonio Jose Correa was the first legislator named in Colombia's mermelada toxica (toxic pork-barrel) scandal: on 5 July 2018 the Prosecutor's Office referred him for allegedly taking a roughly 12-percent kickback on a 3.49-billion-peso Coldeportes sports-infrastructure contract. In 2023 the Supreme Court charged him with aggravated conspiracy, concussion, influence peddling and improper interest in contracting." ///
	if id == "TWNEWLATINO13" & country == "Colombia"

/* (2) Apex / Non-Apex classification (NEW23 no longer in the SC-Justice set) */
gen byte apex = 0
replace apex = 1 if position == "president"
replace apex = 1 if position == "governor"
replace apex = 1 if position == "sc_judge_congressman" & inlist(id, "202", "NEW26", "NEW30", "332")

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
/* strip tweet artifacts that do not wrap and overflow the description column:
   URLs (http/https, incl. t.co short links and archive.org) and @-mentions.
   Also drop a dangling "via" left after removing a trailing "via @handle". */
replace summary = ustrregexra(summary, "https?://[^ ]+", "")
replace summary = ustrregexra(summary, "@[A-Za-z0-9_]+", "")
replace summary = ustrregexra(summary, " [Vv][ií]a *$", "")
replace summary = ustrregexra(summary, " *\.\.+ *", " ")
replace summary = ustrregexra(summary, " +", " ")
replace summary = strtrim(summary)
replace summary = "(no summary available)" if summary == ""

/* ---- truncate to ~300 chars at a word boundary (vectorised) -------------- */
gen byte _long = ustrlen(summary) > 300
replace summary = usubstr(summary, 1, 300)                            if _long
replace summary = usubstr(summary, 1, ustrrpos(summary, " ") - 1)    if _long & ustrrpos(summary, " ") > 1
replace summary = summary + "..."                                    if _long
drop _long

/* ---- escape LaTeX specials ON THE VARIABLE ------------------------------
   Crucial for "$": doing this on a local via subinstr("`d'", ...) fails
   because Stata expands "$" as a global-macro reference when the local is
   dereferenced, so dollar amounts (e.g. "$4 million") reached LaTeX unescaped
   and opened math mode (italic, spaces dropped) that ran off the page.  On the
   variable there is no macro expansion.  Braces were already turned into
   parentheses above, so the braces introduced by \textasciicircum{} etc. are
   safe. */
/* "$": we want a literal "\$" in the .tex.  file write applies one round of
   Stata escape processing, which turns "\$" back into "$", so we store "\\$"
   (two backslashes + dollar, built from char codes to dodge Stata's own string
   escapes); file write then emits exactly "\$". */
replace summary = subinstr(summary, char(36), char(92) + char(92) + char(36), .)
replace summary = subinstr(summary, "&", "\&", .)
replace summary = subinstr(summary, "%", "\%", .)
replace summary = subinstr(summary, "#", "\#", .)
replace summary = subinstr(summary, "_", "\_", .)
replace summary = subinstr(summary, "^", "\textasciicircum{}", .)
replace summary = subinstr(summary, "~", "\textasciitilde{}", .)

/* ---- order rows by disclosure date (ORDER OF OCCURRENCE) -----------------
   The number itself is not printed, but the row order matches the 1..N
   numbering that a_loo_scandal_pa_vs_na.do uses to label the leave-one-out
   figures (same deterministic tie-break: date, then country, then id). */
gsort scandate country id
local N = _N

/* ---- write the longtable -------------------------------------------------- */
capture file close _t
file open _t using "${tables}/sup_scandal_list.tex", write replace
file write _t "\begin{landscape}" _n
file write _t "\begingroup" _n
file write _t "\setstretch{1.0}\footnotesize" _n
file write _t "\setlength{\LTcapwidth}{\linewidth}" _n
file write _t "\begin{longtable}{@{}l c p{15.5cm} l@{}}" _n
file write _t "\caption{Classification of the 176 scandals in the event-window panel. Rows are in order of occurrence (by disclosure date); this is the same position the leave-one-out figures use to label each scandal. A scandal is \textit{Apex} when the implicated official is a president, governor, or Supreme Court justice, and \textit{Non-Apex} otherwise.}\label{tab:sup_scandal_list}\\" _n
file write _t "\toprule" _n
file write _t "\textbf{Country} & \textbf{Year} & \textbf{Description} & \textbf{Class} \\" _n
file write _t "\midrule" _n
file write _t "\endfirsthead" _n
file write _t "\multicolumn{4}{@{}l}{\emph{\tablename~\thetable\ (continued)}}\\" _n
file write _t "\toprule" _n
file write _t "\textbf{Country} & \textbf{Year} & \textbf{Description} & \textbf{Class} \\" _n
file write _t "\midrule" _n
file write _t "\endhead" _n
file write _t "\midrule" _n
file write _t "\multicolumn{4}{r@{}}{\emph{Continued on next page}}\\" _n
file write _t "\endfoot" _n
file write _t "\bottomrule" _n
file write _t "\endlastfoot" _n

forvalues i = 1/`N' {
	local ctry = country[`i']
	local yr  = scanyear[`i']
	local cls = cond(apex[`i'] == 1, "Apex", "Non-Apex")

	local d = summary[`i']
	/* description already cleaned, truncated and LaTeX-escaped on the
	   variable above (escaping "$" there, not on this macro, avoids
	   Stata reading it as a global-macro reference) -- just emit it */
	file write _t `"`ctry' & `yr' & `d' & `cls' \\"' _n
}
file write _t "\end{longtable}" _n
file write _t "\endgroup" _n
file write _t "\end{landscape}" _n
file close _t
display in green "sup_scandal_list.tex written (`N' scandals)"
