
set -e

# Step 1: Look for non-empty stderr files and print its contents

echo "Looking for execution errors..."
for D in $(find -type d -name "GUMBY_*"); do
    echo "Found experiment: $D"
done
echo "Done"

# @CONF_OPTION LIBSWIFT_STDERR_PARSER_CMD: Override the default stderr parser script (default: TODO).
if [ -z "$LIBSWIFT_STDERR_PARSER_CMD" ]; then
    LIBSWIFT_STDERR_PARSER_CMD=aggregate_parser.py
fi

#Step 3: Extract the data needed for the graphs from the experiment log file.
$LIBSWIFT_STDERR_PARSER_CMD . .

#Step 4: Graph the stuff
if [ -z "$R_SCRIPTS_TO_RUN" ]; then
    export R_SCRIPTS_TO_RUN="agg_downloadtime.r"
fi


