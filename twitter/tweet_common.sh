#!/bin/bash

#
# Twitter functionality shared between scripts.
# Meant to be sourced.
#

###############################################################################
# CONFIG
###############################################################################

if [[ -s "twitter.conf" ]]; then
    source twitter.conf
fi
: ${WARCIFY:="true"} # Generate WARC-representation tweets
: ${HARVEST:="true"} # Harvest linked resources
: ${OUT_FOLDER:="."} # . = current

if [[ ! -d "$OUT_FOLDER" ]]; then
   mkdir -p "$OUT_FOLDER"
fi    

CR=$(printf '\x0d')
HT=$(printf '\x09')

################################################################################
# FUNCTIONS
################################################################################

# Creates a temporary file with the given content compressed as gzip
#
# Input: Content
# Output: File with the content gzipped.
#         The caller is responsible for deleting the file after use.
make_gzip_file() {
    local CONTENT="$1"
    local F=$(mktemp)
    echo "$CONTENT" | gzip > "$F"
    echo "$F"
}

# Input: String
# Output: Number of bytes (not number of characters)
bytes() {
    local TEXT="$1"
    LANG=C LC_ALL=C echo "${#TEXT}"
}

# Input file
sha1_32_file() {
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


# Creates a metafile with scripts and logs related to a produced WARC.
#
# Input: WARC_file_name
# Output: Content of WARC (gzip compressed)
create_metafile() {
    local WFN="$1"

    # Generate payload. Note the single CR dividing header & record and the two CRs postfixing the content
    # http://iipc.github.io/warc-specifications/specifications/warc-format/warc-1.0/index.html#file-and-record-model

    local TFILE=$(mktemp)
    cat > "$TFILE" <<EOF    
software: so-me/twitter (https://github.com/netarchivesuite/so-me)${CR}
description: Tweets and profiles harvested from Twitter API and related material harvested using wget${CR}
hostname: $(hostname)${CR}
datetime: $(date +"%Y-%m-%dT%H:%M:%S:%:z")${CR}
isPartOf: ${WFN}${CR}
${CR}
EOF

    cat <<EOF
WARC/1.0${CR}
WARC-Type: warcinfo${CR}
WARC-date: $(TZ=UTC date +%Y-%m-%dT%H:%M:%S)Z${CR}
WARC-Record-ID: <urn:uuid:$(uuidgen)>${CR}
WARC-Block-Digest: $(sha_32_file "$TFILE")${CR}
Content-Type: application/warc-fields${CR}
Content-Length: $(wc -c < "$TFILE")${CR}
${CR}
EOF
    cat "$TFILE"
    rm "$TFILE"
}

# Input: targetURI filename
create_resource_entry() {
    local TARGET_URI="$1"
    local FILENAME="$2"

    
}

# Checks that the last line in the given JSON is valid and if not, discards it.
# Packs the rest with GZIP.
#
# Input: File with JSON entries, one/line
pack_json() {
    local OUT="$1"
    if [[ ! -s "$OUT" ]]; then
        >&2 echo "Warning: pack_json encountered empty file $OUT"
        exit 3
    fi
    local LAST=$(tail -n 1 $OUT | jq . 2> /dev/null)
    if [[ "." == ".$LAST" ]]; then
        echo "Compressing $OUT sans last line"
        head -n -1 $OUT | gzip > "${OUT}.gz"
        if [[ ! -s "${OUT}.gz" ]]; then
            >&2 echo "Error: Could not compress ${OUT}. Maybe there is no room left on the device?"
            return
        fi
        rm "$OUT"
    else
        echo "Compressing $OUT"
        gzip $OUT
    fi
}

# If HARVEST==true, the resources from the given JSON with tweets are harvested
harvest_tweet_resources() {
    local TWEETS="$1"
    if [[ "$HARVEST" == "true" ]]; then
        echo " - Harvesting resources from $TWEETS"
        ./harvest_resources.sh "$TWEETS"
    else
        echo " - Skipping harvest of ${TWEETS} resources"
    fi
}

# If WARCIFY==true, the tweets harvested in JSON format are packed in WARC format
warcify_tweets() {
    local TWEETS="$1"
    local DATETIME="$2"
    if [[ "$WARCIFY" == "true" ]]; then
        SCRIPTS="$SCRIPTS" DATETIME="$DATETIME" JOB="$JOB" ./tweets2warc.sh "$TWEETS"
    else
        echo " - Skipping WARC-representation of tweets from $TWEETS"
    fi
}

#
# Shorthand for calling pack_json, harvest_tweet_resources and warcify_tweets
# JOB = overall job, e.g. tweet_search. Details are handled by SCRIPTS
#
# Input: tweets-file YYYYMMDD-HHMM JOB
post_process_harvested_tweets() {
    local TWEETS="$1"
    local DATETIME="$2"
    local JOB="$3"

    if [[ ! -s "$TWEETS" ]]; then
        >&2 echo "Error (tweet_common.sh): No tweet file specified"
        exit 2
    fi
    if [[ -s "$DATETIME" ]]; then
        >&2 echo "Error: No datetime specified"
        exit 3
    fi
    if [[ -s "$JOB" ]]; then
        >&2 echo "Error: No job specified"
        exit 4
    fi
    pack_json "$TWEETS"
    harvest_tweet_resources "${TWEETS}.gz"
    SCRIPTS="tweet_common.sh $SCRIPTS" warcify_tweets "${TWEETS}.gz" "$DATETIME" "$JOB"
}
