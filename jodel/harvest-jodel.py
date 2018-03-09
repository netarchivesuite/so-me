#!/usr/bin/env python2

import sys
import jodel_api
import json
import pprint
pp = pprint.PrettyPrinter(indent=4)


# Read input parameters
lat = sys.argv[1]
lng = sys.argv[2]
city = sys.argv[3]
access_token = sys.argv[4]
expiration_date = sys.argv[5]
refresh_token = sys.argv[6]
distinct_id = sys.argv[7]
device_uid = sys.argv[8]

account = jodel_api.JodelAccount(lat=lat, lng=lng, city=city, access_token=access_token, expiration_date=expiration_date, refresh_token=refresh_token, distinct_id=distinct_id, device_uid=device_uid, is_legacy=True)

# TODO make empty alive_posts (i.e. array of post_id + timestamp pairs)
# ...

# Get most recent posts
recent = account.get_posts_recent(skip=0, limit=60, after=None, mine=False, hashtag=None, channel=None)

recent_posts = recent[1]['posts']

for post in recent_posts:
    post_id = post['post_id']

    # Download the thread
    #post_details = account.get_post_details_v3(post_id, skip=0)[1]

    #pp.pprint(post_details)



###voorhees = json.dumps(recent)
###print voorhees

