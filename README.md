# Zeroclaw on a VPS

- This guide covers deployment-specific steps for running Zeroclaw as a long-running sandboxed service on a VPS. 
- Follow this guide for a simple setup and for detailed setup and configuration, and usage, see the [official README](https://github.com/zeroclaw-labs/zeroclaw).

## 1. Run one-shot setup script (as root)

Use the included script file in this repo to perform the base VPS setup in one pass:

What this script does:
- Creates a non-root user and grants sudo access.
- Installs Docker and adds the user to the docker group.
- Copies root SSH authorized keys to the new user for passwordless login.
- Adds Zeroclaw PATH bootstrap to `.bashrc` (idempotent; no duplicate entries on rerun).
- Enables user systemd lingering. Zeroclaw's `service install` uses user-scoped systemd (`systemctl --user`), which requires a D-Bus session bus. Headless VPSes don't have one by default.
- Installs Zeroclaw as the non-root user.

### Option 1: Run the script locally on the VPS
```bash
sudo bash zeroclaw-setup.sh
```
### Option 2: Run the scriptwith a custom username (default is `zeroclaw`)
```bash
sudo bash zeroclaw-setup.sh mybot
```
### Option 3: Run the script remotely via curl
```bash
curl -fsSL https://<your-raw-url>/zeroclaw-setup.sh | bash
```

## 2. First login and onboarding

SSH into your VPS as the setup user and run onboarding:
- You will find zeeroclaw installed at `~/.zeroclaw/`.
```bash
ssh -i <path-to-ssh-key> zeroclaw@<your-vps>
zeroclaw onboard
```

Suggested onboarding choices:
- Turn on multi-workspace profiles: Yes
- Give a name to active workspace: `my-bot-space`
- Isolated memory/secrets: Yes (set No only if you need sharing across workspaces)
- cross-workspace-search: No
- Model provider/model: your choice
- Memory backend: SQLite (default)

## 3. Docker sandbox

**Do not skip this step.**
- Zeroclaw uses Docker as a sandbox backend on Linux. 
- Every tool the agent runs (shell, browser, code execution) is contained inside an ephemeral container. 
- Running without sandbox means the agent has unrestricted access to your filesystem.

**Then** enable the sandbox in `~/.zeroclaw/config.toml`:

```toml
[sandbox]
backend = "docker"
```
**Restart zeroclaw service** `zeroclaw service start`

You can verify sandbox is active by running `zeroclaw doctor` — look for "Sandbox: docker" in the output.

## 4. Run as a systemd service

Zeroclaw ships built-in service management:

```bash
zeroclaw service install    # registers a systemd unit
zeroclaw service start      # starts it immediately
```

Check status:

```bash
systemctl --user status zeroclaw
journalctl --user -u zeroclaw -f   # follow logs
```

The service auto-restarts on crash and starts on boot.

## 5. Staying up to date with zeroclaw updates

Re-run the installer to replace the binary, then restart the service. Your config and data in `~/.zeroclaw/` are untouched.

```bash
curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/master/install.sh | bash -s -- --prebuilt --skip-onboard && systemctl --user restart zeroclaw
```

To automate, add a weekly cron job:

```bash
# Runs every Sunday at 03:00 UTC
0 3 * * 0 curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/master/install.sh | bash -s -- --prebuilt --skip-onboard && systemctl --user restart zeroclaw
```

> Pin to a release with `--version vX.Y.Z` if you prefer manual, tested upgrades.
