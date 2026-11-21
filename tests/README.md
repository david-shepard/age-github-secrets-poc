# Test Suite

This directory contains tests for the age-secrets-poc scripts.

## Running Tests

```bash
# Run all tests
./tests/test_encryption.sh
```

## Test Coverage

The test suite currently covers:

1. **Dependency checks** - Verifies that required tools (`age`, `jq`, `curl`) are installed
2. **Script existence** - Ensures all main scripts exist and are executable
3. **Help flags** - Tests that `-h` flags work properly
4. **Full workflow** - Tests complete encryption/decryption cycle with a test key pair
5. **Error handling** - Verifies directory structure and basic error conditions

## Test Structure

```
tests/
├── README.md              # This file
├── test_encryption.sh     # Main test suite
└── temp/                  # Temporary directory (auto-created/cleaned)
```

## Adding New Tests

To add a new test:

1. Create a new function named `test_<description>()`
2. Use the helper functions: `pass()`, `fail()`, `info()`, `section()`
3. Add the function call to `main()` in test_encryption.sh

Example:
```bash
test_my_feature() {
  section "Testing My Feature"
  
  if [[ condition ]]; then
    pass "Feature works correctly"
  else
    fail "Feature failed"
  fi
}
```

## CI/CD Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions usage
- name: Run tests
  run: ./tests/test_encryption.sh
```

## Future Test Ideas

- Test with multiple keys/recipients
- Test nested directory encryption
- Test invalid key handling
- Test concurrent encryption/decryption
- Integration tests with actual GitHub API (mocked)
- Performance tests with large files
- Security tests for proper file permissions
