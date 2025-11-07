# gh-lockbox: PIN-Protected Secret Recovery for GitHub

## Overview

Extract pbj's PIN-protected key recovery mechanism into a standalone GitHub CLI extension that can securely store and recover any secret via GitHub Actions workflows.

## Name: `gh-lockbox`

**Rationale:**
- Clear metaphor: a lockbox stores valuables securely
- Short, memorable, CLI-friendly
- Emphasizes security without being technical
- Natural verb usage: "lockbox your secrets"

## Core Concept

A GitHub CLI extension that:
1. Stores secrets in GitHub Secrets (encrypted at rest by GitHub)
2. Uses PIN-protected split-key encryption for recovery
3. Triggers GitHub Actions workflows to output encrypted blobs
4. Recovers secrets locally by decrypting with user's PIN
5. Never exposes raw secrets in logs or workflow outputs

## Use Cases

1. **Encryption Keys**: Recover keys across devices (pbj's current use)
2. **API Tokens**: Securely recover tokens for CI/CD setup
3. **SSH Keys**: Bootstrap SSH access on new machines
4. **Certificates**: Recover SSL/TLS certificates
5. **Config Files**: Secure recovery of sensitive configuration
6. **Database Credentials**: Safe recovery of connection strings
7. **Any Secret**: Generic secret storage/recovery with PIN protection

## Architecture

### Split-Key Security Model

```
User's PIN (4 digits) + Static Padding (28 bytes) = 32-byte AES Key
         ↓
Encrypts secret before logging to GitHub Actions
         ↓
Recovery: User provides PIN → Decryption → Original secret
```

**Security Properties:**
- PIN alone: insufficient (needs padding from code)
- Code alone: insufficient (needs user's PIN)
- Workflow logs: encrypted blob only (needs PIN to decrypt)
- 237 bits effective entropy (13.3 bits PIN + 224 bits padding)

### Components

1. **CLI Tool** (`gh-lockbox`)
   - Written in Ruby (reuse pbj's crypto code)
   - Installable as gh extension
   - Works with any GitHub repository

2. **GitHub Actions Workflow** (`.github/workflows/lockbox-recovery.yml`)
   - Manually triggered (workflow_dispatch)
   - Encrypts secret with PIN before output
   - One workflow per secret (parameterized)

3. **GitHub Secrets Storage**
   - `LOCKBOX_<NAME>_VALUE`: The actual secret
   - `LOCKBOX_<NAME>_PIN`: The user's PIN
   - Both write-only, secured by GitHub

## Command Interface

```bash
# Install extension
gh extension install ahoward/gh-lockbox

# Store a secret with PIN protection
gh lockbox store my-api-key
  → Prompts for secret value (hidden input)
  → Prompts for 4-digit PIN (masked with *)
  → Confirms PIN
  → Stores LOCKBOX_MY_API_KEY_VALUE and LOCKBOX_MY_API_KEY_PIN
  → Creates/updates workflow file
  → Output: ✓ Locked: my-api-key (recover with 'gh lockbox recover my-api-key')

# List stored secrets
gh lockbox list
  → Shows all LOCKBOX_* secrets in current repo
  → Output: my-api-key, db-password, ssl-cert (3 secrets)

# Recover a secret (on new device)
gh lockbox recover my-api-key
  → Triggers lockbox-recovery workflow (parameterized)
  → Waits for completion
  → Prompts for PIN (3 attempts)
  → Decrypts encrypted blob from logs
  → Outputs secret to STDOUT (or --output FILE)
  → Output: <secret-value>

# Update PIN for existing secret
gh lockbox repin my-api-key
  → Prompts for new PIN
  → Updates LOCKBOX_MY_API_KEY_PIN
  → Output: ✓ PIN updated for my-api-key

# Remove a secret
gh lockbox remove my-api-key
  → Confirms deletion
  → Removes GitHub Secrets
  → Removes workflow file
  → Output: ✓ Removed: my-api-key

# Help
gh lockbox help
  → Shows full usage and examples
```

## Workflow Design

### Single Parameterized Workflow

`.github/workflows/lockbox-recovery.yml`:

```yaml
name: Lockbox Recovery

on:
  workflow_dispatch:
    inputs:
      secret_name:
        description: 'Name of secret to recover'
        required: true
        type: string

jobs:
  recover:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Encrypt secret with PIN
        run: |
          # Use gh-lockbox's internal encryption command
          gh lockbox __internal_encrypt__ ${{ inputs.secret_name }}
        env:
          SECRET_VALUE: ${{ secrets[format('LOCKBOX_{0}_VALUE', inputs.secret_name)] }}
          SECRET_PIN: ${{ secrets[format('LOCKBOX_{0}_PIN', inputs.secret_name)] }}
```

**Benefits:**
- Single workflow for all secrets
- No per-secret workflow files cluttering repo
- Dynamic secret lookup via `secrets[format(...)]`

**Alternative:** Per-secret workflows (like pbj currently does)
- Simpler dynamic lookup
- More visible in Actions UI
- Trade-off: more files vs simpler logic

## Implementation Plan

### Phase 1: Extract Core Crypto (Week 1)

**Tasks:**
1. Create new repo: `ahoward/gh-lockbox`
2. Extract from pbj:
   - PIN input system (`prompt_pin`, `get_pin_with_confirmation`)
   - Encryption layer (`encrypt_with_pin`, `decrypt_with_pin`)
   - Split-key derivation (`derive_pin_key`)
3. Create Ruby gem structure
4. Write unit tests for crypto functions
5. Document security model

**Deliverable:** Working crypto library with tests

### Phase 2: CLI Interface (Week 2)

**Tasks:**
1. Implement `gh lockbox store <name>`
   - Secret input (hidden)
   - PIN input (masked)
   - Store to GitHub Secrets
2. Implement `gh lockbox list`
   - Query GitHub Secrets API
   - Filter for `LOCKBOX_*` pattern
3. Implement `gh lockbox remove <name>`
   - Confirm deletion
   - Remove from GitHub Secrets
4. Write integration tests
5. Create man page

**Deliverable:** Basic store/list/remove working

### Phase 3: Recovery System (Week 3)

**Tasks:**
1. Create workflow template
2. Implement `gh lockbox recover <name>`
   - Trigger workflow with parameter
   - Poll for completion
   - Parse encrypted blob from logs
   - Prompt for PIN
   - Decrypt and output
3. Implement `gh lockbox repin <name>`
4. Add retry logic (3 attempts)
5. Add verbose mode (`-v`)

**Deliverable:** Full recovery working end-to-end

### Phase 4: Polish & Release (Week 4)

**Tasks:**
1. Comprehensive documentation
2. Example use cases
3. Security audit
4. Performance optimization
5. Error handling improvements
6. README with quickstart
7. Submit to gh extension marketplace
8. Write blog post

**Deliverable:** Public release v1.0.0

## File Structure

```
ahoward/gh-lockbox/
├── bin/
│   └── gh-lockbox              # Main executable
├── lib/
│   ├── lockbox.rb              # Core library
│   ├── lockbox/
│   │   ├── crypto.rb           # Encryption/decryption
│   │   ├── pin.rb              # PIN input handling
│   │   ├── github.rb           # GitHub API interactions
│   │   ├── workflow.rb         # Workflow management
│   │   └── version.rb          # Version constant
├── templates/
│   └── lockbox-recovery.yml    # Workflow template
├── test/
│   ├── test_crypto.rb
│   ├── test_pin.rb
│   └── test_integration.rb
├── docs/
│   ├── SECURITY.md             # Security model
│   ├── USAGE.md                # Detailed usage
│   └── EXAMPLES.md             # Common use cases
├── README.md
├── LICENSE
└── gh-lockbox.gemspec
```

## Differences from pbj Implementation

### Improvements

1. **Generic Secret Storage**
   - pbj: hardcoded for encryption keys
   - lockbox: works with any secret

2. **Single Workflow**
   - pbj: separate workflow file
   - lockbox: parameterized workflow (optional)

3. **Better UX**
   - pbj: recovery embedded in clipboard tool
   - lockbox: dedicated purpose, clear commands

4. **Modular Design**
   - pbj: monolithic script
   - lockbox: proper gem structure, testable

5. **Multiple Secrets**
   - pbj: one key per repo
   - lockbox: unlimited secrets per repo

### Simplifications

1. **No Auto-Storage**
   - pbj: auto-stores key on first use
   - lockbox: explicit `store` command

2. **No Git Integration**
   - pbj: integrated with clipboard git commits
   - lockbox: standalone secret management

3. **Simpler Scope**
   - pbj: clipboard + key management + git + PIN
   - lockbox: ONLY secret storage/recovery

## Security Considerations

### Threat Model

**Protected Against:**
- ✅ Workflow log exposure (encrypted blobs)
- ✅ Secrets API read access (PIN required for decryption)
- ✅ Compromised GitHub Secrets (PIN not stored plaintext)
- ✅ Fork/clone attacks (secrets not in repo)

**NOT Protected Against:**
- ❌ Compromised GitHub account (attacker can read secrets)
- ❌ Compromised local machine (PIN entered on device)
- ❌ Keylogger (PIN typed by user)
- ❌ Malicious workflow modifications (can exfiltrate secrets)

### Best Practices

1. **PIN Strength**
   - Recommend 4+ digits
   - Consider alphanumeric PINs (future enhancement)
   - Document PIN != password (convenience/recovery balance)

2. **Padding Management**
   - PERMANENT static padding (never change)
   - Document in SECURITY.md
   - Include warning about backward compatibility

3. **Workflow Security**
   - Workflow file should be reviewed before use
   - Consider workflow approval requirements
   - Document trust model

4. **Secret Hygiene**
   - Delete workflow runs after recovery
   - Rotate secrets periodically
   - Use lockbox as backup, not primary storage

## Migration Path from pbj

Users of pbj can migrate their key recovery:

```bash
# In pbj repo
cat ~/.pbj/.pbj-key  # Copy this value

# Install gh-lockbox
gh extension install ahoward/gh-lockbox

# Store pbj key in lockbox
gh lockbox store pbj-encryption-key
# (paste the key value)
# (enter your pbj PIN)

# Later, recover on new device
gh lockbox recover pbj-encryption-key > ~/.pbj/.pbj-key
chmod 600 ~/.pbj/.pbj-key
```

## Extension Distribution

### Installation

```bash
# Install from GitHub
gh extension install ahoward/gh-lockbox

# Or from source (development)
git clone https://github.com/ahoward/gh-lockbox
cd gh-lockbox
gh extension install .

# Upgrade
gh extension upgrade lockbox

# Uninstall
gh extension remove lockbox
```

### Requirements

- GitHub CLI (`gh`) installed
- Ruby 2.7+ (for crypto operations)
- Git repository with GitHub Actions enabled
- GitHub account with repo access

## Future Enhancements

### v1.1: Multi-Repository Support

```bash
# Store secret globally (accessible from any repo)
gh lockbox store --global my-api-key

# Recover in any repo
gh lockbox recover my-api-key
```

### v1.2: Team Secrets

```bash
# Store with multiple PINs (each team member has own PIN)
gh lockbox store --team db-password
  → Prompt for PINs for alice, bob, carol
  → Any one PIN can recover
```

### v1.3: Secret Templates

```bash
# Store multiple related secrets as a template
gh lockbox template create aws-creds
  → Prompts for: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
  → Stores as bundle with single PIN

gh lockbox template recover aws-creds
  → Recovers all values
  → Outputs as env vars or JSON
```

### v1.4: Stronger Encryption Options

```bash
# Use passphrase instead of 4-digit PIN
gh lockbox store --passphrase my-important-key
  → Full entropy passphrase (not just 4 digits)
  → More secure, less convenient

# Use hardware security key
gh lockbox store --yubikey ssl-cert
  → PIN stored on YubiKey
  → Recovery requires physical key
```

### v1.5: Backup Export

```bash
# Export encrypted backup (offline storage)
gh lockbox export my-secrets.lockbox.enc
  → Encrypted file with all secrets
  → Can restore without GitHub access

gh lockbox import my-secrets.lockbox.enc
  → Restores to GitHub Secrets
```

## Success Metrics

**Adoption:**
- 100+ stars on GitHub in 3 months
- 10+ repos using it (beyond author)
- Featured in GitHub CLI marketplace

**Reliability:**
- 99%+ successful recovery rate
- <5 bug reports per month
- <1 security issue reported

**Community:**
- 5+ external contributors
- 10+ feature requests/discussions
- Integration in other tools (like pbj)

## Documentation Outline

### README.md
- Quick overview
- Installation
- 5-minute quickstart
- Common use cases
- Security notice
- Contributing

### SECURITY.md
- Detailed threat model
- Cryptographic implementation
- Split-key security explained
- PIN strength recommendations
- Known limitations
- Responsible disclosure

### USAGE.md
- Complete command reference
- All options and flags
- Advanced workflows
- Troubleshooting
- FAQ

### EXAMPLES.md
- Recovering encryption keys
- Storing API tokens
- SSH key bootstrap
- Certificate management
- Database credentials
- Multi-device workflows
- CI/CD integration

## Marketing/Announcement

**Tagline:** "Your secrets, locked tight. One PIN to recover."

**Tweet:**
> 🔐 gh-lockbox: PIN-protected secret recovery for GitHub
>
> Store secrets in GitHub Secrets, recover them anywhere with just your PIN. Uses split-key encryption—neither PIN nor code alone can decrypt.
>
> Perfect for: API keys, encryption keys, SSH keys, certs
>
> gh extension install ahoward/gh-lockbox

**Blog Post Title:**
"gh-lockbox: How We Built PIN-Protected Secret Recovery for GitHub Actions"

**Target Audience:**
- DevOps engineers managing secrets across environments
- Developers working on multiple machines
- Open source maintainers sharing access
- Security-conscious teams needing secret rotation
- Anyone using GitHub Actions for deployment

## Timeline

**Week 1:** Core crypto extraction + tests
**Week 2:** CLI interface (store/list/remove)
**Week 3:** Recovery system + workflows
**Week 4:** Polish, docs, release

**Target Release:** v1.0.0 in 4 weeks

## Questions to Resolve

1. **Workflow Strategy:** Single parameterized vs per-secret workflows?
   - Recommend: Single parameterized (cleaner)

2. **Secret Naming:** `LOCKBOX_*` prefix or dedicated namespace?
   - Recommend: `LOCKBOX_*` prefix (clear, grepable)

3. **Ruby Dependency:** Require Ruby or bundle as standalone binary?
   - Recommend: Require Ruby (simpler, gh extensions commonly do this)

4. **Pin Length:** Fixed 4 digits or configurable?
   - Recommend: Start with 4, add `--pin-length` flag in v1.1

5. **Workflow Location:** `.github/workflows/` or custom location?
   - Recommend: Standard `.github/workflows/` (GitHub convention)

## Success Criteria

✅ **v1.0.0 is successful if:**
1. Can store and recover arbitrary secrets
2. Works on Linux and macOS
3. Zero raw secrets in workflow logs
4. Comprehensive test coverage (>80%)
5. Clear documentation
6. No known security vulnerabilities
7. Positive community feedback

---

**Next Steps:**
1. Review and approve this plan
2. Create `ahoward/gh-lockbox` repository
3. Begin Phase 1: Extract crypto code
4. Set up testing infrastructure
5. Write v1.0.0 specification

**Author:** Claude + @ahoward
**Date:** 2025-11-04
**Status:** Proposal - Awaiting Review
