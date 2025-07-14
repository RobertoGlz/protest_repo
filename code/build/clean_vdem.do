/* ----------------------------------------------------------------------------	
						Corruption scandals and protests
						
	Code author: Roberto Gonzalez
	Date: December 19, 2024
	
	Objective: Clean VDEM dataset to classify countries as either democratic
	or not
---------------------------------------------------------------------------- */

/* Read in dataset */
use "${src}/VDEM/VDEM CY Full Others.dta", clear

/* Keep country, year and regime classification */
keep country_name country_text_id country_id year v2x_regime v2x_polyarchy v2cademmob v2caautmob v2x_rule v2smarrest v2smpolhate e_democ e_autoc

/* Keep observations for years in [2008, 2020] */
keep if (year >= 2008 & year <= 2020)

/* Generate an indicator four country being democratic */
generate democratic_in_year = (inlist(v2x_regime, 2, 3))
bysort country_id : egen demoshare = mean(democratic_in_year)

/* Generate indicator for being democratic over 50% of the time */
generate democratic_ov50pc = (demoshare >= 0.5)
drop demoshare v2x_regime

/* Rename some indices */
rename (v2x_polyarchy v2cademmob v2caautmob v2x_rule v2smarrest v2smpolhate) ///
	(elec_demo_index mm_prodemo mm_proautocracy ruleoflaw_index arrest_polcontent_index hatespeech_index)
