#!/bin/bash

#
# Issues a Twitter search with the given keywords and collects the result.
# After processing, it compresses the output and optionally harvests references resources.
#
# Note: The non-pay version of Twitter search only returns a subset of the
# full search result and is only usable for sampling.

#
# Requirements: twarc, jq
#

###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
if [[ -s "twitter.conf" ]]; then
    source twitter.conf
fi
: ${TAGS:="$1"}
: ${OUTBASE:="twitter_search"}
: ${OUTDESIGNATION:="$2"}
: ${HARVEST:="true"} # Harvest linked resources
: ${WARCIFY:="true"} # Generate WARC-representation tweets
: ${TWARC:="$(which twarc)"}
source tweet_common.sh
popd > /dev/null

usage() {
    >&2 cat <<EOF
Issues a Twitter search with the given keywords and collects the result.
After processing, it compresses the output and optionally harvests references resources.

Note: The non-pay version of Twitter search only returns a subset of the
full search result and is only usable for sampling.

Usage: ./tweet_search.sh [tags [output]]

tags:   Comma-separated list of tags, words or phrases.
output: Output prefix. _YYYYMMDD-HHMM.json.gz will be appended.

Sample: ./tweet_search.sh ok18,dkpol twitter_da-politics
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

filter_tweets() {
    echo "Searching tweets with the given tags and piping to $OUT"
    $TWARC search "$TAGS" > $OUT
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
filter_tweets
post_process_harvested_tweets "$OUT"
