# libraries for the model
library(tidyverse)
library(h2o)
library(RCurl)

# libraries used in the API
library(plumber)
library(RMariaDB)
library(DBI)
library(pool)
library(uuid)

h2o.init()

dbConfig <- config::get()

ml_model <- h2o.loadModel(
  "/app/model/y0_1days_adult_minor_IIT/2_StackedEnsemble_BestOfFamily_1_AutoML_8_20230726_142520_auc_0.704/StackedEnsemble_BestOfFamily_1_AutoML_8_20230726_142520"
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
  startDate = clock::add_weeks(Sys.Date(), 1),
  weeks = "1"
) {
  # handle parameters
  # despite typings, the arguments are always strings
  start_date <- as.Date(startDate)
  num_weeks <- max(as.integer(weeks) - 1, 0)

  # calculate the Monday for this week; this is our start date
  start_of_week <- week_start(start_date)
  # first, add the number of weeks requested, then calculate the Sunday
  # of the resuling week; this is our end date
  end_of_week <- week_end(clock::add_weeks(start_of_week, num_weeks))

  query <- DBI::sqlInterpolate(
    my_pool,
    ml_sql,
    startDate = start_of_week,
    endDate = end_of_week
  )

  # run the query, giving us a dataframe
  predictors <- DBI::dbGetQuery(my_pool, query)

  # no rows to predict, so do nothing
  if (nrow(predictors) == 0) {
    return(data.frame())
  }

  # convert the dataframe to an h2o object, removing elements that are not predictors
  h2o_predict_frame <- predictors %>%
    select(-c(person_id, encounter_id, location_id)) %>%
    as.h2o()

  # run the predictions
  # TODO Why does this seem to claim we're running in train / validate mode?
  result <- h2o.predict(ml_model, h2o_predict_frame)

  # h2o persists both the frame *and* the result in it's cluster;
  # however, we don't need them, so after this function returns, we delete them
  on.exit(h2o.rm(h2o_predict_frame))
  on.exit(h2o.rm(result))

  # for the case where we need this, it should be safe to assume
  # that the start week has the correct values
  cohort <- clock::date_format(clock::add_weeks(start_date, -1), format="%Y-W%U")

  # enrich the table of predictors with the results
  prediction_result <- predictors %>%
    bind_cols(as.data.frame(result)) %>%
    # reduce data frame and rename the result
    select(person_id, encounter_id, location_id, rtc_date, predicted_prob_disengage = Disengaged) %>%
    # calculate the patient's risk category
    predict_risk(cohort) %>%
    # add per-row metadata about the run
    mutate(
      prediction_generated_date = Sys.time(),
      model_version = "V6",
      start_date = start_of_week,
      end_date = end_of_week,
      week = clock::date_format(clock::add_weeks(week_start(rtc_date), -1), format="%Y-W%U"),
      .keep = "unused"
    )

  # add the rows from the prediction_result to the ml_weekly_predictions table
  DBI::dbAppendTable(my_pool, SQL('predictions.ml_weekly_predictions'), prediction_result)

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

predict_risk <- function(.data, cohort) {
  # arbitrary cut-off, but we expect one big batch per week
  # and several small batches
  if (nrow(.data) < 200) {
    cutoffs <- DBI::dbGetQuery(
      my_pool,
      DBI::sqlInterpolate(
        my_pool,
        "select
          'Medium Risk' as risk,
          min(predicted_prob_disengage) as probability_threshold
        from predictions.ml_weekly_predictions mlp
        where predicted_risk = 'Medium Risk' and week = ?week
        union
        select
          'High Risk' as risk,
          min(predicted_prob_disengage) as probability_threshold
        from predictions.ml_weekly_predictions mlp
        where predicted_risk = 'High Risk' and week = ?week;",
        week = cohort
      )
    )

    if (nrow(cutoffs) == 2) {
      medium_risk <- cutoffs %>%
        filter(risk == "Medium Risk") %>%
        select(probability_threshold) %>%
        pull
      
      high_risk <- cutoffs %>%
        filter(risk == "High Risk") %>%
        select(probability_threshold) %>%
        pull
      
      # if we have risk thresholds, just use them
      return(
        .data %>%
          mutate(
            predicted_risk = 
              case_when(
                predicted_prob_disengage >= high_risk ~ "High Risk",
                predicted_prob_disengage >= medium_risk ~ "Medium Risk",
                .default = NA_character_
              )
          )
      )
    }
  }

  .data %>% mutate(
    percentile = percent_rank(predicted_prob_disengage),
    predicted_risk = 
      case_when(
        percentile >= .9 ~ "High Risk",
        percentile >= .8 ~ "Medium Risk",
        .default = NA_character_
      ),
    .keep = "all"
  ) %>%
  select(-c(percentile))
}

