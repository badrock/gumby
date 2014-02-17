#!/bin/bash
# aggregate_graph
#
# Filename: aggregate_graph.sh
# Description:
# Author: Riccardo Petrocco
# Maintainer:

# Commentary:
#
# This script will extract the data from multiple experiments and ombine results in new graphs.
#

set -e

# Step 1: Look for non-empty experiment logs
echo "Looking for execution errors..."
for D in $(find -type d -name "GUMBY_*"); do
    echo "Found experiment: $D"
done
echo "Done"

# @CONF_OPTION LIBSWIFT_STDERR_PARSER_CMD: Override the default stderr parser script (default: TODO).
if [ -z "$LIBSWIFT_STDERR_PARSER_CMD" ]; then
    LIBSWIFT_STDERR_PARSER_CMD=aggregate_parser.py
fi

#Step 2: Extract the data needed for the graphs from the experiment log file.
$LIBSWIFT_STDERR_PARSER_CMD . .

#Step 3: Set the proper graphs
if [ -z "$R_SCRIPTS_TO_RUN" ]; then
    export R_SCRIPTS_TO_RUN="agg_downloadtime.r"
fi

#Step 4: Graph the stuff
cd $OUTPUT_DIR
graph_data.sh

