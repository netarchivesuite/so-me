#!/usr/bin/env python2

import jodel_api
import sys

# Read input parameters
lat = sys.argv[1]
lng = sys.argv[2]
city = sys.argv[3]

print "Latitude: " + lat
print "Longitude: " + lng
print "City: " + city

a = jodel_api.JodelAccount(lat=lat, lng=lng, city=city)
account_data = a.get_account_data()

# Generate and print bash-sourcable variable-definitions to stdout
with open("accounts/" + city + "-account-data.sh", "w") as f:
    print >>f, "latitude='" + str(lat) + "'"
    print >>f, "longitude='" + str(lng) + "'"
    print >>f, "city='" + city + "'"
    print >>f, "access_token='" + account_data["access_token"] + "'"
    print >>f, "expiration_date='" + str(account_data["expiration_date"]) + "'"
    print >>f, "refresh_token='" + account_data["refresh_token"] + "'"
    print >>f, "distinct_id='" + account_data["distinct_id"] + "'"
    print >>f, "device_uid='" + account_data["device_uid"] + "'"

