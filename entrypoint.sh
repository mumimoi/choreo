#!/usr/bin/env bash
set -euo pipefail

SSH_PORT="${SSH_PORT:-2222}"
HTTP_PORT="${HTTP_PORT:-6080}"

APP_HOME="/home/app"
SSH_DIR="${SSH_DIR:-${APP_HOME}/ssh}"
RUN_DIR="${RUN_DIR:-${APP_HOME}/run}"
AUTHORIZED_KEYS_FILE="${AUTHORIZED_KEYS_FILE:-${APP_HOME}/.ssh/authorized_keys}"
SSHD_CONFIG="${SSHD_CONFIG:-${SSH_DIR}/sshd_config}"

mkdir -p "${SSH_DIR}" "${RUN_DIR}" "$(dirname "${AUTHORIZED_KEYS_FILE}")"

# Install authorized_keys from env (pilih salah satu)
if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
  printf '%s\n' "${SSH_PUBLIC_KEY}" > "${AUTHORIZED_KEYS_FILE}"
fi
if [[ -n "${AUTHORIZED_KEYS:-}" ]]; then
  printf '%s\n' "${AUTHORIZED_KEYS}" > "${AUTHORIZED_KEYS_FILE}"
fi

if [[ -f "${AUTHORIZED_KEYS_FILE}" ]]; then
  chmod 700 "$(dirname "${AUTHORIZED_KEYS_FILE}")"
  chmod 600 "${AUTHORIZED_KEYS_FILE}"
else
  echo "[entrypoint] WARNING: authorized_keys belum ada."
  echo "[entrypoint] Set env SSH_PUBLIC_KEY atau AUTHORIZED_KEYS agar bisa SSH."
fi

# Generate host keys in user-writable path
if [[ ! -f "${SSH_DIR}/ssh_host_ed25519_key" ]]; then
  ssh-keygen -t ed25519 -f "${SSH_DIR}/ssh_host_ed25519_key" -N "" >/dev/null
  chmod 600 "${SSH_DIR}/ssh_host_ed25519_key"
fi

if [[ ! -f "${SSH_DIR}/ssh_host_rsa_key" ]]; then
  ssh-keygen -t rsa -b 3072 -f "${SSH_DIR}/ssh_host_rsa_key" -N "" >/dev/null
  chmod 600 "${SSH_DIR}/ssh_host_rsa_key"
fi

# Minimal sshd_config (non-root)
if [[ ! -f "${SSHD_CONFIG}" ]]; then
  cat > "${SSHD_CONFIG}" <<EOF
Port ${SSH_PORT}
ListenAddress 0.0.0.0

HostKey ${SSH_DIR}/ssh_host_ed25519_key
HostKey ${SSH_DIR}/ssh_host_rsa_key

PidFile ${RUN_DIR}/sshd.pid

PermitRootLogin no
UsePAM no
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no

PubkeyAuthentication yes
AuthorizedKeysFile ${AUTHORIZED_KEYS_FILE}
AllowUsers app

Subsystem sftp internal-sftp
LogLevel VERBOSE
EOF
fi

# Start SSHD (foreground)
# Note: sshd non-root umumnya hanya bisa menerima login untuk user yang sama (app)
# Start it in background so we can run other processes too.
/usr/sbin/sshd -D -e -f "${SSHD_CONFIG}" &
SSHD_PID=$!

# Start HTTP server (optional, like original)
python3 -m http.server "${HTTP_PORT}" --directory /var/www >/dev/null 2>&1 &
HTTP_PID=$!

# Start cloudflared if token set
if [[ -n "${TUNNEL_TOKEN:-}" ]]; then
  cloudflared tunnel run --token "${TUNNEL_TOKEN}" &
  CF_PID=$!
else
  CF_PID=""
  echo "[entrypoint] TUNNEL_TOKEN kosong -> cloudflared tidak dijalankan"
fi

term() {
  kill -TERM "${HTTP_PID}" 2>/dev/null || true
  kill -TERM "${SSHD_PID}" 2>/dev/null || true
  if [[ -n "${CF_PID}" ]]; then
    kill -TERM "${CF_PID}" 2>/dev/null || true
  fi
  wait || true
}

trap term INT TERM

wait -n
