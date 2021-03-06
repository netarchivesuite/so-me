#!/bin/bash

#
# Iterates the given Twitter handles and performs a timeline-dump for each.
#
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
: ${HANDLES:="$1"}
: ${OUTBASE:="twitter_timeline"}
: ${OUTDESIGNATION:="$2"}
: ${HARVEST:="true"} # Harvest linked resources
: ${WARCIFY:="true"} # Generate WARC-representation tweets
: ${TWARC:="$(which twarc)"}
: ${TWARC_OPTIONS:=""} # Optional extra options

source tweet_common.sh
popd > /dev/null

usage() {
    >&2 cat <<EOF
Iterates the given comma separated Twitter handles and Twitter timeline search for
each and collects the result.
After processing, it compresses the output and optionally harvests references resources.

Note: The non-pay version of Twitter search only returns a subset of the
full search result and is only usable for sampling.

Usage: ./tweet_timeline.sh [handles [output]]

tags:   Comma-separated list of tags, words or phrases.
output: Output prefix. _YYYYMMDD-HHMM.json.gz will be appended.

Sample: ./tweet_search.sh ok18,dkpol twitter_da-politics
EOF
    exit $1
}

check_parameters() {
    if [[ -z "$HANDLES" ]]; then
        >&2 echo "No handles specified"$'\n'
        usage 2
    fi
    : ${OUT:="${OUTBASE}_${OUTDESIGNATION}_$(date +%Y%m%d-%H%M).json"}
}

################################################################################
# FUNCTIONS
################################################################################

export_timelines() {
    echo "Exporting timelines for the given handles and piping to $OUT"
    while read -r HANDLE; do
        echo " - Getting timeline for $HANDLE"
        $TWARC $TWARC_OPTIONS timeline "$HANDLE" >> $OUT
        #echo "$TWARC $TWARC_OPTIONS timeline \"$HANDLE\" > $OUT"
    done <<< "$(tr ',' '\n' <<< "$HANDLES")"
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
export_timelines
post_process_harvested_tweets "$OUT"
