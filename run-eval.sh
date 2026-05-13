#!/usr/bin/env bash
# Run the scorer across 4 configurations and write CSV results to results/
# Usage: bash run-eval.sh

set -e

PROMPT=prompts/default-prompt.txt
COUNT=61
OUT=results

echo "Running evaluation: $COUNT snippets × 4 configurations"
echo

echo "[1/4] haiku, no prompt"
node score.js -n $COUNT -m claude-haiku-4-5 --output $OUT

echo
echo "[2/4] haiku, with prompt"
node score.js -n $COUNT -m claude-haiku-4-5 -s $PROMPT --output $OUT

echo
echo "[3/4] opus, no prompt"
node score.js -n $COUNT -m claude-opus-4-7 --output $OUT

echo
echo "[4/4] opus, with prompt"
node score.js -n $COUNT -m claude-opus-4-7 -s $PROMPT --output $OUT

echo
echo "Done. Results written to $OUT/"
