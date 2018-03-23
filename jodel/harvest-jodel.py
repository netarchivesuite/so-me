#!/usr/bin/env python2
# https://github.com/netarchivesuite/so-me

import base64
import datetime
from datetime import date, datetime, timedelta
import hashlib
import jodel_api
import json
from subprocess import call
import sys
import time
import uuid


###############################################################################
# FUNCTIONS & CLASSES
###############################################################################

class WronglyFormattedJodelTime(Exception):
    pass


def get_sha1_base32(inner_content):
    sha1_eater = hashlib.sha1()
    sha1_eater.update(inner_content)

    digest = sha1_eater.digest()
    sha1_in_base32 = base64.b32encode(digest)
    return sha1_in_base32


def get_updated_at_date(post_details):
    d = post_details['details']['updated_at']
    if (d[4:5] != '-' or d[7:8] != '-' or d[10:11] != 'T' or d[13:14] != ':'
        or d[16:17] != ':' or d[19:20] != '.' or d[23:24] != 'Z'):
        raise WronglyFormattedJodelTime(d)
    return d[0:19] + 'Z'


def get_warc_inner_record(inner_content):
    warc_rec = "HTTP/1.1 200 OK\r\n"
    warc_rec += "Content-Type: application/json; format=jodel_thread\r\n"
    warc_rec += "Content-Length: " + str(len(inner_content)) + "\r\n"
    warc_rec += "X-WARC-signal: jodel_thread\r\n"
    warc_rec += "\r\n"
    warc_rec += inner_content
    return warc_rec


class Warc:
    def __init__(self):
        # Bulk is eeeeeverything that is in a warc file
        self.bulk = ''
        return


    def append_warc_header(self, harvest_start_time_utc):
        self.bulk += "WARC/1.0\r\n"
        self.bulk += "WARC-Type: warcinfo\r\n"

        self.bulk += "WARC-date: " + str(harvest_start_time_utc) + "\r\n"
        self.bulk += "WARC-Record-ID: <urn:uuid:" + str(uuid.uuid4()) + ">\r\n"
        self.bulk += "Content-Type: application/warc-fields\r\n"

        self.bulk += "Content-Length: 73\r\n"
        self.bulk += "\r\n"
        self.bulk += "# \r\n"
        self.bulk += "operator: The Royal Danish Library\r\n"
        self.bulk += "software: Homebrew experimental\r\n"
        self.bulk += "\r\n"
        self.bulk += "\r\n"
        return


    def append_thread(self, post_details, share_url, lat, lng, city):
        # Inject latitude, longitude, and city into the Python datastructure
        post_details['harvester_info'] = {'latitude':str(lat),
                'longitude':str(lng), 'city':str(city),
                'share_url':str(share_url)}

        self.bulk += "WARC/1.0\r\n"
        self.bulk += "WARC-Type: response\r\n"

        self.bulk += "WARC-Target-URI: " + str(share_url) + "\r\n"

        self.bulk += "WARC-Date: "
        self.bulk += str(get_updated_at_date(post_details)) + "\r\n"

        self.bulk += "WARC-Payload-Digest: "
        voorhees = json.dumps(post_details) + "\n"
        self.bulk += "sha1:" + get_sha1_base32(voorhees) + "\r\n"

        self.bulk += "WARC-Record-ID: <urn:uuid:" + str(uuid.uuid4()) + ">\r\n"
        self.bulk += "Content-Type: application/http; msgtype=response\r\n"

        warc_rec = get_warc_inner_record(voorhees)
        self.bulk += "Content-Length: " + str(len(warc_rec)) + "\r\n"
        self.bulk += "\r\n"
        self.bulk += warc_rec
        self.bulk += "\r\n"
        self.bulk += "\r\n"
        return


    def dump_to_file(self, city, harvest_start_time_for_filename):
        assert(type(self.bulk) == str)

        time = str(harvest_start_time_for_filename)

        filepath = "harvests/jodel_" + city + "_" + time + ".warc"
        file = open(filepath, "w")
        file.write(self.bulk)
        file.close()
        return


class ImageUrlList:
    def __init__(self):
        # Image urls, each on a separate line
        self.image_urls = ''
        self.we_got_images = False
        return


    def append_image_urls(self, post_details):
        if str(post_details['details']['image_approved']).lower() == "true":
            # OJ-post has an image
            url = "http:" + post_details['details']['image_url']
            self.image_urls += str(url) + "\n"
            self.we_got_images = True

        replies = post_details['replies']
        for reply in replies:
            if str(reply['image_approved']).lower() == "true":
                # Reply has an image
                url = "http:" + reply['image_url']
                self.image_urls += str(url) + "\n"
                self.we_got_images = True
        return


    def dump_to_file(self, city, harvest_start_time_for_filename):
        assert(type(self.image_urls) == str)

        time = str(harvest_start_time_for_filename)

        filebase = "jodel_" + city + "_" + time + "_images"
        file = open('harvests/image-temp-' + city + '/' + filebase + '.txt',
                'w')
        file.write(self.image_urls)
        file.close()
        return filebase


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
num_of_recent_posts_to_harvest = int(sys.argv[9])
seconds_between_each_harvest = float(sys.argv[10])

# TODO instead, make it so that this program can be called as:
# ./harvest-jodel.py configs/Aarhus-config.sh "$num_of_recent_posts_to_harvest" "$seconds_between_each_harvest"
# in that way making harvest-jodel.sh simpler.

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
    image_url_list = ImageUrlList()

    start_time = time.time()

    # Start generation of warc file
    harvest_start_time_utc = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    warc.append_warc_header(harvest_start_time_utc)
    threads_were_added_to_this_warc = False

    # Get harvest start-time for filename
    t = harvest_start_time_utc  # Example: "2018-03-13T11:27:29Z"
    yyyymmdd = t[0:4] + t[5:7] + t[8:10]
    hhmmss = t[11:13] + t[14:16] + t[17:19]
    harvest_start_time_for_filename = yyyymmdd + "_" + hhmmss

    # Get most recent posts
    recent = account.get_posts_recent(skip=0,
            limit=num_of_recent_posts_to_harvest, after=None, mine=False,
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
            share_url = 'https://share.jodel.com/post?postId=' + post_id
            # Add the jodel-thread (as a warc-record) to current warc file
            warc.append_thread(post_details, share_url, lat, lng, city)
            threads_were_added_to_this_warc = True

            # Collect any image-urls in the thread to harvest at the end
            image_url_list.append_image_urls(post_details)

    # Finish and export current warc file
    if threads_were_added_to_this_warc:
        warc.dump_to_file(city, harvest_start_time_for_filename)

        if image_url_list.we_got_images:
            # Harvest collected images
            call(['bash', '-c',
                'mkdir ./harvests/image-temp-' + city + ' 2>/dev/null'])
            call(['bash', '-c',
                'mkdir ./harvests/image-temp-' + city +
                '/wget-warc-temp 2>/dev/null'])
            filebase = image_url_list.dump_to_file(city,
                    harvest_start_time_for_filename)
            call(['wget', '-q', '--level=0', '--warc-cdx', '--page-requisites',
                '--directory-prefix=harvests/image-temp-' + city
                + '/wget-warc-temp/',
                '--warc-file=harvests/image-temp-' + city + '/' + filebase,
                '--warc-max-size=1G',
                '-i', 'harvests/image-temp-' + city + '/' + filebase + '.txt'])

            # Cleanup garbage-files generated by wget
            call(['bash', '-c',
                'rm ./harvests/image-temp-' + city +
                '/*-meta.warc.gz 2>/dev/null'])
            call(['bash', '-c',
                'rm ./harvests/image-temp-' + city + '/*.cdx 2>/dev/null'])
            call(["bash", '-c',
                'rm -R ./harvests/image-temp-' + city +
                '/wget-warc-temp/* 2>/dev/null'])
            call(['bash', '-c',
                'rm ./harvests/image-temp-' + city +
                '/*_images.txt 2>/dev/null'])

            call(["bash", '-c',
                'mv ./harvests/image-temp-' + city + '/*.warc.gz ./harvests/'])

    if (time.time() - start_time) > 60*60:
        # An hour has passed since we started harvesting, so die
        sys.exit()

    # Otherwise, prepare for next harvest
    alive_posts = next_alive_posts
    time.sleep(seconds_between_each_harvest)

