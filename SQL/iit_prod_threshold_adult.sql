select
  '1 day' as model_type,
  'Medium Risk' as risk,
  location_id,
  min(predicted_prob_disengage) as probability_threshold
from predictions.ml_weekly_predictions mlp
  join amrs.person p
    on mlp.person_id = p.person_id
where predicted_risk = 'Medium Risk' and week = ?week
  and timestampdiff(YEAR, p.birthdate, mlp.rtc_date) >= 18
group by location_id
union
select
  '1 day' as model_type,
  'High Risk' as risk,
  location_id,
  min(predicted_prob_disengage) as probability_threshold
from predictions.ml_weekly_predictions mlp
  join amrs.person p
    on mlp.person_id = p.person_id
where predicted_risk = 'High Risk' and week = ?week
  and timestampdiff(YEAR, p.birthdate, mlp.rtc_date) >= 18
group by location_id
union
select
  '7 day' as model_type,
  'Medium Risk' as risk,
  location_id,
  min(predicted_prob_disengage_7day) as probability_threshold
from predictions.ml_weekly_predictions mlp
  join amrs.person p
    on mlp.person_id = p.person_id
where predicted_risk = 'Medium Risk' and week = ?week
  and timestampdiff(YEAR, p.birthdate, mlp.rtc_date) >= 18
group by location_id
union
select
  '7 day' as model_type,
  'High Risk' as risk,
  location_id,
  min(predicted_prob_disengage_7day) as probability_threshold
from predictions.ml_weekly_predictions mlp
  join amrs.person p
    on mlp.person_id = p.person_id
where predicted_risk = 'High Risk' and week = ?week
  and timestampdiff(YEAR, p.birthdate, mlp.rtc_date) >= 18
group by location_id;
