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
library(RMariaDB)
library(DBI)
library(pool)
library(uuid)

h2o.init()

dbConfig <- config::get()

ml_model <- h2o.loadModel(
  "/app/model/1_StackedEnsemble_BestOfFamily_1_day_default_prediction"
)
ml_sql <- read_file("/app/iit_prod_data_extract.sql")

my_pool <- dbPool(
  drv = RMariaDB::MariaDB(),
  host = dbConfig$host,
  username = dbConfig$user,
  password = dbConfig$password,
  dbname = dbConfig$defaultDb
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
#* @param weeks:int
#*
#* @parser form
#* @serializer json
#* @post /predict
function(
  startDate,
  weeks = "0"
) {
  start_date <- as.Date(startDate)
  # fancy date gymnastics
  week_start <- week_start(start_date)

  num_weeks <- as.integer(weeks)
  if (num_weeks < 0) {

  }

  # same deal, but get end the week (always Sunday)
  week_end <- week_end(clock::add_weeks(week_start, as.integer(weeks)))


  query <- DBI::sqlInterpolate(
    my_pool,
    ml_sql,
    startDate = week_start,
    endDate = week_end
  )

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
      start_date = start_date,
      end_date = week_end,
      week = clock::date_format(clock::add_weeks(week_start(rtc_date), -1), format="%Y-W%U"),
      .keep = "unused"
    ) %>%
    select(-percentile)

  # DBI::dbAppendTable(my_pool, SQL('predictions.ml_weekly_predictions'), prediction_result)

  prediction_result
}

# utility functions

# sets origin to the first Monday after 1970-01-01; this should guarantee that we're
# flooring to the Monday of the week start, e.g.,
#  * 2023-06-26 (Monday) -> 2023-06-26
#  * 2023-06-28 (Wednesday) -> 2023-06-26
#  * 2023 06-25 (Sunday) -> 2023-06-19
#  * 2023-01-01 (Sunday) -> 2022-12-26
#  * 2016-01-01 (Friday, Leap Year) -> 2015-12-28
week_start <- function(date) {
  date <- as.Date(date)
  clock::date_floor(date, "week", origin = as.Date("1970-01-05"))
}

week_end <- function(date) {
  date <- as.Date(date)
  clock::date_ceiling(date, "week", origin = as.Date("1970-01-04"))
}

