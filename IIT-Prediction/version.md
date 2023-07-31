
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

Version 6 of the model is trained using a larger dataset (All AMPATH care data)  and more recent dataset (Anyone with an encounter after 2021):

* "Cohort 2021 Patients: 95101"
* "Cohort 2021 Visits: 859184"

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
