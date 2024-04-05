-- Theoretically, this procedure should not be necessary but, for whatever reason, the model
-- update doesn't always add the expected RTC date, so we add it here.
drop procedure if exists update_encounter_rtc_dates_v1_0;
create definer = analytics procedure predictions.update_encounter_rtc_dates_v1_0()
begin
    update predictions.ml_weekly_predictions mp
        left join etl.flat_hiv_summary_v15b fs_next
        on mlp.encounter_id = fs.encounter_id
        set mlp.rtc_date = fs.rtc_date
        where mlp.rtc_date is null;
end