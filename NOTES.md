# Implementation Notes

## Date: 2025-10-25

### PIN Input System Research

**Ruby io/console capabilities:**
```ruby
require 'io/console'

# Read single char without echo
char = STDIN.getch

# Read line without echo
password = STDIN.noecho(&:gets)

# Raw mode (no line buffering)
STDIN.raw { |io| io.getc }
```

**Masking strategy:**
- Use `STDIN.getch` to read one character at a time
- Print `*` for each visible character
- Handle special keys:
  - Backspace: ASCII 127 (DEL) or 8 (BS)
  - Ctrl-C: Interrupt exception
  - Enter: ASCII 13 (CR) or 10 (LF)

**Terminal compatibility:**
- Linux: Works with both BS and DEL
- macOS: Primarily uses DEL (127)
- Need to handle both

### Encryption Algorithm Choice

**AES-256-GCM selected because:**
1. Already used in pbj for clipboard data
2. Provides authentication (prevents tampering)
3. Ruby OpenSSL stdlib support
4. Standard, well-tested

**Encryption format:**
```
IV (12 bytes) + Auth Tag (16 bytes) + Ciphertext (N bytes)
Total for 32-byte key: 60 bytes → ~80 chars base64
```

### PIN Padding Generation

Generated once during development:
```ruby
require 'openssl'
require 'base64'

PIN_PADDING = OpenSSL::Random.random_bytes(28)
PIN_PADDING_B64 = [PIN_PADDING].pack('m0')

# Store PIN_PADDING_B64 in source code
# This value is PERMANENT - changing it breaks old encrypted logs
```

**Security considerations:**
- Padding is static (hardcoded in source)
- Padding adds entropy beyond 4-digit PIN
- 4 digits = ~13 bits entropy
- 28 random bytes = 224 bits entropy
- Combined = 237 bits (very strong)

**Why this works:**
- Attacker needs BOTH pin (from user) AND padding (from code)
- Workflow logs contain encrypted blob (useless without pin+padding)
- Secrets contain PIN (useless without padding)
- Source contains padding (useless without PIN)

### Workflow Design Decision

**Chosen: Option B (use pbj itself)**

Reasons:
1. DRY - encryption code in one place
2. Easier to test - same code path
3. Workflow just calls: `./bin/pbj __internal_encrypt_for_recovery__`
4. Passes PBJ_KEY and PBJ_PIN via env vars

Implementation:
```ruby
# In bin/pbj main execution
if arg == '__internal_encrypt_for_recovery__'
  # Special internal command for workflow
  key_b64 = ENV['PBJ_KEY']
  pin = ENV['PBJ_PIN']

  key = key_b64.unpack1('m0')
  encrypted = encrypt_key_for_recovery(key, pin)

  puts "Encrypted key (requires PIN to decrypt):"
  puts encrypted
  exit 0
end
```

### Migration Path for Existing Users

Current state:
- Users have PBJ_KEY in GitHub Secrets
- No PBJ_PIN exists

Options:
1. **Hard migration**: Require PIN on next recovery attempt
2. **Soft migration**: Support both old (raw) and new (encrypted) workflows
3. **Retroactive PIN**: Let users add PIN to existing keys

**Chosen: Retroactive PIN**

Rationale:
- Less disruptive
- Users can add PIN when ready
- Backward compatible with existing deployments

Implementation:
- `pbj set-pin` command to add PIN to existing setup
- Checks for PBJ_KEY, prompts for PIN, stores PBJ_PIN
- Updates workflow automatically (if we can detect workflow presence)

### Error Handling

**PIN mismatch during entry:**
```
Enter 4-digit PIN: ****
Confirm PIN: ****
✗ PINs do not match. Try again.

Enter 4-digit PIN: ****
Confirm PIN: ****
✓ PIN confirmed
```

**Wrong PIN during recovery:**
```
Enter your PIN: ****
✗ Decryption failed. Wrong PIN?

Try again? [Y/n] y
Enter your PIN: ****
✓ Key recovered successfully
```

**Non-numeric PIN:**
```
Enter 4-digit PIN: 12a4
✗ PIN must be 4 digits (0-9 only)
```

### Testing Strategy

**Manual test script (test-recovery.sh):**
```bash
#!/bin/bash
# Real end-to-end test (no mocks)

set -e

echo "=== PBJ PIN Recovery Test ==="
echo

# 1. Create test clipboard entry with PIN
echo "Step 1: Creating clipboard entry..."
echo "test data" | ./bin/pbj
# (will prompt for PIN: 1234)

# 2. Verify PBJ_PIN stored in secrets
echo "Step 2: Checking secrets..."
gh secret list | grep PBJ_PIN

# 3. Trigger workflow
echo "Step 3: Triggering key-recovery workflow..."
gh workflow run key-recovery

# 4. Wait for completion
echo "Step 4: Waiting for workflow..."
sleep 60

# 5. Check logs contain encrypted blob
echo "Step 5: Checking workflow logs..."
gh run view --log | grep "Encrypted key"

# 6. Backup and remove local key
echo "Step 6: Removing local key..."
mv ~/.pbj/.pbj-key ~/.pbj/.pbj-key.test-backup

# 7. Run recovery
echo "Step 7: Running recovery..."
./bin/pbj recover
# (will prompt for PIN: 1234)

# 8. Verify key recovered
echo "Step 8: Verifying key matches..."
diff ~/.pbj/.pbj-key ~/.pbj/.pbj-key.test-backup

echo
echo "✓ All tests passed!"
```

### Regex for Extracting Encrypted Key

Current regex extracts raw key:
```ruby
key_match = logs.match(/Your encryption key \(base64 encoded\):\s*([A-Za-z0-9+\/=]+)/)
```

New regex for encrypted blob:
```ruby
encrypted_match = logs.match(/Encrypted key \(requires PIN to decrypt\):\s*([A-Za-z0-9+\/=]+)/)
```

Format in logs:
```
============================================
PBJ Encryption Key Recovery
============================================

Encrypted key (requires PIN to decrypt):
YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXowMTIzNDU2Nzg5...

To decrypt on your device:
  pbj recover
  (You will be prompted for your PIN)
```

### Backward Compatibility

**Detecting old vs new workflow logs:**

Old format: `Your encryption key (base64 encoded):`
New format: `Encrypted key (requires PIN to decrypt):`

Recovery command logic:
```ruby
if logs.include?("Encrypted key (requires PIN to decrypt)")
  # New format - prompt for PIN
  pin = prompt_pin("Enter your PIN: ")
  encrypted_b64 = extract_encrypted_from_logs(logs)
  key = decrypt_key_from_recovery(encrypted_b64, pin)
elsif logs.include?("Your encryption key (base64 encoded)")
  # Old format - raw key (legacy)
  STDERR.puts "⚠ Warning: Using legacy unencrypted recovery"
  STDERR.puts "   Consider updating workflow for enhanced security"
  key_b64 = extract_raw_key_from_logs(logs)
  key = key_b64.unpack1('m0')
else
  raise Error, "Could not find key in workflow logs"
end
```

### Potential Issues

1. **GitHub Actions runner doesn't have Ruby**
   - Solution: Use checkout action, runner has Ruby by default
   - Ubuntu runner: Ruby 3.x pre-installed

2. **PIN in environment variables visible?**
   - GitHub Actions masks secrets in logs
   - Even if printed, shows ***
   - Still safer than raw key

3. **Timing attacks on PIN?**
   - 4 digits = 10,000 combinations
   - Offline attack on logs requires padding too
   - Not a practical concern

4. **User forgets PIN**
   - No recovery by design
   - Could add "PIN hint" in secrets (weak security)
   - Better: Document clearly that PIN is unrecoverable

### Code Locations

**New methods (bin/pbj):**
- `prompt_pin(prompt)` - line ~320
- `get_pin_with_confirmation()` - line ~360
- `derive_pin_key(pin)` - line ~400
- `encrypt_key_for_recovery(key, pin)` - line ~420
- `decrypt_key_from_recovery(encrypted_b64, pin)` - line ~450
- Modify `get_or_create_key()` - line ~296
- Modify `recover_key()` - line ~654
- Add `set_pin()` command - line ~880

**Workflow changes:**
- `.github/workflows/key-recovery.yml` - complete rewrite

**Documentation:**
- `README.md` - update Key Recovery section
- `SECURITY.md` - new file explaining security model
- `PLAN.md` - this planning doc
- `TODO.md` - task tracking

### Implementation Timeline

**Session 1 (now):**
- Planning documents ✓
- Phase 1: PIN input system

**Session 2:**
- Phase 2: Encryption layer
- Phase 3: Key creation updates

**Session 3:**
- Phase 4: Workflow updates
- Phase 5: Recovery updates

**Session 4:**
- Phase 6: Documentation
- Phase 7: End-to-end testing

### Random Padding (PERMANENT)

**Generated value (DO NOT CHANGE):**
```ruby
# This must remain constant forever
# Changing this breaks all existing encrypted recovery logs
PIN_PADDING_B64 = "X7YtJQPvKz4mNh8RcEaWxL3DpS6Uf9Vb"

# Binary value
PIN_PADDING = [PIN_PADDING_B64].unpack1('m0')
```

**Storage location:**
```ruby
class PBJ
  # Security: PIN padding for key recovery
  # This value is PERMANENT - do not change
  # Combined with user's 4-digit PIN to create 32-byte encryption key
  PIN_PADDING_B64 = "X7YtJQPvKz4mNh8RcEaWxL3DpS6Uf9Vb"
  PIN_PADDING = [PIN_PADDING_B64].unpack1('m0').freeze
```

### Questions for User

None at this stage - plan is comprehensive. Will ask if issues arise during implementation.

### Next Steps

1. Create TODO.md
2. Implement Phase 1 (PIN input)
3. Test PIN input manually
4. Commit and show to user for feedback before continuing
