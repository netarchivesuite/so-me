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
