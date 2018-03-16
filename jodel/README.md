# Harvest of Jodel


## To create a new (city-specific) Jodel-account for harvesting

* CREATING NEW ACCOUNTS CURRENTLY DOES NOT WORK - because of an app-update. It's fixable, but we need more time to do this *

cd jodel
./get-new-account.py <latitude> <longitude> <cityname>


### Example:

cd jodel
./get-new-account.py '56.15' '10.216667' 'Aarhus'


## To harvest cities for an hour

* This is currently set up to harvest only Aarhus, via the Aarhus-account that we have, which is not uploaded to github *

cd jodel
./harvest-jodel.sh

Details of how the harvest happens can be configured in the config-section at the start of harvet-jodel.py

