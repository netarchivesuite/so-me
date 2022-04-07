# Twitter harvest, storage, index & discovery

## Prerequisites

The scripts are in `bash` and has been tested under Ubuntu. Besides the standard shell commands the following tools are needed:

 * jq
 * wget 1.14 or later
 * base32
 * twarc (see below)
 * uuidgen, xxd, sha1sum, base32

The excellent tool [twarc](https://github.com/DocNow/twarc) is used for harvesting tweets. Note that `twarc` requires a Twitter account and a registration process for using Twitter apps. Thankfully this is quite simple to do. Please refer to the GitHub page for `twarc` for installation (also available under Ubuntu using `apt-get install twarc`) and registration.


## Quick start sample data

With `twarc` installed, execute `twarc search '#ok18' > ok18.json`. If no results is produced, provide a search word/tag different from `#ok18`.

This will produce the file `ok18.json` with multiple tweets, each one represented by a single line of JSON. 

## Basic statistics

The script `top_twitter.sh` performs basic statistics extraction from the JSON from Twitters API. Run the script without arguments for usage.

Example: Extracts the top-10 most active tweeters for a harvest with `TOPX=10 TOPTYPE=authors_by_tweets ./top_twitter.sh ok18.json`.

## Linked resources

The script `./harvest_resources.sh` extracts all external links from Twitter-JSON and harvests the resources using `wget`.

Example: `./harvest_resources.sh ok18.json`.

This will produce the files
```
ok18.links
ok18.wget.log
ok18.resources.warc.gz
```

## Twitter-JSON -> WARC

The script `tweets2warc.sh` takes tweet-JSON and represents it as a WARC file.

There are no established way of representing tweets that has been harvested through Twitter's API coupled to their web representation, so the choices below are local to the Royal Danish Library.

Each tweet is represented as a separate WARC-entry. The choice was made primarily to ensure direct coupling to Twitter's web representation with the field `WARC-Target-URI` and secondarily to fit well with WARC-indexers that typically handles multi-content records poorly.


WARC-info for the tweet WARC states filename and the filename of the corresponding resource WARC.
```
WARC/1.0
WARC-Type: warcinfo
WARC-date: 2021-01-21T18:16:03Z
WARC-Filename: harvests/twitter_filter_filtertest_20210121-1910.warc.gz
WARC-Record-ID: <urn:uuid:cb4dda72-a7f7-49e3-a39b-00aa5f794b41>
Content-Type: application/warc-fields
Content-Length: 184

# 
operator: The Royal Danish Library
software: tweets2warc.sh  https://github.com/netarchivesuite/so-me/
resources-warc: twitter_filter_filtertest_20210121-1910.resources.warc.gz
```


The WARC-entry headers are specified as

```
WARC/1.0
WARC-Type: response
WARC-Target-URI: ${URL}
WARC-Date: ${TIMESTAMP}
WARC-Payload-Digest: $(sha1_32_string "$TWEET")
WARC-Record-ID: <urn:uuid:$(uuidgen)>
Content-Type: application/http; msgtype=response; format=twitter_tweet
Content-Length: ${TWEET_RESPONSE_SIZE}
```
with a concrete example being
```
WARC/1.0
WARC-Type: response
WARC-Target-URI: https://twitter.com/Kelly_Stiftung/status/1352289409228550144
WARC-Date: 2021-01-21T16:18:14Z
WARC-Payload-Digest: sha1:USQMPXLUSZNJBBQUMJTKJU3HXUOZPXUO
WARC-Record-ID: <urn:uuid:ea589141-c4a0-447a-b03c-3c0b607e3f0f>
Content-Type: application/http; msgtype=response; format=twitter_tweet
Content-Length: 7889
```

 * `URL` points to Twitter's webpage for the tweet: `https://twitter.com/$TWITTER_HANDLE/status/$TWEET_ID`
 * `TIMESTAMP` is the `.created_at`-timestamp from the tweet
 * The `format` in `Content-Type: application/http; msgtype=response; format=twitter_tweet` is a local convention, to help indexers and other tools to recognize the tweets


The HTTP-headers are emulated as

```
HTTP/1.1 200 OK
Content-Type: application/json; format=twitter_tweet
Last-Modified: ${HTTP_TIMESTAMP}
Content-Length: $(bytes "$TWEET")
X-WARC-signal: twitter_tweet
```
with a concrete example being
```
HTTP/1.1 200 OK
Content-Type: application/json; format=twitter_tweet
Last-Modified: Thu, 21 Jan 2021 16:18:14 GMT
Content-Length: 7717
X-WARC-signal: twitter_tweet
```


 * `format` in `Content-Type` is the same local convention as used in the WARC-headers
 * `HTTP_TIMESTAMP` is the timestamp from `.created_at` in the tweet, same as for the WARC-header, but formatted [according to the HTTP standard](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Last-Modified)
 * `X-WARC-signal: twitter_tweet` signals that this is a tweet. This is also a local convention
 

## Metadata WARC

`tweets2warc.sh` also produces a metadata WARC, containing scripts and logs from the harvest of the tweets. Its WARC info is
```
WARC/1.0
WARC-Type: warcinfo
WARC-date: 2021-01-21T18:16:35Z
WARC-Filename: harvests/twitter_filter_filtertest_20210121-1910.metadata-1.warc.gz
WARC-Record-ID: <urn:uuid:3ca958a9-cf0f-4ac7-aca4-353fcf40feae>
Content-Type: application/warc-fields
Content-Length: 246

# 
operator: The Royal Danish Library
software: tweets2warc.sh  https://github.com/netarchivesuite/so-me/
tweets-warc: twitter_filter_filtertest_20210121-1910.warc.gz
resources-warc: twitter_filter_filtertest_20210121-1910.resources.warc.gz
```
Note the `tweets-warc` and `resources-warc` that connects it to the content WARCs.

When called from `tweet_filter.sh` or `tweet_follow.sh`, the records will be
 * The log from `twarc`
 * The links extracted from the tweets, which are used as seed for `wget`
 * The log from `wget`
 * The scripts used for processing
 * The configuration for the scripts
 * (Depending on setup) The cron script starting the harvest. This includes all Twitter tags and handles that are used as argument to `tweet_filter.sh` and `tweet_follow.sh`
 * (Optionally) The raw JSONL stream output from the Twitter API

A sample record is
```
WARC/1.0
WARC-Record-ID: <urn:uuid:0a9f0d3a-0045-4eb5-a54b-036f88eea286>
WARC-Date: 2021-01-21T18:12:01Z
WARC-Type: resource
WARC-Target-URI: metadata://netarkivet.dk/twitter-api?tool=twarc&output=log&job=filter&harvestTime=20210121-1910
WARC-Payload-Digest: sha1:4LXKJ5BHYIXDWX2NGF3NRQR6Z3D72QJX
WARC-Warcinfo-ID: <urn:uuid:cb4dda72-a7f7-49e3-a39b-00aa5f794b41>
Content-Type: text/plain ; twarc log
Content-Length: 12668
```
where the `uuid` for `WARC-Warcinfo-ID` refers to the tweet WARC info record.


## Binding it together

The script `tweet_filter.sh` retrieves all tweets which contains one or more specified keywords. The process is streaming and does not fetch historical tweets (use `tweet_search.sh` for that).

Example: Harvest all tweets mentioning 'dkpol' or 'kvotekonge' for the next half hour: `RUNTIME=1800 ./tweet_filter.sh 'dkpol,kvotekonge'`.

Optionally, `tweet_filter.sh` can call both `tweets2warc.sh` and `harvest_resources` after tweet-collection has finished, thereby producing WARC-files ready for indexing.

The script `tweet_follow.sh` retrieves all tweets from the given Twitter handles. Otherwise it acts as `tweet_filter.sh`.

The scripts `tweet_search.sh` searches the Twitter archive (7 days max with free account) and `tweet_timeline.sh` outputs a timeline for at given Twitter handle.

### Harvest setup sample

The script `cron_job_sample.sh` demonstrates harvests using Danish politica-related tags and Danish persons that often tweets on politics. It is meant to be called once an hour from `cron` or similar and will produce both raw JSON filed with tweets and valid WARC-files. The resources (embedded images, profile pictures, linked webpages and their embedded resources) are also harvested.

The tags and persons are chosen by bootstrapping with `dkpol`, `dkgreen` and a few other commonly used Danish tags on politics. After a few initial harvests, the top-20 tags and handles were extracted (and manually pruned for noise) and the harvest-setup extended with these. This was repeated 2-3 times. The tags and handles selection should not be seen as authoritative in any way.


## Solr-index

We use [webarchive-discovery](https://github.com/ukwa/webarchive-discovery) for indexing. This is expected to be extended to handle the JSON-output from Twitter's API.


## SolrWayback

[Solrwayback](https://github.com/netarchivesuite/solrwayback) is out-of-the-box capable of searching and showing basic information, such as a title and a date, for arbitrary content from a Solr backend with a schema compatible with `webarchive-discovery`. To get a more usable presentation, `Solrwayback` should be extended with explicit support for Twitter tweets & profiles.

## Misc. notes

There is no reply-count in the free Twitter API. There seems to be in the premium API: https://twittercommunity.com/t/reply-count/78367/11

The website https://twitterpolitikere.dk/ seems like a nice place for inspiration for Twitter harvests. See for example their list of top-1000 Danish politiacians by followers:

```
curl -s 'https://filip.journet.sdu.dk/twitter/politikere/' | grep '<h3>#[0-9]* @<' | sed 's/.*twitter.com\/\([^"]*\)".*/\1/'
```

Experiment with GEO-search (centered on Odder):
```
twarc search --geocode 55.878227,10.185354,100mi > geodk.json
```

Experiment with GEO-filter (Denmark bounding box):
```
twarc filter --location "8.08997684086,54.8000145534,12.6900061378,57.730016588" > dkgeo_filter_20200616-1547.json
```
