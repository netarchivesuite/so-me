# Twitter harvest, storage, index & discovery

## Prerequisites

The scripts are in `bash` and has been tested under Ubuntu. Besides the standard shell commands for this system, `jq` and `wget` are expected to be present.

The excellent tool [twarc](https://github.com/DocNow/twarc) is used for harvesting tweets. Note that `twarc` requires a Twitter account and a registration process for using Twitter apps. Thankfully this is quite simple to do. Please refer to the GitHub page for `twarc` for installation (also available under Ubuntu using `apt-get install twarc`) and registration.


## Quick start sample data

With `twarc` installed, execute `twarc search '#ok18' > ok18.json`. If no results is produced, provide a search word/tag different from `#ok18`.

This will produce the file `ok18.json` with multiple tweets, each one represented by a single line of JSON. 

## Basic statistics

The script `top_twitter.sh` performs basic statistics extraction from the JSON from Twitters API. Run the script without arguments for usage.

Example: Extracts the top-10 most active tweeters for a harvest with `TOPX=10 TOPTYPE=authors_by_tweets ./top_twitter.sh ok18.json`.


## Twitter-JSON -> WARC

The script `tweets2warc.sh` takes tweet-JSON and represents it as a WARC file.


## Linked resources

The script `./harvest_resources.sh` extracts all external links from Twitter-JSON and harvests the resources using `wget`.

Example: `./harvest_resources.sh ok18.json`.

This will produce the files
```
ok18.links
ok18.log
ok18.resources.warc.gz
```

## Harvest

The script `tweet_filter.sh` retrieves all tweets which contains one or more specified keywords. The process is streaming and does not fetch historical tweets (use `twarc search` for that).

Example: Harvest all tweets mentioning 'dkpol' or 'kvotekonge' for the next half hour: `RUNTIME=1800 ./tweet_filter.sh 'dkpol,kvotekonge'`.

Optionally, `tweet_filter.sh` can call both `tweets2warc.sh` and `harvest_resources` after tweet-collection has finished, thereby producing WARC-files readu for indexing.

## Solr-index

We use [webarchive-discovery](https://github.com/ukwa/webarchive-discovery) for indexing. This is expected to be extended to handle the JSON-output from Twitter's API.


## SolrWayback

[Solrwayback](https://github.com/netarchivesuite/solrwayback) is out-of-the-box capable of searching and showing basic information, such as a title and a date, for arbitrary content from a Solr backend with a schema compatible with `webarchive-discovery`. To get a more usable presentation, `Solrwayback` should be extended with explicit support for Twitter tweets & profiles.
