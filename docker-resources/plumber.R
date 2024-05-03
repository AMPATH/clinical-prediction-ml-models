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

# h2o is the library that does the predictions
# this will start a JVM and the h2o server on this container
h2o.init()

# the R config package is used to parse the config.yml file, which has the database connection
# settings
dbConfig <- config::get()

# Update this when the model version changes
ml_model_version <- "V9"

# now we load the models into the h2o server instance
# adult model
ml_model_adult <- h2o.loadModel(
  "/app/model/y0_1days_adult_IIT/2_StackedEnsemble_BestOfFamily_1_AutoML_8_20240411_135528_auc_0.739/StackedEnsemble_BestOfFamily_1_AutoML_8_20240411_135528"
)

# peds model
ml_model_minor <- h2o.loadModel(
  "/app/model/y0_1days_minor_IIT/1_StackedEnsemble_AllModels_1_AutoML_6_20240329_151542_auc_0.721/StackedEnsemble_AllModels_1_AutoML_6_20240329_151542"
)

# we also load the SQL query we use to generate the dataframe of records for prediction
ml_sql <- read_file("/app/iit_prod_data_extract.sql")

# finally, we establish a small connection pool to manage DB connections
my_pool <- dbPool(
  drv = RMariaDB::MariaDB(),
  host = dbConfig$host,
  username = dbConfig$user,
  password = dbConfig$password,
  dbname = dbConfig$defaultDb
)

# at this point, Plumber will actually start, but we will have setup the h2o server, loaded the models
# and attempted to connect to the database. That means that issues in any of those steps will cause this
# script to fail early rather than waiting until we actually try to run things.

# Custom router modifications
#* @plumber
function(pr) {
  pr %>%
    # add a hook that runs at exit to close the pool
    pr_hook("exit", function() {
      poolClose(my_pool)
    })
}

# this just ensures that the API always responds with the headers needed for to avoid CORS errors
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

# This is the actual endpoint definition and the place the code really starts

#* @apiTitle AMPATH Interruption in Treatment Prediction Model API
#* @apiDescription This API provides a simple method to run the model for a set of weeks

#* @param startDate:string
#* @param weeks:int
#*
#* @parser form
#* @serializer json
#* @post /predict
function(
  startDate = NA,       # the startDate is the first day to start from
                        # note that it will be adjusted to the Monday of the week its in as we always run in weekly batches
  weeks = "1",          # the number of weeks to run; this is only used for testing
  retrospective = "F"   # whether or not the query is retrospective (run against past data for testing) or prospective
                        # (run normally); this mostly adjusts the query
) {
  retrospective <- as.logical(retrospective)

  # If the startDate is not specified, it defaults to NA and we set it to a week from today
  if (is.na(startDate)) {
    startDate = clock::add_weeks(Sys.Date(), 1)
  }

  # handle parameters
  # despite typings, the arguments are always strings
  start_date <- as.Date(startDate)
  num_weeks <- max(as.integer(weeks) - 1, 0)

  # calculate the Monday for this week; this is our start date
  start_of_week <- week_start(start_date)
  # first, add the number of weeks requested, then calculate the Sunday
  # of the resuling week; this is our end date
  end_of_week <- week_end(clock::add_weeks(start_of_week, num_weeks))

  # here we plug the variables into the query
  query <- DBI::sqlInterpolate(
    my_pool,
    ml_sql,
    startDate = start_of_week,
    endDate = end_of_week,
    retrospective = retrospective
  )

  # run the query, giving us a dataframe
  predictors <- DBI::dbGetQuery(my_pool, query)

  # no rows to predict, so do nothing
  if (nrow(predictors) == 0) {
    return(data.frame())
  }

  # convert the dataframe to an h2o object, removing elements that are not predictors
  # these also split the population by age
  h2o_predict_frame_adults <- predictors %>%
    filter(Age >= 18) %>%
    select(-c(person_id, encounter_id, location_id)) %>%
    as.h2o()
  # h2o uses a client-server model, so the as.h2o() above will actually create a copy
  # of the dataframe in the h2o server; here we add a hook to ensure that we clean-up
  # the dataframes from h2o when we're done with them to help ensure we don't swallow
  # all the server memory.
  #
  # Every h2o object should be removed once we're done with it.
  on.exit(h2o.rm(h2o_predict_frame_adults))

  # this creates the frame for pediatric patients
  h2o_predict_frame_minors <- predictors %>%
    filter(Age < 18) %>%
    select(-c(person_id, encounter_id, location_id)) %>%
    as.h2o()
  on.exit(h2o.rm(h2o_predict_frame_minors))  # on.exit for clean-up

  # run the predictions
  results_adults <- h2o.predict(ml_model_adult, h2o_predict_frame_adults)
  on.exit(h2o.rm(results_adults))   # on.exit for clean-up

  results_minors <- h2o.predict(ml_model_minor, h2o_predict_frame_minors)
  on.exit(h2o.rm(results_minors))   # on.exit for clean-up

  # casting here ensures that these objects are copied as data frames,
  # which makes things easier since most libraries can't work with an H2OFrame
  results_adults_df <- as.data.frame(results_adults)
  results_minors_df <- as.data.frame(results_minors)

  # for the case where we need this, it should be safe to assume
  # that the start week has the correct values
  # a cohort is the predictions generated for a given week
  # note that we use the week _before_ the start date; this is because the calls
  # should be made a week before the RTC date
  cohort <- clock::date_format(clock::add_weeks(start_date, -1), format="%Y-W%U")

  # the h2o result dataframes do not have the person_id, encounter_id, or location_id
  # as these are not used in generating predictions, so here we add those back in
  #
  # IT IS IMPORTANT THAT THE FILTERING DONE HERE EXACTLY MATCHES THE FILTERING DONE
  # WHEN CREATING THE h2o DATAFRAMES OR ELSE THE PREDICTIONS WILL NOT BE MATCHED TO
  # THE CORRECT PATIENT
  #
  # enrich the table of predictors with the results
  prediction_results_adults <- predictors %>%
    filter(Age >= 18) %>%
    bind_cols(results_adults_df) %>%
    # reduce data frame and rename the result
    select(person_id, encounter_id, location_id, rtc_date, predicted_prob_disengage = Disengaged) %>%
    # calculate the patient's risk category
    predict_risk(cohort, "adults") %>%
    # add per-row metadata about the run
    mutate(
      prediction_generated_date = Sys.time(),
      model_version = ml_model_version,
      start_date = start_of_week,
      end_date = end_of_week,
      week = get_week_number(rtc_date),
      .keep = "unused"
    )

  # ditto but for pediatric patients
  prediction_results_minors <- predictors %>%
    filter(Age < 18) %>%
    bind_cols(results_minors_df) %>%
    # reduce data frame and rename the result
    select(person_id, encounter_id, location_id, rtc_date, predicted_prob_disengage = Disengaged) %>%
    # calculate the patient's risk category
    predict_risk(cohort, "minors") %>%
    # add per-row metadata about the run
    mutate(
      prediction_generated_date = Sys.time(),
      model_version = ml_model_version,
      start_date = start_of_week,
      end_date = end_of_week,
      week = get_week_number(rtc_date),
      .keep = "unused"
    )

  # combine adult and peds results into one big frame
  prediction_result <- bind_rows(prediction_results_adults, prediction_results_minors)

  # add the rows from the prediction_result to the ml_weekly_predictions table
  DBI::dbAppendTable(my_pool, SQL('predictions.ml_weekly_predictions_test'), prediction_result)

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

# sets origin to the first Sunday after 1970-01-01; this should guarantee that our
# ceiling is the Sunday of the specified date
week_end <- function(date) {
  date <- as.Date(date)
  clock::date_ceiling(date, "week", origin = as.Date("1970-01-04"))
}

# calculates the "week number" string for the week before the start date
get_week_number <- function(date) {
  previous_week <- clock::add_weeks(week_start(date), -1)
  ywd <- clock::as_iso_year_week_day(previous_week)
  paste0(clock::get_year(ywd), "-W", stringr::str_pad(clock::get_week(ywd), 2, pad = "0"))
}

# embedded SQL queries
# because the predictions are generated on Monday and then run on other days to catch newly added appointments
# but we want the thresholds to remain roughly the same, we use these queries to determine what the threshold
# was for this week to be considered "High Risk" or "Medium Risk"
adult_risk_threshold_query <-
  "select
    'Medium Risk' as risk,
    location_id,
    min(predicted_prob_disengage) as probability_threshold
  from predictions.ml_weekly_predictions mlp
    join amrs.person p
      on mlp.person_id = p.person_id
  where predicted_risk = 'Medium Risk' and week = ?week
    and timestampdiff(YEAR, p.birthdate, mlp.rtc_date) >= 18
  group by location_id
  union
  select
    'High Risk' as risk,
    location_id,
    min(predicted_prob_disengage) as probability_threshold
  from predictions.ml_weekly_predictions mlp
    join amrs.person p
      on mlp.person_id = p.person_id
  where predicted_risk = 'High Risk' and week = ?week
    and timestampdiff(YEAR, p.birthdate, mlp.rtc_date) >= 18
  group by location_id;"

minor_risk_threshold_query <-
  "select
    'Medium Risk' as risk,
    location_id,
    min(predicted_prob_disengage) as probability_threshold
  from predictions.ml_weekly_predictions mlp
    join amrs.person p
      on mlp.person_id = p.person_id
  where predicted_risk = 'Medium Risk' and week = ?week
    and timestampdiff(YEAR, p.birthdate, mlp.rtc_date) < 18
  group by location_id
  union
  select
    'High Risk' as risk,
    location_id,
    min(predicted_prob_disengage) as probability_threshold
  from predictions.ml_weekly_predictions mlp
    join amrs.person p
      on mlp.person_id = p.person_id
  where predicted_risk = 'High Risk' and week = ?week
    and timestampdiff(YEAR, p.birthdate, mlp.rtc_date) < 18
  group by location_id;"

# this is a utility function that mostly handles the risk thresholding
predict_risk <- function(.data, cohort, age_category) {
  # arbitrary cut-off, but we expect one big batch per week
  # and several small batches; small batches are handled by this if
  if (nrow(.data) < 200) {
    cutoffs <- DBI::dbGetQuery(
      my_pool,
      DBI::sqlInterpolate(
        my_pool,
        ifelse(age_category == "minors", minor_risk_threshold_query, adult_risk_threshold_query),
        week = cohort
      )
    )

    if (nrow(cutoffs) == 2) {
      medium_risk <- cutoffs %>%
        filter(risk == "Medium Risk") %>%
        select(location_id, probability_threshold)

      high_risk <- cutoffs %>%
        filter(risk == "High Risk") %>%
        select(location_id, probability_threshold)

      # if we have risk thresholds, just use them
      return(
        .data %>%
          group_by(location_id) %>%
          mutate(
            hrisk_threshold = high_risk %>%
              filter(location_id == cur_group()$location_id) %>%
              select(probability_threshold) %>% pull,
            mrisk_threshold = medium_risk %>%
              filter(location_id == cur_group()$location_id) %>%
              select(probability_threshold) %>% pull,
            predicted_risk =
              case_when(
                predicted_prob_disengage >= hrisk_threshold ~ "High Risk",
                predicted_prob_disengage >= mrisk_threshold ~ "Medium Risk",
                .default = NA_character_
              ),
            .keep = "all"
          ) %>%
          ungroup() %>%
          select(-c(hrisk_threshold, mrisk_threshold))
      )
    }
  }

  # for large batches, we calculate the thresholds from the predictions themselves
  # the scoring system is that the 90th percentile of risk score are "High Risk" and the 80th percentile are "Medium Risk"
  # we also break this down by location, so every location should have about 20% of its weekly visits flagged
  .data %>%
    group_by(location_id) %>%
    mutate(
      percentile = percent_rank(predicted_prob_disengage),
      predicted_risk =
        case_when(
          percentile >= .9 ~ "High Risk",
          percentile >= .8 ~ "Medium Risk",
          .default = NA_character_
        ),
      .keep = "all"
    ) %>%
    ungroup() %>%
    select(-c(percentile)) %>%
    mutate(
      percentile = percent_rank(predicted_prob_disengage),
      predicted_risk =
        case_when(
          !is.na(predicted_risk) ~ predicted_risk,
          percentile >= .9 ~ "High Risk",
          percentile >= .8 ~ "Medium Risk",
          .default = NA_character_
        )
    )%>%
    select(-c(percentile))
}
