# Mac Security Center

A modular Bash-based security auditing tool for macOS.

`main.sh` is the main entry point. It orchestrates category modules from `lib/`, runs selected checks, and writes scan artifacts into `logs_scan/`.

## Usage

```bash
./main.sh --all
./main.sh --security --network --firewall
./main.sh --persistence --filesystem
./security-checkup.sh --all
```

`security-checkup.sh` is kept as a compatibility wrapper around `main.sh`.

## Scan Artifacts

Each run creates a dedicated directory:

```text
logs_scan/mac-security-scan-YYYY-MM-DD_HH-MM-SS/
  report.txt
  scan.log
  summary.txt
  findings.tsv
  findings.json
```

`summary.txt` contains the global score and top issues. `findings.json` is intended for automation, comparisons, dashboards, or later export.

## Modules

- `lib/users.sh`: local users and admin group
- `lib/security.sh`: FileVault, Gatekeeper, SIP, XProtect
- `lib/network.sh`: interfaces, listening ports, active connections, remote IPs
- `lib/ssh.sh`: Remote Login and SSH listener
- `lib/firewall.sh`: Application Firewall and stealth mode
- `lib/sharing.sh`: selected remote sharing services
- `lib/persistence.sh`: login items, LaunchAgents, LaunchDaemons, shell startup files
- `lib/processes.sh`: top CPU, top memory, root processes
- `lib/services.sh`: Homebrew services
- `lib/updates.sh`: macOS software updates
- `lib/filesystem.sh`: SSH key permissions and selected writable paths
- `lib/docker.sh`: Docker daemon, containers, ports, privileged mode, container users

## Notes

Some macOS checks return more complete data when run with `sudo`.
