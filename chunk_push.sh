#!/usr/bin/env bash
# Batch-commit and push all new/modified files in the repository root (dataset-friendly).
# Place this script at the repo root and run it there.
# It commits in chunks to avoid huge commits and arg list limits.

set -euo pipefail

# ---- Settings ---------------------------------------------------------------
BATCH_SIZE="${BATCH_SIZE:-200}"   # override with: BATCH_SIZE=500 ./batch_push.sh
# ---------------------------------------------------------------------------

# Ensure we're inside a Git repo
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Error: not inside a Git repository." >&2
  exit 1
}

# Determine current branch
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Collect changed files (modified tracked + untracked, excluding ignored)
CHANGED_FILES=()

# Modified tracked files (not staged yet)
while IFS= read -r -d '' f; do
  CHANGED_FILES+=("$f")
done < <(git ls-files -m -z)

# Untracked (not ignored) files
while IFS= read -r -d '' f; do
  CHANGED_FILES+=("$f")
done < <(git ls-files -o --exclude-standard -z)

TOTAL=${#CHANGED_FILES[@]}
if (( TOTAL == 0 )); then
  echo "Nothing to commit. Working tree is clean."
  exit 0
fi

echo "Found $TOTAL file(s) to commit on branch '$CURRENT_BRANCH' (batch size: $BATCH_SIZE)."

i=0
while (( i < TOTAL )); do
  # Slice the next chunk
  CHUNK=( "${CHANGED_FILES[@]:i:BATCH_SIZE}" )
  START=$(( i + 1 ))
  END=$(( i + ${#CHUNK[@]} ))

  echo "→ Staging files $START-$END..."
  git add -- "${CHUNK[@]}"

  # Skip empty commits (e.g., if some files were already staged/unchanged)
  if git diff --cached --quiet; then
    echo "   (no staged changes for $START-$END, skipping commit/push)"
  else
    git commit -m "Add dataset files $START-$END"
    echo "→ Pushing batch $START-$END to 'origin/$CURRENT_BRANCH'..."
    git push origin "$CURRENT_BRANCH"
  fi

  i=$(( i + BATCH_SIZE ))
done

# Summary
PUSHES=$(( (TOTAL + BATCH_SIZE - 1) / BATCH_SIZE ))
echo "Done. Processed $TOTAL file(s) in up to $PUSHES push(es) to '$CURRENT_BRANCH'."

# Notes:
# - This handles new and modified files. If you removed tracked files and want to record deletions,
#   run a separate 'git add -A' + commit, or extend the script to handle deletions explicitly.

