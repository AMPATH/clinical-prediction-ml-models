# clinical-prediction-ml-models
The main objective of this project is to predict clinical outcomes using EHR Data and modern ML/AI 

* IIT-Prediction - Start [Here](IIT-Prediction/README.md)

## Docker Image

To build the Docker image, first create a `config.yml` using the file in Docker Files/ called `config.example.yml` as a guide. Then build the Docker image:


```
docker build --tag kenya-prediction-<model_version>:<version> .
```

And run it locally:

```
docker run --rm -p 8000:8000 -v "$(pwd)/Docker Files/config.yml:/app/config.yml:ro" kenya-prediction-<model_version>:<version>
```
