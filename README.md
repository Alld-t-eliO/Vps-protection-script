# VPS Security Checkup

VPS Security Checkup is a modular Bash security and system audit tool for Linux servers.

It focuses on practical checks that matter for internet-facing VPS hosts: users, sudo access, SSH hardening, firewall state, network exposure, Docker, services, processes, package updates, reboot requirements, cron jobs, systemd timers, and sensitive filesystem permissions.

Every scan creates structured artifacts that can be reviewed manually, archived, compared over time, or consumed by automation.

## Quick Start

```bash
chmod +x main.sh security-checkup.sh install.sh
sudo ./main.sh --all
```

`security-checkup.sh` is kept as a compatibility wrapper around `main.sh`.

## Installation

To install a global command:

```bash
sudo ./install.sh
sudo vps-checkup --all
```

You can customize the install target:

```bash
sudo TARGET_DIR=/usr/local/bin COMMAND_NAME=server-checkup ./install.sh
```

## Usage

```bash
sudo ./main.sh [scan options] [global options]
```

Examples:

```bash
sudo ./main.sh --ssh --network --users
sudo ./main.sh --docker --firewall
sudo ./main.sh --all --compare-last
sudo ./main.sh --all --strict
sudo ./main.sh --all --output-dir /var/log/vps-security-scans
sudo ./main.sh --all --json-only
```

## Scan Options

| Option | Description |
| --- | --- |
| `--all` | Run the complete VPS security checkup. |
| `--users` | List valid-shell users, UID 0 accounts, sudo group membership, and NOPASSWD rules. |
| `--network` | Show listening ports and connected remote IPs. |
| `--ssh` | Check effective SSH configuration, Fail2Ban, current SSH sessions, accepted logins, and failed attempts. |
| `--firewall` | Check UFW status, UFW rules, and listening ports. |
| `--docker` | Check Docker daemon state, containers, exposed ports, privileged containers, and container users. |
| `--services` | Show running services, enabled services, failed services, root processes, top processes, cron jobs, and systemd timers. |
| `--updates` | Check package updates, security updates, and reboot requirements. Supports `apt`, `dnf`, and `yum` where available. |
| `--filesystem` | Check world-writable files, SUID/SGID files, sensitive file permissions, and `/tmp` mount hardening options. |

## Global Options

| Option | Description |
| --- | --- |
| `--strict` | Exit with status code `1` when warnings, errors, or critical findings are detected. Useful for CI and scheduled audits. |
| `--output-dir <path>` | Store scan directories under a custom output directory. |
| `--compare-last` | Compare current warning/error/critical findings with the previous scan in the same output directory. |
| `--quiet` | Suppress terminal output while still writing artifacts. |
| `--json-only` | Suppress normal terminal output and print `findings.json` at the end. |
| `--no-color` | Disable ANSI color output. |
| `--config <path>` | Load a custom Bash config file. |
| `--profile <name>` | Load an audit profile from `profiles/<name>.conf`. Built-ins: `workstation`, `server`, `docker-host`, `paranoid`. |
| `--plugin <name>` | Run one plugin from `plugins/<name>.sh`. |
| `--plugins` | Load and run every plugin in `plugins/`. |
| `--save-baseline` | Save current findings as a signed baseline under `baselines/`. |
| `--compare-baseline` | Compare current findings with the signed baseline and verify the baseline hash. |
| `--format jsonl` | Print JSON Lines findings to stdout and write `findings.jsonl`. |
| `--syslog` | Export findings to local syslog through `logger`. |
| `--webhook-url <url>` | POST `findings.json` to a webhook endpoint. |
| `-h`, `--help` | Show help. |

## Output Files

Each scan creates a timestamped directory:

```text
logs_scan/vps-security-scan-YYYY-MM-DD_HH-MM-SS/
  report.txt
  scan.log
  summary.txt
  findings.tsv
  findings.json
  findings.jsonl
  report.html
  compare-last.txt
  compare-baseline.txt
```

| File | Purpose |
| --- | --- |
| `report.txt` | Human-readable full report. |
| `scan.log` | Raw scan log for archiving or forwarding. |
| `summary.txt` | Score, counts, and top issues. |
| `findings.tsv` | Simple tab-separated finding store used for comparisons. |
| `findings.json` | Structured output for scripts, dashboards, CI, or ingestion. |
| `findings.jsonl` | SIEM-friendly JSON Lines export. |
| `report.html` | Standalone visual report for review in a browser. |
| `compare-last.txt` | Created when `--compare-last` is used. |
| `compare-baseline.txt` | Created when `--compare-baseline` is used. |

## Profiles

Profiles live in `profiles/` and can define default scan sets and severity choices:

```bash
sudo ./main.sh --profile workstation
sudo ./main.sh --profile server
sudo ./main.sh --profile docker-host
sudo ./main.sh --profile paranoid
```

When a profile is used without explicit scan options, its `PROFILE_SCANS` list is used.

## Signed Baselines

Create a trusted reference point:

```bash
sudo ./main.sh --all --save-baseline
```

Compare future scans with it:

```bash
sudo ./main.sh --all --compare-baseline
```

The scanner stores a SHA-256 hash next to the baseline and verifies it before comparison.

## Plugins

Plugins live in `plugins/`. Each plugin exposes a function named after the file:

```bash
plugins/nginx.sh       # exposes check_nginx
plugins/databases.sh   # exposes check_databases
```

Run one plugin:

```bash
sudo ./main.sh --plugin nginx
```

Run all plugins:

```bash
sudo ./main.sh --plugins
```

## Finding Levels

| Level | Meaning |
| --- | --- |
| `OK` | Expected secure or healthy state. |
| `INFO` | Informational data or a non-actionable observation. |
| `WARNING` | Review recommended. May be acceptable depending on your server role. |
| `ERROR` | The scanner could not complete an important check. |
| `CRITICAL` | High-risk condition that should be reviewed quickly. |

Many findings include a `remediation` field in JSON and a `Fix:` hint in terminal output.

## Configuration

Default settings live in:

```text
config/default.conf
```

Use a custom config file:

```bash
sudo ./main.sh --all --config ./config/production.conf
```

The config is a Bash file, so keep it trusted and local.

## Automation

Run quietly from cron:

```cron
15 3 * * * /opt/vps-security-checkup/main.sh --all --quiet --compare-last --output-dir /var/log/vps-security-scans
```

Use strict mode in CI:

```bash
sudo ./main.sh --ssh --firewall --strict
```

Use JSON output for tooling:

```bash
sudo ./main.sh --all --json-only > latest-findings.json
sudo ./main.sh --all --format jsonl > latest-findings.jsonl
```

Export to syslog or a webhook:

```bash
sudo ./main.sh --all --syslog
sudo ./main.sh --all --webhook-url https://example.invalid/security-webhook
```

## Recommended Server Baseline

For an internet-facing VPS, review these findings carefully:

- SSH password authentication should be disabled.
- Root SSH login should be disabled.
- A firewall or equivalent cloud security group should be active.
- Fail2Ban or another rate-limiting control should protect SSH.
- Package and security updates should be applied regularly.
- Reboot-required indicators should not be ignored.
- Docker containers should avoid privileged mode and root users.
- `/tmp`, `/var/tmp`, and `/dev/shm` should use `noexec`, `nosuid`, and `nodev` where compatible.
- Sudo `NOPASSWD` rules should be tightly scoped or removed.

## Repository Validation

The included GitHub Actions workflow validates Bash syntax for:

- `main.sh`
- `security-checkup.sh`
- `install.sh`
- all `lib/*.sh` modules
- all `plugins/*.sh` plugins
- `tests/run.sh`

## Privacy And Safety

The scanner runs locally and writes local artifacts. It does not upload data by itself.

Reports may contain usernames, process names, IP addresses, service names, package names, local paths, SSH metadata, and Docker metadata. Review reports before sharing them publicly.

## Limitations

This tool is an audit helper, not a full vulnerability scanner, EDR, IDS, or compliance product. It surfaces local configuration risks and operational signals that still require human review.
