#!/usr/bin/env bash
# Simple bootstrap helper for automated Linux installs
# Downloads kickstart.cfg from this repo and demonstrates applying it

set -euo pipefail
BRANCH="main"

while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--branch)
      BRANCH="$2"; shift 2;;
    *) shift;;
  esac
done

KS_URL="https://raw.githubusercontent.com/wizzense/opentofu-lab-automation/refs/heads/${BRANCH}/tools/iso/kickstart.cfg"
KS_FILE="/tmp/kickstart.cfg"

curl -fsSL "$KS_URL" -o "$KS_FILE"

if [[ ! -f "$KS_FILE" ]]; then
  echo "Failed to download kickstart.cfg" >&2
  exit 1
fi

echo "Kickstart file saved to $KS_FILE"

if command -v virt-install >/dev/null 2>&1; then
  echo "Launching virt-install using the downloaded kickstart file..."
  virt-install \
    --name tofu-lab-vm \
    --ram 2048 \
    --disk size=20 \
    --location 'http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/' \
    --initrd-inject="$KS_FILE" \
    --extra-args "inst.ks=file:/kickstart.cfg console=ttyS0" \
    --noreboot
else
  echo "virt-install not found. Use the kickstart file manually with your installer."
fi
