SET @location=106;  
SET @Start_Date = DATE('2018-01-01');
SET @End_Date = DATE('2022-12-31');
-- 26,23,319,130,313,9,78,310,20,312,12,321,8,341,65,314,64,83,90,106,86,336,91,320,74,76,79,100,311,75 extract for all these sites

SELECT 
	fs.person_id as patientID,
	p.gender as Gender,
	baseline.marital_status AS Marital_status,
	TIMESTAMPDIFF(YEAR,p.birthdate,fs.encounter_datetime) AS Age,
	mc.mrsDisplay as Clinic_Name,
	mc.mflCode AS Clinic_Id,
	pa.address1 AS County,
	pa.address2 AS Sub_County,
    et.name as Encounter_Type_Name,
    et.description as Encounter_Type_Description,
	fs.encounter_id as 	Encounter_ID,
	fs.encounter_datetime as Encounter_Datetime,
	DATE(fs.rtc_date) as RTC_Date,
    IF(YEAR(DATE(fs.arv_first_regimen_start_date))!=1900,DATE(fs.arv_first_regimen_start_date),NULL)  AS ART_Start_Date,
	TIMESTAMPDIFF(YEAR,IF(YEAR(DATE(fs.arv_first_regimen_start_date))!=1900,DATE(fs.arv_first_regimen_start_date),NULL),DATE(fs.encounter_datetime)) as Duration_in_HIV_care,
	baseline.education as Education_Level, 
    fs.weight as Weight,
    fs.height as Height,
	ROUND(fs.weight/((fs.height/100)*(fs.height/100)),2)	as BMI,
	baseline.occupation as Occupation, 
	CASE 
	WHEN fs.location_id in(55,315,19,230,26,23,319,130,313,9,78,310,20,312,12,321,8,341) THEN 'Urban' 
	WHEN fs.location_id in(65,314,64,83,316,90,135,106,86,336,91,320,74,76,79,100,311,75) THEN 'Rural' 
	ELSE NULL END AS Clinic_Location, -- i.e Urban or Rural -- NOT AVAILABLE
	baseline.distance as Distance_to_clinic,
	baseline.travel_time as Travel_time,
	baseline.entry_point as Entry_Point,
    dt2.alcohol as Alcohol_Use,
	dt2.Substance_Use as Substance_use,
	dt2.tb as TB_Comorbidity,
    IF(YEAR(DATE(fs.enrollment_date))!=1900,DATE(fs.enrollment_date),NULL)  as Enrollment_Date,
    IF(YEAR(DATE(fs.hiv_start_date))!=1900,DATE(fs.hiv_start_date),NULL)  as HIV_Start_Date,
	DATEDIFF(IF(YEAR(DATE(fs.arv_first_regimen_start_date))!=1900,DATE(fs.arv_first_regimen_start_date),NULL),IF(YEAR(DATE(fs.hiv_start_date))!=1900,DATE(fs.hiv_start_date),NULL)) as Days_to_Start_of_ART,  -- i.e Late of Earlier
	baseline.hiv_progression as HIV_disease_progression,
    fs.cur_who_stage as	WHO_staging,
    if(fs.cd4_resulted is not null,DATE(fs.cd4_order_date),null) as CD4_Order_Date,
	fs.cd4_resulted AS CD4,
    DATE(fs.cd4_resulted_date) as CD4_Result_Date,
    if(fs.vl_resulted is not null,DATE(fs.vl_order_date),null) as VL_Order_Date,
	fs.vl_resulted as Viral_Load,
    DATE(fs.vl_resulted_date) as VL_Result_Date,
	dt2.mental_health as Mental_health, -- 
	dt3.social_support as Social_support, --
	dt3.health_status as Health_status,  -- eg bed ridden
	dt2.hospitalization as Hospitalization,
	dt2.adherence_counselling as Adherence_counseling,
	fs.hiv_status_disclosed as HIV_disclosure,
	REPLACE(etl.get_arv_names(fs.cur_arv_meds),'##','+') as ART_regimen,
    dt4.Regimen_Line as Regimen_Line,
	dt2.oi as Presence_of_OIs,
	dt2.art_toxicity as ART_toxicities,
    fs.patient_care_status as Patient_Care_Status_Code,
    CASE 
    WHEN fs.patient_care_status=6101 THEN 'Continue' 
    WHEN fs.patient_care_status=6102 THEN 'Discontinue' 
    WHEN fs.patient_care_status=6103 THEN 'Re-enroll' 
	WHEN fs.patient_care_status=1267 THEN 'Completed' 
    WHEN fs.patient_care_status=1187 THEN 'Not Done' 
    WHEN fs.patient_care_status=5488 THEN 'Adherence Counselling'  
    WHEN fs.patient_care_status=7272 THEN 'Urgent Referrals' 
    WHEN fs.patient_care_status=7278 THEN 'Non-urgent Referrals' 
    ELSE NULL END AS Patient_Care_Status,
    
    CASE 
    WHEN fs.patient_care_status=6102 THEN 'Yes'
     WHEN fs.patient_care_status in(6101,6103,1267,1187,7272,5488,7278) THEN 'No'   
     ELSE NULL END AS Ever_disengaged_from_care,
	CASE 
		WHEN fs.is_pregnant=1 THEN 'Pregnant'  
		WHEN fs.is_pregnant=0 THEN 'Not Pregnant' 
	ELSE NULL END AS Pregnancy,
    DATE(fs.edd) as Expected_Date_of_Delivery,
    IF(fs.death_date is not null,1,0) as Death,
    fs.death_date as Death_Date,
    fs.transfer_out as Transferred_Out,
    fs.transfer_out_date AS Transferred_Out_Date,
    fs.date_created as Date_Created
 
FROM amrs.person p 
INNER JOIN etl.flat_hiv_summary_v15b fs ON p.person_id=fs.person_id and is_clinical_encounter=1 
and arv_start_date is not null AND fs.location_id=@location 
AND DATE(fs.rtc_date) BETWEEN @Start_Date and @End_Date 
LEFT OUTER JOIN etl.mfl_codes mc ON fs.location_id=mc.mrsId 
LEFT OUTER JOIN amrs.patient_identifier pi ON p.person_id=pi.patient_id and pi.identifier_type in(8) -- 3 amrs ID
LEFT OUTER JOIN amrs.person_address pa ON p.person_id=pa.person_id 
LEFT OUTER JOIN amrs.concept_name cn_p_status ON fs.patient_care_status=cn_p_status.concept_id AND cn_p_status.locale_preferred='en'
LEFT OUTER JOIN amrs.encounter_type et ON fs.encounter_type=et.encounter_type_id and et.retired=0
LEFT OUTER JOIN (
		SELECT o.person_id,
		MAX(IF(o.concept_id=1054,cn.name,NULL)) as marital_status,
		MAX(IF(o.concept_id=2051,cn.name,NULL)) as entry_point,
		MAX(IF(o.concept_id in(1972,1973),cn.name,NULL)) as occupation, 
		MAX(IF(o.concept_id=1605,cn.name,NULL)) as education,
		MAX(IF(o.concept_id=1710,cn.name,NULL)) as distance, 
		MAX(IF(o.concept_id=5605,cn.name,NULL)) as travel_time,
		MAX(IF(o.concept_id=8365,cn.name,NULL)) as hiv_progression 
		FROM amrs.encounter e 
        INNER JOIN amrs.obs o ON e.encounter_id=o.encounter_id AND e.voided=0 AND concept_id IN(1054,2051,1972,1973,1605,1710,5605,8365)
		INNER JOIN amrs.concept_name cn on o.value_coded=cn.concept_id and o.voided=0 and cn.voided=0 and e.location_id=@location
		AND o.concept_id  and cn.locale='en' and locale_preferred=1 group by person_id 
) AS baseline ON p.person_id=baseline.person_id  

LEFT OUTER JOIN(
		SELECT e.patient_id ,e.encounter_id,visit_id,
		CASE 
			WHEN o.concept_id in(10591) and o.value_coded in(1066) THEN 'No' 
			WHEN o.concept_id in(10591) and o.value_coded in(1065) THEN 'Yes' 
		ELSE NULL END AS tb,
		CASE 
			WHEN o.concept_id in(6836) and o.value_coded in(1066) THEN 'No' 
			WHEN o.concept_id in(6836) and o.value_coded in(1065) THEN 'Yes' 
		ELSE NULL END AS art_toxicity,
		CASE 
			WHEN ((o.concept_id in(6474) AND o.value_coded in(1065)) || (o.concept_id in(1685) AND o.value_coded is not null)) THEN 'Yes' 
			WHEN o.concept_id in(6474) AND o.value_coded in(1066) THEN 'No' -- never 
		ELSE NULL END AS Substance_Use,
        cn.name as alcohol,
		CASE 
			WHEN o.concept_id in(7684,10280) and o.value_coded in(1066) THEN 'No' 
			WHEN o.concept_id in(7684,10280) and o.value_coded in(1065) THEN 'Yes' 
		ELSE NULL END AS mental_health,
		CASE 
		WHEN o.concept_id in(6903)  THEN 'Yes' 
		ELSE NULL END AS oi,
		CASE 
			WHEN o.concept_id in(9771) and o.value_coded in(1066) THEN 'No' 
			WHEN o.concept_id in(9771) and o.value_coded in(1065) THEN 'Yes' 
		ELSE NULL END AS adherence_counselling,
		CASE 
			WHEN o.concept_id in(6419) and o.value_coded in(1066) THEN 'No' 
			WHEN o.concept_id in(6419) and o.value_coded in(1065) THEN 'Yes' 
		ELSE NULL END AS hospitalization 
		FROM amrs.encounter e 
        INNER JOIN amrs.obs o ON e.encounter_id=o.encounter_id AND e.voided=0 AND (DATE(e.encounter_datetime) BETWEEN @Start_Date and @End_Date) 
		AND concept_id in(6836,10591,6474,1685,7684,10280,6903,9771,6419) and o.voided=0 and o.location_id=@location 
        LEFT OUTER JOIN amrs.concept_name cn ON o.value_coded=cn.concept_id AND cn.locale_preferred='en'
        group by e.visit_id
) AS dt2 ON fs.visit_id=dt2.visit_id 

LEFT OUTER JOIN(

		SELECT  person_id, e.encounter_id,visit_id,
		MAX(IF(o.concept_id=11124,cn.name,null)) as health_status,
		MAX(IF(o.concept_id=10012,cn.name,null)) as social_support
		FROM amrs.encounter e 
		INNER JOIN amrs.obs o ON e.encounter_id=o.encounter_id AND concept_id in(11124,10012) 
		AND o.voided=0  and o.location_id=@location AND e.voided=0 AND (DATE(e.encounter_datetime) BETWEEN @Start_Date and @End_Date) 
		INNER JOIN amrs.concept_name cn ON cn.concept_id=o.value_coded  GROUP BY e.visit_id 

) dt3 ON fs.visit_id=dt3.visit_id 

LEFT OUTER JOIN (
		SELECT  person_id, e.encounter_id,visit_id,
		MAX(cn.name) as Regimen_Line
		FROM amrs.encounter e 
		INNER JOIN amrs.obs o ON e.encounter_id=o.encounter_id AND concept_id in(6744) AND (DATE(e.encounter_datetime) BETWEEN @Start_Date and @End_Date) 
		and o.location_id=@location AND e.voided=0 AND o.voided=0  
		INNER JOIN amrs.concept_name cn ON cn.concept_id=o.value_coded  GROUP BY e.visit_id 
) dt4 ON fs.encounter_id=dt4.encounter_id

GROUP BY Encounter_ID
 
ORDER BY patientID ASC, Encounter_Datetime ASC 
