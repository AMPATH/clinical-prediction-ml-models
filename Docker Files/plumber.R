#
# This is a Plumber API. You can run the API by clicking
# the 'Run API' button above.
#
# Find out more about building APIs with Plumber here:
#
#    https://www.rplumber.io/
#

# libraries for the model
library(tidyverse)
library(h2o)

# libraries used in the API
library(plumber)
library(clock)
library(RMariaDB)
library(DBI)
library(pool)
library(uuid)

h2o.init()

dbConfig <- config::get(config = "db")

ml_model <- h2o.loadModel(
  "/app/model/1_StackedEnsemble_BestOfFamily_1_day_default_prediction"
)
ml_sql <- read_file("/app/iit_prod_data_extract.sql")

my_pool <- dbPool(
  drv = RMariaDB::MariaDB(),
  host = dbConfig$host,
  username = dbConfig$user,
  password = dbConfig$password
  dbname = dbConfig$defaultDB
)

# Custom router modifications
#* @plumber
function(pr) {
  pr %>%
    # add a hook that runs at exit to close the pool
    pr_hook("exit", function() {
      poolClose(my_pool)
    })
}

#* @filter cors
cors <- function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")

  if (req$REQUEST_METHOD == "OPTIONS") {
    res$setHeader("Access-Control-Allow-Methods", "*")
    res$setHeader(
      "Access-Control-Allow-Headers",
      req$HTTP_ACCESS_CONTROL_REQUEST_HEADERS
    )

    res$status <- 200
    return(list())
  } else {
    plumber::forward()
  }
}

#* @apiTitle AMPATH Interruption in Treatment Prediction Model API
#* @apiDescription This API provides a simple method to

#* @param startDate:string
#* @param endDate:string
#*
#* @parser form
#* @serializer json
#* @post /predict
function(
  startDate,
  endDate
) {
  query <- DBI::sqlInterpolate(
    my_pool,
    ml_sql,
    startDate = startDate,
    endDate = endDate
  )

  predictors <- DBI::dbGetQuery(my_pool, query)

  h2o_predict_frame <- predictors %>% as.h2o()

  result <- h2o.predict(ml_model, h2o_predict_frame)

  on.exit(h2o.rm(h2o_predict_frame))
  on.exit(h2o.rm(result))

  prediction_result <- predictors %>%
    bind_cols(as.data.frame(result)) %>%
    select(person_id, encounter_id, location_id, rtc_date, predicted_prob_disengage = Disengaged) %>%
    mutate(
      predicted_prob_disengage = predicted_prob_disengage,
      percentile = percent_rank(predicted_prob_disengage),
      predicted_risk = if_else(percentile > .9, "High Risk", if_else(percentile > .8, "Medium Risk", NA_character_)),
      prediction_generated_date = Sys.Date(),
      start_date = as.Date(startDate),
      end_date = as.Date(endDate),
      week = clock::date_format(clock::add_weeks(as.Date(startDate), -1), format="%Y-W%U"),
      .keep = "unused"
    ) %>%
    select(-percentile)

  DBI::dbAppendTable(my_pool, SQL('predictions.ml_weekly_predictions'), prediction_result)

  prediction_result
}
