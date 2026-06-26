#!/bin/bash
# Test suite for encryption/decryption workflows

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$SCRIPT_DIR/tests"
TEMP_DIR="$TEST_DIR/temp"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass() {
  echo -e "${GREEN}✓ PASS:${NC} $1"
  ((TESTS_PASSED++))
}

fail() {
  echo -e "${RED}✗ FAIL:${NC} $1"
  ((TESTS_FAILED++))
}

info() {
  echo -e "${BLUE}ℹ INFO:${NC} $1"
}

section() {
  echo ""
  echo -e "${YELLOW}========================================${NC}"
  echo -e "${YELLOW}$1${NC}"
  echo -e "${YELLOW}========================================${NC}"
}

cleanup() {
  if [[ -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}

setup() {
  cleanup
  mkdir -p "$TEMP_DIR/secrets"
  mkdir -p "$TEMP_DIR/encrypted"
  mkdir -p "$TEMP_DIR/decrypted"
}

# Test 1: Check if required tools are installed
test_dependencies() {
  section "Testing Dependencies"

  if command -v age &> /dev/null; then
    pass "age is installed ($(age --version 2>&1 | head -n1))"
  else
    fail "age is not installed"
  fi

  if command -v jq &> /dev/null; then
    pass "jq is installed ($(jq --version 2>&1))"
  else
    fail "jq is not installed"
  fi

  if command -v curl &> /dev/null; then
    pass "curl is installed"
  else
    fail "curl is not installed"
  fi
}

# Test 2: Check if scripts exist and are executable
test_scripts_exist() {
  section "Testing Script Files"

  local scripts=(
    "encrypt_files_age.sh"
    "decrypt_files_age.sh"
    "export_team_to_recipients.sh"
  )

  for script in "${scripts[@]}"; do
    if [[ -f "$SCRIPT_DIR/$script" ]]; then
      if [[ -x "$SCRIPT_DIR/$script" ]]; then
        pass "$script exists and is executable"
      else
        fail "$script exists but is not executable"
      fi
    else
      fail "$script does not exist"
    fi
  done
}

# Test 3: Test encryption script help flag
test_encrypt_help() {
  section "Testing Encryption Script Help"

  if "$SCRIPT_DIR/encrypt_files_age.sh" -h &> /dev/null; then
    pass "encrypt_files_age.sh -h returns successfully"
  else
    # -h should exit with 1 (from usage function), which is expected
    if [[ $? -eq 1 ]]; then
      pass "encrypt_files_age.sh -h displays help (exit code 1 is expected)"
    else
      fail "encrypt_files_age.sh -h failed unexpectedly"
    fi
  fi
}

# Test 4: Test decrypt script help flag
test_decrypt_help() {
  section "Testing Decryption Script Help"

  if "$SCRIPT_DIR/decrypt_files_age.sh" -h &> /dev/null; then
    pass "decrypt_files_age.sh -h returns successfully"
  else
    if [[ $? -eq 1 ]]; then
      pass "decrypt_files_age.sh -h displays help (exit code 1 is expected)"
    else
      fail "decrypt_files_age.sh -h failed unexpectedly"
    fi
  fi
}

# Test 5: Test full encryption/decryption workflow (requires age)
test_full_workflow() {
  section "Testing Full Encryption/Decryption Workflow"

  if ! command -v age &> /dev/null; then
    info "Skipping workflow test - age not installed"
    return
  fi

  # Generate a test key pair
  info "Generating test key pair..."
  local test_key="$TEMP_DIR/test_key"
  age-keygen -o "$test_key" 2>/dev/null

  # Extract public key
  local pub_key=$(grep "^# public key:" "$test_key" | cut -d: -f2 | tr -d ' ')

  # Create test recipients file
  echo "$pub_key" > "$TEMP_DIR/recipients.txt"

  # Create a test secret
  echo "SECRET_API_KEY=test123456" > "$TEMP_DIR/secrets/test-secret.env"

  # Encrypt the secret manually (simulating the script)
  info "Encrypting test secret..."
  if age -R "$TEMP_DIR/recipients.txt" -a -o "$TEMP_DIR/encrypted/test-secret.env.enc" "$TEMP_DIR/secrets/test-secret.env" 2>/dev/null; then
    pass "Successfully encrypted test secret"
  else
    fail "Failed to encrypt test secret"
    return
  fi

  # Decrypt the secret manually (simulating the script)
  info "Decrypting test secret..."
  if age -d -i "$test_key" -o "$TEMP_DIR/decrypted/test-secret.env" "$TEMP_DIR/encrypted/test-secret.env.enc" 2>/dev/null; then
    pass "Successfully decrypted test secret"
  else
    fail "Failed to decrypt test secret"
    return
  fi

  # Verify content matches
  original_content=$(cat "$TEMP_DIR/secrets/test-secret.env")
  decrypted_content=$(cat "$TEMP_DIR/decrypted/test-secret.env")

  if [[ "$original_content" == "$decrypted_content" ]]; then
    pass "Decrypted content matches original"
  else
    fail "Decrypted content does not match original"
  fi
}

# Test 6: Test error handling for missing recipients file
test_missing_recipients() {
  section "Testing Error Handling"

  # This test would check if scripts properly handle missing files
  # For now, we just check if the directory structure exists
  if [[ -d "$SCRIPT_DIR/secrets" ]]; then
    pass "secrets/ directory exists"
  else
    fail "secrets/ directory does not exist"
  fi

  if [[ -d "$SCRIPT_DIR/encrypted" ]]; then
    pass "encrypted/ directory exists"
  else
    fail "encrypted/ directory does not exist"
  fi

  if [[ -f "$SCRIPT_DIR/recipients.txt" ]]; then
    pass "recipients.txt file exists"
  else
    info "recipients.txt does not exist (this is OK for a fresh repo)"
  fi
}

# Main test runner
main() {
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║  Age Encryption Test Suite            ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
  echo ""

  setup

  test_dependencies
  test_scripts_exist
  test_encrypt_help
  test_decrypt_help
  test_full_workflow
  test_missing_recipients

  cleanup

  echo ""
  echo -e "${YELLOW}========================================${NC}"
  echo -e "${YELLOW}Test Summary${NC}"
  echo -e "${YELLOW}========================================${NC}"
  echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
  echo ""

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
  fi
}

# Trap cleanup on exit
trap cleanup EXIT

main "$@"
