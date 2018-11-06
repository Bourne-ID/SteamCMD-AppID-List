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

# prep the tmux command file for steamcmd
cat steamcmd_appid.json | jq '.applist.apps[]' | jq -r '[.appid] | @csv' | sed 's/^/tmux send-keys "app_status /' | sed 's/$/" ENTER/' > tmux_commands.sh

# Split the commands into the ENV for the number of sessions (todo)
#

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

# Start a tmux session for steamcmd, pipe to file and wait for steam prompt
cd "${rootdir}"
tmux new -d './steamcmd/steamcmd.sh +login anonymous' \; pipe-pane 'cat > ./tmux1'
steamprompt=false

echo "Waiting for Steam prompt"

for attemptnumber in {1..120}; do
    if grep -q "Steam>" tmux1; then
        steamprompt=true
        break
    else
        echo -n "."
        sleep 0.5
    fi
done

echo "Starting App ID checks"

if [ steamprompt ]; then
    . ./tmux_commands.sh &
    tmuxcommandspid=$!
    i=1
    sp="/-\|"
    echo -n ' '
    while [ -d /proc/$tmuxcommandspid ]
    do
      printf "\b${sp:i++%${#sp}:1}"
      sleep 0.2
    done
else
    echo "No steam prompt detected"
    exit "2"
fi

cat ./tmux1
#TODO: Regex parse

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