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

################################################################################
# FUNCTIONS
################################################################################

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
        head -n -1 $OUT | gzip > ${OUT}.gz
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

# If WARCIFY==true, the resources from the given JSON with tweets are harvested
warcify_tweets() {
    local TWEETS="$1"
    if [[ "$WARCIFY" == "true" ]]; then
        ./tweets2warc.sh "$TWEETS"
    else
        echo " - Skipping WARC-representation of tweets from $TWEETS"
    fi
}

# Shorthand for calling pack_json, harvest_tweet_resources and warcify_tweets
#
# Input: tweets-file
post_process_harvested_tweets() {
    local TWEETS="$1"
    pack_json "$TWEETS"
    harvest_tweet_resources "${TWEETS}.gz"
    warcify_tweets "${TWEETS}.gz"
}
