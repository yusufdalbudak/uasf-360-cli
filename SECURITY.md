# Security & acceptable use policy

This tool transmits **purpose-built validation probes** intended for defenders tuning WAAP/WAF/API controls inside approved programs.

### You must NOT

Use it outside **written authorization**. Do not pivot it into covert surveillance, brute forcing live credentials outside agreed scope, data exfiltration, malware deployment, covert channels, unrestricted internet-wide scanning, or denial-of-service (including naive high-volume fuzzing hidden behind “tests”).

### Framework guardrails baked in

- **Scope-regex** anchored on every outbound URL builder.
- **Rate caps** enforced through `config/safety.conf`.
- **`--lab-mode`** for lab-oriented modules (`rate_limit_detection`, tight burst loops).
- **Acknowledgement** required for wider-area targets (`--i-understand` / `UASF_ACK=1`).
- **Destructive payloads** are intentionally omitted; escalate only in fenced lab assets you control.

Violations expose operators to criminal and civil liability. If you observe unsafe third-party forks, disclose responsibly and do not deploy them blindly.
