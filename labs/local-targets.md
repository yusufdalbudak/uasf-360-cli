# Local lab targets

- **Juice Shop** (Docker): `./uasf.sh juice start` → `juice wait` → `juice run …` (see `labs/juice-shop/README.md`).
- **Juice Shop** (via `vt start --id vt-juice-shop`), then aim UASF runs at the URL `vt` prints.
- **Custom container** exposing HTTP on `127.0.0.1` only.
- Never bind unintended lab sockets to `0.0.0.0` on trusted networks — use VMs or segmented VLANs.

