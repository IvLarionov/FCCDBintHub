BEGIN {
    skip_line = false
}

function printid() {
    # content_indicator + unique_system_identifier
    printf("%s%s" OFS, $2, $5) >> OUT_FILE
}

function printenid() {
    # content_indicator + unique_system_identifier + entity_type
    printf("%s%s%s" OFS, $2, $5, $6) >> OUT_FILE
}

function printreid() {
    # content_indicator + unique_system_identifier + date_keyed + sequence_number
    printf("%s%s%s%s" OFS, $2, $5, $7, $8) >> OUT_FILE
}

function printscid() {
    # content_indicator + unique_system_identifier + sequence_number
    printf("%s%s%s" OFS, $2, $5, $7) >> OUT_FILE
}

function printrange(def) {
    if (length($0) == 0) {
        return
    }

    vals_len = 0
    split(def, defs, ",")
    for (i = 1; i in defs; i++) {
        if (index(defs[i], "-") != 0) {
            split(defs[i], def_range, "-")
            for (z = def_range[1]; z <= def_range[2]; z++) {
                vals[++vals_len] = formatval($z)
            }
        } else {
            vals[++vals_len] = formatval($(defs[i]))
        }
    }
    printf("%s", join(vals, 1, vals_len, OFS)) >> OUT_FILE
}

function printrangen(def) {
    if (length($0) == 0) {
        return
    }

    printrange(def)
    printf(RS) >> OUT_FILE
}

function formatval(val) {
    val = trim(val)

    # " -> ""
    # \ -> \\
    # when quote or backslash or OFS contains we should escape all value in double quotes
    val = gensub(/\"/, "\"\"", "g", val)
    val = gensub(/\\/, "\\\\\\\\", "g", val)

    if (index(val, OFS) != 0 || index(val, "\"") != 0 || index(val, "\\") != 0) {
        val = "\"" val "\""
    }
    return val
}

function validate(def) {
    if (length($0) == 0) {
        return
    }

    split(def, validate_defs, ",")
    for (i = 1; i in validate_defs && !skip_line; i++) {
        isnotnull_pos = index(validate_defs[i], "[nn]")
        isnotnull = isnotnull_pos != 0
        dt_pos = index(validate_defs[i], ":")
        if (dt_pos != 0) {
            if (isnotnull) {
                dt = substr(validate_defs[i], dt_pos + 1, isnotnull_pos - dt_pos - 1)
            } else {
                dt = substr(validate_defs[i], dt_pos + 1, length(validate_defs[i]) - dt_pos)
            }
        } else {
            dt = "any"
        }
        split(validate_defs[i], def_parts, ":")
        if (index(def_parts[1], "-") != 0) {
            split(def_parts[1], def_range, "-")
            validaterange(def_range[1], def_range[2], dt, isnotnull)
        } else {
            validaterange(def_parts[1], def_parts[1], dt, isnotnull)
        }
    }

    if (skip_line) {
        if (length(INVALID_LINES_FILE) != 0) {
            print $0 >> INVALID_LINES_FILE
        }
        exit 35
    }
}

function validaterange(start, endcol, dt, isnotnull) {
    for (cell = start; cell <= endcol && !skip_line; cell++) {
        val = formatval($cell)
        if (length(val) == 0) {
            skip_line = isnotnull
        } else {
            skip_line = (dt == "date" && val !~ /^[0-9]{2}\/[0-9]{2}\/[0-9]{4}$/) ||
                (dt == "number" && val !~ /^-?[0-9.]+$/)
        }

        if (skip_line) {
            print "Validation failed (" cell " cell, dt = " dt ", nn = " isnotnull ") at line :" NR ". value: " val
            break
        }
    }
}

# join.awk --- join an array into a string
#
# Arnold Robbins, arnold@skeeve.com, Public Domain
# May 1993

function join(array, start, end, sep,    result, i)
{
    if (sep == "")
       sep = " "
    else if (sep == SUBSEP) # magic value
       sep = ""
    result = array[start]
    for (i = start + 1; i <= end; i++)
        result = result sep array[i]
    return result
}

# ltrim(), rtrim(), and trim() in awk
# https://gist.github.com/andrewrcollins/1592991
function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
function trim(s)  { return rtrim(ltrim(s)); }
