FROM rstudio/plumber:latest

ENV TZ "Africa/Nairobi"

RUN apt-get -y update && apt-get -y install \
	tini \
	libmariadb-dev \
	libmysqlclient21 \
	openjdk-8-jdk-headless \
	cron \
	curl \
	&& rm -rf /var/lib/apt/lists/*

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

RUN Rscript -e "remotes::install_version('h2o', '3.42.0.2')"

COPY docker-resources/crontab /etc/cron.d/crontab
COPY IIT-Prediction/model/V7 /app/model
COPY SQL/iit_prod_data_extract.sql /app/iit_prod_data_extract.sql
COPY docker-resources/run_predictions.sh /app/run_predictions.sh
RUN chmod +x /app/run_predictions.sh
COPY docker-resources/run_daily_stored_procedures.sh /app/run_daily_stored_procedures.sh
RUN chmod +x /app/run_daily_stored_procedures.sh
COPY docker-resources/dailyStoredProcedures.R /app/dailyStoredProcedures.R
COPY docker-resources/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
COPY docker-resources/plumber.R /app/plumber.R

EXPOSE 8000

ENTRYPOINT ["tini", "--", "./docker-entrypoint.sh"]

CMD ["/app/plumber.R"]
