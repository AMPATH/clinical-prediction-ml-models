-- Our ML Query
-- First, we filter the flat_hiv_summary_v15b table to give us only rows we care about
with ml_flat_hiv_summary as (
    select
        fs.*
    from flat_hiv_summary_v15b fs
    where arv_start_date is not null
      and is_clinical_encounter = 1
      and encounter_datetime >= date('2016-01-01')
      and not (
            rtc_date = prev_rtc_date
        and encounter_type = prev_encounter_type_hiv
        and encounter_datetime = prev_encounter_datetime_hiv
    )
),
-- Then, we calculate visit_numbers (really encounter numbers) as number of visits since the start date
visit_numbers as (
    select
        row_number() over (partition by person_id, date(encounter_datetime) order by encounter_datetime) as visit_number,
        person_id,
        encounter_id
    from ml_flat_hiv_summary
),
-- Then, we check for the days defaulted in the previous encounter
days_defaulted as (
    select
        person_id,
        encounter_id,
        encounter_datetime,
        rtc_date,
        prev_clinical_rtc_date_hiv,
        datediff(encounter_datetime, prev_clinical_rtc_date_hiv) as days_defaulted
    from ml_flat_hiv_summary
),
-- CTEs for demographics that we need to roll-forward
marital_status as (
    select
        person_id,
        o.obs_datetime,
        o.concept_id,
        cn.name as concept_value,
        row_number() over (partition by person_id order by obs_datetime) as row_num
    from amrs.obs o
      join amrs.concept_name cn on o.value_coded = cn.concept_id
    where cn.locale = 'en'
      and cn.locale_preferred = 1
      and o.concept_id = 1054
      and o.obs_datetime >= '2016-01-01'
),
travel_time as (
    select
        person_id,
        o.obs_datetime,
        o.concept_id,
        cn.name as concept_value,
        row_number() over (partition by person_id order by obs_datetime) as row_num
    from amrs.obs o
      join amrs.concept_name cn on o.value_coded = cn.concept_id
    where cn.locale = 'en'
      and cn.locale_preferred = 1
      and o.concept_id = 5605
      and o.obs_datetime >= '2016-01-01'
),
# entry_point as (
#     select
#         person_id,
#         o.obs_datetime,
#         o.concept_id,
#         cn.name as concept_value,
#         row_number() over (partition by person_id order by obs_datetime) as row_num
#     from amrs.obs o
#       join amrs.concept_name cn on o.value_coded = cn.concept_id
#     where cn.locale = 'en'
#       and cn.locale_preferred = 1
#       and o.concept_id = 2051
#       and o.obs_datetime >= '2016-01-01'
# ),
# education as (
#     select
#         person_id,
#         o.obs_datetime,
#         o.concept_id,
#         cn.name as concept_value,
#         row_number() over (partition by person_id order by obs_datetime) as row_num
#     from amrs.obs o
#       join amrs.concept_name cn on o.value_coded = cn.concept_id
#     where cn.locale = 'en'
#       and cn.locale_preferred = 1
#       and o.concept_id = 1605
#       and o.obs_datetime >= '2016-01-01'
# ),
# occupation as (
#     select
#         person_id,
#         o.obs_datetime,
#         o.concept_id,
#         cn.name as concept_value,
#         row_number() over (partition by person_id order by obs_datetime) as row_num
#     from amrs.obs o
#       join amrs.concept_name cn on o.value_coded = cn.concept_id
#     where cn.locale = 'en'
#       and cn.locale_preferred = 1
#       and o.concept_id in (1972, 1973)
#       and o.obs_datetime >= '2016-01-01'
# ),
-- Baseline = first visit in recorded data
baseline as (
    select
        fs.*
    from ml_flat_hiv_summary fs
      join visit_numbers vn on vn.encounter_id = fs.encounter_id
    where vn.visit_number = 1
)
select
    fs.person_id,
    fs.encounter_id,
    timestampdiff(YEAR, p.birthdate, fs.encounter_datetime) as Age,
    if(p.birthdate is null, 1, 0) as Age_NA,
    p.gender as Gender,
    ms.concept_value as Marital_status,
    timestampdiff(YEAR,
        if(year(fs.arv_first_regimen_start_date) != 1900,
            date(fs.arv_first_regimen_start_date),
            NULL
        ), DATE(fs.encounter_datetime)) as Duration_in_HIV_care,
    if(fs.arv_first_regimen_start_date is null or year(fs.arv_first_regimen_start_date) = 1900,
        1, 0) as Duration_in_HIV_care_NA,
    round(fs.weight / ((fs.height / 100) * (fs.height / 100)), 2) as BMI,
    if(fs.weight is null or fs.height is null or fs.weight < 1 or fs.height < 1, 1, 0) as BMI_NA,
    case
        when tt.concept_value in ('LESS THAN ONE HOUR', '30 TO 60 MINUTES', 'LESS THAN 30 MINUTES')
            then 'LESS THAN ONE HOUR'
        when tt.concept_value in ('MORE THAN ONE HOUR', 'ONE TO TWO HOURS', 'MORE THAN TWO HOURS')
            then 'MORE THAN ONE HOUR'
        else tt.concept_value
    end as Travel_time,
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
    -- TODO TB_Comorbidity
    fs.cd4_resulted as CD4,
    if(fs.cd4_resulted is null, 1, 0) as CD4_NA,
#     case
#         when ep.concept_value in ('ADULT INPATIENT SERVICE', 'OUTPATIENT SERVICES')
#             then 'INPATIENT / OUTPATIENT SERVICE'
#         when ep.concept_value in ('HIV COMPREHENSIVE CARE UNIT', 'SEXUALLY TRANSMITTED INFECTION',
#                                      'TUBERCULOSIS', 'OTHER NON-CODED', 'OSCAR PROGRAM', 'SELF TEST')
#             then 'OTHER'
#         when ep.concept_value in ('MATERNAL CHILD HEALTH PROGRAM', 'PEDIATRIC INPATIENT SERVICE')
#             then 'PEDIATRIC SERVICE'
#         when ep.concept_value in ('HOME BASED TESTING PROGRAM', 'PERPETUAL HOME-BASED COUNSELING AND TESTING')
#             then 'HOME BASED TESTING'
#         when ep.concept_value in ('"HIV TESTING SERVICES STRATEGY', 'VOLUNTARY COUNSELING AND TESTING CENTER')
#             then 'VOLUNTARY COUNSELING AND TESTING CENTER'
#         else ep.concept_value
#     end as Entry_Point,
    case
        when et.name in ('ADULTINITIAL', 'PEDSINITIAL', 'YOUTHINITIAL') then 'Initial'
        when et.name in ('ADULTRETURN', 'PEDSRETURN', 'YOUTHRETURN') then 'Return'
        else 'Other'
    end as Encounter_Type_Class,
#     case
#         when ed.concept_value in ('FORM 1 TO 2', 'FORM 3 TO 4', 'SECONDARY SCHOOL')
#             then 'SECONDARY SCHOOL'
#         when ed.concept_value in ('PRE PRIMARY', 'PRE UNIT', 'STANDARD 1 TO 3', 'STANDARD 4 TO 8')
#             then 'PRIMARY SCHOOL'
#         when ed.concept_value in ('COLLEGE', 'UNIVERSITY')
#             then 'COLLEGE / UNIVERSITY'
#         else ed.concept_value
#     end as Education_Level,
    vn.visit_number as Visit_Number,
    lag(dd.days_defaulted) over (order by dd.encounter_datetime) as days_defaulted_prev_encounter,
    timestampdiff(YEAR, p.birthdate, baseline.encounter_datetime) as Age_baseline
from ml_flat_hiv_summary as fs
    join visit_numbers vn on vn.encounter_id = fs.encounter_id
    join days_defaulted dd on dd.encounter_id = fs.encounter_id
    join amrs.person p on p.person_id = fs.person_id
    left join marital_status ms
        on ms.row_num = (
            select max(row_num)
            from marital_status ms1
            where ms1.person_id = fs.person_id and ms1.obs_datetime <= fs.encounter_datetime
        )
       and ms.person_id = fs.person_id
    left join travel_time tt
        on tt.row_num = (
            select max(row_num)
            from travel_time tt1
            where tt1.person_id = fs.person_id and tt1.obs_datetime <= fs.encounter_datetime
        )
       and tt.person_id = fs.person_id
#     left join entry_point ep
#         on ep.row_num = (
#             select max(row_num)
#             from entry_point ep1
#             where ep1.person_id = fs.person_id and ep1.obs_datetime <= fs.encounter_datetime
#         )
#        and ep.person_id = fs.person_id
#     left join education ed
#         on ed.row_num = (
#             select max(row_num)
#             from education ed1
#             where ed1.person_id = fs.person_id and ed1.obs_datetime <= fs.encounter_datetime
#         )
#        and ed.person_id = fs.person_id
#     left join occupation occ
#         on occ.row_num = (
#             select max(row_num)
#             from occupation occ1
#             where occ1.person_id = fs.person_id and occ1.obs_datetime <= fs.encounter_datetime
#         )
#        and occ.person_id = fs.person_id
    join amrs.encounter_type et on fs.encounter_type = et.encounter_type_id
    join baseline on baseline.person_id = fs.person_id
where fs.location_id = 75
limit 20;