-- Our ML Query
-- First, we filter the flat_hiv_summary_v15b table to give us only rows we care about
with ml_flat_hiv_summary as (
    select
        fs.*
    from flat_hiv_summary_v15b fs
    where arv_start_date is not null
      and is_clinical_encounter = 1
      and encounter_datetime >= date('2018-01-01')
      and not (
            rtc_date = prev_rtc_date
        and encounter_type = prev_encounter_type_hiv
        and encounter_datetime = prev_encounter_datetime_hiv
    )
),
-- Then, we calculate visit_numbers (really encounter numbers) as number of visits since the start date
visit_numbers as (
    select
        row_number() over (partition by person_id order by encounter_datetime) as visit_number,
        person_id,
        encounter_id
    from ml_flat_hiv_summary
),
-- Combine these into one table
ml_flat_hiv_summary_with_encounter_number as (
    select
        fs.*,
        visit_number
    from ml_flat_hiv_summary fs
        join visit_numbers vn
          on fs.person_id = vn.person_id
         and fs.encounter_id = vn.encounter_id
),
-- Then, we check for the days defaulted in the previous encounter
days_defaulted as (
    select
        person_id,
        encounter_id,
        encounter_datetime,
        prev_clinical_rtc_date_hiv,
        datediff(encounter_datetime, prev_clinical_rtc_date_hiv) as days_defaulted
    from ml_flat_hiv_summary_with_encounter_number
),
-- Calculate some rolling aggregates (joins should ensure we are not over-calculating)
num_2wk_defaults_last_3_visits as (
    select
            fs.person_id,
            fs.encounter_id,
            if(dd1.days_defaulted >= 14, 1, 0) +
            if(dd2.days_defaulted >= 14, 1, 0) +
            if(dd3.days_defaulted >= 14, 1, 0) as num_2wks_defaults_last_3visits
    from ml_flat_hiv_summary_with_encounter_number fs
      left join ml_flat_hiv_summary_with_encounter_number fs_visit_1
         on fs_visit_1.person_id = fs.person_id and fs_visit_1.visit_number = fs.visit_number - 1
      left join days_defaulted dd1
         on dd1.person_id = fs_visit_1.person_id
        and dd1.encounter_id = fs_visit_1.encounter_id
      left join ml_flat_hiv_summary_with_encounter_number fs_visit_2
         on fs_visit_2.person_id = fs_visit_1.person_id and fs_visit_2.visit_number = fs_visit_1.visit_number - 1
      left join days_defaulted dd2
         on dd2.person_id = fs_visit_2.person_id
        and dd2.encounter_id = fs_visit_2.encounter_id
      left join ml_flat_hiv_summary_with_encounter_number fs_visit_3
         on fs_visit_3.person_id = fs_visit_2.person_id and fs_visit_3.visit_number = fs_visit_2.visit_number - 1
      left join days_defaulted dd3
         on dd3.person_id = fs_visit_3.person_id
        and dd3.encounter_id = fs_visit_3.encounter_id
)
select
    fs.person_id,
    fs.encounter_id,
    timestampdiff(YEAR, p.birthdate, fs.encounter_datetime) as Age,
    if(p.birthdate is null, 1, 0) as Age_NA,
    p.gender as Gender,
    null as Marital_status,
    timestampdiff(YEAR,
        if(year(fs.arv_first_regimen_start_date) != 1900,
            date(fs.arv_first_regimen_start_date),
            NULL
        ), DATE(fs.encounter_datetime)) as Duration_in_HIV_care,
    if(fs.arv_first_regimen_start_date is null or year(fs.arv_first_regimen_start_date) = 1900,
        1, 0) as Duration_in_HIV_care_NA,
    round(fs.weight / ((fs.height / 100) * (fs.height / 100)), 2) as BMI,
    if(fs.weight is null or fs.height is null or fs.weight < 1 or fs.height < 1, 1, 0) as BMI_NA,
    null as Travel_time,
    fs.cur_who_stage as WHO_staging,
    if(fs.cur_who_stage is null, 1, 0) as WHO_staging_NA,
    log10(fs.vl_resulted + 1) as Viral_Load_log10,
    if(fs.vl_resulted is null, 1, 0) as Viral_Load_log10_NA,
    if(fs.vl_resulted < 1000, 1, 0) as VL_suppression,
    timestampdiff(DAY, fs.encounter_datetime, fs.vl_resulted_date) as Days_Since_Last_VL,
    fs.hiv_status_disclosed as HIV_disclosure,
    if(fs.hiv_status_disclosed is null, 1, 0) as HIV_disclosure_NA,
    -- NB Regimen Line differs from extraction data
    fs.cur_arv_line as Regimen_Line,
    if(fs.cur_arv_line is null, 1, 0) as Regimen_Line_NA,
    coalesce(fs.is_pregnant, 0) as Pregnancy,
    case
        when fs.location_id in (55, 315, 19, 230, 26, 23, 319, 130, 313, 9, 78, 310, 20, 312, 12, 321, 8, 341)
            then 'Urban'
        when fs.location_id in (65, 314, 64, 83, 316, 90, 135, 106, 86, 336, 91, 320, 74, 76, 79, 100, 311, 75)
            then 'Rural'
    end as Clinic_Location,
    null as TB_Comorbidity,
    fs.cd4_resulted as CD4,
    if(fs.cd4_resulted is null, 1, 0) as CD4_NA,
    null as Entry_Point,
    case
        when et.name in ('ADULTINITIAL', 'PEDSINITIAL', 'YOUTHINITIAL') then 'Initial'
        when et.name in ('ADULTRETURN', 'PEDSRETURN', 'YOUTHRETURN') then 'Return'
        else 'Other'
    end as Encounter_Type_Class,
    null as Education_Level,
    null as Occupation,
    null as Adherence_Counselling_Sessions,
    mc.mrsDisplay as Clinic_Name,
    replace(get_arv_names(fs.cur_arv_meds), '##', '+') as ART_regimen,
    fs.visit_number as Visit_Number,
    lag(dd.days_defaulted) over (order by dd.encounter_datetime) as Days_defaulted_prev_encounter,
    if(dd.days_defaulted is null, 1, 0) as Days_defaulted_prev_encounter_NA,
    num_2wks_defaults_last_3visits,
    if(num_2wks_defaults_last_3visits is null, 1, 0) as num_2wks_defaults_last_3visits_NA,
    0 as ever_defaulted_by_1m_in_last_1year,
    1 as ever_defaulted_by_1m_in_last_1year_NA,
    0 as ever_defaulted_by_1m_in_last_1year,
    1 as ever_defaulted_by_1m_in_last_1year_NA,
    timestampdiff(YEAR, p.birthdate, baseline.encounter_datetime) as Age_baseline,
    p.gender as Gender_baseline,
    null as Marital_status_baseline,
    round(baseline.weight / ((baseline.height / 100) * (baseline.height / 100)), 2) as BMI_baseline,
    null as Travel_time_baseline,
    baseline.cur_who_stage as WHO_staging,
    if(baseline.vl_resulted < 1000, 1, 0) as VL_suppression_baseline,
    log10(baseline.vl_resulted + 1) as Viral_Load_log10_baseline,
    baseline.hiv_status_disclosed as HIV_disclosure_baseline,
    baseline.cur_arv_line as Regimen_Line,
    coalesce(baseline.is_pregnant, 0) as Pregnancy_baseline,
    case
        when baseline.location_id in (55, 315, 19, 230, 26, 23, 319, 130, 313, 9, 78, 310, 20, 312, 12, 321, 8, 341)
            then 'Urban'
        when baseline.location_id in (65, 314, 64, 83, 316, 90, 135, 106, 86, 336, 91, 320, 74, 76, 79, 100, 311, 75)
            then 'Rural'
    end as Clinic_Location_baseline,
    null as TB_Comorbidity_baseline,
    baseline.cd4_resulted as CD4,
    null as Education_Level_baseline,
    null as Occupation_baseline,
    null as Adherence_Counselling_Sessions_baseline,
    mc_b.mrsDisplay as Clinic_Name_baseline,
    replace(get_arv_names(fs.cur_arv_meds), '##', '+') as ART_regimen_baseline
from ml_flat_hiv_summary_with_encounter_number as fs
    left join ml_flat_hiv_summary_with_encounter_number baseline
        on fs.person_id = baseline.person_id
       and fs.encounter_id <> baseline.encounter_id
    left join days_defaulted dd
        on dd.encounter_id = fs.encounter_id
       and dd.person_id = fs.person_id
    join amrs.person p on p.person_id = fs.person_id
    join amrs.encounter_type et on fs.encounter_type = et.encounter_type_id
    left join mfl_codes mc on fs.location_id = mc.mflCode
    left join mfl_codes mc_b on baseline.location_id = mc.mflCode
    left join num_2wk_defaults_last_3_visits 2wk_defaults
         on 2wk_defaults.person_id = fs.person_id
        and 2wk_defaults.encounter_id = fs.encounter_id
where fs.location_id in (319)
  and fs.rtc_date between date_sub(current_date(), interval 1 week) and current_date()
  and (baseline.visit_number is null or baseline.visit_number = 1);