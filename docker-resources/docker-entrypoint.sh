#!/bin/bash

cron
# This is just the default command from the RPlumber image
R -e "pr <- plumber::plumb(rev(commandArgs())[1]); args <- list(host = '0.0.0.0', port = 8000); if (packageVersion('plumber') >= '1.0.0') { pr\$setDocs(TRUE) } else { args\$swagger <- TRUE }; do.call(pr\$run, args)" "$@"
