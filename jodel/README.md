# Harvest of Jodel


## To create a new (city-specific) Jodel-account for harvesting

cd jodel
./get-new-account.py <latitude> <longitude> <cityname>


### Example:

cd jodel
./get-new-account.py '56.15' '10.216667' 'Aarhus'


## To harvest cities for an hour

cd jodel
./harvest-jodel.sh

New cities must be added to harvest-jodel.sh
Details of how the harvest happens can be configured in the config-section at the start of harvest-jodel.py

