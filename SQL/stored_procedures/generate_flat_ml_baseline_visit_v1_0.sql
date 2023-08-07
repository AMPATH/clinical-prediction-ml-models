drop procedure if exists generate_flat_ml_baseline_visit_v1_0;
create definer = analytics procedure generate_flat_ml_baseline_visit_v1_0()
begin
    drop table if exists predictions.flat_ml_baseline_visit;
    create table predictions.flat_ml_baseline_visit (
        person_id                               int                                  not null
            primary key,
        Age_baseline                            int                                  null,
        Gender_baseline                         varchar(50) charset utf8  default '' null,
        Marital_status_baseline                 varchar(100)                         null,
        BMI_baseline                            decimal(21, 2)                       null,
        Travel_time_baseline                    varchar(100)                         null,
        WHO_staging_baseline                    int                                  null,
        VL_suppression_baseline                 int(1)                               null,
        Viral_Load_log10_baseline               double                               null,
        HIV_disclosure_baseline                 int                                  null,
        Regimen_Line_baseline                   int                                  null,
        Pregnancy_baseline                      int(4)                               null,
        Clinic_Location_baseline                varchar(5)                           null,
        TB_Comorbidity_baseline                 varchar(100)                         null,
        CD4_baseline                            double                               null,
        Education_Level_baseline                varchar(100)                         null,
        Occupation_baseline                     varchar(100)                         null,
        Adherence_Counselling_Sessions_baseline varchar(100)                         null,
        Clinic_Name_baseline                    varchar(255) charset utf8 default '' null,
        ART_regimen_baseline                    text charset utf8                    null
    ) as
    with ml_flat_hiv_summary as (
        select
            fs.*
        from etl.flat_hiv_summary_v15b fs
        where arv_start_date is not null
          and is_clinical_encounter = 1
          and encounter_datetime >= date('2016-01-01')
          and not (
                    rtc_date = prev_rtc_date
                and encounter_type = prev_encounter_type_hiv
                and encounter_datetime = prev_encounter_datetime_hiv
            )
    ),
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
    )
    select
        baseline.person_id,
        timestampdiff(YEAR, p.birthdate, baseline.encounter_datetime) as Age_baseline,
        p.gender as Gender_baseline,
        null as Marital_status_baseline,
        case
            when baseline.weight is null or baseline.height is null or baseline.weight < 1 or baseline.height < 1
                then null
            when round(baseline.weight / ((baseline.height / 100) * (baseline.height / 100)), 2) < 5.0
                then null
            when round(baseline.weight / ((baseline.height / 100) * (baseline.height / 100)), 2) > 60.0
                then null
            else round(baseline.weight / ((baseline.height / 100) * (baseline.height / 100)), 2)
        end as BMI,
        null as Travel_time_baseline,
        baseline.cur_who_stage as WHO_staging_baseline,
        if(baseline.vl_resulted < 1000, 1, 0) as VL_suppression_baseline,
        log10(baseline.vl_resulted + 1) as Viral_Load_log10_baseline,
        baseline.hiv_status_disclosed as HIV_disclosure_baseline,
        baseline.cur_arv_line as Regimen_Line_baseline,
        coalesce(baseline.is_pregnant, 0) as Pregnancy_baseline,
        case
            when baseline.location_id in (55, 315, 19, 230, 26, 23, 319, 130, 313, 9, 342, 78, 310, 20, 312, 12, 321, 8, 341, 19, 230)
                then 'Urban'
            when baseline.location_id in (65, 314, 64, 83, 316, 90, 135, 106, 86, 336, 91, 320, 74, 76, 79, 100, 311, 75)
                then 'Rural'
            end as Clinic_Location_baseline,
        null as TB_Comorbidity_baseline,
        baseline.cd4_resulted as CD4_baseline,
        null as Education_Level_baseline,
        null as Occupation_baseline,
        null as Adherence_Counselling_Sessions_baseline,
        l.name as Clinic_Name_baseline,
        replace(etl.get_arv_names(baseline.cur_arv_meds), '##', '+') as ART_regimen_baseline
    from
        ml_flat_hiv_summary_with_encounter_number baseline
            left join amrs.person p using (person_id)
            left join amrs.location l
                      on baseline.location_id = l.location_id
                          and l.retired = 0
    where baseline.visit_number = 1;
end;

