global idi $iec/covid/idi_survey

/* use most recent data */
use $idi/round1/wb1_cleaned_dataset_2020-06-02, clear

/*********/
/* Setup */
/*********/

/* declare survey data */
svyset psu [pw=weight_hh], strata(strata_id) singleunit(scaled)

/* merge to shrug data */
merge m:1 shrid using $idi/survey_shrid_data, keep(match master) nogen
/* 70 obs with missing shrid didn't match */
/* 2 obs with shrid 11-10-244076 didn't match, not present in shrug data */

/* pc11 ids in the dataset are nonsensical drop them */
drop pc11*id 

/* merge using shrid to shrug-pc11 key to extract pc11 state and district ids*/
merge m:1 shrid using $shrug/keys/shrug_pc11_district_key, keep(match master) nogen 

/* note: pc11 ids are missing for the 70 obs in idi survey data with no shrid */
/* pc11 district ids are missing for additional 43 obs (bc shrug-pc11 key has missing pc11_district_ids) */

/* generate earnings */
gen lab_march_earn = lab_march_wage * lab_march_freq if !mi(lab_march_wage) & !mi(lab_march_freq)
gen lab_curr_earn = lab_curr_wage * lab_curr_freq if !mi(lab_curr_wage) & !mi(lab_curr_freq)
gen ln_lab_earn_change = ln(lab_curr_earn) - ln(lab_march_earn)

/* indicator for whether hh has at least one migrant */
gen mig = 1 if mig_size > 0 & !mi(mig_size)
replace mig = 0 if mig_size == 0 

/* migrants ratio */
gen mig_ratio = mig_total_ratio/demo_hh_size

/* generate consumption change */
gen ln_con_change = ln(con_wk) - ln(con_feb/4)

/* gen labour workdays change */
gen ln_lab_work_change = ln(lab_curr_freq) - ln(lab_march_freq)

/* generate labour wage change */
gen ln_lab_wage_change = ln(lab_curr_wage) - ln(lab_march_wage)

/* generate migration pre and post lockdown daily wage */
foreach i of var mig_avg_wage mig_daily_wage{

  if "`i'" == "mig_avg_wage" local unit mig_wage_unit
  if "`i'" == "mig_daily_wage" local unit mig_daily_wage_unit

/* unit - daily wage */
  gen s_`i' = `i' if `unit' == 3

/* convert weekly wage to daily wage */
  replace s_`i' = `i'/6 if `unit' == 1

/* convert monthly to daily wage */
  replace s_`i' = `i'/26 if `unit' == 2

}

/* generate migration wage change */
gen ln_mig_wage_change = ln(s_mig_daily_wage) - ln(s_mig_avg_wage)

/* generate ag inputs change */
gen ln_agr_input_change = ln(agr_curr_inputs) - ln(agr_monsoon_inputs)

/* generate ag borrowing change */
replace agr_curr_borrow = . if agr_curr_borrow == -888
gen ln_agr_borrow_change = ln(agr_curr_borrow) - ln(agr_monsoon_borrow)

/* generate ag price change - since holi */
gen ln_agr_prc_change_holi = ln(agr_prc_curr_kg) - ln(agr_prc_holi_kg)

/* generate ag price change - since last year */
gen ln_agr_prc_change_yr = ln(agr_prc_curr_kg) - ln(agr_prc_prev_yr_kg)

/* for land change, using ID insight's constructed variable bc */
/* the units vary by state and I'm not sure of the conversions! */

/* label variables */
la var lab_march_earn "Pre-lockdown weekly earning"
la var lab_curr_earn "Post-lockdown weekly earning"
label define gt 0 "No transfer" 1 "Received a govt transfer"
label values rel_govt_transfer_fa_prop gt
label define m 0 "No migrants in hh" 1 "At least one migrant in hh"
label values mig m

/* nrega */
label define n 0 "NREGA available" 1 "NREGA unavailable"
label values rel_nrega_unavail_prop n
la var rel_nrega_unavail_prop "NREGA availability"

/* non-agricultural households cannot be self-employed in ag, dropping them */
drop if lab_curr_occu == 1 & demo_ag_hh == 0
drop if lab_march_occu == 1 & demo_ag_hh == 0

/* not doing much with health - drop those vars */
drop hea*

/* save as tempfile */
save $tmp/idi_survey_clean, replace

/************/
/* Analysis */
/************/

cd $tmp
use $tmp/idi_survey_clean, clear

/* 1. Total earnings, wage and days worked loss */
graph hbar ln_lab_earn_change ln_lab_work_change ln_lab_wage_change, ascategory yline(0) yvar(relabel(1 "Labor earnings change" 2 "Labor workdays change" 3 "Labor wage change"))
graphout labor_means

graph box ln_lab_earn_change ln_lab_work_change ln_lab_wage_change, ascategory yline(0) yvar(relabel(1 "Labor earnings change" 2 "Labor workdays change" 3 "Labor wage change")) ylabel(-5 (1) 5)
graphout labor_dist

/* 2. Variation in earnings change by categories */

/* by pre-lockdown occupation category */
cibar ln_lab_earn_change [aw = weight_hh] if lab_march_occu != 0, over(lab_march_occu) barcolor(black sienna sand maroon) graphopts(ytitle("Labor earnings % change") ylabel(-1 (.2) 0.2)) 
graphout earn_worker

/* by education categories, excluding don't know, no responses */
cibar ln_lab_earn_change if demo_edu > 0 [aw = weight_hh], over(demo_edu) barcolor(black teal green olive sand) graphopts(ytitle("Labor earnings % change") ylabel(-2.5 (0.5) 0))
graphout earn_edu

/* consumption change, by ag status */
cibar ln_con_change [aw = weight_hh], over(demo_ag_hh) barcolor(black sienna) graphopts(ytitle("Con % change"))
graphout con_ag

/* by state  */
cibar ln_lab_earn_change [aw = weight_hh] , over(geo_state) barcolor(black pink*0.4 blue*0.6 green*0.4) graphopts(ytitle("Labor earnings % change") ylabel(-2 (0.5) 2))
graphout earn_state

/* by whether/not the hh as at least one migrant member */
cibar ln_lab_earn_change [aw = weight_hh] , over(mig) barcolor(black maroon) graphopts(ytitle("Labor earnings % change") ylabel(-1 (0.2) 1))
graphout earn_mig

cibar ln_lab_work_change [aw = weight_hh] , over(mig) barcolor(black maroon) graphopts(ytitle("Labor workdays % change") ylabel(-1 (0.2) 1))
graphout work_mig

cibar ln_con_change [aw = weight_hh] , over(mig) barcolor(black maroon) graphopts(ytitle("con % change") ylabel(-1 (0.2) 1)) 
graphout con_mig

cibar ln_agr_borrow_change [aw = weight_hh] , over(mig) barcolor(black maroon) graphopts(ytitle("Ag borrow % change"))
graphout ag_borrow_mig

/* variance in earnings change by state */
graph hbar (semean) ln_lab_earn_change [aw = weight_hh], over(geo_state) ytitle("Standard error of mean - lab earnings change")
graphout variance

/* 3. Agriculture */

/* price by crop category */
cibar ln_agr_prc_change_holi [aw = weight_hh], over(agr_crop_cat_prop) barcolor(black sienna sand) graphopts(ytitle("Price changes since holi, by crop category") ylabel(-1 (0.2) 0))
graphout prc_crop_holi

/* price since last year by crop category */
cibar ln_agr_prc_change_yr [aw = weight_hh], over(agr_crop_cat_prop) barcolor(black sienna sand) graphopts(ytitle("Price changes since holi, by crop category") ylabel(-1 (0.2) 0))
graphout prc_crop_yr

/* reasons for sales not starting */
graph hbar (mean) agr_nosell_notready - agr_nosell_machine [aw = weight_hh], ascategory yvar(relabel(1 "Crops not ready" 2 "Saving for seeds/home" 3 "Crops destroyed" 4 "No demand" 5 "Closed markets" 6 "Prices low" 7 "Lockdown" 8 "Labor shortage" 9 "Transport UA" 10 "Machine UA"))
graphout nosell_reason

/* selling difficulties for ongoing sales + sales completed within last two weeks  */
graph hbar (mean) agr_selldiff_none - agr_selldiff_police [aw = weight_hh], ascategory yvar(relabel(1 "No difficulty" 2 "Labor shortage" 3 "Transport UA" 4 "Markets closed" 5 "No demand" 6 "Travel distance too long" 7 " Police harrassment"))
graphout selldiff_reason

/* changes in prices, borrowing, planned land, and inputs */
graph hbox ln_agr_prc_change_yr ln_agr_prc_change_holi ln_agr*borrow* ln_agr*input* agr*land*change* [aw = weight_hh], yline(0) yvar(relabel(1 "Log price change (yr)" 2 "Log price change (since holi)" 3 "Log borrowing change" 4 "Log ag input change" 5 "IDI land planned change (%) var"))
graphout achanges

/* selling status */
catplot agr_crop_status
graphout sell_status

/* crop category */
catplot agr_crop_cat_prop
graphout crop_cat


/* 4. collapse dataset at district level */
collapse_save_labels
collapse (mean) ln* ag*land*mean tdist* pc11_pca* ec13* land* mig_total_ratio [aw = weight_hh], by(pc11_state_id pc11_district_id)
collapse_apply_labels

/* save district level dataset */
save $tmp/idi_survey_clean_district, replace

/* change in earnings and land planned for planting change */
twoway lfitci agr_land_change_mean ln_lab_earn_change, xtitle("% change in weekly earnings") ytitle("% change in land planned for kharif") ylabel(-.8 (0.2) .8) yline(0) xlabel(-3 (1) 2)
graphout earn_land

/* change in earnings and ag input exp */
twoway lfitci ln_agr_input_change ln_lab_earn_change, xtitle("% change in weekly earnings") ytitle("% change in input expenditure")  yline(0) xlabel(-.8 (0.2) .8) 
graphout earn_input_wt

/* change in earnings and change in consumption */
twoway lfitci ln_con_change ln_lab_earn_change, xtitle("% change in weekly earnings") ytitle("% change in consumption")  yline(0) xlabel(-3 (.5) 2)
graphout earn_con_wt

/* change in weekly earning and employment per capita */
twoway lfitci ln_lab_wage_change ec13*, ytitle("% change in wages") xtitle("Non-farm jobs per capita") yline(0) 
graphout earn_emp


