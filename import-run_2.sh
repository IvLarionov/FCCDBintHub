#!/bin/bash

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

# Init config
source "$SCRIPT_DIR/config.sh"

# Check URL set exists
DL_SET_NAME=$(get_property $SCRIPT_DIR"/SettingsFile.integration" "SET")
DL_SET="${DL_SETS[$DL_SET_NAME]}"

if [ "$DL_SET" == "" ]
then
	echo "No URL set found. Available URL sets: ${!DL_SETS[*]}"
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "No URL set found. Available URL sets: ${!DL_SETS[*]}" "" "Error"
	exit 1
fi

IFS=' ' read -r -a DL_SET_URL_NAMES <<< "${DL_SETS[$DL_SET_NAME]}"

API_UN=$(get_property $SCRIPT_DIR"/SettingsFile.integration" "UN")
API_PW=$(get_property $SCRIPT_DIR"/SettingsFile.integration" "PWD")

####################################################
DL_SET_PATH="$DL_PATH/$DL_SET_NAME"
test -e "$DL_SET_PATH" && (rm -rf "$DL_SET_PATH" || exit 10)
mkdir -p "$DL_SET_PATH" || exit 11

echo "Downloading $DL_SET_NAME data..."
add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Downloading $DL_SET_NAME data..." "" "Info"

for DL_URL_NAME in "${DL_SET_URL_NAMES[@]}"
do
    ####################################################
    echo "Downloading $DL_URL_NAME..."
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Downloading $DL_URL_NAME..." "" "Info"

    ZIP_PATH="$DL_SET_PATH/$DL_URL_NAME.zip"
    wget --timeout=60 --tries="${WGET_DOWNLOAD_RETRIES}" --wait="${WAIT_SEC_BEFORE_NEXT_RETRY}" \
        "${DL_URLS[$DL_URL_NAME]}" -O "$ZIP_PATH" || exit 12
    

    add_log_file "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Info" "$ZIP_PATH"

    ####################################################
    echo "Extracting $DL_URL_NAME..."
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Extracting $DL_URL_NAME..." "" "Info"

    ZIP_INFLATE_PATH="$DL_SET_PATH/$DL_URL_NAME"
    mkdir -p "$ZIP_INFLATE_PATH" || exit 13
    cd "$ZIP_INFLATE_PATH" || exit 13
    unzip "$ZIP_PATH" || exit 14
    find . -type f  ! -name "*.dat" -delete || exit 10
    rm -f "$ZIP_PATH" || exit 10

    ####################################################
    echo "Pre processing $DL_URL_NAME files..."
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Pre processing $DL_URL_NAME files..." "" "Info"

    echo "pre-process $DL_URL_NAME $ZIP_INFLATE_PATH"
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "pre-process $DL_URL_NAME $ZIP_INFLATE_PATH" "" "Info"

    "$SCRIPT_DIR/pre-process.sh" "$DL_URL_NAME" "$ZIP_INFLATE_PATH"
    EX_CODE=$?
    if [ "$EX_CODE" -ne 0 ]
    then
        echo "pre-process returned non zero code: $EX_CODE. Script terminating"
        add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "pre-process returned non zero code: $EX_CODE. Script terminating" "" "Error"

        exit 15
    fi

    ####################################################
    cd "$ZIP_INFLATE_PATH" || exit 13
    echo "Importing $DL_URL_NAME files into CSVS..."
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Importing $DL_URL_NAME files into CSVS..." "" "Info"

    CSV_PATH="$DL_SET_PATH/${DL_URL_NAME}_csvs"
    mkdir -p "$CSV_PATH" || exit 16

	echo "prepare-csvs $ZIP_INFLATE_PATH $CSV_PATH"
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "prepare-csvs $ZIP_INFLATE_PATH $CSV_PATH" "" "Info"

	"$SCRIPT_DIR/prepare-csvs.sh" "$ZIP_INFLATE_PATH" "$CSV_PATH"
	EX_CODE=$?
	if [ "$EX_CODE" -ne 0 ]
	then
		echo "prepare-csvs returned non zero code: $EX_CODE. Script terminating"
        add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "prepare-csvs returned non zero code: $EX_CODE. Script terminating" "" "Error"

		exit 17
	fi

    ####################################################
    echo "Cleaning extracted $DL_URL_NAME data..."
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Cleaning extracted $DL_URL_NAME data..." "" "Info"

    cd "$CSV_PATH" || exit 13
    rm -rf "$ZIP_INFLATE_PATH" || exit 10

    ####################################################
    echo "Post processing $DL_URL_NAME CSV files..."
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Post processing $DL_URL_NAME CSV files..." "" "Info"

    echo "post-process-csvs $CSV_PATH"
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "post-process-csvs $CSV_PATH" "" "Info"

    "$SCRIPT_DIR/post-process-csvs.sh" "$CSV_PATH"
    EX_CODE=$?
    if [ "$EX_CODE" -ne 0 ]
    then
        echo "post-process-csvs returned non zero code: $EX_CODE. Script terminating"
        add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "post-process-csvs returned non zero code: $EX_CODE. Script terminating" "" "Error"

        exit 18
    fi

    ####################################################
    echo "Start importing $DL_URL_NAME CSV files..."
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Start importing $DL_URL_NAME CSV files..." "" "Info"

    echo "import-csvs $CSV_PATH $API_UN"
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "import-csvs $CSV_PATH $API_UN" "" "Info"

    cd "$CSV_PATH" || exit 13
    "$SCRIPT_DIR/import-csvs.sh" "$CSV_PATH" "$API_UN" "$API_PW"
    EX_CODE=$?
    if [ "$EX_CODE" -ne 0 ]
    then
        echo "import-csvs returned non zero code: $EX_CODE. Script terminating"
        add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "import-csvs returned non zero code: $EX_CODE. Script terminating" "" "Error"

        exit 19
    fi
done
