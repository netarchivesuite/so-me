#!/usr/bin/env python2

import jodel_api

# TODO take these as input to this script
lat, lng, city = 56.15, 10.216667, "Aarhus"

a = jodel_api.JodelAccount(lat=lat, lng=lng, city=city)
account_data = a.get_account_data()

# TODO take dir/filename below as input to this script
# Generate and print bash-sourcable variable-definitions to stdout
with open("accounts/Aarhus-account-data.sh", "w") as f:
    print >>f, "latitude='" + str(lat) + "'"
    print >>f, "longitude='" + str(lng) + "'"
    print >>f, "city='" + city + "'"
    print >>f, "access_token='" + account_data["access_token"] + "'"
    print >>f, "expiration_date='" + str(account_data["expiration_date"]) + "'"
    print >>f, "refresh_token='" + account_data["refresh_token"] + "'"
    print >>f, "distinct_id='" + account_data["distinct_id"] + "'"
    print >>f, "device_uid='" + account_data["device_uid"] + "'"

