# OWASP Juice Shop (Docker) — bundled lab stack

This directory holds a **`docker-compose`** definition for the upstream **[OWASP Juice Shop](https://owasp.org/www-project-juice-shop/)** image (`bkimminich/juice-shop`). Use it **only on isolated lab hosts**.

## One-liner workflow

```bash
# From repo root (uasf-360-cli/)
./uasf.sh juice start          # or: juice start --port 4000
./uasf.sh juice wait
./uasf.sh juice run --profile demo --out ./output/juice-1 --lab-mode
./uasf.sh juice stop           # when finished
```

`juice run` starts the stack if it is down, waits for HTTP, then runs `./uasf.sh run` with `--target` / `--scope-regex` derived from `UASF_JUICE_HOST` / `UASF_JUICE_PORT` (see repo `config/default.conf`) and the mapped port.

`juice url` prints an example `./uasf.sh run …` command without executing it.

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Service `juice-shop`, publishes `${JUICE_SHOP_PORT:-3000}` |
| `.uasf-juice.port` | Written by `./uasf.sh juice start` — **gitignored** (local state) |

## Requirements

Docker engine + Compose v2 (or `docker-compose`). `curl` is required for `juice wait`.

## Alternate: Vulnerable Target (`vt`)

If you use **[Happy Hacking Space / vt](https://github.com/HappyHackingSpace/vt)** instead, `./uasf.sh vt start --id vt-juice-shop` is still supported; point UASF at the URL that `vt` prints.
