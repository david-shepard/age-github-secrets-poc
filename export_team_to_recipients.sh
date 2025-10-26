#!/bin/bash
set -e

KEY_LIST='recipients.txt'

: "${GH_ORG:?Error: variable GH_ORG not set.}"
: "${GH_TEAM:?Error: variable GH_TEAM not set.}"

echo "Fetching keys for ${GH_ORG}/${GH_TEAM} \n"
MEMBERS=$(curl -k -s -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "https://api.github.com/orgs/$GH_ORG/teams/$GH_TEAM/members" | jq -r '.[].login')

# rm -rf $KEY_LIST

# For each member, fetch (all of) their public SSH keys
for MEMBER in ${MEMBERS[@]}; do
  echo "# User: $MEMBER" >> "${KEY_LIST}"

  echo "Fetching keys for $MEMBER"
  MEMBER_KEYS=$(curl -k -s -H "Accept: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "https://api.github.com/users/$MEMBER/keys" | jq -r '.[].key')

  oldIFS="$IFS"
  IFS=$'\n'
  for KEY in $MEMBER_KEYS; do
    if [[ $KEY != "null" ]]; then
      echo "${KEY}" >> "${KEY_LIST}"
    fi
  done
  IFS="$oldIFS"

done
