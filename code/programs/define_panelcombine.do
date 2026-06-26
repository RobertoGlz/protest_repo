/* ----------------------------------------------------------------------------
   Project: Apex corruption protests paper

   Code author: steveofconnell (original)
   Modifications: Roberto Gonzalez

   Objective: Define a panelcombine program that handles booktabs rules
              rather than hlines. Source the program at the top of any
              analysis do-file that builds a multi-panel table.

   Source of the original program:
     https://raw.githubusercontent.com/steveofconnell/PanelCombine/master/PanelCombine.do
   Copied verbatim from the religion_project_repo project's
     code/programs/define_panelcombine.do
   so this project does not depend on a sibling repository at build time.
---------------------------------------------------------------------------- */

cap prog drop panelcombine
prog define panelcombine
qui {
syntax, use(str asis) paneltitles(str asis) columncount(integer) save(str) [CLEANup]
preserve

tokenize `"`paneltitles'"'
//read in loop
local num 1
while "``num''"~="" {
local panel`num'title="``num''"
local num=`num'+1
}


tokenize `"`use'"'
//read in loop
local num 1
while `"``num''"'~="" {
local filepath `"``num''"'
tempfile temp`num'
insheet using `"`filepath'"', clear
save `temp`num''
local max = `num'
local num=`num'+1
}

//conditional processing loop
tokenize `"`use'"'
local num 1
while `"``num''"'~="" {
local panellabel : word `num' of `c(ALPHA)'
use `temp`num'', clear
	if `num'==1 { //process first panel -- clip bottom
	drop if strpos(v1,"Note:")>0 | strpos(v1,"in parentheses")>0 | strpos(v1,"p<0")>0
	drop if v1=="\end{tabular}" | v1=="}"
	replace v1 = "\midrule \multicolumn{`columncount'}{l}{\textbf{\textit{Panel `panellabel': `panel1title'}}} \\" if v1=="\midrule" & _n<8
	replace v1 = "\midrule" if v1=="\bottomrule" & _n>4 //this is intended to replace the bottom double line; more robust condition probably exists
	}
	else if `num'==`max' { //process final panel -- clip top
	//process header to drop everything until first hline
	g temp = (v1 == "\midrule")
	replace temp = temp+temp[_n-1] if _n>1
	drop if temp==0
	drop temp

	replace v1 = " \multicolumn{`columncount'}{l}{\textbf{\textit{Panel `panellabel': `panel`num'title'}}} \\" if _n==1
	}
	else { //process middle panels -- clip top and bottom
	//process header to drop everything until first hline
	g temp = (v1 == "\midrule")
	replace temp = temp+temp[_n-1] if _n>1
	drop if temp==0
	drop temp

	replace v1 = " \multicolumn{`columncount'}{l}{\textbf{\textit{Panel `panellabel': `panel`num'title'}}} \\" if _n==1
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
	tokenize `"`use'"'
	local num 1
		while `"``num''"'~="" {
		local filepath `"``num''"'
		erase `"`filepath'"'
		local num=`num'+1
		}
	}

restore
}
end
