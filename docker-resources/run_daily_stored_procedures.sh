#!/bin/bash
# this is a really simple script but it's easier to run a Bash script from cron
# and R from the Bash script than running this whole setup from cron
cd /app
Rscript dailyStoredProcedures.R
