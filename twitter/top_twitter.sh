#!/bin/bash

#
# Extracts top-x hashtags/mentions/tweeters/links from the given Twitter API JSON files
#
# NOTE: screen_name is not guaranteed to be persistent over time.
# Consider id_str, although that too can change
#
# TODO:
# - authors_by_tweets_no_retweets
# - authors_by_retweets
# - authors_by_replies should not count replies to one self
# - top-x tags in corpus vs. Twitter count for the tags

###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
if [[ -s "top_twitter.conf" ]]; then
    source top_twitter.conf
fi
: ${TOPX:="-1"} # The result size. -1 means all hashtags
: ${TOPTYPE:="tags"} # tags, mentions, tweeters, links
popd > /dev/null

usage() {
    cat <<EOF
Extracts top-x hashtags, links or tweeters based on the given criteria from
the given Twitter API JSON files.

Usage: ./top_twitter.sh twitter_api_json*

Note 1: twitter_api_json can be GZIPped
Note 2: De-duplication of the tweets is the responsibility of the caller

Environment variables

TOPX: The result size, -1 means no limit

TOPTYPE: 
 - tags:     Tags used in the tweets
 - mentions: Twitter users mentioned in the tweets
 - links:    Links used in the tweets

 - authors_by_tweets:         Most tweets in the corpus
 - authors_by_replies:        Most replies for the tweets in the corpus
 - authors_by_followers:      Most followers in profile
 - authors_by_profile_likes:  Most likes in profile
 - authors_by_profile_tweets: Most tweets in profile
EOF
    exit $1
}

check_parameters() {
    if [[ -z "$1" ]]; then
        echo "No Twitter API JSON files specified"
        usage 2
    fi
}

################################################################################
# FUNCTIONS
################################################################################

authors_by() {
    local T=$(mktemp)
    case "$TOPTYPE" in
        authors_by_followers)
            zcat -f "$@" | jq --indent 0 '[.user.screen_name,.user.followers_count]' | tr -d '"' | tr -d '[' | tr -d ']' | tr ',' ' ' | LC_ALL=C sort -k2,2n -k1 | tac > "$T"
            ;;
        authors_by_profile_likes)
            zcat -f "$@" | jq --indent 0 '[.user.screen_name,.user.favourites_count]' | tr -d '"' | tr -d '[' | tr -d ']' | tr ',' ' ' | LC_ALL=C sort -k2,2n -k1 | tac > "$T"
            ;;
        authors_by_profile_tweets)
            zcat -f "$@" | jq --indent 0 '[.user.screen_name,.user.statuses_count]' | tr -d '"' | tr -d '[' | tr -d ']' | tr ',' ' ' | LC_ALL=C sort -k2,2n -k1 | tac > "$T"
            ;;
        *)
            >&2 echo "Unknown TOPTYPE '$TOPTYPE'"
            usage 3
    esac

    local LINE
    local TWEETER
    local LAST_TWEETER="#Noone"
    while read -r LINE; do
        TWEETER=$(cut -d\  -f1 <<< "$LINE")
        COUNT=$(cut -d\  -f2 <<< "$LINE")
        if [[ "$TWEETER" != "$LAST_TWEETER" ]]; then
            echo "$COUNT $TWEETER"
        fi
        LAST_TWEETER="$TWEETER"
    done < "$T"
    rm "$T"
}

calculate_top_x() {
    local T=$(mktemp)
    case "$TOPTYPE" in
        tags)
            zcat -f "$@" | jq -r 'if .extended_tweet then .extended_tweet.entities.hashtags[].text else .entities.hashtags[].text end' | tr '[[:upper:]]' '[[:lower:]]' | sort | uniq -c | sort -rn > "$T"
            ;;
        links)
            zcat -f "$@" | jq -r 'if .extended_tweet then .extended_tweet.entities.urls[].expanded_url else entities.urls[].expanded_url end' | sort | uniq -c | sort -rn > "$T"
            ;;
        mentions)
            zcat -f "$@" | jq -r 'if .extended_tweet then .extended_tweet.entities.user_mentions[].screen_name else entities.user_mentions[].screen_name end' | sort | uniq -c | sort -rn > "$T"
            ;;
        authors_by_tweets)
            zcat -f "$@" | jq -r '.user.screen_name' | sort | uniq -c | sort -rn > "$T"
            ;;
        authors_by_replies)
            zcat -f "$@" | jq -r '.in_reply_to_screen_name' | grep -v "null" | sort | uniq -c | sort -rn > "$T"
            ;;
        authors_by_*)
            authors_by "$@" > "$T"
            ;;
        *)
            >&2 echo "Unknown TOPTYPE '$TOPTYPE'"
            usage 3
    esac
    
    if [[ "$TOPX" -eq "-1" ]]; then
        cat "$T"
    else
        cat "$T" | head -n $TOPX
    fi
    rm "$T"
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"

calculate_top_x "$@"
