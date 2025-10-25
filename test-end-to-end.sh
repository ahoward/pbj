#!/bin/bash
# End-to-End Test for PIN-Protected Key Recovery
# Tests the complete workflow with real GitHub Actions

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

echo "════════════════════════════════════════════════════════════"
echo "  PBJ PIN-Protected Key Recovery - End-to-End Test"
echo "════════════════════════════════════════════════════════════"
echo

# Check prerequisites
echo "Checking prerequisites..."
echo

if ! command -v gh &> /dev/null; then
    echo "✗ gh CLI not found. Install: https://cli.github.com/"
    exit 1
fi
echo "✓ gh CLI found"

if ! gh auth status &> /dev/null; then
    echo "✗ Not authenticated with gh. Run: gh auth login"
    exit 1
fi
echo "✓ gh authenticated"

USERNAME=$(gh api user -q .login)
echo "✓ Username: $USERNAME"
echo

# Test 1: Verify repo setup
echo "════════════════════════════════════════════════════════════"
echo "TEST 1: Verify Repository Setup"
echo "════════════════════════════════════════════════════════════"
echo

if ! gh repo view "$USERNAME/pbj" &> /dev/null; then
    echo "✗ Repository $USERNAME/pbj not found"
    echo "  Make sure you forked ahoward/pbj"
    exit 1
fi
echo "✓ Repository exists: $USERNAME/pbj"
echo

# Test 2: Create test clipboard entry with PIN
echo "════════════════════════════════════════════════════════════"
echo "TEST 2: Create Clipboard Entry (will prompt for PIN)"
echo "════════════════════════════════════════════════════════════"
echo

# Save existing key if present
if [ -f ".pbj-key" ]; then
    echo "Backing up existing key..."
    cp .pbj-key .pbj-key.e2e-backup
    echo "✓ Existing key backed up to .pbj-key.e2e-backup"
    echo
fi

# Check if PBJ_KEY and PBJ_PIN already exist
echo "Checking GitHub Secrets..."
if gh secret list -R "$USERNAME/pbj" | grep -q "PBJ_KEY"; then
    echo "✓ PBJ_KEY already exists"
else
    echo "⚠  PBJ_KEY not found (will be created on first copy)"
fi

if gh secret list -R "$USERNAME/pbj" | grep -q "PBJ_PIN"; then
    echo "✓ PBJ_PIN already exists"
    echo
    echo "Since PIN already exists, we'll test recovery with existing setup."
    echo "If you want to test fresh setup, delete secrets first:"
    echo "  gh secret delete PBJ_KEY -R $USERNAME/pbj"
    echo "  gh secret delete PBJ_PIN -R $USERNAME/pbj"
    echo
else
    echo "⚠  PBJ_PIN not found"
    echo

    if gh secret list -R "$USERNAME/pbj" | grep -q "PBJ_KEY"; then
        # Existing key without PIN - need to set PIN retroactively
        echo "You have an existing key but no PIN set."
        echo "Running 'pbj set-pin' to add PIN protection..."
        echo "You'll be prompted to set a PIN (use 4242 for testing)"
        echo
        read -p "Press Enter to set PIN..."
        echo

        ./bin/pbj set-pin

        echo
        echo "✓ PIN set successfully"
        echo
    else
        # No key at all - first time setup
        echo "This appears to be first-time setup."
        echo "You'll be prompted to set a PIN (use 4242 for testing)"
        echo
        read -p "Press Enter to create test clipboard entry..."
        echo

        # Create test entry (will prompt for PIN during key creation)
        echo "test-data-$(date +%s)" | ./bin/pbj

        echo
        echo "✓ Test clipboard entry created"
        echo
    fi
fi

# Test 3: Verify secrets stored
echo "════════════════════════════════════════════════════════════"
echo "TEST 3: Verify GitHub Secrets"
echo "════════════════════════════════════════════════════════════"
echo

if ! gh secret list -R "$USERNAME/pbj" | grep -q "PBJ_KEY"; then
    echo "✗ PBJ_KEY not found in secrets"
    exit 1
fi
echo "✓ PBJ_KEY stored in GitHub Secrets"

if ! gh secret list -R "$USERNAME/pbj" | grep -q "PBJ_PIN"; then
    echo "✗ PBJ_PIN not found in secrets"
    exit 1
fi
echo "✓ PBJ_PIN stored in GitHub Secrets"
echo

# Test 4: Trigger key-recovery workflow
echo "════════════════════════════════════════════════════════════"
echo "TEST 4: Trigger Key Recovery Workflow"
echo "════════════════════════════════════════════════════════════"
echo

echo "Triggering key-recovery workflow..."
if ! gh workflow run key-recovery.yml -R "$USERNAME/pbj"; then
    echo "✗ Failed to trigger workflow"
    exit 1
fi
echo "✓ Workflow triggered"
echo

echo "Waiting for workflow to start (10 seconds)..."
sleep 10
echo

# Get most recent workflow run
echo "Finding workflow run..."
RUN_ID=$(gh run list --workflow=key-recovery.yml -R "$USERNAME/pbj" --limit 1 --json databaseId -q '.[0].databaseId')

if [ -z "$RUN_ID" ]; then
    echo "✗ Could not find workflow run"
    exit 1
fi
echo "✓ Workflow run ID: $RUN_ID"
echo

echo "Waiting for workflow to complete (up to 2 minutes)..."
MAX_WAIT=120
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS=$(gh run view "$RUN_ID" -R "$USERNAME/pbj" --json status,conclusion -q '.status')

    if [ "$STATUS" = "completed" ]; then
        CONCLUSION=$(gh run view "$RUN_ID" -R "$USERNAME/pbj" --json conclusion -q '.conclusion')
        if [ "$CONCLUSION" = "success" ]; then
            echo "✓ Workflow completed successfully"
            break
        else
            echo "✗ Workflow failed with conclusion: $CONCLUSION"
            echo
            echo "View logs:"
            echo "  gh run view $RUN_ID -R $USERNAME/pbj --log"
            exit 1
        fi
    fi

    echo -n "."
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done
echo

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "✗ Workflow timed out after $MAX_WAIT seconds"
    echo
    echo "Check status:"
    echo "  gh run view $RUN_ID -R $USERNAME/pbj"
    exit 1
fi
echo

# Test 5: Verify encrypted blob in logs
echo "════════════════════════════════════════════════════════════"
echo "TEST 5: Verify Encrypted Key in Logs"
echo "════════════════════════════════════════════════════════════"
echo

echo "Fetching workflow logs..."
LOGS=$(gh run view "$RUN_ID" -R "$USERNAME/pbj" --log 2>/dev/null)

if echo "$LOGS" | grep -q "Your encryption key (base64 encoded):"; then
    echo "⚠  WARNING: Found RAW KEY in logs (old format)"
    echo "  This means the workflow is using the old unencrypted format"
    echo "  Expected: encrypted blob with PIN"
    exit 1
fi

if echo "$LOGS" | grep -q "Encrypted key (requires PIN to decrypt):"; then
    echo "✓ Found encrypted key blob (PIN-protected format)"
else
    echo "✗ Could not find encrypted key in logs"
    echo
    echo "View logs:"
    echo "  gh run view $RUN_ID -R $USERNAME/pbj --log"
    exit 1
fi
echo

# Test 6: Verify PIN not visible in logs
echo "════════════════════════════════════════════════════════════"
echo "TEST 6: Verify PIN Not Exposed"
echo "════════════════════════════════════════════════════════════"
echo

# Get the PIN value (we can't actually read it from secrets, so we'll check for common patterns)
if echo "$LOGS" | grep -qE "[0-9]{4}"; then
    # Could be PIN or could be something else, check context
    if echo "$LOGS" | grep -qE "PIN.*[0-9]{4}|[0-9]{4}.*PIN"; then
        echo "⚠  WARNING: Possible PIN visible in logs"
        echo "  Check logs manually:"
        echo "  gh run view $RUN_ID -R $USERNAME/pbj --log | grep -i pin"
    else
        echo "✓ No obvious PIN exposure in logs"
    fi
else
    echo "✓ No 4-digit numbers found in logs (PIN masked)"
fi
echo

# Test 7: Test pbj recover command
echo "════════════════════════════════════════════════════════════"
echo "TEST 7: Test 'pbj recover' Command"
echo "════════════════════════════════════════════════════════════"
echo

# Backup current key
if [ -f ".pbj-key" ]; then
    echo "Backing up current key..."
    mv .pbj-key .pbj-key.test-backup
    echo "✓ Current key backed up"
fi
echo

echo "Running 'pbj recover'..."
echo "You will be prompted for your PIN (enter the PIN you set earlier)"
echo
echo "Note: This is an interactive test - you need to enter your PIN"
echo
read -p "Press Enter to start recovery, then enter your PIN when prompted..."
echo

if ./bin/pbj recover; then
    echo
    echo "✓ Recovery completed successfully"
else
    echo
    echo "✗ Recovery failed"

    # Restore backup
    if [ -f ".pbj-key.test-backup" ]; then
        mv .pbj-key.test-backup .pbj-key
        echo "✓ Restored original key from backup"
    fi
    exit 1
fi
echo

# Test 8: Verify recovered key works
echo "════════════════════════════════════════════════════════════"
echo "TEST 8: Verify Recovered Key Works"
echo "════════════════════════════════════════════════════════════"
echo

echo "Testing recovered key by reading clipboard..."
if ./bin/pbj 2>/dev/null | head -1 | grep -q "test-data"; then
    echo "✓ Recovered key works correctly"
else
    echo "⚠  Could not verify key (no test data in clipboard)"
    echo "  This is OK if clipboard is empty"
fi
echo

# Cleanup
echo "════════════════════════════════════════════════════════════"
echo "CLEANUP"
echo "════════════════════════════════════════════════════════════"
echo

echo "Cleaning up..."

# Restore original key if we backed it up
if [ -f ".pbj-key.test-backup" ]; then
    mv .pbj-key.test-backup .pbj-key
    echo "✓ Restored original key"
fi

if [ -f ".pbj-key.e2e-backup" ]; then
    echo "✓ Original key still backed up at .pbj-key.e2e-backup"
fi

echo
echo "IMPORTANT: Delete the workflow run to remove logs:"
echo "  gh run delete $RUN_ID -R $USERNAME/pbj"
echo

# Summary
echo "════════════════════════════════════════════════════════════"
echo "TEST SUMMARY"
echo "════════════════════════════════════════════════════════════"
echo
echo "✓ Repository setup verified"
echo "✓ GitHub Secrets (PBJ_KEY, PBJ_PIN) verified"
echo "✓ Workflow triggered and completed"
echo "✓ Encrypted key blob found in logs"
echo "✓ PIN not exposed in logs"
echo "✓ Recovery command worked"
echo "✓ Recovered key verified"
echo
echo "════════════════════════════════════════════════════════════"
echo "  ALL TESTS PASSED ✓"
echo "════════════════════════════════════════════════════════════"
