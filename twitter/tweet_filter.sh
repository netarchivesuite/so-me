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
    echo "Sourcing twitter"
    source twitter.conf
fi
: ${TAGS:="$1"}
: ${OUTBASE:="twitter_filter"}
: ${OUTDESIGNATION:="$2"}
: ${RUNTIME:="3600"} # Seconds
: ${HARVEST:="true"} # Harvest linked resources
: ${WARCIFY:="true"} # Generate WARC-representation tweets
: ${TWARC:="$(which twarc)"}
echo "Resolved twarc: $TWARC"
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
    : ${OUT:="${OUTBASE}_${OUTDESIGNATION}_$(date +%Y%m%d-%H%M).json"}
}

################################################################################
# FUNCTIONS
################################################################################

warcify() {
    if [[ "$WARCIFY" == "true" ]]; then
        echo "Packing ${OUT}.gz as WARC"
        ./tweets2warc.sh ${OUT}.gz
    else
        echo "Skipping WARC-representation of tweets"
    fi
}

harvest_resources() {
    if [[ "$HARVEST" == "true" ]]; then
        echo "Harvesting resources from ${OUT}.gz"
        ./harvest_resources.sh ${OUT}.gz
    else
        echo "Skipping harvest of ${OUT}.gz resources"
    fi
}

pack_tweets() {
    if [[ ! -s "$OUT" ]]; then
        >&2 echo "Warning: Empty file $OUT for tags $TAGS"
        exit 3
    fi
    local LAST=$(tail -n 1 $OUT | jq . 2> /dev/null)
    if [[ "." == ".$LAST" ]]; then
        echo "Compressing $OUT sans last line"
        head -n -1 $OUT | gzip > ${OUT}.gz
    else
        echo "Compressing $OUT"
        gzip $OUT
    fi
}

filter_tweets() {
    echo "Filtering tweets for $RUNTIME seconds to $OUT"
    timeout $RUNTIME $TWARC filter "$TAGS" > $OUT
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
filter_tweets
pack_tweets
harvest_resources
warcify
