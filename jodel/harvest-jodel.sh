#!/usr/bin/env bash

source accounts/Aarhus-account-data.sh

# Run jodel-harvester for 1 hour
./harvest-jodel.py "$latitude" "$longitude" "$city" "$access_token" "$expiration_date" "$refresh_token" "$distinct_id" "$device_uid"

# TODO add more cities, by repeating the two lines above for each city

