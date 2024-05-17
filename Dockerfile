FROM rstudio/plumber:latest

ENV TZ "Africa/Nairobi"

# install base libraries we need
RUN apt-get -y update -qq && apt-get -y --no-install-recommends install \
    tini \
    libmariadb-dev \
    libmysqlclient21 \
    openjdk-8-jdk-headless \
    cron \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /etc/cron.*/*

# install the R packages we need
# for these, the latest version should always be usable
RUN install2.r --error --skipinstalled \
    tidyverse \
    pool \
    clock \
    config \
    uuid \
    readr \
    RMariaDB \
    DBI \
    && rm -rf /tmp/downloaded_packages

# The model always needs to run on the exact version of h2o used to train it
RUN Rscript -e "remotes::install_version('h2o', '3.44.0.3')"

# Add the prediction model to the app
COPY IIT-Prediction/model/V9B /app/model
# Add the production extraction query to the app
COPY SQL/iit_prod_data_extract.sql /app/iit_prod_data_extract.sql

# The next scripts are used for cron jobs
# this script triggers the predictions to run by hitting the API endpoint
COPY docker-resources/run_predictions.sh /app/run_predictions.sh
RUN chmod 0744 /app/run_predictions.sh
# this script runs a small number of stored procedures we depend on to update
# various tables used in the predictions
COPY docker-resources/run_daily_stored_procedures.sh /app/run_daily_stored_procedures.sh
RUN chmod 0744 /app/run_daily_stored_procedures.sh

# this is a Docker entrypoint script
# it ensures the cron daemon is started and then runs the API
COPY docker-resources/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 0744 /docker-entrypoint.sh

# here we actually setup the cron jobs, using our source crontab
# cron is _very_ picky, so it may not be best to mess with this
COPY docker-resources/crontab /etc/cron.d/iit-crontab
RUN chmod 0644 /etc/cron.d/iit-crontab
RUN crontab -u root /etc/cron.d/iit-crontab

# now we also need to add the R code used here
# this R code actually runs the stored procedures for run_daily_stored_procedures.sh
# this is done in R so we can re-use the database settings for the API
COPY docker-resources/dailyStoredProcedures.R /app/dailyStoredProcedures.R
# plumber.R is the main app
COPY docker-resources/plumber.R /app/plumber.R

# EXPOSE is just documentation; by default, the API is run on port 8000
# In production, this port is not exposed, as we hit the API from inside the container
EXPOSE 8000

# setup the entrypoint
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

# this may not be necessary, but its left in to match the parent container defaults
CMD ["/app/plumber.R"]
