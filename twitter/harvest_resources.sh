#!/bin/bash

#
# Extracts links from tweets and harvests them to a warc-file
# The tool uses wget to do all that
#
# CONSIDER: This skips links to tweets, which might not be the correct action
# TODO: Prioritize images

###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
if [[ -s "harvest_resources.conf" ]]; then
    source harvest_resources.conf
fi
: ${QUOTA_MIN:="50"} # Minimum quota (MB) regardless of tweet count in a single tweets-file
: ${QUOTA_MAX:="500"} # Minimum quota (MB) regardless of tweet count in a single tweets-file
: ${QUOTA_PER_TWEET:="10"} # MB
: ${TIMEOUT:="60"}
popd > /dev/null

usage() {
    cat <<EOF
Extracts links from previously harvested tweets. Harvests the linked resources
at depth 1 (page + directly embedded resources) and stores it in a warc.

Usage: ./harvest_resources.sh tweets.json.gz*
EOF
    exit $1
}

check_parameters() {
    if [[ -z "$1" ]]; then
        echo "No harvested tweets specified"
        usage 2
    fi
}

################################################################################
# FUNCTIONS
################################################################################

harvest() {
    local TFILE="$1"
    local WARC="$2"
    local LINKS="${WARC%.*}.links"
    local LOG="${WARC%.*}.log"
    local WSANS="${WARC%.*}"
    local WT="t_wget_warc_tmp_$RANDOM"
    
    rm -rf "$WT"
    mkdir -p "$WT"
    echo " - Resolving resources for $TFILE" | tee -a "$LOG"
    echo "   - Extracting links to $LINKS" | tee -a "$LOG"
    zcat -f "$TFILE" | jq -r '..|.expanded_url?, .media_url?, .media_url_https?, .profile_image_url_https?, .profile_background_image_url_https?, .profile_banner_url?' | grep -v 'null' | grep -v '^$' | grep -v '.*twitter.com/.*/status/.*' | sort | uniq > "$LINKS"
    local TCOUNT=$(wc -l < "$LINKS")
    local Q=$(( QUOTA_PER_TWEET * TCOUNT ))
    if [[ "$Q" -gt "$QUOTA_MAX" ]]; then
        Q="$QUOTA_MAX"
    fi
    if [[ "$Q" -lt "$QUOTA_MIN" ]]; then
        Q="$QUOTA_MIN"
    fi
    echo "   - wgetting $TCOUNT resources with total size limit ${Q}MB, logging to $LOG" | tee -a "$LOG"
    wget --timeout=${TIMEOUT} --directory-prefix="$WT" --input-file="$LINKS" --page-requisites --warc-file="$WSANS" --quota=${Q}m &>> "$LOG"
    rm -r "$WT"
    echo "   - Produced ${WARC}.gz ($(du -h "${WARC}.gz" | grep -o "^[0-9.]*."))" | tee -a "$LOG"
}

harvest_all() {
    for TFILE in "$@"; do
        if [[ ! -s "$TFILE" ]]; then
            echo " - Skipping $TFILE as there is no content"
            return
        fi
        
        local WARC="${TFILE%.*}"
        if [ ${WARC: -5} == ".json" ]; then
            local WARC="${WARC%.*}"
        fi
        WARC="${WARC}.warc"
        if [[ -s "$WARC" || -s "${WARC}.gz" ]]; then
            echo " - Skipping $TFILE as is is already harvested"
        else
            harvest "$TFILE" "$WARC"
        fi
    done
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
harvest_all "$@"
