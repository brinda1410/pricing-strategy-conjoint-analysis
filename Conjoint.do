clear all
set more off

global filepath "C:\Users\bsapr\OneDrive - The University of Chicago\Conjoint Analysis"

******************************** GLOSSARY *************************************
//1. Features: The different attributes that can be adjusted in a product and  affect its price
//2. Levels: The discrete values of each possible state for every attribute. A level of 0 indicates the feature is absent
//3. Product profile: A vector of the given levels of all attributes
//4. Task: A prompt asking to compare and choose between several product profiles
//5. Options: The number of profiles in a given task
******************************************************************************

***************************** 1. CREATING TASKS ********************************

*1.1 Store values from input variables in globals
/* We initialize the code with two sets of parameters, product information and survey design. 
The first set comprises data on the features, the maximum number of levels across features, and the price levels.
The second set comprises the number of tasks to be given to each respondent, 
number of options per task, and number of respondents (sample size), calculated
based on the rule-of-thumb formula provided by Johnson and Orme(1996)
*/

import excel using "${filepath}/0_Configuration/Input_Specifications.xlsx", sheet("Inputs") firstrow clear
local constant = Constant[1]
local level = Levels[1]
local profiles = Profiles[1]
local task = Tasks[1]
local samplesize = SampleSize[1]
local feature = Features[1]
local feature1 = Feature1[1]
local feature2 = Feature2[1]
local feature3 = Feature3[1]
local price1 = Price1[1]
local price2 = Price2[1]

*Create globals for inputs
global tasks `task'
global features `feature'
global levels `level'
global sample `samplesize'

*1.2 Prepare to create profiles
/*For given features and their respective levels, we want to generate all
possible profiles. We prepare for this by generating a temporary file for each 
feature, with a column vector of first n whole numbers, where n is the number of 
levels. The temp datasets are identical, with only the column headers named
differently
*/
forv i=1/$features { // Number of features
    clear
    set obs $levels // Levels per feature
    gen v`i'=_n
    tempfile temp`i'
    save `temp`i'', replace
    }
	
*1.3 Create profiles
/* Now, we use the cross command to form every pairwise combination of the above 
temp datasets. Each row represents a unique product profile. The number of 
profiles is equal to (number of levels)^(number of features). We also sneak
in a counter for each profile, which is simply a unique tag for each profile
*/
clear
use `temp1'
forv i=2/$features {
    cross using `temp`i''
    }   

*Renaming and labelling
forv i=1/$features{
	replace v`i'=0 if v`i'==2
	}
renvarlab v*, presub(v feature)
sort feature*

*Drop non-existent profiles
egen noprofile=rowtotal(feature*)
drop if noprofile==0
drop noprofile
gen n1=_n

*1.4 Copies of this dataset
/* We create as many copies of the above matrix of profiles as there are 
options. Each variable is uniquely named feature[i][j], where i stands for the 
feature and j stands for the serial number of the copy. Thus, there will be 
(number of features)*(number of options) variables across all the files.
*/
renvarlab feature*, postfix(1)
save "${filepath}/1_Create tasks/profile1", replace

renvarlab feature*, postsub(1 2)
rename n1 n2
save "${filepath}/1_Create tasks/profile2", replace

*1.5 Create tasks
/* We use the cross command again to form every pairwise combination of the 
above copy datasets. Thus, we will get number of tasks equal to 
(number of profiles)^(number of options)
*/
use "${filepath}/1_Create tasks/profile1", clear
cross using "${filepath}/1_Create tasks/profile2"

*1.6 Drop tasks
**1.6.1 Drop tasks with identical profiles
drop if n1==n2
sort n1 n2

**1.6.2 Drop repeating tasks
drop if n1>1 & n2<n1 // Drop repeating tasks

**1.6.3 Drop tasks with rationally obvious choice
/* If a task has profiles in which one profile is objectively superior to all the
other profile options, then choice is illusive. A profile A is defined to be 
objectively dominant to other profiles if the following conditions are met:
i) The level of at least one feature in A is strictly greater than the 
corresponding levels of that feature in other profiles.
ii) The levels of all other features in A are either equal to or lower than the
levels of those features in other profiles
*/

egen option1=rowtotal(feature*1)
egen option2=rowtotal(feature*2)

gen irrational=1
forv i=1/$features {
	replace irrational=0 if ((option1>option2 & feature`i'1<feature`i'2) | (option1<option2 & feature`i'1>feature`i'2) | option1==option2)
}
drop if irrational==1
drop n1 n2 option1 option2 irrational

*1.7 Assign labels to tasks
tostring feature11-feature42, replace

replace feature11 = "No `feature1'" if feature11=="0"
replace feature11 = "Has `feature1'" if feature11=="1"
replace feature21 = "No `feature2'" if feature21=="0"
replace feature21 = "Has `feature2'" if feature21=="1"
replace feature31 = "No `feature3'" if feature31=="0"
replace feature31 = "Has `feature3'" if feature31=="1"
replace feature41 = "`price1'" if feature41=="0"
replace feature41 = "`price2'" if feature41=="1"

replace feature12 = "No `feature1'" if feature12=="0"
replace feature12 = "Has `feature1'" if feature12=="1"
replace feature22 = "No `feature2'" if feature22=="0"
replace feature22 = "Has `feature2'" if feature22=="1"
replace feature32 = "No `feature3'" if feature32=="0"
replace feature32 = "Has `feature3'" if feature32=="1"
replace feature42 = "`price1'" if feature42=="0"
replace feature42 = "`price2'" if feature42=="1"

save "${filepath}/1_Create tasks/all_tasks", replace


********************************************************************************
****************************2. CREATING SURVEYS ********************************
********************************************************************************

* Randomly sample tasks for each client
preserve
forv i = 1/$sample { //it produces same sample for all loops
	use "${filepath}/1_Create tasks/all_tasks", clear
	bsample $tasks
	
	egen Profile_A = concat(feature11-feature41), punct(", ")
	egen Profile_B = concat(feature12-feature42), punct(", ")
	gen Choice = ""
	save "${filepath}/2_Create Surveys/Stata/client`i'", replace
	export excel Profile_A Profile_B Choice using "${filepath}/2_Create Surveys/Excel/client`i'.xlsx", firstrow(variables) replace
	putexcel set "${filepath}/2_Create Surveys/Excel/client`i'.xlsx", modify
	putexcel (A1:C1), bold shrinkfit
}
restore

********************************************************************************
****************************3. GATHER RESPONSES ********************************
********************************************************************************

/* Use this if you want to generate random choices
preserve
forv i = 1/$sample { //it produces same sample for all loops
	import excel "${filepath}/2_Create Surveys/Excel/client`i'.xlsx", firstrow clear
	replace Choice = runiformint(1,2)
	export excel Profile_A Profile_B Choice using "${filepath}/3_Gather Response/client`i'.xlsx", firstrow(variables) replace
}
restore
*/

********************************************************************************
****************************4. PREPARING DATA ***********************************
********************************************************************************

	**** PREPARING FOR ANALYSIS ****

	forv i = 1/$sample {
		* Import
		import excel using "${filepath}/3_Gather Response/client`i'.xlsx", firstrow clear
		
		* Create UID at Profile-level - this will be used to have profiles used in 
		* the same task to be placed, one below other, during clogit. This will 
		* faciliate grouping
		gen profile_uid = _n
		gen client_uid = `i'
		tostring profile_uid client_uid, replace
		egen client_profile_uid = concat(profile_uid client_uid)
		destring client_profile_uid, replace

		* Cleaned data client-wise
		save "${filepath}/4_Preparing Data/Client_wise/client`i'_cleaned.dta", replace
	}

	* Appending to generate cleaned data 
	cd "${filepath}/4_Preparing Data/Client_wise"
	use client1_cleaned, clear
	forv i =2/$sample{
		append using client`i'_cleaned
	}
	drop profile_uid client_uid
	drop if Profile_A=="No Mapping Visualisation, No PDF Download, No Multiple Disaggregation Levels, 150"
	drop if Profile_A=="No Mapping Visualisation, No PDF Download, No Multiple Disaggregation Levels, 100"
	drop if Profile_B=="No Mapping Visualisation, No PDF Download, No Multiple Disaggregation Levels, 150"
	drop if Profile_B=="No Mapping Visualisation, No PDF Download, No Multiple Disaggregation Levels, 100"

	* Arrange all Profiles one below the other
	gen reshape_uid = _n
	reshape long Profile, i(reshape_uid) j(profile_id) string
	replace profile_id = subinstr(profile_id,"_","",1)
	replace Choice=0 if (profile_id=="A" & Choice==2) | (profile_id=="B" & Choice==1)
	replace Choice=1 if Choice!=0
	order client_profile_uid, after(reshape_uid)
	destring client_profile_uid, replace

	* Column for every feature
	split Profile, parse (,) gen(feature)
	renvarlab feature4\Price
	destring Price, replace
	global reg_features = $features - 1

	* Change string values to numeric 1 or 0 for regression
	forv i = 1/$reg_features{
		replace feature`i' = "0" if strpos(feature`i',"No")
		replace feature`i' = "1" if strpos(feature`i',"Has")
		destring feature`i', replace
	}
/*
	replace Price = `price1' if Price == `price1'
	replace Price = `price2' if Price == `price2'
	replace Choice = 0 if Choice == 1
	replace Choice = 1 if Choice == 2
*/
	save "${filepath}/4_Preparing Data/conjoint_cleaned", replace
	
********************************************************************************
****************************4. ANALYSIS	****************************************
********************************************************************************
 
//keep reshape_uid feature* Price Choice

***DEFINING PRODUCTS
egen product = group(feature*)
sum product
global product_n = r(max)

bys product: egen price_product=mean(Price) ///Average price of each product

***CONDITIONAL LOGIT
clogit Choice feature* Price, group(reshape_uid)
global price_coeff=_b[Price]
listcoef, percent help


/*We find that a one standard deviation (~12 points) increase in the assessment score increases
the odds of a candidate ending up as a top quintile performer versus the combined lower quintiles,
by 354.7%, given all other variables are held constant. 
In other words, if candidate A scores 12 points higher on the assessment than candidate B, then A is 4.55 times 
as likely to be a top 20% performer rather than not, as compared to B, given similar backgrounds. 
This effect is statistically significant at the 10% level.
*/



*******GENERATING FURTHER INSIGHTS

***1 PREDICTED MARKET SHARE OF EACH PRODUCT
predict pr_choice

graph bar pr_choice, over(product)

tabstat pr_choice, statistics(N mean sum) by(product)
egen total_cus = sum(pr_choice)

forvalues x = 1/$product_n {
egen temp`x' = sum(pr_choice*(product==`x'))
gen share_`x' = temp`x'/total_cus
}
tabstat share_*, statistics(mean)


***2 OWN PRICE ELASTICITY - effect of price of i on choice of i
forvalues x = 1/$product_n {
	gen own_price_elasticity_`x'= ($price_coeff)*price_product*(1-share_`x')
}
tabstat own_price_elasticity_*, statistics(mean)
***Interpretation: when price of Product 1 increases by x%, its demand decreases by y%***********

***3 CROSS PRICE ELASTICITY - effect of price of product 2 on choice of 1
summ price_product if product==2
global price_product2 = r(mean) 
gen cross_price_elasticity_1_2= (-1)*($price_coeff)*($price_product2)*(1-share_1)

tabstat cross_price_elasticity_1_2, statistics(mean)
***Interpretation: when price of product 2 increases by x%, sales of product 1 will increase by y%

***4 EXPECTED REVENUE
egen revenue = sum(Choice*Price)
