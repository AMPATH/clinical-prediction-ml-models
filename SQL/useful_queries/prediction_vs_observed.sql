-- drawing from a table of predictions, tries to show:
--  1. Predicted probability of IIT (miss appointment by one day)
--  2. Observed results
select
    fs.person_id,
    encounter_type,
    fs.rtc_date,
    encounter_datetime,
    prev_rtc_date,
    weekofyear(prev_rtc_date) - 17 as week_number,
    case
        when fs.rtc_date is null or (date(fs.rtc_date) > date(encounter_datetime) and date(fs.rtc_date) <= date(prev_rtc_date))
            then 'NON-RETURNER'
        when date(prev_rtc_date) = date(encounter_datetime)
            then 'ON-TIME'
        when date(prev_rtc_date) > date(encounter_datetime)
            then 'EARLY'
        when date(prev_rtc_date) < date(encounter_datetime)
            then
                case
                    when timestampdiff(day, prev_rtc_date, encounter_datetime) <= 7
                        then 'LATE: UP TO 7 DAYS'
                    when timestampdiff(day, prev_rtc_date, encounter_datetime) <= 14
                        then 'LATE: UP TO 14 DAYS'
                    when timestampdiff(day, prev_rtc_date, encounter_datetime) <= 28
                        then 'LATE: UP TO 28 DAYS'
                    when timestampdiff(day, prev_rtc_date, encounter_datetime) <= 90
                        then 'LATE: UP TO 90 DAYS'
                    else 'LATE OVER 90 DAYS'
                end
        else '????'
    end as timeliness,
    bp.predicted_prob_disengage
from predictions.bungoma_may_preds bp
left join etl.flat_hiv_summary_v15b fs
  on bp.person_id = fs.person_id
 and (bp.rtc_date = fs.prev_rtc_date)
 -- 186 is a drug pick-up; 99999 is unknown
 and fs.encounter_type_id not in (186, 99999)
where is_clinical_encounter = 1
order by bp.predicted_prob_disengage desc;
