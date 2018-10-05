#!/bin/bash

if [ "$#" -lt 2 ]
then
	echo "Usage: $0 <URL name> <DAT files path>"
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Usage: $0 <URL name> <DAT files path>" "" "Error"
	exit 20
fi

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

# Init config
source "$SCRIPT_DIR/config.sh"

DL_URL_NAME="$1"
DAT_PATH="$2"

function remove_tmp_files() {
    find "$DAT_PATH" -name '*.tmp1' -delete || exit 26
    find "$DAT_PATH" -name '*.tmp2' -delete || exit 26
}
trap remove_tmp_files EXIT

function split_dat() {
    local DAT_FILE="$1"
    local DAT_LINES_PER_FILE="$2"
    local PART_PREFIX
    PART_PREFIX="part_$(basename "${DAT_FILE%.dat}")"
    cd "$DAT_PATH" || exit 27

    split -d -l "$DAT_LINES_PER_FILE" "$DAT_FILE" "$PART_PREFIX" || exit 28
    rm -f "$DAT_FILE" || exit 27
}

function run_awk() {
    local DAT_FILE="$1"
    local COL_COUNT="$2"
    local DAT_PREP_FILE1
    local DAT_PREP_FILE2
    local INCL_DATA
    INCL_DATA=$(cat "$(dirname "$0")/pre-process.awk")
    DAT_PREP_FILE1="${DAT_FILE}.tmp1"
    DAT_PREP_FILE2="${DAT_FILE}.tmp2"

    # In some cases gawk not correct working with bad chars, we should prepare file before run gawk
    iconv -f cp1251 -t UTF-8//IGNORE "$DAT_FILE" > "$DAT_PREP_FILE1" || exit 23

    # Is some cases input files starts with CRLF and from middle lines splitting with LF only
    # We need convert all line endings to LF (remove CR)
    tr -d '\r' < "$DAT_PREP_FILE1" > "$DAT_PREP_FILE2" || exit 23

    local EXIT_CODE
    # gawk older than 4.x not supports includes
    rm -f "$DAT_FILE" || exit 25
    gawk --re-interval -v RS='\n' -v OFS="$SDEL" -v COL_COUNT="$COL_COUNT" -v OUT_FILE="$DAT_FILE" -F "$SDEL" "$INCL_DATA" "$DAT_PREP_FILE2"
    EXIT_CODE="$?"
    test $EXIT_CODE -eq 0 || exit 24

    #rm -f "$DAT_PREP_FILE1" || exit 25
    #rm -f "$DAT_PREP_FILE2" || exit 25
}

for DAT_FNAME in $DAT_PATH/*.dat
do
    DAT_BASENAME="$(basename "$DAT_FNAME")"
    DAT_BASENAME_WO_EXT="${DAT_BASENAME%.dat}"
    COL_COUNT=${DAT_COL_COUNTS[$DAT_BASENAME_WO_EXT]}
    if [ "$COL_COUNT" == "" ]
    then
        continue
    fi

    echo "Preprocessing $DAT_BASENAME_WO_EXT..."
    add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Preprocessing $DAT_BASENAME_WO_EXT..." "" "Info"

    run_awk "$DAT_FNAME" "$COL_COUNT"

    DAT_CELLS="$(head -n1 "$DAT_FNAME" | awk -v RS='\n' -F "$SDEL" '{print NF}')"
    DAT_LINES="$(wc -l "$DAT_FNAME" | cut -d' ' -f1)"
    (( DAT_LINES-- ))
    (( DAT_CELLS*=DAT_LINES ))

    if [ "$DAT_CELLS" -gt "$DAT_CELLS_PER_FILE" ]
    then
        (( DAT_PARTS_COUNT=DAT_CELLS/DAT_CELLS_PER_FILE ))
        if [ "$((DAT_CELLS%DAT_CELLS_PER_FILE))" -gt 0 ]
        then
            (( DAT_PARTS_COUNT++ ))
        fi
        (( DAT_LINES_PER_FILE=DAT_LINES/DAT_PARTS_COUNT ))

        echo "Splitting DAT file for small parts ($DAT_LINES_PER_FILE lines per file)..."
        add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Splitting DAT file for small parts ($DAT_LINES_PER_FILE lines per file)..." "" "Info"

        split_dat "$DAT_FNAME" "$DAT_LINES_PER_FILE"
    fi
done

function rename_dat() {
    local DAT_FILE
    local DAT_FNAME="$1"
    local SUFFIX="$2"
    DAT_FILE="$DAT_PATH/$DAT_FNAME.dat"

    if [ -f "$DAT_FILE" ]
    then
        mv "$DAT_PATH/$DAT_FNAME.dat" "$DAT_PATH/${DAT_FNAME}-$SUFFIX-00.dat" || exit 21
    elif [ "$(find "$DAT_PATH" -name "${DAT_PART_PREFIX}${DAT_FNAME}*" | wc -l)" -gt 0 ]
    then
        for DAT_FNAME2 in $DAT_PATH/${DAT_PART_PREFIX}${DAT_FNAME}*
        do
            PART_NUMBER="$(basename "$DAT_FNAME2" | gawk --re-interval -v pat="^$DAT_PART_PREFIX.+([0-9]{2})$" 'match($0, pat, arr) {print arr[1]}')"
            NEW_DAT_FNAME="${DAT_FNAME}-${SUFFIX}-${PART_NUMBER}.dat"
            mv "$DAT_FNAME2" "$DAT_PATH/$NEW_DAT_FNAME" || exit 21
        done
    fi
}

case "$DL_URL_NAME" in
    full_r|daily_r|daily_r_*)
        rename_dat "RA" "REG"
        rename_dat "EN" "REG"
        rename_dat "CO" "REG"
        rename_dat "RE" "REG"
        rename_dat "SC" "REG"
        rename_dat "HS" "REG"
        ;;
    *)
        echo "Unknown URL name"
        add_log "$API_UN" "$API_PW" "$LOG_URL" "$IHUB_PROCESS" "Unknown URL name" "" "Error"

        exit 22
        ;;
esac
