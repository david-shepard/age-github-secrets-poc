#!/bin/bash
# Export GitHub team members' SSH keys to recipients.txt

set -euo pipefail

KEY_LIST='recipients.txt'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Flags
APPEND=false
VERBOSE=false

# Usage function
usage() {
  cat << EOF
Usage: GH_ORG='org' GH_TEAM='team' $0 [OPTIONS]

Export GitHub team members' public SSH keys to recipients.txt

REQUIRED ENVIRONMENT VARIABLES:
  GH_ORG          GitHub organization name
  GH_TEAM         GitHub team slug/name
  GITHUB_TOKEN    GitHub personal access token with 'read:org' and 'read:user' scopes

OPTIONS:
  -a              Append to existing recipients.txt (default: overwrite)
  -v              Verbose output
  -h              Show this help message

EXAMPLES:
  # Export keys for a team (will overwrite recipients.txt)
  GH_ORG='myorg' GH_TEAM='developers' GITHUB_TOKEN='ghp_xxx' $0

  # Append keys to existing file
  GH_ORG='myorg' GH_TEAM='qa-team' GITHUB_TOKEN='ghp_xxx' $0 -a

EOF
  exit 1
}

# Parse command line arguments
while getopts "avh" opt; do
  case $opt in
    a)
      APPEND=true
      ;;
    v)
      VERBOSE=true
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
  esac
done

# Validate required environment variables
if [[ -z "${GH_ORG:-}" ]]; then
  echo -e "${RED}Error: GH_ORG environment variable is not set${NC}" >&2
  echo "Example: GH_ORG='myorg' GH_TEAM='team' $0" >&2
  exit 1
fi

if [[ -z "${GH_TEAM:-}" ]]; then
  echo -e "${RED}Error: GH_TEAM environment variable is not set${NC}" >&2
  echo "Example: GH_ORG='myorg' GH_TEAM='team' $0" >&2
  exit 1
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo -e "${RED}Error: GITHUB_TOKEN environment variable is not set${NC}" >&2
  echo "Please set a GitHub personal access token with 'read:org' and 'read:user' scopes" >&2
  echo "Create one at: https://github.com/settings/tokens" >&2
  exit 1
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
  echo -e "${RED}Error: 'curl' is not installed.${NC}" >&2
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: 'jq' is not installed.${NC}" >&2
  echo "Please install it first:" >&2
  echo "  - Mac: brew install jq" >&2
  echo "  - Ubuntu: apt install jq" >&2
  exit 1
fi

echo -e "${GREEN}Fetching team members for ${GH_ORG}/${GH_TEAM}...${NC}"

# Fetch team members
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/orgs/$GH_ORG/teams/$GH_TEAM/members")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" -ne 200 ]]; then
  echo -e "${RED}Error: Failed to fetch team members (HTTP $HTTP_CODE)${NC}" >&2

  # Try to extract error message
  ERROR_MSG=$(echo "$BODY" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
  echo -e "${RED}GitHub API error: $ERROR_MSG${NC}" >&2

  if [[ "$HTTP_CODE" -eq 401 ]]; then
    echo "Check that your GITHUB_TOKEN is valid and has the required scopes" >&2
  elif [[ "$HTTP_CODE" -eq 404 ]]; then
    echo "Check that the organization and team names are correct" >&2
  fi
  exit 1
fi

MEMBERS=$(echo "$BODY" | jq -r '.[].login' 2>/dev/null)

if [[ -z "$MEMBERS" ]]; then
  echo -e "${YELLOW}No members found in team ${GH_ORG}/${GH_TEAM}${NC}"
  exit 0
fi

MEMBER_COUNT=$(echo "$MEMBERS" | wc -l | tr -d ' ')
echo -e "${GREEN}Found $MEMBER_COUNT team member(s)${NC}"
echo ""

# Clear or create the key list file
if [[ "$APPEND" == false ]]; then
  echo "# Recipients file for age encryption" > "$KEY_LIST"
  echo "# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$KEY_LIST"
  echo "# Organization: $GH_ORG" >> "$KEY_LIST"
  echo "# Team: $GH_TEAM" >> "$KEY_LIST"
  echo "" >> "$KEY_LIST"
else
  if [[ -f "$KEY_LIST" ]]; then
    echo "" >> "$KEY_LIST"
    echo "# Appended: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$KEY_LIST"
    echo "# Organization: $GH_ORG" >> "$KEY_LIST"
    echo "# Team: $GH_TEAM" >> "$KEY_LIST"
    echo "" >> "$KEY_LIST"
  else
    echo "# Recipients file for age encryption" > "$KEY_LIST"
    echo "# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$KEY_LIST"
    echo "# Organization: $GH_ORG" >> "$KEY_LIST"
    echo "# Team: $GH_TEAM" >> "$KEY_LIST"
    echo "" >> "$KEY_LIST"
  fi
fi

TOTAL_KEYS=0
MEMBERS_WITH_KEYS=0
MEMBERS_WITHOUT_KEYS=0

# For each member, fetch their public SSH keys
while IFS= read -r MEMBER; do
  if [[ -z "$MEMBER" ]]; then
    continue
  fi

  if [[ "$VERBOSE" == true ]]; then
    echo "Fetching keys for: $MEMBER"
  fi

  # Fetch user's SSH keys
  KEY_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/users/$MEMBER/keys")

  KEY_HTTP_CODE=$(echo "$KEY_RESPONSE" | tail -n1)
  KEY_BODY=$(echo "$KEY_RESPONSE" | sed '$d')

  if [[ "$KEY_HTTP_CODE" -ne 200 ]]; then
    echo -e "${YELLOW}⚠ Warning: Failed to fetch keys for $MEMBER (HTTP $KEY_HTTP_CODE)${NC}" >&2
    continue
  fi

  MEMBER_KEYS=$(echo "$KEY_BODY" | jq -r '.[].key' 2>/dev/null)

  if [[ -z "$MEMBER_KEYS" ]] || [[ "$MEMBER_KEYS" == "null" ]]; then
    echo -e "${YELLOW}⚠ $MEMBER has no public SSH keys${NC}"
    ((MEMBERS_WITHOUT_KEYS++))
    continue
  fi

  KEY_COUNT=$(echo "$MEMBER_KEYS" | wc -l | tr -d ' ')
  ((MEMBERS_WITH_KEYS++))
  TOTAL_KEYS=$((TOTAL_KEYS + KEY_COUNT))

  echo "# User: $MEMBER ($KEY_COUNT key(s))" >> "$KEY_LIST"

  oldIFS="$IFS"
  IFS=$'\n'
  for KEY in $MEMBER_KEYS; do
    if [[ "$KEY" != "null" ]] && [[ -n "$KEY" ]]; then
      echo "$KEY" >> "$KEY_LIST"
    fi
  done
  IFS="$oldIFS"

  if [[ "$VERBOSE" == true ]]; then
    echo -e "  ${GREEN}✓ Added $KEY_COUNT key(s)${NC}"
  else
    echo -e "${GREEN}✓ $MEMBER ($KEY_COUNT key(s))${NC}"
  fi
done <<< "$MEMBERS"

echo ""
echo -e "${GREEN}Export complete!${NC}"
echo "Total members: $MEMBER_COUNT"
echo "Members with keys: $MEMBERS_WITH_KEYS"
echo "Members without keys: $MEMBERS_WITHOUT_KEYS"
echo "Total keys exported: $TOTAL_KEYS"
echo ""
echo "Keys saved to: $KEY_LIST"

if [[ "$MEMBERS_WITHOUT_KEYS" -gt 0 ]]; then
  echo ""
  echo -e "${YELLOW}⚠️  WARNING: $MEMBERS_WITHOUT_KEYS member(s) have no SSH keys${NC}"
  echo -e "${YELLOW}   They will not be able to decrypt secrets${NC}"
  echo -e "${YELLOW}   Ask them to add SSH keys to their GitHub profile${NC}"
fi
