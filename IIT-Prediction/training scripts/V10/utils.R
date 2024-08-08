
# custom operator 
`%nin%` <- Negate(`%in%`)

# Function that assign golds
assign_folds <- function(df, k_folds) {
  # Set seed for reproducibility
  set.seed(123)
  
  # Randomly shuffle the unique patient_ids
  shuffled_patient_ids <- sample(unique(df$person_id))
  
  # Calculate the fold_id for each person_id
  fold_ids <- rep(1:k_folds, length.out = length(shuffled_patient_ids))
  
  # Create a lookup table for fold_id
  fold_lookup <- data.frame(person_id = shuffled_patient_ids,
                            fold_id = fold_ids)
  
  # Merge the lookup table with the original dataframe
  df <- df %>%
    left_join(fold_lookup, by = "person_id")
  
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
  time_varrying.df=df%>%
    filter( encounter_type!= 186 & encounter_type!= 158) %>% # V9B remove Drug Pickup and TX Supporter Encounters
    mutate(
      
      # Set NA: for 1 and NA levels
      Pregnancy = if_else(is.na(Pregnancy),0,Pregnancy),
      
      # Change date time to date
      Encounter_Date=as.Date(encounter_datetime),
      VL_Order_Date =as.Date(VL_Order_Date),
      CD4_Order_Date =as.Date(CD4_Order_Date),
      #Next_Encounter_Datetime =as.Date(next_clinical_datetime_hiv), # V9B
      RTC_Date = as.Date(rtc_date),#pmin(as.Date(rtc_date), as.Date(med_pickup_rtc_date), na.rm = TRUE),
      RTC_GT_DB_Closure = factor(if_else(RTC_Date >= as.Date("2024-04-04"), 'Yes', 'No')),
      
      Encounter_ID=encounter_id,
      ART_Adherence = cur_arv_adherence,
      HIV_disclosure_stage = if_else(is.na(hiv_disclosure_status_value),"Not Done",hiv_disclosure_status_value),
      Clinic_County=Clinic_County,
      Clinic_Name =Clinic_Name,
      Program_Name = if_else(is.na(Program_Name),"Unknown",Program_Name),     
      # New Vars
      TB_screening = tb_screen,
      TB_Test_Result =factor(tb_test_result), 
      On_TB_TX = on_tb_tx,
      On_IPT = on_ipt,
      CA_CX_Screening =if_else(is.na(ca_cx_screening),0,ca_cx_screening),
      CA_CX_Screening_Result = factor(if_else(is.na(ca_cx_screening_result),1118,ca_cx_screening_result))
      
      
    )  %>%
    group_by(person_id, Encounter_Date) %>%
    filter(row_number()==1)%>%ungroup() %>% # This collapses multiple encounters per day
    group_by(person_id) %>%
    arrange( person_id, Encounter_Date)%>% # Just to make sure chronology of events are descending
    mutate(
      
      Next_Encounter_Datetime = lead(Encounter_Date, order_by =Encounter_ID), # V9B use next Enc Date instead
      # Set Null dates to today
      Next_Encounter_Datetime = if_else( is.na(Next_Encounter_Datetime), as.Date(Sys.time()),Next_Encounter_Datetime ),
      Visit_Number = row_number(),
      
      # Lab Values
      # VL processing
      VL_suppression = if_else(Viral_Load >= 1000 | is.na(Viral_Load), 0, 1),
      Viral_Load_log10 = log10(Viral_Load+1), # to avoid log10(0) = -Inf
      
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
      `disengagement-1day` = factor(if_else(`Days defaulted` >= 1, "Disengaged",  "Active In Care")),
      `disengagement-2wks` = factor(if_else(`Days defaulted` >= 14, "Disengaged",  "Active In Care")),
      `disengagement-1month` =  factor(if_else(`Days defaulted` >= 28, "Disengaged",  "Active In Care")),
      `disengagement-3month` =  factor(if_else(`Days defaulted` >= 90, "Disengaged",  "Active In Care")),
      `disengagement-7days` = factor(if_else(`Days defaulted` >= 7, "Disengaged",  "Active In Care")),
      
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
      
      num_1day_defaults_last_3visits = as.double(lag(rollapplyr(`disengagement-1day_bin`, 3, sum, partial =TRUE),order_by = Encounter_ID)),
      num_1day_defaults_last_3visits = if_else(is.na(num_1day_defaults_last_3visits), 0, num_1day_defaults_last_3visits),
      
      num_7days_defaults_last_3visits = as.double(lag(rollapplyr(`disengagement-7days_bin`, 3, sum, partial =TRUE),order_by = Encounter_ID)),
      num_7days_defaults_last_3visits = if_else(is.na(num_7days_defaults_last_3visits), 0, num_7days_defaults_last_3visits),
      
      num_1month_defaults_last_3visits = as.double(lag(rollapplyr(`disengagement-1month_bin`, 3, sum, partial =TRUE),order_by = Encounter_ID)),
      num_1month_defaults_last_3visits = if_else(is.na(num_1month_defaults_last_3visits), 0, num_1month_defaults_last_3visits),
      
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
                          'BMI',
                          'WHO_staging',
                          'VL_suppression', 
                          'Viral_Load_log10',
                          'HIV_disclosure',
                          'Regimen_Line', 
                          'Pregnancy',
                          'CD4',
                          "Clinic_Name", 
                          'ART_regimen',
                          'ART_Adherence',
                          'HIV_disclosure_stage',
                          'TB_Test_Result',
                          'On_TB_TX',
                          'On_IPT',
                          'CA_CX_Screening_Result'
                          
  )
  time_varrying.df%>% select(vars_to_impute)
  
  clean.df = time_varrying.df%>% 
    mutate(across(all_of(vars_to_impute), ~.x, .names = "{.col}_orig")) %>%
    group_by(person_id) %>%
    # Add baseline vars
    mutate(across(all_of(vars_to_impute),  ~ if_else(Visit_Number == 1, ., NA),.names = "{.col}_baseline")) %>% 
    #LOCF stands for “Last Observation Carried Forward.” 
    mutate(across(all_of(c(vars_to_impute, paste0(vars_to_impute, "_baseline"))), ~ifelse(is.na(.), na.locf(., na.rm = FALSE), .))) %>% 
    ungroup()%>%
    ## Factor the response variable
    mutate(
      y0=as.factor(`disengagement-1day`),
      y1=as.factor(`disengagement-7days`),
      y2=as.factor(`disengagement-1month`), # This is the main reponse that was used to train the models
      y3=as.factor(`disengagement-3month`),
      Month = as.factor(as.numeric(format(as.Date(RTC_Date), "%m")))
    )
  
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