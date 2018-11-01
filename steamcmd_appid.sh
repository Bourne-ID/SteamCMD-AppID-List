#!/bin/bash
# steamcmd_appid.sh
# Author: Daniel Gibbs
# Website: http://danielgibbs.co.uk
# Version: 180826
# Description: Saves the complete list of all the appid their names in json and csv.

rootdir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

echo "Creating steamcmd_appid.json"
curl https://api.steampowered.com/ISteamApps/GetAppList/v2/ | jq -r '.' > steamcmd_appid.json
echo "Creating steamcmd_appid.xml"
curl https://api.steampowered.com/ISteamApps/GetAppList/v2/?format=xml > steamcmd_appid.xml
echo "Creating steamcmd_appid.csv"
cat steamcmd_appid.json | jq '.applist.apps[]' | jq -r '[.appid, .name] | @csv' > steamcmd_appid.csv
cat steamcmd_appid.json | jq '.applist[]' | md-table > steamcmd_appid.md

# Install SteamCMD
echo ""
echo "Installing SteamCMD"
echo "================================="
cd "${rootdir}"
mkdir -pv "steamcmd"
cd "steamcmd"
if [ ! -f "steamcmd.sh" ]; then
    echo -e "downloading steamcmd_linux.tar.gz...\c"
    wget -N /dev/null http://media.steampowered.com/client/steamcmd_linux.tar.gz 2>&1 | grep -F HTTP | cut -c45-| uniq
    tar --verbose -zxf "steamcmd_linux.tar.gz"
    rm -v "steamcmd_linux.tar.gz"
    chmod +x "steamcmd.sh"
else
    echo "Steam already installed!"
fi

tmux new-session -d
tmux send-keys "echo Hello World" ENTER
tmux kill-session

#for row in $( cat "${rootdir}/steamcmd_appid.json" | jq '.applist.apps[]' | jq -r '.appid'); do
#    subscription=$("${rootdir}/steamcmd"/steamcmd.sh +login anonymous +app_status ${row} +exit | grep Subscribed | wc -l);
#    if [ "${subscription}" == "1" ]; then
#        echo "anonymous sub available: YES: ${row}";
#    else
#    	echo "anonymous sub available: NO: ${row}";
#    fi
#done

echo "exit"
exit