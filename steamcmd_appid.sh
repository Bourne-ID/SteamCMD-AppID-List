#!/bin/bash
# steamcmd_appid.sh
# Author: Daniel Gibbs and Robin Bourne
# Website: http://danielgibbs.co.uk
# Version: 181121
# Description: Saves the complete list of all the appid their names in json and csv and produces a anonymous server list
# env var TMUX_SESSIONS should be set.

rootdir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

echo "Creating steamcmd_appid.json"
curl https://api.steampowered.com/ISteamApps/GetAppList/v2/ | jq -r '.' > steamcmd_appid.json
echo "Creating steamcmd_appid.xml"
curl https://api.steampowered.com/ISteamApps/GetAppList/v2/?format=xml > steamcmd_appid.xml
# echo "Creating steamcmd_appid.csv"
# cat steamcmd_appid.json | jq '.applist.apps[]' | jq -r '[.appid, .name] | @csv' > steamcmd_appid.csv
# cat steamcmd_appid.json | jq '.applist[]' | md-table > steamcmd_appid.md

# prep the tmux command file for steamcmd
cat steamcmd_appid.json | jq '.applist.apps[]' | jq -r '[.appid] | @csv' | sed 's/^/tmux send-keys "app_status /' | sed 's/$/" ENTER/' > tmux_commands.sh
# Split the commands into the ENV for the number of sessions - names of the files will be tmuxXX.sh
split --numeric-suffixes=1 -n l/${TMUX_SESSIONS} --additional-suffix=.sh tmux_commands.sh tmux
# Alter each split file to name the relevant session which will be created later
for id in $(seq -f %02g 01 ${TMUX_SESSIONS}); do
    sed -i "s/send-keys/send-keys -t tmux${id}/" tmux${id}.sh
    echo "tmux send-keys -t tmux${id} \"exit\" ENTER" >> tmux${id}.sh
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
    tmux new -s "tmux${sessionid}" -d './steamcmd/steamcmd.sh +login anonymous' \; pipe-pane "cat > ./tmuxoutput${sessionid}"
done

steamprompt=false

echo "Waiting for Steam prompt"

# Bitwise check - may be useful for debug in the future
for attemptnumber in {1..120}; do
    total=0
    for sessionid in $(seq -f %02g 1 ${TMUX_SESSIONS}); do
        if grep -q "Steam>" tmuxoutput${sessionid}; then
            total=$(( ${total} + ( 2**( ${sessionid} - 1 ) ) ))
        fi
    done

    if [ $(( (2**(${TMUX_SESSIONS}))-1 )) -eq ${total} ]; then
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
      printf "\b${sp:i++%${#sp}:1}"
      sleep 0.2
    done
else
    echo "No steam prompt detected"
    exit "2"
fi

# Merge all tmux output to a single file
for f in tmuxoutput*; do (cat "${f}"; echo) >> tmuxallout.txt; done

# Parse file and create CSV of appid,result
pcre2grep -M -o1 -o2 --om-separator=\; 'AppID ([0-9]{1,8})[\s\S]*?release state: (.*)$' tmuxallout.txt > tmuxallout.csv

# convert the CSV to JSON
jq -Rsn '
  {"applist":
    {"apps":
      [inputs
       | . / "\r\n"
       | (.[] | select((. | length) > 0) | . / ";") as $input
       | {"appid": $input[0]|tonumber, "subscription": $input[1]}
      ]
    }
  }
' < tmuxallout.csv > tmuxallout.json

# Merge the tmux files and generate CSV and MD files

jq -s '[ .[0].applist.apps + .[1].applist.apps | group_by(.appid)[] | add]' steamcmd_appid.json tmuxallout.json > steamcmd_appid.json
cat steamcmd_app.json | jq '.[] |  select(.subscription == "released (Subscribed,Permanent,)") ' > steamcmd_appid_anon_servers.json
cat steamcmd_appid_anon_servers.json | jq -r '[.appid, .name, .subscription] | @csv' > steamcmd_appid_anon_servers.csv
cat steamcmd_appid_anon_servers.json | jq -r '.' | md-table > steamcmd_appid_anon_servers.md

echo "Creating steamcmd_appid.csv"
cat steamcmd_appid.json | jq '.[]' | jq -r '[.appid, .name, .subscription] | @csv' > steamcmd_appid.csv
cat steamcmd_appid.json | jq '.[]' | md-table > steamcmd_appid.md
# Clean up
rm tmux*

echo "exit"
exit
