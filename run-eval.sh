#!/usr/bin/env bash
# Run the scorer across 4 configurations and write CSV results to results/
# If a partial CSV already exists for a configuration, resume from it.
# Usage: bash run-eval.sh

set -e

PROMPT=prompts/default-prompt.txt
COUNT=61
OUT=results

run_config() {
  local label="$1"
  local model="$2"
  local prompt_flag="$3"  # either "-s prompts/default-prompt.txt" or ""

  # Look for an existing (partial) CSV matching this config
  local prompt_label="no-prompt"
  if [ -n "$prompt_flag" ]; then prompt_label="default-prompt"; fi
  local existing
  existing=$(ls "$OUT/${model}__${prompt_label}__all__"*.csv 2>/dev/null | tail -1)

  if [ -n "$existing" ]; then
    echo "$label  →  resuming from $(basename "$existing")"
    node score.js -n $COUNT -m "$model" $prompt_flag --resume "$existing"
  else
    echo "$label"
    node score.js -n $COUNT -m "$model" $prompt_flag --output $OUT
  fi
}

mkdir -p "$OUT"

echo "Running evaluation: $COUNT snippets × 4 configurations"
echo

run_config "[1/4] haiku, no prompt"  claude-haiku-4-5  ""
echo
run_config "[2/4] haiku, with prompt" claude-haiku-4-5  "-s $PROMPT"
echo
run_config "[3/4] opus, no prompt"   claude-opus-4-7   ""
echo
run_config "[4/4] opus, with prompt"  claude-opus-4-7   "-s $PROMPT"

echo
echo "Done. Results written to $OUT/"
