#!/usr/bin/env bash

rm accounts/Aarhus-account-data.sh
rm accounts/Kbh-account-data.sh

# Make the newest version of the jodel-api available
source jodel-virtualenv/bin/activate
pip install --upgrade pip
pip install --upgrade -r requirements.txt

./get-new-account.py "56.1572" "10.2107" "Aarhus"
./get-new-account.py "55.676111" "12.568333" "Kbh"

deactivate

