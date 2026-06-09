#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
# ZeroClaw one-shot VPS setup
# Run this as root on a fresh VPS.
# Safe to re-run — idempotent.
# ─────────────────────────────────────────────────────────

NEW_USER="${1:-zeroclaw}"
ZEROCLAW_HOME="/home/$NEW_USER"

echo "=== 1. Create non-root user $NEW_USER ==="
if ! id "$NEW_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$NEW_USER"
  echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-"$NEW_USER"
fi
if ! id -nG "$NEW_USER" | grep -qw sudo; then
  usermod -aG sudo "$NEW_USER"
fi

echo "=== 2. Install Docker ==="
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | bash
fi
usermod -aG docker "$NEW_USER"

echo "=== 3. Copy root SSH keys (passwordless login) ==="
mkdir -p "$ZEROCLAW_HOME/.ssh"
if [ -f /root/.ssh/authorized_keys ]; then
  cp /root/.ssh/authorized_keys "$ZEROCLAW_HOME/.ssh/authorized_keys"
  chown -R "$NEW_USER":"$NEW_USER" "$ZEROCLAW_HOME/.ssh"
  chmod 700 "$ZEROCLAW_HOME/.ssh"
  chmod 600 "$ZEROCLAW_HOME/.ssh/authorized_keys"
fi

echo "=== 4. Auto-cd on login & PATH ==="
if ! grep -Fq "# ZeroClaw" "$ZEROCLAW_HOME/.bashrc" 2>/dev/null; then
  cat >> "$ZEROCLAW_HOME/.bashrc" <<'BASHRC'

# ZeroClaw
export PATH="$HOME/.cargo/bin:$PATH"
cd
BASHRC
fi
chown "$NEW_USER":"$NEW_USER" "$ZEROCLAW_HOME/.bashrc"

echo "=== 5. Enable user systemd lingering (fixes D-Bus error) ==="
loginctl enable-linger "$NEW_USER"

echo "=== 6. Install ZeroClaw (as $NEW_USER) ==="
su - "$NEW_USER" -c "
  curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/master/install.sh | bash -s -- --prebuilt
"

echo ""
echo "══════════════════════════════════════════════════════"
echo "  Setup complete!"
echo ""
echo "  Next steps (as $NEW_USER):"
echo "    1. ssh $NEW_USER@<your-vps>   (no password)"
echo "    2. zeroclaw onboard           (configure provider)"
echo "    3. Enable sandbox in ~/.zeroclaw/config.toml:"
echo "         [security.sandbox]"
echo "         backend = \"docker\""
echo "    4. zeroclaw service install"
echo "    5. zeroclaw service start"
echo ""
echo "  Update later:"
echo "    curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/master/install.sh | bash -s -- --prebuilt --skip-onboard"
echo "    systemctl --user restart zeroclaw"
echo "══════════════════════════════════════════════════════"
