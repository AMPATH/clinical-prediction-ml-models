drop procedure if exists add_observed_appointments_to_ml_predictions_v1_0;
create definer = analytics procedure predictions.add_observed_appointments_to_ml_predictions_v1_0()
begin
    update predictions.ml_weekly_predictions mp
        left join etl.flat_hiv_summary_v15b fs_next
        on mp.person_id = fs_next.person_id
            and mp.rtc_date = fs_next.prev_rtc_date
            and fs_next.is_clinical_encounter = 1
            and (
                   fs_next.rtc_date is not null
                   and (
                               date(fs_next.rtc_date) <= date(fs_next.encounter_datetime)
                           or date(fs_next.rtc_date) > date(fs_next.prev_rtc_date)
                       )
               )
    set observed_rtc_date = date(fs_next.encounter_datetime)
    where mp.observed_rtc_date is null;
end
