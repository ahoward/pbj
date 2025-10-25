# 🥜🥪 pbj 🍇🥪

### the universal paste buffer

> **p**eanut **b**utter, and fucking **j**elly.

---

## TL;DR 🚀

`pbj` is the universal clipboard you always wanted. One command. All your devices. Encrypted. Distributed. Zero bullshit.

```sh
# copy on laptop
cat secret.txt | pbj

# paste on phone, desktop, server, wherever
pbj > secret.txt
```

Similar to `pbcopy`, `xclip`, `wl-copy` — but **universal**. All your machines sync automatically. Mobile, desktop, servers, toasters. If it has `git` and `gh`, it syncs.

---

## How It Works 🔮

**The Secret Sauce:**
1. 🔐 **AES-256-GCM encryption** (because privacy)
2. 🧩 **10MB chunks** (generous free tier abuse)
3. 🔑 **GitHub Secrets** for key backup (auto-synced on every copy!)
4. 📦 **Git repo as sync backend** (public or private - data is encrypted!)
5. ⚡ **Background push & key backup** (async, non-blocking)

**Data Flow:**
```
stdin → encrypt → chunk → git commit → background push + key backup
                                              ↓
                                         (GitHub)
                                              ↓
git pull ← decrypt ← reassemble ← read chunks → stdout
```

**Storage Layout:**
```
~/.pbj/                    # your forked repo (code + data together!)
├── bin/
│   └── pbj               # the script you run
├── data/                 # encrypted clipboard data (COMMITTED TO GIT!)
│   ├── clip.0000.enc     # encrypted chunk 0
│   ├── clip.0001.enc     # encrypted chunk 1
│   ├── clip.0002.enc     # ...
│   └── manifest.json     # chunk metadata
├── .pbj-key              # encryption key cache (gitignored)
├── prune.log             # background prune log (gitignored)
├── README.md             # this file
└── .gitignore            # only ignores .pbj-key and prune.log
```

**The repo contains both code AND your encrypted data!**
- Code lives in `bin/` (version controlled)
- Data lives in `data/` (version controlled, encrypted, synced!)
- Data is COMMITTED to your fork (it's encrypted, so safe)
- Git sync = clipboard sync across devices
- You run from your own fork

---

## Installation 🛠️

### Step 1: Fork on GitHub
1. Go to https://github.com/ahoward/pbj
2. Click "Fork" (top right)
3. Optional: Make it private if you want (recommended but not required)

**Fork cleanup:**
When you fork, you'll get `ahoward`'s encrypted clipboard data:
- You can't decrypt it (you don't have his key)
- On first run, `pbj` detects the key mismatch and auto-clears it
- Then you start fresh with your own encrypted data

### Step 2: Clone Anywhere (Recommended: ~/.pbj)
```sh
# Recommended location: ~/.pbj
git clone git@github.com:YOUR_USERNAME/pbj.git ~/.pbj

# But you can clone ANYWHERE:
git clone git@github.com:YOUR_USERNAME/pbj.git ~/my-pbj
git clone git@github.com:YOUR_USERNAME/pbj.git /opt/pbj

# Or use HTTPS
git clone https://github.com/YOUR_USERNAME/pbj.git ~/.pbj
```

**Note:** The script automatically detects where it's installed. Data is stored relative to the clone location in `data/`.

### Step 3: Add to PATH
```sh
# For ~/.pbj (recommended):
echo 'export PATH="$HOME/.pbj/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# For custom location:
echo 'export PATH="/your/custom/path/pbj/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Or for zsh
echo 'export PATH="$HOME/.pbj/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Step 4: Verify
```sh
which pbj
# Should output: /home/you/.pbj/bin/pbj (or your custom location)

pbj help
# Should show usage
```

### Alternative: Symlink
```sh
# Clone anywhere, symlink to /usr/local/bin
git clone git@github.com:YOUR_USERNAME/pbj.git ~/pbj
sudo ln -s ~/pbj/bin/pbj /usr/local/bin/pbj
```

**Requirements:**
- Ruby (stdlib only, no gems)
- `gh` CLI (authenticated: `gh auth login`)
- `git`

---

## Usage 💻

### Copy (Write Mode)
```sh
# pipe anything
echo "hack the planet" | pbj
cat image.png | pbj
curl https://example.com | pbj

# or redirect
pbj < document.pdf
```

### Paste (Read Mode)
```sh
# stdout
pbj

# to file
pbj > output.txt

# pipe it
pbj | grep secret | awk '{print $2}'
```

### Cross-Device Sync
```sh
# on your laptop
echo "meeting notes" | pbj

# on your phone (termux)
pbj  # gets the same notes

# on your server
pbj | mail -s "notes" you@example.com
```

### Clipboard History
```sh
# view history (last 20 entries by default)
pbj history

# view more
pbj history 50

# output:
# Clipboard History:
# ================================================================================
# [0] 2025-10-25 14:32:01 (a3f2c91)
#     hack the planet
#
# [1] 2025-10-25 14:30:15 (b4e1a82)
#     meeting notes for tomorrow...
#
# [2] 2025-10-25 12:15:33 (c7d9f31)
#     <binary data>

# paste from history by index
pbj 0  # most recent
pbj 1  # second most recent
pbj 5  # sixth entry

# examples
pbj 2 > old-clipboard.txt
pbj 0 | grep "important"
```

### Key Recovery (PIN-Protected)
```sh
# Recover encryption key on a new device
pbj recover

# This will:
# 1. Back up existing key to .pbj-key.bak (if overwriting)
# 2. Trigger the key-recovery workflow
# 3. Poll until workflow completes (30-60 seconds)
# 4. Prompt for your 4-digit PIN
# 5. Decrypt and save the key automatically
# 6. Remind you to delete the workflow run

# You'll be prompted:
# Enter your PIN: ****
# ✓ Key decrypted successfully

# Alternative: Manual key copy (fastest!)
# Device 1: cat ~/.pbj/.pbj-key
# Device 2: echo "PASTE_KEY_HERE" > ~/.pbj/.pbj-key

# Set or update your PIN
pbj set-pin
```

**Multi-device setup:**
1. Fork `ahoward/pbj` once on GitHub
2. Clone to `~/.pbj` on **Device 1**
3. Add `~/.pbj/bin` to PATH
4. First `pbj` copy prompts for 4-digit PIN
5. Key + PIN stored in GitHub Secrets (encrypted backup)
6. Clone same fork to **Device 2**
7. **Copy key manually** (fastest!) OR use `pbj recover` (requires PIN)

**Key Storage (PIN-Protected):**
- **Primary:** `.pbj-key` file in repo (gitignored, fast)
- **PIN:** 4-digit PIN for key recovery (prompted on first copy)
- **Backup:** GitHub Secrets store both PBJ_KEY and PBJ_PIN (write-only)
- **Auto-backup:** Key + PIN synced to GitHub Secrets in background
- **Recovery:** Workflow encrypts key with PIN before logging (split-key security)
- **Multi-device:** Manual copy (recommended) or `pbj recover` (requires PIN)

**Method 1: Manual copy (RECOMMENDED - fast and simple)**
```bash
# Device 1:
cat ~/.pbj/.pbj-key

# Device 2:
echo "PASTE_KEY_HERE" > ~/.pbj/.pbj-key
chmod 600 ~/.pbj/.pbj-key
```

**Method 2: Automatic recovery with `pbj recover` (PIN-protected)**
```bash
# On Device 2 (automatic - triggers workflow, polls, decrypts key):
pbj recover

# The command will:
# 1. Back up existing key to .pbj-key.bak (if overwriting)
# 2. Trigger key-recovery workflow
# 3. Wait for workflow to complete (30-60 seconds)
# 4. Prompt for your 4-digit PIN
# 5. Decrypt key and save to ~/.pbj/.pbj-key
# 6. Remind you to delete the workflow run

# You'll be prompted:
# Enter your PIN: ****
# ✓ Key decrypted successfully

# Then delete the workflow run:
gh run delete <run-id> -R username/pbj

# If something went wrong, your old key is at:
# ~/.pbj/.pbj-key.bak
```

**Method 3: Manual workflow (if `pbj recover` fails)**
```bash
# On Device 2:
cd ~/.pbj
gh workflow run key-recovery

# Wait 30 seconds, then view logs:
gh run list --workflow=key-recovery
gh run view <run-id> --log

# Copy key from logs to ~/.pbj/.pbj-key
# IMPORTANT: Delete the workflow run after (exposes key in logs!)
```

---

## Features 🎯

✅ **End-to-end encrypted** (AES-256-GCM)
✅ **Automatic chunking** for large files
✅ **GitHub Secrets** key management
✅ **Async background sync** (non-blocking)
✅ **Works with binary data** (images, PDFs, whatever)
✅ **Git-based history** (time-travel your clipboard)
✅ **History browsing** (`pbj history` + `pbj N`)
✅ **Cross-platform** (Linux, macOS, BSD, wherever Ruby runs)
✅ **Zero external dependencies** (stdlib only)
✅ **Robust error handling** (clear error messages)

---

## Architecture 🏗️

**Why this approach wins:**

| Problem | Solution |
|---------|----------|
| Distribution | Fork repo → every user has their own |
| Auth | `gh` CLI (already configured) |
| Sync | Git push/pull (built-in conflict resolution) |
| Privacy | AES-256-GCM encryption (never trust the cloud) |
| Size limits | 10MB chunks (abuse free tier forever) |
| Key management | GitHub Secrets + auto-retrieval |
| History | Git commits (time-travel your clipboard) |
| Binary data | Base64? Nah. Raw encrypted bytes. |
| Code updates | `git pull upstream` (from ahoward/pbj) |

**Security Model:**
- Encryption key stored in GitHub Secrets (write-only, cannot be read via API)
- Local key cache in `.pbj-key` (gitignored, fast access)
- Key fingerprint (SHA256 hash) stored in manifest for mismatch detection
- Each chunk encrypted independently with AES-256-GCM
- Authenticated encryption (GCM) prevents tampering
- **Encrypted data IS committed to your fork** (safe because encrypted)
- Even if someone accesses your repo, they can't decrypt without the key

**Why GitHub Secrets (not Variables)?**
- **Secrets:** Write-only, can't read via API → secure even on public repos ✅
- **Variables:** Readable by anyone on public repos → dangerous ❌
- **Trade-off:** Manual key copy required, but security is worth it

**Key Recovery:**
- **Auto-backup:** Key synced to GitHub Secrets automatically on every copy (background, non-blocking)
- Primary: Copy `.pbj-key` file manually between devices (fast, simple)
- Backup: Use `key-recovery` workflow to retrieve from Secrets (slow but works)
- Workflow exposes key in logs temporarily (delete run after use)
- Key always up-to-date in Secrets (even if regenerated)

**Key Fingerprinting:**
- Each manifest contains SHA256 hash of encryption key (first 64 bits)
- On paste, fingerprint is checked against current key
- Mismatch = auto-cleanup (prevents using wrong key)
- Prevents corruption from forked repos with someone else's data

**Fork-based Distribution:**
- Everyone forks `ahoward/pbj` to their own repo
- Code in `bin/` is version controlled
- Data in `data/` is version controlled (encrypted!)
- Each fork contains that user's encrypted clipboard
- Updates: `git remote add upstream https://github.com/ahoward/pbj.git`
- Pull updates: `git pull upstream main` (merges code, preserves your data)

---

## Hacking 🔧

**Chunk size:**
```ruby
CHUNK_SIZE = 10 * 1024 * 1024  # 10MB
```

**Repo location:**
```ruby
REPO_DIR = File.join(ENV['HOME'], '.pbj')
```

**Encryption:**
- Algorithm: AES-256-GCM
- IV: 12 bytes (random per encryption)
- Auth tag: 16 bytes
- Key: 32 bytes (stored in GitHub Secrets)

**History Management:**
```ruby
MAX_HISTORY_COMMITS = 108       # Keep last 108 entries
REPO_SIZE_WARNING_MB = 420      # Warn at 420MB
AUTO_PRUNE_THRESHOLD_MB = 4242  # Auto-prune at 4.2GB
```

**Why these limits?**
- Git repos store full history (every clipboard entry ever)
- Large files accumulate quickly (even with chunking)
- GitHub free tier: repos should stay under 1GB (recommended)
- 108 entries with auto-prune at 4.2GB gives you headroom
- Auto-pruning runs **in background** after sync (non-blocking)
- `pbj info` shows current size and warnings
- `pbj prune` manually cleans up when needed
- Background prune activity logged to `~/.pbj/prune.log`

---

## Troubleshooting 🐛

**"⚠ KEY MISMATCH DETECTED"**

This is **normal** when you first fork the repo! It means:
- You forked `ahoward/pbj` (or someone else's fork)
- The data was encrypted with their key
- You have a different key

**What happens automatically:**
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

**Solution:** Just start using `pbj` normally:
```sh
echo "my first clipboard" | pbj
pbj  # Should output: my first clipboard
```

**"✗ Not authenticated with gh"**
```sh
gh auth login
```

**"✗ Repository not found at ~/.pbj"**
```sh
# You forgot to fork and clone!
# 1. Fork https://github.com/ahoward/pbj on GitHub
# 2. Clone to ~/.pbj:
git clone git@github.com:YOUR_USERNAME/pbj.git ~/.pbj

# 3. Add to PATH:
echo 'export PATH="$HOME/.pbj/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**"✗ Decryption failed (wrong key or corrupted data)"**

This means your devices have different encryption keys. Fix:

**Option 1: Copy key file between devices**
```sh
# On Device A (has working key):
cat ~/.pbj/.pbj-key

# On Device B (needs key):
# Copy the output and paste:
echo "PASTE_KEY_HERE" > ~/.pbj/.pbj-key
chmod 600 ~/.pbj/.pbj-key
```

**Option 2: Use GitHub Secrets (if you set it up)**
```sh
# Manually retrieve from Secrets
gh secret list -R username/pbj
# (Note: gh can't read secret values directly - they're write-only)
```

**Option 3: Start fresh (loses history)**
```sh
rm ~/.pbj/.pbj-key
rm -rf ~/.pbj/data
echo "new start" | pbj
```

**"✗ Missing chunks"**
```sh
cd ~/.pbj && git pull    # sync latest changes
pbj                      # retry
```

**"✗ Failed to sync to remote"**
- Non-fatal warning (still works locally)
- Check network connection
- Verify `gh auth status`

**Git conflicts:**
- Automatic recovery (`git reset --hard origin/main`)
- Last-write-wins model
- Manual: `cd ~/.pbj && git status`

**View all errors:**
```sh
pbj 2>&1 | tee pbj-debug.log
```

**Repository size issues:**
```sh
pbj info                 # check current size
pbj prune                # keep last 108 entries
pbj prune 50             # keep last 50 entries

# Manual cleanup
cd ~/.pbj
git gc --aggressive --prune=now
```

**Auto-pruning:**
- Automatically triggers at 4242MB
- Runs in **background** after each copy (non-blocking)
- Keeps last 108 clipboard entries
- Warnings logged to `~/.pbj/prune.log`
- Check log: `tail ~/.pbj/prune.log`
- Non-destructive (can disable by editing constants)

---

## License 📜

Do whatever you want. It's peanut butter and jelly.

---

**Made with 🥜 and 🍇 by hackers, for hackers.**
