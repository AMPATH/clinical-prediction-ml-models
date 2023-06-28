# clinical-prediction-ml-models
The main objective of this project is to predict clinical outcomes using EHR Data and modern ML/AI 

* IIT-Prediction - Start [Here](IIT-Prediction/README.md)

## Docker Image

To build the Docker image, first create a `config.yml` using the file in the `docker-resources` folder called `config.example.yml` as a guide. Then build the Docker image:


```
docker build --tag kenya-prediction-<model_version>:<version> .
```

And run it locally:

```
docker run --rm -p 8000:8000 -v "$(pwd)/docker-resources/config.yml:/app/config.yml:ro" kenya-prediction-<model_version>:<version>
```

## The API

The Docker container produced here provides an API to run the models. The API endpoint is paired with a corresponding SQL script that describes how to extract the predictors for the model from the live database.

## IIT

### Cohorts

For interruption in treatment, we treat patients as belonging to week-long cohorts, running from Monday to Sunday (for whatever reason, there are a small number of appointments scheduled on Saturdays and Sundays). Since appoinment date is not a factor in our prediction models, these cohorts are primarily logical groups.

The idea of these cohorts is that the bulk of patients for a given week are gathered and scored on the Sunday the week before the week containing their appointment. For example, a patient with an appointment on June 26th, 2023 should have their results
score on June 18th, 2023. Since patient appointments can be added on a rolling basis, we continue to update the week's appointments every day.

Patient's whose appointment has already been seen are not re-scored, as the overall risk score should not change without an intervening appointment.

This also means that we do not drop patients out of cohorts if their appointment date is moved to a different week. This should be discussed.
