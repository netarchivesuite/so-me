#!/usr/bin/env bash

#
# Re-packages Twitter tweet-JSON, as delivered by twarc, into WARCs
#
# WARC-specification:
# http://iipc.github.io/warc-specifications/specifications/warc-format/warc-1.0/index.html
#
# Requirements: bash, uuidgen, jq, sha1sum, xxd, base32
#

# TODO: Add option for packing multiple tweet-collections into a single WARC.
# TODO: Generate Last-Modified: Sun, 28 Dec 2014 22:40:37 GMT^M


###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
if [[ -s "twitter.conf" ]]; then
    source twitter.conf
fi

# http://iipc.github.io/warc-specifications/specifications/warc-format/warc-1.0/index.html#warcinof
: ${WARC_OPERATOR:="The Royal Danish Library"}
: ${WARC_SOFTWARE:="tweets2warc.sh  https://github.com/netarchivesuite/so-me/"}
: ${WARC_GZ:="true"} # Whether or not to GZIP the WARC content
: ${FORCE:="false"}  # If false, any existing WARC-representation is not overwritten

: ${SCRIPTS:=""}     # Space separated list of scripts to include in the meta WARC. tweets2warc.sh will be added automatically

: ${DATETIME=""}; # If not defined, it will be attmpted grepped from the input filename for pattern YYYYMMDD-hhmm
: ${JOB:=""}    # Major type of job, e.g. "tweet_filter". Must be defined
: ${INCLUDE_TWEET_STREAM:="false"} # If true, the full twitter JSON stream is included in meta
popd > /dev/null

usage() {
    cat <<EOF
Re-packages Twitter tweet-JSON, as delivered by twarc, into WARCs.

Usage: ./tweets2warc.sh tweets_json*
EOF
    exit $1
}

check_parameters() {
    if [[ -z "$1" ]]; then
        echo "No Twitter API JSON files specified"
        usage 2
    fi
    if [[ -z "$JOB" ]]; then
        echo "No JOB specified"
        usage 3
    fi
    if [[ -z "$DATETIME" ]]; then
        DATETIME=$(grep -o "[1-3][0-9][0-9][0-9][0-1][0-9][0-3][0-9]-[0-2][0-9][0-6][0-9]" <<< $1)
        if [[ -z "$DATETIME" ]]; then
            DATETIME=$(date +%Y%m%d-%H%M)
            echo " - No DATETIME specified, could not locate YYYYmmdd-HHMM in $1 - using system $DATETIME"
        else
            echo " - No DATETIME specified, extrached $DATETIME from $1"
        fi
    fi
    SCRIPTS="tweets2warc.sh $SCRIPTS"
    CR=$(printf '\x0d')
    HT=$(printf '\x09')
}

################################################################################
# FUNCTIONS
################################################################################

# Input: String
# Output: Number of bytes (not number of characters)
bytes() {
    local TEXT="$1"
    LANG=C LC_ALL=C echo "${#TEXT}"
}

# Input file
sha1_32() {
    local FILE="$1"
    # sha1:2Z46YIFNTUYSCMYN2DMMJGKJLGE3QEAJ
    echo -n "sha1:"
    sha1sum "$FILE" | cut -d\  -f1 | xxd -r -p | base32
}

# Input String
sha1_32_string() {
    local CONTENT="$1"
    # sha1:2Z46YIFNTUYSCMYN2DMMJGKJLGE3QEAJ
    echo -n "sha1:"
    sha1sum <<< "$CONTENT" | cut -d\  -f1 | xxd -r -p | base32
}

# TODO: CRLF-separator
# http://iipc.github.io/warc-specifications/specifications/warc-format/warc-1.0/index.html#warcinfo
print_warc_header() {
    local T=$(mktemp)
    cat > "$T" <<EOF
# ${CR}
operator: ${WARC_OPERATOR}${CR}
software: ${WARC_SOFTWARE}${CR}
EOF
    cat <<EOF
WARC/1.0${CR}
WARC-Type: warcinfo${CR}
WARC-date: $(TZ=UTC date +%Y-%m-%dT%H:%M:%S)Z${CR}
WARC-Record-ID: <urn:uuid:$(uuidgen)>${CR}
Content-Type: application/warc-fields${CR}
Content-Length: $(wc -c < "$T")${CR}
${CR}
EOF
    cat "$T"
    rm "$T"
    echo "${CR}"
    echo "${CR}"
}

# Input: tweet JSON (single line)
print_tweet_warc_entry() {
    local TWEET="$1"

    # Generate payload. Note the single CR dividing header & record and the two CRs postfixinf the content
    # http://iipc.github.io/warc-specifications/specifications/warc-format/warc-1.0/index.html#file-and-record-model
    local TFILE=$(mktemp)
cat > "$TFILE" <<EOF    
HTTP/1.1 200 OK${CR}
Content-Type: application/json; format=twitter_tweet${CR}
Content-Length: $(bytes "$TWEET")${CR}
X-WARC-signal: twitter_tweet${CR}
${CR}
EOF
    echo "$TWEET" >> "$TFILE"

    # Resolve URL & timestamp
    local T_USER=$(jq -r .user.screen_name <<< "$TWEET")
    local T_ID=$(jq -r .id_str <<< "$TWEET")
    local URL="https://twitter.com/$T_USER/status/$T_ID"

    # "created_at": "Fri Mar 02 10:26:13 +0000 2018",
    local T_TS=$(jq -r .created_at <<< "$TWEET")
    local TIMESTAMP="$(TZ=UTZ date --date="$T_TS" +%Y-%m-%dT%H:%M:%S)Z"
    # WARC-IP-Address: 46.30.212.172

    # Generate WARC-record headers
    cat <<EOF
WARC/1.0${CR}
WARC-Type: response${CR}
WARC-Target-URI: ${URL}${CR}
WARC-Date: ${TIMESTAMP}${CR}
WARC-Payload-Digest: $(sha1_32_string "$TWEET")${CR}
WARC-Record-ID: <urn:uuid:$(uuidgen)>${CR}
Content-Type: application/http; msgtype=response; format=twitter_tweet${CR}
Content-Length: $(wc -c < ${TFILE})${CR}
${CR}
EOF
    cat "$TFILE"
    echo "${CR}"
    echo "${CR}"
    rm "$TFILE"
}
# TODO: Link this to the WARCs with twitter-json and resources

print_meta_header() {
    local T=$(mktemp)
    cat > "$T" <<EOF
# ${CR}
operator: ${WARC_OPERATOR}${CR}
software: ${WARC_SOFTWARE}${CR}
EOF
    cat <<EOF
WARC/1.0${CR}
WARC-Type: warcinfo${CR}
WARC-date: $(TZ=UTC date +%Y-%m-%dT%H:%M:%S)Z${CR}
WARC-Record-ID: <urn:uuid:$(uuidgen)>${CR}
Content-Type: application/warc-fields${CR}
Content-Length: $(wc -c < "$T")${CR}
${CR}
EOF
    cat "$T"
    rm "$T"
    echo "${CR}"
    echo "${CR}"
}

# Input: <UUID for the warcinfo> <filename> <target URI> [content type (mime, default is text/plain)]
print_file_resource() {
    local WARCINFO_UUID="$1"
    local RESOURCE="$2"
    local TARGET_URI="$3"
    local CONTENT_TYPE="$4"
    if [[ -z "$CONTENT_TYPE" ]]; then
        CONTENT_TYPE="text/plain"
    fi
    local TIMESTAMP="$(TZ=UTZ date --date="$(stat --format %y "$RESOURCE")" +"%Y-%m-%dT%H:%M:%S"Z)"

    cat <<EOF
WARC/1.0${CR}
WARC-Record-ID: <urn:uuid:$(uuidgen)>${CR}
WARC-Date: ${TIMESTAMP}${CR}
WARC-Type: resource${CR}
WARC-Target-URI: ${TARGET_URI}${CR}
WARC-Payload-Digest: $(sha1_32_string "$RESOURCE")${CR}
WARC-Warcinfo-ID: ${WARCINFO_UUID}${CR}
Content-Type: ${CONTENT_TYPE}${CR}
Content-Length: $(wc -c < ${RESOURCE})${CR}
${CR}
EOF
    cat "$RESOURCE"
    echo "${CR}"
    echo "${CR}"
}


maybe_gzip() {
    if [[ "true" == "$WARC_GZ" ]]; then
        gzip
    else
        cat
    fi
}

# Input tweets.json dest.warc
json_to_warc() {
    local TWEETS="$1"
    local WARC="$2"
    local T=$(mktemp)
    echo " - Converting $TWEETS to $WARC"

    print_warc_header | maybe_gzip > "$WARC"
    # https://stackoverflow.com/questions/10929453/read-a-file-line-by-line-assigning-the-value-to-a-variable
    # TODO: Figure out how to bypass the stupid temporary file. How do we iterate lines from zcat output? IFS=$'\n' does not help
    zcat -f "$TWEETS" > "$T"
    while read -r TWEET; do
        print_tweet_warc_entry "$TWEET" | maybe_gzip >> "$WARC"
    done < "$T"
    #    done <<< $(zcat -f "$TWEETS")
    rm "$T"
}

ensure_meta_header() {
    local META="$1"
    if [[ -s "$META" ]]; then
        return
    fi
    print_meta_header | maybe_gzip > "$META"
}

# Input a WARC file
# Output: The UUID for the file
get_warcinfo_uuid() {
    local WARC="$1"
    # WARC-Record-ID: <urn:uuid:e1233143-cbb3-4454-a073-2c5fdbeb0f1b>
    zcat "$WARC" | head -c 1000 | grep -a -m 1 "WARC-Record-ID" | cut -d\  -f2
}

create_meta() {
    local META="$1"
    local BASE="$2"
    local JSON_WARC="$3"
    local JSON_STREAM="$4"

    rm -rf "$META"
    echo " - Generating meta WARC $META"
    
    # Add metadata for the tweet WARC + twarc logs
    local JSON_WARC_UUID=$(get_warcinfo_uuid "$JSON_WARC")
    if [[ -z "$JSON_WARC_UUID" ]]; then
        >&2 echo "ERROR: Unable to extract warcinfo UUID for ${JSON_WARC_UUID}. Meta data for main warc will be skipped"
    else
        local TWARC_LOG="${BASE}.twarc.log"
        if [[ -s "$TWARC_LOG" ]]; then
            echo "   - Adding twarc log to meta: $TWARC_LOG"
            ensure_meta_header "$META"
            # Input: <UUID for the warcinfo> <filename> [content type (mime, default is text/plain)]
            print_file_resource "$JSON_WARC_UUID" "$TWARC_LOG" "metadata://netarkivet.dk/twitter-api?tool=twarc&output=log&job=${JOB}&harvestTime=${DATETIME}" "text/plain ; twarc log" | maybe_gzip >> "$META"
        else
            echo "   - Unable to locate twarc log $TWARC_LOG"
        fi
    fi

    # Add metadata for the resources WARC + links + wget log + harvest script
    local RESOURCES="${BASE}.resources.warc.gz"
    if [[ ! -s "$RESOURCES" ]]; then
        local RESOURCES="${BASE}.resources.warc" # Legacy handling
    fi        
    if [[ -s "$RESOURCES" ]]; then
        local RESOURCES_WARC_UUID=$(get_warcinfo_uuid "$RESOURCES")
        if [[ -z "$RESOURCES_WARC_UUID" ]]; then
            >&2 echo "ERROR: Unable to extract warcinfo UUID for ${RESOURCES}. Meta data for resources will be skipped"
            continue
        fi

        local LINKS="${BASE}.links"
        if [[ -s "$LINKS" ]]; then
            echo "   - Adding tweet links: $LINKS to $META"
            ensure_meta_header "$META"
            print_file_resource "$RESOURCES_WARC_UUID" "$LINKS" "metadata://netarkivet.dk/twitter-api?tool=harvest_resources.sh&output=links&job=${JOB}&harvestTime=${DATETIME}" "text/plain ; tweet links" | maybe_gzip >> "$META"
        else
            echo "   - Unable to locate tweet links: $LINKS"
        fi

        local WGET_LOG="${BASE}.wget.log"
        if [[ -s "$WGET_LOG" ]]; then
            echo "   - Adding wget log: $WGET_LOG to $META"
            ensure_meta_header "$META"
            print_file_resource "$RESOURCES_WARC_UUID" "$WGET_LOG" "metadata://netarkivet.dk/twitter-api?tool=wget&output=log&job=${JOB}&harvestTime=${DATETIME}" "text/plain ; wget log" | maybe_gzip >> "$META"
        else
            echo "   - Unable to locate wget log: $WGET_LOG"
        fi

        # Include the script responsible for controlling resource harvest
        SCRIPTS="harvest_resources.sh $SCRIPTS"
    else
        echo "    - Unable to locate resources $RESOURCES"
    fi

    # Add scripts (normally base scripts + cron script)
    for SCRIPT in $SCRIPTS $BASE_META_INCLUDES; do
        if [[ " " == "$SCRIPT" ]]; then # Ignore blanks
            continue
        fi
        if [[ ! -s "$SCRIPT" ]]; then
            echo "   - Skipping addition of script '$SCRIPT' to $META as it could not be located"
            continue
        fi
        echo "   - Adding script '$SCRIPT' to $META"
        ensure_meta_header "$META"
        print_file_resource "$JSON_WARC_UUID" "$SCRIPT" "metadata://netarkivet.dk/twitter-api?tool=tweets2warc&output=${SCRIPT}&job=${JOB}&harvestTime=${DATETIME}" "application/x-shellscript ; harvest script" | maybe_gzip >> "$META"
    done

    # Include original tweet stream if so wanted
    if [[ "true" == "$INCLUDE_TWEET_STREAM" ]]; then
        echo "   - Adding Twitter JSON stream '$JSON_STREAM' to $META"
        local TJ=$(mktemp)
        zcat "$JSON_STREAM" > "$TJ"
        ensure_meta_header "$META"
        print_file_resource "$JSON_WARC_UUID" "$TJ" "metadata://netarkivet.dk/twitter-api?tool=twarc&output=jsonl&job=${JOB}&harvestTime=${DATETIME}" "application/x-ndjson ; Twitter API JSON Stream" | maybe_gzip >> "$META"
        rm "$TJ"
    else
        echo "   - Skipping addition of Twitter JSON stream '$JSON_STREAM' to $META because INCLUDE_TWEET_STREAM=false"
    fi
}

warc_single()  {
    TFILE="$1"
    echo " - tweet2warc.sh processing $TFILE"

    local BASE="${TFILE%.*}"
    if [[ "${BASE: -5}" == ".json" ]]; then
        local BASE="${BASE%.*}"
    fi
    WARC="${BASE}.warc"
    if [[ "true" == "$WARC_GZ" ]]; then
        WARC="${WARC}.gz"
    fi
    if [[ -s "$WARC" || -s "${WARC}.gz" ]]; then
        if [[ "true" == "$FORCE" ]]; then
            echo " - Overwriting existing WARC for $TFILE as FORCE=true"
            json_to_warc "$TFILE" "$WARC"
        else
            echo " - Skipping $WARC as it has already been converted to $WARC"
        fi
    else
        json_to_warc "$TFILE" "$WARC"
    fi

    # Meta contains logs etc.
    local META="${BASE}.metadata.warc.gz"
    if [[ -s "$META" && "true" != "$FORCE" ]]; then
        echo " - Skipping meta file $META as it has already been created"
    else
        rm -f "$META"
        create_meta "$META" "$BASE" "$WARC" "$TFILE"
    fi
}

warc_all() {
    for TFILE in "$@"; do
        if [[ ! -s "$TFILE" ]]; then
            echo " - Skipping $TFILE as there is no content"
            continue
        fi
        warc_single "$TFILE"
    done
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
warc_all "$@"
