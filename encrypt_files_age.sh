#!/bin/bash
# Encrypt all files to ciphertexts

set -euo pipefail

# Get current dir
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# Directory containing plaintext secrets
SECRETS_DIR="$SCRIPT_DIR/secrets"
# Output directory for encrypted secrets
ENCRYPTED_DIR="$SCRIPT_DIR/encrypted"
# Recipients file
RECIPIENTS_FILE="$SCRIPT_DIR/recipients.txt"

ENCRYPT_SUFFIX=".enc"

# Flags
DRY_RUN=false
KEEP_PLAINTEXT=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Usage function
usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Encrypt all plaintext files from ./secrets to ./encrypted

OPTIONS:
  -k              Keep plaintext files after encryption (don't delete)
  -d              Dry run - show what would be encrypted without actually doing it
  -v              Verbose output
  -h              Show this help message

EXAMPLES:
  # Encrypt and delete plaintext (default behavior)
  $0

  # Encrypt but keep plaintext files
  $0 -k

  # Dry run to see what would be encrypted
  $0 -d -v

EOF
  exit 1
}

# Parse command line arguments
while getopts "kdvh" opt; do
  case $opt in
    k)
      KEEP_PLAINTEXT=true
      ;;
    d)
      DRY_RUN=true
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

# Check if age is installed
if ! command -v age &> /dev/null; then
  echo -e "${RED}Error: 'age' is not installed.${NC}" >&2
  echo "Please install it first:" >&2
  echo "  - Mac: brew install age" >&2
  echo "  - Ubuntu: apt install age" >&2
  echo "  - Windows: See README.md for installation instructions" >&2
  exit 1
fi

# Check if recipients file exists and has content
if [[ ! -f "$RECIPIENTS_FILE" ]]; then
  echo -e "${RED}Error: Recipients file not found: $RECIPIENTS_FILE${NC}" >&2
  echo "Please create a recipients.txt file with public keys" >&2
  echo "Run: GH_ORG='your_org' GH_TEAM='your_team' ./export_team_to_recipients.sh" >&2
  exit 1
fi

if [[ ! -s "$RECIPIENTS_FILE" ]]; then
  echo -e "${RED}Error: Recipients file is empty: $RECIPIENTS_FILE${NC}" >&2
  echo "Please add at least one public key to recipients.txt" >&2
  exit 1
fi

# Check if secrets directory exists
if [[ ! -d "$SECRETS_DIR" ]]; then
  echo -e "${RED}Error: Secrets directory not found: $SECRETS_DIR${NC}" >&2
  exit 1
fi

# Create output directory if it doesn't exist (unless dry run)
if [[ "$DRY_RUN" == false ]]; then
  mkdir -p "$ENCRYPTED_DIR"
fi

# Find files to encrypt
SECRET_FILES=()
while IFS= read -r -d '' file; do
  SECRET_FILES+=("$file")
done < <(find "$SECRETS_DIR" -type f ! -name ".gitkeep" -print0)

if [[ ${#SECRET_FILES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}No files found to encrypt in $SECRETS_DIR${NC}"
  exit 0
fi

echo -e "${GREEN}Found ${#SECRET_FILES[@]} file(s) to encrypt${NC}"
if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}DRY RUN MODE - No files will be actually encrypted${NC}"
fi
echo ""

ENCRYPTED_COUNT=0
FAILED_COUNT=0

for FILE in "${SECRET_FILES[@]}"; do
  # Get relative path from secrets dir
  REL_PATH="${FILE#$SECRETS_DIR/}"
  BASE_NAME=$(basename "$FILE")

  # Preserve directory structure
  FILE_DIR=$(dirname "$REL_PATH")
  if [[ "$FILE_DIR" == "." ]]; then
    ENCRYPTED_FILE="$ENCRYPTED_DIR/${BASE_NAME}${ENCRYPT_SUFFIX}"
  else
    ENCRYPTED_FILE="$ENCRYPTED_DIR/${FILE_DIR}/${BASE_NAME}${ENCRYPT_SUFFIX}"
  fi

  if [[ "$VERBOSE" == true ]] || [[ "$DRY_RUN" == true ]]; then
    echo "Encrypting: $REL_PATH → encrypted/${REL_PATH}${ENCRYPT_SUFFIX}"
  fi

  if [[ "$DRY_RUN" == false ]]; then
    # Create subdirectory if needed
    ENCRYPTED_SUBDIR=$(dirname "$ENCRYPTED_FILE")
    mkdir -p "$ENCRYPTED_SUBDIR"

    # Attempt encryption
    if age -R "$RECIPIENTS_FILE" -a -o "$ENCRYPTED_FILE" "$FILE" 2>/dev/null; then
      ((ENCRYPTED_COUNT++))
      if [[ "$VERBOSE" == true ]]; then
        echo -e "  ${GREEN}✓ Success${NC}"
      fi
    else
      ((FAILED_COUNT++))
      echo -e "  ${RED}✗ Failed to encrypt: $REL_PATH${NC}" >&2
    fi
  fi
done

echo ""
if [[ "$DRY_RUN" == false ]]; then
  echo -e "${GREEN}Encryption complete!${NC}"
  echo "Successfully encrypted: $ENCRYPTED_COUNT file(s)"
  if [[ "$FAILED_COUNT" -gt 0 ]]; then
    echo -e "${RED}Failed to encrypt: $FAILED_COUNT file(s)${NC}"
    exit 1
  fi

  # Delete plaintext files unless -k flag is set
  if [[ "$KEEP_PLAINTEXT" == false ]]; then
    echo ""
    echo -e "${YELLOW}Removing plaintext files from $SECRETS_DIR...${NC}"
    for FILE in "${SECRET_FILES[@]}"; do
      rm -f "$FILE"
      if [[ "$VERBOSE" == true ]]; then
        REL_PATH="${FILE#$SECRETS_DIR/}"
        echo "  Deleted: $REL_PATH"
      fi
    done
    echo -e "${GREEN}Plaintext files removed${NC}"
  else
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: Plaintext files retained in $SECRETS_DIR${NC}"
    echo -e "${YELLOW}   Remember to delete them manually or avoid committing them to git${NC}"
  fi
else
  echo "Would encrypt ${#SECRET_FILES[@]} file(s)"
  if [[ "$KEEP_PLAINTEXT" == false ]]; then
    echo "Would delete plaintext files after encryption"
  fi
fi
