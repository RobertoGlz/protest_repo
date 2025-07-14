/* ----------------------------------------------------------------------------
					Violent Effects of Apex Corruption
					
	Code author: Roberto Gonzalez
	Date: May 26, 2025
	
	Objective: Estimate incidence rate ratios with Poisson regression for the
	number of Protests occuring after Corruption scandals, depreciations and 
	football match losses
---------------------------------------------------------------------------- */

/* Program for combining panels from "https://raw.githubusercontent.com/steveofconnell/PanelCombine/master/PanelCombine.do" */
cap prog drop panelcombine
prog define panelcombine
qui {
syntax, use(str asis) paneltitles(str asis) columncount(integer) save(str asis) [CLEANup]
preserve

tokenize `"`paneltitles'"'
//read in loop
local num 1
while "``num''"~="" {
local panel`num'title="``num''"
local num=`num'+1
}


tokenize `use'
//read in loop
local num 1
while "``num''"~="" {
tempfile temp`num'
insheet using "``num''", clear
save `temp`num''
local max = `num'
local num=`num'+1
}

//conditional processing loop
local num 1
while "``num''"~="" {
local panellabel : word `num' of `c(ALPHA)'
use `temp`num'', clear
	if `num'==1 { //process first panel -- clip bottom
	drop if strpos(v1,"Note:")>0 | strpos(v1,"in parentheses")>0 | strpos(v1,"p<0")>0
	drop if v1=="\end{tabular}" | v1=="}"
	replace v1 = "\midrule \multicolumn{`columncount'}{l}{ \linebreak \textbf{\textit{Panel `panellabel': `panel1title'}}} \\" if v1=="\midrule" & _n<8
	replace v1 = "\midrule" if v1=="\bottomrule" & _n>4 //this is intended to replace the bottom double line; more robust condition probably exists
	}
	else if `num'==`max' { //process final panel -- clip top
	//process header to drop everything until first hline
	g temp = (v1 == "\midrule")
	replace temp = temp+temp[_n-1] if _n>1
	drop if temp==0
	drop temp
	
	replace v1 = " \multicolumn{`columncount'}{l}{\linebreak \textbf{\textit{Panel `panellabel': `panel`num'title'}}} \\" if _n==1
	}
	else { //process middle panels -- clip top and bottom
	//process header to drop everything until first hline
	g temp = (v1 == "\midrule")
	replace temp = temp+temp[_n-1] if _n>1
	drop if temp==0
	drop temp
	
	replace v1 = " \multicolumn{`columncount'}{l}{\linebreak \textbf{\textit{Panel `panellabel': `panel`num'title'}}} \\" if _n==1
	drop if strpos(v1,"Note:")>0 | strpos(v1,"in parentheses")>0 | strpos(v1,"p<0")>0
	drop if v1=="\end{tabular}" | v1=="}"
	replace v1 = "\bottomrule" if v1=="\bottomrule\bottomrule"
	}
	save `temp`num'', replace
local num=`num'+1
}

use `temp1',clear
local num 2
while "``num''"~="" {
append using `temp`num''
local num=`num'+1
}

outsheet using `save', noname replace noquote


	if "`cleanup'"!="" { //erasure loop
	tokenize `use'
	local num 1
		while "``num''"~="" {
		erase "``num''"
		local num=`num'+1
		}
	}

restore
}
end
/* ------------------------------------------------------------------------- */

if "`c(username)'" == "lalov" {
		gl identity "C:\Users\lalov\ITAM Seira Research Dropbox\Eduardo Rivera"
} 
if "`c(username)'" == "Rob_9" {
	global identity "C:/Users/Rob_9/Dropbox"
}

do "${identity}/Corrupcion/protest_repo/code/analysis/poisson_reg_main.do"
do "${identity}/Corrupcion/protest_repo/code/analysis/poisson_reg_depreciation.do"

/* Make panels */
foreach nnn in 90 120 {
	panelcombine, use(Panel_`nnn'_corruption.tex Panel_`nnn'_depreciation.tex) columncount(3) ///
		paneltitles("Corruption Scandals" "Depreciation (Month-on-Month)") ///
		save("${work}/results/tables/poisson_`nnn'window_panels.tex") cleanup
}