#!/bin/bash
# steamcmd_appid.sh
# Author: Daniel Gibbs
# Website: http://danielgibbs.co.uk
# Version: 180826
# Description: Saves the complete list of all the appid their names in json and csv.

rootdir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

echo "Creating steamcmd_appid.json"
curl https://api.steampowered.com/ISteamApps/GetAppList/v2/ | jq -r '.' > steamcmd_appid.json
echo "Creating steamcmd_appid.csv"
curl https://api.steampowered.com/ISteamApps/GetAppList/v2/ | jq '.applist.apps[]' | jq -r '[.appid, .name] | @csv' > steamcmd_appid.csv
echo "exit"
exit