# One-Day and Seven-Day Endpoint Implementation

Part of the feedback we've been getting is that the 1-day default predictions are not as useful, since patients may default by 1 day, but return within a few days. As an enhancement we'd like to implement a second model to predict 7-day defaults that we'll run alongside the 1-day default predictions. We would like to roll this out gradually to the existing clinics and as a default for new clinics, in order to be able to determine whether the 7-day model is, indeed, an improvement over the 1-day model.

In order to do this, we're going to add a small amount of complexity to the existing code specifically:
We'll be adding two columns to the ml_weekly_predictions table: predicted_prob_disengage_7day and predicted_risk_7day . Those fields will be identical to the predicted_prob_disengage and predicted_risk fields respectively, but based on the 7-day model rather than the 1-day model.

There's an existing table, ml_facility_metadata , which is currently used entirely. We will be adding a column to this called prediction_endpoint to capture whether each site should be using the predictions from the 1-day model or the 7-day model on a per-clinic basis.

I think, on the programming side we basically need to modify the mlWeeklyPredictionsBase query to include:
A join on predictions.ml_facility_metadata  aliased to mlfm where mlfm.location_id = ml.location_id

Change this column definition:
```json
    {
      "type": "simple_column",
      "alias": "predicted_prob_disengage",
      "column": "ml.predicted_prob_disengage"
    },
```

To something like:
```json
    {
      "type": "derived_column",
      "alias": "predicted_prob_disengage",
      "column": "case when mlfm.prediction_endpoint = 7 then ml.predicted_prob_disengage_7day else ml.predicted_prob_disengage"
    },
```
