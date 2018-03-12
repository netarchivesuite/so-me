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
: ${RUNTIME:="3600"} # Seconds
: ${HARVEST:="true"} # Harvest linked resources
: ${TWARC:="$(which twarc)"}
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

# Following Twitter profiles is done by following user-IDs, not handles.
# The handles needs to be resolved to IDs first.
#
# Input: HANDLES
# Output: IDS
resolve_user_profiles() {
    echo " - Resolving user profiles from handles to $OUT_PROFILES"
    $TWARC users "$HANDLES" | gzip > $OUT_PROFILES
    IDS=$(zcat $OUT_PROFILES | jq -r .id_str | tr '\n' ',' | sed 's/,$//')
    if [[ "." == "$IDS" ]]; then
        >&2 echo "Error: Inable to extract any IDs from $OUT_PROFILES"
    fi
}

follow_users() {
    local USER_COUNT=$(tr ',' '\n' <<< "$IDS" | wc -l)
    echo " - Filtering tweets from $USER_COUNT users for $RUNTIME seconds to $OUT_TWEETS"
    timeout $RUNTIME twarc filter --follow "$IDS" > $OUT_TWEETS
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
resolve_user_profiles
follow_users
post_process_harvested_tweets "$OUT_TWEETS"
