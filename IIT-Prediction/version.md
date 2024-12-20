# Premise

This file is used to keep track of model version metadata

## V1

TODO:

## V2

TODO:

## V3

TODO:

## V4

TODO:

## V5

TODO:

## V6

Version 6 of the model is trained using a larger dataset (All AMPATH care data) and more recent dataset (Anyone with an encounter after 2021):

- "Cohort 2021 Patients: 95101"
- "Cohort 2021 Visits: 859184"

Some predictors have been added while others have been removed. Here is a list of the new predictors used to train the model

```
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
```

Also here is a list of all predictors:

```

X=c(

  c(    'Age','Age_NA',
        'Gender' ,
        'Duration_in_HIV_care', 'Duration_in_HIV_care_NA',
        'BMI', 'BMI_NA',
        #'Days_to_Start_of_ART', 'Days_to_Start_of_ART_NA',
        'WHO_staging','WHO_staging_NA',
        'Viral_Load_log10', 'Viral_Load_log10_NA', 'VL_suppression', 'Days_Since_Last_VL',
        'HIV_disclosure','HIV_disclosure_NA',
        'Regimen_Line', 'Regimen_Line_NA',
        'Pregnancy',
        'CD4','CD4_NA', 'Days_Since_Last_CD4',
        "Encounter_Type_Class",
        'ART_regimen',
        'Visit_Number',
        'Days_defaulted_in_prev_enc', 'Days_defaulted_in_prev_enc_NA',
         'num_2wks_defaults_last_3visits', 'num_2wks_defaults_last_3visits_NA',
        'ever_defaulted_by_1m_in_last_1year','ever_defaulted_by_1m_in_last_1year_NA',
         'ever_defaulted_by_1m_in_last_2year','ever_defaulted_by_1m_in_last_2year_NA',

        # Baseline
        'Age_baseline',
        'Gender_baseline' ,
        'BMI_baseline',
        'WHO_staging_baseline',
        'VL_suppression_baseline',
        'Viral_Load_log10_baseline',
        'HIV_disclosure_baseline',
        'Regimen_Line_baseline',
        'Pregnancy_baseline',
        'CD4_baseline',
        "Clinic_Name_baseline",
        'ART_regimen_baseline',

        # New Vars
      'ART_Adherence',
      'HIV_disclosure_stage',
      'Clinic_County',
      'Clinic_Name',
      'Program_Name',
      'TB_screening',
      'TB_Test_Result',
      'On_TB_TX',
      'On_IPT',
      'CA_CX_Screening',
      'CA_CX_Screening_Result'



    )


)


```

### Model to use?

2_StackedEnsemble_BestOfFamily_1_AutoML_8_20230726_142520_auc_0.704

## V7

Version 7 of the model is trained using 2 cohorts of datasets:

- Adult 88,809 (93.383876%)
- Minor 6,292 (6.616124%)

With these changes, the cross-validated AUC has increased from ~70 to ~77

Some predictors have been added while others have been removed.

### New predictors

Here is a list of the new predictors that have been added

```
      'Month',
      'num_1day_defaults_last_3visits',
      'num_7days_defaults_last_3visits',
      'num_1month_defaults_last_3visits'
```

Please see the util files on how these variables are define

```
      Month = as.factor(as.numeric(format(as.Date(RTC_Date), "%m")))

      num_1day_defaults_last_3visits = as.double(lag(rollapplyr(`disengagement-1day_bin`, 3, sum, partial =TRUE),order_by = Encounter_ID)),
      num_1day_defaults_last_3visits = if_else(is.na(num_1day_defaults_last_3visits), 0, num_1day_defaults_last_3visits),

      num_7days_defaults_last_3visits = as.double(lag(rollapplyr(`disengagement-7days_bin`, 3, sum, partial =TRUE),order_by = Encounter_ID)),
      num_7days_defaults_last_3visits = if_else(is.na(num_7days_defaults_last_3visits), 0, num_7days_defaults_last_3visits),

      num_1month_defaults_last_3visits = as.double(lag(rollapplyr(`disengagement-1month_bin`, 3, sum, partial =TRUE),order_by = Encounter_ID)),
      num_1month_defaults_last_3visits = if_else(is.na(num_1month_defaults_last_3visits), 0, num_1month_defaults_last_3visits),

```

### Removed predictors

Here is a list of the old predictors that have been removed

```
      'VL_suppression',
      'num_2wks_defaults_last_3visits_NA'
```

### All predictors

Finally here is a list of all predictors:

```


X=c(

  c(    'Age','Age_NA',
        'Gender' ,
        'Duration_in_HIV_care', 'Duration_in_HIV_care_NA',
        'BMI', 'BMI_NA',
        #'Days_to_Start_of_ART', 'Days_to_Start_of_ART_NA',
        'WHO_staging','WHO_staging_NA',
        'Viral_Load_log10', 'Viral_Load_log10_NA', # REMOVED (V7) 'VL_suppression',
        'Days_Since_Last_VL',
        'HIV_disclosure','HIV_disclosure_NA',
        'Regimen_Line', 'Regimen_Line_NA',
        'Pregnancy',
        'CD4','CD4_NA', 'Days_Since_Last_CD4',
        "Encounter_Type_Class",
        'ART_regimen',
        'Visit_Number',
        'Days_defaulted_in_prev_enc', 'Days_defaulted_in_prev_enc_NA',
         'num_2wks_defaults_last_3visits', # REMOVED (V7) 'num_2wks_defaults_last_3visits_NA',
        'ever_defaulted_by_1m_in_last_1year','ever_defaulted_by_1m_in_last_1year_NA',
         'ever_defaulted_by_1m_in_last_2year','ever_defaulted_by_1m_in_last_2year_NA',

        # Baseline
        'Age_baseline',
        'Gender_baseline' ,
        'BMI_baseline',
        'WHO_staging_baseline',
        'VL_suppression_baseline',
        'Viral_Load_log10_baseline',
        'HIV_disclosure_baseline',
        'Regimen_Line_baseline',
        'Pregnancy_baseline',
        'CD4_baseline',
        "Clinic_Name_baseline",
        'ART_regimen_baseline',

        # New Vars (V6)
      'ART_Adherence',
      'HIV_disclosure_stage',
      'Clinic_County',
      'Clinic_Name',
      'Program_Name',
      'TB_screening',
      'TB_Test_Result',
      'On_TB_TX',
      'On_IPT',
      'CA_CX_Screening',
      'CA_CX_Screening_Result',

      # New Var (V7)
      'Month',
      'num_1day_defaults_last_3visits',
      'num_7days_defaults_last_3visits',
      'num_1month_defaults_last_3visits'




    )


)


```

### Model to use?

#### Adult Model

IIT-Prediction/model/V7/y0_1days_adult_IIT/1_StackedEnsemble_BestOfFamily_1_AutoML_1_20230812_150159_auc_0.775

Note: Please remember to factorize all character predictors before scoring

```
clean.df= clean.long.df %>%
      mutate_if(is.character, as.factor)
```

### Minor Model

IIT-Prediction/model/V7/y0_1day_minor_IIT/1_StackedEnsemble_BestOfFamily_1_AutoML_2_20230813_03957_auc_0.734

Note: Please remember to factorize all character predictors before scoring as shown below

```
clean.df= clean.long.df %>%
      mutate_if(is.character, as.factor)
```

### Monitoring

Please save logs especially warning logs which we can use to track any drift in concept or bad variables.

## V8

### New predictors

Here is a list of the new predictors that have been added

```
      'Days_Since_Last_VL_NA',
      'Days_Since_Last_CD4_NA',
      'BMI_baseline_NA',
      'WHO_staging_baseline_NA',
      'Regimen_Line_baseline_NA',
      'HIV_disclosure_baseline_NA',
      'CD4_baseline_NA',
      'Viral_Load_log10_baseline_NA'
```

### Removed Predictors

```
    'TB_screening',
    'On_TB_TX',
    'On_IPT',
    'CA_CX_Screening',
    'CA_CX_Screening_Result',
     'num_2wks_defaults_last_3visits',
      'ever_defaulted_by_1m_in_last_1year',
     'ever_defaulted_by_1m_in_last_1year_NA',
       'ever_defaulted_by_1m_in_last_2year',
     'ever_defaulted_by_1m_in_last_2year_NA',
      'Age_baseline',
      'Gender_baseline' ,
      'BMI_baseline',
      'WHO_staging_baseline',
      'VL_suppression_baseline',
      'Viral_Load_log10_baseline',
      'HIV_disclosure_baseline',
      'Regimen_Line_baseline',
      'Pregnancy_baseline',
      'CD4_baseline',
      "Clinic_Name_baseline",
      'ART_regimen_baseline',
```

## V9

Version 9 of the model is trained using 2 cohorts of datasets:

- Adult - up to 04-04-2024
- Minor - up to 04-04-2024

Facility level predictors have been added (please see the csv shared via drive)
We have simplified the model by removing some predictors

### New predictors

Here is a list of the new predictors that have been added

```
      'Days_Since_Last_VL_NA',
      'Days_Since_Last_CD4_NA',
      'BMI_baseline_NA',
      'WHO_staging_baseline_NA',
      'Regimen_Line_baseline_NA',
      'HIV_disclosure_baseline_NA',
      'CD4_baseline_NA',
      'Viral_Load_log10_baseline_NA',
      'Current_Clinic_County',
      'Size_Enrollments_Log10',
      'Volume_Visits_Log10',
      'Care Programme',
      'Facility Type'
```

### Removed predictors

Here is a list of the old predictors that have been removed

```
      'Clinic_County', # Removed in V9
      'Clinic_Name', # Removed in V9
      "Clinic_Name_baseline",  # Removed in V9
```

### All predictors

Finally here is a list of all predictors:

```


X=c(

   c(    
   
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
   'HIV_disclosure_stage', 
   'Program_Name', 
   'Days_Since_Last_CD4', 'Days_Since_Last_CD4_NA',
   'Month', 'TB_Test_Result', 
   'Viral_Load_log10', 'Viral_Load_log10_NA',
   'BMI', 'BMI_NA',
   'CD4','CD4_NA',  'Facility Type'
   
    )


)


```

### Model to use?

#### Adult Model

IIT-Prediction/model/V9/y0*1days_adult_IIT/1_StackedEnsemble*...

Note: Please remember to factorize all character predictors before scoring

```
clean.df= clean.long.df %>%
      mutate_if(is.character, as.factor)
```

### Minor Model

IIT-Prediction/model/V9/y0*1day_minor_IIT/1_StackedEnsemble*...

Note: Please remember to factorize all character predictors before scoring as shown below

```
clean.df= clean.long.df %>%
      mutate_if(is.character, as.factor)
```

### Monitoring

Please save logs especially warning logs which we can use to track any drift in concept or bad variables.

## V9B

Version 9B of the model is trained using 2 cohorts of datasets:

- Adult - up to 04-04-2024
- Minor - up to 04-04-2024


In version 9B we have changed how we define the outcome variable (Y), please see below

### Outcome Variable Changes

We first remove drug refill encounter types then recalculate next encounter date. ETL's next_clinical_datetime_hiv has drug refill next encounter date, that's why we need to recalculate. See the code below:

```
clean.df= clean.long.df %>% 
      filter(RTC_Date <= as.Date("2024-04-04") & Encounter_Date >= as.Date("2021-01-01") ) %>% # this is the db open & closure date
      filter(encounter_type!= 186 & encounter_type!= 158) %>% # V9B - STEP1 => REMOVE DRUG REFILL ENCOUNTER TYPES
      group_by(person_id)%>%
      mutate(
            Next_Encounter_Datetime = lead(Encounter_Date, order_by =Encounter_ID) # V9B - STEP2 =>  Lag next Enc Date instead of using ETL's next_clinical_datetime_hiv which has drug refill next encounter date

      ) %>%
      ungroup()

```



### New predictors

Here is a list of the new predictors that have been added from version 9 to 9B

None

### Removed predictors

Here is a list of the old predictors that have been removed from version 9 to 9B


None

### All predictors

Finally here is a list of all predictors:

```


X=c(

   c(    
   
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
   'HIV_disclosure_stage', 
   'Program_Name', 
   'Days_Since_Last_CD4', 'Days_Since_Last_CD4_NA',
   'Month', 'TB_Test_Result', 
   'Viral_Load_log10', 'Viral_Load_log10_NA',
   'BMI', 'BMI_NA',
   'CD4','CD4_NA',  'Facility Type'
   
    )


)


```

### Model to use?

#### Adult Model

IIT-Prediction/model/V9/y0_1days_adult_IIT/2_StackedEnsemble_BestOfFamily_*...

Note: We use 2_StackedEnsemble_BestOfFamily_ instead of 1_StackedEnsemble_AllModel_, because 2_StackedEnsemble_BestOfFamily_ offers similar performance with less variability. 
Note: Please remember to factorize all character predictors before scoring

```
clean.df= clean.long.df %>%
      mutate_if(is.character, as.factor)
```

### Minor Model

IIT-Prediction/model/V9/y0_1day_minor_IIT/2_StackedEnsemble_BestOfFamily_*...

Note: We use 2_StackedEnsemble_BestOfFamily_ instead of 1_StackedEnsemble_AllModel_, because 2_StackedEnsemble_BestOfFamily_ offers similar performance with less variability.
Note: Please remember to factorize all character predictors before scoring as shown below

```
clean.df= clean.long.df %>%
      mutate_if(is.character, as.factor)
```

### Monitoring

Please save logs especially warning logs which we can use to track any drift in concept or bad variables.


## V10

Version 10 of the model is trained using 2 cohorts of datasets:

- Adult - up to 04-04-2024
- Minor - up to 04-04-2024


In version 10 we have changed how we define the outcome variable (Y), please see below

### Outcome Variable Changes

Instead of using a Delta (number of days defaulted) of `>=1 days` we have changed to `>= 7 days`. Please see `y1` in: `IIT-Prediction/training scripts/V10/main.R`


### New predictors

Here is a list of the new predictors that have been added

```
num_7days_defaults_last_3visits
```

definition can be found here `IIT-Prediction/training scripts/V10/utils.R`

### Removed predictors


None

### All predictors

Finally here is a list of all predictors:

```

X=c(

   c(    
   
   'Age','Age_NA', 
   'Gender' ,  
   'num_1day_defaults_last_3visits',
   'num_7days_defaults_last_3visits',
   'Current_Clinic_County',
   'Days_defaulted_in_prev_enc', 'Days_defaulted_in_prev_enc_NA',
   'Size_Enrollments_Log10',
   'Volume_Visits_Log10',
   'Care Programme',
   'Days_Since_Last_VL',  'Days_Since_Last_VL_NA',
   'Visit_Number',  
   'HIV_disclosure_stage', 
   'Program_Name', 
   'Days_Since_Last_CD4', 'Days_Since_Last_CD4_NA',
   'Month', 'TB_Test_Result', 
   'Viral_Load_log10', 'Viral_Load_log10_NA',
   'BMI', 'BMI_NA',
   'CD4','CD4_NA',  'Facility Type'
   
    )


)


```

### Model to use?

#### Adult Model

`IIT-Prediction/model/V10/y1_7days_adult_IIT/2_StackedEnsemble_BestOfFamily_*...`

Note: Please remember to factorize all character predictors before scoring

```
clean.df= clean.long.df %>%
      mutate_if(is.character, as.factor)
```

### Minor Model

`IIT-Prediction/model/V10/y1_7days_adult_IIT/2_StackedEnsemble_BestOfFamily_*...`

Note: Please remember to factorize all character predictors before scoring as shown below

```
clean.df= clean.long.df %>%
      mutate_if(is.character, as.factor)
```

### Monitoring

Please save logs especially warning logs which we can use to track any drift in concept or bad variables.


## V11

Version 11 of the model is trained using 2 cohorts of datasets:

- Adult - up to 2024-09-30
- Minor - up to 2024-09-30


In version 11 we have changed how we define the outcome variable (Y), please see below

### Outcome Variable Changes

The definitions for the outcome variables have changed. Please see `disengagement-1day` and `disengagement-7days` in: `IIT-Prediction/training scripts/V11/utils.R`

```
 ######################## Modified in V11 ###############################################
      
       # If Next Encounter type is 186 or 153, set the response variables to NA ==>  Modified in V11
      `disengagement-1day` = factor(if_else(  Next_Encounter_Type %in% c(186,153,158), NA, `disengagement-1day`)),
      `disengagement-2wks` = factor(if_else(  Next_Encounter_Type %in% c(186,153,158), NA, `disengagement-2wks`)),
      `disengagement-1month` = factor(if_else(  Next_Encounter_Type %in% c(186,153,158), NA, `disengagement-1month`)),
      `disengagement-3month` = factor(if_else(  Next_Encounter_Type %in% c(186,153,158), NA, `disengagement-3month`)),
      `disengagement-7days` = factor(if_else(  Next_Encounter_Type %in% c(186,153,158), NA, `disengagement-7days`)),
      
      # Binary version of the response variable
      `disengagement-1day_bin`  = ifelse(`disengagement-1day` == "Disengaged", TRUE, FALSE),
      `disengagement-2wks_bin`  = ifelse(`disengagement-2wks` == "Disengaged", TRUE, FALSE),
      `disengagement-1month_bin`  = ifelse(`disengagement-1month` == "Disengaged", TRUE, FALSE),
      `disengagement-3month_bin`  = ifelse(`disengagement-3month` == "Disengaged", TRUE, FALSE),
      `disengagement-7days_bin`  = ifelse(`disengagement-7days` == "Disengaged", TRUE, FALSE),

```


### Predictors related to previous IIT have changed 

The definitions for number of missed-visits out of the last three have changed. Please see: `IIT-Prediction/training scripts/V11/utils.R`

```
      # Number of non-clinical encounters in the last 3 visits ==> Added in V11
      num_of_med_pickups_in_last_3visits = as.double(lag(rollapplyr(is.na(`disengagement-1day`), 3, 
                                                                    sum_ignore_na, partial =T),order_by = Encounter_ID)) %>% replace_na(0),
      
      # Number of days defaulted in the previous CLINICAL encounters ==> Added V11
      is_non_med_pickup_visit = if_else(encounter_type %nin% c(186,153,158), 1, 0),
      index_of_last_clinical_visit =  na_if(lag(cummax(row_number() * is_non_med_pickup_visit),order_by = Encounter_ID), 0),
      Days_defaulted_in_prev_enc = `Days defaulted`[index_of_last_clinical_visit], # Modified in V11
 
      # Number of missed-visit out of the last three for each endpoint Y ==> V11
      num_2wks_defaults_last_3visits = as.double(lag(rollapplyr(`disengagement-2wks_bin`, 3+num_of_med_pickups_in_last_3visits,
                                                                sum_ignore_na, partial =T),order_by = Encounter_ID)) %>% replace_na(0),
      num_1day_defaults_last_3visits = as.double(lag(rollapplyr(`disengagement-1day_bin`, 3+num_of_med_pickups_in_last_3visits, 
                                                                sum_ignore_na, partial =T),order_by = Encounter_ID)) %>% replace_na(0),
      num_7days_defaults_last_3visits = as.double(lag(rollapplyr(`disengagement-7days_bin`, 3+num_of_med_pickups_in_last_3visits, 
                                                                 sum_ignore_na, partial =T),order_by = Encounter_ID)) %>% replace_na(0),
      num_1month_defaults_last_3visits = as.double(lag(rollapplyr(`disengagement-1month_bin`, 3+num_of_med_pickups_in_last_3visits, 
                                                                  sum_ignore_na, partial =T),order_by = Encounter_ID)) %>% replace_na(0),
```

### Data Cleaning changes

#### Days_defaulted_in_prev_enc_log changes

```
     Days_defaulted_in_prev_enc =  if_else(Days_defaulted_in_prev_enc<=-31, -31,Days_defaulted_in_prev_enc),
     Days_defaulted_in_prev_enc =  if_else(Days_defaulted_in_prev_enc>365, 365,Days_defaulted_in_prev_enc), 
     Days_defaulted_in_prev_enc_log = log(Days_defaulted_in_prev_enc+32), # Added in V11
```

#### BMI changes

```
    BMI =  if_else(between(BMI, 10, 35), BMI,NA_real_), # Modified in V11
```

### New Predictors

 - We have dropped `Days_defaulted_in_prev_enc` and `Days_defaulted_in_prev_enc_NA`
 - We have substituted with  `Days_defaulted_in_prev_enc_log` and `Days_defaulted_in_prev_enc_log_NA`


### All Predictors

Finally here is a list of all predictors:

```

X=c(

   c(    
   
   'Age','Age_NA', 
   'Gender' ,  
   'num_1day_defaults_last_3visits',
   'num_7days_defaults_last_3visits',
   'Current_Clinic_County',
   'Days_defaulted_in_prev_enc_log', 'Days_defaulted_in_prev_enc_log_NA', # Modified in V11
   'Size_Enrollments_Log10',
   'Volume_Visits_Log10',
   'Care Programme',
   'Days_Since_Last_VL',  'Days_Since_Last_VL_NA',
   'Visit_Number',  
   'HIV_disclosure_stage', 
   'Program_Name', 
   'Days_Since_Last_CD4', 'Days_Since_Last_CD4_NA',
   'Month', 'TB_Test_Result', 
   'Viral_Load_log10', 'Viral_Load_log10_NA',
   'BMI', 'BMI_NA',
   'CD4','CD4_NA',  'Facility Type'
   
    )


)


```

### 1-day Model to use?

#### Adult Model

`IIT-Prediction/model/V11/y0_1day_adult_IIT/1_StackedEnsemble_BestOfFamily_*...`

Note: Please note that 1day model only  does not have this predictor 'num_7days_defaults_last_3visits'


#### Minor Model

`IIT-Prediction/model/V11/y0_1day_minor_IIT/1_StackedEnsemble_BestOfFamily_*...`

Note: Please note that 1day model does not have this predictor 'num_7days_defaults_last_3visits'



### 7-days Model to use?

#### Adult Model

`IIT-Prediction/model/V11/y1_7days_adult_IIT/1_StackedEnsemble_BestOfFamily_*...`

Note: Please note that 7days model has both these predictors: 'num_1day_defaults_last_3visits', 'num_7days_defaults_last_3visits'


#### Minor Model

`IIT-Prediction/model/V11/y1_7days_minor_IIT/1_StackedEnsemble_BestOfFamily_*...`

Note: Please note that 7days model has both these predictors: 'num_1day_defaults_last_3visits', 'num_7days_defaults_last_3visits'


### Monitoring

Please save logs especially warning logs which we can use to track any drift in concept or bad variables.
