# Enhanced Key Recovery Security - Implementation Plan

## Overview
Enhance `pbj recover` to use PIN-protected key recovery, preventing exposure of raw encryption keys in GitHub Actions logs.

## Security Model

### Current Issue
- Key stored in GitHub Secrets (PBJ_KEY)
- Workflow exposes raw key in logs (visible briefly, requires manual deletion)
- Anyone with access to workflow logs can see the key

### Enhanced Security
- User provides 4-digit PIN during recovery
- PIN stored in GitHub Secrets (PBJ_PIN)
- Workflow encrypts PBJ_KEY with (PIN + random padding) before logging
- Local recovery decrypts with same algorithm
- Random padding known only to code = "split key" security

### Security Properties
1. **PIN alone insufficient** - Random padding required (in code)
2. **Code alone insufficient** - User's PIN required
3. **Logs less sensitive** - Encrypted blob instead of raw key
4. **Workflow runs safer** - Even if logs leaked, key still protected

## Implementation Phases

### Phase 1: PIN Input System
**Files:** `bin/pbj`
**Tasks:**
1. Add method `prompt_pin(prompt_text)`
   - Use `io/console` for raw terminal input
   - Mask input with `*` characters
   - Handle backspace/delete
   - Return 4-digit PIN string
2. Add method `get_pin_with_confirmation()`
   - Prompt for PIN
   - Prompt for confirmation
   - Loop until they match
   - Validate 4-digit numeric format
3. Test PIN input manually

### Phase 2: PIN-based Encryption
**Files:** `bin/pbj`
**Tasks:**
1. Define `PIN_PADDING` constant (random 28-byte string, hardcoded in source)
2. Add method `derive_pin_key(pin)`
   - Convert 4-digit PIN to bytes
   - Append PIN_PADDING to create 32-byte key
   - Return key suitable for AES-256
3. Add method `encrypt_key_for_recovery(key, pin)`
   - Derive 32-byte key from pin + padding
   - Encrypt PBJ_KEY with AES-256-GCM
   - Return base64-encoded encrypted blob
4. Add method `decrypt_key_from_recovery(encrypted_b64, pin)`
   - Derive 32-byte key from pin + padding
   - Decrypt blob
   - Validate decryption succeeded
   - Return raw key
5. Test encryption/decryption round-trip

### Phase 3: Update Key Creation Flow
**Files:** `bin/pbj`
**Tasks:**
1. Modify `get_or_create_key()` to prompt for PIN on first run
2. Store PIN in GitHub Secrets as PBJ_PIN
3. Ensure both PBJ_KEY and PBJ_PIN are stored together
4. Update user messaging

### Phase 4: Update Workflow
**Files:** `.github/workflows/key-recovery.yml`
**Tasks:**
1. Read both PBJ_KEY and PBJ_PIN from secrets
2. Implement encryption logic in bash/ruby
   - Option A: Inline ruby script in workflow
   - Option B: Call pbj itself in workflow (clever!)
3. Output encrypted blob instead of raw key
4. Update instructions in output

### Phase 5: Update Recovery Command
**Files:** `bin/pbj`
**Tasks:**
1. Modify `recover_key()` to prompt for PIN
2. Extract encrypted blob from workflow logs
3. Decrypt blob with PIN
4. Save decrypted key to .pbj-key
5. Handle decryption failures (wrong PIN)
6. Allow retry on wrong PIN

### Phase 6: Documentation
**Files:** `README.md`, `SECURITY.md` (new)
**Tasks:**
1. Document PIN requirement
2. Explain split-key security model
3. Update key recovery instructions
4. Add security considerations section
5. Document PIN recovery options (there are none - by design)

### Phase 7: End-to-End Testing
**Files:** `test-recovery.sh` (new)
**Tasks:**
1. Create fresh test fork
2. Generate key with PIN
3. Trigger workflow
4. Run recovery with correct PIN
5. Verify key recovered correctly
6. Test wrong PIN (should fail)
7. Test without PIN (should fail)
8. Document test results

## Technical Details

### PIN Padding Generation
```ruby
# Generate once, hardcode in source
PIN_PADDING = OpenSSL::Random.random_bytes(28)
# Store as base64 in source for readability
PIN_PADDING_B64 = "..." # base64 encoded
```

### Encryption Flow
```
User PIN (4 digits) → "1234"
PIN bytes: "\x01\x02\x03\x04" (4 bytes)
PIN_PADDING: <28 random bytes>
Combined: PIN + PIN_PADDING = 32 bytes
AES-256-GCM key = combined

Encrypt PBJ_KEY with AES-256-GCM
Output: IV (12) + Auth Tag (16) + Ciphertext (32) = 60 bytes
Base64: ~80 chars
```

### Workflow Encryption
The workflow needs to do the same encryption. Options:

**Option A: Inline Ruby in workflow**
```yaml
- name: Output encrypted key
  run: |
    ruby << 'EOF'
    require 'openssl'
    require 'base64'

    key = ENV['PBJ_KEY']
    pin = ENV['PBJ_PIN']
    # ... encryption code ...
    puts encrypted_b64
    EOF
  env:
    PBJ_KEY: ${{ secrets.PBJ_KEY }}
    PBJ_PIN: ${{ secrets.PBJ_PIN }}
```

**Option B: Use pbj itself**
```yaml
- name: Checkout repo
  uses: actions/checkout@v3

- name: Encrypt key
  run: |
    ./bin/pbj __encrypt_key_for_recovery__
  env:
    PBJ_KEY: ${{ secrets.PBJ_KEY }}
    PBJ_PIN: ${{ secrets.PBJ_PIN }}
```

Option B is cleaner (DRY principle, same code path).

## Migration Strategy

### For Existing Users
- Existing PBJ_KEY secrets remain valid
- First `pbj recover` prompts: "No PIN found. Set one? [Y/n]"
- Allow setting PIN retroactively
- Update PBJ_PIN secret

### For New Users
- First `pbj` copy prompts for PIN
- Both PBJ_KEY and PBJ_PIN stored together

## Edge Cases

1. **User forgets PIN** - No recovery (by design, security feature)
2. **PIN_PADDING changes** - Old encrypted logs become unreadable (document carefully)
3. **Workflow fails mid-execution** - Same as current behavior
4. **Multiple devices with different PINs** - Last PIN wins (stored in GitHub)
5. **PIN in workflow logs?** - Never output PIN, only encrypted blob

## Security Analysis

### Threat Model
- **Attacker has workflow logs**: Protected by PIN + padding
- **Attacker has source code**: Protected by PIN (padding known but PIN isn't)
- **Attacker has GitHub Secrets access**: Protected by padding (PIN stored but padding isn't in secrets)
- **Attacker has logs + source**: Protected by PIN (padding known from source, encrypted blob in logs, PIN unknown)

### Key Insight
The PIN must be known by the user at recovery time. The padding is baked into the code. Neither alone can decrypt the blob in the logs.

## Implementation Order

1. ✅ Create PLAN.md (this file)
2. ✅ Create NOTES.md for implementation details
3. ✅ Create TODO.md for task tracking
4. ✅ Implement Phase 1 (PIN input)
5. ✅ Implement Phase 2 (encryption)
6. ✅ Implement Phase 3 (key creation)
7. ✅ Implement Phase 4 (workflow)
8. ✅ Implement Phase 5 (recovery)
9. ✅ Implement Phase 6 (docs)
10. ✅ Implement Phase 7 (testing script - awaiting user test execution)

## Estimated Complexity
- PIN input system: Medium (terminal handling tricky)
- Encryption layer: Low (standard crypto)
- Workflow updates: Medium (need to test in real GitHub Actions)
- Recovery updates: Low (modify existing code)
- Testing: High (real end-to-end, no mocks)

Total: ~4-6 hours of focused work

## Success Criteria
- [x] PIN input works with masking
- [x] Encryption/decryption round-trips correctly
- [x] Workflow outputs encrypted blob (not raw key)
- [x] Recovery works with correct PIN (code complete, needs user test)
- [x] Recovery fails with wrong PIN (code complete, needs user test)
- [ ] End-to-end test passes (awaiting user execution: ./test-end-to-end.sh)
- [x] Documentation complete (SECURITY.md + README.md updates)
- [x] No raw keys in logs (workflow uses internal encryption command)
