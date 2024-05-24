-- ML query
-- Calculate rolling default numbers
with num_1day_defaults_last_3_visits as (
    select
        dd1.person_id,
        dd1.encounter_id,
        dd1.visit_number,
        case
            when dd1.days_defaulted_last_encounter is null or
                 dd2.days_defaulted_last_encounter is null or
                 dd3.days_defaulted_last_encounter is null
                then null
            else
                if(dd1.days_defaulted_last_encounter >= 1, 1, 0) +
                if(dd2.days_defaulted_last_encounter >= 1, 1, 0) +
                if(dd3.days_defaulted_last_encounter >= 1, 1, 0)
        end as num_1day_defaults_last_3_visits
    from predictions.flat_ml_days_defaulted dd1
             left join predictions.flat_ml_days_defaulted dd2
                       on dd2.person_id = dd1.person_id
                           and dd2.visit_number = dd1.visit_number - 1
             left join predictions.flat_ml_days_defaulted dd3
                       on dd3.person_id = dd2.person_id
                           and dd3.visit_number = dd2.visit_number - 1
)
-- describe the columns we need
select
    fs.person_id,
    fs.encounter_id,
    fs.encounter_type,
    fs.location_id,
    date(fs.rtc_date) as rtc_date,
    timestampdiff(YEAR, p.birthdate, fs.encounter_datetime) as Age,
    if(p.birthdate is null, 1, 0) as Age_NA,
    p.gender as Gender,
    -- BMI = wt / (ht / 100)^2
    -- BMI < 5.0 or over 60.0 are considered errors, usually errors in the underlying data
    case
        when fs.weight is null or fs.height is null or fs.weight < 1 or fs.height < 1
            then null
        when round(fs.weight / ((fs.height / 100) * (fs.height / 100)), 2) < 5.0
            then null
        when round(fs.weight / ((fs.height / 100) * (fs.height / 100)), 2) > 60.0
            then null
        else round(fs.weight / ((fs.height / 100) * (fs.height / 100)), 2)
    end as BMI,
    case
        when fs.weight is null or fs.height is null or fs.weight < 1 or fs.height < 1
            then 1
        when round(fs.weight / ((fs.height / 100) * (fs.height / 100)), 2) < 5.0
            then 1
        when round(fs.weight / ((fs.height / 100) * (fs.height / 100)), 2) > 60.0
            then 1
        else 0
    end as BMI_NA,
    log10(fs.vl_resulted + 1) as Viral_Load_log10,
    if(fs.vl_resulted is null, 1, 0) as Viral_Load_log10_NA,
    timestampdiff(DAY, fs.encounter_datetime, fs.vl_resulted_date) as Days_Since_Last_VL,
    if(fs.vl_resulted_date is null, 1, 0) as Days_Since_Last_VL_NA,
    fs.cd4_resulted as CD4,
    if(fs.cd4_resulted is null, 1, 0) as CD4_NA,
    datediff(fs.encounter_datetime, fs.cd4_resulted_date) as Days_Since_Last_CD4,
    if(fs.cd4_resulted_date is null, 1, 0) as Days_Since_Last_CD4_NA,
    -- flat_hiv_summary has a visit_number value, but its a total counter
    -- the model is trained on data from 2021, so we recalculate the visit number from the
    -- default data
    dd.visit_number as Visit_Number,
    days_defaulted_last_encounter as Days_defaulted_in_prev_enc,
    if(days_defaulted_last_encounter is null, 1, 0) as Days_defaulted_in_prev_enc_NA,
    num_1day_defaults_last_3_visits as num_1day_defaults_last_3visits,
    coalesce(fs.hiv_disclosure_status_value, 'Not Done') as HIV_disclosure_stage,
    fs.tb_test_result as TB_Test_Result,
    convert(month(date(fs.rtc_date)), char) as 'Month',
    mfm.clinic_county as Current_Clinic_County,
    mfm.size_enrollments_log10 as Size_Enrollments_Log10,
    mfm.volume_visits_log10 as Volume_Visits_Log10,
    mfm.care_programme as 'Care Programme',
    mfm.facility_type as 'Facility Type',
    program.name as Program_Name
from etl.flat_hiv_summary_v15b as fs
        left join predictions.flat_ml_days_defaulted dd
                on dd.encounter_id = fs.encounter_id
                    and dd.person_id = fs.person_id
        join amrs.person p on p.person_id = fs.person_id
        left join predictions.ml_facility_metadata mfm
            on fs.location_id = mfm.location_id
        -- If a patient in enrolled in PMTCT, they are also enrolled in antenatal care
        -- Currently, we only keep the PMTCT record
        left join etl.program_visit_map pvm
                on pvm.visit_type_id = fs.visit_type
                    and pvm.voided is null
                    and (pvm.program_type_id != 42 or pvm.visit_type_id not in (51, 54))
                    and (pvm.program_type_id != 52 or pvm.visit_type_id not in (1, 2))
        left join amrs.program program
                on pvm.program_type_id = program.program_id
                    and program.retired = 0
        left join num_1day_defaults_last_3_visits 1day_defaults
                on 1day_defaults.person_id = fs.person_id
                    and 1day_defaults.encounter_id = fs.encounter_id
        left join predictions.ml_weekly_predictions mlp
                on mlp.encounter_id = fs.encounter_id
where
  -- filter to only targetted locations
  fs.location_id in (
    -- Dumisha
    26, 23, 319, 130, 313, 9, 78, 310, 20, 312, 12, 321, 8, 341, 342, 65, 314, 64, 83, 90, 106, 86, 336, 91, 320, 74, 76, 79, 100, 311, 75, 195, 19, 230,
    -- Uzima
    1, 13, 14, 15, 197, 198, 17, 227, 214, 306, 11, 229, 421, 422, 423, 420,
    -- April 2024 rollout (NB some are included above - 420, 421, 422, & 423) (Done May 2024)
    211, 60, 323, 140, 4, 322, 351, 352, 208, 69, 208, 11, 229, 55, 315, 64, 334, 135, 335,
    -- May 2024 rollout (Done June 2024)
    393, 396, 411, 492, 116, 397, 434, 438, 435, 439, 62, 333, 94, 406, 23, 319, 76, 338
  )
  -- filter encounters: 111 - LabResult, 99999 - lab encounter type
  -- these encounters are post-visit lab result entries and should not appear in predicted data
  and fs.encounter_type not in (111, 99999)
  -- ET 116 - Transfer Encounter; 9998 - transfer expected to AMPATH clinic
  and (fs.encounter_type != 116 or fs.transfer_in_location_id = 9998)
  -- 9999 - transfered to non-AMPATH clinic, we discount these for the list of patient's that we care about trying to
  -- proactively follow-up on since we do not anticipate these patient's returning to AMPATH. If they do, they will be
  -- returned to normal status at whatever clinic they visit
  and (fs.transfer_in_location_id is null or fs.transfer_in_location_id != 9999)
  and fs.is_clinical_encounter = 1
  -- don't generate predictions for patients who have transferred out
  and fs.out_of_care is null
  -- substituted from the R script
  and fs.rtc_date between ?startDate and ?endDate
  and (fs.next_clinical_datetime_hiv is null
    or (?retrospective and fs.next_clinical_datetime_hiv >= fs.rtc_date)
  )
  and fs.encounter_datetime < fs.date_created
  -- filter dead patients
  and fs.death_date is null
  -- if not run retrospectively, don't generate new predictions for existing cases
  and (?retrospective or mlp.encounter_id is null);
