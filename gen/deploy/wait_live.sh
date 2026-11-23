#!/bin/bash
# Waits until the web build just deployed is what the site serves (GitHub Pages takes 1-3 min): prints LIVE <id> or
# NOT LIVE after 5 min. usage: gen/deploy/wait_live.sh [ashes-xxxxxxxx]  (default: the id in the pages clone)
cd "$(dirname "$0")/../.."
id="${1:-$(grep -o '"executable":"ashes-[0-9a-f]*"' ../ashes-in-the-rain-pages/index.html | grep -o 'ashes-[0-9a-f]*')}"
u=$(git remote get-url origin | sed -E 's#.*github.com[:/]([^/]+)/([^.]+)(\.git)?#https://\1.github.io/\2/#')
for i in $(seq 1 30); do curl -s "$u/index.html?$i" | grep -q "$id" && { echo "LIVE $id"; exit 0; }; sleep 10; done
echo "NOT LIVE $id"; exit 1
