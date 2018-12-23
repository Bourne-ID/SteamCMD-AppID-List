#!/bin/bash
# steamcmd_appid.sh
# Author: Daniel Gibbs and Robin Bourne
# Website: http://danielgibbs.co.uk
# Version: 181121
# Description: Saves the complete list of all the appid their names in json and csv and produces a anonymous server list
# env var TMUX_SESSIONS should be set.

# Static variables
rootdir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# Functions

# Downloads the source data files for analysis
download_steam_files() {
echo "Creating steamcmd_appid.json"
curl https://api.steampowered.com/ISteamApps/GetAppList/v2/ | jq -r '.' > steamcmd_getapplist.json
echo "Creating steamcmd_appid.xml"
curl https://api.steampowered.com/ISteamApps/GetAppList/v2/?format=xml > steamcmd_appid.xml
}

# Checks for SteamCMD, and installs if it does not exist
install_steamcmd(){
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
    cd "${rootdir}"
}

# Generate a list of commands to send to SteamCMD.
# Parameter 1: JSON content to parse as an array of relevant entities
# Returns: Output as string
generate_commands() {
    local input_json=${1}
    local temp_file=$(mktemp)
    echo $input_json > $temp_file

    local output=$(jq -n -f "$temp_file" | jq -r '.[] | [.appid] | @csv' | sed 's/^/tmux send-keys "app_status /' | sed 's/$/" ENTER/')

    echo "${output}"
    rm $temp_file
}

# check required external variables
if [ -z ${TMUX_SESSIONS+x} ]; then
    echo "TMUX_SESSIONS is not set. Please set this variable to allocate the number of TMUX sessions that should be used to query SteamCMD"
    exit 1
fi

# pre-requirements
download_steam_files
install_steamcmd

# prep the tmux command file for steamcmd
parsed_json=$(cat steamcmd_getapplist.json | jq '.applist.apps')
output=$(generate_commands "$parsed_json")
echo "$output" > tmux_commands.sh

# Split the commands into the ENV for the number of sessions - names of the files will be tmuxXX.sh
split --numeric-suffixes=1 -n l/${TMUX_SESSIONS} --additional-suffix=.sh tmux_commands.sh tmux
# Alter each split file to name the relevant session which will be created later
for id in $(seq -f %02g 01 ${TMUX_SESSIONS}); do
    sed -i "s/send-keys/send-keys -t tmux${id}/" tmux${id}.sh
    echo "tmux send-keys -t tmux${id} \"exit\" ENTER" >> tmux${id}.sh
done

# Start a tmux session for steamcmd, pipe to file and wait for steam prompt(s)
echo "Starting ${TMUX_SESSIONS} TMUX Sessions"
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

echo "Processing Output from TMUX Sessions..."

# Merge all tmux output to a single file
for f in tmuxoutput*; do (cat "${f}"; echo) >> tmuxallout.txt; done

# Parse file and create CSV of appid,result and convert the CSV to JSON
pcre2grep -M -o1 -o2 --om-separator=\; 'AppID ([0-9]{1,8})[\s\S]*?release state: (.*)$' tmuxallout.txt | jq -Rsn '
  {"applist":
    {"apps":
      [inputs
       | . / "\r\n"
       | (.[] | select((. | length) > 0) | . / ";") as $input
       | {"appid": $input[0]|tonumber, "subscription": $input[1]}
      ]
    }
  }
' > tmuxallout.json

# Merge the tmux files and generate CSV and MD files

jq -s '[ .[0].applist.apps + .[1].applist.apps | group_by(.appid)[] | add]' steamcmd_getapplist.json tmuxallout.json > steamcmd_appid.json

# Analyse licences and add additional OS/licence information

echo "Extract released/prereleased appid's for further analysis"
anon_servers=$(cat steamcmd_appid.json | jq '[.[] |  select(.subscription | contains("release"))]')
echo "$anon_servers" > steamcmd_appid_anon_servers.json

echo "Generate tmux script for anon servers"
output=$(generate_commands "$anon_servers")

echo "$output" > tmux_anon_commands.sh

chmod +x tmux_anon_commands.sh

sed -i "s/send-keys/send-keys -t tmuxwindows/" tmux_anon_commands.sh
echo "tmux send-keys -t tmuxwindows \"exit\" ENTER" >> tmux_anon_commands.sh

echo "Spin up 1 TMUX LinuxGSM in Windows Mode"
tmux new -s "tmuxwindows" -d './steamcmd/steamcmd.sh +@sSteamCmdForcePlatformType windows +login anonymous' \; pipe-pane "cat > ./tmuxoutputwindows.txt"

echo "Waiting for Steam Prompt"
while ! grep -q "Steam>" tmuxoutputwindows.txt; do
        echo -n "."
done

# executing commands to widows shell and awaiting finish
./tmux_anon_commands.sh &

# wait for the tmux session to finish

while [ $(tmux ls | wc -l) -ne "0" ]
    do
      printf "\b${sp:i++%${#sp}:1}"
      sleep 0.2
    done

echo "Parsing Windows Information"
pcre2grep -M -o1 -o2 --om-separator=\; 'AppID ([0-9]{1,8})[\s\S]*?release state: (.*)$' tmuxoutputwindows.txt > tmuxwindows.csv

# convert the CSV to JSON
jq -Rsn '

      [inputs
       | . / "\r\n"
       | (.[] | select((. | length) > 0) | . / ";") as $input
       | {"appid": $input[0]|tonumber, "subscription": $input[1]}
      ]

' < tmuxwindows.csv > tmuxwindows.json

echo "Adding Windows Compatibility Information"
cat tmuxwindows.json | jq '[.[] | .windows = (.subscription | contains("Invalid Platform") | not )]' > tmuxwindows.json$$
mv tmuxwindows.json$$ tmuxwindows.json

echo "Adding Linux Compatibility Information" #here
cat steamcmd_appid_anon_servers.json | jq '[.[] | .linux = (.subscription | contains("Invalid Platform") | not )]' > steamcmd_appid_anon_servers.json$$
mv steamcmd_appid_anon_servers.json$$ steamcmd_appid_anon_servers.json

echo "Merging information"

jq -s '[ .[0] + .[1] | group_by(.appid)[] | add]' steamcmd_appid_anon_servers.json tmuxwindows.json > steamcmd_appid_anon_servers.json$$
mv steamcmd_appid_anon_servers.json$$ steamcmd_appid_anon_servers.json

cat steamcmd_appid_anon_servers.json | jq '.[] | [.appid, .name, .subscription, .linux, .windows] | @csv' > steamcmd_appid_anon_servers.csv
cat steamcmd_appid_anon_servers.json | jq -s '.[]' | md-table > steamcmd_appid_anon_servers.md

# Remove details of licence information as this has been known to change randomly
cat steamcmd_appid.json | jq '[.[] | .subscription = (.subscription | sub("(?<vers>.? ).*"; .vers) | rtrimstr(" "))]' > steamcmd_appid.json$$
mv steamcmd_appid.json$$ steamcmd_appid.json

cat steamcmd_appid_anon_servers.json | jq '[.[] | .subscription = (.subscription | sub("(?<vers>.? ).*"; .vers) | rtrimstr(" "))]' > steamcmd_appid_anon_servers.json$$
mv steamcmd_appid_anon_servers.json$$ steamcmd_appid_anon_servers.json

cat steamcmd_appid.json | jq '.[] | [.appid, .name, .subscription] | @csv' > steamcmd_appid.csv
cat steamcmd_appid.json | md-table > steamcmd_appid.md

echo "exit"
exit
