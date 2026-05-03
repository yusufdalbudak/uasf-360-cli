# UASF 360 CLI

**Universal Application Security Validation Framework** — production-oriented, **CLI-only**, Bash tooling for authorized **WAAP / WAF / API** defensive validation on Linux and macOS. No dashboards or long-running backends.

Correlation header sent on every probe: **`X-UASF-Correlation`** — filter WAAP dashboards (including AppTrana) on this header.

See [SECURITY.md](SECURITY.md) for legal constraints, [QUICKSTART.md](QUICKSTART.md) for a five-minute setup, [EXAMPLES.md](EXAMPLES.md) for scripted usage, [CHANGELOG.md](CHANGELOG.md) for release notes.

## Requirements

- Bash 3.2+ (macOS)/5+, **`curl`**, **`jq`**
- Optional: `perl` (milliseconds), ShellCheck (CI), Docker + [**`vt`**](labs/vt/README.md)

## Typical commands

```bash
chmod +x uasf.sh
./uasf.sh doctor
./uasf.sh init

./uasf.sh list-modules
./uasf.sh list-scenarios
./uasf.sh validate-scenario --file scenarios/sqli-smoke.json \
  --target https://example.com --scope-regex '^https://example\.com'

./uasf.sh run --target https://example.com --scope-regex '^https://example\.com' \
  --profile quick --out ./output/run-name --i-understand --rps 2 --timeout 10

./uasf.sh run --target http://localhost:3000 --scope-regex '^http://localhost:3000' \
  --profile full-lab --lab-mode --out ./output/local-lab

./uasf.sh vt list && ./uasf.sh vt start --id vt-juice-shop && ./uasf.sh vt stop --id vt-juice-shop
./uasf.sh report --run ./output/run-name
```

## Architecture

Single entrypoint `./uasf.sh` wires `lib/*.sh`:

- Mandatory gates — `scope.sh`, `safety.sh`, `rate_limit.sh`
- One HTTP engine — `http.sh`
- Classification — `verdict.sh`, `detection.sh`
- Persistence — `evidence.sh`, `report.sh`
- Modular probes — `modules/*.sh`

## Outputs

Artifacts under **`--out`**: `results.csv`, `results.ndjson`, `audit.log`, `run.json`, `summary.md`, `evidence/`, optional **`report.html`** (`--html`).

## Installation

Symlink helper (respects **`PREFIX`** env):

```bash
./install.sh
```

## Acknowledgements

Thank you to [**Happy Hacking Space**](https://github.com/HappyHackingSpace) for [**`vt`** (Vulnerable Target)](https://github.com/HappyHackingSpace/vt) and the [**`vt-templates`**](https://github.com/HappyHackingSpace/vt-templates) ecosystem. UASF exposes optional `./uasf.sh vt …` wrappers and lab docs that integrate with upstream `vt`; the tool itself is maintained by Happy Hacking Space, not bundled in this repository. See [`labs/vt/README.md`](labs/vt/README.md).
