select
    mlp.week as `Week`,
    mlp.model_version as `Model Version`,
    l.name as `Clinic`,
    count(*) as `# of Appointments`,
    sum(if(mlp.predicted_risk is not null, 1, 0)) as `# Predicted IIT`,
    sum(if(mlp.observed_rtc_date is not null, 1, 0)) as `# Observed Returns`,
    sum(if(mlp.observed_rtc_date < mlp.rtc_date, 1, 0)) as `# Early Returns`,
    sum(if(mlp.observed_rtc_date = mlp.rtc_date, 1, 0)) as `# On-time Returns`,
    sum(if(mlp.observed_rtc_date > mlp.rtc_date, 1, 0)) as `# Late Returns`,
    sum(if(date(now()) > mlp.rtc_date and mlp.observed_rtc_date is null, 1, 0)) as `# Non-returners`,
    sum(if(mlp.predicted_risk is null and mlp.observed_rtc_date <= mlp.rtc_date, 1, 0)) as `# Predicted on-time who returned on-time`,
    sum(if(mlp.predicted_risk is null and (mlp.observed_rtc_date > mlp.rtc_date or mlp.observed_rtc_date is null), 1, 0)) as `# Predicted on-time who returned late`,
    sum(if(mlp.predicted_risk is not null and mlp.observed_rtc_date <= mlp.rtc_date, 1, 0)) as `# Predicted late who returned on-time`,
    sum(if(mlp.predicted_risk is not null and (mlp.observed_rtc_date > mlp.rtc_date or mlp.observed_rtc_date is null), 1, 0)) as `# Predicted late who returned late`,
    coalesce(sum(if(mlp.predicted_risk is not null and (mlp.observed_rtc_date > mlp.rtc_date or mlp.observed_rtc_date is null), 1, 0)) /
        (sum(if(mlp.predicted_risk is not null and (mlp.observed_rtc_date > mlp.rtc_date or mlp.observed_rtc_date is null), 1, 0)) +
            sum(if(mlp.predicted_risk is not null and mlp.observed_rtc_date <= mlp.rtc_date, 1, 0))), 0.0000) as `PPV`,
    coalesce(sum(if(mlp.predicted_risk is null and mlp.observed_rtc_date <= mlp.rtc_date, 1, 0)) /
        (sum(if(mlp.predicted_risk is null and mlp.observed_rtc_date <= mlp.rtc_date, 1, 0)) +
            sum(if(mlp.predicted_risk is null and (mlp.observed_rtc_date > mlp.rtc_date or mlp.observed_rtc_date is null), 1, 0))), 0.0000) as `NPV`,
    coalesce(sum(if(mlp.predicted_risk is not null and (mlp.observed_rtc_date > mlp.rtc_date or mlp.observed_rtc_date is null), 1, 0)) /
        (sum(if(mlp.predicted_risk is not null and (mlp.observed_rtc_date > mlp.rtc_date or mlp.observed_rtc_date is null), 1, 0)) +
            sum(if(mlp.predicted_risk is null and (mlp.observed_rtc_date > mlp.rtc_date or mlp.observed_rtc_date is null), 1, 0))), 0.0000) as `Sensitivity`,
    coalesce(sum(if(mlp.predicted_risk is null and mlp.observed_rtc_date <= mlp.rtc_date, 1, 0)) /
        (sum(if(mlp.predicted_risk is null and mlp.observed_rtc_date <= mlp.rtc_date, 1, 0)) +
            sum(if(mlp.predicted_risk is not null and mlp.observed_rtc_date <= mlp.rtc_date, 1, 0))), 0.0000) as `Specificity`
from ml_weekly_predictions mlp
    left join amrs.location l
        on l.location_id = mlp.location_id
where
    mlp.rtc_date <= date(now()) and mlp.start_date >= '2023-01-01'
and l.name != 'Location Test'
group by model_version, mlp.week, l.name with rollup;