#!/bin/bash

#
# Sets up a Twitter filter with the given keywords and collects the result
# for a given amount of time. After processing, it compresses the output
# and optionally harvests references resources.
#

#
# Requirements: twarc, timeout, jq
#

###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
if [[ -s "twitter.conf" ]]; then
    source twitter.conf
fi
: ${TAGS:="$1"}
: ${OUTBASE:="twitter_filter"}
: ${OUTDESIGNATION:="$2"}
: ${OUT_FOLDER:="."}
: ${RUNTIME:="3600"} # Seconds
: ${HARVEST:="true"} # Harvest linked resources
: ${WARCIFY:="true"} # Generate WARC-representation tweets
: ${TWARC:="$(which twarc)"}
: ${TWARC_OPTIONS:=""} # Optional extra options
: ${NOBUFFER:="stdbuf -oL -eL"}

source tweet_common.sh
popd > /dev/null

usage() {
    >&2 cat <<EOF
Sets up a Twitter filter with the given keywords and collects the result
for a given amount of time. After processing, it compresses the output
and optionally harvests references resources.

Usage: ./tweet_filter.sh [tags [output]]

tags:   Comma-separated list of tags, words or phrases.
output: Output prefix. _YYYYMMDD-HHMM.json.gz will be appended.

Sample: ./tweet_filter.sh ok18,dkpol twitter_da-politics
EOF
    exit $1
}

check_parameters() {
    if [[ -z "$TAGS" ]]; then
        >&2 echo "No tags specified"$'\n'
        usage 2
    fi
    : ${OUT_TIME=$(date +%Y%m%d-%H%M)}
    local OUT_H="${OUT_FOLDER}/${OUTBASE}_${OUTDESIGNATION}_${OUT_TIME}"
    : ${OUT:="${OUT_H}.json"}
    : ${OUT_TWARC_LOG:="${OUT_H}.twarc.log"}
}

################################################################################
# FUNCTIONS
################################################################################

filter_tweets() {
    echo "Filtering tweets for $RUNTIME seconds to $OUT"
    timeout $RUNTIME $NOBUFFER $TWARC $TWARC_OPTIONS --log "$OUT_TWARC_LOG" filter "$TAGS" > $OUT
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
filter_tweets
SCRIPTS="tweet_filter.sh $SCRIPTS" post_process_harvested_tweets "$OUT" "$OUT_TIME" filter
