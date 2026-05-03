# Optional lab integration: [Vulnerable Target (`vt`)](https://github.com/HappyHackingSpace/vt)

[HHS `vt`](https://github.com/HappyHackingSpace/vt) is a Go + Docker Compose tool that starts **intentionally vulnerable** apps from community templates ([`vt-templates`](https://github.com/HappyHackingSpace/vt-templates)). It is **not bundled** here — install upstream and keep workloads on **isolated lab networks**.

**Juice Shop only:** this repo also bundles `./uasf.sh juice …` + `labs/juice-shop/docker-compose.yml` (pure Docker, no `vt` install). See `labs/juice-shop/README.md`.

| Resource | Link |
|----------|------|
| `vt` CLI | [HappyHackingSpace/vt](https://github.com/HappyHackingSpace/vt) |
| Templates (DVWA, Juice Shop, WebGoat, …) | [HappyHackingSpace/vt-templates](https://github.com/HappyHackingSpace/vt-templates) |

### Prerequisites

- Go **1.24+** (for `go install`)
- Docker and Docker Compose
- MIT license upstream; templates may label lab vs CVE workflows

### Install `vt`

```bash
go install github.com/happyhackingspace/vt/cmd/vt@latest
# ensure $(go env GOPATH)/bin is on PATH
```

Optional: pin a binary path without altering PATH:

```bash
export UASF_VT_BIN=/path/to/vt
```

(You can also set `UASF_VT_BIN` in `config/default.conf` or a user snippet loaded by `uasf_init_config`.)

---

## UASF ↔ vt commands

Short **list** shorthand maps to `vt template --list`. **Any other** `vt` subcommand passes through.

```bash
# List templates (= vt template --list)
./uasf.sh vt
./uasf.sh vt list
./uasf.sh vt list --filter sqli

# Stateful lab (upstream commands)
./uasf.sh vt template --update
./uasf.sh vt ps
./uasf.sh vt start --id vt-juice-shop
./uasf.sh vt stop --id vt-juice-shop

# Debug / flags supported by upstream
./uasf.sh vt -v debug template --list
```

Direct wrapper (same prerequisites):

```bash
./labs/vt/vt-wrapper.sh template --list
```

---

## Typical workflow

1. **Provision** target: `./uasf.sh vt start --id vt-juice-shop` (use the URL/port the CLI prints — often `http://localhost`).
2. **Scope** probes: `./uasf.sh run --interactive` can derive `--scope-regex` from `--target`; keep scope tight.
3. **Run**: `./uasf.sh run --target … --scope-regex … --profile demo --out ./output/run1 --lab-mode --waf-evasion standard --i-understand` (omit `--lab-mode` for GET-only bundles if required).
4. **Correlate** in WAAP with header `X-UASF-Correlation`.

Use `UASF_VT_BASE_URL` in automation if your template publishes a non-default URL or port mapping.
