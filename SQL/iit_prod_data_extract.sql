SET @location = 90;
SET @Start_Date = DATE('2018-01-01');
SET @End_Date = DATE('2023-05-04');
-- 26,23,319,130,313,9,78,310,20,312,12,321,8,341,65,314,64,83,90,106,86,336,91,320,74,76,79,100,311,75 extract for all these sites

# dates in the future

SELECT p.person_id                                                                        AS person_id,
       TIMESTAMPDIFF(YEAR, p.birthdate, fs.encounter_datetime)                            AS Age,
       IF(p.birthdate is null, 1, 0)                                                      AS Age_NA,
       p.gender                                                                           as Gender,
       baseline.marital_status                                                            as Marital_status,
       TIMESTAMPDIFF(YEAR, IF(YEAR(fs.arv_first_regimen_start_date) >= 2000, DATE(fs.arv_first_regimen_start_date),
                              NULL), DATE(fs.encounter_datetime))                         as Duration_in_HIV_care,
       IF(fs.arv_first_regimen_start_date IS NULL OR YEAR(fs.arv_first_regimen_start_date) < 2000, 1,
          0)                                                                              as Duration_in_HIV_care_NA,
       ROUND(fs.weight / ((fs.height / 100) * (fs.height / 100)), 2)                      as BMI,
       IF(fs.weight is null or fs.height is null or fs.weight < 1 or fs.height < 1, 1, 0) as BMI_NA,
       CASE
           WHEN baseline.travel_time IN ('LESS THAN ONE HOUR', '30 TO 60 MINUTES', 'LESS THAN 30 MINUTES')
               THEN 'LESS THAN ONE HOUR'
           WHEN baseline.travel_time IN ('MORE THAN ONE HOUR', 'ONE TO TWO HOURS', 'MORE THAN TWO HOURS')
               THEN 'MORE THAN ONE HOUR'
           ELSE baseline.travel_time
           END                                                                            as Travel_time,
       DATEDIFF(IF(YEAR(fs.arv_first_regimen_start_date) >= 2000, DATE(fs.arv_first_regimen_start_date), NULL),
                IF(YEAR(fs.hiv_start_date) >= 2000, DATE(fs.hiv_start_date),
                   NULL))                                                                 as Days_to_Start_of_ART, -- i.e Late of Earlier
       IF(fs.arv_first_regimen_start_date is null or YEAR(fs.arv_first_regimen_start_date) < 2000
              or fs.hiv_start_date is null or YEAR(fs.hiv_start_date) < 2000, 1, 0)       as Days_to_Start_of_ART_NA,
       fs.cur_who_stage                                                                   as WHO_staging,
       IF(fs.cur_who_stage is null, 1, 0)                                                 as WHO_staging_NA,
       LOG10(fs.vl_resulted + .0000000000001)                                             as Viral_Load_log10,
       IF(fs.vl_resulted is null, 1, 0)                                                   as Viral_Load_log10_NA,
       IF(fs.vl_resulted < 1000, 1, 0)                                                    as VL_suppression,
       fs.hiv_status_disclosed                                                            as HIV_disclosure,
       IF(fs.hiv_status_disclosed is null, 1, 0)                                          as HIV_disclosure_NA,
       CASE
           WHEN dt4.Regimen_Line = 'FIRST LINE HIV ANTIRETROVIRAL DRUG TREATMENT' THEN 1
           WHEN dt4.Regimen_Line = 'SECOND LINE HIV ANTIRETROVIRAL DRUG TREATMENT' THEN 2
           WHEN dt4.Regimen_Line = 'THIRD LINE HIV ANTIRETROVIRAL DRUG TREATMENT' THEN 3
           WHEN REPLACE(etl.get_arv_names(fs.cur_arv_meds), '##', '+') in
                ('d4T + 3TC + NVP', 'd4T + 3TC + EFV', '3TC + TDF + DTG', '3TC + AZT + ABC', '3TC + EFV + ABC',
                 '3TC + EFV + AZT', '3TC + EFV + TDF', '3TC + NVP + ABC', '3TC + NVP + AZT', '3TC + NVP + TDF',
                 '3TC + RTV + AZT + ATV', '3TC + RTV + AZT + LOP', '3TC + RTV + TDF + ATV', '3TC + RTV + TDF + LOP',
                 '3TC + TDF + DTG', 'd4T + 3TC + EFV', 'd4T + 3TC + NVP')
               THEN 1
           WHEN REPLACE(etl.get_arv_names(fs.cur_arv_meds), '##', '+') in
                ('3TC + ABC + DTG', '3TC + ABC + ETR', '3TC + AZT + DTG', '3TC + RTV + ABC + ATV',
                 '3TC + RTV + ABC + LOP')
               THEN 2
           WHEN REPLACE(etl.get_arv_names(fs.cur_arv_meds), '##', '+') = '3TC + RTV + TDF + LOP + DTG'
               THEN 3
           ELSE 5
           END                                                                            as Regimen_Line,
       IF(dt4.Regimen_Line is null and fs.cur_arv_meds is null, 1, 0)                     as Regimen_Line_NA,
       CASE
           WHEN fs.is_pregnant = 1 THEN 'Pregnant'
           WHEN fs.is_pregnant = 0 or fs.is_pregnant is null THEN 'Not Pregnant'
           END                                                                            AS Pregnancy,
       CASE
           WHEN fs.location_id IN (55, 315, 19, 230, 26, 23, 319, 130, 313, 9, 78, 310, 20, 312, 12, 321, 8, 341)
               THEN 'Urban'
           WHEN fs.location_id IN (65, 314, 64, 83, 316, 90, 135, 106, 86, 336, 91, 320, 74, 76, 79, 100, 311, 75)
               THEN 'Rural'
           ELSE NULL END                                                                  AS Clinic_Location,      -- i.e Urban or Rural
       dt2.tb                                                                             as TB_Comorbidity,
       fs.cd4_resulted                                                                    AS CD4,
       IF(fs.cd4_resulted is null, 1, 0)                                                  AS CD4_NA,
       CASE
           WHEN baseline.entry_point IN ('ADULT INPATIENT SERVICE', 'OUTPATIENT SERVICES')
               THEN 'INPATIENT / OUTPATIENT SERVICE'
           WHEN baseline.entry_point IN ('HIV COMPREHENSIVE CARE UNIT', 'SEXUALLY TRANSMITTED INFECTION',
                                         'TUBERCULOSIS', 'OTHER NON-CODED', 'OSCAR PROGRAM', 'SELF TEST')
               THEN 'OTHER'
           WHEN baseline.entry_point IN ('MATERNAL CHILD HEALTH PROGRAM', 'PEDIATRIC INPATIENT SERVICE')
               THEN 'PEDIATRIC SERVICE'
           WHEN baseline.entry_point IN ('HOME BASED TESTING PROGRAM', 'PERPETUAL HOME-BASED COUNSELING AND TESTING')
               THEN 'HOME BASED TESTING'
           WHEN baseline.entry_point IN ('"HIV TESTING SERVICES STRATEGY', 'VOLUNTARY COUNSELING AND TESTING CENTER')
               THEN 'VOLUNTARY COUNSELING AND TESTING CENTER'
           ELSE baseline.entry_point
           END                                                                            as Entry_Point,
       CASE
           WHEN et.name in ('ADULTINITIAL', 'PEDSINITIAL', 'YOUTHINITIAL') THEN 'Initial'
           WHEN et.name in ('ADULTRETURN', 'PEDSRETURN', 'YOUTHRETURN') THEN 'Return'
           ELSE 'Other' END                                                               as Encounter_Type_Class, -- NB Look into 'OTHER'
       CASE
           WHEN baseline.education in ('FORM 1 TO 2', 'FORM 3 TO 4', 'SECONDARY SCHOOL')
               THEN 'SECONDARY SCHOOL'
           WHEN baseline.education in ('PRE PRIMARY', 'PRE UNIT', 'STANDARD 1 TO 3', 'STANDARD 4 TO 8')
               THEN 'PRIMARY SCHOOL'
           WHEN baseline.education in ('COLLEGE', 'UNIVERSITY')
               THEN 'COLLEGE / UNIVERSITY'
           ELSE baseline.education
           END                                                                            as Education_Level,
       CASE
           WHEN baseline.occupation in ('TEACHER', 'POLICE OFFICER', 'HEALTH CARE PROVIDER',
                                        'VOLUNTARY TESTING AND COUNSELING CENTER COUNSELOR', 'CLINICIAN',
                                        'FORMAL EMPLOYMENT', 'INDUSTRIAL WORKER', 'LABORATORY TECHNOLOGIST', 'MECHANIC',
                                        'MINER', 'NURSE', 'OTHER HEALTH WORKER', 'TRUCK DRIVER', 'CASUAL WORKER',
                                        'CIVIL SERVANT', 'CLEANER')
               THEN 'EMPLOYED'
           WHEN baseline.occupation in ('FARMER', 'FISHING', 'SELF EMPLOYMENT', 'SEX WORKER', 'BODA-BODA')
               THEN 'SELF EMPLOYMENT'
           WHEN baseline.occupation in ('UNEMPLOYED', 'OTHER NON-CODED', 'NOT APPLICABLE', 'HOUSEWIFE', 'STUDENT')
               THEN 'UNEMPLOYED'
           ELSE baseline.occupation
           END                                                                            as Occupation,
       dt2.oi                                                                             as Presence_of_OIs,
       mc.mrsDisplay                                                                      as Clinic_Name,
       REPLACE(etl.get_arv_names(fs.cur_arv_meds), '##', '+')                             as ART_regimen,
       visit_num                                                                          as Visit_Number,
       encounter_datetime,
       prev_clinical_rtc_date_hiv,
       DATEDIFF(encounter_datetime, prev_clinical_rtc_date_hiv)                           as Days_defaulted
FROM amrs.person p
         INNER JOIN etl.flat_hiv_summary_v15b fs ON p.person_id = fs.person_id and is_clinical_encounter = 1
    AND arv_start_date is not null AND fs.location_id = @location
    AND DATE(fs.rtc_date) = @End_Date
         LEFT OUTER JOIN etl.mfl_codes mc ON fs.location_id = mc.mrsId
         LEFT OUTER JOIN amrs.encounter_type et ON fs.encounter_type = et.encounter_type_id and et.retired = 0
         LEFT OUTER JOIN (SELECT o.person_id,
                                 MAX(IF(o.concept_id = 1054, cn.name, NULL))          as marital_status,
                                 MAX(IF(o.concept_id = 2051, cn.name, NULL))          as entry_point,
                                 MAX(IF(o.concept_id in (1972, 1973), cn.name, NULL)) as occupation,
                                 MAX(IF(o.concept_id = 1605, cn.name, NULL))          as education,
                                 MAX(IF(o.concept_id = 1710, cn.name, NULL))          as distance,
                                 MAX(IF(o.concept_id = 5605, cn.name, NULL))          as travel_time,
                                 MAX(IF(o.concept_id = 8365, cn.name, NULL))          as hiv_progression
                          FROM amrs.encounter e
                                   INNER JOIN amrs.obs o ON e.encounter_id = o.encounter_id AND e.voided = 0
                              AND o.voided = 0 AND concept_id IN (1054, 2051, 1972, 1973, 1605, 1710, 5605, 8365)
                                   INNER JOIN amrs.concept_name cn
                                              ON o.value_coded = cn.concept_id AND cn.voided = 0
                                                  AND cn.locale = 'en' AND locale_preferred = 1
                          WHERE e.location_id = @location
                          GROUP BY person_id) AS baseline ON p.person_id = baseline.person_id

         LEFT OUTER JOIN(SELECT e.patient_id,
                                e.encounter_id,
                                visit_id,
                                CASE
                                    WHEN o.concept_id in (10591) and o.value_coded in (1066) THEN 'No'
                                    WHEN o.concept_id in (10591) and o.value_coded in (1065) THEN 'Yes'
                                    ELSE NULL END AS tb,
                                CASE
                                    WHEN o.concept_id in (6836) and o.value_coded in (1066) THEN 'No'
                                    WHEN o.concept_id in (6836) and o.value_coded in (1065) THEN 'Yes'
                                    ELSE NULL END AS art_toxicity,
                                CASE
                                    WHEN ((o.concept_id in (6474) AND o.value_coded in (1065)) ||
                                          (o.concept_id in (1685) AND o.value_coded is not null)) THEN 'Yes'
                                    WHEN o.concept_id in (6474) AND o.value_coded in (1066) THEN 'No' -- never
                                    ELSE NULL END AS Substance_Use,
                                cn.name           as alcohol,
                                CASE
                                    WHEN o.concept_id in (7684, 10280) and o.value_coded in (1066) THEN 'No'
                                    WHEN o.concept_id in (7684, 10280) and o.value_coded in (1065) THEN 'Yes'
                                    ELSE NULL END AS mental_health,
                                CASE
                                    WHEN o.concept_id in (6903) THEN 'Yes'
                                    ELSE NULL END AS oi,
                                CASE
                                    WHEN o.concept_id in (9771) and o.value_coded in (1066) THEN 'No'
                                    WHEN o.concept_id in (9771) and o.value_coded in (1065) THEN 'Yes'
                                    ELSE NULL END AS adherence_counselling,
                                CASE
                                    WHEN o.concept_id in (6419) and o.value_coded in (1066) THEN 'No'
                                    WHEN o.concept_id in (6419) and o.value_coded in (1065) THEN 'Yes'
                                    ELSE NULL END AS hospitalization
                         FROM amrs.encounter e
                                  INNER JOIN amrs.obs o ON e.encounter_id = o.encounter_id AND e.voided = 0
                             AND o.voided = 0
                             AND concept_id in (6836, 10591, 6474, 1685, 1685, 7684, 10280, 6903, 9771, 6419)
                                  LEFT OUTER JOIN amrs.concept_name cn
                                                  ON o.value_coded = cn.concept_id AND cn.locale = 'en' AND
                                                     locale_preferred = 1
                         WHERE e.location_id = @location
                           AND (DATE(e.encounter_datetime) BETWEEN @Start_Date and @End_Date)
                         group by e.visit_id) AS dt2 ON fs.visit_id = dt2.visit_id

         LEFT OUTER JOIN(SELECT person_id,
                                e.encounter_id,
                                visit_id,
                                MAX(IF(o.concept_id = 11124, cn.name, null)) as health_status,
                                MAX(IF(o.concept_id = 10012, cn.name, null)) as social_support
                         FROM amrs.encounter e
                                  INNER JOIN amrs.obs o
                                             ON e.encounter_id = o.encounter_id AND concept_id in (11124, 10012)
                                                 AND o.voided = 0 and o.location_id = @location AND e.voided = 0 AND
                                                (DATE(e.encounter_datetime) BETWEEN @Start_Date and @End_Date)
                                  INNER JOIN amrs.concept_name cn ON cn.concept_id = o.value_coded
                             AND cn.locale = 'en' AND locale_preferred = 1
                         GROUP BY e.visit_id) dt3 ON fs.visit_id = dt3.visit_id

         LEFT OUTER JOIN (SELECT person_id,
                                 e.encounter_id,
                                 visit_id,
                                 cn.name as Regimen_Line
                          FROM amrs.encounter e
                                   INNER JOIN amrs.obs o ON e.encounter_id = o.encounter_id AND concept_id in (6744) AND
                                                            (DATE(e.encounter_datetime) BETWEEN @Start_Date and @End_Date)
                              and o.location_id = @location AND e.voided = 0 AND o.voided = 0
                                   INNER JOIN amrs.concept_name cn ON cn.concept_id = o.value_coded
                          GROUP BY e.visit_id) dt4 ON fs.encounter_id = dt4.encounter_id

