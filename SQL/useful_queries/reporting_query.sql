SELECT x.name,
       SUM(CASE WHEN q_num = 1 THEN count ELSE 0 END)  AS high_risk_client,
       SUM(CASE WHEN q_num = 2 THEN count ELSE 0 END)  AS high_risk_client_contacted,
       SUM(CASE WHEN q_num = 3 THEN count ELSE 0 END)  AS phone_follow_up,
       SUM(CASE WHEN q_num = 4 THEN count ELSE 0 END)  AS home_follow_up,
       SUM(CASE WHEN q_num = 5 THEN count ELSE 0 END)  AS successful_contact_attempts,
       SUM(CASE WHEN q_num = 6 THEN count ELSE 0 END)  AS successful_contact_attempts_kept_appointment,
       SUM(CASE WHEN q_num = 7 THEN count ELSE 0 END)  AS successful_contact_attempts_missed_appointment,
       SUM(CASE WHEN q_num = 8 THEN count ELSE 0 END)  AS unsuccessful_contact_attempts,
       SUM(CASE WHEN q_num = 9 THEN count ELSE 0 END)  AS no_contact_attempts,
       SUM(CASE WHEN q_num = 10 THEN count ELSE 0 END) AS no_contact_attempts_kept_appointment,
       SUM(CASE WHEN q_num = 11 THEN count ELSE 0 END) AS rescheduled_appointment,
       SUM(CASE WHEN q_num = 12 THEN count ELSE 0 END) AS unsuccessful_kept_appointment
​
FROM (SELECT al.name, COUNT(distinct ml.person_id) AS count, 1 AS q_num
      FROM predictions.ml_weekly_predictions `ml`
          INNER JOIN amrs.location al
      ON al.location_id = ml.location_id
      WHERE (ml.location_id IN (65
          , 213
          , 19
          , 230
          , 8
          , 341
          , 9
          , 342))
        AND (ml.week = '2023-W38')
        AND (ml.predicted_risk IS NOT NULL)
      group by ml.location_id
      UNION
      SELECT al.name, COUNT (distinct ml.person_id) AS count, 2 AS q_num
      FROM predictions.ml_weekly_predictions `ml`
          INNER JOIN amrs.location al
      ON al.location_id = ml.location_id
          LEFT JOIN etl.pre_appointment_summary `pre` ON pre.person_id = ml.person_id
      WHERE (ml.location_id IN (65
          , 213
          , 19
          , 230
          , 8
          , 341
          , 9
          , 342))
        AND (ml.week = '2023-W38')
        AND (ml.predicted_risk IS NOT NULL)
        AND (pre.is_successful_phone_follow_up IS NOT NULL
         OR pre.attempted_home_visit IS NOT NULL)
      group by ml.location_id
      UNION
      SELECT al.name, COUNT (distinct pre.person_id) AS count, 3 AS q_num
      FROM predictions.ml_weekly_predictions `ml`
          INNER JOIN amrs.location al
      ON al.location_id = ml.location_id
          LEFT JOIN etl.pre_appointment_summary `pre` ON pre.person_id = ml.person_id
      WHERE (ml.location_id IN (65
          , 213
          , 19
          , 230
          , 8
          , 341
          , 9
          , 342))
        AND (ml.week = '2023-W38')
        AND (ml.predicted_risk IS NOT NULL)
        AND (pre.is_successful_phone_follow_up IS NOT NULL)
      group by ml.location_id
      UNION
      SELECT al.name, COUNT (distinct ml.person_id) AS count, 4 AS q_num
      FROM predictions.ml_weekly_predictions `ml`
          INNER JOIN amrs.location al
      ON al.location_id = ml.location_id
          LEFT JOIN etl.pre_appointment_summary `pre` ON pre.person_id = ml.person_id
      WHERE (ml.location_id IN (65
          , 213
          , 19
          , 230
          , 8
          , 341
          , 9
          , 342))
        AND (ml.week = '2023-W38')
        AND (ml.predicted_risk IS NOT NULL)
        AND (pre.attempted_home_visit IS NOT NULL)
      group by ml.location_id
      UNION
      SELECT al.name, COUNT (distinct ml.person_id) AS count, 5 AS q_num
      FROM predictions.ml_weekly_predictions `ml`
          INNER JOIN amrs.location al
      ON al.location_id = ml.location_id
          LEFT JOIN etl.pre_appointment_summary `pre` ON pre.person_id = ml.person_id
      WHERE (ml.location_id IN (65
          , 213
          , 19
          , 230
          , 8
          , 341
          , 9
          , 342))
        AND (ml.week = '2023-W38')
        AND (ml.predicted_risk IS NOT NULL)
        AND (pre.is_successful_phone_follow_up = 'YES'
         OR pre.attempted_home_visit = 'YES')
      group by ml.location_id
      UNION
      SELECT al.name, COUNT (distinct ml.person_id) AS count, 6 AS q_num
      FROM predictions.ml_weekly_predictions `ml`
          INNER JOIN amrs.location al
      ON al.location_id = ml.location_id
          LEFT JOIN etl.pre_appointment_summary `pre` ON pre.person_id = ml.person_id
          LEFT JOIN etl.flat_hiv_summary_v15b `fh`
          ON ml.person_id = fh.person_id AND fh.next_clinical_datetime_hiv IS NULL AND
          fh.is_clinical_encounter = 1
      WHERE (ml.location_id IN (65
          , 213
          , 19
          , 230
          , 8
          , 341
          , 9
          , 342))
        AND (ml.week = '2023-W38')
        AND (ml.predicted_risk IS NOT NULL)
        AND (pre.is_successful_phone_follow_up = 'YES'
         OR pre.attempted_home_visit = 'YES') and pre.reschedule_appointment is null
        AND fh.encounter_datetime BETWEEN ml.prediction_generated_date
        AND ml.end_date
      group by ml.location_id
      UNION
      SELECT al.name, COUNT (distinct ml.person_id) AS count, 7 AS q_num
      FROM predictions.ml_weekly_predictions `ml`
          INNER JOIN amrs.location al
      ON al.location_id = ml.location_id
          LEFT JOIN etl.pre_appointment_summary `pre` ON pre.person_id = ml.person_id
          LEFT JOIN etl.flat_hiv_summary_v15b `fh`
          ON ml.person_id = fh.person_id AND fh.next_clinical_datetime_hiv IS NULL AND
          fh.is_clinical_encounter = 1
      WHERE (ml.location_id IN (65
          , 213
          , 19
          , 230
          , 8
          , 341
          , 9
          , 342))
        AND (ml.week = '2023-W38')
        AND (ml.predicted_risk IS NOT NULL)
        AND (pre.is_successful_phone_follow_up = 'YES'
         Or pre.attempted_home_visit = 'YES')
        AND fh.encounter_datetime NOT BETWEEN ml.prediction_generated_date
        AND ml.end_date
      group by ml.location_id
      UNION
      SELECT
    al.name,
    COUNT(DISTINCT ml.person_id) AS count,
    8 AS q_num
FROM
    predictions.ml_weekly_predictions ml
INNER JOIN
    amrs.location al ON al.location_id = ml.location_id
LEFT JOIN
    etl.pre_appointment_summary pre ON pre.person_id = ml.person_id
WHERE
    ml.location_id IN (65, 213, 19, 230, 8, 341, 9, 342)
    AND ml.week = '2023-W38'
    AND ml.predicted_risk IS NOT NULL
    AND (
        pre.is_successful_phone_follow_up = 'NO'
        and pre.attempted_home_visit IS NULL
    )
    AND pre.is_successful_phone_follow_up = (
        SELECT MAX(pre_inner.is_successful_phone_follow_up)
        FROM etl.pre_appointment_summary pre_inner
        WHERE pre_inner.person_id = ml.person_id
    )
GROUP BY
    ml.location_id
​
      UNION
      SELECT al.name, COUNT (distinct ml.person_id) AS count, 9 AS q_num
      FROM predictions.ml_weekly_predictions `ml`
          INNER JOIN amrs.location al
      ON al.location_id = ml.location_id
          LEFT JOIN etl.pre_appointment_summary `pre` ON pre.person_id = ml.person_id
      WHERE (ml.location_id IN (65
          , 213
          , 19
          , 230
          , 8
          , 341
          , 9
          , 342))
        AND (ml.week = '2023-W38')
        AND (ml.predicted_risk IS NOT NULL)
        AND (pre.is_successful_phone_follow_up IS NULL
        and pre.attempted_home_visit IS NULL)
      group by ml.location_id
      UNION
      SELECT al.name, COUNT (distinct ml.person_id) AS count, 10 AS q_num
      FROM predictions.ml_weekly_predictions `ml`
          INNER JOIN amrs.location al
      ON al.location_id = ml.location_id
          LEFT JOIN etl.pre_appointment_summary `pre` ON pre.person_id = ml.person_id
          LEFT JOIN etl.flat_hiv_summary_v15b `fh`
          ON ml.person_id = fh.person_id AND fh.next_clinical_datetime_hiv IS NULL AND
          fh.is_clinical_encounter = 1
      WHERE (ml.location_id IN (65
          , 213
          , 19
          , 230
          , 8
          , 341
          , 9
          , 342))
        AND (ml.week = '2023-W38')
        AND (ml.predicted_risk IS NOT NULL)
        AND (pre.is_successful_phone_follow_up="NO"
        and pre.attempted_home_visit IS NULL )
        AND fh.encounter_datetime BETWEEN ml.prediction_generated_date
        AND ml.end_date
      group by ml.location_id
      UNION
      SELECT al.name, COUNT (distinct ml.person_id) AS count, 11 AS q_num
      FROM predictions.ml_weekly_predictions `ml`
          INNER JOIN amrs.location al
      ON al.location_id = ml.location_id
          LEFT JOIN etl.pre_appointment_summary `pre` ON pre.person_id = ml.person_id
      WHERE (ml.location_id IN (65
          , 213
          , 19
          , 230
          , 8
          , 341
          , 9
          , 342))
        AND (ml.week = '2023-W38')
        AND (ml.predicted_risk IS NOT NULL)
        AND (pre.reschedule_appointment is not null)
      group by ml.location_id
      union
      SELECT al.name,
             COUNT(DISTINCT ml.person_id) AS count,
             12                            AS q_num
      FROM predictions.ml_weekly_predictions ml
               INNER JOIN
           amrs.location al ON al.location_id = ml.location_id
               LEFT JOIN
           etl.pre_appointment_summary pre ON pre.person_id = ml.person_id
       LEFT JOIN etl.flat_hiv_summary_v15b `fh`
          ON ml.person_id = fh.person_id AND fh.next_clinical_datetime_hiv IS NULL AND
          fh.is_clinical_encounter = 1
      WHERE ml.location_id IN (65, 213, 19, 230, 8, 341, 9, 342)
        AND ml.week = '2023-W38'
        AND ml.predicted_risk IS NOT NULL
        AND (
                  pre.is_successful_phone_follow_up = 'NO'
              and pre.attempted_home_visit IS NULL
          )
        AND pre.is_successful_phone_follow_up = (SELECT MAX(pre_inner.is_successful_phone_follow_up)
                                                 FROM etl.pre_appointment_summary pre_inner
                                                 WHERE pre_inner.person_id = ml.person_id)   AND fh.encounter_datetime BETWEEN ml.prediction_generated_date
        AND ml.end_date
      GROUP BY ml.location_id
      ) x
group by x.name;