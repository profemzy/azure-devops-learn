#!/bin/bash
# Phase 2 Lab 2.5: Conflict Resolution Practice Script
# Creates intentional merge conflicts for practice

set -euo pipefail

echo "=== Phase 2 Lab 2.5: Merge Conflict Practice ==="
echo ""
echo "This script creates a controlled merge conflict scenario."
echo ""

# Check if in git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "[ERROR] Not in a Git repository. Run 01-setup-repo.sh first."
    exit 1
fi

# Save current branch
ORIGINAL_BRANCH=$(git branch --show-current)
echo "[INFO] Current branch: $ORIGINAL_BRANCH"

# Step 1: Create branch-a with changes
echo ""
echo "[STEP 1] Creating branch-a with initial change..."
git checkout -b branch-a 2>/dev/null || git checkout branch-a
echo "Content from Branch A" > conflict-practice.txt
git add conflict-practice.txt
git commit -m "feat: add initial content from branch A"

# Step 2: Switch to main and create conflicting change
echo ""
echo "[STEP 2] Creating conflicting change on main..."
git checkout main
echo "Content from Main Branch" > conflict-practice.txt
git add conflict-practice.txt
git commit -m "feat: add content from main branch"

# Step 3: Attempt merge
echo ""
echo "[STEP 3] Attempting to merge branch-a into main..."
if git merge branch-a 2>&1; then
    echo "[INFO] No conflict occurred. This shouldn't 1
fi happen."
    exit

# Step 4: Show conflict status
echo ""
echo "[STEP 4] Conflict detected! Current status:"
git status

# Step 5: Show the conflict
echo ""
echo "[STEP 5] Conflict markers in file:"
echo "---"
cat conflict-practice.txt
echo "---"

# Step 6: Instructions for resolution
echo ""
echo "=== CONFLICT RESOLUTION INSTRUCTIONS ==="
echo ""
echo "The file contains conflict markers:"
echo "  <<<<<<< HEAD     <- Your current branch changes"
echo "  =======          <- Separator"
echo "  >>>>>>> branch-a <- Incoming branch changes"
echo ""
echo "To resolve, choose ONE of these options:"
echo ""
echo "Option 1: Keep main branch version"
echo "  git checkout --ours conflict-practice.txt"
echo "  git add conflict-practice.txt"
echo ""
echo "Option 2: Keep branch-a version"
echo "  git checkout --theirs conflict-practice.txt"
echo "  git add conflict-practice.txt"
echo ""
echo "Option 3: Manual resolution"
echo "  Edit conflict-practice.txt to combine changes"
echo "  Remove conflict markers (<<<<<<<, =======, >>>>>>>)"
echo "  git add conflict-practice.txt"
echo ""
echo "After resolving:"
echo "  git commit -m 'merge: resolve conflict in conflict-practice.txt'"
echo "  git branch -d branch-a"
echo ""
echo "To abort and start over:"
echo "  git merge --abort"
echo ""

# Cleanup helper
echo "=== CLEANUP ==="
echo "When done, run: git checkout $ORIGINAL_BRANCH && git branch -D branch-a"
