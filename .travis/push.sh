#!/bin/sh

git config --global user.email "BourneID@h-r-l.co.uk"
git config --global user.name "Bourne-ID"

git remote set-url origin https://Bourne-ID:${GH_TOKEN}@github.com/Bourne-ID/SteamCMD-AppID-List.git

git checkout ${TRAVIS_BRANCH}
git add steamcmd_appid.json
git add steamcmd_appid.xml
git add steamcmd_appid.csv
git add steamcmd_appid.md
git add steamcmd_appid_anon.json
git add steamcmd_appid_anon.csv
git add steamcmd_appid_anon.md
git commit --message "Travis build: $(date +%Y-%m-%d)"


git push --set-upstream origin ${TRAVIS_BRANCH}
