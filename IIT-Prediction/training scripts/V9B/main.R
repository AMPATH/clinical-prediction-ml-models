##################################################################################
# About
##################################################################################

  
# # Premise
#   
#   Despite the progress in HIV care in suppressing viral load, disengagement from HIV care remains a significant issue that impairs the 
# path of achieving the global target to end the HIV/AIDS epidemic by 2030, set forth by WHO and the Joint United Nations Programme on HIV/AIDS (UNAIDS). In light of the above, we sought to develop and validate data-driven / AI rules than can be used to foster the early identification of patients at risk of disengagement from care.
# 
# # Objective 
# 
# > The main objective of this study is to predict disengagement by x days denoted by y1,y2....yn. 
# 
# # Training & Validation of Models
# 
# We leveraged Super Learner (Stacked Ensamble) algorithm to train and validated ML models. The details of implementation can be found here:
#   




##################################################################################
# Step 1: Install / Load Relevant Packages
##################################################################################

# function to install missing packages
ipak <- function(pkg){
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg))
    install.packages(new.pkg, dependencies = TRUE, repos='http://cran.rstudio.com/')
  sapply(pkg, require, character.only = TRUE)
}

#install.packages('package_name', dependencies=TRUE, repos='http://cran.rstudio.com/')

packages =c(  "dplyr", "tidyverse",  "zoo", "runner", "readr", "h2o")

ipak(packages)

select = dplyr::select; summarize = dplyr::summarize; rename = dplyr::rename; mutate = dplyr::mutate;


#‘h2o’ version 3.42.0.2 was used

##################################################################################
# Step 2: Intialize H2o Cluster & load helper function
##################################################################################

# Set seed
set.seed(123)

# init h20
h2o.init( ip = "localhost", port = 7070, max_mem_size = "16G", nthreads = -1)

print(getwd())
# Load helper functions
source("training scripts/V9/utils.R") #


##################################################################################
# Step 3. Data Pre-processing & cleaning
##################################################################################


k_folds=11 # please not that the last fold will be used as a proxy for external validation set
# read raw data
training_data_2021 <- readRDS(file = "training_data_2021.Rds")
Facility_Metadata <- read_csv("Facility Metadata v8.csv") # will share this file via drive
clean.long.df = clean_longitudinal_data(training_data_2021)
clean.df= clean.long.df %>% 
      filter(RTC_Date <= as.Date("2024-04-04") & Encounter_Date >= as.Date("2021-01-01") ) %>% # this is the db open & closure date
      filter(encounter_type!= 186 & encounter_type!= 158) %>% # V9B - REMOVE DRUG REFILL ENCOUNTER TYPES
      group_by(person_id)%>% mutate( Age_2021 = first(Age), Cohort = if_else(Age_2021>=18, "Adult", "Minor")) %>%
      ungroup() %>%
      assign_folds(k_folds) %>% #group_by(person_id) %>% arrange( person_id, desc(Visit_Number)) %>% filter(row_number()==4)%>
      left_join(Facility_Metadata, by = "location_id") %>%
      mutate_if(is.character, as.factor)   

 # handle extreme values
 clean.df_before_cleaning = clean.df # make a copy of original data
 clean.df <- clean.df_before_cleaning %>%
  mutate(
   
    Duration_in_HIV_care =  if_else(between(Duration_in_HIV_care, 0, 100), Duration_in_HIV_care,NA_real_),
     BMI =  if_else(between(BMI, 5, 35), BMI,NA_real_),
     CD4 =  if_else(between(CD4, 0, 1500), CD4,NA_real_),
     Viral_Load_log10 =  if_else(between(Viral_Load_log10, -10, 10), Viral_Load_log10,NA_real_),
    
     Days_defaulted_in_prev_enc =  if_else(Days_defaulted_in_prev_enc<=-31, -31,Days_defaulted_in_prev_enc),
    Days_defaulted_in_prev_enc =  if_else(Days_defaulted_in_prev_enc>365, 365,Days_defaulted_in_prev_enc),
    
     Days_Since_Last_VL =  if_else(Days_Since_Last_VL<0, 0,Days_Since_Last_VL),
     Days_Since_Last_CD4 =  if_else(Days_Since_Last_CD4<0, 0,Days_Since_Last_CD4),
     Days_Since_Last_VL =  if_else(Days_Since_Last_VL>1000, 1000,Days_Since_Last_VL),
     Days_Since_Last_CD4 =  if_else(Days_Since_Last_CD4>1000, 1000,Days_Since_Last_CD4),

     BMI_baseline =  if_else(between(BMI_baseline, 5, 35), BMI_baseline,NA_real_),
     CD4_baseline =  if_else(between(CD4_baseline, 0, 1500), CD4_baseline,NA_real_),
     Viral_Load_log10_baseline =  if_else(between(Viral_Load_log10_baseline, -10, 10), Viral_Load_log10_baseline,NA_real_)
  )

##################################################################################
# Step 4. Handle Missing Data 
##################################################################################
sigma=1
# Handle Missing Data
model.df = clean.df%>%
  mutate(
    # create training weights for class imbalance
    y0=as.factor(`disengagement-1day`),
    y0_weight = if_else(y0=='Disengaged', (sum(clean.df[,"disengagement-1day"] == 'Active In Care', na.rm=T) / nrow(clean.df))*sigma,
                        1-sum(clean.df[,"disengagement-1day"] == 'Active In Care', na.rm=T) / nrow(clean.df)),
    y1=as.factor(`disengagement-2wks`),
    y1_weight = if_else(y1=='Disengaged', (sum(clean.df[,"disengagement-2wks"] == 'Active In Care', na.rm=T) / nrow(clean.df))*sigma,
                        1-sum(clean.df[,"disengagement-2wks"] == 'Active In Care', na.rm=T) / nrow(clean.df)),
    
    y2=as.factor(`disengagement-1month`),
    y2_weight = if_else(y2=='Disengaged', (sum(clean.df[,"disengagement-1month"] == 'Active In Care', na.rm=T) / nrow(clean.df))*sigma,
                        1-sum(clean.df[,"disengagement-1month"] == 'Active In Care', na.rm=T) / nrow(clean.df)),
    y3=as.factor(`disengagement-3month`),
    y3_weight = if_else(y3=='Disengaged', (sum(clean.df[,"disengagement-3month"] == 'Active In Care', na.rm=T) / nrow(clean.df))*sigma,
                        1-sum(clean.df[,"disengagement-3month"] == 'Active In Care', na.rm=T) / nrow(clean.df)),
    
    y4=as.factor(`disengagement-7days`),
    y4_weight = if_else(y4=='Disengaged', (sum(clean.df[,"disengagement-7days"] == 'Active In Care', na.rm=T) / nrow(clean.df))*sigma,
                        1-sum(clean.df[,"disengagement-7days"] == 'Active In Care', na.rm=T) / nrow(clean.df))
  )%>%
  mutate(
    
    # Add missing Data Indicators
    Age_NA= ifelse(is.na(Age), 1, 0),
    Duration_in_HIV_care_NA= ifelse(is.na(Duration_in_HIV_care),  1, 0),
    BMI_NA= ifelse(is.na(BMI), 1, 0),
    WHO_staging_NA= ifelse(is.na(WHO_staging),  1, 0),
    Regimen_Line_NA= ifelse(is.na(Regimen_Line),  1, 0),
    HIV_disclosure_NA= ifelse(is.na(HIV_disclosure),  1, 0),
    CD4_NA= ifelse(is.na(CD4), 1, 0),
    Viral_Load_log10_NA= ifelse(is.na(Viral_Load_log10), 1, 0),
    #Days_to_Start_of_ART_NA= ifelse(is.na(Days_to_Start_of_ART),  1, 0), #REMOVED
    #Adherence_Counselling_Sessions_NA = ifelse(is.na(Adherence_Counselling_Sessions),  1, 0),
    Days_defaulted_in_prev_enc_NA= ifelse(is.na(Days_defaulted_in_prev_enc), 1, 0),
    num_2wks_defaults_last_3visits_NA= ifelse(is.na(num_2wks_defaults_last_3visits), 1, 0),
    ever_defaulted_by_1m_in_last_1year_NA= ifelse(is.na(ever_defaulted_by_1m_in_last_1year), 1, 0),
    ever_defaulted_by_1m_in_last_2year_NA= ifelse(is.na(ever_defaulted_by_1m_in_last_2year), 1, 0),
    
    # Added in version 8
    ############################################################
    Days_Since_Last_VL_NA= ifelse(is.na(Days_Since_Last_VL),  1, 0),
    Days_Since_Last_CD4_NA= ifelse(is.na(Days_Since_Last_CD4),  1, 0),
    BMI_baseline_NA= ifelse(is.na(BMI_baseline), 1, 0),
    WHO_staging_baseline_NA= ifelse(is.na(WHO_staging_baseline),  1, 0),
    Regimen_Line_baseline_NA= ifelse(is.na(Regimen_Line_baseline),  1, 0),
    HIV_disclosure_baseline_NA= ifelse(is.na(HIV_disclosure_baseline),  1, 0),
    CD4_baseline_NA= ifelse(is.na(CD4_baseline), 1, 0),
    Viral_Load_log10_baseline_NA= ifelse(is.na(Viral_Load_log10_baseline), 1, 0),
    ##################################################
    
    # Set NA to a fixed value (usually zero)
    Age= ifelse(is.na(Age), 0, Age),
    Duration_in_HIV_care= ifelse(is.na(Duration_in_HIV_care), 0, Duration_in_HIV_care),
    #Weight= ifelse(is.na(Weight), 0, Weight),
    #Height= ifelse(is.na(Height),0, Height),
    BMI= ifelse(is.na(BMI),0, BMI),
    WHO_staging= ifelse(is.na(WHO_staging), 0, WHO_staging),
    Regimen_Line= ifelse(is.na(Regimen_Line), 0, Regimen_Line),
    HIV_disclosure= ifelse(is.na(HIV_disclosure), 0, HIV_disclosure),
    CD4= ifelse(is.na(CD4),0, CD4),
    Viral_Load_log10= ifelse(is.na(Viral_Load_log10), log10(1), Viral_Load_log10),
    #Days_to_Start_of_ART= ifelse(is.na(Days_to_Start_of_ART), 0, Days_to_Start_of_ART),  #REMOVED
    #Adherence_Counselling_Sessions_NA= ifelse(is.na(Adherence_Counselling_Sessions), 0, Adherence_Counselling_Sessions),
    Days_defaulted_in_prev_enc= ifelse(is.na(Days_defaulted_in_prev_enc),0, Days_defaulted_in_prev_enc),
    num_2wks_defaults_last_3visits= ifelse(is.na(num_2wks_defaults_last_3visits),0, num_2wks_defaults_last_3visits),
    ever_defaulted_by_1m_in_last_1year= ifelse(is.na(ever_defaulted_by_1m_in_last_1year),0,ever_defaulted_by_1m_in_last_1year),
    ever_defaulted_by_1m_in_last_2year= ifelse(is.na(ever_defaulted_by_1m_in_last_2year),0, ever_defaulted_by_1m_in_last_2year),
    
     # Added in version 8
    ############################################################
    Days_Since_Last_VL= ifelse(is.na(Days_Since_Last_VL), 0, Days_Since_Last_VL),
    Days_Since_Last_CD4= ifelse(is.na(Days_Since_Last_CD4), 0, Days_Since_Last_CD4),
    BMI_baseline= ifelse(is.na(BMI_baseline),0, BMI_baseline),
    WHO_staging_baseline= ifelse(is.na(WHO_staging_baseline), 0, WHO_staging_baseline),
    Regimen_Line_baseline= ifelse(is.na(Regimen_Line_baseline), 0, Regimen_Line_baseline),
    HIV_disclosure_baseline= ifelse(is.na(HIV_disclosure_baseline), 0, HIV_disclosure_baseline),
    CD4_baseline= ifelse(is.na(CD4_baseline),0, CD4_baseline),
    Viral_Load_log10_baseline= ifelse(is.na(Viral_Load_log10_baseline), log10(1), Viral_Load_log10_baseline),
    
    ART_regimen_baseline = factor(if_else(is.na(ART_regimen_baseline),"Other",ART_regimen_baseline)),
    ART_Adherence = factor(if_else(is.na(ART_Adherence),"Other",ART_Adherence)),
    
     # Added in version 8 (FROM location metadata CSV)
    ############################################################
    Current_Clinic_County = factor(if_else(is.na(Current_Clinic_County),"Other",Current_Clinic_County)),
    `Care Programme` = factor(if_else(is.na(`Care Programme`),"Other",`Care Programme`)),
    `Urban_Rural`  = factor(if_else(is.na(Urban_Rural),"Other",Urban_Rural)),
    `Current Facility Level`  = factor(if_else(is.na(`Current Facility Level`),"Other",`Current Facility Level`)),
    `Private_Public`  = factor(if_else(is.na(Private_Public),"Other",Private_Public)),
    `Facility Type`  = factor(if_else(is.na(`Facility Type`),"Other",`Facility Type`))
   
    
  )%>% mutate_if(is.character, as.factor) 



##################################################################################
# Step 5. Define Predictors
##################################################################################

# predictors
X=c(   
   'Age','Age_NA', 
   'Gender' ,  
   'num_1day_defaults_last_3visits',
   'Current_Clinic_County',
   'Days_defaulted_in_prev_enc', 'Days_defaulted_in_prev_enc_NA',
   'Size_Enrollments_Log10', 
   'Volume_Visits_Log10',
   'Care Programme',
   'Days_Since_Last_VL',  'Days_Since_Last_VL_NA',
   'Visit_Number',  
   'HIV_disclosure_stage', 'HIV_disclosure_baseline_NA',
   'Program_Name', 
   'Days_Since_Last_CD4', 'Days_Since_Last_CD4_NA',
   'Month', 
   'TB_Test_Result', 
   'Viral_Load_log10', 'Viral_Load_log10_NA',
   'BMI', 'BMI_NA',
   'CD4','CD4_NA',  
   'Facility Type'
)





##################################################################################
# Step 6. Define ML algorithm & Hyper-parameter tuning
##################################################################################

# Experimentation
max_models=30#200 #10 20
stopping_rounds =7#15 #10
stopping_tolerance = 0.001#0.0000001#0.0001 #0.02
fold_column <- "fold_id"
max_runtime_mins = 60#22000000#80 40
balance_classes = F # false by default
include_algos= c(
  "XGBoost", #"DRF", 
  "StackedEnsemble",  "GLM",
"GBM"

 )
stopping_metric="logloss"
sort_metric="auc"
assignment_type="stratified"
verbosity= NA



##################################################################################
# 1 day Disengagement | Weighted | Adult
##################################################################################

## Train the model
y='y0'
x = c(X)
weights_column = 'y0_weight'
main.df = model.df%>%filter(!is.na(`y0`) & Cohort=='Adult' )%>%select(c(y,x, fold_id, weights_column))

h2o_frame <- as.h2o(main.df)

train <- h2o.assign(h2o_frame[h2o_frame$fold_id != k_folds, ],key = "train")
test <- h2o.assign(h2o_frame[h2o_frame$fold_id == k_folds, ],key = "test")

one.day.adult.h2o <- h2o.automl(x = x, y = y, training_frame = train, leaderboard_frame = test,  fold_column = fold_column, balance_classes=balance_classes,
    stopping_metric =stopping_metric, stopping_rounds = stopping_rounds, stopping_tolerance = stopping_tolerance, max_models = max_models,  distribution = "bernoulli",
    max_runtime_secs = 60 * max_runtime_mins * max_models, seed = 1, sort_metric = sort_metric, 
    project_name=paste0(y,'_', format(Sys.time(), "%H%M%S")), 
    include_algos=include_algos, keep_cross_validation_fold_assignment= T,
    keep_cross_validation_predictions=T, verbosity = verbosity, 
    weights_column = weights_column,
    max_runtime_secs_per_model = 60 * max_runtime_mins)
one.day.adult.h2o

## Test the model
evaluate_ml_model(test, y, x, hyper_parameters, one.day.adult.h2o)


##################################################################################
# 1 day Disengagement | Weighted | Minor (Peds + Youth as of 2021)
##################################################################################

## Train the model
y='y0'
x = c(X)
weights_column = 'y0_weight'
main.df = model.df%>%filter(!is.na(`y0`) & Cohort=='Minor' )%>%select(c(y,x, fold_id, weights_column))

h2o_frame <- as.h2o(main.df)

train <- h2o.assign(h2o_frame[h2o_frame$fold_id != k_folds, ],key = "train")
test <- h2o.assign(h2o_frame[h2o_frame$fold_id == k_folds, ],key = "test")

one.day.minor.h2o <- h2o.automl(x = x, y = y, training_frame = train, leaderboard_frame = test,  fold_column = fold_column, balance_classes=balance_classes,
    stopping_metric =stopping_metric, stopping_rounds = stopping_rounds, stopping_tolerance = stopping_tolerance, max_models = max_models,  distribution = "bernoulli",
    max_runtime_secs = 60 * max_runtime_mins * max_models, seed = 1, sort_metric = sort_metric, 
    project_name=paste0(y,'_', format(Sys.time(), "%H%M%S")), 
    include_algos=include_algos, keep_cross_validation_fold_assignment= T,
    keep_cross_validation_predictions=T, verbosity = verbosity, 
    weights_column = weights_column,
    max_runtime_secs_per_model = 60 * max_runtime_mins)
one.day.minor.h2o

## Test the model
evaluate_ml_model(test, y, x, hyper_parameters, one.day.minor.h2o)
