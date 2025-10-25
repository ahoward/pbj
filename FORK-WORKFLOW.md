# Fork Workflow & Key Management

## The Fork Problem

When `ahoward` uses this repo, it will contain his encrypted clipboard data. When you fork it, you get:
- ✅ The code (`bin/pbj`)
- ✅ His encrypted data (`data/*.enc`) ← **Problem!**
- ❌ NOT his encryption key (stored in GitHub Secrets)

## The Solution: Key Fingerprinting

### How It Works

**On Copy:**
```ruby
manifest = {
  timestamp: Time.now.to_i,
  chunks: 2,
  preview: "my clipboard data...",
  key_fingerprint: "a1b2c3d4e5f6g7h8"  # SHA256(key)[0..15]
}
```

**On Paste:**
```ruby
# 1. Read manifest
manifest = JSON.parse(File.read('data/manifest.json'))

# 2. Check fingerprint
if manifest['key_fingerprint'] != SHA256(my_key)[0..15]
  # MISMATCH! This data was encrypted with a different key
  handle_key_mismatch()
end
```

### Auto-Cleanup on Mismatch

When a key mismatch is detected:

```
⚠ KEY MISMATCH DETECTED
============================================================
The clipboard data was encrypted with a different key.

This usually happens when you:
  1. Forked someone else's repo (contains their data)
  2. Cloned on a new device (different key)
  3. Deleted your encryption key

Data fingerprint: a1b2c3d4e5f6g7h8
Your fingerprint:  z9y8x7w6v5u4t3s2

🗑️  Clearing incompatible data...
✓ Data cleared. You can now start using pbj with your key.
```

**What happens:**
1. Deletes `data/` directory
2. Creates fresh empty `data/`
3. Commits: `"clear incompatible clipboard data (key mismatch)"`
4. Pushes to your fork

**Result:** Your fork now has zero data, ready for YOUR clipboard with YOUR key.

## Fork Workflow

### First Time Setup

```bash
# 1. Fork ahoward/pbj on GitHub
#    Creates: https://github.com/username/pbj

# 2. Clone your fork
git clone git@github.com:username/pbj.git ~/.pbj
cd ~/.pbj

# 3. Add to PATH
echo 'export PATH="$HOME/.pbj/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 4. First paste will detect mismatch and auto-clear
pbj  # Triggers key mismatch detection → auto-cleanup

# 5. Start using normally
echo "my first clipboard" | pbj
pbj  # Works!
```

### Multi-Device Setup

**Device 1 (already set up):**
```bash
echo "test" | pbj  # Creates key, stores in GitHub Secrets
```

**Device 2 (new device):**
```bash
# Same fork, different device
git clone git@github.com:username/pbj.git ~/.pbj
export PATH="$HOME/.pbj/bin:$PATH"

pbj  # Auto-retrieves key from GitHub Secrets → works!
```

**Key retrieval:**
- Checks `.pbj-key` (local cache)
- If missing, retrieves from GitHub Secrets
- Fingerprint matches → decryption works
- All devices use same key → seamless sync

## Security Considerations

### Q: Is it safe that my encrypted data is public?

**A: Yes! Your data is encrypted with AES-256-GCM.**

**Public fork (totally fine!):**
- Anyone can download your encrypted chunks
- They can't decrypt without your key (stored in Secrets)
- AES-256-GCM is considered secure (military-grade encryption)
- Even if leaked, data is unreadable without the key
- `ahoward/pbj` is public with his encrypted data right now!

**Private fork (extra paranoid):**
- Extra layer of access control
- Only you can even see the encrypted chunks
- Overkill for most users, but available if wanted

**Recommendation:** Public is fine. The encryption is the real security.

### Q: What if someone gets my encryption key?

**A: They can decrypt your clipboard history.**

**Protection:**
- Key stored ONLY in GitHub Secrets (encrypted by GitHub)
- Local cache `.pbj-key` (file permission 0600)
- Never committed to git
- Never transmitted except via GitHub API

**If compromised:**
```bash
# Generate new key (WARNING: loses all history)
rm ~/.pbj/.pbj-key
rm -rf ~/.pbj/data
pbj < <(echo "fresh start")
```

### Q: Why not gitignore data/?

**A: That defeats the entire purpose!**

The whole point is syncing clipboard across devices via git:
- Device A: `pbj < file` → commits to `data/` → pushes
- Device B: `git pull` → reads `data/` → `pbj` outputs
- If `data/` is gitignored, no sync happens!

## Template Repo Alternative

GitHub has "template" repositories that create fresh copies (not forks).

**Pros:**
- No inherited data
- Clean start
- No key mismatch

**Cons:**
- Loses fork relationship with upstream
- Can't `git pull upstream` for updates
- Have to manually merge updates

**Recommendation:** Stick with fork + auto-cleanup. It's simpler and maintains upstream relationship.

## Testing Key Mismatch

```bash
# Simulate forking someone else's repo
cd ~/.pbj

# Save your key
cp .pbj-key .pbj-key.backup

# Generate fake data with different key
ruby -e '
  require "openssl"
  require "json"

  fake_key = OpenSSL::Random.random_bytes(32)
  fake_fingerprint = Digest::SHA256.hexdigest(fake_key)[0, 16]

  manifest = {
    timestamp: Time.now.to_i,
    chunks: 1,
    preview: "fake data",
    key_fingerprint: fake_fingerprint
  }

  File.write("data/manifest.json", JSON.pretty_generate(manifest))
  File.write("data/clip.0000.enc", "fake encrypted data")
'

# Commit fake data
git add data/
git commit -m "test: fake data with different key"

# Try to paste (should trigger mismatch)
pbj  # ⚠ KEY MISMATCH DETECTED → auto-cleanup

# Restore your key
cp .pbj-key.backup .pbj-key
```

## Conclusion

**The fork workflow works because:**
1. Each user generates unique encryption key
2. Key fingerprint stored with every clipboard entry
3. Mismatch detection prevents wrong key usage
4. Auto-cleanup makes forking seamless
5. Users never see someone else's data (can't decrypt)

**It's secure because:**
- Encrypted data safe to share (AES-256-GCM)
- Keys never in repo (GitHub Secrets only)
- Fingerprint prevents wrong key disasters
- Each fork isolated by encryption
