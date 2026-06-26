#!/bin/bash
# Decrypt encrypted files back to plaintext secrets

set -euo pipefail

# Get current dir
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# Directory containing encrypted secrets
ENCRYPTED_DIR="$SCRIPT_DIR/encrypted"
# Output directory for decrypted secrets
SECRETS_DIR="$SCRIPT_DIR/secrets"

# Default SSH key location (can be overridden with -i flag)
DEFAULT_KEY="$HOME/.ssh/id_rsa"
IDENTITY_FILE="${IDENTITY_FILE:-$DEFAULT_KEY}"

# Flags
DRY_RUN=false
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

Decrypt all encrypted files from ./encrypted to ./secrets

OPTIONS:
  -i <key_file>   Specify identity file (private key) to use for decryption
                  Default: $DEFAULT_KEY
  -d              Dry run - show what would be decrypted without actually doing it
  -v              Verbose output
  -h              Show this help message

EXAMPLES:
  # Decrypt using default key
  $0

  # Decrypt using specific key
  $0 -i ~/.ssh/my_github_key

  # Dry run to see what would be decrypted
  $0 -d -v

ENVIRONMENT VARIABLES:
  IDENTITY_FILE   Override default identity file location

EOF
  exit 1
}

# Parse command line arguments
while getopts "i:dvh" opt; do
  case $opt in
    i)
      IDENTITY_FILE="$OPTARG"
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

# Check if identity file exists
if [[ ! -f "$IDENTITY_FILE" ]]; then
  echo -e "${RED}Error: Identity file not found: $IDENTITY_FILE${NC}" >&2
  echo "Please specify a valid private key with -i flag" >&2
  exit 1
fi

# Check if encrypted directory exists
if [[ ! -d "$ENCRYPTED_DIR" ]]; then
  echo -e "${RED}Error: Encrypted directory not found: $ENCRYPTED_DIR${NC}" >&2
  exit 1
fi

# Create output directory if it doesn't exist (unless dry run)
if [[ "$DRY_RUN" == false ]]; then
  mkdir -p "$SECRETS_DIR"
fi

# Find and decrypt files
ENCRYPTED_FILES=$(find "$ENCRYPTED_DIR" -type f -name "*.enc" -o -name "*.age")
FILE_COUNT=$(echo "$ENCRYPTED_FILES" | grep -c . || echo "0")

if [[ "$FILE_COUNT" -eq 0 ]]; then
  echo -e "${YELLOW}No encrypted files found in $ENCRYPTED_DIR${NC}"
  exit 0
fi

echo -e "${GREEN}Found $FILE_COUNT encrypted file(s) to decrypt${NC}"
if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}DRY RUN MODE - No files will be actually decrypted${NC}"
fi
echo ""

DECRYPTED_COUNT=0
FAILED_COUNT=0

while IFS= read -r ENCRYPTED_FILE; do
  if [[ -z "$ENCRYPTED_FILE" ]]; then
    continue
  fi

  # Get relative path from encrypted dir
  REL_PATH="${ENCRYPTED_FILE#$ENCRYPTED_DIR/}"

  # Remove .enc or .age extension
  DECRYPTED_NAME="${REL_PATH%.enc}"
  DECRYPTED_NAME="${DECRYPTED_NAME%.age}"

  DECRYPTED_FILE="$SECRETS_DIR/$DECRYPTED_NAME"

  # Create subdirectories if needed
  DECRYPTED_DIR=$(dirname "$DECRYPTED_FILE")

  if [[ "$VERBOSE" == true ]] || [[ "$DRY_RUN" == true ]]; then
    echo "Decrypting: $REL_PATH → secrets/$DECRYPTED_NAME"
  fi

  if [[ "$DRY_RUN" == false ]]; then
    mkdir -p "$DECRYPTED_DIR"

    # Attempt decryption
    if age -d -i "$IDENTITY_FILE" -o "$DECRYPTED_FILE" "$ENCRYPTED_FILE" 2>/dev/null; then
      ((DECRYPTED_COUNT++))
      if [[ "$VERBOSE" == true ]]; then
        echo -e "  ${GREEN}✓ Success${NC}"
      fi
    else
      ((FAILED_COUNT++))
      echo -e "  ${RED}✗ Failed to decrypt: $REL_PATH${NC}" >&2
      echo -e "    ${YELLOW}Ensure your private key has access to this file${NC}" >&2
    fi
  fi
done <<< "$ENCRYPTED_FILES"

echo ""
if [[ "$DRY_RUN" == false ]]; then
  echo -e "${GREEN}Decryption complete!${NC}"
  echo "Successfully decrypted: $DECRYPTED_COUNT file(s)"
  if [[ "$FAILED_COUNT" -gt 0 ]]; then
    echo -e "${RED}Failed to decrypt: $FAILED_COUNT file(s)${NC}"
  fi
  echo ""
  echo -e "${YELLOW}⚠️  WARNING: Decrypted files are in $SECRETS_DIR${NC}"
  echo -e "${YELLOW}   These files contain sensitive data and should NOT be committed to git${NC}"
else
  echo "Would decrypt $FILE_COUNT file(s)"
fi
