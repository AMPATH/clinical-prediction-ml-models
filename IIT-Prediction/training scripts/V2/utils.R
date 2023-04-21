lickert_agree <- function(x, na.rm=FALSE) (as.integer(case_when(
  x =="Strongly Agree" ~ 5,
  x == "Agree"   ~ 4,
  x == "Neutral"   ~ 3,
  x == "Disagree"   ~ 2,
  x == "Strongly Disagree"   ~ 1,
  TRUE ~ NA_real_
)))


checked_unchecked <- function(x, na.rm=FALSE) (as.factor(case_when(
  x =="Checked" ~ "Yes",
  x == "Unchecked"   ~ "No",
  TRUE ~ NA_character_
)))


care_status_cd <- function(x, na.rm=FALSE) (as.factor(case_when(
  x ==6101~	"Continue",
  x ==6102	~"Discontinue",
  x ==6103~	"Re-enroll",
  x ==1267~	"Completed",
  x ==1187~	"Not Done",
  x ==5488~	"Adherence Counselling",
  x ==7272	~"Urgent Referrals",
  x ==7278~"on-urgent Referrals",
  TRUE ~ NA_character_
)))

import_clean_data = function(){
  
  first_line =c("d4T + 3TC + NVP",'d4T + 3TC + EFV','3TC + TDF + DTG','3TC + AZT + ABC',
                '3TC + EFV + ABC','3TC + EFV + AZT','3TC + EFV + TDF','3TC + NVP + ABC',
                '3TC + NVP + AZT','3TC + NVP + TDF','3TC + RTV + AZT + ATV','3TC + RTV + AZT + LOP',
                '3TC + RTV + TDF + ATV','3TC + RTV + TDF + LOP','3TC + TDF + DTG','d4T + 3TC + EFV',
                'd4T + 3TC + NVP'
              )
  second_line=c('3TC + ABC + DTG','3TC + ABC + ETR','3TC + AZT + DTG','3TC + RTV + ABC + ATV',
                '3TC + RTV + ABC + LOP' )
  third_line =c("3TC + RTV + TDF + LOP + DTG" )
  
  raw1.df =  readr::read_csv("Prediction Model Data v3-1.csv", na = "NULL")
  raw2.df =  readr::read_csv("Prediction Model Data v3-1.csv", na = "NULL")
  raw3.df =  readr::read_csv("busia data v3-3.csv", na = "NULL")
  raw4.df =  readr::read_csv("webuye data v3-4.csv", na = "NULL")
  raw5.df =  readr::read_csv("education_occupation_adherence_counselling_oi.csv", na = "NULL")%>%
    mutate(
      # Occupation
      Education_Level = Education,
      Presence_of_OIs = if_else(is.na(Presence_of_OIs),0,1),
      Adherence_Counselling_Sessions =  if_else(is.na(Adherence_Counselling_Session_No),0,1),
      patientID= person_id
    )%>%select(patientID,Occupation,Education_Level,Adherence_Counselling_Sessions,Presence_of_OIs)
  
  
  raw.df = rbind(raw1.df,raw2.df, raw3.df, raw4.df)%>%select(-Occupation,-Education_Level, -Presence_of_OIs)%>%
    left_join(raw5.df, by=c("patientID"))
  #raw.df =  readr::read_csv("Prediction Model Data v2.csv", na = "NULL")
  
  
  baseline.df=raw.df%>%
    mutate_at(c("Patient_Care_Status_Code"),care_status_cd) %>%
    mutate(
      
      Encounter_Type_Class = case_when(
        Encounter_Type_Name %in% c("ADULTINITIAL", "PEDSINITIAL", "YOUTHINITIAL") ~"Initial",
        Encounter_Type_Name %in% c("ADULTRETURN", "PEDSRETURN", "YOUTHRETURN") ~"Return",
        
        TRUE ~ "Other"),
      
      Travel_time = case_when(
        Travel_time %in% c("LESS THAN ONE HOUR", "30 TO 60 MINUTES", "LESS THAN 30 MINUTES") ~"LESS THAN ONE HOUR",
        Travel_time %in% c("MORE THAN ONE HOUR", "ONE TO TWO HOURS", "MORE THAN TWO HOURS") ~"MORE THAN ONE HOUR",
        
        TRUE ~ Travel_time),
      
      Education_Level = case_when(
        Education_Level %in% c("FORM 1 TO 2","FORM 3 TO 4", "SECONDARY SCHOOL") ~"SECONDARY SCHOOL",
        Education_Level %in% c("PRE PRIMARY", "PRE UNIT", "STANDARD 1 TO 3", "STANDARD 4 TO 8") ~"PRIMARY SCHOOL",
        Education_Level %in% c("COLLEGE", "UNIVERSITY") ~"COLLEGE / UNIVERSITY",
        
        TRUE ~ Education_Level),
      
      
      Occupation = case_when(
        
        
        Occupation %in% c("TEACHER", "POLICE OFFICER", "HEALTH CARE PROVIDER",
                          "VOLUNTARY TESTING AND COUNSELING CENTER COUNSELOR",
                          "CLINICIAN", "FORMAL EMPLOYMENT", "INDUSTRIAL WORKER",
                          "LABORATORY TECHNOLOGIST", "MECHANIC", "MINER",
                          "NURSE", "OTHER HEALTH WORKER", "TRUCK DRIVER", "CASUAL WORKER",
                          "CIVIL SERVANT", "CLEANER"
        ) ~"EMPLOYED",
        Occupation %in% c("FARMER", "FISHING", "SELF EMPLOYMENT", "SEX WORKER", "BODA-BODA") ~"SELF EMPLOYMENT",
        Occupation %in% c("UNEMPLOYED", "OTHER NON-CODED", "NOT APPLICABLE", "HOUSEWIFE", 
                          "STUDENT") ~"UNEMPLOYED",
        
        TRUE ~ Occupation),
      
      
      Regimen_Line = as.integer(case_when(
        
        Regimen_Line %in% c("FIRST LINE HIV ANTIRETROVIRAL DRUG TREATMENT") ~1,
        Regimen_Line %in% c("SECOND LINE HIV ANTIRETROVIRAL DRUG TREATMENT") ~2,
        Regimen_Line %in% c("THIRD LINE HIV ANTIRETROVIRAL DRUG TREATMENT") ~3,
        
        TRUE ~ NA_real_)),
      
      
      
      Entry_Point = case_when(
        
        Entry_Point %in% c("ADULT INPATIENT SERVICE", "OUTPATIENT SERVICES") ~"INPATIENT / OUTPATIENT SERVICE",
        Entry_Point %in% c( "HIV COMPREHENSIVE CARE UNIT", "SEXUALLY TRANSMITTED INFECTION", "TUBERCULOSIS", "OTHER NON-CODED", "OSCAR PROGRAM", "SELF TEST") ~"OTHER",
        Entry_Point %in% c("MATERNAL CHILD HEALTH PROGRAM", "PEDIATRIC INPATIENT SERVICE") ~"PEDIATRIC SERVICE",
        Entry_Point %in% c("HOME BASED TESTING PROGRAM", "PERPETUAL HOME-BASED COUNSELING AND TESTING" ) ~"HOME BASED TESTING",
        Entry_Point %in% c("HIV TESTING SERVICES STRATEGY", "VOLUNTARY COUNSELING AND TESTING CENTER" ) ~"VOLUNTARY COUNSELING AND TESTING CENTER",
        
        TRUE ~ Entry_Point),
      
      Regimen_Line =  as.factor(ifelse( !is.na(Regimen_Line),
                                        as.integer( Regimen_Line),
                                        case_when(
                                          
                                          ART_regimen %in% first_line ~1,
                                          ART_regimen %in% second_line ~2,
                                          ART_regimen %in% third_line ~3,
                                          ART_regimen %nin% c(first_line,second_line,third_line) ~5,
                                          
                                          TRUE ~ NA_real_)
                                        
                                        
      )
      
      
      
      )
      
      ,ART_regimen =   ifelse(
        ART_regimen %in% c(first_line,second_line,third_line),
        ART_regimen, "Invalid Regimen")
      
      
    )  %>%
    group_by(patientID) %>%
    mutate(
      # First Encounter
      Next_Encounter_Datetime = lead(Encounter_Datetime, order_by=Encounter_ID), # lag
      Next_Encounter_Datetime = if_else(is.na(Next_Encounter_Datetime), Sys.time(), Next_Encounter_Datetime), # Set Null dates to 2022
      
      # Second Encounter
      
      Next_Encounter_Datetime_2 = lead(Encounter_Datetime, order_by=Encounter_ID, n=2), # lag
      Next_Encounter_Datetime_2 = if_else(is.na(Next_Encounter_Datetime_2), Sys.time(), Next_Encounter_Datetime_2), # Set Null dates to 2022
      RTC_Date_2 =  lead( RTC_Date, order_by=Encounter_ID) # lag,
      
      
      
    )%>%filter(row_number()==1)%>%ungroup() %>% 
    mutate(
      Diff_Next_Prev_Encounter_Datetime = difftime(Next_Encounter_Datetime ,Encounter_Datetime , units = c("days")),
      
      `Days until scheduled visit` = difftime(RTC_Date ,Encounter_Datetime , units = c("days")),
      `Days until actual visit -from enrollment date`  = difftime(Next_Encounter_Datetime ,Encounter_Datetime , units = c("days")),
      `Days  until actual visit _from scheduled visit date` =   difftime(Next_Encounter_Datetime , RTC_Date,  units = c("days")),
      
      
      # First Encounter
      
      `Days defaulted` =   difftime(Next_Encounter_Datetime , RTC_Date , units = c("days")),
      `disengagement-1day` = factor(if_else(`Days defaulted`>1, "Disengaged",  "Active In Care")),
      `disengagement-2wks` = factor(if_else(`Days defaulted`>14, "Disengaged",  "Active In Care")),
      `disengagement-1month` =  factor(if_else(`Days defaulted`>30, "Disengaged",  "Active In Care")),
      `disengagement-3month` =  factor(if_else(`Days defaulted`>90, "Disengaged",  "Active In Care")),
      
      # Second Encounter
      `Days_defaulted_in_first_enc` =   as.numeric(`Days defaulted`),
      
      `Days defaulted_2` =   difftime(Next_Encounter_Datetime_2 , RTC_Date_2 , units = c("days")),
      `disengagement_2-1day` = factor(if_else(`Days defaulted_2`>1, "Disengaged",  "Active In Care")),
      `disengagement_2-2wks` = factor(if_else(`Days defaulted_2`>14, "Disengaged",  "Active In Care")),
      `disengagement_2-1month` =  factor(if_else(`Days defaulted_2`>30, "Disengaged",  "Active In Care")),
      `disengagement_2-3month` =  factor(if_else(`Days defaulted_2`>90, "Disengaged",  "Active In Care")),
      
      # End of Second Encounter
      
      
    ) %>%select(-Patient_Care_Status_Code)
  
  ### One Hot Encoding
  
  # ARV_dummy <- caret::dummyVars(" ~ patientID + ART_", data=baseline.df%>%mutate(ART_= ART_regimen))
  # ARV_df <- data.frame(predict(ARV_dummy, newdata=baseline.df%>%mutate(ART_= ART_regimen)))%>%
  #   rename_with( ~ gsub("...", "_", .x, fixed = TRUE)) %>% mutate_if(is.numeric, ~replace(., is.na(.), 0))
  # ARV_dummy_vars = names(ARV_df%>%select(-patientID))
  #clean.df = baseline.df%>%inner_join(ARV_df, by="patientID")
  
  ## End of One Hot Encoding
  clean.df = baseline.df
  
  return(clean.df)
}

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


import_longitudinal_data = function(){
  
  first_line =c("d4T + 3TC + NVP",'d4T + 3TC + EFV','3TC + TDF + DTG','3TC + AZT + ABC',
                '3TC + EFV + ABC','3TC + EFV + AZT','3TC + EFV + TDF','3TC + NVP + ABC',
                '3TC + NVP + AZT','3TC + NVP + TDF','3TC + RTV + AZT + ATV','3TC + RTV + AZT + LOP',
                '3TC + RTV + TDF + ATV','3TC + RTV + TDF + LOP','3TC + TDF + DTG','d4T + 3TC + EFV',
                'd4T + 3TC + NVP'
  )
  second_line=c('3TC + ABC + DTG','3TC + ABC + ETR','3TC + AZT + DTG','3TC + RTV + ABC + ATV',
                '3TC + RTV + ABC + LOP' )
  
  third_line =c("3TC + RTV + TDF + LOP + DTG" )
  
  raw1.df =  readr::read_csv("Prediction data 2018-01-01 to 2022-12-31.csv", na = "NULL")
  
  time_varrying.df=raw1.df%>% mutate(
    # Occupation
    Presence_of_OIs = if_else(is.na(Presence_of_OIs),0,1),
    Adherence_Counselling_Sessions =  if_else(is.na(Adherence_counseling),0,1),
    patientID= patientID
  )%>% mutate_at(c("Patient_Care_Status_Code"),care_status_cd) %>%
    mutate(
      
      # Clean Encounter Type Class
      Encounter_Type_Class = case_when(
        Encounter_Type_Name %in% c("ADULTINITIAL", "PEDSINITIAL", "YOUTHINITIAL") ~"Initial",
        Encounter_Type_Name %in% c("ADULTRETURN", "PEDSRETURN", "YOUTHRETURN") ~"Return",
        
        TRUE ~ "Other"),
      
      # Harmonize Travel_time
      Travel_time = case_when(
        Travel_time %in% c("LESS THAN ONE HOUR", "30 TO 60 MINUTES", "LESS THAN 30 MINUTES") ~"LESS THAN ONE HOUR",
        Travel_time %in% c("MORE THAN ONE HOUR", "ONE TO TWO HOURS", "MORE THAN TWO HOURS") ~"MORE THAN ONE HOUR",
        
        TRUE ~ Travel_time),
      
      # Harmonize Education Level
      Education_Level = case_when(
        Education_Level %in% c("FORM 1 TO 2","FORM 3 TO 4", "SECONDARY SCHOOL") ~"SECONDARY SCHOOL",
        Education_Level %in% c("PRE PRIMARY", "PRE UNIT", "STANDARD 1 TO 3", "STANDARD 4 TO 8") ~"PRIMARY SCHOOL",
        Education_Level %in% c("COLLEGE", "UNIVERSITY") ~"COLLEGE / UNIVERSITY",
        
        TRUE ~ Education_Level),
      
      # Harmonize Occupation
      Occupation = case_when(
        Occupation %in% c("TEACHER", "POLICE OFFICER", "HEALTH CARE PROVIDER",
                          "VOLUNTARY TESTING AND COUNSELING CENTER COUNSELOR",
                          "CLINICIAN", "FORMAL EMPLOYMENT", "INDUSTRIAL WORKER",
                          "LABORATORY TECHNOLOGIST", "MECHANIC", "MINER",
                          "NURSE", "OTHER HEALTH WORKER", "TRUCK DRIVER", "CASUAL WORKER",
                          "CIVIL SERVANT", "CLEANER" ) ~"EMPLOYED",
        Occupation %in% c("FARMER", "FISHING", "SELF EMPLOYMENT", "SEX WORKER", "BODA-BODA") ~"SELF EMPLOYMENT",
        Occupation %in% c("UNEMPLOYED", "OTHER NON-CODED", "NOT APPLICABLE", "HOUSEWIFE", 
                          "STUDENT") ~"UNEMPLOYED",
        
        TRUE ~ Occupation),
      
      # Clean Regimen Line
      Regimen_Line = as.integer(case_when(
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
        Entry_Point %in% c("ADULT INPATIENT SERVICE", "OUTPATIENT SERVICES") ~"INPATIENT / OUTPATIENT SERVICE",
        Entry_Point %in% c( "HIV COMPREHENSIVE CARE UNIT", "SEXUALLY TRANSMITTED INFECTION", "TUBERCULOSIS", "OTHER NON-CODED", "OSCAR PROGRAM", "SELF TEST") ~"OTHER",
        Entry_Point %in% c("MATERNAL CHILD HEALTH PROGRAM", "PEDIATRIC INPATIENT SERVICE") ~"PEDIATRIC SERVICE",
        Entry_Point %in% c("HOME BASED TESTING PROGRAM", "PERPETUAL HOME-BASED COUNSELING AND TESTING" ) ~"HOME BASED TESTING",
        Entry_Point %in% c("HIV TESTING SERVICES STRATEGY", "VOLUNTARY COUNSELING AND TESTING CENTER" ) ~"VOLUNTARY COUNSELING AND TESTING CENTER",
        
        TRUE ~ Entry_Point),
      
      ART_regimen =   ifelse(
        ART_regimen %in% c(first_line,second_line,third_line),
        ART_regimen, "Invalid Regimen"),
      
      Encounter_Date=as.Date(Encounter_Datetime),
      VL_suppression = if_else(Viral_Load >= 1000 | is.na(Viral_Load), 0, 1),
      Viral_Load_log10 = log10(Viral_Load+0.00000000000000001) # to avoid log10(0) = -Inf
      
      
    )  %>%
    select(-Patient_Care_Status_Code)%>% 
    group_by(patientID, Encounter_Date) %>%
    filter(row_number()==1)%>%ungroup() %>% # This collapses multiple encounters per days 
    group_by(patientID) %>%
    arrange( patientID, Encounter_Date)%>% # Just to make sure cronology of events are descending
    mutate(
      # First Encounter
      Next_Encounter_Datetime_null = lead(Encounter_Date, order_by = Encounter_ID), # lag
      Next_Encounter_Datetime = if_else(
        is.na(Next_Encounter_Datetime_null),
        as.Date(Sys.time()),
        Next_Encounter_Datetime_null
      ), # Set Null dates to 2022
      
      Visit_Number = row_number(),
      
      # Labeled response variables
      `Days defaulted` =   difftime(Next_Encounter_Datetime , RTC_Date , units = c("days")),
      `disengagement-1day` = factor(if_else(`Days defaulted` > 1, "Disengaged",  "Active In Care")),
      `disengagement-2wks` = factor(if_else(`Days defaulted` > 14, "Disengaged",  "Active In Care")),
      `disengagement-1month` =  factor(if_else(`Days defaulted` > 30, "Disengaged",  "Active In Care")),
      `disengagement-3month` =  factor(if_else(`Days defaulted` > 90, "Disengaged",  "Active In Care")),
      
      # Binary version of the response variable
      `disengagement-1day_bin`  = ifelse(`disengagement-1day` == "Disengaged", TRUE, FALSE),
      `disengagement-2wks_bin`  = ifelse(`disengagement-2wks` == "Disengaged", TRUE, FALSE),
      `disengagement-1month_bin`  = ifelse(`disengagement-1month` == "Disengaged", TRUE, FALSE),
      `disengagement-3month_bin`  = ifelse(`disengagement-3month` == "Disengaged", TRUE, FALSE),
      
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
                          "Presence_of_OIs", 
                          "Adherence_Counselling_Sessions",
                          "Clinic_Name", 
                          'ART_regimen'
  )
  
  clean.df = time_varrying.df%>% 
    mutate(across(all_of(vars_to_impute), ~.x, .names = "{.col}_orig")) %>%
    group_by(patientID) %>%
    mutate(across(all_of(vars_to_impute), ~ifelse(is.na(.), na.locf(., na.rm = FALSE), .))) %>% 
    ungroup()
  
  return(clean.df)
}



confIntAUC = function(model, index, y, newdata){
  
  AUC= format(round(h2o.performance(model = model, newdata = newdata)@metrics$AUC*index,2 ),nsmall = 2)
  LL = format(round(c(pROC::roc( as.numeric(as.data.frame(newdata[,y])[,y])-1,as.data.frame(predict(model, newdata = newdata))[,'Yes'], ci=TRUE, plot=FALSE) $ci*index)[1],2),nsmall = 2)
  UL = format(round(c(pROC::roc( as.numeric(as.data.frame(newdata[,y])[,y])-1,as.data.frame(predict(model, newdata = newdata))[,'Yes'], ci=TRUE, plot=FALSE) $ci*index)[3],2),nsmall = 2)
  
  return( list(AUC=paste0(AUC, ' (',LL,'-',UL,')'), LL=LL, UL=UL))
}


# Custom Predict Function
custom_predict <- function(model, newdata) {
  newdata_h2o <- as.h2o(newdata)
  res <- as.data.frame(h2o.predict(model, newdata_h2o))
  return(round(res[, 3]))  # round the probabilities
}





# Function for collecting cross-validation results: 

results_cross_validation <- function(h2o_model) {
  h2o_model@model$cross_validation_metrics_summary %>% 
    as.data.frame() %>% 
    select(-mean, -sd) %>% 
    t() %>% 
    as.data.frame() %>% 
    mutate_all(as.character) %>% 
    mutate_all(as.numeric) %>% 
    select(Accuracy = accuracy, 
           AUC = auc, 
           Precision = precision, 
           Specificity = specificity, 
           Recall = recall, 
           Logloss = logloss) %>% 
    return()
}



plot_results <- function(df_results) {
  df_results %>% 
    gather(Metrics, Values) %>% 
    ggplot(aes(Metrics, Values, fill = Metrics, color = Metrics)) +
    geom_boxplot(alpha = 0.3, show.legend = FALSE) + 
    theme(plot.margin = unit(c(1, 1, 1, 1), "cm")) +    
    scale_y_continuous(labels = scales::percent) + 
    facet_wrap(~ Metrics, scales = "free") + 
    labs(title = "Model Performance by Some Criteria Selected", y = NULL)
}

getAUC_onTestData <- function(i) {
  
  # Extract i-th model:
  best_ith <- h2o.getModel(autoML@leaderboard[i, 1])
  
  # Model performance by ith model by AUC on Test data:
  metrics_ith <- h2o.performance(model = best_ith, newdata = test)
  
  # Return output:
  return(data.frame(AUC_Test = metrics_ith@metrics$AUC, model_id = best_ith@model_id))
  
}

results_cross_validation <- function(h2o_model) {
  h2o_model@model$cross_validation_metrics_summary %>% 
    as.data.frame() %>% 
    arrange(desc(mean)) %>% 
    select(-mean, -sd) %>% 
    t() %>% 
    as.data.frame() %>% 
    mutate_all(as.character) %>% 
    mutate_all(as.numeric) %>% 
    select(Accuracy = accuracy, 
           AUC = auc, 
           Precision = precision, 
           Specificity = specificity, 
           Sensitivity = recall, 
           Logloss = logloss) %>% 
    return()
}