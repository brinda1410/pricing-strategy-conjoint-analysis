I led this proof-of-concept (POC) analysis as a Product Associate at Vera Solution to estimate relative willingness to pay for the features of Vera's flagship impact measurement Salesforce-based product. Vera aims to create a social sector driven by outcomes, accountability, and data-informed decisions – a sector in which data systems help organizations deliver better results. This POC was a part of my initiative to make product decisions more data-driven based on the feedback from existing customers using the product. The POC was presented to the CTO, CEO and Director of Products. This is the presentation I used https://prezi.com/p/9xcga3q8sher/conjoint-experiment/

# Conjoint analysis
Conjoint experiment is a survey-based statistical technique used in quantitative market research to determine how people value different features of a product. It helps capture the relative preference of a user over different product features. It is considered to be one of the most scientific ways to identify top feature combinations that can be sold at a given price. There are some limitations of conjoint survey:
1. It uses stated preference, not real behavior. But consumers often don’t know what’s good for them
2. It doesn’t tell us why respondents prefer certain attributes over others
3. It helps maximizes profit, not customer utility
# Terminology
1. Features: The different attributes that can be adjusted in a product and  affect its price
2. Levels: The discrete values of each possible state for every attribute. A level of 0 indicates the feature is absent
3. Product profile: A vector of the given levels of all attributes
4. Task: A prompt asking to compare and choose between several product profiles
5. Options: The number of profiles in a given task
# Methodology
We write a Stata program to automate the design and execution of a conjoint survey. The code executes the following steps:
## Creation of tasks
### Code initialization
We initialize the code with two sets of parameters, product information and survey design, from the “Input_Specifications.xlsx” file in folder 0_Configuration. 
The first set comprises data on the features, the maximum number of levels across features, and the price levels. The second set comprises the number of tasks to be 
given to each respondent, number of options per task, and number of respondents (sample size), calculated based on the rule-of-thumb formula provided by Johnson and Orme (1996):
N500
N >= 500 * lambda / gamma * delta
Where
N is the minimum sample size
lambda is the maximum number of levels among all attributes
gamma is the number of tasks each respondent must do
delta is the number of profiles per task
## Prepare to create profiles
For given features and their respective levels, we want to generate all possible profiles. We prepare for this by generating a temporary file for each feature, with a column vector of first n whole numbers, where n is the number of levels. The temp datasets are identical, with only the column headers named differently.
## Create profiles
Now, we use the cross command to form every pairwise combination of the above temp datasets. Each row represents a unique product profile. We also sneak in a counter for each profile, which is simply a unique tag for each profile. The number of profiles is equal to (number of levels)(number of features).
## Drop non-existent profiles
We drop profiles which have all features at level 0, which implies that all features are absent in that profile, since the product needs at least one feature to exist.
## Copies of this dataset
We create as many copies of the above matrix of profiles as there are options. Each variable is uniquely named feature[i][j], where i stands for the feature and j stands for the serial number of the copy. Thus, there will be (number of features)*(number of options) variables across all the files.
## Create tasks
We use the cross command again to form every pairwise combination of the above copy datasets. Thus, we will get number of tasks equal to (number of profiles)(number of options).
## Drop tasks
We drop tasks which are illogical:
1. We drop tasks which have identical profiles
2. We drop tasks which are duplicates of other tasks
3. We drop tasks with rationally obvious choice. If a task has profiles in which one profile is objectively superior to all the other profile options, then choice is illusive. A profile A is defined to be objectively dominant to other profiles if the following conditions are met:
      a) The level of at least one feature in A is strictly greater than the corresponding levels of that feature in other profiles.
      b) The levels of all other features in A are either equal to or lower than the levels of those features in other profiles
## Store tasks
We store the final set of tasks client-wise in folder 1_Create tasks
# Creating surveys
We use the bsample command to select a random sample of tasks for each client, and store them as  in folder 2_Create Surveys
# Gathering Responses
The sheets generated in the above step are supposed to be circulated offline among respondents to intake responses. We also provide a code to generate random responses.
# Preparing data for analysis
Once all responses are in, we collate the responses into a single file. We first clean each respondent’s responses and add unique IDs for each client. Next, we stack all the responses one below the other in a single file “conjoint_cleaned”
# Analysis and conclusion
We analyze the data by fitting a conditional logistic regression model of the option chosen on all features and price, grouping on the respondent's unique ID. Using the listcoef command, we estimate the percent change in odds of a product profile getting selected depending on whether a given feature is present or absent. The negative coefficient on price indicates that after controlling for all features, the higher price, the less likely one customer will purchase the product.
The goal of conjoint analysis is to determine how much each level of each feature contributes to the consumer’s overall preference. This is called “partworth of the feature”.
For example, if we estimate the following regression, where betas are the log-odds

𝑃𝑟𝑒𝑓𝑒𝑟𝑒𝑛𝑐𝑒=𝛽 + 𝛽1 𝐷𝑖𝑠𝑝𝑙𝑎𝑦 + 𝛽2 𝐵𝑎𝑡𝑡𝑒𝑟𝑦 + 𝛽3 𝑂𝑆 + 𝛽4 𝑆𝑐𝑟𝑒𝑒𝑛 − 𝛽5 𝑃𝑟𝑖𝑐𝑒

1. Relative preference of Display over Battery = 𝛽1/𝛽2
2. Willingness to pay for larger screen = Price differential  Relative preference  = ($250-$150)𝛽5/𝛽4

We also provide code for generating graphs and tables for the following metrics :

1. Predicted market share of each product profile
2. Each product’s own price elasticity and cross price elasticities
    a) Own price elasticity is the effect of price of product i on choice of i
    b) Cross price elasticity is the effect of price of product j on choice of i
3. Expected revenue of a product mix
# Limitations
The program has the following constraints/assumptions:
1. It works for a maximum of two options per task
2. It works for a maximum of three features
3. It works for a maximum of two levels: “Feature present” and “Feature absent”
