#!/bin/bash

#
# Sets up a Twitter filter with the given list of Twitter handles and
# collects the result for a given amount of time.
# After processing, it compresses the output and optionally harvests
# referenced resources.
#

#
# Requirements: twarc, timeout, jq
#

# TODO: How do we represent friends & followers?
# TODO: The cache stores the returned screen_name rather than the searched

###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
if [[ -s "twitter.conf" ]]; then
    source twitter.conf
fi
: ${HANDLES:="$1"}
: ${OUTBASE:="twitter_users"}
: ${OUTDESIGNATION:="$2"}
: ${OUTDESIGNATION:="noname"}
: ${RUNTIME:="3780"} # Seconds
: ${HARVEST:="true"} # Harvest linked resources
: ${TWARC:="$(which twarc)"}
: ${LOOKUP_CHUNK_SIZE:="200"}
: ${CALM_TIME:="7"}
source tweet_common.sh
popd > /dev/null

usage() {
    >&2 cat <<EOF
Sets up a Twitter filter with the given list of Twitter handles and
collects the result for a given amount of time.
After processing, it compresses the output and optionally harvests
referenced resources.

Usage: ./tweet_follow.sh [handles [output]]

handles: Comma-separated list of twitter handles (aka user names)
output:  Output prefix. _YYYYMMDD-HHMM.json.gz will be appended.

Sample: ./tweet_follow.sh larsloekke,YildizAkdogan da-persons
EOF
    exit $1
}

check_parameters() {
    if [[ -z "$HANDLES" ]]; then
        >&2 echo "No Twitter handles specified"$'\n'
        usage 2
    fi
    HANDLES=$(sed 's/ *, */,/g' <<< "$HANDLES")

    : ${OUT_PRE:="${OUTBASE}_${OUTDESIGNATION}"}
    : ${OUT_POST:="$(date +%Y%m%d-%H%M).json"}
    : ${OUT_PROFILES:="${OUT_PRE}_profiles_${OUT_POST}.gz"}
    : ${OUT_TWEETS:="${OUT_PRE}_tweets_${OUT_POST}"}
}

################################################################################
# FUNCTIONS
################################################################################

resolve_chunked() {
    local HANDLES="$1"
    $TWARC users "$HANDLES"
}


chunk_profiles() {
    local ALL_HANDLES=$(tr ',' '\n' <<< "$1")
    COUNTER=0
    HANDLES=""
    while read HANDLE; do
        if [[ "." != ".$HANDLES" ]]; then
            HANDLES="${HANDLES},"
        fi
        HANDLES="${HANDLES}${HANDLE}"
        COUNTER=$(( COUNTER+1 ))
        if [[ "$COUNTER" -eq "$LOOKUP_CHUNK_SIZE" ]]; then
            resolve_chunked "$HANDLES"
            HANDLES=""
            COUNTER=0
            sleep $CALM_TIME
        fi
    done <<< "$ALL_HANDLES"
    if [[ "." != ".$HANDLES" ]]; then
        resolve_chunked "$HANDLES"
    fi
}

# Following Twitter profiles is done by following user-IDs, not handles.
# The handles needs to be resolved to IDs first.
#
# Input: HANDLES (comma separated)
# Output: IDS (comma separated)
resolve_user_profiles_old() {
    echo " - Resolving user profiles from handles to $OUT_PROFILES"
#    $TWARC users "$HANDLES" | gzip > $OUT_PROFILES
    chunk_profiles "$HANDLES" | gzip > $OUT_PROFILES
    IDS=$(zcat $OUT_PROFILES | jq -r .id_str | tr '\n' ',' | sed 's/,$//')
    if [[ "." == "$IDS" ]]; then
        >&2 echo "Error: Inable to extract any IDs from $OUT_PROFILES"
    fi
}

resolve_user_profiles_and_update_cache() {
    local MISSING="$1"
    chunk_profiles "$MISSING" | gzip > $OUT_PROFILES

    # Store resolved IDs
    local EPOCH=$(date +%s)
    zcat $OUT_PROFILES | jq -r "[.screen_name,.id_str,\"$EPOCH\"] | @csv" | tr -d '"' | tr ',' ' ' >> twitter_handles.dat

    # Return resolved IDs
    zcat $OUT_PROFILES | jq -r .id_str
}

# Existing: 

handles_to_ids() {
    if [[ ! -s twitter_handles.dat ]]; then
        echo "# handle id epoch" >> twitter_handles.dat
    fi

    # Check cache
    UNRESOLVED=""
    while read -r HANDLE; do
        # handle id epoch
        ID=$(grep -i "$HANDLE " twitter_handles.dat | cut -d\  -f2)
        if [[ -z $ID ]]; then
            if [[ "." != ".$UNRESOLVED" ]]; then
                UNRESOLVED="${UNRESOLVED},"
            fi
            UNRESOLVED="${UNRESOLVED}${HANDLE}"
        else
            echo $ID
        fi
    done <<< $(tr ',' '\n' <<< "$HANDLES")

    
    # All handles resolved
    if [[ "." == ".$UNRESOLVED" ]]; then
        exit
    fi

    echo "$(date +'%Y-%m-%d %H:%M'): Resolving missing handles $UNRESOLVED" >> twitter_handles.log
    resolve_user_profiles_and_update_cache "$UNRESOLVED"
    sleep $CALM_TIME
}

resolve_ids() {
    IDS=$(handles_to_ids | tr '\n' ',' | tr '\n' ',' | sed 's/,$//')
}

follow_users() {
    local USER_COUNT=$(tr ',' '\n' <<< "$IDS" | wc -l)
    echo " - Filtering tweets from $USER_COUNT users for $RUNTIME seconds to $OUT_TWEETS"
    timeout $RUNTIME $TWARC filter --follow "$IDS" > $OUT_TWEETS
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
# resolve_user_profiles
resolve_ids
follow_users
post_process_harvested_tweets "$OUT_TWEETS"
