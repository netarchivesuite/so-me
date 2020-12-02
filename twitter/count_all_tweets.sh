#!/bin/bash

#
# Takes a list of folders with tweets ending in .json or .json.gz and counts
# how many individual tweets there are.
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
Takes a list of folders with tweets ending in .json or .json.gz and counts
how many individual tweets there are.

Usage: ./count_all_tweets.dh tweets-folder*

Sample: ./count_all_tweets.sh harvest2019 harvest2020
EOF
    exit $1
}

check_parameters() {
    if [[ -z "$1" ]]; then
        >&2 echo "No tweet-folders specified"$'\n'
        usage 2
    fi
}

################################################################################
# FUNCTIONS
################################################################################

count_file() {
    local FILE="$1"

    local COUNT=$(zcat -f "$FILE" | wc -l)
    if [[ "." != ".$COUNT" ]]; then
        TOTAL_COUNT=$(( TOTAL_COUNT + COUNT ))
        FILE_COUNT=$(( FILE_COUNT+1 ))
    else
        >&2 echo "Error: Unable to count tweets in $FILE"
    fi
    if [[ -s ${F%.json}.resources.warc || -s ${F%.json.gz}.resources.warc || -s ${F%.json}.resources.warc.gz || -s ${F%.json.gz}.resources.warc.gz ]]; then
        RESOURCE_FILES=$(( RESOURCE_FILES+1 ))
    fi
}

count_all() {
    local FOLDERS="$@"
    TOTAL_COUNT=0
    FILE_COUNT=0
    RESOURCE_FILES=0
    local FC=1
    local FT=$(tr ' ' '\n' <<< ${FOLDERS} | wc -l)
    for FOLDER in $FOLDERS; do
        echo " - Folder ${FC}/${FT} $FOLDER"
        while read -r FILE; do 
            count_file "$FILE"
        done <<< $(find "$FOLDER" -iname "*.json" -o -iname "*.json.gz")
        FC=$((FC+1))
        echo "   Running total: $FILE_COUNT files ($RESOURCE_FILES with harvested resources) with $TOTAL_COUNT individual tweets"
    done
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
count_all "$@"
