#!/bin/bash

if [ "$#" -lt 2 ]
then
    echo "Usage: $0 <DAT files path> <Output CSV files path>"
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Usage: $0 <DAT files path> <Output CSV files path>" "" "Error"

    exit 1
fi

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

# Init config
source "$SCRIPT_DIR/config.sh"

PATH="$PATH:$SCRIPT_DIR"
DAT_PATH="$1"
CSV_PATH="$2"
CSV_HEADER=()

function remove_tmp_files() {
    find "$DAT_PATH" -name '*.tmp' -delete || exit 30
    find "$DAT_PATH" -name '*.invalid' -delete || exit 30
}
trap remove_tmp_files EXIT

function run_awk() {
    local DAT_FILE="$1"
    local AWK_CODE="$2"
    local CSV_FILE
    local INCL_DATA
    local DAT_TMP_FILE # This file is result of gawk
    local INVALID_LINES_FILE
    local EXIT_CODE
    CSV_FILE="$CSV_PATH/$3.csv"
    INCL_DATA=$(cat "$(dirname "$0")/prepare-csv.awk")
    DAT_TMP_FILE="${DAT_FILE}.tmp"
    INVALID_LINES_FILE="${DAT_FILE}.invalid"

    # When AWK no print anything in output file, "cat" fails with non 0 exit code
    echo -e '' > "$DAT_TMP_FILE"

    # gawk older than 4.x not supports includes
    gawk --re-interval -v INVALID_LINES_FILE="$INVALID_LINES_FILE" -v RS='\n' -v OFS="$TDEL" -v OUT_FILE="$DAT_TMP_FILE" -F "$SDEL" "$INCL_DATA \
$AWK_CODE" "$DAT_FILE"
    EXIT_CODE="$?"

    if [ "$EXIT_CODE" -eq 35 ]
    then
        echo "Skipped invalid lines:"
        echo "====================="
        cat "$INVALID_LINES_FILE"
        echo "====================="
    elif [ ! "$EXIT_CODE" -eq 0 ]
    then
        exit 32
    fi

    rm -f "$DAT_FILE" || exit 31

    # Write header into CSV when file not exists
    IFS="$TDEL"
    test -f "$CSV_FILE" || (printf "%s" "${CSV_HEADER[*]}" > "$CSV_FILE" || exit 33)
    cat "$DAT_TMP_FILE" >> "$CSV_FILE" || exit 34
    rm -f "$DAT_TMP_FILE" || exit 31
}

function run_q_notmp() {
    local IN_CSV_FILE="$2"
    local OUT_CSV_FILE="$3"

    if [ -f "$OUT_CSV_FILE" ]
    then
        q -H -e cp1251 -E cp1251 -d "," "$1" < "$IN_CSV_FILE" >> "$OUT_CSV_FILE" || exit 30
    else
        q -OH -e cp1251 -E cp1251 -d "," "$1" < "$IN_CSV_FILE" > "$OUT_CSV_FILE" || exit 30
    fi
}

function split_reg_co() {
    local SUFFIX
    local CSV_FILE="$1"
    SUFFIX="REG"

    run_q_notmp "SELECT * FROM - WHERE RA_AA_COORDINATE_TYPE = \"A\"" \
        "$CSV_FILE" "$CSV_PATH/CO-Array-$SUFFIX.csv"
    run_q_notmp "SELECT
            \"Registration ID\",
            RA_AA_RECORD_TYPE RA_CO_RECORD_TYPE,
            RA_AA_CONTENT_INDICATOR RA_CO_CONTENT_INDICATOR,
            RA_AA_FILE_NUMBER RA_CO_FILE_NUMBER,
            RA_AA_REGISTRATION_NUMBER RA_CO_REGISTRATION_NUMBER,
            RA_AA_UNIQUE_SYSTEM_IDENTIFIER RA_CO_UNIQUE_SYSTEM_IDENTIFIER,
            RA_AA_COORDINATE_TYPE RA_CO_COORDINATE_TYPE,
            RA_AA_LATITUDE_DEGREES RA_CO_LATITUDE_DEGREES,
            RA_AA_LATITUDE_MINUTES RA_CO_LATITUDE_MINUTES,
            RA_AA_LATITUDE_SECONDS RA_CO_LATITUDE_SECONDS,
            RA_AA_LATITUDE_DIRECTION RA_CO_LATITUDE_DIRECTION,
            RA_AA_LATITUDE_TOTAL_SECONDS RA_CO_LATITUDE_TOTAL_SECONDS,
            RA_AA_LONGITUDE_DEGREES RA_CO_LONGITUDE_DEGREES,
            RA_AA_LONGITUDE_MINUTES RA_CO_LONGITUDE_MINUTES,
            RA_AA_LONGITUDE_SECONDS RA_CO_LONGITUDE_SECONDS,
            RA_AA_LONGITUDE_DIRECTION RA_CO_LONGITUDE_DIRECTION,
            RA_AA_LONGITUDE_TOTAL_SECONDS RA_CO_LONGITUDE_TOTAL_SECONDS
        FROM - WHERE RA_AA_COORDINATE_TYPE = \"T\"" \
        "$CSV_FILE" "$CSV_PATH/CO-Tower-$SUFFIX.csv"
    rm -f "$CSV_FILE" || exit 31
}

for DAT_FILE in $DAT_PATH/*.dat
do
    DAT_FNAME="$(basename "$DAT_FILE")"
    PART_NUMBER="$(echo "$DAT_FNAME" | gawk --re-interval -v pat="^.+-.+-([0-9]{2}).dat$" 'match($0, pat, arr) {print ":" arr[1]}')"
    DAT_FNAME="$(echo "$DAT_FNAME" | gawk --re-interval -v pat="^(.+)-(.+)-[0-9]{2}.dat$" 'match($0, pat, arr) {print arr[1] "-" arr[2]}')"

    echo "Processing ${DAT_FNAME}${PART_NUMBER}..."
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Processing ${DAT_FNAME}${PART_NUMBER}..." "" "Info"

    case "$DAT_FNAME" in
        RA-REG)
            CSV_HEADER=("Registration ID" RA_RECORD_TYPE RA_CONTENT_INDICATOR RA_FILE_NUMBER \
                RA_REGISTRATION_NUMBER RA_UNIQUE_SYSTEM_IDENTIFIER RA_APPLICATION_PURPOSE \
                RA_PREVIOUS_PURPOSE RA_INPUT_SOURCE_CODE RA_STATUS_CODE RA_DATE_ENTERED \
                RA_DATE_RECEIVED RA_DATE_ISSUED RA_DATE_CONSTRUCTED RA_DATE_DISMANTLED \
                RA_DATE_ACTION RA_ARCHIVE_FLAG_CODE RA_VERSION RA_SIGNATURE_FIRST_NAME \
                RA_SIGNATURE_MIDDLE_INITIAL RA_SIGNATURE_LAST_NAME RA_SIGNATURE_SUFFIX \
                RA_SIGNATURE_TITLE RA_INVALID_SIGNATURE RA_STRUCTURE_STREET_ADDRESS \
                RA_STRUCTURE_CITY RA_STRUCTURE_STATE_CODE RA_COUNTY_CODE RA_ZIP_CODE \
                RA_HEIGHT_OF_STRUCTURE RA_GROUND_ELEVATION RA_OVERALL_HEIGHT_ABOVE_GROUND \
                RA_OVERALL_HEIGHT_AMSL RA_STRUCTURE_TYPE RA_DATE_FAA_DETERMINATION_ISSUED \
                RA_FAA_STUDY_NUMBER RA_FAA_CIRCULAR_NUMBER RA_SPECIFICATION_OPTION \
                RA_PAINTING_AND_LIGHTING RA_MARK_LIGHT_CODE RA_MARK_LIGHT_OTHER \
                RA_FAA_EMI_FLAG RA_NEPA_FLAG)

            run_awk "$DAT_FILE" '{validate("5:number[nn],10-15:date,17:number,29-32:number,34:date,37:number");
                printid(); printrangen("1-42")}' "$DAT_FNAME"
            ;;
        CO-REG)
            CSV_HEADER=("Registration ID" RA_AA_RECORD_TYPE RA_AA_CONTENT_INDICATOR \
                RA_AA_FILE_NUMBER RA_AA_REGISTRATION_NUMBER RA_AA_UNIQUE_SYSTEM_IDENTIFIER \
                RA_AA_COORDINATE_TYPE RA_AA_LATITUDE_DEGREES RA_AA_LATITUDE_MINUTES \
                RA_AA_LATITUDE_SECONDS RA_AA_LATITUDE_DIRECTION RA_AA_LATITUDE_TOTAL_SECONDS \
                RA_AA_LONGITUDE_DEGREES RA_AA_LONGITUDE_MINUTES RA_AA_LONGITUDE_SECONDS \
                RA_AA_LONGITUDE_DIRECTION RA_AA_LONGITUDE_TOTAL_SECONDS \
                RA_AA_ARRAY_TOWER_POSITION RA_AA_ARRAY_TOTAL_TOWER)

            run_awk "$DAT_FILE" '{validate("5:number[nn],7-9:number,11-14:number,16-18:number");
                printid(); printrangen("1-18")}' "$DAT_FNAME"

            echo "Splitting $DAT_FNAME into Tower and Array..."
            if [[ "$DAT_FNAME" == *-APP ]]
            then
                split_app_co "$CSV_PATH/$DAT_FNAME.csv"
            else # Registration
                split_reg_co "$CSV_PATH/$DAT_FNAME.csv"
            fi
            ;;
        EN-REG)
            CSV_HEADER=("Entity ID" "Registration ID" EN_RECORD_TYPE EN_CONTENT_INDICATOR \
                EN_FILE_NUMBER EN_REGISTRATION_NUMBER EN_UNIQUE_SYSTEM_IDENTIFIER \
                EN_CONTACT_TYPE EN_ENTITY_TYPE EN_ENTITY_TYPE_OTHER EN_LICENSEE_ID \
                EN_ENTITY_NAME EN_FIRST_NAME EN_MI EN_LAST_NAME EN_SUFFIX EN_PHONE \
                EN_FAX_NUMBER EN_INTERNET_ADDRESS EN_STREET_ADDRESS EN_STREET_ADDRESS_2 \
                EN_PO_BOX EN_CITY EN_STATE EN_ZIP_CODE EN_ATTENTION EN_FRN)

            run_awk "$DAT_FILE" '{validate("5:number[nn]");
                printenid(); printid(); printrangen("1-25")}' "$DAT_FNAME"
            ;;
        HS-REG)
            CSV_HEADER=("Registration ID" HS_RECORD_TYPE HS_CONTENT_INDICATOR HS_FILE_NUMBER \
                HS_REGISTRATION_NUMBER HS_UNIQUE_SYSTEM_IDENTIFIER HS_DATE HS_DESCRIPTION)

            run_awk "$DAT_FILE" '{validate("5:number[nn],6:date[nn]"); printid();
                printrangen("1-7")}' "$DAT_FNAME"
            ;;
        RE-REG)
            CSV_HEADER=("FCC Remarks ID" "Registration ID" RE_RECORD_TYPE RE_CONTENT_INDICATOR RE_FILE_NUMBER \
                RE_REGISTRATION_NUMBER RE_UNIQUE_SYSTEM_IDENTIFIER RE_REMARK_TYPE \
                RE_DATE_KEYED RE_SEQUENCE_NUMBER RE_REMARK_TEXT)

            run_awk "$DAT_FILE" '{validate("5:number[nn],7:date[nn],8:number"); printreid(); printid();
                printrangen("1-9")}' "$DAT_FNAME"
            ;;
        SC-REG)
            CSV_HEADER=("Special Condition ID" "Registration ID" SC_RECORD_TYPE SC_CONTENT_INDICATOR SC_FILE_NUMBER \
                SC_REGISTRATION_NUMBER SC_UNIQUE_SYSTEM_IDENTIFIER SC_DATE_KEYED \
                SC_SEQUENCE_NUMBER SC_REMARK_TEXT)

            run_awk "$DAT_FILE" '{validate("5:number[nn],6:date[nn],7:number"); printscid(); printid();
                printrangen("1-8")}' "$DAT_FNAME"
            ;;
        *)
            echo "No mappings"
            ;;
    esac
done
