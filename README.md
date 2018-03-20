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

Tools
```
sudo apt-get install twarc jq wget
```
Visit [twarc](https://github.com/DocNow/twarc) and follow the instructions for acquiring and configuring Twitter API keys for twarc. It takes a few minuts and requires a Twitter account. Without this, no Twitter harvest.

Ensure that Java 1.8 is installed.


webarchive-discovery
```
git clone https://github.com/netarchivesuite/webarchive-discovery.git
pushd webarchive-discovery/
git checkout solrconfig
cp -r warc-indexer/src/main/solr/solr7/ ../so-me_solr7_config
git checkout some
git merge origin/WARCTargetURI -m "Custom build"
sed 's%"normalise" *: *[a-z]\+,%"normalise": true,%' -i warc-indexer/src/main/resources/reference.conf 
mvn package -DskipTests
popd
```
There should now be a JAR ready for use. Verify with
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


Tomcat (for running SolrWayback)
```
mkdir tomcat
curl 'http://mirrors.dotsrc.org/apache/tomcat/tomcat-8/v8.5.29/bin/apache-tomcat-8.5.29.tar.gz' | tar -xzo --strip-components=1 -C tomcat
tomcat/bin/startup.sh
```
There should now be a tomcat running. Verify by visiting [http://localhost:8080/](http://localhost:8080/).


SolrWayback
```
git clone https://github.com/netarchivesuite/solrwayback.git
pushd solrwayback
mvn package -DskipTests
popd

cp solrwayback/src/test/resources/properties/solrwayback.properties ~/
sed -e 's%proxy.port=.*%proxy.port=9010%' -e 's%solr.server=.*%solr.server=http://localhost:9000/solr/some/%' -e 's%wayback.baseurl=.*%wayback.baseurl=http://localhost:8080/solrwayback/%' -i ~/solrwayback.properties 

cp solrwayback/target/test-classes/properties/solrwaybackweb.properties ~/
sed 's%wayback.baseurl=.*%wayback.baseurl=http://localhost:8080/solrwayback/%' -i ~/solrwaybackweb.properties 

cp solrwayback/target/solrwayback-3.1-SNAPSHOT.war tomcat/webapps/solrwayback.war
```
SolrWayback should now be running in Tomcat. Verify by visiting [http://localhost:8080/solrwayback/](http://localhost:8080/solrwayback/) and issuing a search for `*:*` which should give 0 results and no errors.


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

Harvest the linked resources (might take 10 minutes or so)
```
twitter/harvest_resources.sh equidae.json
```

You now have `equidae.warc` and `equidae.resources.warc.gz`.


### Jodel

[ ] Write guide

### Index WARCs

Index the WARCs harvested from Twitter & Jodel with
```
java -Xmx1g -jar webarchive-discovery/warc-indexer/target/warc-indexer*jar-with-dependencies.jar* -s http://localhost:9000/solr/some equidae*.warc*
```
Solr should now contain tweets, jodels, images and linked resources. Verify by issuing a search in [http://localhost:8080/solrwayback/](http://localhost:8080/solrwayback/).

