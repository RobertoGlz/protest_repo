/* ----------------------------------------------------------------------------
						Corruption and Protests
					
	Author: Roberto Gonzalez
	Date: November 19, 2024
	
	Objective: Run 5 different specifications by Roberto
---------------------------------------------------------------------------- */

/* 8 months - Drop overlaps */
do "${code}/explore/a_reg_onlyfirst_scandal.do"

/* 6 months - drop overlaps */
do "${code}/explore/a_reg_nooverlap_scandal_90dayswindow.do"

/* Use only Latinobarometro scandals*/
do "${code}/explore/a_reg_LB_scandals.do"

/* Use 84 days (3 months) with 7 day bins */
do "${code}/explore/a_reg_scandal_7daybins.do"

/* Use 84 days with 14 day bins */
do "${code}/explore/a_reg_scandal_14daybins.do"