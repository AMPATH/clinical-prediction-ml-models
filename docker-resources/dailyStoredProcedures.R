# This doesn't need to be in R but is for convenience
library(RMariaDB)
library(DBI)
library(pool)

dbConfig <- config::get()

my_pool <- dbPool(
  drv = RMariaDB::MariaDB(),
  host = dbConfig$host,
  username = dbConfig$user,
  password = dbConfig$password,
  dbname = dbConfig$defaultDb
)

DBI::dbExecute(
  my_pool,
  "CALL predictions.generate_flat_ml_baseline_visit_v1_0();"
)

DBI::dbExecute(
  my_pool,
  "CALL predictions.generate_flat_ml_days_defaulted_v1_0();"
)

DBI::dbExecute(
  my_pool,
  "CALL predictions.add_observed_appointments_to_ml_predictions_v1_0();"
)
