# Harvest of Jodel

## Basic setup

Install Python 2, pip 2 and Python setuptools (`sudo pip install -U setuptools`).

Install the Jodel API
```
pip2 install jodel_api
```

If the scripts stop working, upgrade the Jodel API with
```
pip2 install --upgrade jodel_api
```


## To create a new (city-specific) Jodel-account for harvesting

```
cd jodel
./get-new-account.sh <latitude> <longitude> <cityname>
```

[Google Maps](https://maps.google.com) can provide coordinates: Find the location, right click and select _"What's here?"_ - the coordinates are shown at the bottom of the window.

### Example:

```
cd jodel
./get-new-account.sh '56.15' '10.216667' 'Aarhus'
```


## To harvest cities for an hour

Edit the script `harvest-jodel.sh` to use the created Jodel account and start it

```
cd jodel
./harvest-jodel.sh
```

The results are stored in the `harvests`-folder.

Details of how the harvest happens can be configured in the config-section at the start of harvest-jodel.py

