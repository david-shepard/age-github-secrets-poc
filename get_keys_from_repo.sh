#!/bin/bash
set -e


KEY_LIST='recipients.txt'

ORG=push-and-pray-ops
TEAM=sudo
echo "Fetching keys for ${ORG}/${TEAM} \n"
MEMBERS=$(curl -k -s -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "https://api.github.com/orgs/$ORG/teams/$TEAM/members" | jq -r '.[].login')

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
