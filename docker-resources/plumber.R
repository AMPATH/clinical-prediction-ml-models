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
  "/app/model/y0_1days_IIT/StackedEnsemble_AllModels_1_AutoML_1_20230615_104136"
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
#* @apiDescription This API provides a simple method to run the model for a set of weeks

#* @param startDate:string
#* @param weeks:int
#*
#* @parser form
#* @serializer json
#* @post /predict
function(
  startDate = Sys.Date(),
  weeks = "0"
) {
  # handle parameters
  # despite typings, the arguments are always strings
  start_date <- as.Date(startDate)
  num_weeks <- max(as.integer(weeks), 0)

  # calculate the Monday for this week; this is our start date
  week_start <- week_start(start_date)
  # first, add the number of weeks requested, then calculate the Sunday
  # of the resuling week; this is our end date
  week_end <- week_end(clock::add_weeks(week_start, weeks))

  query <- DBI::sqlInterpolate(
    my_pool,
    ml_sql,
    startDate = week_start,
    endDate = week_end
  )

  # run the query, giving us a dataframe
  predictors <- DBI::dbGetQuery(my_pool, query)

  # convert the dataframe to an h2o object, removing elements that are not predictors
  h2o_predict_frame <- predictors %>%
    select(-c(person_id, encounter_id, location_id, rtc_date))
    as.h2o()

  # run the predictions
  # TODO Why does this seem to claim we're running in train / validate mode?
  result <- h2o.predict(ml_model, h2o_predict_frame)

  # h2o persists both the frame *and* the result in it's cluster;
  # however, we don't need them, so after this function returns, we delete them
  on.exit(h2o.rm(h2o_predict_frame))
  on.exit(h2o.rm(result))

  # enrich the table of predictors with the results
  prediction_result <- predictors %>%
    bind_cols(as.data.frame(result)) %>%
    # reduce data frame and rename the result
    select(person_id, encounter_id, location_id, rtc_date, predicted_prob_disengage = Disengaged) %>%
    # calculate the patient's risk category
    predict_risk()
    mutate(
      predicted_prob_disengage = predicted_prob_disengage,
      percentile = percent_rank(predicted_prob_disengage),
      predicted_risk = if_else(percentile > .9, "High Risk", if_else(percentile > .8, "Medium Risk", NA_character_)),
      .keep = "unused"
    ) %>%
    select(-percentile)
    %>%
    # add per-row metadata about the run
    mutate(
      prediction_generated_date = Sys.time(),
      model_version = "V5",
      start_date = week_start,
      end_date = week_end,
      week = clock::date_format(clock::add_weeks(week_start(rtc_date), -1), format="%Y-W%U"),
      .keep = "unused"
    )

  # add the rows from the prediction_result to the ml_weekly_predictions table
  # DBI::dbAppendTable(my_pool, SQL('predictions.ml_weekly_predictions'), prediction_result)

  # return the result so the API returns *something*
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

