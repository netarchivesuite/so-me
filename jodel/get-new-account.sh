#!/usr/bin/env bash

# Make the newest version of the jodel-api available
source jodel-virtualenv/bin/activate
pip install --upgrade pip
pip install --upgrade -r requirements.txt

./get-new-account.py "$1" "$2" "$3"

deactivate

