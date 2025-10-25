# PBJ Architecture

## Fork-Based Distribution Model

### The Elegant Solution

Instead of creating a separate data-only repo (`pbj-sync`), **the repo IS the installation**.

```
ahoward/pbj (upstream)
    ↓ (user forks on GitHub)
username/pbj (user's fork)
    ↓ (user clones locally)
~/.pbj/ (local installation)
    ├── bin/pbj          ← executable (version controlled)
    ├── data/            ← clipboard data (gitignored)
    ├── README.md        ← docs (version controlled)
    └── .gitignore       ← excludes data/
```

### How It Works

**Installation:**
1. User forks `ahoward/pbj` → creates `username/pbj`
2. User clones to `~/.pbj`: `git clone git@github.com:username/pbj.git ~/.pbj`
3. User adds `~/.pbj/bin` to PATH
4. Done! The script runs from the repo itself

**Usage:**
- User runs `pbj` from PATH → executes `~/.pbj/bin/pbj`
- Script stores data in `~/.pbj/data/` (gitignored)
- Git commits go to `username/pbj` (their fork)
- Code updates via `git pull upstream main`

**Multi-Device Sync:**
- Same fork cloned to multiple devices
- All devices commit encrypted data to `username/pbj`
- Git handles sync (push/pull)
- Encryption key stored in GitHub Secrets of `username/pbj`

## Key Constants

```ruby
# All paths relative to script location - works anywhere!
SCRIPT_PATH = File.realpath(__FILE__)        # /path/to/clone/bin/pbj
BIN_DIR = File.dirname(SCRIPT_PATH)          # /path/to/clone/bin
REPO_DIR = File.dirname(BIN_DIR)             # /path/to/clone
DATA_DIR = File.join(REPO_DIR, 'data')       # /path/to/clone/data

REPO_NAME = 'pbj'  # GitHub repo name (forked to username/pbj)
```

This means you can clone to **any location** and it just works:
- `~/.pbj` (recommended)
- `~/my-pbj`
- `/opt/pbj`
- Anywhere!

## File Layout

```
~/.pbj/ (or any location!)
├── .git/                    # Git internals
├── bin/
│   └── pbj                 # The executable (THIS FILE runs from here!)
├── data/                   # COMMITTED TO GIT (encrypted clipboard data)
│   ├── clip.0000.enc      # Encrypted clipboard chunks
│   ├── clip.0001.enc
│   └── manifest.json      # Metadata
├── .pbj-key               # Encryption key cache (gitignored)
├── prune.log              # Background pruning log (gitignored)
├── .gitignore             # Only excludes .pbj-key and prune.log
├── README.md              # Documentation
└── ARCHITECTURE.md        # This file
```

## Why This Works

**Advantages:**
- ✅ Self-contained: clone once, works everywhere
- ✅ Updates: `git pull upstream main` gets new features
- ✅ Isolation: each user's data in their own fork
- ✅ No separate repos: code and data location unified
- ✅ PATH simple: `~/.pbj/bin` is consistent

**Trade-offs:**
- ⚠️ Users must fork (not just clone)
- ⚠️ Data directory grows (managed via auto-prune)
- ⚠️ Git repo contains both code and encrypted data
- ⚠️ Fork repo size grows with clipboard history (pruned at 4.2GB)

**Important: Data is NOT gitignored!**
- The whole point is to sync clipboard data via git
- Data is encrypted (AES-256-GCM) so safe to commit
- Each user's fork contains their encrypted clipboard
- Devices sync by pushing/pulling from the fork

## Data Flow

**Copy Operation:**
```
pbj < file
  ↓
~/.pbj/bin/pbj executes
  ↓
Encrypts data
  ↓
Writes to ~/.pbj/data/clip.*.enc
  ↓
git add data/
git commit -m "update clipboard"
git push origin main (background)
  ↓
GitHub: username/pbj updated
```

**Paste Operation:**
```
pbj > file
  ↓
~/.pbj/bin/pbj executes
  ↓
git pull origin main (fetch latest)
  ↓
Reads ~/.pbj/data/clip.*.enc
  ↓
Decrypts and outputs
```

## Updating Code

Users can pull updates from upstream:

```bash
cd ~/.pbj
git remote add upstream https://github.com/ahoward/pbj.git
git pull upstream main
git push origin main  # Push updates to their fork
```

This keeps their fork in sync with new features while preserving their clipboard data (which is gitignored).
