# so-me
Social Media harvests

Scripts for handling data from social media networks using APIs, as opposed to www-based harvesting. The common goal is to

* Harvest posts and pack them as WARCs
* Harvest resources referenced by posts (images, webpages)
* Index is all into Solr using [webarchive-discovery](https://github.com/ukwa/webarchive-discovery)
* Provide discovery with [Solrwayback](https://github.com/netarchivesuite/solrwayback)

## Twitter

[Twitter](https://twitter.com/) is characterized by persistent users, loose coupling of subjects with hashtags, strong inter-post references (retweets, replies) and unlimited historical recall (unless posts are deleted by their author).

Tweets are harvested using [twarc](https://github.com/DocNow/twarc), while resources are harvested and WARC-packed using [Wget tool](https://www.gnu.org/software/wget/).

## Jodel

[Jodel](https://jodel-app.com/) is a new social network with a strong user base in Denmark. It is characterized by anonymity, locality and recentness. It is made up of fully public independent posts, each with a non-branching comment track.


## Full guide

### Basic install

Install webarchive-discovery
```
git clone https://github.com/netarchivesuite/webarchive-discovery.git
pushd webarchive-discovery/
git checkout solrconfig
cp -r warc-indexer/src/main/solr/solr7/ ../so-me_solr7_config
git checkout some
mvn package -DskipTests
popd
```
There should now be a JAR redy for use. Verify with
```
ll  webarchive-discovery/warc-indexer/target/warc-indexer*jar-with-dependencies.jar*
```


SolrCloud
```
git clone https://github.com/tokee/solrscripts.git
solrscripts/cloud_install.sh 7.2.1
solrscripts/cloud_start.sh 7.2.1
solrscripts/cloud_sync.sh 7.2.1 so-me_solr7_config/discovery/conf/ so-me.conf some
```
There should now be a Solr running with an empty `some`-collection. Verify by visiting [http://localhost:9000/solr/#/some/collection-overview](http://localhost:9000/solr/#/some/collection-overview).

SolrWayback
```
git clone https://github.com/netarchivesuite/solrwayback.git
pushd solrwayback
mvn package -DskipTests

```

[ ] Finish guide


### Twitter data

Full guide in [twitter README](twitter/README.md).

Get some JSON tweets by either searching backwards in time
```
twarc search 'horses,ponies' > equidae.json
```
or filter 10 minutes forward
```
RUNTIME=600 twitter/tweet_filter.sh 'horses,ponies' 'equidae'
```

Convert the Twitter JSON to WARC
```
twitter/tweets2warc.sh equidae.json
```

Harvest the linked resources
```
twitter/harvest_resources.sh equidae.json
```

You now have `equidae.warc` and `equidae.resources.warc.gz`.


### Jodel

[ ] Write guide


