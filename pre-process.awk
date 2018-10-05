{
    if (length($0) == 0) {
        next
    }

    if (length(prev) != 0) {
        if (COL_COUNT == prev_nf + NF - 1) {
            print prev " " formatline($0) >> OUT_FILE

            prev = ""
            prev_nf = 0
        } else {
            prev = prev " " formatline($0)
            prev_nf = prev_nf + NF - 1
        }
    } else if (COL_COUNT > NF) {
        prev = formatline($0)
        prev_nf = NF
    } else {
        print formatline($0) >> OUT_FILE
    }
}

function formatline(line) {
    line = trim(line)

    # Replace any unknown chars to nothing
    return gensub(/([^0-9A-Za-z!"#$%&'()*+,\\\-./:;<=>?@\[\]^_`~{}| ])/, "", "g", line)
}

# ltrim(), rtrim(), and trim() in awk
# https://gist.github.com/andrewrcollins/1592991
function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
function trim(s)  { return rtrim(ltrim(s)); }
