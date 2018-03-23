#!/usr/bin/env bash

# harvest-jodel.py will run the harvester for 1 hour. Repeat with cron.


source configs/Aarhus-config.sh

./harvest-jodel.py "$latitude" "$longitude" "$city" "$access_token" "$expiration_date" "$refresh_token" "$distinct_id" "$device_uid" "$num_of_recent_posts_to_harvest" "$seconds_between_each_harvest" &


source configs/Kbh-config.sh

./harvest-jodel.py "$latitude" "$longitude" "$city" "$access_token" "$expiration_date" "$refresh_token" "$distinct_id" "$device_uid" "$num_of_recent_posts_to_harvest" "$seconds_between_each_harvest" &


# TODO add more cities, by repeating the two lines above for each city

