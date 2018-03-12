#!/usr/bin/env bash

#
# Re-packages Twitter tweet-JSON, as delivered by twarc, into WARCs
#
# WARC-specification:
# http://iipc.github.io/warc-specifications/specifications/warc-format/warc-1.0/index.html
#
# Requirements: bash, uuidgen, jq, sha1sum, xxd, base32
#

# TODO: Add option for packing multiple tweet-collections into a single WARC.
# TODO: Generate Last-Modified: Sun, 28 Dec 2014 22:40:37 GMT^M


###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
if [[ -s "twitter.conf" ]]; then
    source twitter.conf
fi

# http://iipc.github.io/warc-specifications/specifications/warc-format/warc-1.0/index.html#warcinof
: ${WARC_OPERATOR:="The Royal Danish Library"}
: ${WARC_SOFTWARE:="Homebrew experimental"}
: ${WARC_GZ:="true"} # Whether or not to GZIP the WARC content
: ${FORCE:="false"}  # If false, any existing WARC-representation is not overwritten
popd > /dev/null

usage() {
    cat <<EOF
Re-packages Twitter tweet-JSON, as delivered by twarc, into WARCs.

Usage: ./tweets2warc.sh tweets_json*
EOF
    exit $1
}

check_parameters() {
    if [[ -z "$1" ]]; then
        echo "No Twitter API JSON files specified"
        usage 2
    fi
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

# Input file
sha1_32() {
    local FILE="$1"
    # sha1:2Z46YIFNTUYSCMYN2DMMJGKJLGE3QEAJ
    echo -n "sha1:"
    sha1sum "$FILE" | cut -d\  -f1 | xxd -r -p | base32
}

# Input String
sha1_32_string() {
    local CONTENT="$1"
    # sha1:2Z46YIFNTUYSCMYN2DMMJGKJLGE3QEAJ
    echo -n "sha1:"
    sha1sum <<< "$CONTENT" | cut -d\  -f1 | xxd -r -p | base32
}

# TODO: CRLF-separator
# http://iipc.github.io/warc-specifications/specifications/warc-format/warc-1.0/index.html#warcinfo
print_warc_header() {
    local T=$(mktemp)
    cat > "$T" <<EOF
# ${CR}
operator: ${WARC_OPERATOR}${CR}
software: ${WARC_SOFTWARE}${CR}
EOF
    cat <<EOF
WARC/1.0${CR}
WARC-Type: warcinfo${CR}
WARC-date: $(TZ=UTC date +%Y-%m-%dT%H:%M:%S)Z${CR}
WARC-Record-ID: <urn:uuid:$(uuidgen)>${CR}
Content-Type: application/warc-fields${CR}
Content-Length: $(wc -c < "$T")${CR}
${CR}
EOF
    cat "$T"
    rm "$T"
    echo "${CR}"
    echo "${CR}"
}

# Input: tweet JSON (single line)
print_tweet_warc_entry() {
    local TWEET="$1"
    
    # Generate payload. Not the single CR dividing header & record and the two CRs postfixinf the content
    # http://iipc.github.io/warc-specifications/specifications/warc-format/warc-1.0/index.html#file-and-record-model
    local TFILE=$(mktemp)
cat > "$TFILE" <<EOF    
HTTP/1.1 200 OK${CR}
Content-Type: application/json; format=twitter_tweet${CR}
Content-Length: $(bytes "$TWEET")${CR}
X-WARC-signal: twitter_tweet${CR}
${CR}
EOF
    echo "$TWEET" >> "$TFILE"

    # Resolve URL & timestamp
    local T_USER=$(jq -r .user.screen_name <<< "$TWEET")
    local T_ID=$(jq -r .id_str <<< "$TWEET")
    local URL="https://twitter.com/$T_USER/status/$T_ID"

    # "created_at": "Fri Mar 02 10:26:13 +0000 2018",
    local T_TS=$(jq -r .created_at <<< "$TWEET")
    local TIMESTAMP="$(TZ=UTZ date --date="$T_TS" +%Y-%m-%dT%H:%M:%S)Z"
    # WARC-IP-Address: 46.30.212.172

    # Generate WARC-record headers
    cat <<EOF
WARC/1.0${CR}
WARC-Type: response${CR}
WARC-Target-URI: ${URL}${CR}
WARC-Date: ${TIMESTAMP}${CR}
WARC-Payload-Digest: $(sha1_32_string "$TWEET")${CR}
WARC-Record-ID: <urn:uuid:$(uuidgen)>${CR}
Content-Type: application/http; msgtype=response; format=twitter_tweet${CR}
Content-Length: $(wc -c < ${TFILE})${CR}
${CR}
EOF
    cat "$TFILE"
    echo "${CR}"
    echo "${CR}"
}

# Input tweets.json dest.warc
warc_single() {
    local TWEETS="$1"
    local WARC="$2"
    echo " - Converting $TWEETS to $WARC"

    print_warc_header > "$WARC"
    # https://stackoverflow.com/questions/10929453/read-a-file-line-by-line-assigning-the-value-to-a-variable
    while read -r TWEET; do
        print_tweet_warc_entry "$TWEET" >> "$WARC"
    done < "$TWEETS"
}

warc_all() {
    for TFILE in "$@"; do
        if [[ ! -s "$TFILE" ]]; then
            echo " - Skipping $TFILE as there is no content"
            return
        fi
        
        local WARC="${TFILE%.*}"
        if [[ "${WARC: -5}" == ".json" ]]; then
            local WARC="${WARC%.*}"
        fi
        WARC="${WARC}.warc"
        if [[ -s "$WARC" || -s "${WARC}.gz" ]]; then
            if [[ "true" == "$FORCE" ]]; then
                echo " - Overwriting existing WARC for $TFILE as FORCE=true"
                warc_single "$TFILE" "$WARC"
            else
                echo " - Skipping $TFILE as it has already been converted"
            fi
        else
            warc_single "$TFILE" "$WARC"
        fi
    done
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"

warc_all "$@"
