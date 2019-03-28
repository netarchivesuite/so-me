#!/bin/bash

#
# Takes a list of files with tweets and counts how many individual tweets there are.
# Resilient towards corrupted files.
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
source tweet_common.sh
popd > /dev/null

usage() {
    >&2 cat <<EOF
# Takes a list of files with tweets and counts how many individual tweets there are.
# Resilient towards corrupted files.

Usage: ./count_tweets.dh tweets-file*

Sample: ./count_tweets.sh twitter_search_ft19_2019*.json.gz
EOF
    exit $1
}

check_parameters() {
    if [[ -z "$1" ]]; then
        >&2 echo "No tweet-files specified"$'\n'
        usage 2
    fi
}

################################################################################
# FUNCTIONS
################################################################################

count_all() {
    local FILES="$@"
    local TOTAL_COUNT=0
    local FILE_COUNT=0
    local RESOURCE_FILES=0
    for F in $FILES; do
        local COUNT=$(zcat -f "$F" | wc -l)
        if [[ "." != ".$COUNT" ]]; then
            TOTAL_COUNT=$(( TOTAL_COUNT + COUNT ))
            FILE_COUNT=$(( FILE_COUNT+1 ))
        else
            >&2 echo "Error: Unable to count tweets in $F"
        fi
        if [[ -s ${F%.json}.resources.warc || -s ${F%.json.gz}.resources.warc ]]; then
            RESOURCE_FILES=$(( RESOURCE_FILES+1 ))
        fi
    done
    echo "$FILE_COUNT files ($RESOURCE_FILES with harvested resources) with $TOTAL_COUNT individual tweets"
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
count_all "$@"
