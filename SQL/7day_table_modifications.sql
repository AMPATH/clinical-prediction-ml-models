-- Script of changes to make to ml_weekly_predictions to accomodate 1-day and 7-day predictions
alter table ml_weekly_predictions
    add predicted_prob_disengage_7day decimal(4, 4) null after predicted_risk;

alter table ml_weekly_predictions
    add predicted_risk_7day varchar(50) null after predicted_prob_disengage_7day;

create index ml_weekly_predictions__prod_query_index_7day
    on ml_weekly_predictions (person_id, predicted_risk_7day, week, predicted_prob_disengage_7day);
