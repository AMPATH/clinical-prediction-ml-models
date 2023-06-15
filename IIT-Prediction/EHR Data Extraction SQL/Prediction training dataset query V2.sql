select
    fs.person_id,
    fs.encounter_id,
    fs.location_id,
    fs.rtc_date,
    timestampdiff(YEAR, p.birthdate, fs.encounter_datetime) as Age,
    if(p.birthdate is null, 1, 0) as Age_NA,
    p.gender as Gender,
    timestampdiff(YEAR,
                  if(year(fs.arv_first_regimen_start_date) != 1900,
                     date(fs.arv_first_regimen_start_date),
                     NULL
                      ), date(fs.encounter_datetime)) as Duration_in_HIV_care,
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
    -- comorbidities
    fs.on_tb_tx,
    fs.tb_prophylaxis_duration,
    coalesce(fs.tb_screen, 0) as tb_screen,
    coalesce(fs.on_ipt, 0) as on_ipt,
    coalesce(fs.ca_cx_screen, 0) as ca_cx_screening,
    fs.ca_cx_screening_result,
    fs.cd4_resulted as CD4,
    if(fs.cd4_resulted is null, 1, 0) as CD4_NA,
    datediff(fs.encounter_datetime, fs.cd4_resulted_date) as Days_Since_Last_CD4,
    null as Entry_Point,
    case
        when et.name in ('ADULTINITIAL', 'PEDSINITIAL', 'YOUTHINITIAL') then 'Initial'
        when et.name in ('ADULTRETURN', 'PEDSRETURN', 'YOUTHRETURN') then 'Return'
        else 'Other'
        end as Encounter_Type_Class,
    et.name as Encounter_Name,
    program.name as Program_Name,
    l.name as Clinic_Name,
    l.state_province as Clinic_County,
    l.address4 as Clinic_Sub_County,
    replace(get_arv_names(fs.cur_arv_meds), '##', '+') as ART_regimen
from flat_hiv_summary_v15b as fs
         left join predictions.flat_ml_baseline_visit baseline
                   on fs.person_id = baseline.person_id
         left join predictions.flat_ml_days_defaulted dd
                   on dd.encounter_id = fs.encounter_id
                       and dd.person_id = fs.person_id
         join amrs.person p on p.person_id = fs.person_id
         left join amrs.encounter_type et on fs.encounter_type = et.encounter_type_id
         left join amrs.location l
                   on fs.location_id = l.location_id
                       and l.retired = 0
         left join etl.program_visit_map pvm
                   on pvm.visit_type_id = fs.visit_type
         left join amrs.program program
                   on pvm.program_type_id = program.program_id
where fs.encounter_datetime >= '2016-01-01'
  and fs.arv_start_date is not null
  and is_clinical_encounter = 1;