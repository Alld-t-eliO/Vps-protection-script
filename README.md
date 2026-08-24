# VPS Security Checkup

A Bash-based security auditing script for Linux VPS servers.

The script performs a collection of security and system checks and generates a structured report containing information about users, SSH, networking, firewall configuration, Docker, services, processes, packages, and filesystem permissions.

It is designed primarily as a **learning project** for Linux, Bash scripting, system administration, and defensive security.

> The script is currently designed and tested primarily for Ubuntu-based systems.

---

## Features

### Users

- Lists users with a valid shell
- Displays UID and shell information
- Detects multiple UID `0` accounts
- Reports potentially dangerous root-account configurations

### Network

- Displays established TCP connections
- Extracts connected remote IP addresses
- Lists listening TCP/UDP ports
- Shows processes associated with listening sockets when permissions allow it

### SSH

- Checks effective OpenSSH configuration
- Checks `PermitRootLogin`
- Checks `PasswordAuthentication`
- Displays successful SSH connections
- Displays failed SSH attempts from the last 24 hours
- Displays currently active SSH connections
- Checks Fail2Ban status and the `sshd` jail

### Firewall

- Detects whether UFW is installed
- Checks whether UFW is active
- Displays verbose firewall status
- Lists numbered firewall rules
- Displays listening network ports

### Docker

- Detects whether Docker is installed and available
- Checks Docker service status
- Lists containers and their status
- Displays published container ports
- Detects privileged containers
- Displays restart policies
- Displays container mounts
- Checks configured container users
- Highlights containers potentially running as root

### Services & Processes

- Lists running systemd services
- Lists enabled services
- Detects failed services
- Lists processes running as root
- Displays the top CPU-consuming processes
- Displays the top memory-consuming processes

### Updates

- Checks for available package updates
- Checks for security updates
- Counts pending updates
- Detects whether the system requires a reboot
- Lists packages responsible for a pending reboot when available

### Filesystem & Permissions

- Searches for world-writable files
- Lists SUID and SGID files for review
- Displays permissions and ownership of sensitive files such as:

```text
/etc/passwd
/etc/shadow
/etc/group
/etc/gshadow
/etc/ssh/sshd_config
```

---

## Terminal Output

The terminal output uses ANSI colors to make results easier to read.

| Status | Meaning |
|---|---|
| 🟢 `[OK]` | Check passed |
| 🔵 `[INFO]` | Informational result |
| 🟡 `[WARNING]` | Something worth reviewing |
| 🔴 `[ERROR]` | A check could not be completed |
| 🔴 `[CRITICAL]` | Potentially unsafe configuration |
| 🟣 Sections | Report categories |

ANSI color codes are only used for terminal output.

The generated report remains plain text, making it suitable for logging, automated processing, or sending through another application.

---

## Requirements

The script expects a Linux system using tools commonly available on Ubuntu.

Main dependencies include:

```text
bash
systemd / systemctl
OpenSSH
ss
awk
grep
sed
find
stat
apt
```

Optional integrations:

```text
ufw
fail2ban
docker
```

Some checks are automatically skipped when the corresponding software is unavailable.

---

## Installation

Clone the repository:

```bash
git clone <YOUR_REPOSITORY_URL>
cd <YOUR_REPOSITORY>
```

Make the script executable:

```bash
chmod +x security-checkup.sh
```

Check the Bash syntax:

```bash
bash -n security-checkup.sh
```

Optionally analyze the script with ShellCheck:

```bash
sudo apt install shellcheck
shellcheck security-checkup.sh
```

---

## Usage

For the most complete audit, run the script with elevated privileges:

```bash
sudo ./security-checkup.sh
```

Some information, including system logs, process details, firewall state, Docker configuration, and authentication data, may be incomplete without sufficient permissions.

---

## 📄 Reports

Reports are generated automatically under:

```text
$HOME/security-logs/
```

Each report uses a timestamped filename:

```text
security-report-YYYY-MM-DD_HH-MM-SS.txt
```

Example:

```text
security-report-2026-08-25_01-30-42.txt
```

Reports intentionally contain no ANSI color sequences.

> Security reports may contain sensitive infrastructure information such as usernames, IP addresses, open ports, running services, container names, and filesystem paths. Do not publish generated reports publicly.

---

## Project Structure

The script is organized into security categories:

```text
VPS SECURITY CHECKUP
│
├── Users
│
├── Network / IP
│
├── SSH
│   ├── Configuration
│   ├── Fail2Ban
│   └── Activity
│
├── Firewall
│
├── Docker
│   ├── Status
│   ├── Containers
│   ├── Exposed ports
│   ├── Privileged containers
│   ├── Restart policies
│   ├── Mounts
│   └── Container users
│
├── Services / Processes
│
├── Updates / Packages
│
└── Filesystem / Permissions
```

The project uses small Bash functions for individual checks and `check_*` functions to group related checks into categories.

---

## Security

This project is intended for **defensive security auditing of systems you own or are authorized to administer**.

The script is read-oriented and is designed to inspect system configuration rather than modify security settings automatically.

Before publishing forks or modifications, make sure the source code does not contain:

- API keys
- Discord bot tokens
- SSH private keys
- passwords
- `.env` files
- private infrastructure information

Generated security reports should generally remain private.

---

## Development

This project is being developed progressively as a way to learn:

- Bash scripting
- Linux administration
- Linux permissions
- networking
- systemd
- OpenSSH
- Docker security
- firewall configuration
- log analysis
- defensive security auditing

Planned areas for future development include:

- sudo and authentication auditing
- security event analysis
- stronger Docker configuration checks
- filesystem integrity monitoring
- configurable security baselines
- report summaries and severity counts
- Discord bot integration

---

## Disclaimer

This script is not a replacement for a professional security audit or dedicated security tools.

A result marked `[OK]` does not guarantee that a system is secure, and a `[WARNING]` does not necessarily indicate a vulnerability.

Always review findings in the context of the system being audited.

---

## License

Choose a license appropriate for your project, such as the MIT License, before distributing or accepting contributions.
