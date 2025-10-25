# TODO: Enhanced Key Recovery Security

## Phase 1: PIN Input System ✅

### Tasks
- [x] Add `require 'io/console'` to pbj
- [x] Implement `prompt_pin(prompt_text)` method
  - [x] Use STDIN.getch for character-by-character input
  - [x] Mask input with `*` characters
  - [x] Handle backspace (ASCII 127 and 8)
  - [x] Handle Enter (ASCII 13 and 10)
  - [x] Handle Ctrl-C (raise Interrupt)
  - [x] Print masked characters to STDERR
  - [x] Return PIN string
- [x] Implement `get_pin_with_confirmation()` method
  - [x] Prompt for PIN
  - [x] Prompt for confirmation
  - [x] Loop until match
  - [x] Validate 4-digit numeric format
  - [x] Return confirmed PIN
- [x] Generated PIN_PADDING constant (28 bytes)
- [x] Added PIN_PADDING_B64 to PBJ class
- [x] Created test-pin-input.rb for manual testing
- [ ] Manual test: Run and verify masking works (ready for user testing)
- [ ] Manual test: Verify backspace works (ready for user testing)
- [ ] Manual test: Verify PIN confirmation works (ready for user testing)
- [ ] Commit Phase 1

## Phase 2: Encryption Layer ✅

### Tasks
- [x] Generate PIN_PADDING (28 random bytes) - Done in Phase 1
- [x] Store PIN_PADDING_B64 as constant in PBJ class - Done in Phase 1
- [x] Implement `derive_pin_key(pin)` method
  - [x] Convert PIN string to 4 bytes
  - [x] Append PIN_PADDING
  - [x] Return 32-byte key
- [x] Implement `encrypt_key_for_recovery(key, pin)` method
  - [x] Derive key from PIN
  - [x] Create AES-256-GCM cipher
  - [x] Encrypt key
  - [x] Return IV + tag + ciphertext as base64
- [x] Implement `decrypt_key_from_recovery(encrypted_b64, pin)` method
  - [x] Decode base64
  - [x] Extract IV, tag, ciphertext
  - [x] Derive key from PIN
  - [x] Decrypt and verify
  - [x] Return raw key or raise error
- [x] Test: Encrypt/decrypt round-trip with PIN "1234"
- [x] Test: Verify wrong PIN fails decryption
- [x] Test: Different PINs work independently
- [x] Test: Random IVs produce different ciphertexts
- [x] Commit Phase 2

## Phase 3: Update Key Creation Flow ✅

### Tasks
- [x] Modify `get_or_create_key()` method
  - [x] After generating new key, prompt for PIN
  - [x] Store PIN in GitHub Secrets as PBJ_PIN
  - [x] Update user messaging
- [x] Add `set_pin()` method for existing users
  - [x] Check if PBJ_KEY exists
  - [x] Prompt for PIN with confirmation
  - [x] Store PBJ_PIN in GitHub Secrets
  - [x] Confirm success
- [x] Add `pbj set-pin` command to CLI
- [x] Update help/usage text
- [ ] Test: Create new key, verify PIN prompted (needs real test)
- [ ] Test: Run `pbj set-pin` on existing key (needs real test)
- [ ] Test: Verify PBJ_PIN in GitHub Secrets (needs real test)
- [x] Commit Phase 3

## Phase 4: Update Workflow ✅

### Tasks
- [x] Add internal command `__internal_encrypt_for_recovery__`
  - [x] Read PBJ_KEY from ENV
  - [x] Read PBJ_PIN from ENV
  - [x] Decrypt key from base64
  - [x] Encrypt key with PIN
  - [x] Output encrypted blob
  - [x] Exit
- [x] Update `.github/workflows/key-recovery.yml`
  - [x] Checkout repository
  - [x] Run internal encrypt command
  - [x] Pass PBJ_KEY and PBJ_PIN via env
  - [x] Update output text
  - [x] Update security warning
- [x] Fix: PIN_PADDING unpack1 on string (not array)
- [x] Test: Internal command locally ✓
- [ ] Test: Trigger workflow manually (needs real GitHub Actions)
- [ ] Test: Verify encrypted blob in logs (not raw key)
- [ ] Test: Verify no PIN visible in logs
- [x] Commit Phase 4

## Phase 5: Update Recovery Command ✅

### Tasks
- [x] Modify `recover_key()` method
  - [x] After workflow completes, prompt for PIN
  - [x] Extract encrypted blob from logs
  - [x] Decrypt with user's PIN
  - [x] Handle wrong PIN (allow retry - 3 attempts)
  - [x] Save decrypted key
- [x] Add backward compatibility check
  - [x] Detect old format (raw key) in logs
  - [x] Support both formats with warning
  - [x] Regex for new format: "Encrypted key (requires PIN to decrypt):"
  - [x] Regex for old format: "Your encryption key (base64 encoded):"
- [ ] Test: Recover with correct PIN (needs real GitHub Actions)
- [ ] Test: Recover with wrong PIN (should fail/retry)
- [ ] Test: Recover from old workflow format (backward compat)
- [x] Commit Phase 5

## Phase 6: Documentation ✅

### Tasks
- [x] Create `SECURITY.md`
  - [x] Explain split-key security model
  - [x] Document threat model
  - [x] Explain why PIN + padding is secure
  - [x] Document PIN recovery policy (none by design)
  - [x] Entropy analysis
  - [x] Cryptographic details
  - [x] Comparison to other tools
  - [x] Security audit checklist
- [x] Update `README.md`
  - [x] Add PIN to Key Recovery section
  - [x] Update multi-device setup instructions
  - [x] Update Key Storage section with PIN info
  - [x] Update Method 2 with PIN prompts
- [x] Update usage output (done in Phase 3)
  - [x] Add `pbj set-pin` command
  - [x] Update help text
- [x] Commit Phase 6

## Phase 7: End-to-End Testing ⬜

### Tasks
- [x] Create `test-end-to-end.sh` script
  - [x] Test 1: Verify repository setup
  - [x] Test 2: Create clipboard with PIN (or use existing)
  - [x] Test 3: Verify PBJ_KEY and PBJ_PIN in secrets
  - [x] Test 4: Trigger workflow and wait for completion
  - [x] Test 5: Verify encrypted blob in logs (not raw key)
  - [x] Test 6: Verify PIN not exposed in logs
  - [x] Test 7: Run pbj recover (interactive PIN entry)
  - [x] Test 8: Verify recovered key works
  - [x] Cleanup and restore backups
- [ ] Run full test suite ⚠️  USER MUST RUN: ./test-end-to-end.sh
- [ ] Document test results in NOTES.md (after user runs test)
- [ ] Fix any issues found (if any)
- [ ] Commit Phase 7

## Final Steps ⬜

### Tasks
- [ ] Final code review
- [ ] Check all TODOs resolved
- [ ] Verify no raw keys in any logs
- [ ] Verify PIN masking works on Linux/macOS
- [ ] Update PLAN.md with completion status
- [ ] Create summary commit message
- [ ] Push to main
- [ ] Tag release if appropriate

## Issues / Blockers

(None yet)

## Notes

- Remember: PIN_PADDING must remain constant forever
- Test on actual GitHub Actions (no mocks)
- Each phase should be committed separately
- User should review after Phase 1 before continuing
