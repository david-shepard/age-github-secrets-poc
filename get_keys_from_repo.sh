#!/bin/bash
set -e

KEY_LIST='recipients.txt'

MEMBERS=$(curl -k -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "https://api.github.com/orgs/push-and-pray-ops/teams/sudo/members" | jq -r '.[].login')

# rm -rf $KEY_LIST

# For each member, fetch their public SSH keys
for MEMBER in ${MEMBERS[@]}; do
  echo "member: $MEMBER"
  PAYLOAD=$(curl -k -s -H "Accept: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "https://api.github.com/users/$MEMBER/keys")
  echo "payload: $PAYLOAD"
  echo "$KEY"
  if [[ $KEY != "null" ]]; then
    echo "${KEY} \# $MEMBER" >> "${KEY_LIST}"
  fi
done
