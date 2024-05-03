-- This query basically attempts to get visit return timeliness
-- This has normally been used as a recursive query (SQL WITH)
-- as a building block for more complicated reporting queries.
select
    fs.person_id,
    fs.encounter_id,
    case
        when fs2.rtc_date is null
            then 'NON-RETURNER'
        when date(fs2.prev_rtc_date) = date(fs2.encounter_datetime)
            then 'ON-TIME'
        when date(fs2.prev_rtc_date) > date(fs2.encounter_datetime)
            then
                case
                    when timestampdiff(day, fs2.encounter_datetime, fs2.prev_rtc_date) <= 7
                        then 'EARLY: UP TO 7 DAYS'
                    when timestampdiff(day, fs2.encounter_datetime, fs2.prev_rtc_date) <= 14
                        then 'EARLY: UP TO 14 DAYS'
                    when timestampdiff(day, fs2.encounter_datetime, fs2.prev_rtc_date) <= 28
                        then 'EARLY: UP TO 28 DAYS'
                    when timestampdiff(day, fs2.encounter_datetime, fs2.prev_rtc_date) <= 90
                        then 'EARLY: UP TO 90 DAYS'
                    else 'EARLY: MORE THAN 90 DAYS'
                end
        when date(fs2.prev_rtc_date) < date(fs2.encounter_datetime)
            then
                case
                    when timestampdiff(day, fs2.prev_rtc_date, fs2.encounter_datetime) <= 7
                        then 'LATE: UP TO 7 DAYS'
                    when timestampdiff(day, fs2.prev_rtc_date, fs2.encounter_datetime) <= 14
                        then 'LATE: UP TO 14 DAYS'
                    when timestampdiff(day, fs2.prev_rtc_date, fs2.encounter_datetime) <= 28
                        then 'LATE: UP TO 28 DAYS'
                    when timestampdiff(day, fs2.prev_rtc_date, fs2.encounter_datetime) <= 90
                        then 'LATE: UP TO 90 DAYS'
                    else 'LATE: OVER 90 DAYS'
                end
        else '????'
    end as timeliness
from etl.flat_hiv_summary_v15b fs
    join predictions.ml_weekly_predictions ml
        on fs.encounter_id = ml.encounter_id
    left join etl.flat_hiv_summary_v15b fs2
        on fs.person_id = fs2.person_id
        and (
           fs2.prev_rtc_date = fs.rtc_date
        )
       and fs2.is_clinical_encounter = 1
       and fs2.encounter_type not in (186, 99999)
where fs.is_clinical_encounter = 1
  and fs.encounter_type not in (186, 99999);
