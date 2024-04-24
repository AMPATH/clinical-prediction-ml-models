# Technical Documentation

This document includes various notes on the technical aspects of this project.

Here is the layout of the key parts of this project:

```
├── .github/                        # GitHub-specific files
      └── workflows                 # GitHub Actions actions
            └──docker-publish.yml   # Builds and publishes the Docker image
├── docker-resources                # All files used in the Docker image
       └── plumber.R                # This implements the predictions
├── IIT-Prediction                  # Files related to training the model
       └── model                    # Contains the actual model versions
├── SQL                             # Various related SQL scripts, including
                                    # the production data extract and some
                                    # reporting scripts
```

## Production deployment of clinical-prediction-ml-models

This model is deployed as a Docker container running on the AMPATH analytics server. It is built on GitHub using this repo.

To deploy this container we use the following set of steps:

1. Stop the currently running container (`docker stop ampath-iit-prediction-model`)
2. Remove the current container, so we can re-use the name (`docker rm ampath-iit-prediction-model`)
3. Pull the latest image (`docker pull ampathke/ampath-iit-prediction-model-<model_version>:latest`)
4. Start the latest image (`docker run -v[path/to/config.yml]:/app/config.yml --name ampath-iit-prediction-model --restart unless-stopped ampathke/ampath-iit-prediction-model-<model_version>:latest`

## Adding a new model version

There is a short checklist of steps to take when there is a new model version:

- [ ] Add the new model under `IIT-Prediction/model/<model_version>`
- [ ] Update the `iit_prod_data_extract.sql` file to include any new predictors
      and remove removed predictors (extraction of new predictors can be
      coordinated with the modelling team)
- [ ] Update the `Dockerfile` changing the line that looks like `COPY IIT-Prediction/model/<model_version> /app/model` to the new model version
- [ ] Change the `ml_model_version` variable in `plumber.R`
- [ ] Change the paths to the models in `plumber.R` (the lines that use `h2o.loadModel()`) to the new paths. You should only be pointing to the StackedEnsemble model for the given model version.
- [ ] Change the image tag in the `docker-publish.yml` GitHub workflow to
      reflect the new model version.

## Manually generating predictions

Hopefully, this isn't a common occurrence, but to manually run the predictions:

1. SSH into the analytics server
2. Open a shell in the container by running `docker exec -it ampath-iit-prediction-model bash`
3. In the shell, run `bash /app/run_predictions.sh`

If it is successful, after a brief pause, you should see a lot of predictions written to the console in JSON format. If you see something like: `{"error": "500 - Internal Service Errror"}`, you will need to view the Docker image logs. See the [troubleshooting](#Troubleshooting) section for details.

## Troubleshooting

The Docker container is fairly noisy, but since it's R-based it seomtimes gives obtuse error messages. In general, from the Analytics server run `docker logs ampath-iit-prediction-model` to see the output. There may be something helpful there (like a database connection error or obvious programming error) or something quite convoluted.

If the issue seems transient, restart the container (`docker restart ampath-iit-prediction-model`) and then manually run the predictions. If the error seems non-transient or occurs after restarting and running predictions, there's probably an error either in the R code or the SQL statement.
