# Examples

### AppTrana WAAP demo correlation

```bash
./uasf.sh run \
  --target https://protect.example.com \
  --scope-regex '^https://protect\.example\.com' \
  --scenario scenarios/apptrana-waap-demo.json \
  --rps 2 --timeout 10 \
  --out ./output/apptrana-demo \
  --i-understand \
  --html
```

WAAP dashboards: Attacks/Trends filtered by **`X-UASF-Correlation`**.

### Scenario requiring POST bodies

```bash
./uasf.sh validate-scenario --file scenarios/auth-abuse.json \
  --target https://labs.local --scope-regex '^https://labs\.local' \
  --allow-mutating-methods

./uasf.sh run --target https://labs.local \
  --scope-regex '^https://labs\.local' \
  --scenario scenarios/auth-abuse.json \
  --allow-mutating-methods \
  --lab-mode --out ./output/auth-lab
```

### Custom module mix

```bash
./uasf.sh run --target ... --scope-regex '^https://...\.' \
  --profile custom \
  --modules sqli,waf_fingerprint,bot_detection \
  --out ./output/custom --i-understand
```

### Optional VT-backed lab target

Follow [labs/vt/README.md](labs/vt/README.md), then `./uasf.sh vt ...` helpers.
