#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=proxmox-lib.sh
source "${SCRIPT_DIR}/proxmox-lib.sh"

TARGET="ephemeral"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--target ephemeral|continuous]" >&2
      exit 1
      ;;
  esac
done

if [[ "$TARGET" == "ephemeral" ]]; then
  VMID="$VM_EPHEMERAL"
  HOSTNAME="oqto-e2e-ephemeral"
elif [[ "$TARGET" == "continuous" ]]; then
  VMID="$VM_CONTINUOUS"
  HOSTNAME="oqto-e2e-continuous"
else
  echo "Invalid target: $TARGET" >&2
  exit 1
fi

require_key

KEY_CONTENT=$(cat "$OQTO_E2E_SSH_KEY.pub")

proxmox_cmd "cat > /tmp/oqto-e2e-key.pub <<'EOF'
${KEY_CONTENT}
EOF"

proxmox_cmd "/usr/sbin/qm stop ${VMID}" >/dev/null 2>&1 || true
proxmox_cmd "/usr/sbin/qm destroy ${VMID} --purge" >/dev/null 2>&1 || true
proxmox_cmd "/usr/sbin/pct stop ${VMID}" >/dev/null 2>&1 || true
proxmox_cmd "/usr/sbin/pct destroy ${VMID} --purge" >/dev/null 2>&1 || true

rootfs_arg="${OQTO_E2E_STORAGE}:${OQTO_E2E_ROOTFS_SIZE}"

proxmox_cmd "/usr/sbin/pct create ${VMID} ${OQTO_E2E_LXC_TEMPLATE} \
  --hostname ${HOSTNAME} \
  --storage ${OQTO_E2E_STORAGE} \
  --rootfs ${rootfs_arg} \
  --cores ${OQTO_E2E_CT_CORES} \
  --memory ${OQTO_E2E_CT_MEMORY_MB} \
  --swap ${OQTO_E2E_CT_SWAP_MB} \
  --net0 name=eth0,bridge=${OQTO_E2E_BRIDGE},ip=dhcp \
  --features nesting=1,keyctl=1 \
  --unprivileged 1 \
  --ssh-public-keys /tmp/oqto-e2e-key.pub"

proxmox_cmd "/usr/sbin/pct start ${VMID}"

ip=$(lxc_wait_for_ip "$VMID")

proxmox_cmd "/usr/sbin/pct exec ${VMID} -- bash -lc 'apt-get update && apt-get install -y openssh-server sudo git curl docker.io'"
proxmox_cmd "/usr/sbin/pct exec ${VMID} -- bash -lc 'systemctl enable --now ssh'"
proxmox_cmd "/usr/sbin/pct exec ${VMID} -- bash -lc 'systemctl enable --now docker'"

proxmox_cmd "/usr/sbin/pct exec ${VMID} -- bash -lc 'useradd -m -s /bin/bash ${OQTO_E2E_SSH_USER} || true'"
proxmox_cmd "/usr/sbin/pct exec ${VMID} -- bash -lc 'usermod -aG sudo ${OQTO_E2E_SSH_USER}'"
proxmox_cmd "/usr/sbin/pct exec ${VMID} -- bash -lc 'usermod -aG docker ${OQTO_E2E_SSH_USER}'"
proxmox_cmd "/usr/sbin/pct exec ${VMID} -- bash -lc 'mkdir -p /home/${OQTO_E2E_SSH_USER}/.ssh && chown -R ${OQTO_E2E_SSH_USER}:${OQTO_E2E_SSH_USER} /home/${OQTO_E2E_SSH_USER}/.ssh'"
proxmox_cmd "/usr/sbin/pct exec ${VMID} -- bash -lc 'cat /root/.ssh/authorized_keys > /home/${OQTO_E2E_SSH_USER}/.ssh/authorized_keys && chown ${OQTO_E2E_SSH_USER}:${OQTO_E2E_SSH_USER} /home/${OQTO_E2E_SSH_USER}/.ssh/authorized_keys'"
proxmox_cmd "/usr/sbin/pct exec ${VMID} -- bash -lc 'chmod 700 /home/${OQTO_E2E_SSH_USER}/.ssh && chmod 600 /home/${OQTO_E2E_SSH_USER}/.ssh/authorized_keys'"
proxmox_cmd "/usr/sbin/pct exec ${VMID} -- bash -lc 'echo "${OQTO_E2E_SSH_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/oqto-e2e && chmod 440 /etc/sudoers.d/oqto-e2e'"

echo "Created LXC ${VMID} (${HOSTNAME}) at ${ip}. Opening SSH session..."

exec ssh -i "$OQTO_E2E_SSH_KEY" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "${OQTO_E2E_SSH_USER}@${ip}"
