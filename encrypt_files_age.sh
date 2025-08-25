#!/bin/bash
# Encrypt all files to ciphertexts

# Get current dir
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"


# Directory containing plaintext secrets
SECRETS_DIR="$SCRIPT_DIR/secrets"
# Output directory for encrypted secrets
ENCRYPTED_DIR="$SCRIPT_DIR/encrypted"

ENCRYPT_SUFFIX=".enc"
# Create output directory if it doesn't exist
mkdir -p "$ENCRYPTED_DIR"

for FILE in "$SECRETS_DIR"/*; do
  if [[ -f "$FILE" ]]; then
    BASE_NAME=$(basename "$FILE")
    ENCRYPTED_FILE="$ENCRYPTED_DIR/${BASE_NAME}${ENCRYPT_SUFFIX}"
    echo "BASE_NAME:" "$BASE_NAME"
    echo "ENCRYPTED_FILE: $ENCRYPTED_FILE"
    age -R recipients.txt -a -o "$ENCRYPTED_FILE" "$FILE"
  fi
done

rm -rf ${SECRETS_DIR}/*
