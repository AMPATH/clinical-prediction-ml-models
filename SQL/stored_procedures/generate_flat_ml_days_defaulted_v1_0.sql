drop procedure if exists generate_flat_ml_days_defaulted_v1_0;
create definer=analytics procedure generate_flat_ml_days_defaulted_v1_0()
begin
    drop table predictions.flat_ml_days_defaulted;
    create table predictions.flat_ml_days_defaulted as
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
            visit_number,
            datediff(encounter_datetime, prev_clinical_rtc_date_hiv) as days_defaulted
        from ml_flat_hiv_summary_with_encounter_number
    )
    select
        person_id,
        encounter_id,
        date(encounter_datetime) as ecnounter_date,
        visit_number,
        coalesce(
            dd.days_defaulted,
            lag(dd.days_defaulted) over (partition by dd.person_id order by dd.encounter_datetime)
        ) as days_defaulted_last_encounter
    from days_defaulted dd;

    alter table flat_ml_days_defaulted
        add primary key (person_id, encounter_id);

    create index flat_ml_days_defaulted_person_encounter_idx
        on predictions.flat_ml_days_defaulted (person_id, encounter_date);
end;
