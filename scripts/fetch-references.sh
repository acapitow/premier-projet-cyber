#!/usr/bin/env bash
# =============================================================================
# fetch-references.sh — SOC Home Lab
# Auteur : André Capito (@acapitow)
#
# Clone (en shallow) les dépôts de référence reconnus dans references/
# (dossier EXCLU du dépôt via .gitignore). On s'appuie sur eux pour le format
# des règles Sigma, la config Sysmon, les IDs Atomic Red Team et les rôles
# Ansible Wazuh. Voir NOTICE.md pour les licences.
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF_DIR="${ROOT}/references"
mkdir -p "$REF_DIR"

# nom|url
REPOS=(
  "sigma|https://github.com/SigmaHQ/sigma.git"
  "sysmon-config|https://github.com/SwiftOnSecurity/sysmon-config.git"
  "sysmon-modular|https://github.com/olafhartong/sysmon-modular.git"
  "atomic-red-team|https://github.com/redcanaryco/atomic-red-team.git"
  "wazuh-ansible|https://github.com/wazuh/wazuh-ansible.git"
)

echo "Clonage des dépôts de référence dans : $REF_DIR"
for entry in "${REPOS[@]}"; do
  name="${entry%%|*}"; url="${entry##*|}"
  dest="${REF_DIR}/${name}"
  if [[ -d "$dest/.git" ]]; then
    echo "  [=] $name déjà présent — git pull"
    git -C "$dest" pull --ff-only --depth 1 || true
  else
    echo "  [+] clonage de $name (shallow)"
    git clone --depth 1 "$url" "$dest"
  fi
done

echo
echo "Terminé. Rappel : 'references/' est ignoré par git et chaque dépôt garde sa licence."
