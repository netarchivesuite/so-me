#!/bin/bash

#
# Proof Of Concept harvester of YouTube pages, videos & metadata
#
# Requirements: bash, uuidgen, sha1sum, xxd, base32, wget, youtube-dl, youtube-comment-downloader
#

# TODO: Consider using CDX to avoid duplicates

###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
if [[ -s "youtube.conf" ]]; then
    source "youtube.conf"     # Local overrides
fi
: ${URLS:=$@}
: ${URL_FILE:="$2"}
: ${USE_URL_FILE:=$( if [[ ".$1" == ".-f" ]]; then echo "true"; else echo "false"; fi)}
: ${WARC:="$(pwd)/youtube_$(date +%Y%m%d-%H%M)"} # .warc is automatically appended
: ${MAP:="${WARC}.map.csv"} # YouTube-URL Movie info comments subtitles*
: ${DELAY:="1.3"}  # Delay in seconds between each harvest
: ${TIMEOUT:="60"} # wget timeout in seconds
: ${LOG:="$(pwd)/youtube_harvest.log"}
: ${COMMENT_DOWNLOADER:="$(pwd)/youtube-comment-downloader/downloader.py"}
: ${DEBUG:="false"} # true == don't delete the temporary folder for YouTube-data
popd > /dev/null

usage() {
    echo "Usage: ./youtube_harvest.sh ( [-f url_list_file] | url* )"
    exit $1
}

out() {
    echo "$1" | tee -a "$LOG"
}

error() {
    >&2 echo "$1"
    echo "$1" >> "$LOG"
}

check_parameters() {
    if [[ ! -s "$COMMENT_DOWNLOADER" ]]; then
        >&2 echo "Error: $COMMENT_DOWNLOADER not available"
        >&2 echo "Refer to README.md for instructions on installing"
        usage 10
    fi
    if [[ "." == .$(which "youtube-dl") ]]; then
        >&2 echo "Error: youtube-dl not available"
        >&2 echo "Refer to README.md for instructions on installing"
        usage 11
    fi
    if [[ "true" == "$USE_URL_FILE" && ! -s "$URL_FILE" ]]; then
        >&2 echo "Error: Could not read url_list_file '$URL_FILE'"
        usage 2
    fi

    if [[ "false" == "$USE_URL_FILE" && -s "$URLS" && $(grep -o " " <<< "$URLS" | wc -l) -eq 0 ]]; then
        out "Note: Assuming -f as there are only one argument '$URLS' which exists on the file system"
        URL_FILE="$URLS"
        USE_URL_FILE="true"
    fi
    
    echo "# Date Youtube-URL Video-URL metadata comments subtitles*" >> "$MAP"

    # We need those for WARCs
    CR=$(printf '\x0d')
    HT=$(printf '\x09')
}

################################################################################
# FUNCTIONS
################################################################################

# Input: String
# Output: Number of bytes (not number of characters)
bytes() {
    local TEXT="$1"
    LANG=C LC_ALL=C echo "${#TEXT}"
}

# Input String
sha1_32_string() {
    local CONTENT="$1"
    # sha1:2Z46YIFNTUYSCMYN2DMMJGKJLGE3QEAJ
    echo -n "sha1:"
    sha1sum <<< "$CONTENT" | cut -d\  -f1 | xxd -r -p | base32
}
# Adds a record to a WARC, taking care of headers, checksums etc.
#
# Input: file WARC-Entry-URL Content-Type [Related-Record-ID]
add_file() {
    local FILE="$1"
    local URL="$2"
    local CONTYPE="$3"
    local RELATED="$4"
    if [[ "." != ".$RELATED" ]]; then
        RELATED="Related-Record-ID: $RELATED$CR"$'\n'
    fi
    
    if [[ ! -s "$FILE" ]]; then
        out "     - Note: File '$FILE' requested for WARC inclusion not available"
        return
    fi
    
    out "    - Adding $FILE to WARC as $(head -c 50 <<< "$URL")..."

    # Generate payload. Note the single CR dividing header & record and the two CRs postfixinf the content
    # http://iipc.github.io/warc-specifications/specifications/warc-format/warc-1.0/index.html#file-and-record-model
    local TFILE=$(mktemp)
    cat > "$TFILE" <<EOF    
HTTP/1.1 200 OK${CR}
Content-Type: ${CONTYPE}${CR}
Content-Length: $(wc -c < "$FILE")${CR}
X-WARC-signal: youtube_resource${CR}
${CR}
EOF
    cat "$FILE" >> "$TFILE"

    # "created_at": "Fri Mar 02 10:26:13 +0000 2018",
    local TIMESTAMP="$(TZ=UTZ date +%Y-%m-%dT%H:%M:%S)Z"
    # WARC-IP-Address: 46.30.212.172
    
    # Generate WARC-record headers
    cat >> "${WARC}.warc" <<EOF
WARC/1.0${CR}
WARC-Type: response${CR}
WARC-Target-URI: ${URL}${CR}
WARC-Date: ${TIMESTAMP}${CR}
WARC-Payload-Digest: $(sha1_32_string "$TFILE")${CR}
WARC-Record-ID: <urn:uuid:$(uuidgen)>${CR}${RELATED}
Content-Type: application/http; msgtype=response${CR}
Content-Length: $(wc -c < ${TFILE})${CR}
${CR}
EOF
    cat "$TFILE" >> "${WARC}.warc"
    echo "${CR}" >> "${WARC}.warc"
    echo "${CR}" >> "${WARC}.warc"
    rm "$TFILE"
}

# Resolves WARC-Record-ID from WARC for use with Related-Record-ID
# Input: WARC-Target-URI
get_record_id() {
    local URI="$2"
    grep -a -A 10 "WARC-Type: response" "${WARC}.warc" | grep -a -B 5 "WARC-Target-URI: .*<\?$URI>\?" | grep "WARC-Record-ID" | cut -d\  -f2 | sed -e 's/<urn://' -e 's/>//'
}

# Add YouTube video and extra data to WARC
#
# Input: YouTube-URL Video-ID Video-URL
add_video_and_metadata() {
    local URL="$1"
    local VID="$2"
    local VURL="$3"

    local TIMESTAMP="$(TZ=UTZ date +%Y-%m-%dT%H:%M:%S)Z"

    out "  - Adding data for $URL to WARC"
    
    local PAGE_ID=$(get_record_id "$URL")
    if [[ "." == ".$PAGE_ID" ]]; then
        >&2 echo "Warning: Unable to locate WARC-Record-ID for YouTube page '$URL' in '${WARC}.warc'. Related-Record-ID will not be set for video file"
    fi
    add_file "${VID}.mkv" "$VURL" "video/x-matroska" "$PAGE_ID"
    add_file "${VID}.info.json" "$URL/${VID}.info.json" "application/json" "$PAGE_ID"
    add_file "${VID}.comments.json" "$URL/${VID}.comments.json" "application/json" "$PAGE_ID"

    echo -n "$TIMESTAMP $URL $VURL $URL/${VID}.info.json $URL/${VID}.comments.json" >> "$MAP"

    local VIDEO_ID=$(get_record_id "$VURL")
    if [[ "." == ".$PAGE_ID" ]]; then
        >&2 echo "Warning: Unable to locate WARC-Record-ID for YouTube video '$VURL' in '${WARC}.warc'. Related-Record-ID will not be set for metadata and sub-titles"
    fi
    for SUB in ${VID}.*.vtt; do
        # TODO: Consider if this should be referenced to the page and not the video
        # Remember that subtitles are also embedded in the video
        add_file "$SUB" "$URL/$SUB" "text/vtt" "$VIDEO_ID"
        if [[ -s "$SUB" ]]; then
            echo -n " $URL/$SUB" >> "$MAP"
        fi
    done
    echo "" >> "$MAP"
}

# Input: YouTube-URL
harvest_pages() {
    local URL_FILE="$1"
    local WT="t_wget_warc_tmp_$RANDOM"
    out " - Harvesting $(grep -v "^#" "$URL_FILE" | grep -v "^$" | wc -l) web pages with embedded resources as listed in $URL_FILE"
    wget --no-verbose --timeout=${TIMEOUT} --directory-prefix="$WT" --input-file="$URL_FILE" --page-requisites --warc-file="$WARC" &>> "$LOG"
    rm -rf "$WT"
}

# Harvest youTube page with resources, YouTube video (Matroska container), video metadata,
# comments and subtitles (is present)
#
# Input: YouTube-URL
harvest_single() {
    local URL="$1"

    out " - Fetching video and metadata for $URL"
    local TDOWN="t_youtube_data_$RANDOM"
    mkdir -p "$TDOWN"
    pushd "$TDOWN" > /dev/null
    
    local VID=$(cut -d= -f2 <<< "$URL")
    local VURL=$(youtube-dl -g -f bestvideo+bestaudio "$URL" | head -n 1)
    out "    - Resolved temporary video URL $(head -c 50 <<< "$VURL")..."
    out "    - Downloading video, metadata and optional subtitles for $URL"
    youtube-dl -q -o $VID -k --write-info-json -f bestvideo+bestaudio --all-subs --embed-subs --add-metadata --recode-video mkv "$URL" &>> "$LOG"
    if [[ ! -s "${VID}.mkv" ]]; then
        error "Error: Unable to resolve video from page ${URL}. Leaving temporary folder $(pwd)"
        popd > /dev/null
        return
    fi

    out "    - Downloading comments for Video-ID $VID"
    $COMMENT_DOWNLOADER --youtubeid ${VID} --output ${VID}.comments.json &>> "$LOG"
    add_video_and_metadata "$URL" "$VID" "$VURL"
    
    popd > /dev/null
    if [[ ".true" != ".$DEBUG" ]]; then
        rm -r "$TDOWN"
    else
        out "    - Keeping folder with YouTube data for $VID ad DEBUG == true"
    fi
}

# Iterate all given URLs and harvest the data from them
harvest_all() {
    local TURLS=$(mktemp)
    if [[ "true" != "$USE_URL_FILE" ]]; then
        tr ' ' '\n' <<< "$URLS" > "$TURLS"
        URL_FILE="$TURLS"
    else
        out "Reading URLs from '$URL_FILE'"
    fi
    harvest_pages "$URL_FILE"

    out " - Fetching videos and metadata"
    while read -r URL; do
        if [[ ".$URL" == "." || ${URL:0:1} == "#" ]]; then
            continue
        fi
        harvest_single "$URL"
    done < "$URL_FILE"
    rm -rf "$TURLS"
    out "Finished processing. Result stored in ${WARC}.warc"
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
pushd ${BASH_SOURCE%/*} > /dev/null
harvest_all
popd > /dev/null
