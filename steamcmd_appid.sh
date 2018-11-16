#!/bin/bash
# steamcmd_appid.sh
# Author: Daniel Gibbs and Robin Bourne
# Website: http://danielgibbs.co.uk
# Version: 181106
# Description: Saves the complete list of all the appid their names in json and csv and produces a anonymous server list
# env var TMUX_SESSIONS should be set.

TMUX_SESSIONS=4

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
# Split the commands into the ENV for the number of sessions - names of the files will be tmuxXX.sh
split --numeric-suffixes=1 -n l/${TMUX_SESSIONS} --additional-suffix=.sh tmux_commands.sh tmux
# Alter each split file to name the relevant session which will be created later
for id in $(seq -f %02g 01 ${TMUX_SESSIONS}); do
    sed -i "s/send-keys/send-keys -t tmux${id}/" tmux${id}.sh
    echo "tmux send-keys -t tmux${id} /"exit/" ENTER" >> tmux${id}.sh
    tail tmux${id}.sh
done

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
for sessionid in $(seq -f %02g 01 ${TMUX_SESSIONS}); do
    tmux new -s "tmux${sessionid}" -d './steamcmd/steamcmd.sh +login anonymous' \; pipe-pane "cat > ./tmux${sessionid}"
done

steamprompt=false

echo "Waiting for Steam prompt"

for attemptnumber in {1..120}; do
    total=1
    for sessionid in $(seq -f %02g 1 ${TMUX_SESSIONS}); do
        if grep -q "Steam>" tmux${sessionid}; then
            total=$(( ${total} + ( 2**${sessionid} ) ))
        fi
    done

    if [ $(( (2**(${TMUX_SESSIONS}+1))-1 )) -eq ${total} ]; then
        steamprompt=true
        break
    else
        echo -n "."
        sleep 0.5
    fi
done

echo "\n Starting App ID checks"

if [ steamprompt ]; then
    for sessionid in $(seq -f %02g 01 ${TMUX_SESSIONS}); do
        . ./tmux${sessionid}.sh &
    done
    i=1
    sp="/-\|"
    echo -n ' '
    while [ $(tmux ls | wc -l) -ne "0" ]
    do
      sleep 5
      tail -n 1 tmux04
    done
else
    echo "No steam prompt detected"
    exit "2"
fi

# Parse file and create CSV of appid,result
pcre2grep -M -o1 -o2 --om-separator=, 'AppID ([0-9]{1,6})[\s\S]*?release state: (.*)$' tmux1 > anon1

cat anon1

# AppID ([0-9]{1,6})[\S\s]*?release state: (.*)$



#for row in $( cat "${rootdir}/steamcmd_appid.json" | jq '.applist.apps[]' | jq -r '.appid'); do
#    subscription=$("${rootdir}/steamcmd"/steamcmd.sh +login anonymous +app_status ${row} +exit | grep Subscribed | wc -l);
#    if [ "${subscription}" == "1" ]; then
#        echo "anonymous sub available: YES: ${row}";
#    else
#    	echo "anonymous sub available: NO: ${row}";
#    fi
#done

#later we do jq merge on appid index
echo "exit"
exit
