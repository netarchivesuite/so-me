#!/bin/bash

#
# Extracts links from tweets and harvests them to a warc-file
# The tool uses wget to do all that
#
# CONSIDER: This skips links to tweets, which might not be the correct action

###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
if [[ -s "harvest_resources.conf" ]]; then
    source harvest_resources.conf
fi
: ${QUOTA_MIN:="50"} # Minimum quota (MB) regardless of tweet count in a single tweets-file
: ${QUOTA_MAX:="500"} # Maximum quota (MB) regardless of tweet count in a single tweets-file
: ${QUOTA_PER_TWEET:="10"} # MB
: ${TIMEOUT:="60"}
: ${IMAGE_REGEXP:='.*\.(jpg|jpeg|gif|png|webp)$'}
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

# Input: File with links
prioritize() {
    local LINKS="$1"

    echo "   - Prioritizing images above all else in $LINKS"
    local T_I=$(mktemp)
    local T_R=$(mktemp)
    grep -i -E "${IMAGE_REGEXP}" "$LINKS" > "$T_I"
    grep -v -i -E "${IMAGE_REGEXP}" "$LINKS" > "$T_R"
    cat "$T_I" "$T_R" > "$LINKS"
    rm "$T_I" "$T_R"
}

# Twitter profile images as referred in the tweet JSON is in the form
# https://pbs.twimg.com/profile_images/<numeric_userid>/i4-KEH9h_normal.jpg
# Removing the '_normal'-part yields the full-size image
#
# Note: The order of the links will be changed. Call this before prioritize()
#
# Input: File with links
expand_large_profile_images() {
    local LINKS="$1"

    echo "   - Expanding profile images to full size"
    local T=$(mktemp)
    grep '.*pbs.twimg.com/profile_images/[0-9]*/.*_normal.[a-zA-Z]\+$' "$LINKS" | sed 's/_normal\(.[a-zA-Z]\+$\)/\1/' > "$T"
    cat "$LINKS" >> "$T"
    sort < "$T" | uniq > "$LINKS"
    rm "$T"
}

harvest() {
    local TFILE="$1"
    local WARC="$2"
    local WBASE="${WARC%.*}"
    local LINKS="${WBASE%.*}.links"
    local LOG="${WBASE%.*}.log"
    local WSANS="${WARC%.*}"
    local WT="t_wget_warc_tmp_$RANDOM"
    
    rm -rf "$WT"
    mkdir -p "$WT"
    echo " - Resolving resources for $TFILE" | tee -a "$LOG"
    echo "   - Extracting links to $LINKS" | tee -a "$LOG"
    zcat -f "$TFILE" | jq -r '..|.expanded_url?, .media_url?, .media_url_https?, .profile_image_url_https?, .profile_background_image_url_https?, .profile_banner_url?' | grep -v 'null' | grep -v '^$' | grep -v '.*twitter.com/.*/status/.*' | sort | uniq > "$LINKS"
    expand_large_profile_images "$LINKS"
    prioritize "$LINKS"
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
        if [[ "${WARC: -5}" == ".json" ]]; then
            local WARC="${WARC%.*}"
        fi
        WARC="${WARC}.resources.warc"
        if [[ -s "${WARC}" || -s "${WARC}.gz" ]]; then
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
