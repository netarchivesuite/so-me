#!/bin/bash

#
# Expected to be started at regular intervals by cron or similar
#
#
# Important: This script relies on the CONF_FOLDER (default "config/", relative to the script location)
# containing credentials.sh and jobs files. See the "config_template/" folder for details.
# The config/ folder is not part of the standard repository as it contains Twitter credentials.
#
#

# TODO: Correct formatting of missing handles to remove faulty links

pushd ${BASH_SOURCE%/*} > /dev/null
set -o pipefail

###############################################################################
# CONFIG
###############################################################################

if [[ -s "twitter.conf" ]]; then
    source twitter.conf
fi
: ${LOG:="twitter_cron.log"}
: ${LOG_ONETIME:="twitter_ONETIME.log"}
: ${CONF_FOLDER:="config"}
: ${CREDENTIALS_FILE:="${CONF_FOLDER}/credentials.sh"}
: ${PERFORM_ONETIME:="true"} # If true, historical harvests are performed for ONETIME
: ${PERFORM_BATCH:="true"}   # If true, batch harvests are performed
: ${STATUS_PAGE:="twitter_status.html"}
: ${BEFORE:=""} # If defined, this script will be called before processing

# Used for statistics in report
: ${TOPX:="20"}
: ${TOP_FILES:="harvests/*_$(date --date="yesterday" +"%Y%m%d")-*.json.gz harvests/*_$(date +"%Y%m%d")-*.json.gz"}

# Used for status generation
STARTED_ONETIME=0
STARTED_BATCH=0

# Logs messages with timestamp. Logically it belongs under FUNCTIONS, but it is needed
# by check_parameters
log() {
    echo "$(date +%Y-%m-%dT%H:%M:%S) $1" >> "$LOG"
}
log_onetime() {
    echo "$(date +%Y-%m-%dT%H:%M:%S) $1" >> "$LOG_ONETIME"
}

fail() {
    log "Fatal error: $1"
    cat > "$STATUS_PAGE" <<EOF
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <title>Twitter harvest status</title>
</head>
<body>
<h1>Twitter harvest status</h1>
<p>Updated $(date +"%Y-%m-%d %H:%M")</p>
<h2>Fatal error: $1</h2>

<h2>Last 50 log entries</h2>
<pre>
$(tail -n 50 "$LOG" | escape)
</pre>
</body>
EOF
    exit $2
}

# Called before any processing is performed
# Typically used to fetch latest version of the job definitions
before() {
    if [[ -z "$BEFORE" ]]; then
        return
    fi
    if [[ ! -s "$BEFORE" ]]; then
        fail "The BEFORE script '$BEFORE' is not available" 13
    fi
    log "Calling BEFORE script '$BEFORE'"
    . "$BEFORE" &>> "$LOG"
}

check_parameters() {
    if [[ ! -d "$CONF_FOLDER" ]]; then
        fail "No config folder '$CONF_FOLDER'" 12
    fi
    if [[ ! -s "${CREDENTIALS_FILE}" ]]; then
        fail "Could not locate ${CREDENTIALS_FILE}" 10
    fi
    source "${CREDENTIALS_FILE}"
    if [[ ${#CREDENTIALS[@]} -eq 0 ]]; then
        fail "There were 0 credentials in ${CREDENTIALS_FILE}" 11
    fi
}

################################################################################
# FUNCTIONS
################################################################################


# Replaces newlines in the given file with , and removes all spaces. Ensures there is no trailing comma
# Input: File
commarize() {
    tr '\n' ',' < "$1" | sed -e 's/ //' -e 's/,*$//'
}

# Harvests tags or profiles stated in the given jobfile, then adds the content
# of the jobfile to ${JOB}.processed and deletes the jobfile.
#
# Input: Jobfile such as 'tags_0_dk.onetime' or 'profiles_1_politikere.onetime'
onetime_job() {
    local JOB="$1" # tags_0_dk.onetime
    local PROCESSED="${JOB}.processed"

    log "Processing onetime job '$JOB'"
    local NAME_ONLY=${JOB##*/}
    local RELEVANT=$(cut -d. -f1 <<< "$NAME_ONLY")  # tags_0_dk
    local JOBTYPE=$(cut -d_ -f1 <<< "$RELEVANT") # tags
    local CI=$(cut -d_ -f2 <<< "$RELEVANT") # 0
    local JOBNAME=$(cut -d_ -f3 <<< "$RELEVANT") # dk

    CREDS="${CREDENTIALS[$CI]}"
    if [[ -z "$CREDS" ]]; then
        fail "Could not resolve credentials with index $CI for job '$JOB'. Please check credentials.sh" 20
    fi

    if [[ "tags" == "$JOBTYPE" ]]; then
        log "Starting onetime tag based harvests for job $JOB with $(wc -l < "$JOB") entries"
        while read -r TAG; do
            if [[ "." == ".$TAG" ]]; then
                continue
            fi
            # TODO Handle https://github.com/netarchivesuite/so-me/issues/17 so that this can be collapsed
            if [[ "true" == "$PERFORM_ONETIME" ]]; then
                log "Starting onetime harvest for tag #$TAG"
                log_onetime "#$TAG"
#                echo "TWARC_OPTIONS=\"$CREDS\" ./tweet_search.sh \"#$TAG\" \"${JOBNAME}_${TAG}\" < /dev/null >> tweet_search.log 2>> tweet_search.log &\""
                TWARC_OPTIONS="$CREDS" ./tweet_search.sh "#$TAG" "${JOBNAME}_${TAG}" < /dev/null >> tweet_search.log 2>> tweet_search.log &
                STARTED_ONETIME=$((STARTED_ONETIME+1))
            else
                log "Skipping onetime harvest for tag #$TAG as PERFORM_ONETIME==$PERFORM_ONETIME"
            fi
        done < "$JOB"
        cat "$JOB" >> "$PROCESSED"
        rm "$JOB"
    elif [[ "profiles" == "$JOBTYPE" ]]; then
        log "Starting onetime profile based harvests for job $JOB with $(wc -l < "$JOB") entries"
        while read -r PROFILE; do
            if [[ "." == ".$PROFILE" ]]; then
                continue
            fi
            if [[ "true" == "$PERFORM_ONETIME" ]]; then
                log "Starting onetime harvest for profile $PROFILE"
                log_onetime "@$PROFILE"
#                echo "TWARC_OPTIONS=\"$CREDS\" ./tweet_timeline.sh \"$PROFILE\" \"${JOBNAME}_${PROFILE}\" < /dev/null >> tweet_timeline.log 2>> tweet_timeline.log &\""
                TWARC_OPTIONS="$CREDS" ./tweet_timeline.sh "$PROFILE" "${JOBNAME}_${PROFILE}" < /dev/null >> tweet_timeline.log 2>> tweet_timeline.log &
                STARTED_ONETIME=$((STARTED_ONETIME+1))
            else
                log "Skipping onetime harvest for profile #$PROFILE as PERFORM_ONETIME==$PERFORM_ONETIME"
            fi
        done < "$JOB"
        cat "$JOB" >> "$PROCESSED"
        rm "$JOB"
    else
        log "Error: Unknown job type '$JOBTYPE' for onetime job '$JOB'"
    fi
}

# Takes a list of tags or profiles and starts a time-limited streaming harvest.
#
# Input: Jobfile such as 'tags_0_dk.current' or 'profiles_1_politikere.current'
batch_job() {
    local JOB="$1" # tags_0_dk.current

    log "Processing batch job '$JOB'"
    local NAME_ONLY=${JOB##*/}
    local RELEVANT=$(cut -d. -f1 <<< "$NAME_ONLY")  # tags_0_dk
    local JOBTYPE=$(cut -d_ -f1 <<< "$RELEVANT") # tags
    local CI=$(cut -d_ -f2 <<< "$RELEVANT") # 0
    local JOBNAME=$(cut -d_ -f3 <<< "$RELEVANT") # dk

    CREDS="${CREDENTIALS[$CI]}"
    if [[ -z "$CREDS" ]]; then
        fail "Could not resolve credentials with index $CI for job '$JOB'. Please check credentials.sh" 21
    fi

    if [[ "tags" == "$JOBTYPE" ]]; then
        if [[ "true" == "$PERFORM_BATCH" ]]; then
            log "Starting batch harvest for tag job $JOB with $(wc -l < "$JOB") entries"
#            echo "TWARC_OPTIONS=\"$CREDS\" ./tweet_filter.sh \"$(commarize "$JOB")\" \"${JOBNAME}\" < /dev/null >> tweet_filter.log 2>> tweet_filter.log &\""
            TWARC_OPTIONS="$CREDS" ./tweet_filter.sh "$(commarize "$JOB")" "${JOBNAME}" < /dev/null >> tweet_filter.log 2>> tweet_filter.log &
            STARTED_BATCH=$((STARTED_BATCH+1))
        else
            log "Skipping batch harvest for tag $JOB ($(wc -l < "$JOB") entries) as PERFORM_BATCH==$PERFORM_BATCH"
        fi
    elif [[ "profiles" == "$JOBTYPE" ]]; then
        if [[ "true" == "$PERFORM_BATCH" ]]; then
            log "Starting batch harvest for profile job $JOB with $(wc -l < "$JOB") entries"
#            echo "TWARC_OPTIONS=\"$CREDS\" ./tweet_follow.sh \"$(commarize "$JOB")\" \"${JOBNAME}\" < /dev/null >> tweet_filter.log 2>> tweet_filter.log &\""
            TWARC_OPTIONS="$CREDS" ./tweet_follow.sh "$(commarize "$JOB")" "${JOBNAME}" < /dev/null >> tweet_filter.log 2>> tweet_filter.log &
            STARTED_BATCH=$((STARTED_BATCH+1))
        else
            log "Skipping batch harvest for profile $JOB ($(wc -l < "$JOB") entries) as PERFORM_BATCH==$PERFORM_BATCH"
        fi
    else
        log "Error: Unknown job type '$JOBTYPE' for batch job '$JOB'"
    fi
}

# Executes all onetime jobs and removes the logfiles
onetime_jobs() {
    local JOBS="$(find "$CONF_FOLDER" -iname "*.onetime")"
    local JOBS_COUNT="$(wc -l <<< "$JOBS")"
    if [[ "$JOBS_COUNT" -ne 0 && "." != ".$JOBS" ]]; then
        log "Executing $JOBS_COUNT onetime jobs"
        while read -r JOB; do
            if [[ "." == ".$JOB" ]]; then
                continue
            fi
            onetime_job "$JOB"
        done <<< "$JOBS"
    else
        log "Zero onetime jobs (no changes to setup since last run)"
    fi
}

# Executes all batch jobs
batch_jobs() {
    local JOBS="$(find "$CONF_FOLDER" -iname "*.current")"
    local JOBS_COUNT="$(wc -l <<< "$JOBS")"
    if [[ "$JOBS_COUNT" -ne 0 ]]; then
        log "Executing $JOBS_COUNT batch jobs"
        while read -r JOB; do
            batch_job "$JOB"
        done <<< "$JOBS"
    else
        log "Zero batch jobs (technically legal but worrying)"
    fi
}

# Removes comments and empty lines + other janitorial work to produce
# sorted newline separated tags/profiles
# Input: jobfile
clean_job_file() {
    local JOB="$1"
    grep -v "^;" < "$JOB" | tr ',' $'\n' | tr -d ' ' | grep -v "^$" | sed 's/[@#]//' | LC_ALL=c sort
}

# Processes a single job file, updating old/current and added/removed
# Input: Non-cleaned job-file
prepare_job() {
    local JOB="$1" # tags_0_dk.txt
    local BASE=${JOB%.*} # tags_0_dk
    local CURRENT="${BASE}.current"
    local OLD="${BASE}.old"
    local ADDED="${BASE}.added"
    # local PROCESSED="${BASE}.added.processed" # Not used here
    local REMOVED="${BASE}.removed"
    local ONETIME="${BASE}.onetime"

    # Normalise the job
    if [[ -s "$CURRENT" ]]; then
        mv "$CURRENT" "$OLD"
    else
        echo -n "" > "$OLD"
    fi
    clean_job_file "$JOB" > "$CURRENT"

    LC_ALL=c comm -2 -3 "$CURRENT" "$OLD" | tr -d ' ' > "$ADDED"
    LC_ALL=c comm -1 -3 "$CURRENT" "$OLD" | tr -d ' ' > "$REMOVED"
    if [[ -s "$ADDED" ]]; then
        cat "$ADDED" >> "$ONETIME"
    fi
}


JOBS_REGEXP='^.*/\(tags\|profiles\)_[0-9]\+_.*[.]txt'
# Iterates the txt-files with tags and profiles, producing both one-time and recurring jobs
prepare_jobs() {
    # Locate jobs
    local TXTS="$(find "$CONF_FOLDER" -iname "*.txt" | LC_ALL=c sort)"
    local JOBS="$(grep "$JOBS_REGEXP" <<< "$TXTS")"
    if [[ $(wc -l <<< "$TXTS") -ne $(wc -l <<< "$JOBS") ]]; then
        log "Warning: Encountered non-job txt-files in the config folder '$CONF_FOLDER':"
        log "$(grep -v "$JOBS_REGEXP" <<< "$TXTS")"
    fi
    local JOBS_COUNT="$(wc -l <<< "$JOBS")"
    if [[ "$JOBS_COUNT" -eq 0 ]]; then
        log "Zero batch jobs in $CONF_FOLDER (technically legal but worrying)"
        return
    fi
    log "Preparing $JOBS_COUNT harvest definitions from $CONF_FOLDER"

    while read -r JOB; do
        prepare_job "$JOB"
    done <<< "$JOBS"

}

escape() {
    sed -e 's/&/&amp;/g' -e 's/</&lt;/g' -e 's/>/&gt;/g'
}

last_produced() {
    pushd "$OUT_FOLDER" > /dev/null
    ls -lart | tail -n 100 | escape
    popd > /dev/null
}

# Timestamp for the latest change to files in the config folder
config_last_changed() {
   find "$CONF_FOLDER" -type f -iname "*.txt" -exec stat \{} --printf="%y\n" \; | sort -n -r | head -n 1 | grep -o "[1-9][0-9]\{3\}-[01][0-9]-[0-3][0-9] [012][0-9]:[0-6][0-9]"
} 

to_tags() {
    sed 's/\s*\([0-9]*\) \(.*\)/<tr><td>\1<\/td> <td><a href="https:\/\/twitter.com\/search?q=%23\2\&f=live">#\2<\/a><\/td><\/tr>/'
}
to_profile() {
    sed 's/\s*\([0-9]*\) \(.*\)/<tr><td>\1<\/td> <td><a href="https:\/\/twitter.com\/\2">@\2<\/a><\/td><\/tr>/'
}
to_link() {
    sed 's/\s*\([0-9]*\) \(.*\)/<tr><td>\1<\/td> <td><a href="\2">\2<\/a><\/td><\/tr>/'
}

# Output statistics from harvested tweets
all_tops() {
    cat <<EOF
<h2>Assorted statistics from the last 2 days of Twitter API harvests</h2>

<div style="width: 15em; float: left">
  <h3>Tags</h3>
    <table>
    $(TOPX=$TOPX TOPTYPE=tags ./top_twitter.sh $TOP_FILES | to_tags)
    </table>
</div>

<div style="width: 15em; float: left">
  <h3>Authors by tweets</h3>
    <table>
    $(TOPX=$TOPX TOPTYPE=authors_by_tweets ./top_twitter.sh $TOP_FILES | to_profile)
    </table>
</div>

<div style="width: 15em; float: left">
  <h3>Authors by replies</h3>
    <table>
    $(TOPX=$TOPX TOPTYPE=authors_by_replies ./top_twitter.sh $TOP_FILES | to_profile)
    </table>
</div>

  <h3 style="clear: both; padding-top: 1em">Top $TOPX links</h3>
    <table>
    $(TOPX=$TOPX TOPTYPE=links ./top_twitter.sh $TOP_FILES | to_link)
    </table>
EOF
}


create_status_page() {
    log "Creating status page at $STATUS_PAGE"
    local T=$(mktemp)
    cat > "$T" <<EOF
<html>
<head><title>Twitter harvest status</title></head>
<body>
<h1>Twitter harvest status</h1>
<p>Status updated $(date +"%Y-%m-%d %H:%M")</p>
<ul>
<li>Started batch jobs (will run for ~${RUNTIME} seconds): $STARTED_BATCH</li>
<li>Started onetime jobs (will finish when completed): $STARTED_ONETIME</li>
<li>Job definitions last updated: $(config_last_changed)</li>
</ul>
This status page is statically generated and will only update at next cron call.

Harvest setup controlled from <a href="https://github.com/kb-dk/twitter-config">twitter-config</a>.

<h2>Last 20 new tags &amp; profiles</h2>
<pre>
$(tail -n 20 "$LOG_ONETIME" | escape)
</pre>

<h2>Last 50 log entries</h2>
<pre>
$(tail -n 50 "$LOG" | escape)
</pre>

<h2>Last line with "Resolving missing handles" from twitter_handles.log</h2>
<p>These profiles has probably been abandoned or suspended. Consider removing them from the definitions, but do remember that suspensions can be temporary.</p>
<p>
<tt>$(tac twitter_handles.log | grep -m 1 "Resolving missing handles" | sed 's/\([a-zA-Z0-9_]\+\)/ <a href="https:\/\/twitter.com\/\1">\1<\/a>/g')</tt>
</p>

$(all_tops)

<h2>Last 100 produced files (from earlier runs)</h2>
<pre>
$(last_produced)
</pre>
</body>
EOF
    mv "$T" "$STATUS_PAGE"
    chmod 755 "$STATUS_PAGE"
}

###############################################################################
# CODE
###############################################################################

log "Controller script started ****************************************************"
before
check_parameters "$@"
pushd ${BASH_SOURCE%/*} > /dev/null
prepare_jobs
batch_jobs
onetime_jobs
log "All onetime- and batch-jobs activated"
create_status_page
log "Exiting controller script"
popd > /dev/null
