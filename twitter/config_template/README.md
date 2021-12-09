# so-me twitter harvest configuration

## Description

Controls the setup for an instance of https://github.com/netarchivesuite/so-me

Curators control master files with tags & profiles. The configuration system checks for
changes and updates the local setup to use current tags & profiles as well as performing
historical searches for newly added tags and profiles.

## Files

### `credentials.sh`

Contains OAuth-tokens from Twitter. These are tied to Twitter profiles and can also be used
for posting Tweets etc., so guard them carefully. If the project is newly started, copy 
`credentials.template` to `credentials.sh` and add credential tokens to the file.

### `type_CI_filename.txt`

List of tags or profiles to harvest for the given credentials-index. The parts of the filename are

 * `type`: Only `tags` or `profiles` is supported. `tags` means a list of tags to match
 and `profiles` means a list of Twitter-handles to follow
 * `CI`: The index of the credentials to use, as specified in `credentials.sh`
 * `filename`: Used for constructing the filenames for WARCS, logs and other files


**Examples:**
 
 `tags_0_dk.txt` will harvest tweets matching the tags in the file, using the first
 credentials in the `credentials.sh` file, producing output files such as 
 `twitter_filter_dk_20211115-0600.warc.gz` and `twitter_filter_dk_20211115-0600.twarc.log`
 
 `profiles_1_politikere.txt` will follow the profiles specified in the file, using
 the second credentials specified in `credentials.sh`, producing output files such as
 `twitter_users_politikere_tweets_20211115-0700.warc.gz`
 
See the files `tags_0_dk.sample` and `profiles_1_politikere.sample` for samples.

### `type_CI_filename.current` and `type_CI_filename.old`

Created by the processing scripts to keep track of changes. Do not touch!

### `type_CI_filename.added`, `type_CI_filename.added.processed` and `type_CI_filename.removed`

Created by the processing scripts to keep track of single time harvests. Do not touch!

### `type_CI_filename.log`

Updated by the processing scripts to keep a log of the changes. The content is not used
by the scripts themselves, so manual changes are not problematic from a processing point
of view.

