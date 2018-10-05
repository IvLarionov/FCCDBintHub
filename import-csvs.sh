#!/bin/bash
if [ "$#" -lt 3 ]
then
    echo "Usage: $0 <CSV files path> <API username> <API password>"
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Usage: $0 <CSV files path> <API username> <API password>" "" "Error"

    exit 1
fi

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

# Init config
source "$SCRIPT_DIR/config.sh"

CURL_OUT_FILE="$DL_PATH/curl_$(date +%s).log"

function remove_curl_out() {
    test -f "$CURL_OUT_FILE" && rm -f "$CURL_OUT_FILE"
}
trap remove_curl_out EXIT

function remove_csv_part_files() {
    find "$CSV_PATH" -name 'part_*' -delete || exit 56
}
trap remove_csv_part_files EXIT

CSV_PATH="$1"

function split_csv() {
    local CSV_FNAME="$1"
    local CSV_FILE="$2"
    local CSV_LINES_PER_FILE="$3"
    local PART_PREFIX="${CSV_PART_PREFIX}${CSV_FNAME}_"
    local TMP_FILE
    TMP_FILE="$(mktemp)"
    cd "$CSV_PATH" || return 53

    tail -n +2 "$CSV_FILE" | split -d -l "$CSV_LINES_PER_FILE" - "$PART_PREFIX"
    for PART_FILE in $PART_PREFIX*
    do
        head -n 1 "$CSV_FILE" > "$TMP_FILE"
        cat "$PART_FILE" >> "$TMP_FILE"
        mv -f "$TMP_FILE" "$PART_FILE"
    done
    rm -f "$TMP_FILE"
}

# https://stackoverflow.com/a/21595107
function get_json_val() {
    python -c "import json,sys;sys.stdout.write(json.dumps(json.load(sys.stdin)$1))" | sed -e 's/^"//' -e 's/"$//'
}

function run_import() {
    local IMP_ID="$1"
    local IMP_ACTION="$2"
    local CSV_FNAME="$3"
    local CSV_FILE="$4"
    local WAIT_FOR_END="$5"

    echo "Running import [impId=$IMP_ID,impAction=$IMP_ACTION] for $CSV_FNAME..."
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Running import [impId=$IMP_ID,impAction=$IMP_ACTION] for $CSV_FNAME..." "" "Info"

    local EX_CODE
    local RESPONSE_CODE
    local PROCESS_ID
    local RETRIES

    RETRIES="$IMPORT_CURL_RETRIES"
    while true
    do
        (( RETRIES-- ))
        if [ "$RETRIES" -eq -1 ]
        then
            echo "Retries exceeded"
            add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Retries exceeded" "" "Error"

            return 51
        fi

        RESPONSE_CODE=0
        RESPONSE_CODE=$(curl --user "$API_UN:$API_PW" --write-out '%{http_code}' --silent --output "$CURL_OUT_FILE" -F action="$IMP_ACTION" -F file=@"$CSV_FILE" "$ENDPOINT_URL/api/v3/imports/$IMP_ID/run")
        EX_CODE=$?
        if [ "$EX_CODE" -ne 0 ]
        then
            echo "Curl returned non zero code: $EX_CODE"
            add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Curl returned non zero code: $EX_CODE" "" "Error"

        fi
        if [ "$RESPONSE_CODE" -ne 200 ]
        then
            echo "Server returned non 200 response code: $RESPONSE_CODE"
            add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Server returned non 200 response code: $RESPONSE_CODE" "" "Error"

            if [ -f "$CURL_OUT_FILE" ]
            then
                >&2 echo "==============="
                >&2 cat "$CURL_OUT_FILE"
                >&2 printf "\\n===============\\n"
                rm -f "$CURL_OUT_FILE"
            fi
            echo "Waiting $WAIT_SEC_BEFORE_NEXT_RETRY sec. before next attempt..."
            add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Waiting $WAIT_SEC_BEFORE_NEXT_RETRY sec. before next attempt..." "" "Info"

            sleep "$WAIT_SEC_BEFORE_NEXT_RETRY"
        else
            break
        fi
    done

    if [ "$WAIT_FOR_END" -eq 1 ]
    then
        local CURRENT_STATUS
        local FL
        PROCESS_ID=$(get_json_val "['process_id']" < "$CURL_OUT_FILE")
        FL="/"

        if [ "$PROCESS_ID" == "" ]
        then
            echo "Can't get process id"
            add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Can't get process id" "" "Error"

            if [ -f "$CURL_OUT_FILE" ]
            then
                >&2 echo "==============="
                >&2 cat "$CURL_OUT_FILE"
                >&2 printf "\\n===============\\n"
                rm -f "$CURL_OUT_FILE"
            fi
            return 57
        fi
        echo "[processId=$PROCESS_ID]"
        add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "[processId=$PROCESS_ID]" "" "Info"

        RETRIES="$IMPORT_CURL_RETRIES"
        while true
        do
            if [ "$FL" == "/" ]
            then
                FL="\\"
            else
                FL="/"
            fi
            echo -ne 'Waiting for import end... '
            echo -ne "$FL"
            echo -ne '\r'

            (( RETRIES-- ))
            if [ "$RETRIES" -eq -1 ]
            then
                echo "Retries exceeded"
                add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Retries exceeded" "" "Error"

                return 51
            fi

            RESPONSE_CODE=0
            RESPONSE_CODE=$(curl --user "$API_UN:$API_PW" --write-out '%{http_code}' --silent --output "$CURL_OUT_FILE" "$ENDPOINT_URL/api/v3/imports/runs/$PROCESS_ID")
            EX_CODE=$?
            if [ "$EX_CODE" -ne 0 ]
            then
                echo "Curl returned non zero code: $EX_CODE"
                add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Curl returned non zero code: $EX_CODE" "" "Error"

            fi
            if [ "$RESPONSE_CODE" -ne 200 ]
            then
                echo "Server returned non 200 response code: $RESPONSE_CODE"
                add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Server returned non 200 response code: $RESPONSE_CODE" "" "Error"

                if [ -f "$CURL_OUT_FILE" ]
                then
                    >&2 echo "==============="
                    >&2 cat "$CURL_OUT_FILE"
                    >&2 printf "\\n===============\\n"
                    rm -f "$CURL_OUT_FILE"
                fi
                echo "Waiting $WAIT_SEC_BEFORE_NEXT_RETRY sec. before next attempt..."
                add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Waiting $WAIT_SEC_BEFORE_NEXT_RETRY sec. before next attempt..." "" "Info"

                sleep "$WAIT_SEC_BEFORE_NEXT_RETRY"
                continue
            else
                RETRIES="$IMPORT_CURL_RETRIES"
            fi

            CURRENT_STATUS=$(get_json_val "['status']" < "$CURL_OUT_FILE")
            case "$CURRENT_STATUS" in
                RUNNING_*|IN_QUEUE|PENDING)
                    sleep 10
                    ;;
                INTERRUPTED|NUM_CELLS_LIMIT_EXCEEDED)
                    echo
                    echo "Import run failed: $CURRENT_STATUS"
                    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Import run failed: $CURRENT_STATUS" "" "Error"

                    return 54
                    ;;
                EXECUTED_*)
                    echo
                    echo "Import run success: $CURRENT_STATUS"
                    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Import run success: $CURRENT_STATUS" "" "Info"

                    return 0
                    ;;
                *)
                    echo
                    echo "Unknown import status: $CURRENT_STATUS"
                    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Unknown import status: $CURRENT_STATUS" "" "Error"

                    return 55
                    ;;
            esac
        done
    fi
    return 0
}

function test_exitcode() {
    local EX_CODE="$1"
    if [ "$EX_CODE" -ne 0 ]
    then
        printf "\\nScript terminating\\n"
        exit "$EX_CODE"
    fi
}

echo "Using API endpoint: $ENDPOINT_URL"
add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Using API endpoint: $ENDPOINT_URL" "" "Info"

echo "Using API username: $API_UN"
add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Using API username: $API_UN" "" "Info"

echo "Removing old part files..."
add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Removing old part files..." "" "Info"
find "$CSV_PATH" -name "${CSV_PART_PREFIX}*" -delete || exit 50

if [ "$(find "$CSV_PATH" -name '*.csv' | wc -l)" -eq 0 ]
then
    echo "No import files found."
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "No import files found." "" "Warning"

    exit 0
fi

for CSV_FILE in $CSV_PATH/*.csv
do
    CSV_FNAME="$(basename "$CSV_FILE")"
    CSV_FNAME="${CSV_FNAME%.csv}"
    CSV_FNAME="$(echo "$CSV_FNAME" | gawk --re-interval '{s = $1; sub(/^[0-9]{1,2}_/, "", s); print s}')"
    IMP_ID="${IMP_IDS[$CSV_FNAME]}"
    IMP_ACTION="${IMP_ACTIONS[$CSV_FNAME]}"

    add_log_file "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Info" "$CSV_FILE"

    # Force waiting before run next import (when running full import server return 504 after start 6+ imports concurrently)
    WAIT_FOR_END="1"

    if [ "$IMP_ID" == "" ]
    then
        echo "Skipped $CSV_FNAME. No Import ID"
        add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Skipped $CSV_FNAME. No Import ID" "" "Warning"

        continue
    fi
    if [ "$IMP_ACTION" == "" ]
    then
        echo "Skipped $CSV_FNAME. No Import Action"
        add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Skipped $CSV_FNAME. No Import Action" "" "Warning"

        continue
    fi

    echo "Importing $CSV_FNAME with action $IMP_ACTION..."
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Importing $CSV_FNAME with action $IMP_ACTION..." "" "Info"


    CSV_CELLS="$(head -n1 "$CSV_FILE" | awk -v RS='\n' -F "$TDEL" '{print NF}')"
    CSV_LINES="$(wc -l "$CSV_FILE" | cut -d' ' -f1)"
    (( CSV_LINES-- ))
    (( CSV_CELLS*=CSV_LINES ))

    if [ "$CSV_CELLS" -gt "$MAX_IMPORT_CSV_CELLS" ]
    then
        (( CSV_PARTS_COUNT=CSV_CELLS/MAX_IMPORT_CSV_CELLS ))
        if [ "$((CSV_CELLS%MAX_IMPORT_CSV_CELLS))" -gt 0 ]
        then
            (( CSV_PARTS_COUNT++ ))
        fi
        (( CSV_LINES_PER_FILE=CSV_LINES/CSV_PARTS_COUNT ))

        echo "Splitting CSV file for small parts ($CSV_LINES_PER_FILE lines per file)..."
        add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Splitting CSV file for small parts ($CSV_LINES_PER_FILE lines per file)..." "" "Info"

        split_csv "$CSV_FNAME" "$CSV_FILE" "$CSV_LINES_PER_FILE"
        PART_ITER=0
        for CSV_PART_FILE in $CSV_PATH/${CSV_PART_PREFIX}${CSV_FNAME}_[0-9]*
        do
            (( PART_ITER++ ))
            run_import "$IMP_ID" "$IMP_ACTION" "${CSV_FNAME}:$PART_ITER" "$CSV_PART_FILE" "$WAIT_FOR_END"
            IMP_EXIT_CODE="$?"
            rm -f "$CSV_PART_FILE"

            test_exitcode "$IMP_EXIT_CODE"
        done
    else
        run_import "$IMP_ID" "$IMP_ACTION" "$CSV_FNAME" "$CSV_FILE" "$WAIT_FOR_END"
        test_exitcode "$?"
    fi
done

test -f "$CURL_OUT_FILE" && rm -f "$CURL_OUT_FILE"
