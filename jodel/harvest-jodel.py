#!/usr/bin/env python2

import sys
import jodel_api
import json
import time
import datetime
from datetime import date
from datetime import datetime
import uuid

import pprint
pp = pprint.PrettyPrinter(indent=4)


###############################################################################
# CONFIG
###############################################################################

NUM_OF_RECENT_POSTS_TO_HARVEST = 10
SECONDS_BETWEEN_EACH_HARVEST = 10


###############################################################################
# FUNCTIONS & CLASSES
###############################################################################

class WronglyFormattedJodelTime(Exception):
    pass


def convert_to_json(post_details):
    post_details_as_json = ''
    # TODO
    return post_details_as_json


def get_updated_at_date(post_details):
    d = post_details['details']['updated_at']
    if (d[4:5] != '-' or d[7:8] != '-' or d[10:11] != 'T' or d[13:14] != ':'
        or d[16:17] != ':' or d[19:20] != '.' or d[23:24] != 'Z'):
        raise WronglyFormattedJodelTime(d)
    return d[0:19] + 'Z'


class Warc:
    def __init__(self):
        # Bulk is eeeeeverything that is in a warc file
        self.bulk = ''
        return


    def append_warc_header(self):
        self.bulk += "WARC/1.0\r\n"
        self.bulk += "WARC-Type: warcinfo\r\n"

        self.bulk += "WARC-date: "
        right_now = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
        self.bulk += str(right_now) + "\r\n"

        self.bulk += "WARC-Record-ID: <urn:uuid:" + str(uuid.uuid4()) + ">\r\n"

        self.bulk += "Content-Type: application/warc-fields\r\n"

        self.bulk += "Content-Length: 73\r\n"
        self.bulk += "\r\n"
        self.bulk += "#\r\n"
        self.bulk += "operator: The Royal Danish Library\r\n"
        self.bulk += "software: Homebrew experimental\r\n"
        return


    def append_thread(self, post_details):
        self.bulk += "\r\n"
        self.bulk += "\r\n"

        self.bulk += "WARC/1.0\r\n"
        self.bulk += "WARC-Type: response\r\n"

        # TODO
        self.bulk += "WARC-Target-URI: http://TODO-INSERT-HERE.com\r\n"

        self.bulk += "WARC-Date: "
        self.bulk += get_updated_at_date(post_details) + "\r\n"


        self.bulk += ""
        self.bulk += "\r\n"


        # TODO
        return


    def output_to_stdout(self):
        print self.bulk
        # TODO
        return


###############################################################################
# CODE
###############################################################################

# Read input parameters
lat = sys.argv[1]
lng = sys.argv[2]
city = sys.argv[3]
access_token = sys.argv[4]
expiration_date = sys.argv[5]
refresh_token = sys.argv[6]
distinct_id = sys.argv[7]
device_uid = sys.argv[8]

account = jodel_api.JodelAccount(lat=lat, lng=lng, city=city,
        access_token=access_token, expiration_date=expiration_date,
        refresh_token=refresh_token, distinct_id=distinct_id,
        device_uid=device_uid, is_legacy=True)

# Dictionary with post_id as key and timestamp as value.
# Alive posts are posts that had not been deleted(via downvotes/deletion) or
# been pushed out through the bottom of our "main-feed-harvest-window" when we
# last harvested
alive_posts = {}


while True:
    warc = Warc()
    warc.append_warc_header()

    # Get most recent posts
    recent = account.get_posts_recent(skip=0,
            limit=NUM_OF_RECENT_POSTS_TO_HARVEST, after=None, mine=False,
            hashtag=None, channel=None)
    recent_posts = recent[1]['posts']

    # For building the dict of alive posts for next harvest
    next_alive_posts = {}

    for post in recent_posts:
        post_id = post['post_id']

        # When post was last updated
        updated_at = post['updated_at']

        if post_id in alive_posts:
            # Thread was harvested last time
            previously_updated_at = alive_posts[post_id]

            if previously_updated_at == updated_at:
                # Thread was not updated since last harvest, it just survives
                post_details = None
            else:
                # Thread has been updated since last harvest, so dl it
                post_details = account.get_post_details_v3(post_id, skip=0)[1]
        else:
            # Thread was not dl'ed last time, i.e. it is new, so dl the thread
            post_details = account.get_post_details_v3(post_id, skip=0)[1]

        # For checking recent posts against next time
        next_alive_posts[post_id] = updated_at

        if post_details is not None:
            # Export the thread as json
            #pp.pprint(post_details)
            warc.append_thread(post_details)
            print('..................')

            # FOR TESTING
            msg = post['message']
            pp.pprint(msg[:10])
            #pp.pprint(post['child_count'])

    warc.output_to_stdout()

    alive_posts = next_alive_posts
    print('--------------------')
    time.sleep(SECONDS_BETWEEN_EACH_HARVEST)





# Se https://docs.python.org/2/tutorial/datastructures.html
#    https://github.com/netarchivesuite/so-me

###voorhees = json.dumps(recent)
###print voorhees

