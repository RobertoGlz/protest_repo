/* ----------------------------------------------------------------------------
						Corruption and Protests
					
	Author: Roberto Gonzalez
	Date: November 18, 2024
	
	Objective: Set up config do file with relative paths to the project and 
		for main configurations
---------------------------------------------------------------------------- */

/* ------------------------------ Boilerplate ------------------------------ */
set more off
set varabbrev off
clear all
macro drop _all

/* Set Stata version */
version 18

/* ------------------------------ Directories ------------------------------ */
/* To replicate on another computer uncomment the following line by removing 
	the // and change the path to the local directory where you stored the 
	replication folder 
*/

// global main "your/local/path/to/replication/folder"

if "${main}" == "" {
	if "`c(username)'" == "Rob_9" {
		global main "C:/Users/Rob_9/Dropbox/Corrupcion"
	}
	else if "`c(username)'" == "OtherCollaborator" {
		global main "C:/Users/Other/Collaborator/Corrupcion"
	}
	else {
		display as error "User is not recognized."
		display as error "Specify the main directory in the 00_config do file."
		exit 198
	}
}

/* Create globals for the subdirectories */
/* Source folder (raw data) */
global src "${main}/WORKING FOLDER/Event Study - Scandals/Data/raw"

/* Github repo and code folder */
capture mkdir "${main}/protest_repo"
capture mkdir "${main}/protest_repo/code"
global code "${main}/protest_repo/code"

capture mkdir "${code}/analysis"
capture mkdir "${code}/build"
capture mkdir "${code}/explore"

/* Working folder for additional data and results */
capture mkdir "${main}/Protest_Work"
global work "${main}/Protest_Work"
capture mkdir "${work}/temp"
capture mkdir "${work}/results"
capture mkdir "${work}/results/figures"
capture mkdir "${work}/results/tables"

/* Set significance levels for tables */
global star "star(* 0.1 ** 0.05 *** 0.01)"

/* Colors for graphs */
global saphblue "15 82 186"
global brightred "220 0 0"
