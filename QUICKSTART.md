# Quickstart

1. **`./uasf.sh doctor`** — verify Bash, curl, jq, Docker/vt optionally.
2. **`./uasf.sh init`** — create `output/` and `evidence/` placeholders.
3. Choose a authorized target and **tight `--scope-regex` anchor** (`^https://your-host\.example\.`).
4. For anything except loopback/private, add **`--i-understand`** (or `export UASF_ACK=1`).
5. **`./uasf.sh validate-scenario --file ...`** before unattended runs.

### First profile run

```bash
./uasf.sh run \
  --target https://staging.example \
  --scope-regex '^https://staging\.example' \
  --profile quick \
  --out ./output/first-run \
  --rps 2 --timeout 8 \
  --i-understand
```

### Inspect results

Open `summary.md`, skim `audit.log`, slice `results.csv`, or ingest `results.ndjson` downstream.
