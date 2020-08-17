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

There are no established way of representing tweets that has been harvested through Twitter's API coupled to their web representation, so the choices below are local to the Royal Danish Library. The tweets are represented as separate WARC-entries. The choice was made to ensure direct coupling to Twitter's web representation with the field `WARC-Target-URI` and secondarily to fit well with WARC-indexers that typically handles multi-content records poorly.


The WARC-entry header are specified as

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

 * `URL` points to Twitter's webpage for the tweet: `https://twitter.com/$TWITTER_HANDLE/status/$TWEET_ID`
 * `TIMESTAMP` is the `.created_at`-timestamp from the tweet
 * The `format` in `Content-Type: application/http; msgtype=response; format=twitter_tweet` is a local convention, to help indexers and other tools to recognize the tweets


The HTTP-headers are specified as

```
HTTP/1.1 200 OK
Content-Type: application/json; format=twitter_tweet
Content-Length: $(bytes "$TWEET")
X-WARC-signal: twitter_tweet
```

 * `format`is the same local convention as used in the WARC-headers
 * `X-WARC-signal: twitter_tweet` signals that this is a tweet. This is also a local convention
 

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
