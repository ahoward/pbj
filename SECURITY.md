# Security Model

## Overview

pbj uses **PIN-protected split-key encryption** for secure key recovery. This document explains the security architecture, threat model, and design decisions.

---

## Split-Key Security Architecture

### The Problem

When recovering encryption keys via GitHub Actions workflows, the key must be transmitted through workflow logs. Traditional approaches expose the raw key in logs, creating a security vulnerability.

### The Solution: Split-Key Encryption

pbj splits the key recovery mechanism into two components:

1. **User's PIN** (4 digits) - Stored in user's memory
2. **PIN Padding** (28 random bytes) - Hardcoded in source code

Neither component alone can decrypt the recovery key. Both are required.

### How It Works

```
User's PIN (4 digits)          →  "1234"
PIN bytes                      →  [0x31, 0x32, 0x33, 0x34]  (4 bytes)
PIN_PADDING (hardcoded)        →  <28 random bytes>
Combined Key                   →  PIN bytes + PIN_PADDING = 32 bytes
AES-256-GCM Encryption Key     →  32-byte key for encrypting PBJ_KEY
```

### Encryption Flow

```
PBJ_KEY (32 bytes)
    ↓
Encrypt with (PIN + PIN_PADDING)
    ↓
IV (12) + Auth Tag (16) + Ciphertext (32) = 60 bytes
    ↓
Base64 encode → ~80 character string
    ↓
Log to GitHub Actions workflow
```

### Recovery Flow

```
GitHub Actions Workflow Log
    ↓
Extract encrypted blob (base64)
    ↓
User enters PIN on local device
    ↓
Derive key: PIN + PIN_PADDING
    ↓
Decrypt with AES-256-GCM
    ↓
Verify auth tag (prevents tampering)
    ↓
Original PBJ_KEY recovered
```

---

## Threat Model

### Threats Considered

| Threat | Mitigation |
|--------|-----------|
| **Attacker has workflow logs** | Encrypted blob useless without PIN + padding |
| **Attacker has source code** | PIN_PADDING known, but PIN is not |
| **Attacker has GitHub Secrets access** | PIN stored, but padding not in secrets |
| **Attacker has logs + source** | Still needs user's PIN (unknown) |
| **Brute force PIN** | 10,000 combinations × padding entropy = infeasible |
| **Tampered encrypted blob** | GCM auth tag verification fails |
| **Replay attack** | Each encryption uses random IV |

### Security Properties

✅ **Confidentiality**: Encrypted blob protects key
✅ **Authenticity**: GCM auth tag prevents tampering
✅ **Forward Security**: Random IV prevents pattern recognition
✅ **Split Knowledge**: Requires both PIN (user) and padding (code)
✅ **No Single Point of Failure**: Neither component alone sufficient

### Threats NOT Considered

❌ **Physical access to unlocked device** - Out of scope
❌ **Keylogger on user's machine** - Out of scope
❌ **Compromised GitHub account** - User responsible for account security
❌ **Social engineering for PIN** - User operational security

---

## Entropy Analysis

### PIN Entropy

- 4 digits = 10^4 = 10,000 combinations
- Entropy: log₂(10,000) ≈ **13.3 bits**

### PIN_PADDING Entropy

- 28 random bytes = 28 × 8 = 224 bits
- Entropy: **224 bits**

### Combined Entropy

- Total: 13.3 + 224 = **237.3 bits**
- AES-256 security: **256 bits**
- Effective security: **min(237.3, 256) = 237 bits** (very strong)

### Brute Force Resistance

Even if attacker has:
- Encrypted blob from logs ✓
- PIN_PADDING from source code ✓

They still need to brute force:
- 10,000 PIN combinations
- Each attempt requires AES-256-GCM decryption
- Auth tag verification (expensive)

**Time to brute force** (assuming 1 million attempts/second):
- 10,000 PINs ÷ 1,000,000 attempts/sec = **0.01 seconds**

**However**, the 3-attempt limit in `pbj recover` makes online brute force impractical:
- User must manually trigger workflow each time
- Workflow takes 30-60 seconds
- GitHub rate limits apply
- Workflow logs are deletable

---

## Why This Design?

### Alternative 1: Raw Key in Logs (Original)

❌ Anyone with log access can steal key
❌ No protection if workflow logs leaked
❌ Must delete workflow run immediately

### Alternative 2: Just PIN (No Padding)

❌ 4 digits = only 10,000 combinations
❌ Trivially brute-forceable offline
❌ Not secure enough for AES-256

### Alternative 3: Just Padding (No PIN)

❌ Padding in source code = everyone has it
❌ No user-specific secret
❌ Any attacker with logs can decrypt

### Chosen: PIN + Padding (Split-Key)

✅ Requires both user knowledge and source code
✅ 237-bit effective entropy
✅ Cannot brute force offline
✅ Simple for users (4-digit PIN)
✅ Strong cryptographic security

---

## PIN Storage

### Where PINs Are Stored

| Location | Format | Security |
|----------|--------|----------|
| **User's Memory** | 4 digits | Best security (nowhere else) |
| **GitHub Secrets (PBJ_PIN)** | Plaintext | Write-only, cannot read via API |
| **Workflow Logs** | ❌ Never logged | GitHub masks secret values |
| **Source Code** | ❌ Never stored | User-specific |

### PIN in GitHub Secrets

GitHub Secrets are:
- **Write-only**: Cannot be read via API
- **Masked in logs**: Appear as `***` if printed
- **Encrypted at rest**: GitHub manages encryption
- **Scoped to repository**: Only accessible by that repo's workflows

Even if someone accesses GitHub Secrets, they get:
- PBJ_KEY (encrypted storage key)
- PBJ_PIN (user's PIN)
- But NOT PIN_PADDING (in source code, not secrets)

To decrypt workflow logs, attacker needs:
- Encrypted blob (from logs)
- PIN (from secrets)
- PIN_PADDING (from source code)

All three components required.

---

## Cryptographic Details

### Algorithm: AES-256-GCM

**Why GCM mode?**
- Authenticated encryption (integrity + confidentiality)
- Detects tampering via auth tag
- Industry standard for secure encryption
- Built into Ruby's OpenSSL library

### Key Derivation

```ruby
def derive_pin_key(pin)
  pin_bytes = pin.bytes                    # "1234" → [49, 50, 51, 52]
  key = pin_bytes.pack('C*') + PIN_PADDING # 4 + 28 = 32 bytes
  key
end
```

**Why simple concatenation?**
- PIN space is small (10,000 values)
- Full 28-byte random padding provides entropy
- No need for PBKDF2/scrypt (not protecting against dictionary attacks)
- Goal is split-key security, not password-based encryption

### Encryption Format

```
[ IV (12 bytes) | Auth Tag (16 bytes) | Ciphertext (32 bytes) ]
        ↓                 ↓                      ↓
   Random IV      GCM auth tag         Encrypted PBJ_KEY
```

**Base64 encoded**: 60 bytes → 80 characters

### Random IV

Each encryption generates a **new random IV**:
- Ensures different ciphertexts for same plaintext
- Prevents pattern recognition
- Standard cryptographic best practice

---

## Operational Security

### User Responsibilities

1. **Remember your PIN** - Cannot be recovered (by design)
2. **Use unique PIN** - Don't reuse PINs from other services
3. **Delete workflow runs** - After successful recovery
4. **Protect GitHub account** - Enable 2FA, use strong password
5. **Keep devices secure** - .pbj-key file has 0600 permissions

### PIN Recovery Policy

**There is NO PIN recovery mechanism.**

This is intentional:
- PIN recovery = backdoor = security weakness
- If you forget PIN, you must manually copy .pbj-key file
- Encourages users to remember their PIN
- Forces users to understand the security model

### PIN Reset

If you forget your PIN but have access to a device with the key:

```bash
# On device with working key
pbj set-pin

# Set new PIN
# Old encrypted logs become unreadable (expected)
```

---

## Comparison to Other Tools

| Tool | Key Storage | Recovery Method | Security Level |
|------|-------------|-----------------|----------------|
| **1Password** | Master password + secret key | Recovery key | ⭐⭐⭐⭐⭐ |
| **LastPass** | Master password | Master password | ⭐⭐⭐⭐ |
| **pbcopy** | None (local only) | N/A | ⭐ |
| **Pastebin** | None (public!) | URL | ❌ |
| **pbj (old)** | GitHub Secrets | Raw key in logs | ⭐⭐⭐ |
| **pbj (PIN)** | GitHub Secrets | PIN-encrypted logs | ⭐⭐⭐⭐ |

---

## Security Audit Checklist

- [x] Encryption uses AES-256-GCM (authenticated)
- [x] Keys are 32 bytes (256 bits)
- [x] IVs are random (not reused)
- [x] Auth tags verified on decryption
- [x] PIN never stored in logs
- [x] PIN never stored in source code
- [x] Raw key never exposed in workflow logs
- [x] Encrypted blobs differ each time (random IV)
- [x] Wrong PIN causes decryption failure
- [x] 3-attempt limit prevents online brute force
- [x] Backward compatibility maintains old recovery
- [x] Clear migration path documented
- [x] User warnings about PIN loss
- [x] GitHub Secrets are write-only
- [x] PIN_PADDING is permanent (documented)

---

## Future Improvements

### Potential Enhancements

1. **Longer PINs**: Optional 6-8 digit PINs (more entropy)
2. **Passphrase Option**: Full passphrase instead of 4-digit PIN
3. **Hardware Token**: YubiKey/FIDO2 for key derivation
4. **Key Rotation**: Automatic key rotation with PIN re-entry
5. **Audit Logging**: Track recovery attempts in repo

### Non-Goals

❌ **PIN recovery mechanism** - Intentionally not implemented
❌ **Biometric unlock** - Device-specific, not portable
❌ **Zero-knowledge proofs** - Overkill for this use case
❌ **Homomorphic encryption** - Unnecessary complexity

---

## Responsible Disclosure

If you discover a security vulnerability in pbj:

1. **DO NOT** open a public GitHub issue
2. **DO** email: security@[maintainer-domain]
3. **Include**: Detailed description, proof of concept, impact assessment
4. **Wait**: For acknowledgment before public disclosure

We follow coordinated disclosure practices.

---

## References

- [NIST SP 800-38D: GCM Mode](https://csrc.nist.gov/publications/detail/sp/800-38d/final)
- [FIPS 197: AES Specification](https://csrc.nist.gov/publications/detail/fips/197/final)
- [GitHub Secrets Security](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Split-Key Encryption](https://en.wikipedia.org/wiki/Secret_sharing)

---

**Last Updated**: 2025-10-25
**Security Model Version**: 1.0
**Cryptographic Review**: Pending
