# custom operator 
`%nin%` <- Negate(`%in%`)

# Function that assign golds
assign_folds <- function(df, k_folds) {
  # Set seed for reproducibility
  set.seed(123)
  
  # Randomly shuffle the unique patient_ids
  shuffled_patient_ids <- sample(unique(df$patientID))
  
  # Calculate the fold_id for each patientID
  fold_ids <- rep(1:k_folds, length.out = length(shuffled_patient_ids))
  
  # Create a lookup table for fold_id
  fold_lookup <- data.frame(patientID = shuffled_patient_ids,
                            fold_id = fold_ids)
  
  # Merge the lookup table with the original dataframe
  df <- df %>%
    left_join(fold_lookup, by = "patientID")
  
  # Return the updated dataframe
  return(df)
}

# function to set outliers to NA
set_quantile_bounds_to_na <- function(x, lower_quantile = 0.01, upper_quantile = 0.99) {
  lower_bound <- quantile(x, probs = lower_quantile, na.rm = TRUE)
  upper_bound <- quantile(x, probs = upper_quantile, na.rm = TRUE)
  x[x < lower_bound | x > upper_bound] <- NA
  return(x)
}

# This function  cleans and imputes data
clean_longitudinal_data = function(df){
  
  # Define first-line regimen
  first_line =c("d4T + 3TC + NVP",'d4T + 3TC + EFV','3TC + TDF + DTG','3TC + AZT + ABC',
                '3TC + EFV + ABC','3TC + EFV + AZT','3TC + EFV + TDF','3TC + NVP + ABC',
                '3TC + NVP + AZT','3TC + NVP + TDF','3TC + RTV + AZT + ATV','3TC + RTV + AZT + LOP',
                '3TC + RTV + TDF + ATV','3TC + RTV + TDF + LOP','3TC + TDF + DTG','d4T + 3TC + EFV',
                'd4T + 3TC + NVP'
  )
  
  # Define second-line regimen
  second_line=c('3TC + ABC + DTG','3TC + ABC + ETR','3TC + AZT + DTG','3TC + RTV + ABC + ATV',
                '3TC + RTV + ABC + LOP' )
  
  # Define second-line regimen
  third_line =c("3TC + RTV + TDF + LOP + DTG" )
  
  #raw1.df =  readr::read_csv("Prediction data 2018-01-01 to 2022-12-31.csv", na = "NULL")
  
  time_varrying.df=df%>% 
    mutate(
      
      # Set NA: for 1 and NA levels
      Presence_of_OIs = if_else(is.na(Presence_of_OIs),0,1),
      Pregnancy = if_else(is.na(Pregnancy),0,1),
      Adherence_Counselling_Sessions =  if_else(is.na(Adherence_counseling),0,as.numeric(Adherence_counseling)),
      
      # Clean Encounter Type Class
      Encounter_Type_Class = case_when(
        is.na(Encounter_Type_Name) ~ NA_character_,
        Encounter_Type_Name %in% c("ADULTINITIAL", "PEDSINITIAL", "YOUTHINITIAL") ~"Initial",
        Encounter_Type_Name %in% c("ADULTRETURN", "PEDSRETURN", "YOUTHRETURN") ~"Return",
        
        TRUE ~ "Other"),
      
      # Harmonize Travel_time
      Travel_time = case_when(
        is.na(Travel_time) ~ NA_character_,
        Travel_time %in% c("LESS THAN ONE HOUR", "30 TO 60 MINUTES", "LESS THAN 30 MINUTES") ~"LESS THAN ONE HOUR",
        Travel_time %in% c("MORE THAN ONE HOUR", "ONE TO TWO HOURS", "MORE THAN TWO HOURS") ~"MORE THAN ONE HOUR",
        
        TRUE ~ NA_character_),
      
      # Harmonize Education Level
      Education_Level = case_when(
        is.na(Education_Level) ~ NA_character_,
        Education_Level %in% c("FORM 1 TO 2","FORM 3 TO 4", "SECONDARY SCHOOL") ~"SECONDARY SCHOOL",
        Education_Level %in% c("PRE PRIMARY", "PRE UNIT", "STANDARD 1 TO 3", "STANDARD 4 TO 8") ~"PRIMARY SCHOOL",
        Education_Level %in% c("COLLEGE", "UNIVERSITY") ~"COLLEGE / UNIVERSITY",
        
        TRUE ~ NA_character_),
      
      # Harmonize Occupation
      Occupation = case_when(
        is.na(Occupation) ~ NA_character_,
        Occupation %in% c("TEACHER", "POLICE OFFICER", "HEALTH CARE PROVIDER",
                          "VOLUNTARY TESTING AND COUNSELING CENTER COUNSELOR",
                          "CLINICIAN", "FORMAL EMPLOYMENT", "INDUSTRIAL WORKER",
                          "LABORATORY TECHNOLOGIST", "MECHANIC", "MINER",
                          "NURSE", "OTHER HEALTH WORKER", "TRUCK DRIVER", "CASUAL WORKER",
                          "CIVIL SERVANT", "CLEANER" ) ~"EMPLOYED",
        Occupation %in% c("FARMER", "FISHING", "SELF EMPLOYMENT", "SEX WORKER", "BODA-BODA") ~"SELF EMPLOYMENT",
        Occupation %in% c("UNEMPLOYED", "OTHER NON-CODED", "NOT APPLICABLE", "HOUSEWIFE", 
                          "STUDENT") ~"UNEMPLOYED",
        
        TRUE ~ NA_character_),
      
      # Clean Regimen Line
      Regimen_Line = as.integer(case_when(
        is.na(Regimen_Line) ~ NA_real_,
        Regimen_Line %in% c("FIRST LINE HIV ANTIRETROVIRAL DRUG TREATMENT") ~1,
        Regimen_Line %in% c("SECOND LINE HIV ANTIRETROVIRAL DRUG TREATMENT") ~2,
        Regimen_Line %in% c("THIRD LINE HIV ANTIRETROVIRAL DRUG TREATMENT") ~3,
        
        TRUE ~ NA_real_)),
      
      # If regimen line is null, estimate based on ART regimen
      Regimen_Line =  as.factor(
        ifelse( !is.na(Regimen_Line),
                as.integer( Regimen_Line),
                case_when(
                  
                  ART_regimen %in% first_line ~1,
                  ART_regimen %in% second_line ~2,
                  ART_regimen %in% third_line ~3,
                  ART_regimen %nin% c(first_line,second_line,third_line) ~5,
                  
                  TRUE ~ NA_real_))
      ),
      
      # Harmonize Entry Point
      Entry_Point = case_when(
        is.na(Entry_Point) ~ NA_character_,
        Entry_Point %in% c("ADULT INPATIENT SERVICE", "OUTPATIENT SERVICES") ~"INPATIENT / OUTPATIENT SERVICE",
        Entry_Point %in% c( "HIV COMPREHENSIVE CARE UNIT", "SEXUALLY TRANSMITTED INFECTION", "TUBERCULOSIS", "OTHER NON-CODED", "OSCAR PROGRAM", "SELF TEST") ~"OTHER",
        Entry_Point %in% c("MATERNAL CHILD HEALTH PROGRAM", "PEDIATRIC INPATIENT SERVICE") ~"PEDIATRIC SERVICE",
        Entry_Point %in% c("HOME BASED TESTING PROGRAM", "PERPETUAL HOME-BASED COUNSELING AND TESTING" ) ~"HOME BASED TESTING",
        Entry_Point %in% c("HIV TESTING SERVICES STRATEGY", "VOLUNTARY COUNSELING AND TESTING CENTER" ) ~"VOLUNTARY COUNSELING AND TESTING CENTER",
        
        TRUE ~ NA_character_),
      
      # ART Regimen
      ART_regimen =   ifelse(
        ART_regimen %in% c(first_line,second_line,third_line),
        ART_regimen, "Invalid Regimen"),
      
      # Change date time to date
      Encounter_Date=as.Date(Encounter_Datetime),
      
      # VL processing
      VL_suppression = if_else(Viral_Load >= 1000 | is.na(Viral_Load), 0, 1),
      Viral_Load_log10 = log10(Viral_Load+1) # to avoid log10(0) = -Inf
      
      
      
    )  %>%
    group_by(patientID, Encounter_Date) %>%
    filter(row_number()==1)%>%ungroup() %>% # This collapses multiple encounters per day
    group_by(patientID) %>%
    arrange( patientID, Encounter_Date)%>% # Just to make sure cronology of events are descending
    mutate(
      # First Encounter
      Next_Encounter_Datetime_null = lead(Encounter_Date, order_by = Encounter_ID), # lag
      
      # Set Null dates to 2022
      Next_Encounter_Datetime = if_else(
        is.na(Next_Encounter_Datetime_null),
        as.Date(Sys.time()),
        Next_Encounter_Datetime_null
      ),
      
      Visit_Number = row_number(),
      
      # Lab Values
      # NOTE _order_Date are highly missing so we estimate potential vl/cd4 order date
      VL_Order_Date_Estimated = if_else( !is.na(Viral_Load) & is.na(VL_Order_Date),  
                                         lag(Encounter_Date, order_by =Encounter_ID), # use last Enc as VL_Order_Date
                                         VL_Order_Date # otherwise use VL_Order_Date 
      ),
      VL_Order_Date_Estimated =  na.locf( VL_Order_Date_Estimated, na.rm = FALSE), # LOCF
      
      # NOTE _order_Date are highly missing so we estimate potential vl/cd4 order date
      CD4_Order_Date_Estimated = if_else( !is.na(CD4) & is.na(CD4_Order_Date),  
                                          lag(Encounter_Date, order_by =Encounter_ID), # use last Enc as CD4_Order_Date
                                          CD4_Order_Date # otherwise use CD4_Order_Date 
      ),
      CD4_Order_Date_Estimated =  na.locf(CD4_Order_Date_Estimated, na.rm = FALSE), # LOCF
      
      # Calculate Days_Since_Last
      Days_Since_Last_VL = as.numeric(difftime(Encounter_Date, VL_Order_Date_Estimated, units = "days")),
      Days_Since_Last_CD4 = as.numeric(difftime(Encounter_Date, CD4_Order_Date_Estimated, units = "days")),
      
      # Labeled response variables
      `Days defaulted` =   difftime(Next_Encounter_Datetime , RTC_Date , units = c("days")),
      `disengagement-1day` = factor(if_else(`Days defaulted` > 1, "Disengaged",  "Active In Care")),
      `disengagement-2wks` = factor(if_else(`Days defaulted` > 14, "Disengaged",  "Active In Care")),
      `disengagement-1month` =  factor(if_else(`Days defaulted` > 30, "Disengaged",  "Active In Care")),
      `disengagement-3month` =  factor(if_else(`Days defaulted` > 90, "Disengaged",  "Active In Care")),
      `disengagement-7days` = factor(if_else(`Days defaulted` > 7, "Disengaged",  "Active In Care")),
      
      # Binary version of the response variable
      `disengagement-1day_bin`  = ifelse(`disengagement-1day` == "Disengaged", TRUE, FALSE),
      `disengagement-2wks_bin`  = ifelse(`disengagement-2wks` == "Disengaged", TRUE, FALSE),
      `disengagement-1month_bin`  = ifelse(`disengagement-1month` == "Disengaged", TRUE, FALSE),
      `disengagement-3month_bin`  = ifelse(`disengagement-3month` == "Disengaged", TRUE, FALSE),
      `disengagement-7days_bin`  = ifelse(`disengagement-7days` == "Disengaged", TRUE, FALSE),
      
      # Number of days defaulted in the previous encounters
      Days_defaulted_in_prev_enc = as.numeric(lag(`Days defaulted`, order_by =Encounter_ID)),
      
      # Number of missed-visit (> 2 weeks) out of the last three
      num_2wks_defaults_last_3visits = as.double(lag(rollapplyr(`disengagement-2wks_bin`, 3, sum, partial =TRUE),order_by = Encounter_ID)),
      num_2wks_defaults_last_3visits = if_else(is.na(num_2wks_defaults_last_3visits), 0, num_2wks_defaults_last_3visits),
      
      # Have you disengagements (by 1 month) in the last year
      ever_defaulted_by_1m_in_last_1year = as.numeric(runner(
        x = `disengagement-1month_bin`,
        k = "1 years",
        idx = Encounter_Date,
        f = function(x) {
          any(head(x,-1))
        }
      )),
      
      # Have you disengagements (by 1 month) in the last 2 years
      ever_defaulted_by_1m_in_last_2year = as.numeric(runner(
        x = `disengagement-1month_bin`,
        k = "2 years",
        idx = Encounter_Date,
        f = function(x) {
          any(head(x,-1))
        }
      ))
      
      
    ) %>%
    ungroup() 
  
  ## IMPUTATION (Lagging)
  vars_to_impute =  c(    'Age',
                          'Gender' ,  
                          'Marital_status', 
                          'BMI',
                          'Height',
                          'Weight',
                          'Travel_time',  
                          'WHO_staging',
                          'VL_suppression', 
                          'Viral_Load_log10',
                          'HIV_disclosure',
                          'Regimen_Line', 
                          'Pregnancy',
                          'Clinic_Location',
                          'TB_Comorbidity',
                          'CD4',
                          'Entry_Point', 
                          'Education_Level',  
                          "Occupation",
                          #"Presence_of_OIs", 
                          "Adherence_Counselling_Sessions",
                          "Clinic_Name", 
                          'ART_regimen'
  )
  
  clean.df = time_varrying.df%>% 
    mutate(across(all_of(vars_to_impute), ~.x, .names = "{.col}_orig")) %>%
    group_by(patientID) %>%
    #LOCF stands for “Last Observation Carried Forward.” 
    mutate(across(all_of(vars_to_impute), ~ifelse(is.na(.), na.locf(., na.rm = FALSE), .))) %>% 
    # Add baseline vars
    mutate(across(all_of(vars_to_impute), baseline = .[Visit_Number == 1], .names = "{.col}_baseline")) %>%
    
    ungroup()%>%
    ## Factor the response variable
    mutate(
      y0=as.factor(`disengagement-1day`),
      y1=as.factor(`disengagement-2wks`),
      y2=as.factor(`disengagement-1month`), # This is the main reponse that was used to train the models
      y3=as.factor(`disengagement-3month`),
    )
  
  return(clean.df)
}


# This function trains the model given parameters
train_ml_model <- function(main.df, y, x, hyper_parameters, export_path, weights_column) {
  main.df = model.df%>%
    filter(!is.na({{y}} ))%>%select(c({{y}},{{x}}, `fold_id`, {{weights_column}}))
  h2o_frame <- as.h2o(main.df)
  # train model
  train <- h2o.assign(h2o_frame[h2o_frame$fold_id != hyper_parameters$k_folds, ],key = "train")
  test <- h2o.assign(h2o_frame[h2o_frame$fold_id == hyper_parameters$k_folds, ],key = "test")
  autoML <- h2o.automl(x = x, y = y,
                       training_frame = train, 
                       leaderboard_frame = test,  
                       fold_column = hyper_parameters$fold_column, 
                       balance_classes = hyper_parameters$balance_classes,
                       stopping_metric = hyper_parameters$stopping_metric, 
                       stopping_rounds = hyper_parameters$stopping_rounds, 
                       stopping_tolerance = hyper_parameters$stopping_tolerance, 
                       max_models = hyper_parameters$max_models, 
                       max_runtime_secs = 60 * hyper_parameters$max_runtime_mins * hyper_parameters$max_models, 
                       seed = 1, 
                       sort_metric = hyper_parameters$sort_metric, 
                       project_name=paste0(y,'_', format(Sys.time(), "%H%M%S")), 
                       include_algos=hyper_parameters$include_algos, 
                       keep_cross_validation_fold_assignment= T,
                       keep_cross_validation_predictions=T, 
                       verbosity = hyper_parameters$verbosity, 
                       weights_column = hyper_parameters$weights_column,
                       max_runtime_secs_per_model = 60 * hyper_parameters$max_runtime_mins)
  ## save the model
  unlink(export_path, recursive = TRUE)
  for (i in 1:nrow(autoML@leaderboard)) {
    model_id <- as.character(autoML@leaderboard[i, "model_id"])
    model_auc <-autoML@leaderboard[i, "auc"]
    model_rank <- i
    model <- h2o.getModel(model_id)
    h2o.saveModel(model, path = paste0( export_path, "/", model_rank, "_", model_id, "_auc_", round(model_auc, 3)))
    
  }
  print(h2o.get_leaderboard(object = autoML, extra_columns = "ALL"))
  print(h2o.explain(autoML, train))
  print(autoML@leader)
  print(h2o.performance(autoML@leader)%>%plot())
  return(autoML)
  
}

evaluate_ml_model <- function(main.df, y, x, hyper_parameters, autoML) {
  main.df = model.df%>%
    filter(!is.na({{y}} ))%>%select(c({{y}},{{x}}, `fold_id`))
  h2o_frame <- as.h2o(main.df)
  
  test <- h2o.assign(h2o_frame[h2o_frame$fold_id == hyper_parameters$k_folds, ],key = "test")
  h2o.performance(autoML@leader, newdata=test)%>%plot()
  pd_best <- h2o.predict(autoML@leader, test) %>% as.data.frame() %>% pull(Disengaged)
  
  h2o.performance(model = autoML@leader, newdata = test)
  h2o.explain(autoML, test)
  
}

