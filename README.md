# Choose-your-own-adventure experiments

Experiments evaluating how well an LLM can navigate [The Gamma](https://thegamma.net) type
provider member trees — i.e., whether it can correctly recommend the next step when building
a data query interactively, one member pick at a time.

## Background

The Gamma exposes data through a type provider protocol: querying data means navigating a tree
of named members (filter, group, sort, pick a country, pick an indicator, …). The interactive
editor presents the available members at each step and the user picks one. This project asks:
*can an LLM make those picks correctly, given the query goal?*

There are five provider types, each with different navigation patterns:

| Provider | Data | Navigation style |
|----------|------|-----------------|
| `olympics` | Olympic medal data | Tabular: filter → group → sort → paging → get series |
| `worldbank` | World Bank indicators | Data cube: byCountry/byYear → value → topic → indicator |
| `expenditure` | UK government spending | Data cube: byService/byYear → sub-service → indicator |
| `shared` | Uploaded CSV datasets | Browse by date/tag → pick dataset → tabular ops |
| `drWho` | Doctor Who graph | Graph navigation → `explore` → tabular ops |

## Setup

Requires Node.js and a running instance of
[thegamma-unified](../thegamma-unified/) on `http://localhost:5000`.

```
npm install
cp config.js.example config.js   # add your Anthropic API key
```

`config.js` (gitignored) must export `ANTHROPIC_API_KEY`.

## Scripts

### `score.js` — LLM evaluation

Walks ground-truth navigation chains from `data/eval-snippets.json`, asks the LLM for the
next step at each point, and reports how often it picks correctly. The LLM always follows
the correct path regardless of its answer, so each step is scored independently.

```
node score.js [options]

Options:
  -n, --count <n>             number of snippets to test (default: 3)
  -p, --provider <name>       filter to a specific provider
  -m, --model <name>          LLM model to use (default: claude-haiku-4-5)
  -s, --system-prompt <file>  path to a text file containing the system prompt
  -o, --output <dir>          write CSV results to this directory
  -r, --resume <file>         resume an interrupted run: skip already-scored chains
                              and append new rows to the existing CSV

Examples:
  node score.js -n 5
  node score.js -n 5 -p olympics
  node score.js -n 10 -p worldbank -m claude-sonnet-4-6
  node score.js -n 5 -p olympics -s prompts/default-prompt.txt
  node score.js -n 61 -s prompts/default-prompt.txt --output results
  node score.js -n 61 -s prompts/default-prompt.txt --resume results/run.csv
```

Omitting `-s` sends bare queries with no system prompt (useful as a baseline).
The default system prompt lives in `prompts/default-prompt.txt` and can be
copied and modified to experiment with different phrasings.

Options are capped at 500 when a member list is very large (e.g. the full athlete
roster), to stay within API token limits. The correct option is always included in
the sample.

CSV files are named `{model}__{prompt}__{provider}__{timestamp}.csv` and contain
one row per chain with columns `snippet_id, snippet_title, chain_index, provider,
total_steps, correct_steps`.

### `run-eval.sh` — Full evaluation across all configurations

Runs `score.js` across four configurations (haiku/opus × no-prompt/with-prompt)
for all 61 snippets. Automatically detects partial CSVs in `results/` and resumes
them rather than starting over.

```
bash run-eval.sh
```

### `extract.js` — Ground-truth extraction

Parses `data/snippets-thegamma.json` (gallery snippet data) and extracts navigation chains
into `data/eval-snippets.json`. Run this if the source snippets change.

```
node extract.js
```

For `shared` provider chains, adds a `hint` field (e.g. `"Use data source from May 2017
named 'Turing People'"`) that is passed to the LLM to avoid impossible date-guessing.
For snippets with multiple chains, merges per-chain hints from `data/extra-hints.json`
to help the LLM distinguish between chains (e.g. "This chain gets data for China").

### `verifier.js` — Chain integrity check

Verifies that every chain in `eval-snippets.json` can be fully traversed against the live
providers. Useful after changes to the server or the snippet data.

```
node verifier.js
```

Reports `OK` or `FAIL` per chain with details on where navigation breaks.

### `cyoa.js` — Interactive explorer

Interactive choose-your-own-adventure navigator: pick a data source, then step through the
member tree with LLM suggestions highlighted. Useful for manual exploration.

```
node cyoa.js
```

## Project structure

```
score.js          Main evaluation script
extract.js        Extracts chains from gallery snippets
verifier.js       Verifies chains against the live server
cyoa.js           Interactive member-tree explorer
run-eval.sh       Runs all 4 configurations end-to-end

providers.js      Shared provider setup, type resolution helpers
log.js            Coloured logging helpers (clr, log)
config.js         API key — gitignored, create manually

data/
  snippets-thegamma.json   Raw gallery snippet data (source)
  eval-snippets.json       Extracted chains used by score/verifier
  extra-hints.json         Handwritten per-chain hints for multi-chain snippets

prompts/
  default-prompt.txt       Default system prompt with per-provider navigation rules

results/
  *.csv                    Result CSVs from evaluation runs
  results.ipynb            Jupyter notebook with analysis and charts
  *.png                    Charts exported by the notebook

paper/
  paper-vlhcc.tex          VLHcc paper describing The Gamma providers
  paper-cyoa.tex           Related paper; used to inform the system prompt
```

## Results

LLM accuracy on all 61 snippets (665 steps total):

| Provider    | Haiku, no prompt | Haiku, with prompt | Opus, no prompt | Opus, with prompt |
|-------------|------------------|--------------------|-----------------|-------------------|
| olympics    | 47%              | 60%                | 64%             | 80%               |
| worldbank   | 63%              | 67%                | 75%             | 79%               |
| shared      | 56%              | 68%                | 55%             | 77%               |
| **overall** | **54%**          | **65%**            | **60%**         | **79%**           |

The system prompt (per-provider navigation rules) adds roughly 10–15 pp for Haiku and
~20 pp for Opus. `expenditure` and `drWho` are excluded from the per-provider table due
to too few chains for reliable estimates; they are included in the `overall` figures.

See `results.ipynb` for full analysis including prompt lift by provider, accuracy vs
chain length, hardest snippets, and a per-chain Haiku vs Opus comparison.
